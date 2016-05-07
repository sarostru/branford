
-- Learned that you can use macros to redirect field names
local struct Vector {x : double; y : double; z : double}

local Color = terralib.types.newstruct("Color")
Color.entries = {{"r", double}, {"g", double}, {"b", double}}
Color.metamethods.__entrymissing = macro(function(f, o)
    if f == "x" then return `o.r
    elseif f == "y" then return `o.g
    elseif f == "z" then return `o.b
    -- TODO:: This way of raising an error doesn't seem to work well, the error message doesn't show up anywhere
    else error("No field " .. f .. " in terra object " .. o)
    end
end)

terra dot(v : Vector, c : Color)
    return v.x * c.x + v.y * c.y + v.z * c.z
end

function show_terra(f)
    print("----------------------------------")
    print("Pretty Print of Generated Terra")
    print("----------------------------------")
    print(f:printpretty())
    print("----------------------------------")
    print("Disassembly of Generated Terra")
    print("----------------------------------")
    print(f:disas())
end

print(dot({x=1, y=2, z=3}, {r=1, g=0.5, b=1.0/3}))
show_terra(dot)

-- Example session showing the error message currently with the
-- raising error call 
-- $ terra -i dimensao.t
-- > terra wrong(v : Vector, c : Color)
-- >> return v.x * c.q
-- >> end
-- [string "stdin"]:1: Errors reported during function declaration.
-- [string "stdin"]:1: expected a type but found nil
-- [string "stdin"]:1: expected a type but found nil
-- 
-- stack traceback:
--     [C]: in function 'error'
--     src/terralib.lua:388: in function 'finishandabortiferrors'
--     src/terralib.lua:1086: in function 'defineobjects'
--     [string "stdin"]:1: in main chunk



    
