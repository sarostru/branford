--[[
Next up I want an interpreter, so lets do it in lua first, in Taha they use a 
small integer language
]]--

-- Putting the environment in lua using the explicit function implementation 
-- from Taha
-- env0 = function () error("Yikes!") end
-- function extend(env, x, v)
-- 	return function (y) if x == y then return v else return env(y) end end
-- end
-- env0 = function () error("Yikes!") end

--[[
  In order to support recursive functions, I have moved to a recursive
  table based environment.
  This is interesting, the stricter Taha one means you must use a 'let' plus
  a 'let rec' to define your recursive functions as otherwise you can't update
  the environment after a function has been defined to include the function 
  itself.
]]--
env_key = 0
function branch(env)
	local new_env = {}
	new_env[env_key] = env
	return new_env
end

function extend(env, x, v)
	env[x] = v
	return env
end

function retrieve(env, x)
	if env == nil then error("Yikes!") end
	local v = env[x]
	if v == nil then return retrieve(env[env_key], x) end
	return env[x]
end

function prompt()
	io.write("@>") 
end

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

op_table = {}
op_table["define"] = 
	function(e, env) 
		local name, expr = unpack(e)
		local value = eval(expr, env)
		local env = extend(env, name[2], value[1])
		return {"defined", env}
	end
op_table["if"] = 
	function(e, env)
		local pred, t_expr, f_expr = unpack(e)
		local result = eval(pred, env)
		-- False is zero, can env be changed in evaluating the if? hmm
		if result[1] ~= 0 then return eval(t_expr, env)
		else return eval(f_expr, env)
		end
	end
op_table["lambda"] = 
	function(e, env)
		local args, body = unpack(e)
		local parms = {}
		local j = 2
		while args[j] ~= nil do
			parms[j-1] = args[j][2]
			j = j + 1
		end
		local fenv  = branch(env)
		local lambda = function (args) 
							local i = 1
							while parms[i] ~= nil do
								fenv = extend(fenv, parms[i], args[i])
								i = i + 1
							end
							local result = eval(body, fenv)
							return result[1]
						end
		print("defined lambda: ", lambda)
		return {lambda, env}
	end
op_table["apply"] = 
	function(fname, params, env) 
		local lambda = eval(fname, env)
		local args = {}
		local i = 1
		while params[i] ~= nil do
			local result = eval(params[i], env)
			args[i] = result[1]
			i = i + 1
		end
		return {lambda[1](args), env}
	end

dispatch_table = {}
dispatch_table["number"] = 
	function(L, env) 
		local x = table.remove(L, 1) 
		return {x, env} 
	end
dispatch_table["symbol"] = 
	function(L, env) 
		local name = table.remove(L, 1)
		return {retrieve(env, name), env} 
	end
dispatch_table["list"] = 
	function(L, env)
		local op = table.remove(L, 1)
		local op_name = op[2]
		if op_table[op_name] ~= nil then
			return op_table[op_name](L, env)
		else
			return op_table["apply"](op, L, env)
		end
	end

function eval(expr, env)
	-- Shallow copying the expression, since I have made eval destructive on
	-- expr by using the table.remove approach.  Not sure if that was a good 
	-- idea.
	local e = {}
	for k, v in pairs(expr) do e[k] = v end
	local dispatch_code = table.remove(e, 1)
	return dispatch_table[dispatch_code](e, env)
end


function iscomplete(e)
	-- Welp this is terrible...
	local _, nl = string.gsub(e, "%(", "(")
	local _, nr = string.gsub(e, "%)", ")")
	return nl <= nr
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
-- local env = env0
local env = {}
env = extend(env, "+", function (args) return args[1] + args[2] end)
env = extend(env, "-", function (args) return args[1] - args[2] end)
env = extend(env, "*", function (args) return args[1] * args[2] end)
env = extend(env, "=", function (args) if args[1] == args[2] then return 1 else return 0 end end)
env = extend(env, "<", function (args) if args[1] < args[2] then return 1 else return 0 end end)
driver_loop(env)