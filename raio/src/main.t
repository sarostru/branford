local argparse = require "argparse"
local magick = require "magick"

-- I don't use lua too much, but they recommend patching print like this
-- so that tables get printed reasonably.
local inspect = require "inspect"
local sys_print = print
function print(x) if type(x) == "table" then return sys_print(inspect(x)) else return sys_print(x) end end

local parser = argparse("raio", "Ray Tracer in terra.")
-- No scene file for the moment
--parser:argument("input", "Input scene file (.lua).")
parser:option("-o --output", "Output file (png).", "a.png")
parser:option("-b --background", "Input file for background (.png)", "gold_energy.png") 
--parser:option("-I --include", "Include locations."):count("*")

local args = parser:parse()
-- print(args)  -- Assuming print is patched to handle tables nicely.

-- Point/Vector constructors
-- N.B. Doing this manually since I am thinking these will become
--      the types of the terra version.  We will see if this is the
--      right way to do it or not.
local Point = {}
Point.make = function (x, y, z) return {x=x, y=y, z=z} end
local Vector = {}
Vector.make = function (x, y, z) return {x=x, y=y, z=z} end
Vector.normalize = function(v)
    -- TODO:: Handle close to zero length case
    local s = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    return Vector.make(v.x/s, v.y/s, v.z/s)
end
Vector.scale = function(v, s)
    return Vector.make(v.x * s, v.y * s, v.z * s)
end
Vector.add = function(v, w)
    -- TODO:: Abuse of structural typing here, letting points and vecs add in the same way 
    return Vector.make(v.x + w.x, v.y + w.y, v.z + w.z)
end
-- A Ray
local Ray = {}
Ray.make = function(p, v) 
    return {p = p, u = Vector.normalize(v), t=0}
end
-- A Pixel
local Pixel = {}
Pixel.make = function(r, g, b, a)
    return {r=r, g=g, b=b, a=a}
end
-- A Texture
local Texture = {}
Texture.make = function(file)
    local tex = {}
    tex.file = file
    tex.image = assert(magick.load_image(tex.file))
    tex.width = tex.image:get_width()
    tex.height = tex.image:get_height()
    return tex
end

local pixels = {width = 1, height = 1, units="dimensionless"}

local image = {X = 4, Y = 6}
local resources = {directory = "/home/scott/repos/branford/raio/resources"}
local background = Texture.make(resources.directory .. "/textures/" .. args.background)

-- background.image:set_format("RGB")
-- raw_image = background.image:get_blob()
-- local out = assert(io.open("output.raw", "wb"))
-- out:write(raw_image)
-- for i = 0,10 do
--     print(raw_image[i].unpack('i'))
-- end

-- Set up the POV
-- Coordinates centered around the viewer
--   - (x,y,z)
--   - +'ve y-axis is "up"
--   - +'ve z-axis is the viewing direction
--   - x-axis is across the image 
-- Assume Screen is Centered at (0,0,0)
-- Viewer sits at (0,0,-viewing_distance)
-- Since we want adding pixels to improve the same image and not give a different
-- viewing angle, we instead let the viewing distance shift and fix the ratio between
-- the height of the screen and the viewing distance.
-- That is a constance viewing_angle.
--
-- For an image that is X pixels across and Y pixels up, we imagine that it stretches
-- over the square [-X/2, X/2] x [-Y/2, Y/2] 
-- which gets mapped into physical units.
--
-- For simplicity we will set the viewing angle to 45 degrees
-- by setting viewing_distance to Y/2 * px_height
local viewing_distance = (image.Y / 2) * pixels.height

-- This means we can now get the unit vector direction for each pixel ray 
-- In these comments capitals are Points in 3 space but lowercase is a vector.
-- i.e. P = (1,2,3) is the point (1,2,3)
-- but p = (1,2,3) is the vector
-- and p. is a point plus vector
-- Given point P of each pixel on the screen we can get the direction of the 
-- pixel ray p as,
--   - p = (P - V)/||(P-V)||
-- This pixel ray will travel out from P

-- Background Texture is a png, we scale into the local units and then tile it
-- at "infinite" distance with left bottom corner at (0,0,infinite)
-- The background doesn't get intersected like a normal object, the number is
-- just used to scale the width
background.infinite = 5
background.origin = {x=0, y=0, z=background.infinite}
background.hit = function (bg, ray)
    -- at what x,y does ray.z intersect with background.infinite
    -- p = (x0, y0, z0) + t * (ux, uy, uz)
    local t = (bg.origin.z - ray.p.z) / ray.u.z
    local i = Point.make(Vector.add(ray.p, Vector.scale(ray.u, t)))
    -- get the color at that point
    local x = math.fmod(i.x, bg.width)
    local y = math.fmod(i.y, bg.height)
    return Pixel.make(bg.image:get_pixel(i.x, i.y))
end

for x = -image.X/2, image.X/2 do
    for y = -image.Y/2, image.Y/2 do
        x = x * pixels.width
        y = y * pixels.height
        local P = Point.make(x ,y, 0)
        local V = Point.make(0, 0, -viewing_distance)
        -- print({x = x, y = y, P = P, V = V})
        
    end
end


