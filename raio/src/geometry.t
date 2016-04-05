
local C = terralib.includec("stdio.h")
-- Vector
-- 3D vector with x,y,z named tags by default
--
local Vector = {x = 0,
                y = 0,
                z = 0}

Vector.new = function () return {} end

function Vector:init (x, y, z)
    self.x = x
    self.y = y
    self.z = z
end

function Vector:add (v)
    local u = Vector.new()
    u.x = self.x + v.x
    u.y = self.y + v.y
    u.z = self.z + v.z
    return u
end

local metatable = {
  __index = Vector;
}

local PublicVector = setmetatable(Vector, {
  __call = function ()
    return setmetatable(Vector.new(), metatable)
  end;
})

-- Module Table
local geom = {_module="geometry",
              Vector=PublicVector}

-- Elementwise Fixed Vector

-- Using the syntax sugaring struct definition
-- struct TerraVector {
--     x : double;
--     y : double;
--     z : double;
-- }

-- TODO:: To get a variable vector, we need a function
--        that takes a list of names x, y, z, ...
--        and a type int, float, etc

-- This is equivalent to the syntax sugar version above
-- but will make it easy to metaprogram
TerraVector = terralib.types.newstruct("TerraVector")
TerraVector.entries = {
    {"x", double}, {"y", double}, {"z", double}
}

terra TerraVector:init(x : double,
                       y : double,
                       z : double)
    self.x = x
    self.y = y
    self.z = z
    return self
end

-- This will add 'add' to TerraVector.methods
terra TerraVector:add (v : TerraVector)
    var u : TerraVector
    u.x = self.x + v.x
    u.y = self.y + v.y
    u.z = self.z + v.z
    return u
end

terra TerraVector:mul (v : TerraVector)
    var u : TerraVector
    u.x = self.x * v.x
    u.y = self.y * v.y
    u.z = self.z * v.z
    return u
end

-- return module_table

-- Tests
local inspect = require("inspect")
local sys_print = print
function print(x) if type(x) == "table" then return sys_print(inspect(x)) else return sys_print(x) end end


-- Testing Vector
local function test_vector()
    assert(geom._module == "geometry", "Not the geometry module")
    local v = geom.Vector()
    
    assert(v.x == 0 and v.y == 0 and v.z == 0, "Starts as zero")
    v:init(5,5,5)
    assert(v.x == 5 and v.y == 5 and v.z == 5, "All 5")
    local u = v:add(v)
    assert(u.x == 10 and u.y == 10 and u.z == 10, "All 10")
    
    local w = geom.Vector()
    assert(w.x == 0 and w.y == 0 and w.z == 0, "Starts as zero")
    
end

test_vector()

local function test_terra_vector()
    local terra test_one()
        var v : TerraVector
        v:init(1,2,3)
        return v
    end
    local v = test_one()
    assert(v.x == 1 and v.y == 2 and v.z == 3, "Equals 1, 2, 3")
    local terra test_two() 
        var v : TerraVector
        v:init(1,2,3)
        var u : TerraVector
        u:init(4,5,6)
        var w : TerraVector
        w = v:add(u)
        C.printf("v = %f, u = %f, w = %f\n", v, u, w)
        return w 
    end
    local u = test_two()
    print({name=u, x=u.x, y=u.y, z=u.z})
    assert(u.x == 5 and u.y == 7 and u.z == 9, "Equals 5, 7, 9")
    -- print("add function")
    -- print(TerraVector.methods.add:printpretty())
    -- print("Disassembly")
    -- print(TerraVector.methods.add:disas())
    local combined_function = terra(v : TerraVector, u: TerraVector)
        return u:add(v):mul(v):add(v):mul(u)
    end
    print("combined function")
    print(combined_function:printpretty())
    print("Disassembly")
    print(combined_function:disas())

    local terra partitioned_function(u: TerraVector, v: TerraVector)
        return u.x + v.x + u.y + v.y + u.z + v.z
    end
    print("partitioned function")
    print(partitioned_function:printpretty())
    print("Disassembly")
    print(partitioned_function:disas())
    
end

test_terra_vector()
