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

: read-metadata-block-stream-info ( -- stream-info )
    16 flac-read-uint
    16 flac-read-uint
    24 flac-read-uint
    24 flac-read-uint
    20 flac-read-uint
    3 flac-read-uint 1 +
    5 flac-read-uint 1 +
    36 flac-read-uint
    128 flac-read-uint 16 >be bytes>hex-string
    stream-info boa ;

: read-metadata-block-seek-table ( length -- seek-table )
    18 / <iota> [
        drop 64 flac-read-uint 64 flac-read-uint 16 flac-read-uint seek-point boa
    ] map seek-table boa ;

: read-metadata-block-vorbis-comment ( length -- vorbis-comment )
    dup [ 8 * flac-read-uint ] dip >be
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

: read-metadata-block-padding ( length -- padding )
    dup 8 * flac-read-uint drop flac-padding boa ;

: read-metadata-block-application ( length -- application )
    8 * flac-read-uint drop application new ;

: read-metadata-block-cuesheet ( length -- cuesheet )
    dup [ 8 * flac-read-uint ] dip >be
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

: read-metadata-block-picture ( length -- picture )
    dup [ 8 * flac-read-uint ] dip >be
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

: read-metadata-block ( metadata length type -- metadata )
    [
        {
            { metadata-stream-info [ drop read-metadata-block-stream-info >>stream-info ] }
            { metadata-padding [ read-metadata-block-padding >>padding ] }
            { metadata-application [ read-metadata-block-application >>application ] }
            { metadata-seek-table [ read-metadata-block-seek-table >>seek-table ] }
            { metadata-vorbis-comment [ read-metadata-block-vorbis-comment >>vorbis-comment ] }
            { metadata-cuesheet [ read-metadata-block-cuesheet >>cuesheet ] }
            { metadata-picture [ read-metadata-block-picture >>picture ] }
        } case
    ] with-big-endian ;

: read-flac-metadata ( -- metadata )
    32 flac-read-uint FLAC-MAGIC = [ not-a-flac-file ] unless
    metadata new
    [
        read-metadata-block-header
        [ length>> ] [ type>> ] [ last?>> not ] tri
        [ read-metadata-block ] dip
    ] loop ;
