! Copyright (C) 2007, 2008 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors qualified io.streams.c init fry namespaces make
assocs kernel parser lexer strings.parser tools.deploy.config
vocabs sequences words words.private memory kernel.private
continuations io prettyprint vocabs.loader debugger system
strings sets vectors quotations byte-arrays sorting ;
QUALIFIED: bootstrap.stage2
QUALIFIED: classes
QUALIFIED: command-line
QUALIFIED: compiler.errors.private
QUALIFIED: compiler.units
QUALIFIED: continuations
QUALIFIED: definitions
QUALIFIED: init
QUALIFIED: io.backend
QUALIFIED: io.thread
QUALIFIED: layouts
QUALIFIED: listener
QUALIFIED: prettyprint.config
QUALIFIED: source-files
QUALIFIED: vocabs
IN: tools.deploy.shaker

! This file is some hairy shit.

: strip-init-hooks ( -- )
    "Stripping startup hooks" show
    "cpu.x86" init-hooks get delete-at
    "command-line" init-hooks get delete-at
    "libc" init-hooks get delete-at
    "system" init-hooks get delete-at
    deploy-threads? get [
        "threads" init-hooks get delete-at
    ] unless
    native-io? [
        "io.thread" init-hooks get delete-at
    ] unless
    strip-io? [
        "io.files" init-hooks get delete-at
        "io.backend" init-hooks get delete-at
    ] when
    strip-dictionary? [
        "compiler.units" init-hooks get delete-at
        "tools.vocabs" init-hooks get delete-at
    ] when ;

: strip-debugger ( -- )
    strip-debugger? [
        "Stripping debugger" show
        "resource:basis/tools/deploy/shaker/strip-debugger.factor"
        run-file
    ] when ;

: strip-libc ( -- )
    "libc" vocab [
        "Stripping manual memory management debug code" show
        "resource:basis/tools/deploy/shaker/strip-libc.factor"
        run-file
    ] when ;

: strip-cocoa ( -- )
    "cocoa" vocab [
        "Stripping unused Cocoa methods" show
        "resource:basis/tools/deploy/shaker/strip-cocoa.factor"
        run-file
    ] when ;

: strip-word-names ( words -- )
    "Stripping word names" show
    [ f >>name f >>vocabulary drop ] each ;

: strip-word-defs ( words -- )
    "Stripping symbolic word definitions" show
    [ "no-def-strip" word-prop not ] filter
    [ [ ] >>def drop ] each ;

: sift-assoc ( assoc -- assoc' ) [ nip ] assoc-filter ;

: strip-word-props ( stripped-props words -- )
    "Stripping word properties" show
    [
        swap '[
            [
                [ drop _ member? not ] assoc-filter sift-assoc
                >alist f like
            ] change-props drop
        ] each
    ] [
        "Remaining word properties:" print
        [ props>> keys ] gather .
    ] [
        H{ } clone '[
            [ [ _ [ ] cache ] map ] change-props drop
        ] each
    ] tri ;

: stripped-word-props ( -- seq )
    [
        strip-dictionary? deploy-compiler? get and [
            {
                "combination"
                "members"
                "methods"
            } %
        ] when

        strip-dictionary? [
            {
                "alias"
                "boa-check"
                "cannot-infer"
                "coercer"
                "compiled-effect"
                "compiled-generic-uses"
                "compiled-uses"
                "constraints"
                "custom-inlining"
                "declared-effect"
                "default"
                "default-method"
                "default-output-classes"
                "derived-from"
                "engines"
                "forgotten"
                "identities"
                "if-intrinsics"
                "infer"
                "inferred-effect"
                "inline"
                "inlined-block"
                "input-classes"
                "interval"
                "intrinsics"
                "lambda"
                "loc"
                "local-reader"
                "local-reader?"
                "local-writer"
                "local-writer?"
                "local?"
                "macro"
                "memo-quot"
                "mixin"
                "method-class"
                "method-generic"
                "modular-arithmetic"
                "no-compile"
                "optimizer-hooks"
                "outputs"
                "participants"
                "predicate"
                "predicate-definition"
                "predicating"
                "primitive"
                "reader"
                "reading"
                "recursive"
                "register"
                "register-size"
                "shuffle"
                "slot-names"
                "slots"
                "special"
                "specializer"
                "step-into"
                "step-into?"
                "transform-n"
                "transform-quot"
                "tuple-dispatch-generic"
                "type"
                "writer"
                "writing"
            } %
        ] when
        
        strip-prettyprint? [
            {
                "break-before"
                "break-after"
                "delimiter"
                "flushable"
                "foldable"
                "inline"
                "lambda"
                "macro"
                "memo-quot"
                "parsing"
                "word-style"
            } %
        ] when
    ] { } make ;

: strip-words ( props -- )
    [ word? ] instances
    deploy-word-props? get [ 2dup strip-word-props ] unless
    deploy-word-defs? get [ dup strip-word-defs ] unless
    strip-word-names? [ dup strip-word-names ] when
    2drop ;

: strip-recompile-hook ( -- )
    [ [ f ] { } map>assoc ]
    compiler.units:recompile-hook
    set-global ;

: strip-vocab-globals ( except names -- words )
    [ child-vocabs [ words ] map concat ] map concat swap diff ;

: stripped-globals ( -- seq )
    [
        "callbacks" "alien.compiler" lookup ,

        "inspector-hook" "inspector" lookup ,

        {
            bootstrap.stage2:bootstrap-time
            continuations:error
            continuations:error-continuation
            continuations:error-thread
            continuations:restarts
            listener:error-hook
            init:init-hooks
            io.thread:io-thread
            source-files:source-files
            input-stream
            output-stream
            error-stream
        } %

        "mallocs" "libc.private" lookup ,

        deploy-threads? [
            "initial-thread" "threads" lookup ,
        ] unless

        strip-io? [ io.backend:io-backend , ] when

        { } {
            "alarms"
            "tools"
            "io.launcher"
            "random"
        } strip-vocab-globals %

        strip-dictionary? [
            "libraries" "alien" lookup ,

            { } { "cpu" } strip-vocab-globals %

            {
                gensym
                name>char-hook
                classes:class-and-cache
                classes:class-not-cache
                classes:class-or-cache
                classes:class<=-cache
                classes:classes-intersect-cache
                classes:implementors-map
                classes:update-map
                command-line:main-vocab-hook
                compiled-crossref
                compiled-generic-crossref
                compiler.units:recompile-hook
                compiler.units:update-tuples-hook
                compiler.units:definition-observers
                definitions:crossref
                interactive-vocabs
                layouts:num-tags
                layouts:num-types
                layouts:tag-mask
                layouts:tag-numbers
                layouts:type-numbers
                lexer-factory
                listener:listener-hook
                root-cache
                vocab-roots
                vocabs:dictionary
                vocabs:load-vocab-hook
                word
                parser-notes
            } %

            { } { "math.partial-dispatch" } strip-vocab-globals %
            
            "peg-cache" "peg" lookup ,
        ] when

        strip-prettyprint? [
            {
                prettyprint.config:margin
                prettyprint.config:string-limit?
                prettyprint.config:boa-tuples?
                prettyprint.config:tab-size
            } %
        ] when

        strip-debugger? [
            {
                compiler.errors.private:compiler-errors
                continuations:thread-error-hook
            } %
        ] when

        deploy-c-types? get [
            "c-types" "alien.c-types" lookup ,
        ] unless

        deploy-ui? get [
            "ui-error-hook" "ui.gadgets.worlds" lookup ,
        ] when

        "<value>" "stack-checker.state" lookup [ , ] when*

        "windows-messages" "windows.messages" lookup [ , ] when*

    ] { } make ;

: strip-globals ( stripped-globals -- )
    strip-globals? [
        "Stripping globals" show
        global swap
        '[ drop _ member? not ] assoc-filter
        [ drop string? not ] assoc-filter ! strip CLI args
        sift-assoc
        dup keys unparse show
        21 setenv
    ] [ drop ] if ;

: compress ( pred string -- )
    "Compressing " prepend show
    instances
    dup H{ } clone [ [ ] cache ] curry map
    become ; inline

: compress-byte-arrays ( -- )
    [ byte-array? ] "byte arrays" compress ;

: compress-quotations ( -- )
    [ quotation? ] "quotations" compress ;

: compress-strings ( -- )
    [ string? ] "strings" compress ;

: finish-deploy ( final-image -- )
    "Finishing up" show
    >r { } set-datastack r>
    { } set-retainstack
    V{ } set-namestack
    V{ } set-catchstack
    "Saving final image" show
    [ save-image-and-exit ] call-clear ;

SYMBOL: deploy-vocab

: set-boot-quot* ( word -- )
    [
        \ boot ,
        init-hooks get values concat %
        ,
        strip-io? [ \ flush , ] unless
    ] [ ] make "Boot quotation: " write dup . flush
    set-boot-quot ;

: strip ( -- )
    strip-libc
    strip-cocoa
    strip-debugger
    strip-recompile-hook
    strip-init-hooks
    deploy-vocab get vocab-main set-boot-quot*
    stripped-word-props >r
    stripped-globals strip-globals
    r> strip-words
    compress-byte-arrays
    compress-quotations
    compress-strings
    H{ } clone classes:next-method-quot-cache set-global ;

: (deploy) ( final-image vocab config -- )
    #! Does the actual work of a deployment in the slave
    #! stage2 image
    [
        [
            deploy-vocab set
            deploy-vocab get require
            strip
            finish-deploy
        ] [
            print-error flush 1 exit
        ] recover
    ] bind ;

: do-deploy ( -- )
    "output-image" get
    "deploy-vocab" get
    "Deploying " write dup write "..." print
    dup deploy-config dup .
    (deploy) ;

MAIN: do-deploy
