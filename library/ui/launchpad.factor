IN: gadgets-launchpad
USING: gadgets gadgets-borders gadgets-buttons gadgets-labels
gadgets-layouts gadgets-listener gadgets-theme help inspector io
kernel memory namespaces sequences ;

: <launchpad> ( menu -- )
    [ first2 >r <label> [ drop ] r> append <bevel-button> ] map
    make-pile 1 over set-pack-fill { 5 5 0 } over set-pack-gap
    <default-border> dup highlight-theme ;

: default-launchpad
    {
        { "Listener" [ listener-window ] }
        { "Documentation" [ [ handbook ] in-browser ] }
        { "Tutorial" [ [ tutorial ] in-browser ] }
        { "Vocabularies" [ [ vocabs. ] in-browser ] }
        { "Globals" [ [ global describe ] in-browser ] }
        { "Memory" [ [ heap-stats. terpri room. ] in-browser ] }
        { "Save image" [ save ] }
        { "Exit" [ 0 exit ] }
    } <launchpad> ;

: launchpad-window ( -- )
    default-launchpad "Factor" simple-window ;
