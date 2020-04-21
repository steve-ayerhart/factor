! Copyright (C) 2009 Daniel Ehrenberg
! See http://factorcode.org/license.txt for BSD license.
USING: kernel system destructors accessors io.streams.duplex ;

IN: flac.bitstream

TUPLE: flac-bitstream < disposable
    stream ;

HOOK: open-flac-bitstream os ( flac-bitstream -- flac-bitstream' )

M: flac-bitstream dispose* ( flac-bitstream -- ) stream>> dispose ;

: <flac-bitstream> ( path -- flac-bitstream )
    flac-bitstream new
    swap >>path ;

: with-flac-bitstream ( flac-bitstream quot -- )
    [ open-flac-bitstream ] dip with-stream ; inline
