! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: alien.syntax math io.encodings.binary kernel io io.files locals endian bit-arrays math.intervals combinators math.order sequences io.streams.peek io.binary namespaces accessors byte-arrays ;
USING: prettyprint ;
USING: flac.metadata.private flac.metadata ;

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

ENUM: flac-channel-assignment
    channels-mono
    channels-left/right
    channels-left/right/center
    channels-left/right/left-surround/right-surround
    channels-left/right/center/left-surround/right-surround
    channels-left/right/center/lfe/left-surround/right-surround
    channels-left/right/center/lfe/center-surround/side-left/side-right
    channels-left/right/center/lfe/left-surround/right-surround/side-left/side-right
    channels-left
    channels-right
    channels-mid ;

ENUM: flac-frame-number-type
    frame-number-type-frame
    frame-number-type-sample ;

ENUM: flac-subframe-type
    subframe-type-constant
    subframe-type-verbatim
    subframe-type-fixed
    subframe-type-lpc ;

ENUM: flac-entropy-coding-method
    entropy-coding-partioned-rice
    entropy-coding-partioned-rice2 ;

TUPLE: flac-subframe
    { type maybe{ subframe-type-constant
                  subframe-type-verbatim
                  subframe-type-fixed
                  subframe-type-lpc } }
    { wasted-bits integer }
    { data byte-array } ;

TUPLE: frame-header
    { number-type maybe{ frame-number-type-frame frame-number-type-sample } }
    { blocksize integer }
    { sample-rate integer }
    { channels integer }
    { channel-assignment maybe{ channels-mono
                                channels-left/right
                                channels-left/right/center
                                channels-left/right/left-surround/right-surround
                                channels-left/right/center/left-surround/right-surround
                                channels-left/right/center/lfe/left-surround/right-surround
                                channels-left/right/center/lfe/center-surround/side-left/side-right
                                channels-left/right/center/lfe/left-surround/right-surround/side-left/side-right
                                channels-left
                                channels-right
                                channels-mid } }
    { bits-per-sample integer }
    { frame|sample-number integer }
    { crc integer } ;

TUPLE: frame-footer
    { crc integer } ;

TUPLE: flac-frame
    { header frame-header }
    { subframes sequence }
    { footer frame-footer } ;

: 0xxxxxxx? ( n -- ? ) 0x80 bitand 0x80 = not ;
: 110xxxxx? ( n -- ? ) dup [ 0xc0 bitand 0xc0 = ] [ 0x20 bitand 0x20 = not ] bi* and ;
: 1110xxxx? ( n -- ? ) dup [ 0xe0 bitand 0xe0 = ] [ 0x10 bitand 0x10 = not ] bi* and ;
: 11110xxx? ( n -- ? ) dup [ 0xf0 bitand 0xf0 = ] [ 0x08 bitand 0x08 = not ] bi* and ;
: 111110xx? ( n -- ? ) dup [ 0xf8 bitand 0xf8 = ] [ 0x04 bitand 0x04 = not ] bi* and ;
: 1111110x? ( n -- ? ) dup [ 0xfc bitand 0xfc = ] [ 0x02 bitand 0x02 = not ] bi* and ;
: 11111110? ( n -- ? ) dup [ 0xfe bitand 0xfe = ] [ 0x01 bitand 0x01 = not ] bi* and ;

:: remaining-bytes ( n -- n )
    {
        { [ n 110xxxxx? ] [ 1 ] }
        { [ n 1110xxxx? ] [ 2 ] }
        { [ n 11110xxx? ] [ 3 ] }
        { [ n 111110xx? ] [ 4 ] }
        { [ n 1111110x? ] [ 5 ] }
        { [ n 11111110? ] [ 6 ] }
    } cond ;

! : remaining-bytes ( n -- n )
!     {
!         { [ dup 110xxxxx? ] [ drop 1 ] }
!         { [ dup 1110xxxx? ] [ drop 2 ] }
!         { [ dup 11110xxx? ] [ drop 3 ] }
!         { [ dup 111110xx? ] [ drop 4 ] }
!         { [ dup 1111110x? ] [ drop 5 ] }
!         { [ dup 11111110? ] [ drop 6 ] }
!     } cond ;

:: decode-utf8-uint ( frame-length bitstream -- n )
    frame-length 7 -
    bitstream read-bit
    frame-length <iota>
    [
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
    {
        { [ dup 0b0000 = ] [ drop reserved-block-size ] }
        { [ dup 0b0001 = ] [ drop 192 ] }
        { [ dup 0b0010 0b0101 between? ] [ 2 - 2^ 567 * ] }
        { [ dup 0b0110 0b0111 between? ] [ ] }
        { [ dup 0b1000 0b1111 between? ] [ 8 - 2^ 256 * ] }
    } cond ;

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
    frame-header boa ;

:: decode-subframe-type ( n -- type )
    {
        { [ n 0 = ] [ 0 ] }
        { [ n 1 = ] [ 1 ] }
        { [ n 8 >= n 12 <= and ] [ 2 ] }
        { [ n 32 >= ] [ 3 ] }
        [ invalid-subframe-type ]
    } cond <flac-subframe-type> ;

:: decode-subframe ( bitstream -- subframe )
    1 bitstream read-bit 1 = [ invalid-subframe-sync ] when
    6 bitstream read-bit decode-subframe-type
    1 bitstream read-bit ! TODO: wasted-bits: 0 for now..
    B{ }
    flac-subframe boa ;


! TODO: actually decode based on subframe type
! TODO: handle wasted bits assuming 1 byte for now :/
: read-subframe ( frame-header channel -- subframe )
    drop drop
   1 read bitstreams:<msb0-bit-reader> decode-subframe ;

: read-subframes ( frame-header -- seq )
    dup channels>> swap <repetition> [ read-subframe ] map-index ;

: read-frame-header ( -- frame-header )
    4 read bitstreams:<msb0-bit-reader> decode-header ;

: read-frame ( -- frame )
    read-frame-header
    dup read-subframes
    frame-footer new
    flac-frame boa ;

: decode-file ( filename -- something )
    binary
    [
        read-flac-magic [ not-a-flac-file ] unless
        read-stream-info .
        skip-metadata
!        51448296 seek-absolute seek-input
        read-frame
        contents .
    ] with-file-reader ;
