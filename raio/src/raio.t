local argparse = require "argparse"
local drimg = require "dromozoa.image"

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

-- Epsilon check
local close_to = function(x, y)
    local epsilon = 0.001
    return math.abs(x - y) < epsilon
end
-- Point/Vector constructors
-- N.B. Doing this manually since I am thinking these will become
--      the types of the terra version.  We will see if this is the
--      right way to do it or not.
local Point = {}
Point.make = function (x, y, z) return {x=x, y=y, z=z} end
local Vector = {}
Vector.make = function (x, y, z) return {x=x, y=y, z=z} end
Vector.magnitude = function(v)
    return v.x * v.x + v.y * v.y + v.z * v.z
end
Vector.normalize = function(v)
    -- TODO:: Handle close to zero length case
    local s = math.sqrt(Vector.magnitude(v))
    return Vector.make(v.x/s, v.y/s, v.z/s)
end
Vector.scale = function(v, s)
    return Vector.make(v.x * s, v.y * s, v.z * s)
end
Vector.sum = function(v)
    return v.x + v.y + v.z
end
Vector.add = function(v, w)
    -- TODO:: Abuse of structural typing here, letting points and vecs add in the same way 
    return Vector.make(v.x + w.x, v.y + w.y, v.z + w.z)
end
Vector.mul = function(v, w)
    return Vector.make(v.x * w.x, v.y * w.y, v.z * w.z)
end
Vector.sub = function(v, w)
    -- TODO:: Abuse of structural typing here, letting points and vecs add in the same way 
    return Vector.make(v.x - w.x, v.y - w.y, v.z - w.z)
end
Vector.dot = function(v, w)
    return Vector.sum(Vector.mul(v, w))
end
-- A Ray
local Ray = {}
Ray.make = function(p, v) 
    return {p = p, u = Vector.normalize(v), t=0}
end
Ray.at = function(ray, t)
    return Vector.add(ray.p, Vector.scale(ray.u, t))
end
-- A Pixel
local Pixel = {}
Pixel.make = function(r, g, b)
    return {r=r, g=g, b=b}
end
-- A Texture
local Texture = {}
Texture.make = function(file)
    local tex = {}
    tex.file = file
    tex.image = drimg.read(assert(io.open(tex.file)))
    tex.width = tex.image:width()
    tex.height = tex.image:height()
    Texture.generate_array(tex)
    return tex
end
Texture.generate_array = function(tex)
    tex.array = {}
    for i = 1, tex.height do
        tex.array[i] = {}
        for j = 1, tex.width do
            tex.array[i][j] = Pixel.make(0,0,0)
        end
    end
    for p in tex.image:each() do
        tex.array[p.y][p.x] = Pixel.make(p.R, p.G, p.B)
    end
end
Texture.at = function(tex, x, y)
    -- (x, y) in [0.0, 1.0]x[0.0, 1.0]
    return {r = 0, g = 0, b = 0}
end

-- Color
--   implements the texture interface
local Color = {}
Color.make = function(r, g, b)
    local color = {r = r, g = g, b = b}
    return color
end
Color.at = function(color, x, y)
    -- (x, y) in [0.0, 1.0]x[0.0, 1.0]
    return color
end
local yellow = Color.make(255, 255, 0)
local white = Color.make(255, 255, 255)

-- Sphere
-- TODO:: Use the polymorphic syntax on objects
local Sphere = {}
Sphere.make = function(center, radius, texture)
    local sphere = {center = center,
                    radius = radius,
                    texture= texture}
    return sphere
end
Sphere.intersection_point = function(sphere, ray)
    -- p = x0,y0,z0 + t * (ux, uy, uz)
    -- r^2 = (x - xc)^2 + (y - yc)^2 + (z - zc)^2
    -- r^2 = (tux + x0 - xc)^2 + (tuy + y0 - yc)^2 + (tuz + z0 - zc)^2
    -- r^2 = t^2 (ux^2 + uy^2 + uz^2) + t (2(uxa) + 2(uyb) + 2(uzc)) + a^2 + b^2 + c^2
    --  A = ux^2 + uy^2 + uz^2
    --  B = 2(ux + a + uy + b + uz + c)
    --  C = a^2 + b^2 + c^2 - r^2
    -- t = (-B +- sqrt(B^2 - 4AC))/(2A)
    local O = Vector.sub(ray.p, sphere.center)
    local A = Vector.magnitude(ray.u) 
    local B = 2 * Vector.sum(Vector.mul(ray.u, O))
    local C = Vector.magnitude(O) - sphere.radius * sphere.radius
    local M = B * B - 4 * A * C
    if M < 0 then
        return {hits = 0, point = nil, normal = nil}
    elseif close_to(M, 0) then
        local t = - B / (2 * A)
        local p = Ray.at(ray, t)
        local n = Vector.normalize(Vector.sub(p, sphere.center))
        return {hits = 1, point = p, normal = n}
    else
        -- "The minus path is always less", quoth the Miser
        local t = (-B - math.sqrt(M)) / (2 * A)
        local p = Ray.at(ray, t)
        local n = Vector.normalize(Vector.sub(p, sphere.center))
        return {hits = 2, point = p, normal = n}
    end
end
Sphere.spherical_coords = function(point)
    local coords = {theta = 0, phi = 0}
    coords.theta = math.acos(point.z / sphere.r)
    coords.phi = math.atan(point.y / point.x)
    return coords
end
Sphere.hit = function(sphere, ray)
    local hit = Sphere.intersection_point(sphere, ray)
    -- local coords = Sphere.spherical_coords(point)
    -- TODO:: actual mapping
    local coords = {theta = 0.0, phi = 0.0}
    -- TODO:: Have to use the colon self syntax instead of color
    local color = Color.at(sphere.texture,
                           coords.theta, coords.phi)
    hit['color'] = color
    return hit
end

local pixels = {width = 0.5, height = 0.5, units="dimensionless"}

-- image format required for drimg header
local image_desc = {
    width = 800;
    height = 800;
    channels = 3;
    min = 0;
    max = 255;
}
local image = drimg(image_desc)
local resources = {directory = "/home/scott/repos/branford/raio/resources"}
local background = Texture.make(resources.directory .. "/textures/" .. args.background)

print({width = background.image:width(),
       height = background.image:height(),
       channels = background.image:channels(),
       min = background.image:min(),
       max = background.image:max()})

local LightSource = {}
LightSource.make = function(point, intensity, color)
    local ls = {}
    ls.point = point
    ls.intensity = intensity
    ls.color = color
    return ls
end

local scene = {}
scene.objects = {Sphere.make(Point.make(0, 30, 50), 40, yellow)}
scene.light_source = LightSource.make(Point.make(-100, -100, -100), 100, white)
scene.ambient_light_intensity = 0.25
-- TODO:: shininess should be attached to the objects
scene.shininess = 32

local Shader = {}
Shader.phong = function(scene, ray, hit)
    local Lp = scene.light_source.point
    local Ip = scene.light_source.intensity
    local Ia = scene.ambient_light_intensity
    local p = hit.point
    local n = hit.normal
    local c = hit.color
    -- I = ambient + diffuse + specular

    local light_dir = Vector.normalize(Vector.sub(Lp, p))
    local lambertian = math.max(Vector.dot(light_dir, n), 0)
    local specular = 0
    if lambertian > 0 then
        local half_dir = Vector.normalize(Vector.add(Vector.sub(Vector.make(0,0,0), ray.u), light_dir))
        local spec_angle = math.max(Vector.dot(half_dir, n), 0)
        specular = math.pow(spec_angle, scene.shininess)
    end
    local cv = Vector.make(c.r, c.g, c.b)
    local Ac = Vector.scale(cv, Ia)
    local Dc = Vector.scale(cv, lambertian)
    local Sc = Vector.scale(cv, specular)
    local rv = Vector.add(Ac, Vector.add(Dc, Sc))
    rv = Vector.make(math.min(rv.x, 255), math.min(rv.y, 255), math.min(rv.z, 255))
    return Color.make(math.floor(rv.x), math.floor(rv.y), math.floor(rv.z))
end


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
-- For an image that is width pixels across and height pixels up, we imagine that it stretches
-- over the square [-width/2, width/2] x [-height/2, height/2] 
-- which gets mapped into physical units.
--
-- For simplicity we will set the viewing angle to 45 degrees
-- by setting viewing_distance to height/2 * px_height
local viewing_distance = (image:height() / 2) * pixels.height

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
local round_to_index = function(x, n)
    return math.floor(x % n) + 1
end
background.infinite = 200
background.origin = {x=0, y=0, z=background.infinite}
background.hit = function (bg, ray)
    -- at what x,y does ray.z intersect with background.infinite
    -- p = (x0, y0, z0) + t * (ux, uy, uz)
    local t = (bg.origin.z - ray.p.z) / ray.u.z
    local i = Ray.at(ray, t)
    -- get the color at that point
    local x = round_to_index(i.x, bg.width)
    local y = round_to_index(i.y, bg.height)
    return bg.array[y][x]
end

for p in image:each() do
    local x = (p.x - 1 - image:width()/2) * pixels.width
    local y = (p.y - 1 - image:height()/2) * pixels.height
    local P = Point.make(x ,y, 0)
    local V = Point.make(0, 0, -viewing_distance)
    local ray = Ray.make(P, Vector.sub(P, V))
    local hit = nil
    for i, object in ipairs(scene.objects) do
        -- TODO:: what you want more than spheres?
        hit = Sphere.hit(object, ray)
    end
    if hit.point == nil then
        local c = background.hit(background, ray)
        p:rgb(c.r, c.g, c.b)
    else
        local actual_color = Shader.phong(scene, ray, hit)
        p:rgb(actual_color.r, actual_color.g, actual_color.b)
    end
end
image:write_png(assert(io.open("test.png", "wb"))):close()
