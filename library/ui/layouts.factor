! Copyright (C) 2005, 2006 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: errors generic hashtables kernel math
namespaces queues sequences ;
IN: gadgets

DEFER: relayout-1

: invalidate ( gadget -- )
    \ relayout-1 swap set-gadget-state ;

: forget-pref-dim ( gadget -- ) f swap set-gadget-pref-dim ;

: invalid ( -- queue ) \ invalid get-global ;

: add-invalid ( gadget -- )
    #! When unit testing gadgets without the UI running, the
    #! invalid queue is not initialized and we simply ignore
    #! invalidation requests.
    invalid [ enque ] [ drop ] if* ;

DEFER: relayout

: invalidate* ( gadget -- )
    \ relayout over set-gadget-state
    dup forget-pref-dim
    dup gadget-root?
    [ add-invalid ] [ gadget-parent [ relayout ] when* ] if ;

: relayout ( gadget -- )
    #! Relayout and redraw a gadget and its parent before the
    #! next iteration of the event loop. Should be used when the
    #! gadget's size has potentially changed. See relayout-1.
    dup gadget-state \ relayout eq?
    [ drop ] [ invalidate* ] if ;

: relayout-1 ( gadget -- )
    #! Relayout and redraw a gadget before the next iteration of
    #! the event loop. Should be used if the gadget should be
    #! repainted, or if its internal layout changed, but its
    #! preferred size did not change.
    dup gadget-state
    [ drop ] [ dup invalidate add-invalid ] if ;

: show-gadget t swap set-gadget-visible? ;

: hide-gadget f swap set-gadget-visible? ;

: (set-rect-dim) ( dim gadget quot -- )
    >r 2dup rect-dim =
    [ [ 2drop ] [ set-rect-dim ] if ] 2keep
    [ drop ] r> if ; inline

: set-layout-dim ( dim gadget -- )
    #! Can only be used inside layout*.
    [ invalidate ] (set-rect-dim) ;

: set-gadget-dim ( dim gadget -- )
    [ invalidate* ] (set-rect-dim) ;

GENERIC: pref-dim* ( gadget -- dim )

: ?set-gadget-pref-dim ( dim gadget -- )
    dup gadget-state [ 2drop ] [ set-gadget-pref-dim ] if ;

: pref-dim ( gadget -- dim )
    #! Do not cache the pref-dim if it is potentially invalid.
    dup gadget-pref-dim [ ] [
        [ pref-dim* dup ] keep ?set-gadget-pref-dim
    ] ?if ;

M: gadget pref-dim* rect-dim ;

GENERIC: layout* ( gadget -- )

M: gadget layout* drop ;

: prefer ( gadget -- ) dup pref-dim swap set-layout-dim ;

DEFER: layout

: layout-children ( gadget -- ) [ layout ] each-child ;

: layout ( gadget -- )
    #! Position the children of the gadget inside the gadget.
    #! Note that nothing is done if the gadget does not need to
    #! be laid out.
    dup gadget-state [
        f over set-gadget-state
        dup layout* dup layout-children
    ] when drop ;

TUPLE: pack align fill gap ;

: pref-dims ( gadget -- list ) [ pref-dim ] map ;

: orient ( gadget seq1 seq2 -- seq )
    >r >r gadget-orientation r> r> [ pick set-axis ] 2map nip ;

: packed-dim-2 ( gadget sizes -- list )
    [ over rect-dim over v- rot pack-fill v*n v+ ] map-with ;

: packed-dims ( gadget sizes -- seq )
    2dup packed-dim-2 swap orient ;

: gap-locs ( gap sizes -- seq )
    { 0 0 } [ v+ over v+ ] accumulate 2nip ;

: aligned-locs ( gadget sizes -- seq )
    [ >r dup pack-align swap rect-dim r> v- n*v ] map-with ;

: packed-locs ( gadget sizes -- seq )
    over pack-gap over gap-locs >r dupd aligned-locs r> orient ;

: round-dims ( seq -- newseq )
    { 0 0 } swap
    [ swap v- dup [ ceiling ] map [ swap v- ] keep ] map nip ;

: pack-layout ( gadget sizes -- )
    round-dims over gadget-children
    >r dupd packed-dims r> 2dup [ set-layout-dim ] 2each
    >r packed-locs r> [ set-rect-loc ] 2each ;

C: pack ( vector -- pack )
    #! gap: between each child.
    #! fill: 0 leaves default width, 1 fills to pack width.
    #! align: 0 left, 1/2 center, 1 right.
    dup delegate>gadget
    [ set-gadget-orientation ] keep
    0 over set-pack-align
    0 over set-pack-fill
    { 0 0 } over set-pack-gap ;

: delegate>pack ( vector tuple -- ) >r <pack> r> set-delegate ;

: <pile> ( -- pack ) { 0 1 } <pack> ;

: <shelf> ( -- pack ) { 1 0 } <pack> ;

: dim-sum ( seq -- dim ) { 0 0 } [ v+ ] reduce ;

: gap-dims ( gap sizes -- seeq )
    [ dim-sum ] keep length 1 [-] rot n*v v+ ;

: pack-pref-dim ( gadget sizes -- dim )
    over pack-gap over gap-dims >r max-dim r>
    rot gadget-orientation set-axis ;

M: pack pref-dim*
    dup gadget-children pref-dims pack-pref-dim ;

M: pack layout*
    dup gadget-children pref-dims pack-layout ;

: fast-children-on ( dim axis gadgets -- i )
    swapd [ rect-loc v- over v. ] binsearch nip ;

M: pack children-on
    dup gadget-orientation swap gadget-children [
        3dup
        >r >r dup rect-loc swap rect-dim v+ origin get v-
        r> r> fast-children-on 1+
        >r
        >r >r rect-loc origin get v-
        r> r> fast-children-on
        0 max
        r>
    ] keep <slice> ;
