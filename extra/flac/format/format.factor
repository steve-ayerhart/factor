! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: alien.syntax math byte-arrays sequences kernel strings arrays assocs ;

IN: flac.format

CONSTANT: FLAC-MAGIC 0x664c6143 ! fLaC
CONSTANT: sync-code 0b11111111111110

CONSTANT: MIN-BLOCK-SIZE 16
CONSTANT: MAX-BLOCK-SIZE 65535
CONSTANT: MAX-SAMPLE-SIZE: 4608
CONSTANT: MAX-CHANNELS 8
CONSTANT: MIN-BITS-PER-SAMPLE 4
CONSTANT: MAX-BITS-PER-SAMPLE 32 ! The value is ((2^16) - 1) * 10
CONSTANT: MAX-LPC-ORDER 32
CONSTANT: MAX-LPC-ORDER-48000HZ 12
CONSTANT: MIN-QLP-COEFF-PRECISION 5
CONSTANT: MAX-QLP-COEEF-PRECISION 15
CONSTANT: MAX-FIXED-ORDER 4
CONSTANT: MAX-RICE-PARTITION-ORDER 15

ERROR: not-a-flac-file ;
ERROR: sync-code-error ;
ERROR: invalid-channel-assignment ;
ERROR: reserved-block-size ;
ERROR: invalid-sample-rate ;
ERROR: reserved-subframe-type ;
ERROR: invalid-subframe-sync ;

ENUM: flac-frame-number-type
    frame-number-type-frame
    frame-number-type-sample ;

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

TUPLE: flac-frame-header
    { number-type maybe{ frame-number-type-frame frame-number-type-sample } }
    { blocksize integer }
    { sample-rate integer }
    { channels integer }
    { channel-assignment
      maybe{ channels-mono
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

ENUM: flac-subframe-type
    subframe-type-constant
    subframe-type-verbatim
    subframe-type-fixed
    subframe-type-lpc ;

ENUM: flac-entropy-coding-method-type
    entropy-coding-partioned-rice
    entropy-coding-partioned-rice2 ;

TUPLE: flac-entropy-coding-method-partioned-rice-contents
    { parameters integer }
    { raw-bits integer }
    { capacity-by-order integer } ;

TUPLE: flac-entropy-coding-method-partioned-rice
    { order integer }
    { contents flac-entropy-coding-method-partioned-rice-contents } ;

TUPLE: flac-entropy-coding-method
    { type maybe{ entropy-coding-partioned-rice
                  entropy-coding-partioned-rice2 } }
    { data flac-entropy-coding-method-partioned-rice } ;

TUPLE: flac-subframe-constant
    { value integer } ;

TUPLE: flac-subframe-verbatim
    { data byte-array } ;

TUPLE: flac-subframe-fixed
    { warmup sequence }
    { entropy-coding-method flac-entropy-coding-method }
    residual ;

TUPLE: flac-subframe-lpc
    { entropy-coding-method maybe{ entropy-coding-partioned-rice
                                   entropy-coding-partioned-rice2 } }
    { qlp-coeff-precision integer }
    { quantization-level integer }
    { qlp-coeff integer }
    { warmup integer }
    residual ;

TUPLE: flac-subframe-header
    { subframe-type maybe{ subframe-type-constant
                           subframe-type-verbatim
                           subframe-type-fixed
                           subframe-type-lpc } }
    { pre-order maybe{ integer } }
    { wasted-bits integer } ;

TUPLE: flac-subframe
    { header flac-subframe-header }
    { data maybe{ flac-subframe-constant
                  flac-subframe-verbatim
                  flac-subframe-fixed
                  flac-subframe-lpc } } ;

TUPLE: flac-frame-footer
    { crc integer } ;

TUPLE: flac-frame
    { header flac-frame-header }
    { subframes sequence }
    { footer flac-frame-footer } ;

ENUM: metadata-type
    metadata-stream-info
    metadata-padding
    metadata-application
    metadata-seek-table
    metadata-vorbis-comment
    metadata-cuesheet
    metadata-picture
    { metadata-invalid 127 } ;


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

TUPLE: flac-padding
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
    { padding maybe{ flac-padding } }
    { application maybe{ application } }
    { seek-table maybe{ seek-table } }
    { vorbis-comment maybe{ vorbis-comment } }
    { cuesheet maybe{ cuesheet } }
    { picture maybe{ picture } } ;
