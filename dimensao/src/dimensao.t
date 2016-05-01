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
