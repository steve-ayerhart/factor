! :folding=indent:collapseFolds=1:

! $Id$
!
! Copyright (C) 2004 Slava Pestov.
! 
! Redistribution and use in source and binary forms, with or without
! modification, are permitted provided that the following conditions are met:
! 
! 1. Redistributions of source code must retain the above copyright notice,
!    this list of conditions and the following disclaimer.
! 
! 2. Redistributions in binary form must reproduce the above copyright notice,
!    this list of conditions and the following disclaimer in the documentation
!    and/or other materials provided with the distribution.
! 
! THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
! INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
! FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
! DEVELOPERS AND CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
! SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
! PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
! OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
! WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
! OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
! ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

IN: httpd-responder

USE: combinators
USE: kernel
USE: lists
USE: logging
USE: namespaces
USE: stdio
USE: stack
USE: streams
USE: strings

USE: httpd

: <responder> ( -- responder )
    <namespace> [
        ( url -- )
        [
            drop "GET method not implemented" httpd-error
        ] "get" set

        ( url -- )
        [
            drop "POST method not implemented" httpd-error
        ] "post" set
    ] extend ;

: serving-html ( -- )
    "200 Document follows" "text/html" response print ;

: serving-text ( -- )
    "200 Document follows" "text/plain" response print ;

: redirect ( to -- )
    "301 Moved Permanently" "text/plain" response write
    "Location: " write print ;

: get-responder ( name -- responder )
    "httpd-responders" get get* ;

: responder-argument ( argument -- argument )
    dup f-or-"" [ drop "default-argument" get ] when ;

: call-responder ( method argument responder -- )
    [
        over [ responder-argument swap get call ] with-request
    ] bind ;

: no-such-responder ( name -- )
    "404 no such responder: " swap cat2 httpd-error ;

: trim-/ ( url -- url )
    #! Trim a leading /, if there is one.
    dup "/" str-head? dup [ nip ] [ drop ] ifte ;

: log-responder ( argument -- )
    "Calling responder " swap cat2 log ;

: serve-responder ( argument method -- )
    swap
    dup log-responder
    trim-/ "/" split1 dup [
        over get-responder dup [
            rot drop call-responder
        ] [
            2drop no-such-responder drop
        ] ifte
    ] [
        ! Argument is just a responder name without /
        drop "/" swap "/" cat3 redirect drop
    ] ifte ;
