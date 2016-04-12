
local C = {}
C.stdio = terralib.includec("stdio.h")
C.math = terralib.includec("math.h")

local inspect = require("inspect")
local sys_print = print
function print(x) if type(x) == "table" then return sys_print(inspect(x)) else return sys_print(x) end end

-- TODO:: Best way to metaprogram a tuple?
--        The reason to use the tuple is that structs
--        don't get structural types, but tuples do
local Tuple = tuple(double, double, double)

-- TODO:: metaprogram to generate this function?
--        Accept arbitary number of arguments
terra Tuple:set(x : double, y : double, z : double)
    self._0 = x
    self._1 = y
    self._2 = z
    return self
end

terra Tuple:add(v : Tuple)
    var w : Tuple
    w:set(self._0 + v._0, self._1 + v._1, self._2 + v._2)
    -- C.printf("w._0 = %f, w._1 = %f, w._2 = %f\n", w._0, w._1, w._2)
    return w
end

terra Tuple:sub(v : Tuple)
    var w : Tuple
    w:set(self._0 - v._0, self._1 - v._1, self._2 - v._2)
    return w
end

terra Tuple:mul(v : Tuple)
    var w : Tuple
    w:set(self._0 * v._0, self._1 * v._1, self._2 * v._2)
    return w
end

-- Curious if there is any difference in assembly generated
-- for this and the above colon syntax mul, doesn't seem like it
terra tuple_mul(u : Tuple, v : Tuple) : Tuple
    return {u._0 * v._0, u._1 * v._1, u._2 * v._2}
end

terra Tuple:sum()
    return self._0 + self._1 + self._2
end

-- Looks like the dot product will automatically inline the call to sum
terra Tuple:dot(v : Tuple)
    return self:mul(v):sum()
    
end

local function print_tuple(label, x)
    local T = {}
    T[label] = {x._0, x._1, x._2}
    print(T)
end

local function test_tuple()
    local terra test_one()
        var x : Tuple
        var y : Tuple
        x:set(1,2,3)
        y:set(0,0,1)
        return {x=x, y=y}
    end
    local vars = test_one()
    local x = vars.x
    local y = vars.y
    print_tuple("x", x)
    print_tuple("y", y)
    print_tuple("x + y", x:add(y))
    print_tuple("x - y", x:sub(y))
    print_tuple("x * y", x:mul(y))
    print_tuple("x * y", tuple_mul(x, y))

    Tuple.methods.mul:printpretty()
    -- Tuple.methods.mul:disas()
    -- tuple_mul:printpretty()
    -- Tuple.methods.sum:printpretty()
    -- Tuple.methods.dot:printpretty()
    -- Tuple.methods.dot:disas()
end

test_tuple()

local Space = {Affine = "Affine", Vector = "Vector", Scalar = "Scalar"}
local Units = {L = "Length", M = "Mass", T = "Time", C = "Color"}

local DimensionalQuantity = {space = nil, units = nil, datatype = nil}
local _DQ = DimensionalQuantity
local DQ = nil

_DQ.new = function (space, units, datatype)
    return {fragment = function (x) return `x end,
            nargs = 1}
end

function _DQ:set(space, units, datatype)
    self.space = space
    self.units = units
    self.datatype = datatype
    return self
end

function _DQ:make(x, y, z)
    -- TODO:: How to make this general?
    local terra make()
        var v : self.datatype
        v:set([x], [y], [z])
        return v
    end 
    return make()
end

function _DQ:print()
    print({space = self.space;
           units = self.units})
    return self
end

function _DQ:add(other)
    -- Must match on Units
    assert(self.units == other.units, "add: Units Mismatch, (self, other) = (" .. tostring(self.units) .. ", " .. tostring(other.units) .. ")")
    -- Must match on Datatype
    assert(self.datatype == other.datatype, "add: Datatype Mismatch")
    -- Can add Vector + Vector -> Vector
    -- Can add Affine + Vector -> Affine
    if self.space == Space.Vector then
        return DQ():set(other.space, self.units, self.datatype) 
    elseif self.space == Space.Affine 
      and other.space == Space.Vector then
        return DQ():set(Space.Affine, self.units, self.datatype)
    else
        assert(false, "add: Can't add two Affine Quantities")
    end
end

function _DQ:sub(other)
    -- Must match on Units
    assert(self.units == other.units, "sub: Units Mismatch, (self, other) = (" .. tostring(self.units) .. ", " .. tostring(other.units) .. ")")
    -- Must match on Datatype
    assert(self.datatype == other.datatype, "sub: Datatype Mismatch")
    -- Can sub Vector - Vector -> Vector
    -- Can sub Affine - Vector -> Affine
    -- Can sub Affine - Affine -> Vector
    if self.space == Space.Vector 
      and other.space == Space.Vector then
        return DQ():set(Space.Vector, self.units, self.datatype) 
    elseif self.space == Space.Vector
      and other.space == Space.Affine then
        assert(false, "sub: Can't subtract Affine from Vector Quantities")
    elseif self.space == Space.Affine 
      and other.space == Space.Vector then
        return DQ():set(Space.Affine, self.units, self.datatype)
    else
        return DQ():set(Space.Vector, self.units, self.datatype)
    end
end

function _DQ:mul(other)
    print("DQ: ", self, " * ", other) 
    -- TODO: Testing for constants, just check if table
    --       Assume a constant value
    if type(other) ~= "table" then
        local constant = other
        assert(self.space == Space.Scalar)
        other = DQ():set(Space.Scalar, "", self.datatype)
        other.fragment = function () return `constant end
        other.nargs = 0
    end
    -- TODO:: Checks?
    assert(self.datatype == other.datatype)
    -- TODO:: Units calculations for real
    local units = self.units .. ":" .. other.units
    local r = DQ():set(self.space, units, self.datatype)
    -- TODO:: Has to be recursive and evaluate the argument
    --        fragments
    r.args = {}
    if other.nargs == 0 then
        r.fragment = function(x) return `[self.fragment(x)] * [other.fragment()] end
        r.nargs = 1
    else
        r.fragment = function(x, y) return `x:mul(y) end
        r.nargs = 2
    end
    
    return r
end

function _DQ:dot(other)
    -- TODO:: This one makes less sense as a generic DQ
    --        Maybe there is some way to annotate the
    --        operators of the underlying datatype?
    assert(self.datatype == other.datatype)
    -- TODO:: Units calculations for real
    local units = self.units .. ":" .. other.units
    -- Extracting the return type from the method definition
    local rtype = self.datatype.methods.dot.type.returntype
    local r = DQ():set(Space.Scalar, units, rtype)
    -- TODO:: both arguments are the same
    if self == other then
        r.fragment = function (x) return `x:dot(x) end
        r.nargs = 1
    else
        r.fragment = function (x, y) return `x:dot(y) end
        r.nargs = 2
    end
    return r
end

local DQ_metatable = {
  __index = _DQ;
}

DQ = setmetatable(_DQ, {
   __call = function ()
    return setmetatable(_DQ.new(), DQ_metatable)
  end;
})

local Scalar = DQ():set(Space.Scalar, "", double)

local Point = DQ():set(Space.Affine, Units.L, Tuple)
local Vector = DQ():set(Space.Vector, Units.L, Tuple)

local Time = DQ():set(Space.Affine, Units.T, Tuple)
local Duration = DQ():set(Space.Vector, Units.T, Tuple)

local Color = DQ():set(Space.Scalar, Units.C, Tuple)


-- Specs:
-- DQ has all operators defined on the underlying datatype
-- For each operator where checks are to be performed, you
-- specify what checks/what doesn't and how to combine
-- the returned DQ

Point:print()
Vector:print()

Point:add(Vector):print()
-- Can't add Point to Point
assert(not pcall(function () Point:add(Point) end))
-- can't add Pont to Time
assert(not pcall(function () Point:add(Time) end))
Vector:add(Vector):print()
Vector:add(Point):print()

Point:sub(Vector):print()
-- Can't sub Point to Point
Point:sub(Point):print()
-- can't sub Pont to Time
assert(not pcall(function () Point:sub(Time) end))
Vector:sub(Vector):print()
assert(not pcall(function () Vector:sub(Point) end))

local function scale_vector_by_color(x, c)
    -- Should work and get units L * C, x and c must have
    -- matching underlying datatypes
    -- i.e. DQ(x.space, x.units * c.units, x.datatype)
    return x:mul(c)
end

local function compiling_svc(lambda, x, c)
    local r = lambda(x, c)
    -- At this point we can assert that it passed the dim checks
    -- We don't have values, so r is DQ with the right type
    r:print()
    local terra csvc(x : x.datatype, c : c.datatype) : r.datatype
       return [r.fragment(x, c)]
    end
    return csvc
end

csvc_func = compiling_svc(scale_vector_by_color, Vector, Color)
csvc_func:printpretty()

-- csvc_func:disas()
-- Tuple.methods.mul:disas()
-- Nice, it's identical
sys_print(Tuple.methods.mul.type)


local function L2norm2(q)
    -- Should work and get units ^ 2 from v but different datatype, Scalar value
    -- i.e. DQ(Scalar, q.units, q.datatype.elemtype)
    -- ?? The mapping from 1 arg to 2 is not captured
    --    nor would constants be captured if they were here
    return q:dot(q)
end

local function compiling_l22(lambda, x)
    local r = lambda(x)
    -- At this point we can assert that it passed the dim checks
    -- We don't have values, so r is DQ with the right type
    r:print()
    local terra l22(x : x.datatype) : r.datatype
       return [r.fragment(x)]
    end
    return l22
end
l22_func = compiling_l22(L2norm2, Vector)
l22_func:printpretty()

local function mul_constant(q)
    return q:mul(18)
end

local function compiling_mc(lambda, x)
    local r = lambda(x)
    r:print()
    local terra mc(x : x.datatype) : r.datatype
       return [r.fragment(x)]
    end
    return mc
end
mc_func = compiling_mc(mul_constant, Scalar)
mc_func:printpretty()
mc_func:disas()

local function l22_mul_constant(q)
    return q:dot(q):mul(18)
end

local function compiling_l22mc(lambda, x)
    local r = lambda(x)
    r:print()
    local terra l22(x : x.datatype) : r.datatype
       return [r.fragment(x)]
    end
    return l22

end
l22_mc_func = compiling_l22mc(l22_mul_constant, Vector)
l22_mc_func:printpretty()

os.exit()

-- local function compile_DQ(lambda, args)
--     -- evaluate with DQs, assert that it checks
--     local function validate ()
--         -- right way to specify multiple args?
--         lambda(args) 
--     end
--     assert(pcall(validate), "function failed the dimension check")
--     -- wrap in escapes, eval and compile 
--     -- local terra lambda_terra (args.datatypes : {}) : {}
--     --     return `[lambda(args)]
--     -- end
--     -- return lambda_terra
-- end

local function genadd(a,b)
    local sum = `a + b
    local a = `a
    local b = `b
    print("the type of a is " .. a:gettype())
    print("the type of b is " .. b:gettype())
    print("the type of sum is " .. sum:gettype())
    -- use the type to do whatever you want
    return sum
end

terra foo()
    var d : double = 1.5
    var i : int= 1
    d = [genadd(d,i)] -- the type of sum is double
    i = [genadd(i,i)] -- the type of sum is int
end

foo()
print("the type of foo is", foo:gettype())
os.exit()

-- How to use these to verify the terra expressions?
local function test_with_terra()
    -- I want things like y = x + z * 3 to get dimension
    -- checked as I go
    -- but then the generated code should only have the
    -- raw mathematics left in it
    local x = Point:make(1, 2, 3)
    local y = Point:make(0, 0, 1)
    print_tuple("x", x)
    print_tuple("y", y)
    
    -- I'm getting a bit confused
    -- What it would be like
    -- p = Point(1, 2, 3)
    -- q = Point(3, 4, 5)
    -- v = p:sub(q)
    -- So what should that call do?
    -- It could check the analysis, then actually do the computation, but that interleaves my code execution with the dimensional analysis
    -- So instead, I have to just do the dim analysis, but postpone the actual calculations
    -- The variables should accumulate the expressions and then merge those into 1 terra function only when we want it to execute
    -- Cool, that makes sense.
    -- The DQ class will do all of the analysis and in addition to the dataype we need to maintain the expression tree so we can go back later and to the compile pass.
    
    -- function L2norm_lua(p, q)
    --     -- This should be able to type check
    --     return sqrt((p - q).dot(p - q))
    -- end
    -- A terra function that doesn't have DQ types might 
    -- look like this
    -- terra L2norm_terra(p : Tuple, q : Tuple) : double
    --     return `[L2norm_lua]
    -- end
    -- Could we write terra functions with DQ types?
    -- No?  It seems like L2 norm should work over all DQ types that match, so this function would have to typecheck
    -- Maybe, if compile a version for each DQ type we are interested in it might work
    -- terra L2norm_dq(p : DQ, q : DQ) : double
    -- end
    
    
    
    
    
end

-- test_with_terra()
