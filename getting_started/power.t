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

-- let's see what it does with a plain loop
terra terra_loop5 (x: int)
  var y: int = x
  for i=1, 5 do
    y = y * x
  end
  return y
end

-- I can parameterize on the type
function make_power_func(value_type, n)
	local terra f (x : value_type)
		return [pow(n, x)]
	end
	return f
end
terra_power8 = make_power_func(double, 8)

