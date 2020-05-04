! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: math io.encodings.binary kernel io io.files locals endian bit-arrays math.intervals combinators combinators.extras math.order sequences namespaces accessors byte-arrays math.bitwise ;
USING: prettyprint ;
USING: flac.bitstream flac.metadata flac.format ;

IN: flac.decoder

: read-utf8-uint ( -- n )
    0 [ 1 flac-read-uint 1 = ] [ 1 + ] while
    dup [ 7 swap - flac-read-uint ] dip
    <iota> [
        drop
        2 flac-read-uint drop
        6 shift 6 flac-read-uint bitor
    ] each ;

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

: read-flac-subframe-constant ( frame-header subframe-header -- constant-subframe )
    drop bits-per-sample>> flac-read-uint flac-subframe-constant boa ;

! : read-flac-residuals  ( block-size - seq )
!     2 flac-read-uint
!     dup
!     {
!         { [ 0 1 between? ] [ <flac-entropy-coding-method> ] }
!         [ drop reserved-residual-coding ]
!     } cond-case
!     4 flac-read-uint
!     ;

: read-flac-residuals ( block-size -- seq )
    ;

: read-flac-subframe-fixed ( frame-header subframe-header -- fixed-subframe )
    [ [ blocksize>> ] [ bits-per-sample>> ] bi ] dip
    pre-order>> swap <repetition> [ flac-read-sint ] map ! warm up samples
    [ read-flac-residuals ] dip
!   swap read-flac-redisduals
    flac-subframe-fixed new swap >>warmup swap drop ;

: decode-flac-subframe-type ( n -- type order )
    dup
    {
        { [ 0 = ] [ drop f 0 ] }
        { [ 1 = ] [ drop f 1 ] }
        { [ 8 12 between? ] [ -1 shift 7 bitand 2 ] }
        { [ 32 63 between? ] [ -1 shift 31 bitand 3 ] }
        [ drop reserved-subframe-type ]
    } cond-case
    <flac-subframe-type> swap ;

: read-flac-subframe-header ( -- subframe-header )
    1 flac-read-uint 1 = [ invalid-subframe-sync ] when
    6 flac-read-uint decode-flac-subframe-type
    1 flac-read-uint
    flac-subframe-header boa ;

: read-flac-subframe ( frame-header -- subframe )
    read-flac-subframe-header dup dup
    [
        subframe-type>>
        {
            { subframe-type-constant [ read-flac-subframe-constant ] }
            { subframe-type-fixed [ read-flac-subframe-fixed ] }
        } case
    ] dip swap
    flac-subframe boa ;

: read-flac-subframes ( frame-header -- seq )
    dup channels>> swap <repetition> [ read-flac-subframe ] map ;

: read-flac-frame-header ( -- frame-header )
    14 flac-read-uint drop ! ignore sync
    1 flac-read-uint drop ! reserved
    1 flac-read-uint
    4 flac-read-uint
    4 flac-read-uint
    4 flac-read-uint
    3 flac-read-uint
    1 flac-read-uint drop ! ignore magic sync for now
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
    8 flac-read-uint
    flac-frame-header boa ;

: read-flac-frame-footer ( -- frame-footer )
    16 flac-read-uint flac-frame-footer boa ;

: read-flac-frame ( -- frame )
    read-flac-frame-header dup
    read-flac-subframes
    read-flac-frame-footer
    flac-frame boa ;

: read-flac-file ( filename -- flac-stream )
    [
        read-flac-metadata drop
        read-flac-frame drop
        read-flac-frame drop
        read-flac-frame drop
        read-flac-frame

    ] with-flac-file-reader ;
