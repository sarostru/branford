-- To try next
-- Combining with dimensional analysis
-- Using array instead of xyz and then using entrymissing
-- Can I make new versions of primitive types?
-- I.e. With structs I can make different types with the same structure, can I do that for double
-- flipping order of inputs to a function?


-- Vector
local mul_vector_macro = macro(function(s, v)
    local vt = a:gettype()
    local bt = b:gettype()
    assert(at == bt, string.format("Error: Can only add scalar to scaler.  Got %s and %s", at, bt))
    return `at({x=s * v.x, y = s * v.y, z = s * v.z})
end)

local function make_vector_type(ScalarType, Size)
    local t = terralib.types.newstruct("Vector[" .. ValueType.type .. ", " .. Size .. "]")
    t.entries = {{"x", ScalarType}, {"y", ScalarType}, {"z", ScalarType}}
    t.metamethods.__add = add_vector_macro
    t.metamethods.__sub = sub_vector_macro
    t.metamethods.__mul = mul_vector_macro
    t.metamethods.__div = div_vector_macro
end


-- Scalar
local add_scalar_macro = macro(function(a, b)
    local at = a:gettype()
    local bt = b:gettype()
    assert(at == bt, string.format("Error: Can only add scalar to scaler.  Got %s and %s", at, bt))
    return `at({value=a.value + b.value})
end)

local mul_scalar_macro = macro(function(a, b)
    local at = a:gettype()
    local bt = b:gettype()
    -- assert scalar * scalar
    -- or scalar * vector
    assert(at == bt, string.format("Error: Can only add scalar to scaler.  Got %s and %s", at, bt))
    return `at({value=a.value * b.value})
end)

local function make_scalar_type(ValueType)
    local t = terralib.types.newstruct("Scalar[" .. ValueType.type .. "]")
    t.entries = {{"value", ValueType}}
    t.metamethods.__add = add_scalar_macro
    t.metamethods.__sub = sub_scalar_macro
    t.metamethods.__mul = mul_scalar_macro
    t.metamethods.__div = div_scalar_macro
    return t
end



function Scalar(ValueType)
    local T = {
        ValueType = ValueType,
        add = function(a, b) return a + b end,
        mul = function(a, b) return a * b end,
        inv = function(a) return -a end
    }
    return T
end

-- Vector
function Vector(ScalarType, Size)
    local T = {
        ScalarType = ScalarType,
        Size = Size,
        add = nil,
        sub = nil,
        mul = nil
    }
    return T
end

-- Vector Space
function VectorSpace(VectorType)
    local T = {
        ScalarType = VectorType.ScalarType,
        VectorType = VectorType,
        add = function(u, v) return u + v end,
        mul = function(s, v) return s * v end
    }
    return T
end

-- Affine Space
function AffineSpace(VectorSpace)
    local T = {
        add = function(p, v) return p + v end,
        sub = function(p, q) return p - q end
    }
end

-- Real numbers and Euclidian R3
ScalarType = double
struct VectorType { x : ScalarType; y : ScalarType; z : ScalarType}

EuclideanSpace = VectorSpace(ScalarType, VectorType)
u = VectorType({3, 2, 1})
v = VectorType({1, 2, 3})
w = EuclideanSpace.add(u, v)

