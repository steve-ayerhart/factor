! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: endian sequences kernel classes.struct io.binary io.files io.encodings io.encodings.string io.encodings.utf8 io.encodings.binary alien.c-types alien.endian math locals accessors prettyprint combinators math.parser strings arrays io.streams.byte-array sequences.generalizations assocs splitting byte-arrays alien.syntax alien.enums io.encodings.ascii ;
USING: flac.bitstream flac.format ;

QUALIFIED: bitstreams
QUALIFIED: io

IN: flac.metadata

ERROR: cuesheet-index-reserved-must-be-zero ;

: read-metadata-block-header ( -- header )
    1 flac-read-uint 1 =
    7 flac-read-uint <metadata-type>
    24 flac-read-uint
    metadata-block-header boa ;

:: (decode-stream-info) ( bs -- stream-info )
    16 bs bitstreams:read
    16 bs bitstreams:read
    24 bs bitstreams:read
    24 bs bitstreams:read
    20 bs bitstreams:read
    3 bs bitstreams:read 1 +
    5 bs bitstreams:read 1 +
    36 bs bitstreams:read
    128 bs bitstreams:read 16 >be bytes>hex-string
    stream-info boa ;

: decode-stream-info ( byte-array -- stream-info )
    bitstreams:<msb0-bit-reader> (decode-stream-info) ;

: decode-seek-table ( byte-array -- seek-table )
    dup
    binary
    [
        length 18 / <iota>
        [ drop 8 io:read be> 8 io:read be> 2 io:read be> seek-point boa ] map
    ] with-byte-reader
    seek-table boa ;

: decode-vorbis-comment ( byte-array -- comments )
    binary
    [
        4 io:read le> io:read utf8 decode
        4 io:read le> <iota> [
            drop
            4 io:read le> io:read utf8 decode
            "=" split
        ] map
    ] with-byte-reader >alist vorbis-comment boa ;

: encode-vorbis-string ( str -- byte-array )
    dup binary [ length 4 >le io:write utf8 encode io:write ] with-byte-writer ;

: encode-vorbis-comments ( assoc -- byte-array )
    dup binary [
        length 4 >le io:write
        [ 2array "=" join encode-vorbis-string io:write ] assoc-each
    ] with-byte-writer ;

: encode-vorbis-comment ( vorbis-comment -- byte-array )
    binary [
        [ vendor-string>> encode-vorbis-string io:write ]
        [ comments>> encode-vorbis-comments io:write ] bi
    ] with-byte-writer ;

: encode-padding ( padding -- byte-array )
    length>> <byte-array> ;

: decode-padding ( byte-array -- padding )
    length flac-padding boa ;

: decode-application ( byte-array -- application )
    drop application new ;

: decode-cuesheet ( byte-array -- cuesheet )
    binary
    [
        128 io:read ascii decode
        8 io:read be>
        259 io:read drop f
        1 io:read be> <iota> [
            drop
            8 io:read be>
            1 io:read be>
            12 io:read ascii decode
            21 io:read drop 0 <cuesheet-track-type> t
            1 io:read <iota> [
                drop
                8 io:read be>
                1 io:read be>
                3 io:read be> = 0 [ cuesheet-index-reserved-must-be-zero ] unless
                cuesheet-index boa
            ] map
            cuesheet-track boa
        ] map
    ] with-byte-reader cuesheet boa ;

: decode-picture ( byte-array -- picture )
    binary
    [
        4 io:read be> <picture-type>
        4 io:read be> io:read utf8 decode
        4 io:read be> io:read utf8 decode
        4 io:read be>
        4 io:read be>
        4 io:read be>
        4 io:read be>
        4 io:read be> io:read
    ] with-byte-reader picture boa ;

: decode-metadata-block ( metadata byte-array type -- metadata )
    [
        {
            { metadata-stream-info [ decode-stream-info >>stream-info ] }
            { metadata-padding [ decode-padding >>padding ] }
            { metadata-application [ decode-application >>application ] }
            { metadata-seek-table [ decode-seek-table >>seek-table ] }
            { metadata-vorbis-comment [ decode-vorbis-comment >>vorbis-comment ] }
            { metadata-cuesheet [ decode-cuesheet >>cuesheet ] }
            { metadata-picture [ decode-picture >>picture ] }
        } case
    ] with-big-endian ;

: read-flac-metadata ( -- metadata )
    32 flac-read-uint FLAC-MAGIC = [ not-a-flac-file ] unless
    metadata new
    "HI" .
    [
        "HI" .
        read-metadata-block-header
        [ length>> io:read ] [ type>> ] [ last?>> not ] tri
        [ decode-metadata-block ] dip
    ] loop ;
!     metadata new
!     [
!         read-metadata-block-header
!         [ length>> io:read ] [ type>> ] [ last?>> not ] tri
!         [ decode-metadata-block ] dip
!     ] loop ;
