! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: math io.encodings.binary kernel io io.files locals endian bit-arrays math.intervals combinators combinators.extras math.order sequences namespaces accessors byte-arrays math.bitwise ;
USING: prettyprint ;
USING: flac.bitstream flac.metadata flac.format ;

IN: flac.decoder

CONSTANT: sync-code 16382

ERROR: sync-code-error ;
ERROR: invalid-channel-assignment ;
ERROR: reserved-block-size ;
ERROR: invalid-sample-rate ;
ERROR: reserved-subframe-type ;
ERROR: invalid-subframe-sync ;

: 0xxxxxxx? ( n -- ? ) 0x80 mask? not ;
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

! :: decode-utf8-uint ( frame-length bitstream -- n )
!     frame-length 7 -
!     bitstream read-bit
!     frame-length <iota> [
!         drop
!         2 bitstream read-bit drop
!         6 shift 6 bitstream read-bit bitor
!     ] each ;

: read-utf8-uint ( -- n )
    8 flac-read-uint dup
    [ 0b11000000 <= ]
    [
        8 flac-read-uint drop
        1 shift 0xff bitand
    ] while ;

! : read-utf8-uint ( -- n )
!      1 read dup
!      be> 0xxxxxxx?
!      [ be> ]
!      [ dup be> remaining-bytes read B{ } append-as be> ] if ;

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
        { 0b000 [ "TODO" ] }
        { 0b001 [ 8 ] }
        { 0b010 [ 12 ] }
        { 0b011 [ "TODO" ] }
        { 0b100 [ 16 ] }
        { 0b101 [ 20 ] }
        { 0b110 [ 24 ] }
        { 0b111 [ "TODO" ] }
    } case ;

: decode-sample-rate ( n -- n )
    {
        { 0b0000 [ "TODO" ] }
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
        { 0b1100 [ 8 flac-read-uint 1000 * ] }
        { 0b1101 [ 16 flac-read-uint ] }
        { 0b1110 [ 16 flac-read-uint 10 * ] }
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

! :: decode-header ( bitstream -- frame-header )
!     [
!         14 bitstream read-bit drop ! ignore sync
!         1 bitstream read-bit drop ! reserved
!         1 bitstream read-bit
!         4 bitstream read-bit
!         4 bitstream read-bit
!         4 bitstream read-bit
!         3 bitstream read-bit
!         1 bitstream read-bit drop ! ignore magic sync
!         read-utf8-uint
!         [
!             {
!                 [ <flac-frame-number-type> ]
!                 [ decode-block-size ]
!                 [ decode-sample-rate ]
!                 [ decode-channels ]
!                 [ decode-bits-per-sample ]
!             } spread
!         ] dip
!         1 read be>
!     ] with-big-endian
!     flac-frame-header boa ;
! 
! : decode-subframe-type ( n -- order type )
!     dup
!     {
!         { [ 0 = ] [ drop f 0 ] }
!         { [ 1 = ] [ drop f 1 ] }
!         { [ 8 12 between? ] [ -1 shift 7 bitand 2 ] }
!         { [ 32 63 between? ] [ -1 shift 31 bitand 3 ] }
!         [ drop reserved-subframe-type ]
!     } cond-case <flac-subframe-type> swap ;
! 
! : read-residual ( order -- residual )
!     drop "TODO" ;
! 
! : read-constant-subframe ( frame-header subframe-header -- constant-subframe )
!     drop bits-per-sample>> 8 / read be> flac-subframe-constant boa ;
! 
! : read-fixed-subframe ( fame-header subframe-header -- fixed-subframe )
!     order>> swap bits-per-sample>> <repetition> [
!         8 / read be>
!     ] map flac-subframe-fixed new swap >>warmup dup . ;
! 
! : read-lpc-subframe ( predictive-order -- lpc-subframe )
!     drop "TODO" ;
! 
! :: decode-subframe-header ( bitstream -- subframe-header )
!     1 bitstream read-bit 1 = [ invalid-subframe-sync ] when
!     6 bitstream read-bit decode-subframe-type
!     1 bitstream read-bit ! TODO: wasted-bits: 0 for now..
!     flac-subframe-header boa ;
! 
! ! TODO: actually decode based on subframe type
! ! TODO: handle wasted bits assuming 1 byte for now :/
! : read-subframe ( frame-header -- subframe )
!     1 read bitstreams:<msb0-bit-reader> decode-subframe-header dup dup
!     [
!         subframe-type>>
!         {
!             { subframe-type-constant [ read-constant-subframe ] }
!             { subframe-type-fixed [ read-fixed-subframe ] }
!         } case
!     ] dip swap flac-subframe boa ;
! 
! : read-subframes ( frame-header -- seq )
!     dup channels>> swap <repetition> [ dup . read-subframe ] map ;
! 
! : read-frame-header ( -- frame-header )
!     4 read bitstreams:<msb0-bit-reader> decode-header ;
! 
! : read-frame-footer ( -- frame-footer )
!     2 read be> flac-frame-footer boa ;
! 
! : read-frame ( -- frame )
!     read-frame-header dup
!     read-subframes
!     read-frame-footer
!     flac-frame boa ;
! 
! : read-flac-file ( filename -- something )
!     binary
!     [
!         read-flac-magic [ not-a-flac-file ] unless
!         read-stream-info .
!         skip-metadata
! !        51448296 seek-absolute seek-input
!         4 <iota> [ drop read-frame ] map
!     ] with-file-reader ;

: read-flac-frame-header ( -- frame-header )
    14 flac-read-uint drop
    1 flac-read-uint drop
    1 flac-read-uint <flac-frame-number-type>
    4 flac-read-uint decode-block-size
    4 flac-read-uint decode-sample-rate
    4 flac-read-uint decode-channels
    3 flac-read-uint decode-bits-per-sample
    1 flac-read-uint drop
    read-utf8-uint
    flac-frame-header boa ;

: read-flac-file ( filename -- flac-stream )
    [
        read-flac-metadata
    ] with-flac-stream-reader ;
