USING: io.files io.sockets io kernel threads
namespaces tools.test continuations strings byte-arrays
sequences prettyprint system io.encodings.binary io.encodings.ascii ;
IN: temporary

! Unix domain stream sockets
[
    [
        "unix-domain-socket-test" temp-file delete-file
    ] ignore-errors

    "unix-domain-socket-test" temp-file <local>
    ascii <server> [
        accept [
            "Hello world" print flush
            readln "XYZ" = "FOO" "BAR" ? print flush
        ] with-stream
    ] with-disposal

    "unix-domain-socket-test" temp-file delete-file
] "Test" spawn drop

yield

[ { "Hello world" "FOO" } ] [
    [
        "unix-domain-socket-test" temp-file <local>
        ascii <client> [
            readln ,
            "XYZ" print flush
            readln ,
        ] with-stream
    ] { } make
] unit-test

! Unix domain datagram sockets
[
    "unix-domain-datagram-test" temp-file delete-file
] ignore-errors

: server-addr "unix-domain-datagram-test" temp-file <local> ;
: client-addr "unix-domain-datagram-test-2" temp-file <local> ;

[
    [
        server-addr <datagram> "d" set

        "Receive 1" print

        "d" get receive >r reverse r>
        
        "Send 1" print
        dup .

        "d" get send

        "Receive 2" print

        "d" get receive >r " world" append r>
        
        "Send 1" print
        dup .

         "d" get send

        "d" get dispose

        "Done" print

        "unix-domain-datagram-test" temp-file delete-file
    ] with-scope
] "Test" spawn drop

yield

[
    "unix-domain-datagram-test-2" temp-file delete-file
] ignore-errors

client-addr <datagram>
"Four" print
"d" set

[ ] [
    "hello" >byte-array
    server-addr
    "d" get send
] unit-test

[ "olleh" t ] [
    "d" get receive
    server-addr =
    >r >string r>
] unit-test

[ ] [
    "hello" >byte-array
    server-addr
    "d" get send
] unit-test

[ "hello world" t ] [
    "d" get receive
    server-addr =
    >r >string r>
] unit-test

[ ] [ "d" get dispose ] unit-test

! Test error behavior

[
    "unix-domain-datagram-test-3" temp-file delete-file
] ignore-errors

"unix-domain-datagram-test-2" temp-file delete-file

[ ] [ client-addr <datagram> "d" set ] unit-test

[
    B{ 1 2 3 } "unix-domain-datagram-test-3" <local> "d" get send
] must-fail

[ ] [ "d" get dispose ] unit-test

! See what happens on send/receive after close

[ "d" get receive ] must-fail

[ B{ 1 2 } server-addr "d" get send ] must-fail

! Invalid parameter tests

[
    image binary [ stdio get accept ] with-file-reader
] must-fail

[
    image binary [ stdio get receive ] with-file-reader
] must-fail

[
    image binary [
        B{ 1 2 } server-addr
        stdio get send
    ] with-file-reader
] must-fail
