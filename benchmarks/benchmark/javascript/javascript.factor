! Copyright (C) 2009 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: io.encodings.utf8 io.files kernel peg.javascript ;
in: benchmark.javascript

: javascript-benchmark ( -- )
    "vocab:benchmark/javascript/jquery-1.3.2.min.js"
    utf8 file-contents parse-javascript drop ;

main: javascript-benchmark