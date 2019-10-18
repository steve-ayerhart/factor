USE: strings
USE: kernel
USE: math
USE: test
USE: lists
USE: namespaces
USE: compiler

! http://inferno.bell-labs.com/cm/cs/who/bwk/interps/pap.html

: string-step ( n str -- )
    2dup string-length > [
        dup [ "123" , , "456" , , "789" , ] make-string
        dup dup string-length 2 /i 0 swap rot substring
        swap dup string-length 2 /i 1 + 1 swap rot substring cat2
        string-step
    ] [
        2drop
    ] ifte ; compiled

: string-benchmark ( n -- )
    "abcdef" 10 [ 2dup string-step ] times 2drop ; compiled

[ ] [ 400000 string-benchmark ] unit-test