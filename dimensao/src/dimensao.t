-- Trying something simpler
-- I think if I use structs like tags, I could
-- identify those during a macro pass and strip out the 
-- struct and replace it with the underlying datatype.


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

-- Attempt #1
-- Make it a struct parameter, seemed plausible but this is
-- quite wrong since it's value will not be available at compile time
-- e.g. struct ChiralDouble {chirality : int, x : double}
-- This doesn't work, we need the value of the chirality earlier
-- Attempt #2
-- Add additional information directly into the struct table
struct ChiralDouble {x : double}
local Chirality = {left=ChiralDouble,
                   right=ChiralDouble,
                   up=ChiralDouble,
                   down=ChiralDouble}
for i, v in ipairs(chirality) do
    v.chirality = i
end

terra make_up (x : double)
    return [Chirality.up]({x=x})
end

terra make_down (x : double)
    return [Chirality.down]({x=x})
end

local add_chiral_macro = macro(function(x, y)
    print(type(x))
    print(x)
    print(type(y))
    print(y)
    return `ChiralDouble({x=x.x + y.x})
end)


terra add_chiral(x : ChiralDouble, y : ChiralDouble)
    return add_chiral_macro(x, y)
end

local T = {}
for i, v in ipairs(Chirality) do
    T[i] = make_add_chiral(v)
end

u = make_up(7)
d = make_down(4)

print_chiral(u)
print_chiral(d)

-- Can add up to up
print_chiral(add_chiral(u, u))
-- Can add down to down
print_chiral(add_chiral(d, d))
-- Can't add up to down
print_chiral(add_chiral(d, u))



