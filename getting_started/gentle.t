--[[
Working through the examples and syntax from Taha's paper, 
"A Gentle Introduction to Multi-stage Programming"
to match up equivalent concepts in terra
]]--
print("Let's be Gentle, Together!")

--[[
Things are a bit different in lua-terra land, but lets just try some things
So they talk about avoiding name capture first with this example, 
let rec h n z = if n=0 then z
else .<(fun x -> .~(h (n-1) .<x+ .~z>.)) n>.;;
]]--

-- Unstage version in lua
function weird_thing_lua (n, z) 
	if n == 0 then 
		return z 
	else 
		local function f(x) return weird_thing_lua(n-1, x + z) end
		return f(n)
	end
end
-- return weird_thing_lua(3,1)
-- should give 7

--[[
Ok, so unlike metaocaml, we can't stage lua code we instead use terra
first the terra version.
Actually this is interesting, you can't nest function definitions in terra
That makes sense since it is C like
]]--

--[[
This won't compile 
terra f(x:int) 
	terra g(y:int) return f(y) end
	return g(x)
end
]]-- 

--[[
I think you have to bounce back and forth between lua and terra
]]--
-- Calling this will go infinite :)
function h(x)
	local terra g(y:int) return h(y) end
	return g(x)
end

-- This isn't staged but it bounces back and forth between the two languages
-- By default lua functions called from terra do not give back return values
-- Since it can't type them, so you have to cast it to a terra function with 
-- an explicit type signature.
function weird_thing (n, z)
	if n == 0 then
		return z
	else
		local terra_weird_thing = terralib.cast( {int, int} -> int, weird_thing)
		local terra f(x:int) return terra_weird_thing(n-1, x + z) end
		return f(n)
	end
end	
print("Calling weird_thing(3,1):")
print(weird_thing(3, 1))

--[[
Now how do I stage this, I guess first off, is what is a code object for us?
What they do in Taha, is you compile your weird thing for n as an integer, but 
with z still undefined, I think you can do it a bit easier here
]]--

--[[
Giving up on this guy, the idea was maybe I have to use factory functions inside 
each iteration, but its weird, moving on to other things, may come back to this
function make_weird_thing (n)
	local terra h (n: int, z: int)
		if n == 0 then
			return z
		else
			[local terra_weird_thing = terralib.cast( {int, int} -> int, make_weird_thing)
			function f(x) return make_weird_thing(n-1, x + z) end]
]]--


--[[
This is just cool, pasting it in
]]--
terra add1(a : double)
    return a + a
end

print("Show disassembly")
add1:disas()

print("Compile The code")
add1:compile()

print("Pretty Version:")
add1:printpretty()

--[[
Power example
]]--

--in lua
function lua_power (n, x)
	if n == 0 then return 1
	else return x * lua_power(n-1, x)
	end
end
printf = function(s,...)
           return io.write(s:format(...))
         end -- function
printf("lua power: 2^5 = %d\n", lua_power(5,2))


--in terra recursvie functions need an explicit return type
terra terra_power (n: int, x: int) : int
	if n == 0 then return 1
	else return x * terra_power(n-1, x)
	end
end
printf("terra power: 2^5 = %d\n", terra_power(5,2))
printf("Naive terra power function")
terra_power:printpretty()
printf("Naive terra dissassembly")
-- Its big don't look at it...
-- terra_power:disas()

--This mul example shows how to quote and unquote expressions into terra code
function mul(x, y)
	return `x * y
end

terra terra_mul(x:int, y:int)
	return [mul(x, y)]
end

--[[
Then we can do the same thing to generate the power function
]]--
function pow(n, x)
	if n == 0 then return `1
	else return `x*[pow(n-1,x)]
	end
end

terra terra_pow5 (x: int)
	return [pow(5, x)]
end
printf("terra_staged power: 2^5 = %d\n", terra_pow5(2))
print("Pretty printing the staged function")
terra_pow5:printpretty()
print("Printing the dissassembly")
terra_pow5:disas()

-- neat, that is awesome!

--[[
Next up I want an interpreter, so lets do it in lua first, in Taha they use a 
small integer language
]]--

-- Putting the environment in lua using the explicit function implementation 
-- from Taha
env0 = function () error("Yikes!") end
function extend(env, x, v)
	return function (y) if x == y then return v else return env(y) end 
end

--[[I don't have types like in ocaml, so what to do, I guess prepend things with
a type tag that indexes into a table of things to do ]]--
int = "type:int"
var = "type:var"


dispatch_table = {
	[int] = function (x, env) return x end
	[var] = function (x, env) return env(x) end
}

function eval1(e, env) 
	local dispatch_key, expression = unpack(e)
	return dispatch_table[dispatch_key](expression, env)
end

-- Parsing
