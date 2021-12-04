: square ( n -- n ) dup * ;

: star ascii * emit ;

: test-if ( n -- n ) if 255 else 0 then ;

: test-again ( -- ) begin ascii * emit again ;

: test-loop ( -- ) 5 0 do i . loop cr ;

: test-loop2 ( -- ) -1 5 do i . -1 +loop cr ;
