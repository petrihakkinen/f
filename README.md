# f
Simple Forth interpreter that can be used as a commandline calculator

## Examples

	> f 10 2 * 5 +		( calculate 10 * 2 + 5 )
	25

	> f pi 2 / sin
	1.0

	> f ascii *    ( print the ascii value of * )
	42

	> f 1024 hex   ( convert 1024 from decimal to hex )
	400

	> f hex 1000 decimal    ( convert 1000 from hex to decimal )
	4096

	> f : square dup * ;    ( add a new word to dictionary )
	OK

	> cat .f    ( dictionary is automatically saved to file named .f )
	: square dup * ;

	> f 5 square
	25  ( the file .f is loaded automatically so all previously defined words can be used )

	> f load test.f 1 test-if    ( you can also load any Forth source file with LOAD )
	255

## Caveats

Many characters such as >, <, (, ) and ; have special meaning in shell. Use quotes to prevent shell interpreting them.

	> f 5 '>' 8
	0

	> f : test 1 ;	( no need to quote ; at the end of input... )
	OK

	> f : test 1 ';' test	( But you have to use quotes if you have code following ; )
	1

