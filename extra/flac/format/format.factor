! Copyright (C) 2020 .
! See http://factorcode.org/license.txt for BSD license.
USING: alien.syntax math byte-arrays sequences ;

IN: flac.format

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

TUPLE: flac-subframe-header
    { subframe-type maybe{ subframe-type-constant
                           subframe-type-verbatim
                           subframe-type-fixed
                           subframe-type-lpc } }
    { order maybe{ integer } }
    { wasted-bits integer } ;

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
    { entropy-coding-method flac-entropy-coding-method }
    { warmup sequence }
    residual ;

TUPLE: flac-subframe-lpc
    { entropy-coding-method maybe{ entropy-coding-partioned-rice
                                   entropy-coding-partioned-rice2 } }
    { qlp-coeff-precision integer }
    { quantization-level integer }
    { qlp-coeff integer }
    { warmup integer }
    residual ;

TUPLE: flac-subframe
    { subframe-header flac-subframe-header }
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
