IN: scratchpad
USING: kernel lists test ;

[ [ 1 2 3 4 5 ] ] [
    <queue> [ 1 2 3 4 5 ] [ swap enque ] each
    5 [ drop deque swap ] project nip
] unit-test