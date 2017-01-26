local QuaternionTypeFactory
local QuaternionType
local inspect = require "inspect"

mul_quat_macro_impl = macro(function(x, y)
    local xt = x.value:gettype()
    local yt = y.value:gettype()
    local exp = quote
        var u : xt = x.value
        var v : yt = y.value
    in
        xt({u[0]*v[0] - u[1]*v[1] - u[2]*v[2] - u[3]*v[3],
            u[0]*v[1] + u[1]*v[0] + u[2]*v[3] + u[3]*v[2],
            u[0]*v[2] - u[1]*v[3] + u[2]*v[0] + u[3]*v[1],
            u[0]*v[3] + u[1]*v[2] - u[2]*v[1] + u[3]*v[0]}) 
    end
    return exp
end)

mul_quat_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    print(string.format("x:gettype() = %s", xt))
    print(string.format("y:gettype() = %s", yt))
    if (xt == QuaternionType) and (yt == QuaternionType) then
        -- return `mul_quat_macro_impl(x, y)
        local vt = vector(double, 4)
        return `QuaternionType({vt(x.value[0]*y.value[0] - x.value[1]*y.value[1] - x.value[2]*y.value[2] - x.value[3]*y.value[3],
            x.value[0]*y.value[1] + x.value[1]*y.value[0] + x.value[2]*y.value[3] + x.value[3]*y.value[2],
            x.value[0]*y.value[2] - x.value[1]*y.value[3] + x.value[2]*y.value[0] + x.value[3]*y.value[1],
            x.value[0]*y.value[3] + x.value[1]*y.value[2] - x.value[2]*y.value[1] + x.value[3]*y.value[0])}) 
    end
    -- assert(xt.units == yt.units, "The units are not the same!")
    return `x * y.value
end)

QuaternionTypeFactory = function(ValueType)
    local name = "Quaternion[" .. ValueType.name .. "]"
    local qt = vector(ValueType, 4)
    local t = terralib.types.newstruct(name)

    t.entries = {{field="value", type=qt}}

    -- t.entries = {{field="a", type=ValueType},
    --              {field="b", type=ValueType},
    --              {field="c", type=ValueType},
    --              {field="d", type=ValueType}}
    -- t.value_type = ValueType
    -- We will inherit all the metamethods from the vector value type
    -- but special case when we are multiplying 2 quaternions
    t.metamethods.__mul = mul_quat_macro
    return t
end
    
QuaternionType = QuaternionTypeFactory(double)
print(inspect(QuaternionType))


terra muld(x : double, y : QuaternionType)
    return x * y
end
muld:printpretty()
muld:disas()
terra mul(x : QuaternionType, y : QuaternionType)
    return x * y
end
mul:printpretty()
mul:disas()
