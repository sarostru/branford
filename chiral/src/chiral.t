-- Trying something simpler
-- Wrapping up doubles with some additional chirality information

print("----------------------------------")
print("Manual Chirality with structs")
print("----------------------------------")

-- Left and Right Doubles are totally different, you can't
-- possibly add them to each other
struct LeftDouble  {x : double}
struct RightDouble {x : double}


terra make_left (x : double)
    return LeftDouble({x=x})
end


terra make_right (x : double)
    return RightDouble({x=x})
end


terra add_left (x : LeftDouble, y : LeftDouble)
    return LeftDouble({x=x.x + y.x})
end


terra add_right (x : RightDouble, y : RightDouble)
    return RightDouble({x=x.x + y.x})
end


function print_chiral(x)
    print(string.format("{type : %s, value : %s}", terralib.typeof(x), x.x))
end

print_chiral(make_left(2))
print_chiral(make_right(2))

l = make_left(5) 
r = make_right(6)

-- Can add left and left doubles
print_chiral(add_left(l, l))
-- Can't add left and right doubles
success, error_msg = pcall(function () add_right(l, r) end)
assert(not success)
print(error_msg)

-- This is pretty good, but could we make the chirality a parameter instead?
print("----------------------------------")
print("Parameterized Chirality with Macros")
print("----------------------------------")

-- Attempt #1
-- Make it a struct parameter, seemed plausible but this is
-- quite wrong since it's value will not be available at compile time
-- e.g. struct ChiralDouble {chirality : int, x : double}
-- This doesn't work, we need the value of the chirality earlier

-- Attempt #2
-- Create a different unique struct for each chirality programmatically
-- Use a macro instead of a terra function to make sure the chiralities match
local ChiralityTypes = {"left", "right", "up", "down"}
local Chirality = {}
for i, v in ipairs(ChiralityTypes) do
    t = terralib.types.newstruct("Chirality." .. v)
    t.entries = {{field="x", type=double}}
    Chirality[v] = t
end

local function make_chiral(chiral_type, x)
    local terra make (x : double)
        return chiral_type({x=x})
    end
    return make(x)
end

local add_chiral_macro = macro(function(x, y)
    local xt = x:gettype()
    local yt = y:gettype()
    assert(xt == yt, string.format("Error: chiral mismatch between %s and %s", xt, yt))
    return `xt({x=x.x + y.x})
end)

-- N.B. We can't make one add_chiral terra function, since macros evaluate at 
-- compile time, a function like this cannot have enough information to do the
-- macro checks.  Instead we must only provide a macro
-- terra add_chiral(x : ChiralDouble, y : ChiralDouble)
--     return add_chiral_macro(x, y)
-- end

-- Since we can't have the one function, for convenience in this testing we can
-- wrap calling the macro in a lua function
local function add_chiral(x, y)
    local terra add(x : terralib.typeof(x), y : terralib.typeof(y))
        return add_chiral_macro(x, y)
    end
    return add(x, y)
end

u = make_chiral(Chirality.up, 7)
d = make_chiral(Chirality.down, 4)

print_chiral(u)
print_chiral(d)

-- Can add up to up
print_chiral(add_chiral(u, u))
-- Can add down to down
print_chiral(add_chiral(d, d))
-- Can't add up to down
success, error_msg = pcall(function () print_chiral(add_chiral(d, u)) end)
assert(not success)
print(error_msg)

-- Taking a look at the function and the disassembly
local terra add_up(x : terralib.typeof(u), y : terralib.typeof(u))
    return add_chiral_macro(x, y)
end
print("----------------------------------")
print("Pretty Print of Generated Terra")
print("----------------------------------")
print(add_up:printpretty())
print("----------------------------------")
print("Disassembly of Generated Terra")
print("----------------------------------")
print(add_up:disas())
