! Copyright (C) 2009 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: math sequences kernel ;
in: benchmark.gc1

: gc1-benchmark ( -- ) 600000 iota [ >bignum 1 + ] map drop ;

main: gc1-benchmark