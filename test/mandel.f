create ascii-table
	BL ,
	chars `'.-,_:^~!";r/\+()><|=?lci[]vtzjL7fx*s}{YTJ1unCyIFo2ewVh3ka%Z45SX$PmGApqbdUE&K69OHg#D8RQW0MB@N

here ascii-table - const MAX_CHARS ( number of chars in ascii-table )

-2.00 const X1
 0.60 const X2
-1.12 const Y1
 1.12 const Y2

0 var x
0 var y

: sqr ( n -- n^2 ) dup * ;

: mandel-at ( x0 y0 -- iter )
	0 x !  ( clear x & y )
	0 y !
	0 ( s: x0 y0 iter )
	begin
		( check termination )	
		dup [ MAX_CHARS 1- lit ] =   x @ sqr   y @ sqr +   4 >   or  if
			nip nip exit
		then
		( step )
		x @ sqr  y @ sqr -   4 pick + ( x' = x*x - y*y + x0 )
		x @ y @ * 2 *   4 pick + ( y' = 2*x*y + y0 )
		y ! ( y = y' )
		x ! ( x = x' )
		1+ ( increment iteration )
	again ;

: mandel ( width height -- )
	dup 0 do
		over 0 do
			( map to range )
			over i swap 1- / [ X2 X1 - lit ] * X1 + ( x )
			over j swap 1- / [ Y2 Y1 - lit ] * Y1 + ( y )
			mandel-at
			ascii-table + @ emit
		loop
		cr
	loop 2drop ;

50 24 mandel