
local C = terralib.includec("stdio.h")

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
end

test_tuple()

local Space = {Affine = "Affine", Vector = "Vector"}
local Units = {L = "Length", M = "Mass", T = "Time"}

local DimensionalQuantity = {space = nil, units = nil, datatype = nil}
local _DQ = DimensionalQuantity
local DQ = nil

_DQ.new = function (space, units, datatype)
    return {}
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

local DQ_metatable = {
  __index = _DQ;
}

DQ = setmetatable(_DQ, {
   __call = function ()
    return setmetatable(_DQ.new(), DQ_metatable)
  end;
})

local Point = DQ():set(Space.Affine, Units.L, Tuple)
local Vector = DQ():set(Space.Vector, Units.L, Tuple)

local Time = DQ():set(Space.Affine, Units.T, Tuple)
local Duration = DQ():set(Space.Vector, Units.T, Tuple)

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
    
    
    
    
    
    
end

test_with_terra()
