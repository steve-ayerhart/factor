! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: alien.syntax math io.encodings.binary kernel io io.files locals endian bit-arrays ;
USING: prettyprint ;
USING: flac.metadata.private flac.metadata ;

QUALIFIED: bitstreams


IN: flac.decoder

ALIAS: read-bit bitstreams:read
CONSTANT: sync-code 16382
ERROR: sync-code-error ;

ENUM: flac-channel-assignment
    channel-assignment-independent
    channel-assignment-left-side
    channel-assignment-right-side
    channel-assignment-mid-side ;
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

TUPLE: subframe
    { type maybe{ subframe-type-constant
                  subframe-type-verbatim
                  subframe-type-fixed
                  subframe-type-lpc } } ;

TUPLE: frame-header
    { blocksize integer }
    { sample-rate integer }
    { channels integer }
    { channel-assignment maybe{ channel-assignment-independent
                                channel-assignment-left-side
                                channel-assignment-right-side
                                channel-assignment-mid-side } }
    { bits-per-sample integer }
    { number-type maybe{ frame-number-type-frame frame-number-type-sample } }
    { number integer }
    { crc integer } ;

TUPLE: frame-footer
    { crc integer } ;

:: read-sync-code ( bitstream -- ? )
    14 bitstream read-bit sync-code = ;

:: (decode-frame-header) ( bitstream -- )
    [
        bitstream read-sync-code [ sync-code-error ] unless
        1 bitstream read-bit drop
        1 bitstream read-bit drop
        4 bitstream read-bit integer>bit-array .
        4 bitstream read-bit integer>bit-array .

    ] with-big-endian ;

: decode-frame-header ( -- )
    [
        3 read bitstreams:<msb0-bit-reader> (decode-frame-header)
    ] with-big-endian ;

: decode-file ( filename -- )
    binary
    [
        read-flac-magic [ not-a-flac-file ] unless
        read-stream-info drop
        skip-metadata
        decode-frame-header
    ] with-file-reader ;
