#!lua

-- Disabling * wildcard expansion:
-- run this in shell (could be placed in bash init file?):
-- alias f='set -f;f';f(){ ~/code/f/f.lua "$@";set +f;}
-- this creates an alias so f can now be invoked like this: f 2 3 *

local input						-- input buffer
local cur_pos = 1				-- current position in input buffer
local cur_line = 1				-- not really used
local colon_pos					-- position of the previous colon in input buffer
local compile_mode = false		-- interpret or compile mode?
local stack = {}
local return_stack = {}
local mem = { [0] = 10 }		-- where user defined words and variables reside
local pc = 0					-- program counter for executing compiled code
local new_definitions			-- array of variable and constant definitions to be added to .f

function printf(...)
	print(string.format(...))
end

function errorf(...)
	error(string.format(...), 2)
end

function make_set(t)
	local set = {}
	for _, v in pairs(t) do
		set[v] = true
	end
	return set
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
	assert(v, "stack empty!")
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
	assert(v, "stack empty!")
	return v
end

function remove(idx)
	assert(stack[#stack + idx + 1], "stack underflow!")
	table.remove(stack, #stack + idx + 1)
end

function peek_char()
	local char = input:sub(cur_pos, cur_pos)
	if #char == 0 then char = nil end
	return char
end

function r_push(value)
	return_stack[#return_stack + 1] = value
end

function r_pop()
	local v = return_stack[#return_stack]
	assert(v, "return stack empty!")
	return_stack[#return_stack] = nil
	return v
end

function r_peek(idx)
	local v = return_stack[#return_stack + idx + 1]
	assert(v, "return stack underflow!")
	return v
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
function next_symbol(delimiters)
	delimiters = delimiters or "[ \n\t]"

	-- skip leading delimiters
	while true do
		local char = peek_char()
		if char and string.match(char, delimiters) then
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
		if char == nil or string.match(char, delimiters) then
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

		if n == 0 then return "0" end

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

-- Compilation & Execution

function here()
	return #mem + 1
end

function emit(value)
	table.insert(mem, value)
end

function check_compile_mode(word)
	if not compile_mode then
		errorf(word .. " may only be used inside colon definitions")
	end
end

function fetch()
	local instr = mem[pc]
	pc = pc + 1
	return instr
end

-- Executes a compiled word at given address in program memory.
function execute(addr)
	pc = addr

	while pc > 0 do
		local instr = fetch()
		local func = dict[instr]
		if func == nil then
			errorf("trying to execute undefined word %s", tostring(instr))
		end
		func()
	end
end

-- Executes input buffer.
function execute_input(str)
	input = str
	cur_pos = 1
	cur_line = 1

	while true do
		local sym = next_symbol()
		if sym == nil then break end
		sym = string.upper(sym)
		--printf("symbol [%s]", sym)

		if compile_mode then
			-- compile mode
			if immediate_words[sym] then
				-- execute immediate word
				dict[sym]()
			else
				local w = dict[sym]
				local n = parse_number(sym)

				if w then -- is it a word?
					emit(sym)
				elseif n then -- is it a number?
					emit('lit')
					emit(n)
				else
					errorf("undefined word '%s'", sym)
				end
			end
		else
			-- interpret mode
			local func = dict[sym]
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
end

-- Built-in words

immediate_words = make_set{
	":", ";", "(", "[", "IF", "ELSE", "THEN", "BEGIN", "UNTIL", "AGAIN", "DO", "LOOP", "+LOOP", "ASCII",
}

dict = {
	[','] = function()
		emit(pop())
	end,
	['('] = function()
		-- skip block comment
		next_symbol("%)")
	end,
	['['] = function()
		check_compile_mode('[')
		-- temporarily fall back to the interpreter
		compile_mode = false
	end,
	[']'] = function()
		assert(not compile_mode, "] without matching [")
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
		assert(not compile_mode, ": cannot be used inside colon definition")
		colon_pos = cur_pos
		local name = string.upper(next_symbol())
		local start_offset = here()
		compile_mode = true
		dict[name] = function()
			if pc > 0 then
				-- call another word when executing compiled word
				r_push(pc)
				pc = start_offset
			else
				-- call compiled word from interpreter
				execute(start_offset)
			end
		end
	end,
	[';'] = function()
		check_compile_mode(";")
		emit('ret')
		compile_mode = false
	end,
	['>R'] = function()
		r_push(pop())
	end,
	['R>'] = function()
		push(r_pop())
	end,
	CONST = function()
		local name = next_symbol()
		local value = pop()

		dict[string.upper(name)] = function()
			if compile_mode then
				emit('lit')
				emit(value)
			else
				push(value)
			end
		end

		if new_definitions then
			table.insert(new_definitions, value .. " const " .. name .. "\n")
		end
	end,
	VAR = function()
		assert(not compile_mode, "VAR cannot be used inside colon definition")		
		local name = next_symbol()
		local addr = here()
		local value = pop()
		emit(value)

		dict[string.upper(name)] = function()
			push(addr)
		end

		if new_definitions then
			table.insert(new_definitions, value .. " var " .. name .. "\n")
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

		if compile_mode then
			emit('lit')
			emit(char:byte(1))
		else
			push(char:byte(1))
		end
	end,
	BASE = function() push(0) end,
	HEX = function() mem[0] = 16 end,
	DECIMAL = function() mem[0] = 10 end,
	TRUE = function() push(1) end,
	FALSE = function() push(0) end,
	PI = function() push(math.pi) end,
	I = function() push(r_peek(-1)) end,
	LOAD = function()
		local filename = next_symbol()
		local file = assert(io.open(filename, "r"))
		local code = file:read("a")
		file:close()
		input = code .. " " .. input:sub(cur_pos)
		cur_pos = 1
		cur_line = 1
	end,
	IF = function()
		check_compile_mode("IF")
		-- emit conditional branch
		emit('?branch')
		push(here())
		push('if')
		emit(0)	-- placeholder branch offset
	end,
	ELSE = function()
		check_compile_mode("ELSE")
		assert(pop() == 'if', "ELSE without matching IF")
		local where = pop()
		-- emit jump to THEN
		emit('branch')
		push(here())
		push('if')
		emit(0)	-- placeholder branch offset
		-- patch branch offset for ?branch at IF
		mem[where] = here() - where - 1
	end,
	THEN = function()
		check_compile_mode("THEN")
		-- patch branch offset for ?branch at IF
		assert(pop() == 'if', "THEN without matching IF")
		local where = pop()
		mem[where] = here() - where - 1
	end,
	BEGIN = function()
		check_compile_mode("BEGIN")
		push(here())
		push('begin')
	end,
	UNTIL = function()
		check_compile_mode("UNTIL")
		assert(pop() == 'begin', "UNTIL without matching BEGIN")
		local target = pop()
		emit('?branch')
		emit(target - here() - 1)
	end,
	AGAIN = function()
		check_compile_mode("AGAIN")
		assert(pop() == 'begin', "AGAIN without matching BEGIN")
		local target = pop()
		emit('branch')
		emit(target - here() - 1)
	end,
	DO = function()
		check_compile_mode("DO")
		emit('SWAP')
		emit('>R')	-- limit to return stack
		emit('>R')	-- loop counter to return stack
		push(here())
		push('do')
	end,
	LOOP = function()
		check_compile_mode("LOOP")
		assert(pop() == 'do', "LOOP without matching DO")
		local target = pop()
		emit('lit')
		emit(1)
		emit('loop')
		emit(target - here() - 1)		
	end,
	["+LOOP"] = function()
		check_compile_mode("+LOOP")
		assert(pop() == 'do', "+LOOP without matching DO")
		local target = pop()
		emit('loop')
		emit(target - here() - 1)		
	end,

	-- internal words, these are in lowercase so they are not accessible from user code

	lit = function()
		push(fetch())
	end,
	branch = function()
		local offset = fetch()
		pc = pc + offset
	end,
	['?branch'] = function()
		local offset = fetch()
		if pop() == 0 then
			pc = pc + offset
		end
	end,
	loop = function()
		local offset = fetch()
		local step = pop()
		local counter = r_pop() + step
		local limit = r_pop()
		if (step >= 0 and counter < limit) or (step < 0 and counter > limit) then
			r_push(limit)
			r_push(counter)
			pc = pc + offset
		end
	end,
	ret = function()
		if #return_stack > 0 then
			pc = r_pop()
		else
			pc = 0
		end
	end,
}

-- load init file
local file = io.open(".f", "r")
if file then
	local src = file:read("a")
	file:close()
	execute_input(src)
end

-- execute input
local src = table.concat({...}, " ")
colon_pos = nil
new_definitions = {}
execute_input(src)

-- store variables and constants
if #new_definitions > 0 then
	for _, str in ipairs(new_definitions) do
		local file = assert(io.open(".f", "a"))
		file:write("\n", str)
		file:close()
	end
end

-- store colon definition
if colon_pos then
	local file = assert(io.open(".f", "a"))
	file:write("\n: ", src:sub(colon_pos), " ;\n")
	file:close()
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

if #stack > 0 then io.write("\n") end
