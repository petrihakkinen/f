# f

f is a Forth interpreter that can be used as a command line calculator on Unix-like shells.

Features:

- Evaluate expressions directly from command line (bash or other Unix-like shell)
- Input and output support any numeric base from binary to base-36
- New user defined words (subroutines), variables and constants persist between runs
- External code can be loaded from files
- Fully programmable, includes most standard Forth words


## Installation

1. Prerequisite: Install and compile Lua 5.4 from <http://www.lua.org/download.html>.

2. Assuming you are using bash, add the following alias to your `.bashrc` (or `.bash_profile` on macOS):

	alias f='set -f;f';f(){ /path/to/lua /path/to/f.lua "$@";set +f;}

`/path/to/lua` should be replaced with a path to the Lua interpreter on your system and `/path/to/f.lua` with a path to `f.lua` where-ever you installed it.

Other shells may require different mantra for the alias. While it is not strictly necessary, the alias makes it easy to invoke `f` anywhere from the command line. It also disables wildcard expansion (aka globbing) for the asterisk so that `*` can be used as a word name.

f is written 100% in Lua so you don't need to compile it.


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

	> f 5 square    ( init file is loaded automatically so all previously defined words can be used )
	25

	> f load test/mandel.f
	```````'''''''...............----,:,,---....''''''
	``````'''''...............-----,,_^\^^_----....'''
	`````'''...............-------,,,:^;(~:,,----....'
	````'''..............-------,,__~+?NN+\:,,,---....
	```''..............------,,__::^~iNNNN"^:___,,-...
	``''.............----,,,__~]+;/NNNNNNNN?{"~~"^,-..
	``'...........--,,,,,,,__^~\NNNNNNNNNNNNNN[N7~_,-.
	`'........---_:___,___::~0NNNNNNNNNNNNNNNNNN+^:,--
	`....-----,,__c!/~i!~^^~+NNNNNNNNNNNNNNNNNNNNNh_--
	`.------,,,,_:~+NvNNN=r;eNNNNNNNNNNNNNNNNNNNN>(,--
	`-----,,,__/~!/NNNNNNNNlNNNNNNNNNNNNNNNNNNNNNW:,--
	`,,_:::_^^!+cNzNNNNNNNNNNNNNNNNNNNNNNNNNNNNNy:_,--
	`,,_:::_^^!+cNzNNNNNNNNNNNNNNNNNNNNNNNNNNNNNy:_,--
	`-----,,,__/~!/NNNNNNNNlNNNNNNNNNNNNNNNNNNNNNW:,--
	`.------,,,,_:~+NvNNN=r;eNNNNNNNNNNNNNNNNNNNN>(,--
	`....-----,,__c!/~i!~^^~+NNNNNNNNNNNNNNNNNNNNNh_--
	`'........---_:___,___::~0NNNNNNNNNNNNNNNNNN+^:,--
	``'...........--,,,,,,,__^~\NNNNNNNNNNNNNN[N7~_,-.
	``''.............----,,,__~]+;/NNNNNNNN?{"~~"^,-..
	```''..............------,,__::^~iNNNN"^:___,,-...
	````'''..............-------,,__~+?NN+\:,,,---....
	`````'''...............-------,,,:^;(~:,,----....'
	``````'''''...............-----,,_^\^^_----....'''
	```````'''''''...............----,:,,---....''''''


## About the Forth environment

All word names are case-insensitive. Values are double precision floats, which can represent any integer up to 2^53 without loss of precision. Numeric base used for parsing and formatting numbers can be changed by modifying the BASE variable.

For example,

	> f 100 8 base ! ( push 100 in decimal and change numeric base to octal )
	144

The built-in words BINARY, HEX and DECIMAL set the BASE accordingly.


## Init File

On startup f attempts to load the file `.f`, if it exists, from the current directory. New words, variables and constants are automatically appended to the init file. You should not need to edit the init file manually. You can list the contents of the init file using the LIST word, and remove existing words using FORGET. 

When defining new words, previous definitions for that word are automatically removed.


## Constants and Variables

The words CONST and VAR are used to define constants and variables:

	> f 360 const circle    ( define a new constant named "circle" )

	> f circle 2 *
	720

	> f 10 var x    ( define a new variable named "x" )

	> f 5 x +!    ( increment x by 5 )

	> f x @    ( print the value of x )
	15


## Caveats

Many characters such as `>`, `<`, `(`, `)` and `;` have special meaning in shell. Therefore, it's better to avoid using them in word names. If you must, use quotes to prevent shell interpreting them:

	> f 5 '>' 8
	0

Normally you don't need to add semicolon at the end of colon definitions (f adds it for you). However, if you have code following a colon definition that needs to be immediately interpreted, a quoted semicolon marks the end of the colon definition.

	> f : test 1 ';' test    ( Defines a new word and executes it )
	1

As is typical with Forth, control flow words (IF, DO and LOOP etc.) may not be used outside colon definitions. In the future we may implement unnamed words (with :NONAME) to circumvent this restriction.


## Word Index

The following letters are used to denote values on the stack:

- `x` any value
- `n` float or integer number
- `flag` a boolean flag with possible values 1 (representing true) and 0 (representing false)
- `addr` numeric address in the memory (where compiled words and variables go)

### Arithmetic

| Word       | Stack              | Description                                                         |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| +          | ( n n - n )        | Add two values                                                      |
| -          | ( n n - n )        | Subtract two values                                                 |
| *          | ( n n - n )        | Multiply two values                                                 |
| /          | ( n1 n2 - n )      | Divide n1 by n2                                                     |
| //         | ( n1 n2 - n )      | Divide n1 by n2 and convert the result to integer using FLOOR       |
| %          | ( n n - n )        | Compute the remainder of division                                   |
| ^          | ( n1 n2 - n )      | Raise n1 to the power of n2                                         |
| 1+         | ( n - n )          | Increment value by 1                                                |
| 1-         | ( n - n )          | Decrement value by 1                                                |
| 2+         | ( n - n )          | Increment value by 2                                                |
| 2-         | ( n - n )          | Decrement value by 2                                                |
| 2*         | ( n - n )          | Multiply value by 2                                                 |
| 2/         | ( n - n )          | Divide value by 2                                                   |
| NEGATE     | ( n - n )          | Negate value                                                        |
| ABS        | ( n - n )          | Compute the absolute value                                          |
| MIN        | ( n1 n2 - n )      | Compute the minimum of two values                                   |
| MAX        | ( n1 n2 - n )      | Compute the maximum of two values                                   |
| AND        | ( n n - n )        | Compute the bitwise and of two values                               |
| OR         | ( n n - n )        | Compute the bitwise or of two values                                |
| XOR        | ( n n - n )        | Compute the bitwise exlusive or of two values                       |
| LSHIFT     | ( n1 n2 - n )      | Rotate bits of n1 left n2 times, fill new bits with zero            |
| RSHIFT     | ( n1 n2 - n )      | Rotate bits of n1 right n2 times, fill new bits with zero           |
| FLOOR      | ( n - n )          | Round down to next integer value                                    |
| CEIL       | ( n - n )          | Round up to next integer value                                      |
| SQRT       | ( n - n )          | Compute the square root of a value                                  |
| EXP        | ( n - n )          | Compute e^x, where e is the base of natural logarithms              |
| LOG        | ( n - n )          | Compute the natural logarithm of a value                            |
| RANDOM     | ( n1 n2 - n )      | Generate a random integer value between n1 and n2 (inclusive)       |
| FRANDOM    | ( - n )            | Generate a random float between 0.0 and 1.0                         |

### Trigonometry

| Word       | Stack              | Description                                                         |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| SIN        | ( n - n )          | Compute the sine in radians                                         |
| COS        | ( n - n )          | Compute the cosine in radians                                       |
| TAN        | ( n - n )          | Compute the tangent in radians                                      |
| ASIN       | ( n - n )          | Compute the arc-sine in radians                                     |
| ACOS       | ( n - n )          | Compute the arc-cosine in radians                                   |
| ATAN       | ( n - n )          | Compute the arc-tangent in radians                                  |
| DEG        | ( n - n )          | Convert radians to degrees                                          |
| RAD        | ( n - n )          | Convert degrees to radians                                          |

### Stack Manipulation

| Word       | Stack                   | Description                                                         |
| ---------- | ----------------------- | ------------------------------------------------------------------- |
| DUP        | ( x - x x )             | Duplicate topmost stack element                                     |
| DROP       | ( x - )                 | Remove topmost stack element                                        |
| NIP        | ( x1 x2 - x2 )          | Remove the second topmost stack element                             |
| OVER       | ( x1 x2 - x1 x2 x1 )    | Duplicate the second topmost stack element                          |
| SWAP       | ( x1 x2 - x2 x1 )       | Swap two elements                                                   |
| ROT        | ( x1 x2 n3 - x2 x3 x1 ) | Rotate three topmost stack elements                                 |
| PICK       | ( n - x )               | Duplicates the Nth topmost stack element                            |
| 2DUP       | ( x1 x2 - x1 x2 x1 x2 ) | Duplicate two topmost stack elements                                |
| 2DROP      | ( x x - )               | Remove two topmost stack elements                                   |
| PUSH       | S: ( x - ) R: ( - x )   | Move value from data stack to return stack (>R in standard Forth)   |
| POP        | S: ( - x ) R: ( x - )   | Move value from return stack to data stack (R> in standard Forth)   |
| R@         | S: ( - x ) R: ( x - x ) | Copy value from return stack to data stack (without removing it)    |

### Memory

| Word       | Stack              | Description                                                       |
| ---------- | ------------------ | ----------------------------------------------------------------- |
| @          | ( addr - n )       | Fetch value from address                                          |
| !          | ( n addr - )       | Store value at address                                            |
| +!         | ( n addr - )       | Increment value in address by n                                   |

### Compilation and Execution

| Word            | Stack              | Description                                                         |
| --------------- | ------------------ | ------------------------------------------------------------------- |
| : \<name\>      | ( - )              | Define new word with name \<name\> ("colon definition")             |
| ;               | ( - )              | Mark the end of colon definition, go back to interpreted state      |
| ,               | ( n - )            | Enclose value to next free location in output dictionary            |
| (               | ( - )              | Parse until the next ), throw away the parsed symbol                |
| [               | ( - )              | Change from compile to interpreter state                            |
| ]               | ( - )              | Change from interpreter to compile state                            |
| CREATE \<name\> | ( - )              | Add new (empty) word to dictionary with name \<name\>               |
| CONST \<name\>  | ( n - )            | Capture value to a new word with name \<name\>                      |
| VAR \<name\>    | ( n - )            | Create new variable with name \<name\> and with initial value n     |
| ALLOT           | ( n - )            | Allocates space for n elements from output dictionary               |
| ASCII \<char\>  | ( - (n) )          | Emit literal containing the ASCII code of the following symbol      |
| CHARS \<string\> | ( - )             | Enclose a space-terminated string into output dictionary            |
| HERE            | ( - n )            | Push the address of the next free location in output dictionary     |
| LOAD \<filename\> | ( - )            | Load and interpret Forth source code from external file             |
| VLIST           | ( - )              | Print the names of all defined words                                |
| LIST            | ( - )              | Print the contents of init file                                     |
| FORGET \<name\> | ( - )              | Remove all definitions of a word from init file                     |
| LIT             | ( n - )            | Emit value from data stack to output dictionary                     |

### Constants and Variables

| Word            | Stack              | Description                                                         |
| --------------- | ------------------ | ------------------------------------------------------------------- |
| TRUE            | ( - 1 )            | Push one                                                            |
| FALSE           | ( - 0 )            | Push zero                                                           |
| PI              | ( - n )            | Push the value of pi                                                |
| BL              | ( - n )            | Push 32, the ASCII code of space character                          |
| BASE            | ( - addr )         | Push the address of built-in numeric base variable                  |
| BINARY          | ( - )              | Switch numeric base to binary (shortcut for 2 BASE !)               |
| DECIMAL         | ( - )              | Switch numeric base to decimal (shortcut for 10 BASE !)             |
| HEX             | ( - )              | Switch numeric base to hexadecimal (shortcut for 16 BASE !)         |

### Logical Operations

| Word       | Stack              | Description                                                         |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| =          | ( n1 n2 - flag )   | Compare n1 = n2 and set flag accordingly                            |
| <          | ( n1 n2 - flag )   | Compare n1 < n2 and set flag accordingly                            |
| >          | ( n1 n2 - flag )   | Compare n1 > n2 and set flag accordingly                            |
| 0=         | ( n - flag )       | Compare n = 0 and set flag accordingly                              |
| 0<         | ( n - flag )       | Compare n < 0 and set flag accordingly                              |
| 0>         | ( n - flag )       | Compare n > 0 and set flag accordingly                              |
| NOT        | ( n - flag )       | Same as 0=, used to denote inversion of a flag                      |

### Control Flow

| Word       | Stack              | Description                                                                       |
| ---------- | ------------------ | --------------------------------------------------------------------------------- |
| IF         | ( flag - )         | If flag is zero, skip to next ELSE or THEN, otherwise continue to next statement  |
| ELSE       | ( - )              | See IF                                                                            |
| THEN       | ( - n )            | See IF                                                                            |
| BEGIN      | ( - )              | Mark the beginning of indefinite or until loop                                    |
| UNTIL      | ( flag - )         | If flag is zero, jump to previous BEGIN, otherwise continue to next statement     |
| AGAIN      | ( - n )            | Jump (unconditionally) to previous BEGIN                                          |
| DO         | ( n1 n2 - )        | Initialize do loop, n1 is the limit value, n2 is the initial value of counter     |
| LOOP       | ( - )              | Increment loop counter by 1, jump to previous DO if counter has not reached limit |
| +LOOP      | ( n - )            | Add n to counter, jump to previous DO if counter has not reached limit            |
| EXIT       | ( - n )            | Exit immediately from current word (make sure return stack is balanced!)          |
| I          | ( - n )            | Push loop counter of innermost loop                                               |
| J          | ( - n )            | Push loop counter of second innermost loop                                        |

### Output

| Word       | Stack              | Description                                                       |
| ---------- | ------------------ | ----------------------------------------------------------------- |
| .          | ( n - )            | Print value using current numeric base followed by space          |
| CR         | ( - )              | Print newline character                                           |
| SPACE      | ( - )              | Print space character                                             |
| SPACES     | ( n - )            | Print n space characters                                          |
| EMIT       | ( n - )            | Print character, where n is the ASCII code                        |
