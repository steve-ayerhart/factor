! Copyright (C) 2005, 2009 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs colors delegate delegate.protocols
destructors hashtables io io.streams.plain io.streams.string
kernel make namespaces present sequences sets splitting strings
strings.tables summary ;
IN: io.styles

GENERIC: stream-format ( str style stream -- )
GENERIC: make-span-stream ( style stream -- stream' )
GENERIC: make-block-stream ( style stream -- stream' )
GENERIC: make-cell-stream ( style stream -- stream' )
GENERIC: stream-write-table ( table-cells style stream -- )

PROTOCOL: formatted-output-stream-protocol
stream-format make-span-stream make-block-stream
make-cell-stream stream-write-table ;

: format ( str style -- ) output-stream get stream-format ;

: tabular-output ( style quot -- )
    swap [ { } make ] dip output-stream get stream-write-table ; inline

: with-row ( quot -- )
    { } make , ; inline

: with-cell ( quot -- )
    H{ } output-stream get make-cell-stream
    [ swap with-output-stream ] keep , ; inline

: write-cell ( str -- )
    [ write ] with-cell ; inline

: with-style ( style quot -- )
    swap dup assoc-empty? [
        drop call
    ] [
        output-stream get make-span-stream swap with-output-stream
    ] if ; inline

: with-nesting ( style quot -- )
    [ output-stream get make-block-stream ] dip
    with-output-stream ; inline

TUPLE: filter-writer stream ;

CONSULT: output-stream-protocol filter-writer stream>> ;

CONSULT: formatted-output-stream-protocol filter-writer stream>> ;

M: filter-writer stream-element-type stream>> stream-element-type ;

M: filter-writer dispose stream>> dispose ;

TUPLE: ignore-close-stream < filter-writer ;

M: ignore-close-stream dispose drop ;

C: <ignore-close-stream> ignore-close-stream

TUPLE: style-stream < filter-writer style ;
INSTANCE: style-stream output-stream

DEFER: inherit-style

: do-nested-style ( style style-stream -- style stream )
    [ style>> inherit-style ] [ stream>> ] bi ; inline

C: <style-stream> style-stream

M: style-stream stream-format
    do-nested-style stream-format ;

M: style-stream stream-write
    [ style>> ] [ stream>> ] bi stream-format ;

M: style-stream stream-write1
    [ 1string ] dip stream-write ;

M: style-stream make-span-stream
    do-nested-style make-span-stream ;

M: style-stream make-block-stream
    do-nested-style make-block-stream ;

M: style-stream make-cell-stream
    do-nested-style make-cell-stream ;

M: style-stream stream-write-table
    do-nested-style stream-write-table ;

M: plain-writer stream-format
    nip stream-write ;

M: plain-writer make-span-stream
    swap <style-stream> <ignore-close-stream> ;

M: plain-writer make-block-stream
    nip <ignore-close-stream> ;

M: plain-writer stream-write-table
    [
        drop
        [ [ >string ] map ] map format-table
        [ nl ] [ write ] interleave
    ] with-output-stream* ;

M: plain-writer make-cell-stream 2drop <string-writer> ;

! Font styles
SYMBOL: plain
SYMBOL: bold
SYMBOL: italic
SYMBOL: bold-italic

! Character styles
SYMBOL: foreground
SYMBOL: background
SYMBOL: font-name
SYMBOL: font-size
SYMBOL: font-style

! Presentation
SYMBOL: presented

! Link
SYMBOL: href

! Image
SYMBOL: image-style

! Paragraph styles
SYMBOL: page-color
SYMBOL: border-color
SYMBOL: inset
SYMBOL: wrap-margin

! Table styles
SYMBOL: table-gap
SYMBOL: table-border

CONSTANT: standard-table-style
    H{
        { table-gap { 5 5 } }
        { table-border T{ rgba f 0.8 0.8 0.8 1.0 } }
    }

<PRIVATE

: inherit? ( format -- ? )
    HS{
        foreground background font-name font-size font-style
    } in? ;

PRIVATE>

: inherit-style ( child parent -- child' )
    [ drop inherit? ] assoc-filter swap assoc-union! ;

! Input history
TUPLE: input string ;

C: <input> input

M: input present string>> ;

M: input summary
    [
        "Input: " %
        string>> "\n" split1
        [ % ] [ "..." "" ? % ] bi*
    ] "" make ;

: write-object ( str obj -- ) presented associate format ;

: write-image ( image -- ) [ "" ] dip image-style associate format ;
