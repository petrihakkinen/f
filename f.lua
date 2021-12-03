#!lua

--[[

Simple Forth interpreter that can be used as a commandline calculator

Disabling * wildcard expansion:
run this in shell (could be placed in bash init file?):
alias f='set -f;f';f(){ ~/code/f/f.lua "$@";set +f;}
this creates an alias so f can now be invoked like this: f 2 3 *

Examples:

> f ascii *    ( prints the ascii value of * )
42

> f 1024 hex   ( converts 1024 (dec) to hex )
400

> f hex 1000 decimal ( converts 1000 (hex) to decimal )
4096

> f 5 '>' 8  ( < and > have to be enclosed in quotes because they have special meaning in shell )
0

> f : square dup * ;  ( ; at the end is optional because ; is eliminated by shell )
OK

( : checks errors in the input by compiling it, appends the input as a new line to .f and prints OK )

> cat .f
: square dup * ;

> f 5 square
25  ( the file .f is loaded in by f, so all previously defined words can be used )

--]]

local input = table.concat({...}, " ")
local cur_pos = 1				-- current position in input buffer
local compile_mode = false		-- interpret or compile mode?
local stack = {}
local mem = { [0] = 10 }
local dictionary = {}			-- where user defined words are compiled into

print("input: " .. input)

function printf(...)
	print(string.format(...))
end

function errorf(...)
	error(string.format(...), 2)
end

-- Stack

function push(v)
	stack[#stack + 1] = v
end

function push_bool(v)
	stack[#stack + 1] = v and 1 or 0
end

function pop()
	local v = stack[#stack]
	assert(v, "stack underflow")
	stack[#stack] = nil
	return v
end

function pop2()
	local a = pop()
	local b = pop()
	return b, a
end

function peek(idx)
	local v = stack[#stack + idx + 1]
	assert(v, "stack underflow")
	return v
end

function remove(idx)
	assert(stack[#stack + idx + 1], "stack underflow")
	table.remove(stack, #stack + idx + 1)
end

function peek_char()
	local char = input:sub(cur_pos, cur_pos)
	if #char == 0 then char = nil end
	return char
end

-- Dictionary

function here()
	return #dictionary + 1
end

function emit(value)
	table.insert(dictionary, value)
end

function patch(offset, value)
	assert(dictionary[offset], "invalid dictionary offset")
	dictionary[offset] = value
end

-- Parsing

-- Returns next character from input. Returns nil at end of input.
function next_char()
	local char = peek_char()
	if char == '\n' then cur_line = cur_line + 1 end
	cur_pos = cur_pos + 1
	return char
end

-- Returns the next symbol from input. Returns nil at end of input.
function next_symbol(delimiter)
	delimiter = delimiter or " "

	-- skip leading delimiters
	while true do
		local char = peek_char()
		if char == delimiter then
			next_char()
		else
			break
		end
	end

	-- end of file reached?
	if peek_char() == nil then return nil end

	-- scan for next delimiter character
	local start = cur_pos
	while true do
		local char = next_char()
		if char == delimiter or char == nil then
			return input:sub(start, cur_pos - 2)
		end
	end
end

function next_number()
	local sym = next_symbol()
	if sym == nil then error("unexpected end of input") end
	local n = parse_number(sym)
	if n == nil then errorf("expected number, got '%s'", sym) end
	return n
end

-- Returns the current numeric base.
function base()
	return mem[0]
end

-- Returns string representation of a number in current numeric base.
function format_number(n)
	if math.type(n) == "integer" then
		local base = mem[0]
		assert(base >= 2 and base <= 36, "invalid numeric base")

		local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		local result = ""

		local neg
		if n < 0 then
			n = math.abs(n)
			neg = true
		end

		-- TODO: negative hexadecimals should be handled specially?

		while n > 0 do
			local d = n % base
			result = digits:sub(d + 1, d + 1) .. result
			n = n // base
		end

		if neg then result = "-" .. result end
		return result
	else
		return tostring(n)
	end
end

-- Parses number from a string using current numeric base.
function parse_number(str)
	local base = mem[0]
	assert(base >= 2 and base <= 36, "invalid numeric base")
	return tonumber(str, base)
end

-- Built-in words

interpret_dict = {
	[','] = function()
		emit(pop())
	end,
	['('] = function()
		-- skip block comment
		next_symbol(")")
	end,
	[']'] = function()
		assert(compile_mode, "] without matching [")
		compile_mode = true
	end,
	['+'] = function() local a, b = pop2(); push(a + b) end,
	['-'] = function() local a, b = pop2(); push(a - b) end,
	['*'] = function() local a, b = pop2(); push(a * b) end,
	['/'] = function() local a, b = pop2(); push(a / b) end,
	['//'] = function() local a, b = pop2(); push(math.floor(a / b)) end,
	['<'] = function() local a, b = pop2(); push_bool(a < b) end,
	['>'] = function() local a, b = pop2(); push_bool(a > b) end,
	['='] = function() local a, b = pop2(); push_bool(a == b) end,
	['0<'] = function() push_bool(pop() < 0) end,
	['0>'] = function() push_bool(pop() > 0) end,
	['0='] = function() push_bool(pop() == 0) end,
	['1+'] = function() push(pop() + 1) end,
	['1-'] = function() push(pop() - 1) end,
	['2+'] = function() push(pop() + 2) end,
	['2-'] = function() push(pop() - 2) end,
	['.'] = function() io.write(format_number(pop()), " ") end,
	['!'] = function()
		local n, addr = pop2()
		mem[addr] = n
	end,
	['@'] = function()
		local addr = pop()
		push(mem[addr] or 0)
	end,
	[':'] = function()
		compile_mode = true
	end,
	CONST = function()
		local name = next_symbol()
		local value = pop()

		-- add compile time word which emits the constant as literal
		compile_dict[name] = function()
			emit('lit')
			emit(value)
		end

		-- add word to interpreter dictionary so that the constant can be used at compile time
		interpret_dict[name] = function()
			push(value)
		end
	end,
	DUP = function() push(peek(-1)) end,
	OVER = function() push(peek(-2)) end,
	DROP = function() pop() end,
	ROT = function() push(peek(-3)); remove(-4) end,
	SWAP = function() local a, b = pop2(); push(b); push(a) end,
	PICK = function() push(peek(-pop())) end,
	ROLL = function() local i = pop(); push(peek(-i)); remove(-i - 1) end,
	NEGATE = function() push(-pop()) end,
	AND = function() local a, b = pop2(); push(a & b) end,
	OR = function() local a, b = pop2(); push(a | b) end,
	XOR = function() local a, b = pop2(); push(a ~ b) end,
	ABS = function() push(math.abs(pop())) end,
	MIN = function() local a, b = pop2(); push(math.min(a, b)) end,
	MAX = function() local a, b = pop2(); push(math.max(a, b)) end,
	SIN = function() push(math.sin(pop())) end,
	COS = function() push(math.cos(pop())) end,
	TAN = function() push(math.tan(pop())) end,
	CR = function() io.write("\n") end,
	EMIT = function() io.write(string.char(pop())) end,
	SPACE = function() io.write(" ") end,
	SPACES = function() io.write(string.rep(" ", pop())) end,
	ASCII = function()
		local char = next_symbol()
		if #char ~= 1 then error("invalid symbol following ASCII") end
		push(char:byte(1))
	end,
	BASE = function() push(0) end,
	HEX = function() mem[0] = 16 end,
	DECIMAL = function() mem[0] = 10 end,
}

compile_dict = {
	[':'] = function()
		error("invalid :")
	end,
	[';'] = function()
		compile_mode = false
	end,
	['('] = interpret_dict['('],
	['['] = function()
		-- temporarily fall back to the interpreter
		compile_mode = false
	end,
	IF = function()
		-- emit conditional branch
		emit('?branch')
		push(here())
		push('if')
		emit(0)	-- placeholder branch offset
	end,
	ELSE = function()
		assert(pop() == 'if', "ELSE without matching IF")
		local where = pop()
		-- emit jump to THEN
		emit('branch')
		push(here())
		push('if')
		emit(0)	-- placeholder branch offset
		-- patch branch offset for ?branch at IF
		patch(where, here() - where - 1)
	end,
	THEN = function()
		-- TODO: patch branch offset for ?branch at IF
		assert(pop() == 'if', "THEN without matching IF")
		local where = pop()
		patch(where, here() - where - 1)
	end,
	BEGIN = function()
		push(here())
		push('begin')
	end,
	UNTIL = function()
		assert(pop() == 'begin', "UNTIL without matching BEGIN")
		local target = pop()
		emit('?branch')
		emit(target - here() - 1)
	end,
	AGAIN = function()
		assert(pop() == 'begin', "AGAIN without matching BEGIN")
		local target = pop()
		emit('branch')
		emit(target - here() - 1)
	end,
	DO = function()
		emit('do')
		push(here())
		push('do')
	end,
	LOOP = function()
		assert(pop() == 'do', "LOOP without matching DO")
		local target = pop()
		emit('loop')
		emit(target - here() - 1)		
	end,
	["+LOOP"] = function()
		assert(pop() == 'do', "+LOOP without matching DO")
		local target = pop()
		emit('+loop')
		emit(target - here() - 1)		
	end,
	ASCII = function()
		local char = next_symbol()
		if #char ~= 1 then error("invalid symbol following ASCII") end
		emit('lit')
		emit(char:byte(1))
	end,
}

-- TODO: execute init file
-- local file, err = io.open(filename, "r")
-- if file == nil then print(err); os.exit(-1) end
-- input = file:read("a")
-- file:close()

-- execute input
while true do
	local sym = next_symbol()
	if sym == nil then break end
	sym = string.upper(sym)
	--printf("symbol [%s]", sym)

	if compile_mode then
		-- compile mode
		local func = compile_dict[sym]
		if func == nil then
			-- is it a number?
			local n = parse_number(sym)
			if n == nil then errorf("undefined word '%s'", sym) end
			emit('lit')
			emit(n)
		else
			func()
		end
	else
		-- interpret mode
		local func = interpret_dict[sym]
		if func == nil then
			-- is it a number?
			local n = parse_number(sym)
			if n == nil then errorf("undefined word '%s'", sym) end
			push(n)
		else
			func()
		end
	end
end

-- print results
for i, v in ipairs(stack) do
	if i > 1 then io.write(" ") end
	if type(v) == "number" then
		io.write(format_number(v))
	else
		io.write(tostring(v))
	end
end
io.write("\n")