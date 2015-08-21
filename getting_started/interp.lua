--[[
Next up I want an interpreter, so lets do it in lua first, in Taha they use a 
small integer language
]]--

-- Putting the environment in lua using the explicit function implementation 
-- from Taha
env0 = function () error("Yikes!") end
function extend(env, x, v)
	return function (y) if x == y then return v else return env(y) end end
end

--[[I don't have types like in ocaml, so what to do, I guess prepend things with
a type tag that indexes into a table of things to do ]]--
--int = "type:int"
--var = "type:var"


-- local dispatch_table = {
	-- int = function (x, env) return x end,
	-- var = function (x, env) return env(x) end
-- }

-- function eval1(e, env) 
	-- local dispatch_key, expression = unpack(e)
	-- return dispatch_table[dispatch_key](expression, env)
-- end

function prompt()
	io.write("@>") 
end

-- A chunk:
--  assignment: x = 3
--  
-- function make_state_machine()
	-- local keywords = {"function", "return", "end", "if", "else", "then"}
	-- local symbols = {}
	-- states["function"] = make_transition_function()
	-- states[""]
	
	-- local state_transitions = {}
	-- local function method_1_func() return true end
	-- local methods_table {
		-- method_1 = method_1_func
	-- }
	-- return methods_table
-- end


-- Going with scheme syntax
function tokenize(s)
	local L = string.gmatch(string.gsub(string.gsub(s, "%(", " ( "), "%)", " ) "), "%S+")
	local T = {}
	local i = 1
	for l in L do
		T[i] = l
		i = i + 1
	end
	return {i = 1, n = i, tokens = T}	
end

function atom(e)
	local n = tonumber(e)
	if not n then return {"symbol", e}
	else return {"number", n} end
end

function make_tree(tokens)
	local T = tokens.tokens
	if tokens.n == 0 then
		error("unexpected EOF while reading")
	end
	local token = T[tokens.i]
	tokens.i = tokens.i + 1
	tokens.n = tokens.n - 1
	if '(' == token then 
		local L = {"list"}
		local j = 2
		while T[tokens.i] ~= ')' do
			L[j] = make_tree(tokens)
			j = j + 1
		end
		tokens.i = tokens.i + 1
		tokens.n = tokens.n - 1
		return L
	elseif ')' == token then
		error("unexpected )")
	else
		return atom(token)
	end
end




function eval(e, env)
	local dispatch_table = {}
	dispatch_table["number"] = function(L) print("number: ", L[2]) return {L[2], env} end
	dispatch_table["symbol"] = function(L) print("symbol: ", L[2]) return {env(L[2]), env} end
	dispatch_table["list"] = function(L)
		local op_table = {}
		op_table["define"] = function(L) print("define: ", L[3][2], L[4][2]) 
								local value = eval(L[4], env)
								local env = extend(env, L[3][2], value[1])
								return {"defined", env}
							end
		op_table["if"] = function(L) print("if")
							local result = eval(L[3], env)
							-- False is zero, can env be changed in evaluating the if? hmm
							if result[1] ~= 0 then return eval(L[4], env)
							else return eval(L[5], env)
							end
						end
		op_table["lambda"] = function(L)
								local parms = {}
								local j = 2
								while L[3][j] ~= nil do
									parms[j-1] = L[3][j][2]
									j = j + 1
								end
								local body = L[4]
								local fenv  = env
								local lambda = function (args) 
													local i = 1
													while parms[i] ~= nil do
														fenv = extend(fenv, parms[i], args[i])
														i = i + 1
													end
													local result = eval(body, fenv)
													return result[1]
												end
								return {lambda, env}
							end
		op_table["apply"] = function(L) 
								local lambda = eval(L[2], env)
								local args = {}
								local i = 1
								-- Arguments start at L[3] so i + 2
								while L[i+2] ~= nil do
									local result = eval(L[i+2], env)
									args[i] = result[1]
									i = i + 1
								end
								return {lambda[1](args), env}
							end
						
		if op_table[L[2][2]] ~= nil then
			return op_table[L[2][2]](L)
		else
			return op_table["apply"](L)
		end
	end
	return dispatch_table[e[1]](e)
end

function iscomplete(e)
	-- Welp this is terrible...
	local _, nl = string.gsub(e, "%(", "(")
	local _, nr = string.gsub(e, "%)", ")")
	return nl == nr
end

function read_exp(e)
	local l = io.read('*l')
	local new_exp = e .. l
	if iscomplete(new_exp) then return new_exp end
	return read_exp(new_exp)
end

function driver_loop(env)
	prompt()
	local e = read_exp("")
	if e == "exit" then print("Goodbye Friend!") return end
	local T = make_tree(tokenize(e))
	local result = eval(T, env)
	local val = result[1]
	local env = result[2]
	print("val: ", val)
	return driver_loop(env)
end
local env = env0
env = extend(env, "+", function (args) return args[1] + args[2] end)
env = extend(env, "*", function (args) return args[1] * args[2] end)
env = extend(env, "<", function (args) if args[1] < args[2] then return 1 else return 0 end end)
driver_loop(env)
-- A few things work now, but recursive functions are broken.
-- I think I finally understand better why there is a a letrec primitive for
-- defining recursive functions