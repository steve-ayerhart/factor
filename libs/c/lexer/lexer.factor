! Copyright (C) 2009 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors combinators combinators.short-circuit
generalizations kernel locals math.order math.ranges
sequences.parser sequences sequences.generalizations
sorting.functor sorting.slots unicode ;
in: c.lexer

: take-c-comment ( sequence-parser -- seq/f )
    [
        dup "/*" take-sequence [
            "*/" take-until-sequence*
        ] [
            drop f
        ] if
    ] with-sequence-parser ;

: take-c++-comment ( sequence-parser -- seq/f )
    [
        dup "//" take-sequence [
            [
                [
                    { [ current char: \n = ] [ sequence-parse-end? ] } 1||
                ] take-until
            ] [
                advance drop
            ] bi
        ] [
            drop f
        ] if
    ] with-sequence-parser ;

: skip-whitespace/comments ( sequence-parser -- sequence-parser )
    skip-whitespace-eol
    {
        { [ dup take-c-comment ] [ skip-whitespace/comments ] }
        { [ dup take-c++-comment ] [ skip-whitespace/comments ] }
        [ ]
    } cond ;

: take-define-identifier ( sequence-parser -- string )
    skip-whitespace/comments
    [ current { [ blank? ] [ char: \( = ] } 1|| ] take-until ;

:: take-quoted-string ( sequence-parser escape-char quote-char -- string )
    sequence-parser n>> :> start-n
    sequence-parser advance
    [
        {
            [ { [ previous escape-char = ] [ current quote-char = ] } 1&& ]
            [ current quote-char = not ]
        } 1||
    ] take-while :> string
    sequence-parser current quote-char = [
        sequence-parser advance* string
    ] [
        start-n sequence-parser n<< f
    ] if ;

: (take-token) ( sequence-parser -- string )
    skip-whitespace [ current { [ blank? ] [ f = ] } 1|| ] take-until ;

:: take-token* ( sequence-parser escape-char quote-char -- string/f )
    sequence-parser skip-whitespace
    dup current {
        { quote-char [ escape-char quote-char take-quoted-string ] }
        { f [ drop f ] }
        [ drop (take-token) ]
    } case ;

: take-token ( sequence-parser -- string/f )
    char: \ char: " take-token* ;

: c-identifier-begin? ( ch -- ? )
    char: a char: z [a,b]
    char: A char: Z [a,b]
    { char: _ } 3append member? ;

: c-identifier-ch? ( ch -- ? )
    char: a char: z [a,b]
    char: A char: Z [a,b]
    char: 0 char: 9 [a,b]
    { char: _ } 4 nappend member? ;

: (take-c-identifier) ( sequence-parser -- string/f )
    dup current c-identifier-begin? [
        [ current c-identifier-ch? ] take-while
    ] [
        drop f
    ] if ;

: take-c-identifier ( sequence-parser -- string/f )
    [ (take-c-identifier) ] with-sequence-parser ;

<< "length" [ length ] define-sorting >>

: sort-tokens ( seq -- seq' )
    { length>=< <=> } sort-by ;

: take-c-integer ( sequence-parser -- string/f )
    [
        dup take-integer [
            swap
            { "ull" "uLL" "Ull" "ULL" "ll" "LL" "l" "L" "u" "U" }
            take-longest [ append ] when*
        ] [
            drop f
        ] if*
    ] with-sequence-parser ;

CONSTANT: c-punctuators
    {
        "[" "]" "(" ")" "{" "}" "." "->"
        "++" "--" "&" "*" "+" "-" "~" "!"
        "/" "%" "<<" ">>" "<" ">" "<=" ">=" "==" "!=" "^" "|" "&&" "||"
        "?" ":" ";" "..."
        "=" "*=" "/=" "%=" "+=" "-=" "<<=" ">>=" "&=" "^=" "|="
        "," "#" "##"
        "<:" ":>" "<%" "%>" "%:" "%:%:"
    } ;

: take-c-punctuator ( sequence-parser -- string/f )
    c-punctuators take-longest ;
