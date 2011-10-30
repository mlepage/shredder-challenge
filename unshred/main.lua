-- DARPA Shredder Challenge http://www.shredderchallenge.com/
-- Copyright (C) 2011 Marc Lepage

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local data, img
local w, h

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
    if (g < 128 and abs(rgb2h(r, g, b) - 300) <= 60) then return r, g, b, 0 end
    return r, g, b, a
end

function love.load()
    print("loading image")
    data = love.image.newImageData("puzzle1/puzzle1_(1 of 1)_400dpi.png")
    w, h = data:getWidth(), data:getHeight()

    print("masking image")
    data:mapPixel(filter)

    img = love.graphics.newImage(data)

    love.graphics.setBackgroundColor(0, 255, 0)
    love.graphics.setColor(255, 255, 255, 255)
end

function love.update(dt)
end

function love.draw()
    love.graphics.draw(img, 0, 0, 0, 0.25, 0.25)
end

function love.keypressed(k)
    if k == "r" then
        love.filesystem.load("main.lua")()
    end
end
