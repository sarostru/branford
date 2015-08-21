-- Examples copied from the getting started page
-- http://terralang.org/getting-started.html

terra myfn()
    var a = 3.0 --a will have type double
end

terra myfn()
    var a : int, b : double = 3, 4.5
    var c : double, d       = 3, 4.5
end

C = terralib.includec("stdlib.h")
terra doit()
    var a = [&int](C.malloc(sizeof(int) * 2))
    @a,@(a+1) = 1,2
end

--[[
Pointers (@ replaces C's * defer operator)
var a : int = 1
var pa : &int = &a
@pa = 4
var b = @pa

Static array example
var a : int[4]
a[0],a[1],a[2],a[3] = 0,1,2,3

SIMD Vector example
var a = vector(1,2,3,4) -- a has type vector(int,4)
var a = vectorof(int,3,4.5,4) -- a has type vector(int,3)
                              -- 4.5 will be cast to an int
terra saxpy(a :float,  X : vector(float,3), Y : vector(float,3),)
	return a*X + Y
end

Structs
struct Complex { real : float; imag : float; }
terra doit()
    var c : Complex
    c.real = 4
    c.imag = 5
end

]]--

--Function Pointers
terra add(a : int, b : int) return a + b end
terra sub(a : int, b : int) return a - b end
terra doit(usesub : bool, v : int)
    var a : {int,int} -> int
    if usesub then
        a = sub
    else
        a = add
    end
    return a(v,v)
end

--Dynamic Array Example
function Array(typ)
    return terra(N : int)
        var r : &typ = [&typ](C.malloc(sizeof(typ) * N))
        return r
    end
end

local NewIntArray = Array(int)

terra doit(N : int)
    var my_int_array = NewIntArray(N)
    --use your new int array
end