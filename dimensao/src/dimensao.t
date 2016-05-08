local inspect = require "inspect"

-- imacro = terralib.internalmacro(function(diag, tree, x, y)
--     -- print("Diag")
--     -- print(inspect(diag))
--     -- print("Tree")
--     -- print(inspect(tree))
--     -- print("X")
--     -- print(inspect(x))
--     -- print("Y")
--     -- print(inspect(y))
--     local xt = x:gettype()
--     local yt = y:gettype()
--     print(string.format("x.units = %s", inspect(xt.units)))
--     print(string.format("y.units = %s", inspect(yt.units)))
--     assert(xt.units == yt.units, "The units are not the same!")
--     return `xt({x.value + y.value})
-- end)
add_dim_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    print(string.format("x.units = %s", inspect(xt.units)))
    print(string.format("y.units = %s", inspect(yt.units)))
    assert(xt.units == yt.units, "The units are not the same!")
    return `xt({x.value + y.value})
end)

function combine_units (U, V)
    local W = {}
    for i, v in pairs(U) do
        print(i)
        print(v)
        W[i] = v
    end
    for i, v in pairs(V) do
        print(i)
        print(v)
        if W[i] == nil then
            W[i] = v
        else
            W[i] = W[i] + v
        end
    end
    return W
end

local DimensionalType

mul_dim_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    print(string.format("x.units = %s", inspect(xt.units)))
    print(string.format("y.units = %s", inspect(yt.units)))
    assert(xt.units == yt.units, "The units are not the same!")
    local zt = DimensionalType(xt.base_type, combine_units(xt.units, yt.units))
    return `zt({x.value + y.value})
end)



DimensionalType = function(BaseType, units)
    local name = BaseType.name .. "[" 
    print("Units")
    local labels = {}
    local j = 1
    print(inspect(units))
    for i, v in pairs(units) do
        print(string.format("%s -> %s", i, v))
        labels[j] = i
        j = j + 1
        labels[j] = v
        j = j + 1
    end
    local name = name .. table.concat(labels, ",") .. "]"
    local t = terralib.types.newstruct(name)
    t.entries = {{field="value", type=BaseType}}
    t.base_type = BaseType
    t.units = units
    print("Methods")
    if BaseType.methods ~= nil then
        for i, v in pairs(BaseType.methods) do
            print(string.format("%s -> %s", i, v))
        end
    end
    print("MetaMethods")
    if BaseType.metamethods ~= nil then
        for i, v in pairs(BaseType.metamethods) do
            print(string.format("%s -> %s", i, v))
        end
    end
    print("Fields")
    if BaseType.fields ~= nil then
        for i, v in pairs(BaseType.fields) do
            print(string.format("%s -> %s", i, v))
        end
    end
    t.metamethods.__add = add_dim_macro
    t.metamethods.__mul = mul_dim_macro
    return t
end

D = DimensionalType(double, {L=1, T=1, M=1})
D2 = DimensionalType(double, {L=1, T=1})

terra add(x : D, y : D)
    return x + y
end
add:printpretty()
add:disas()
terra mul(x : D, y : D)
    return x * y
end
mul:printpretty()
mul:disas()

-- print(add({{value=5.0}, {value=2.0}}))

-- terra tadd(x : D, y: D2)
--     return x + x + x + y
-- end
-- tadd:printpretty()
-- tadd:disas()
