! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: math io.encodings.binary kernel io io.files locals endian bit-arrays math.intervals combinators combinators.extras math.order sequences io.streams.peek io.binary namespaces accessors byte-arrays math.bitwise ;
USING: prettyprint ;
USING: flac.metadata.private flac.metadata flac.format ;

QUALIFIED: bitstreams

IN: flac.decoder

ALIAS: read-bit bitstreams:read
ALIAS: peek-bits bitstreams:peek

CONSTANT: sync-code 16382
ERROR: sync-code-error ;
ERROR: invalid-channel-assignment ;
ERROR: reserved-block-size ;
ERROR: invalid-sample-rate ;
ERROR: invalid-subframe-type ;
ERROR: invalid-subframe-sync ;

: 0xxxxxxx? ( n -- ? ) 0x80 mask? = not ;
: 110xxxxx? ( n -- ? ) [ 0xc0 mask? ] [ 0x20 mask? not ] bi and ;
: 1110xxxx? ( n -- ? ) [ 0xe0 mask? ] [ 0x10 mask? not ] bi and ;
: 11110xxx? ( n -- ? ) [ 0xf0 mask? ] [ 0x08 mask? not ] bi and ;
: 111110xx? ( n -- ? ) [ 0xf8 mask? ] [ 0x04 mask? not ] bi and ;
: 1111110x? ( n -- ? ) [ 0xfc mask? ] [ 0x02 mask? not ] bi and ;
: 11111110? ( n -- ? ) [ 0xfe mask? ] [ 0x01 mask? not ] bi and ;

: remaining-bytes ( n -- n )
    {
        { [ 110xxxxx? ] [ 1 ] }
        { [ 1110xxxx? ] [ 2 ] }
        { [ 11110xxx? ] [ 3 ] }
        { [ 111110xx? ] [ 4 ] }
        { [ 1111110x? ] [ 5 ] }
        { [ 11111110? ] [ 6 ] }
    } cond-case ;

:: decode-utf8-uint ( frame-length bitstream -- n )
    frame-length 7 -
    bitstream read-bit
    frame-length <iota> [
        drop
        2 bitstream read-bit drop
        6 shift 6 bitstream read-bit bitor
    ] each ;

: read-utf8-uint ( -- n )
     1 read dup
     be> 0xxxxxxx?
     [ be> ]
     [
         dup be> remaining-bytes read
         B{ } append-as be>
     ] if ;

: decode-block-size ( n -- n )
    dup
    {
        { [ 0b0000 = ] [ drop reserved-block-size ] }
        { [ 0b0001 = ] [ drop 192 ] }
        { [ 0b0010 0b0101 between? ] [ 2 - 2^ 567 * ] }
        { [ 0b0110 0b0111 between? ] [ ] }
        { [ 0b1000 0b1111 between? ] [ 8 - 2^ 256 * ] }
    } cond-case ;

: decode-bits-per-sample ( n -- n )
    {
        { 0b000 [ -99 ] }
        { 0b001 [ 8 ] }
        { 0b010 [ 12 ] }
        { 0b011 [ -99 ] }
        { 0b100 [ 16 ] }
        { 0b101 [ 20 ] }
        { 0b110 [ 24 ] }
        { 0b111 [ -99 ] }
    } case ;

: decode-sample-rate ( n -- n )
    {
        { 0b0000 [ -99 ] }
        { 0b0001 [ 88200 ] }
        { 0b0010 [ 17640 ] }
        { 0b0011 [ 19200 ] }
        { 0b0100 [ 8000 ] }
        { 0b0101 [ 16000 ] }
        { 0b0110 [ 22050 ] }
        { 0b0111 [ 24000 ] }
        { 0b1000 [ 32000 ] }
        { 0b1001 [ 44100 ] }
        { 0b1010 [ 48000 ] }
        { 0b1011 [ 96000 ] }
        { 0b1100 [ 1 read be> 1000 * ] }
        { 0b1101 [ 2 read be> ] }
        { 0b1110 [ 2 read be> 10 * ] }
        { 0b1111 [ invalid-sample-rate ] }
    } case ;

: decode-channels ( n -- channels channel-assignment )
    dup
    {
        { [ dup 0b0000 0b0111 between? ] [ 1 + ] }
        { [ 0b1000 0b1010 between? ] [ 2 ] }
        [ invalid-channel-assignment ]
    } cond swap
    <flac-channel-assignment> ;

:: decode-header ( bitstream -- frame-header )
    [
        14 bitstream read-bit drop ! ignore sync
        1 bitstream read-bit drop ! reserved
        1 bitstream read-bit
        4 bitstream read-bit
        4 bitstream read-bit
        4 bitstream read-bit
        3 bitstream read-bit
        1 bitstream read-bit drop ! ignore magic sync
        read-utf8-uint
        [
            {
                [ <flac-frame-number-type> ]
                [ decode-block-size ]
                [ decode-sample-rate ]
                [ decode-channels ]
                [ decode-bits-per-sample ]
            } spread
        ] dip
        1 read be>
    ] with-big-endian
    flac-frame-header boa ;

:: decode-subframe-type ( n -- type )
    {
        { [ n 0 = ] [ 0 ] }
        { [ n 1 = ] [ 1 ] }
        { [ n 8 >= n 12 <= and ] [ 2 ] }
        { [ n 32 >= ] [ 3 ] }
        [ invalid-subframe-type ]
    } cond <flac-subframe-type> ;


: read-constant-subframe ( subframe-header frame-header -- data )
    >>bits-per-sample 8 / read swap drop ;

: read-fixed-subframe ( predictive-order -- subframe )
    drop 9 ;

: read-lpc-subframe ( predictive-order -- subframe )
    drop 9 ;

:: decode-subframe-header ( bitstream -- subframe )
    1 bitstream read-bit 1 = [ invalid-subframe-sync ] when
    6 bitstream read-bit decode-subframe-type
    1 bitstream read-bit ! TODO: wasted-bits: 0 for now..
    flac-subframe-header boa ;

! TODO: actually decode based on subframe type
! TODO: handle wasted bits assuming 1 byte for now :/
: read-subframe ( frame-header -- subframe )
    [
        1 read bitstreams:<msb0-bit-reader> decode-subframe-header dup
    ] dip swap
    subframe-type>>
    {
        { subframe-type-constant [ "1" ] }
        { subframe-type-verbatim [ drop drop B{ } ] }
        { subframe-type-fixed [ drop drop B{ } ] }
        { subframe-type-lpc [ drop drop B{ } ] }
    } case
    flac-subframe boa ;

: read-subframes ( frame-header -- seq )
    dup channels>> swap <repetition> [ read-subframe ] map ;

: read-frame-header ( -- frame-header )
    4 read bitstreams:<msb0-bit-reader> decode-header ;

: read-frame-footer ( -- frame-footer )
    2 read be> flac-frame-footer boa ;

: read-frame ( -- frame )
    read-frame-header
    dup read-subframes
    read-frame-footer
    flac-frame boa ;

: read-flac-file ( filename -- something )
    binary
    [
        read-flac-magic [ not-a-flac-file ] unless
        read-stream-info .
        skip-metadata
!        51448296 seek-absolute seek-input
        3 <iota> [ drop read-frame ] map
    ] with-file-reader ;
