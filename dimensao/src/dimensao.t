-- DQ geometry = {AffineSpace, VectorSpace}
-- DQ units = {Units}
-- DQ datatype = {datatype}

local Constants = {
    Geometry = {
        AffineSpace = "AffineSpace",
        VectorSpace = "VectorSpace"
    },
    Units = {
        Dimensionless = "",
        Length = "Length",
        Time = "Time",
        Mass = "Mass",  
        Color = "Color"
    }
}


local function newFunction(self, f, arity) 
    if arity == 1 then
        return function () return f(self) end
    elseif arity == 2 then
        return function (x) return f(self, x) end
    else
        print("Error: Invalid function arity", f)
    end
    return nil
end


local function newVTable (self, functions)
    local self = self
    local vtable = {}
    for k, f in ipairs(functions) do
        vtable[k] = newFunction(self, f.func, f.arity)
    end
    return vtable
end

local InputFunctions = {
    toDQ={arity=1, func=function(x) return "Type Here?"end}
}

local BinaryFunctions = {
    add={arity=2, func=function(x, y) return `x + y end}, 
    sub={arity=2, func=function(x, y) return `x - y end}, 
    mul={arity=2, func=function(x, y) return `x * y end}
}


-- local ScalarFunctions = {
--     -- binary ops
--     add, sub, mul, div, pow, close_to,
--     -- unary ops
--     sqrt, negate, recip,
--     -- conversion
--     to_vec
-- }
-- 
-- local VectorDQ = {
--     -- elementwise, binary ops
--     add, sub, mul, div, pow, close_to,
--     -- elementwise unary ops
--     sqrt, negate, recip,
--     -- vector math ops
--     dot, sum,
--     -- getitem, extract element to Scalar
--     get,
--     -- setitem, assign Scalar to element
--     set,
--     -- utility ops composed of the others
--     normalize
-- }


local DQTable = {
    -- TODO:: These need to actual implementations
    --        each one should be wrapped in a argument
    --        handler function, then instead of + 
    --        it has to do the dimension checks
    __add = function (x, y) 
        print("DQ.add(", x, y, ")")
        -- TODO:: Temporarily inserting 5 here
        return 5 + y
    end,
    __sub = function (x, y)
        print("DQ.sub(", x, y, ")")
        return x - y
    end,
    __mul = function (x, y)
        print("DQ.mul(", x, y, ")")
        return x * y
    end    
}


local function newDimensionalQuantity (geometry, units, functions , datatype)
    local self = {geometry=geometry,
                  units=units,
                  datatype=datatype}
    local functions = functions 
    local vtable = newVTable(self, functions)
    setmetatable(vtable, DQTable)

    return vtable
end

local DQ = newDimensionalQuantity

local Scalar = DQ(Constants.Geometry.AffineSpace,
                  Constants.Units.Dimensionless,
                  BinaryFunctions,
                  double)


local function some_math(x) 
    return (x + 2) * 3 - 2
end

-- I need to:
-- 1. Upcast constants into dimensional things
-- 2. Store the AST
-- 3. Store the position(s) in the AST of the arguments
-- 4. Provide 2 evaulation modes of the AST
--  a) Verify that everything typechecks using dimensional analysis
--  b) Generate the raw terra code

-- Let's start with only the plus operator and only numbers

local Number = "Number"

function join(...)
    if #arg == 0 then
        return ""
    end

    local s = arg[1]
    for i = 2, #arg do
        s = s .. " -> " .. arg[i]
    end
    return s
end

local AdditionOperators = {}
AdditionOperators[join(Number, Number)] = function (x, y) return x + y end


local inspect = require "inspect"
local ASTNode = {}
ASTNode.__add = function(x, y)
        print(inspect(AdditionOperators))
        local f = AdditionOperators[join(x.Type, y.Type)]
        print(inspect(f))
        
        return f(x.value, y.value)
    end

function make_number(value)
    local T = {Type=Number, value=value}
    setmetatable(T, ASTNode)
    return T
end

local x = make_number(10)
local y = make_number(8)
print("x = ", x.value, ", type = ", inspect(x.Type))
print("y = ", y.value, ", type = ", inspect(y.Type))
print("x + y = ", x + y)




print(inspect(Scalar))
print(some_math(Scalar))
-- print(some_math(Scalar))
-- print(some_math(Scalar))
-- print(some_math(Scalar))
