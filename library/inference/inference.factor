! Copyright (C) 2004, 2005 Slava Pestov.
! See http://factor.sf.net/license.txt for BSD license.
IN: inference
USING: errors generic interpreter io kernel lists math
namespaces prettyprint sequences strings unparser vectors words ;

! This variable takes a boolean value.
SYMBOL: inferring-base-case

TUPLE: inference-error message rstate data-stack call-stack ;

: inference-error ( msg -- )
    recursive-state get meta-d get meta-r get
    <inference-error> throw ;

M: inference-error error. ( error -- )
    "! Inference error:" print
    dup inference-error-message print
    "! Recursive state:" print
    inference-error-rstate [.] ;

TUPLE: value recursion safe? ;

C: value ( -- value )
    t over set-value-safe?
    recursive-state get over set-value-recursion ;

M: value = eq? ;

TUPLE: computed ;

C: computed ( -- value ) <value> over set-delegate ;

TUPLE: literal value ;

C: literal ( obj -- value )
    <value> over set-delegate
    [ set-literal-value ] keep ;

M: value literal-value ( value -- )
    {
        "A literal value was expected where a computed value was found.\n"
        "This means that an attempt was made to compile a word that\n"
        "applies 'call' or 'execute' to a value that is not known\n"
        "at compile time. The value might become known if the word\n"
        "is marked 'inline'. See the handbook for details."
    } concat inference-error ;

TUPLE: meet values ;

C: meet ( values -- value )
    <value> over set-delegate [ set-meet-values ] keep ;

PREDICATE: tuple safe-literal ( obj -- ? )
    dup literal? [ value-safe? ] [ drop f ] ifte ;

DEFER: subst-value

: (subst-value) ( new old value -- value )
    dup meet? [
        [ meet-values subst-value ] keep
    ] [
        tuck eq? [ drop ] [ nip ] ifte
    ] ifte ;

: subst-value ( new old seq -- )
    [ >r 2dup r> (subst-value) ] nmap 2drop ;

: (subst-values) ( newseq oldseq seq -- )
    #! Mutates seq.
    -rot [ pick subst-value ] 2each drop ;

: subst-values ( new old node -- )
    #! Mutates the node.
    [
        3dup node-in-d  (subst-values)
        3dup node-in-r  (subst-values)
        3dup node-out-d (subst-values)
        3dup node-out-r (subst-values)
        drop
    ] each-node 2drop ;

! Word properties that affect inference:
! - infer-effect -- must be set. controls number of inputs
! expected, and number of outputs produced.
! - infer - quotation with custom inference behavior; ifte uses
! this. Word is passed on the stack.

! Vector of results we had to add to the datastack. Ie, the
! inputs.
SYMBOL: d-in

: pop-literal ( -- rstate obj )
    1 #drop node, pop-d dup value-recursion swap literal-value ;

: computed-value-vector ( n -- vector )
    empty-vector dup [ drop <computed> ] nmap ;

: required-inputs ( n stack -- values )
    length - 0 max computed-value-vector ;

: ensure-d ( typelist -- )
    length meta-d get required-inputs dup
    meta-d [ append ] change
    d-in [ append ] change ;

: hairy-node ( node effect quot -- )
    over car ensure-d
    -rot 2dup car length 0 rot node-inputs
    2slip
    second length 0 rot node-outputs ; inline

: effect ( -- [[ in# out# ]] )
    #! After inference is finished, collect information.
    d-in get length object <repeated> >list
    meta-d get length object <repeated> >list 2list ;

: init-inference ( recursive-state -- )
    init-interpreter
    0 <vector> d-in set
    recursive-state set
    dataflow-graph off
    current-node off ;

GENERIC: apply-object

: apply-literal ( obj -- )
    #! Literals are annotated with the current recursive
    #! state.
    <literal> push-d  1 #push node, ;

M: object apply-object apply-literal ;

M: wrapper apply-object wrapped apply-literal ;

: active? ( -- ? )
    #! Is this branch not terminated?
    d-in get meta-d get and ;

: terminate ( -- )
    #! Ignore this branch's stack effect.
    meta-d off meta-r off d-in off ;

: terminator? ( obj -- ? )
    #! Does it throw an error?
    dup word? [ "terminator" word-prop ] [ drop f ] ifte ;

: handle-terminator ( quot -- )
    #! If the quotation throws an error, do not count its stack
    #! effect.
    [ terminator? ] contains? [ terminate ] when ;

: infer-quot ( quot -- )
    #! Recursive calls to this word are made for nested
    #! quotations.
    [ active? [ apply-object t ] [ drop f ] ifte ] all? drop ;

: infer-quot-value ( rstate quot -- )
    recursive-state get >r
    swap recursive-state set
    dup infer-quot handle-terminator
    r> recursive-state set ;

: check-return ( -- )
    #! Raise an error if word leaves values on return stack.
    meta-r get empty? [
        "Word leaves " meta-r get length unparse
        " element(s) on return stack. Check >r/r> usage." append3
        inference-error
    ] unless ;

: with-infer ( quot -- )
    [
        inferring-base-case off
        f init-inference
        call
        check-return
    ] with-scope ;

: infer ( quot -- effect )
    #! Stack effect of a quotation.
    [ infer-quot effect ] with-infer ;

: (dataflow) ( quot -- dataflow )
    infer-quot #return node, dataflow-graph get ;

: dataflow ( quot -- dataflow )
    #! Data flow of a quotation.
    [ (dataflow) ] with-infer ;

: dataflow-with ( quot stack -- effect )
    #! Infer starting from a stack of values.
    [ meta-d set (dataflow) ] with-infer ;
