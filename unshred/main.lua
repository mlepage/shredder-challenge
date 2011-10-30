-- DARPA Shredder Challenge http://www.shredderchallenge.com/
-- Copyright (C) 2011 Marc Lepage

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local data, img
local w, h
local spans = {}

local function rgb2hsv(r, g, b)
    local max, min = max(r, g, b), min(r, g, b)
    if max == 0 then return -1, 0, 0 end -- rgb is 0, so s = 0, v is undefined
    local delta = max - min
    local s, h = delta / max
    if r == max then
        h =     ( g - b ) / delta -- between yellow & magenta
    elseif g == max then
        h = 2 + ( b - r ) / delta -- between cyan & yellow
    else
        h = 4 + ( r - g ) / delta -- between magenta & cyan
    end
    h = h * 60;                   -- degrees
    if h < 0 then h = h + 360 end
    return h, s, max
end

local function rgb2h(r, g, b)
    local max, min = max(r, g, b), min(r, g, b)
    -- omit check for max==0
    local delta = max - min
    local h
    if r == max then
        h =     ( g - b ) / delta -- between yellow & magenta
    elseif g == max then
        h = 2 + ( b - r ) / delta -- between cyan & yellow
    else
        h = 4 + ( r - g ) / delta -- between magenta & cyan
    end
    h = h * 60;                   -- degrees
    if h < 0 then h = h + 360 end
    return h
end

function filter(x, y, r, g, b, a)
    local h, s, v = rgb2hsv(r, g, b)
    -- text
    if v < 128 then return 0, 0, 0, 255 end
    -- background
    if g < 128 and abs(h - 300) <= 60 then return 128, 128, 128, 0 end
    -- lines
    if v < 224 then return 0, 128, 255, 255 end
    -- paper
    return 255, 255, 0, 255
    --return r, g, b, 255
end

function findspans()
    local spancount = 0
    local r, g, b, a
    local i = -1
    local spanlist = {}
    for y = 0, h-1 do
        for x = 0, w-1 do
            r, g, b, a = data:getPixel(x, y)
            if i == -1 then
                if a ~= 0 then i = x end -- start span
            elseif a == 0 then
                spanlist[#spanlist+1], i = {i, x-1}, -1 -- end span
            end
        end
        if i ~= -1 then
            spanlist[#spanlist+1], i = {i, w-1}, -1 -- end span
        end
        if #spanlist ~= 0 then
            spancount = spancount + #spanlist
            spans[y], spanlist = spanlist, {}
        end
    end
    print("found", spancount)
end

function love.load()
    print("loading image")
    data = love.image.newImageData("puzzle1/puzzle1_(1 of 1)_400dpi.png")
    w, h = data:getWidth(), data:getHeight()
    print("image", w, h)

    print("masking image background")
    data:mapPixel(filter)

    print("finding spans")
    --findspans()

    print("misc")
    img = love.graphics.newImage(data)

    love.graphics.setBackgroundColor(128, 128, 128)
    love.graphics.setColor(255, 255, 255, 255)
end

function love.update(dt)
end

function love.draw()
    love.graphics.draw(img, 0, 0, 0, 1/6, 1/6)
end

function love.keypressed(k)
    if k == "r" then
        love.filesystem.load("main.lua")()
    end
end
