# f
Simple Forth interpreter that can be used as a commandline calculator

## Examples

	> f 10 2 * 5 +    ( calculate 10 * 2 + 5 )
	25

	> f pi 2 / sin
	1.0

	> f ascii *    ( print the ascii value of * )
	42

	> f 1024 hex    ( convert 1024 from decimal to hex )
	400

	> f hex 1000 decimal    ( convert 1000 from hex to decimal )
	4096

	> f : square dup *    ( add a new word to dictionary )

	> cat .f    ( dictionary is automatically saved to file named .f )
	: square dup * ;

	> f 5 square
	25    ( the file .f is loaded automatically so all previously defined words can be used )

	> f load test.f 1 test-if    ( you can also load any Forth source file with LOAD )
	255

## Constants and Variables

F supports constants and variables. The words CONST and VAR are used for defining them:

	> f 360 const circle    ( define a new constant named "circle" )

	> f circle 2 *
	720

	> f 10 var x    ( define a new variable named "x" )

	> f x @ 5 + x !    ( increment x by 5 )

	> f x @    ( print the value of x )
	15

## Caveats

Many characters such as >, <, (, ) and ; have special meaning in shell. Therefore, it's better to avoid using them in word names. If you must, use quotes to prevent shell interpreting them:

	> f 5 '>' 8
	0

Normally you don't need to add semicolon at the end of colon definitions (f adds it for you). However, if you have code following a colon definition that needs to be immediately interpreted, a quoted semicolon marks the end of the colon definition.

	> f : test 1 ';' test    ( Defines a new word and executes it )
	1

## Built-in Words
