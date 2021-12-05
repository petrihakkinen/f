-- f
-- Forth interpreter that can be used as a command line calculator on Unix-like shells
--
-- Copyright (c) 2021 Petri Häkkinen
-- See LICENSE file for details

local input						-- input buffer
local cur_pos = 1				-- current position in input buffer
local cur_line = 1				-- not really used
local compile_mode = false		-- interpret or compile mode?
local stack = {}
local return_stack = {}
local mem = { [0] = 10 }		-- where user defined words and variables reside
local pc = 0					-- program counter for executing compiled code
local new_definitions			-- array of variable and constant definitions to be added to .f
local load_used					-- has the LOAD word been executed?

math.randomseed(os.time())

function printf(...)
	print(string.format(...))
end

function runtime_error(...)
	printf(...)

	-- scan backwards one symbol
	while cur_pos > 1 do
		cur_pos = cur_pos - 1
		if string.match(input:sub(cur_pos, cur_pos), "%S") then break end
	end
	while cur_pos > 1 do
		if string.match(input:sub(cur_pos - 1, cur_pos - 1), "%s") then break end
		cur_pos = cur_pos - 1
	end

	-- trim other lines before erroneous error
	local err_loc = input	
	for i = cur_pos, 1, -1 do
		if err_loc:sub(i, i) == '\n' then
			err_loc = err_loc:sub(i + 1)
			cur_pos = cur_pos - i
			break
		end
	end

	-- trim other lines after erroneous line
	err_loc = string.match(err_loc, "(.-)\n") or err_loc

	-- handle tabs
	for i = 1, cur_pos do
		if err_loc:sub(i, i) == '\t' then cur_pos = cur_pos + 3 end
	end
	err_loc = string.gsub(err_loc, "\t", "    ")

	-- show error location
	print(err_loc)
	print(string.rep(" ", cur_pos - 1) .. "^")

	os.exit(-1)
end

function runtime_assert(cond, msg)
	if not cond then
		runtime_error(msg)
	end
	return cond
end

function make_set(t)
	local set = {}
	for _, v in pairs(t) do
		set[v] = true
	end
	return set
end

-- Converts x from float to integer if it can be exactly represented as integer.
function int(x)
	return math.tointeger(x) or x
end

-- Init File

function load_init_file()
	local file = io.open(".f", "r")
	if file then
		local src = file:read("a")
		file:close()
		if not string.match(src, "\n$") then src = src .. "\n" end
		return src
	end
end

function save_init_file(src)
	local file = assert(io.open(".f", "w"))
	file:write(src)
	file:close()
end

function find_definition(src, name)
	src = string.upper(src)

	local pat_name = string.gsub(name, "([^%w])", "%%%1")

	-- match colon definition
	local s, e = string.match(src, "():%s+" .. pat_name .. "%s+.-;\n()")
	if s and e then return s, e, "colon" end

	-- match variable
	s, e = string.match(src, "()[%d%.]+%s+VAR%s+" .. pat_name .."\n()")
	if s and e then return s, e, "var" end

	-- match constant
	s, e = string.match(src, "()[%d%.]+%s+CONST%s+" .. pat_name .."\n()")
	if s and e then return s, e, "const" end
end

function forget(name)
	local src = load_init_file()
	if src == nil then return false end

	local s, e = find_definition(src, name)

	if s and e then
		src = src:sub(1, s - 1) .. src:sub(e)
		save_init_file(src)
		return true
	end

	return false
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
	runtime_assert(v, "stack underflow")
	stack[#stack] = nil
	return v
end

function pop_int()
	local v = math.tointeger(pop())
	runtime_assert(v, "integer argument expected")
	return v
end

function pop2()
	local a = pop()
	local b = pop()
	return b, a
end

function pop_int2()
	local a = pop_int()
	local b = pop_int()
	return b, a
end

function peek(idx)
	local v = stack[#stack + idx + 1]
	runtime_assert(v, "stack underflow")
	return v
end

function remove(idx)
	runtime_assert(stack[#stack + idx + 1], "stack underflow")
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
	runtime_assert(v, "return stack underflow")
	return_stack[#return_stack] = nil
	return v
end

function r_peek(idx)
	local v = return_stack[#return_stack + idx + 1]
	runtime_assert(v, "return stack underflow")
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
function next_symbol(delimiters, allow_eof)
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
	if peek_char() == nil then
		if not allow_eof then runtime_error("unexpected end of input") end
		return nil
	end

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
	local n = parse_number(sym)
	if n == nil then runtime_error("expected number, got '%s'", sym) end
	return n
end

-- Returns the current numeric base.
function base()
	return mem[0]
end

-- Returns string representation of a number in current numeric base.
-- Floats are always printed in base-10!
function format_number(n)
	if math.type(n) == "float" then return tostring(n) end

	local base = mem[0]
	runtime_assert(base >= 2 and base <= 36, "invalid numeric base")

	local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local result = ""

	if n == 0 then return "0" end

	if n < 0 then
		n = math.abs(n)

		if base == 2 then
			local num_digits = 32
			n = (1 << num_digits) - n
		elseif base == 4 then
			local num_digits = 16
			n = (1 << num_digits * 2) - n
		elseif base == 8 then
			local num_digits = 16
			n = (1 << num_digits * 3) - n
		elseif base == 16 then
			local num_digits = 8
			n = (1 << num_digits * 4) - n
		else
			result = "-"
		end			
	end

	while n > 0 do
		local d = n % base
		result = result .. digits:sub(d + 1, d + 1)
		n = n // base
	end

	return string.reverse(result)
end

-- Parses number from a string using current numeric base.
function parse_number(str)
	local base = mem[0]
	runtime_assert(base >= 2 and base <= 36, "invalid numeric base")
	if base == 10 then
		return tonumber(str)
	else
		return tonumber(str, base)
	end
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
		runtime_error("%s may only be used inside colon definitions", word)
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
			runtime_error("trying to execute undefined word %s", tostring(instr))
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
		local sym = next_symbol(nil, true)
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
					runtime_error("undefined word %s", sym)
				end
			end
		else
			-- interpret mode
			local func = dict[sym]
			if func == nil then
				-- is it a number?
				local n = parse_number(sym)
				if n == nil then runtime_error("undefined word %s", sym) end
				push(n)
			else
				func()
			end
		end
	end
end

-- Built-in words

immediate_words = make_set{
	":", ";", "(", "[", "IF", "ELSE", "THEN", "BEGIN", "UNTIL", "AGAIN", "DO", "LOOP", "+LOOP", "EXIT",
	"ASCII", "CHARS"
}

hidden_words = make_set{
	"lit", "branch", "?branch", "loop", "ret",
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
		runtime_assert(not compile_mode, "] without matching [")
		compile_mode = true
	end,
	['+'] = function() local a, b = pop2(); push(a + b) end,
	['-'] = function() local a, b = pop2(); push(a - b) end,
	['*'] = function() local a, b = pop2(); push(a * b) end,
	['/'] = function() local a, b = pop2(); runtime_assert(b ~= 0, "division by zero"); push(int(a / b)) end,
	['//'] = function() local a, b = pop2(); runtime_assert(b ~= 0, "division by zero"); push(math.floor(a / b)) end,
	['%'] = function() local a, b = pop2(); push(a % b) end,
	['^'] = function() local a, b = pop2(); push(int(a ^ b)) end,
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
	['2*'] = function() push(pop() * 2) end,
	['2/'] = function() push(int(pop() / 2)) end,
	['.'] = function() io.write(format_number(pop()), " ") end,
	['!'] = function() local addr = pop_int(); local n = pop(); mem[addr] = n end,
	['+!'] = function() local addr = pop_int(); local n = pop(); mem[addr] = mem[addr] + n end,
	['@'] = function() local addr = pop_int(); push(mem[addr] or 0) end,
	CREATE = function()
		local name = string.upper(next_symbol())
		local addr = here()
		dict[name] = function()
			push(addr)
		end
	end,
	ALLOT = function()
		local n = pop_int()
		for i = 1, n do
			emit(0)
		end
	end,
	[':'] = function()
		runtime_assert(not compile_mode, ": cannot be used inside colon definition")
		local start = cur_pos
		local name = string.upper(next_symbol())
		local addr = here()
		compile_mode = true
		dict[name] = function()
			if pc > 0 then
				-- call another word when executing compiled word
				r_push(pc)
				pc = addr
			else
				-- call compiled word from interpreter
				execute(addr)
			end
		end

		if new_definitions then
			-- TODO: this does not take into account that interpreted code may be following a colon definition
			table.insert(new_definitions, { name = name, type = "colon", src = ": " .. input:sub(start) .. " ;\n" })
		end
	end,
	[';'] = function()
		check_compile_mode(";")
		emit('ret')
		compile_mode = false
	end,
	CONST = function()
		local name = next_symbol()
		local uname = string.upper(name)
		local value = pop()

		dict[uname] = function()
			if compile_mode then
				emit('lit')
				emit(value)
			else
				push(value)
			end
		end

		if new_definitions then
			table.insert(new_definitions, { name = uname, type = "const", src = value .. " const " .. name .. "\n" })
		end
	end,
	VAR = function()
		runtime_assert(not compile_mode, "VAR cannot be used inside colon definition")		
		local name = next_symbol()
		local uname = string.upper(name)
		local addr = here()
		local value = pop()
		emit(value)

		dict[uname] = function()
			push(addr)
		end

		if new_definitions then
			table.insert(new_definitions, { name = uname, type = "var", src = value .. " var " .. name .. "\n" })
		end
	end,
	DUP = function() push(peek(-1)) end,
	['2DUP'] = function() push(peek(-2)); push(peek(-2)) end,
	OVER = function() push(peek(-2)) end,
	DROP = function() pop() end,
	['2DROP'] = function() pop2() end,
	NIP = function() local a, b = pop2(); push(b) end,
	ROT = function() push(peek(-3)); remove(-4) end,
	SWAP = function() local a, b = pop2(); push(b); push(a) end,
	PICK = function() push(peek(-pop())) end,
	PUSH = function() r_push(pop()) end,
	POP = function() push(r_pop()) end,
	['R@'] = function() push(r_peek(-1)) end,
	NEGATE = function() push(-pop()) end,
	AND = function() local a, b = pop_int2(); push(a & b) end,
	OR = function() local a, b = pop_int2(); push(a | b) end,
	XOR = function() local a, b = pop_int2(); push(a ~ b) end,
	NOT = function() push_bool(pop() == 0) end,
	LSHIFT = function() local a, b = pop_int2(); push(a << b) end,
	RSHIFT = function() local a, b = pop_int2(); push(a >> b) end,
	ABS = function() push(math.abs(pop())) end,
	MIN = function() local a, b = pop2(); push(math.min(a, b)) end,
	MAX = function() local a, b = pop2(); push(math.max(a, b)) end,
	SIN = function() push(math.sin(pop())) end,
	COS = function() push(math.cos(pop())) end,
	TAN = function() push(math.tan(pop())) end,
	ASIN = function() push(math.asin(pop())) end,
	ACOS = function() push(math.acos(pop())) end,
	ATAN = function() push(math.atan(pop())) end,
	DEG = function() push(math.deg(pop())) end,
	RAD = function() push(math.rad(pop())) end,
	FLOOR = function() push(math.floor(pop())) end,
	CEIL = function() push(math.ceil(pop())) end,
	SQRT = function() local a = pop(); runtime_assert(a >= 0, "argument for SQRT but be >= 0"); push(int(math.sqrt(a))) end,
	EXP = function() push(math.exp(pop())) end,
	LOG = function() local a = pop(); runtime_assert(a > 0, "argument for LOG must be > 0"); push(math.log(a)) end,
	RANDOM = function() local a, b = pop_int2(); runtime_assert(a <= b, "invalid interval for RANDOM"); push(math.random(a, b)) end,
	FRANDOM = function() push(math.random()) end,
	CR = function() io.write("\n") end,
	EMIT = function() io.write(string.char(pop())) end,
	SPACE = function() io.write(" ") end,
	SPACES = function() io.write(string.rep(" ", pop_int())) end,
	ASCII = function()
		local char = next_symbol()
		if #char ~= 1 then runtime_error("invalid symbol following ASCII") end

		if compile_mode then
			emit('lit')
			emit(char:byte(1))
		else
			push(char:byte(1))
		end
	end,
	CHARS = function()
		local chars = next_symbol()
		for i = 1, #chars do
			emit(chars:byte(i))
		end
	end,
	HERE = function() push(here()) end,
	BASE = function() push(0) end,
	BINARY = function() mem[0] = 2 end,
	DECIMAL = function() mem[0] = 10 end,
	HEX = function() mem[0] = 16 end,
	TRUE = function() push(1) end,
	FALSE = function() push(0) end,
	BL = function() push(32) end,
	PI = function() push(math.pi) end,
	I = function() push(r_peek(-1)) end,
	J = function() push(r_peek(-3)) end,
	LOAD = function()
		local filename = next_symbol()
		local file = runtime_assert(io.open(filename, "r"))
		local src = file:read("a")
		file:close()
		input = src .. " " .. input:sub(cur_pos)
		cur_pos = 1
		cur_line = 1
		load_used = true
	end,
	VLIST = function()
		local words = {}
		for name in pairs(dict) do
			if not hidden_words[name] then
				words[#words + 1] = name
			end
		end
		table.sort(words)
		for _, name in ipairs(words) do
			io.write(name, " ")
		end
		io.write("\n")
	end,
	LIST = function()
		local src = load_init_file()
		if src then io.write(src) end
	end,
	FORGET = function()
		local name = string.upper(next_symbol())
		runtime_assert(forget(name), string.format("word %s not found", name))
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
		runtime_assert(pop() == 'if', "ELSE without matching IF")
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
		runtime_assert(pop() == 'if', "THEN without matching IF")
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
		runtime_assert(pop() == 'begin', "UNTIL without matching BEGIN")
		local target = pop()
		emit('?branch')
		emit(target - here() - 1)
	end,
	AGAIN = function()
		check_compile_mode("AGAIN")
		runtime_assert(pop() == 'begin', "AGAIN without matching BEGIN")
		local target = pop()
		emit('branch')
		emit(target - here() - 1)
	end,
	DO = function()
		check_compile_mode("DO")
		emit('SWAP')
		emit('PUSH')	-- limit to return stack
		emit('PUSH')	-- loop counter to return stack
		push(here())
		push('do')
	end,
	LOOP = function()
		check_compile_mode("LOOP")
		runtime_assert(pop() == 'do', "LOOP without matching DO")
		local target = pop()
		emit('lit')
		emit(1)
		emit('loop')
		emit(target - here() - 1)		
	end,
	["+LOOP"] = function()
		check_compile_mode("+LOOP")
		runtime_assert(pop() == 'do', "+LOOP without matching DO")
		local target = pop()
		emit('loop')
		emit(target - here() - 1)		
	end,
	EXIT = function()
		check_compile_mode("EXIT")
		emit('ret')
	end,
	LIT = function()
		emit('lit')
		emit(pop())
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
local src = load_init_file()
if src then execute_input(src) end

-- execute input
local src = table.concat({...}, " ")
new_definitions = {}
execute_input(src)

-- store new definitions (forget previous definitions)
if #new_definitions > 0 and not load_used then
	local src = load_init_file() or ""
	local success = true

	for _, def in ipairs(new_definitions) do
		local _, _, existing_type = find_definition(src, def.name)

		if existing_type then
			if existing_type == def.type then
				forget(def.name)
				src = load_init_file() or ""
			else
				printf("WARNING! Conflicting definition for %s found. Init file not updated! (use FORGET to remove the definition)", def.name)
				success = false
			end
		end

		src = src .. def.src
	end
	if success then save_init_file(src) end
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
