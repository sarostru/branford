-- Numbers that have colors example
-- synes -> Synesthesia
-- I'm calling a "Syne" a colored number
local Synes = {}

-- They obey some simple mixing rules, primary synes
-- may be added to each other and multiplied by each other
-- which will yield a tertiary color. 
-- tertiary colors can be added to each other but also divided by each other to get back the original primary syne.


-- Symbols to use for the colors
local red = "red"
local blue = "blue"
local yellow = "yellow"
local purple = "purple"
local green = "green"
local orange = "orange"

-- Primary/Tertiary Lookup Tables
local PrimaryColors = {red=red, blue=blue, yellow=yellow}
local TertiaryColors = {purple=purple, green=green, orange=orange}

-- Color Table to use
local Colors = {red, blue, yellow, purple, green, orange}

-- Mixing Table for Multiplication
local PrimaryMixings = {
    red={blue=purple, yellow=orange},
    blue={red=purple, yellow=green},
    yellow={blue=green, red=orange}}

-- Mixing Table for Division
local TertiaryMixings = {
    purple={green=blue, orange=red},
    green={purple=blue, orange=yellow},
    orange={purple=red, green=yellow}}


local function make_syne(color, x)
    local terra make (x : double)
        return [Synes[color]]({x=x})
    end
    return make(x)
end

local add_synes_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    assert(xt == yt, string.format("Error: Can only add synes with the same color.  Got %s and %s", xt, yt))
    return `xt({x=x.x + y.x})
end)

local sub_synes_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    assert(xt == yt, string.format("Error: Can only subtract synes with the same color.  Got %s and %s", xt, yt))
    return `xt({x=x.x - y.x})
end)

local mul_synes_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    local x_mixing = PrimaryMixings[xt.color]
    local y_mixing = PrimaryMixings[yt.color]

    assert(xt.color ~= yt.color, string.format("Error: Can't multiply synes of the same color. Got %s and %s", xt, yt))

    assert(x_mixing ~= nil and y_mixing ~= nil, string.format("Error: Can only multiply primary color synes.  Got %s and %s", xt, yt))
    local tertiary_syne = Synes[x_mixing[yt.color]]
    return `tertiary_syne({x=x.x * y.x})
end)

local div_synes_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    local x_mixing = TertiaryMixings[xt.color]
    local y_mixing = TertiaryMixings[yt.color]

    assert(xt.color ~= yt.color, string.format("Error: Can't divide synes of the same color. Got %s and %s", xt, yt))

    assert(x_mixing ~= nil and y_mixing ~= nil, string.format("Error: Can only divide tertiary color synes.  Got %s and %s", xt, yt))
    local primary_syne = Synes[x_mixing[yt.color]]
    return `primary_syne({x=x.x * y.x})
end)

local function make_syne_type(color)
    local level = "Primary"
    if TertiaryColors[color] ~= nil then
        level = "Tertiary"
    elseif PrimaryColors[color] == nil then
        error(string.format("Error: %s is not a valid color", color))
    end 
    local t = terralib.types.newstruct(level .. "Syne." .. color)
    t.entries = {{field="x", type=double}}
    t.metamethods.__add = add_synes_macro
    t.metamethods.__sub = sub_synes_macro
    t.metamethods.__mul = mul_synes_macro
    t.metamethods.__div = div_synes_macro

    t.level = level
    t.color = color
    return t
end

for i, v in ipairs(Colors) do
    Synes[v] = make_syne_type(v)
end

-- Convenience Printing Function
function print_syne(x)
    print(string.format("{color : %s, value : %s}", terralib.typeof(x), x.x))
end

-- Convenience Add Function for Testing the macros
local function add_synes(x, y)
    local terra add(x : terralib.typeof(x), y : terralib.typeof(y))
        return x + y
    end 
    return add(x, y)
end

-- Convenience Sub Function for Testing the macros
local function sub_synes(x, y)
    local terra sub(x : terralib.typeof(x), y : terralib.typeof(y))
        return x - y
    end 
    return sub(x, y)
end

-- Convenience Mul Function for Testing the macros
local function mul_synes(x, y)
    local terra mul(x : terralib.typeof(x), y : terralib.typeof(y))
        return x * y
    end 
    return mul(x, y)
end

-- Convenience Div Function for Testing the macros
local function div_synes(x, y)
    local terra div(x : terralib.typeof(x), y : terralib.typeof(y))
        return x / y
    end 
    return div(x, y)
end

-- Primary
local w = make_syne(yellow, 2)
local x = make_syne(red, 5)
local y = make_syne(blue, 6)
local z = make_syne(red, 3)

-- Tertiary
local p = make_syne(purple, 10)
local q = make_syne(green, 3)
local r = make_syne(orange, -2)

local function print_header(label)
    print("---------------------------")
    print(label)
    print("---------------------------")
end

print_header("Starting Synes")

print_syne(x)
print_syne(y)
print_syne(z)
print_syne(p)
print_syne(q)
print_syne(r)

-- Catch errors and print them
local function print_fail(f, x, y)
    local success
    local error_msg
    success, error_msg = pcall(function () f(x, y) end)
    assert(not success, string.format("Unexpected success with function %s and values %s and %s", f, x, y))
    print(error_msg)
end

-- Addition
print_header("Addition")
print_syne(add_synes(x, z))
print_syne(add_synes(w, w))

print_fail(add_synes, x, y)
print_fail(add_synes, w, x)
print_fail(add_synes, w, y)

-- Subtraction
print_header("Subtraction")
print_syne(sub_synes(x, z))
print_syne(sub_synes(w, w))

print_fail(sub_synes, x, y)
print_fail(sub_synes, w, x)
print_fail(sub_synes, w, y)

-- Multiplication
print_header("Multiplication")
print_syne(mul_synes(x, w))
print_syne(mul_synes(x, y))
print_fail(mul_synes, x, x)

-- Division
print_header("Division")
print_syne(div_synes(p, r))
print_syne(div_synes(p, q))
print_syne(div_synes(q, p))
print_syne(div_synes(r, p))

print_fail(div_synes, r, r)
print_fail(div_synes, r, x)
print_fail(div_synes, x, p)

-- More complex function
local function more_complex(a, b, c, d)
    local terra f (a : terralib.typeof(a), b : terralib.typeof(b), c : terralib.typeof(c), d : terralib.typeof(d))
        return (a + b) * (c + d)
    end
    return f(a, b, c, d)
end

-- Catch errors and print them
local function print_fail_4(f, a, b, c, d)
    local success
    local error_msg
    success, error_msg = pcall(function () f(a, b, c, d) end)
    assert(not success, string.format("Unexpected success with function %s and values %s, %s, %s, and %s", f, a, b, c, d))
    print(error_msg)
end

print_header("Combined Addition and Multiplication")
print_syne(more_complex(x, x, y, y))
print_fail_4(more_complex, x, x, y, z)
print_fail_4(more_complex, p, p, q, q)

-- Taking a look at the a function and the disassembly
local terra eg_func(x : terralib.typeof(x), y : terralib.typeof(y))
    -- N.B. You need the parens here for order of operations
    return (x + x) * (y + y)
end
print("----------------------------------")
print("Pretty Print of Generated Terra")
print("----------------------------------")
print(eg_func:printpretty())
print("----------------------------------")
print("Disassembly of Generated Terra")
print("----------------------------------")
print(eg_func:disas())
