create ascii-table
	BL ,
	ascii ` , ascii ' , ascii . , ascii - , ascii , , ascii _ , ascii : , ascii ^ , ascii ~ , ascii ! , ascii " ,
	ascii ; , ascii r , ascii / , ascii \ , ascii + , ascii ( , ascii ) , ascii > , ascii < , ascii | , ascii = ,
	ascii ? , ascii l , ascii c , ascii i , ascii [ , ascii ] , ascii v , ascii t , ascii z , ascii j , ascii L ,
	ascii 7 , ascii f , ascii x , ascii * , ascii s , ascii } , ascii { , ascii Y , ascii T , ascii J , ascii 1 ,
	ascii u , ascii n , ascii C , ascii y , ascii I , ascii F , ascii o , ascii 2 , ascii e , ascii w , ascii V ,
	ascii h , ascii 3 , ascii k , ascii a , ascii % , ascii Z , ascii 4 , ascii 5 , ascii S , ascii X , ascii $ ,
	ascii P , ascii m , ascii G , ascii A , ascii p , ascii q , ascii b , ascii d , ascii U , ascii E , ascii & ,
	ascii K , ascii 6 , ascii 9 , ascii O , ascii H , ascii g , ascii # , ascii D , ascii 8 , ascii R , ascii Q ,
	ascii W , ascii 0 , ascii M , ascii B , ascii @ , ascii N ,

here ascii-table - const MAX_CHARS ( number of chars in ascii-table )

80 const WIDTH
40 const HEIGHT

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

: mandel ( -- )
	HEIGHT 0 do
		WIDTH 0 do
			( map to range )
			i WIDTH 1- / [ X2 X1 - lit ] * X1 +
			j HEIGHT 1- / [ Y2 Y1 - lit ] * Y1 +
			mandel-at
			ascii-table + @ emit
		loop
		cr
	loop ;

mandel