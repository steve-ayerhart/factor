! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: endian sequences kernel classes.struct io io.binary io.files io.encodings io.encodings.string io.encodings.utf8 io.encodings.binary alien.c-types alien.endian math locals accessors prettyprint combinators pack  math.parser strings arrays io.streams.byte-array sequences.generalizations assocs splitting byte-arrays alien.syntax alien.enums io.encodings.ascii ;
QUALIFIED: bitstreams

IN: flac.metadata

ALIAS: read-bit bitstreams:read

CONSTANT: FLAC-MAGIC "fLaC"

ENUM: metadata-type
    metadata-stream-info
    metadata-padding
    metadata-application
    metadata-seek-table
    metadata-vorbis-comment
    metadata-cuesheet
    metadata-picture
    { metadata-invalid 127 } ;

ERROR: not-a-flac-file ;
ERROR: cuesheet-index-reserved-must-be-zero ;

TUPLE: metadata-block-header
    { last? boolean }
    { type maybe{ metadata-stream-info
                  metadata-padding
                  metadata-application
                  metadata-seek-table
                  metadata-vorbis-comment
                  metadata-cuesheet
                  metadata-picture
                  metadata-invalid } }
    { length integer } ;

TUPLE: stream-info
    { min-block-size integer }
    { max-block-size integer }
    { min-frame-size integer }
    { max-frame-size integer }
    { sample-rate integer }
    { channels integer }
    { bits-per-sample integer }
    { samples integer }
    { md5 string } ;

TUPLE: seek-table
    { seek-points array } ;
TUPLE: seek-point
    { sample-number integer }
    { offset integer }
    { total-samples } ;

TUPLE: vorbis-comment
    { vendor-string string }
    { comments assoc } ;

TUPLE: padding
    { length integer } ;

TUPLE: application
    { id string }
    { data byte-array } ;

ENUM: cuesheet-track-type audio non-audio ;

TUPLE: cuesheet-track
    { offset integer }
    { number number }
    { isrc string }
    { type integer }
    { pre-emphasis boolean }
    { indices array } ;
TUPLE: cuesheet-index
    { offset integer }
    { number integer } ;
TUPLE: cuesheet
    { catalog-number integer }
    { lead-in integer }
    { cd? boolean }
    { tracks array } ;

ENUM: picture-type
    other
    file-icon
    other-file-icon
    front-cover
    back-cover
    leaflet-page
    media
    lead-artist/performer/soloist
    artist/performer
    conductor
    band/orchestra
    composer
    lyricist/text-writer
    recording-location
    during-recording
    during-performance
    movie/video-screen-capture
    bright-coloured-fish
    illustration
    badn/artist-logotype
    publisher/studio-logotype ;

TUPLE: picture
    type
    { mime-type string }
    { description string }
    { width integer }
    { height integer }
    { depth integer }
    { colors integer }
    { data byte-array } ;

TUPLE: metadata
    { stream-info stream-info }
    { padding maybe{ padding } }
    { application maybe{ application } }
    { seek-table maybe{ seek-table } }
    { vorbis-comment maybe{ vorbis-comment } }
    { cuesheet maybe{ cuesheet } }
    { picture maybe{ picture } } ;

<PRIVATE

: read-flac-magic ( -- ? )
    4 read utf8 decode FLAC-MAGIC = ;

:: (decode-metadata-block-header) ( bitstream -- header )
    [
        1 bitstream read-bit 1 =
        7 bitstream read-bit <metadata-type>
        24 bitstream read-bit
    ] with-big-endian
    metadata-block-header boa ;

: decode-metadata-block-header ( byte-array -- header )
    bitstreams:<msb0-bit-reader> (decode-metadata-block-header) ;

: read-metadata-block-header ( -- header )
    4 read decode-metadata-block-header ;

:: (decode-stream-info) ( bitstream -- stream-info )
    [
        16 bitstream read-bit
        16 bitstream read-bit
        24 bitstream read-bit
        24 bitstream read-bit
        20 bitstream read-bit
        3 bitstream read-bit 1 +
        5 bitstream read-bit 1 +
        36 bitstream read-bit
        128 bitstream read-bit u128>byte-array bytes>hex-string
    ] with-big-endian
    stream-info boa ;

: decode-stream-info ( byte-array -- stream-info )
    bitstreams:<msb0-bit-reader> (decode-stream-info) ;

: decode-seek-table ( byte-array -- seek-table )
    dup
    binary
    [
        length 18 / <iota>
        [ drop 8 read be> 8 read be> 2 read be> seek-point boa ] map
    ] with-byte-reader
    seek-table boa ;

: decode-vorbis-comment ( byte-array -- comments )
    binary
    [
        4 read le> read utf8 decode
        4 read le> <iota> [
            drop
            4 read le> read utf8 decode
            "=" split
        ] map
    ] with-byte-reader >alist vorbis-comment boa ;

: encode-vorbis-string ( str -- byte-array )
    dup binary [ length 4 >le write utf8 encode write ] with-byte-writer ;

: encode-vorbis-comments ( assoc -- byte-array )
    dup binary [
        length 4 >le write
        [ 2array "=" join encode-vorbis-string write ] assoc-each
    ] with-byte-writer ;

: encode-vorbis-comment ( vorbis-comment -- byte-array )
    binary [
        [ vendor-string>> encode-vorbis-string write ]
        [ comments>> encode-vorbis-comments write ] bi
    ] with-byte-writer ;

: encode-padding ( padding -- byte-array )
    length>> <byte-array> ;

: decode-padding ( byte-array -- padding )
    length padding boa ;

: decode-application ( byte-array -- application )
    drop application new ;

: decode-cuesheet ( byte-array -- cuesheet )
    binary
    [
         128 read ascii decode
         8 read be>
         259 read drop f
         1 read be> <iota> [
             drop
             8 read be>
             1 read be>
             12 read ascii decode
             21 read drop 0 <cuesheet-track-type> t
             1 read <iota> [
                 drop
                 8 read be>
                 1 read be>
                 3 read be> = 0 [ cuesheet-index-reserved-must-be-zero ] unless
                 cuesheet-index boa
             ] map
             cuesheet-track boa
        ] map
    ] with-byte-reader cuesheet boa ;

: decode-picture ( byte-array -- picture )
    binary
    [
        4 read be> <picture-type>
        4 read be> read utf8 decode
        4 read be> read utf8 decode
        4 read be>
        4 read be>
        4 read be>
        4 read be>
        4 read be> read
    ] with-byte-reader picture boa ;

: decode-metadata-block ( metadata byte-array type -- metadata )
    {
        { metadata-stream-info [ decode-stream-info >>stream-info ] }
        { metadata-padding [ decode-padding >>padding ] }
        { metadata-application [ decode-application >>application ] }
        { metadata-seek-table [ decode-seek-table >>seek-table ] }
        { metadata-vorbis-comment [ decode-vorbis-comment >>vorbis-comment ] }
        { metadata-cuesheet [ decode-cuesheet >>cuesheet ] }
        { metadata-picture [ decode-picture >>picture ] }
    } case ;

PRIVATE>

: read-stream-info ( -- stream-info )
    read-metadata-block-header
    length>> read decode-stream-info ;

: skip-metadata ( -- )
    [
        read-metadata-block-header
        [ length>> read drop ] [ last?>> not ] bi
    ] loop ;

! TODO: handle other formats gracefully such as ID3
: read-metadata ( filename -- metadata )
    binary
    [
        read-flac-magic [ not-a-flac-file ] unless
        metadata new
        [
            read-metadata-block-header
            [ length>> read ] [ type>> ] [ last?>> not ] tri
            [ decode-metadata-block ] dip
        ] loop
    ] with-file-reader ;

: <flac-metadata> ( filename -- metadata )
    read-metadata ;
