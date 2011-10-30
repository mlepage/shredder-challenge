-- DARPA Shredder Challenge http://www.shredderchallenge.com/
-- Copyright (C) 2011 Marc Lepage

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local data, img
local sx, sy, w, h = 1/6, 1/6
local spans, spancount = {}, 0
local chads, unusedchads = {}, {}

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

local function addspan(spans, y, span)
    local spanlist = spans[y]
    if spanlist == nil then
        spanlist = {}
        spans[y] = spanlist
    end
    for i = #spanlist, 1, -1 do
        local other = spanlist[i]
        if span[2] < other[1] then
            spanlist[i+1] = other
        else
            spanlist[i+1] = span
            break
        end
    end
    if spanlist[1] == spanlist[2] then
        spanlist[1] = span
    end
end

local function removespan(spans, y, span)
    local spanlist = spans[y]
    for i = 1, #spanlist do
        local other = spanlist[i]
        if span[2] < other[1] then
            spanlist[i-1] = other
        end
    end
    spanlist[#spanlist] = nil
end

local function overlap(span1, span2)
    return span1[1] <= span2[2] and span2[1] <= span1[2]
end

-- maps pixels of a chad
local function mapchad(chad, func)
    local r, g, b, a
    for y, spanlist in pairs(chad.spans) do
        for _, span in ipairs(spanlist) do
            for x = span[1], span[2] do
                data:setPixel(x, y, func(x, y, data:getPixel(x, y)))
            end
        end
    end
end

local function chadat(x, y)
    for _, chad in ipairs(chads) do
        if chad.xmin <= x and x <= chad.xmax
                and chad.ymin <= y and y <= chad.ymax then
            return chad
        end
    end
    return nil
end

-- builds an index of all spans in the image
function indexspans()
    print("indexing spans...")
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
    print("spans:", spancount)
end

-- recursively expands a chad from the span
local function expand(chad, y, span, visited)
    -- add visited span to chad
    visited[span] = true
    addspan(chad.spans, y, span)
    -- increase chad area and bounds
    local x1, x2 = span[1], span[2]
    chad.area = chad.area + (x2 - x1 + 1)
    if chad.ymin == nil or y < chad.ymin then chad.ymin = y end
    if chad.ymax == nil or chad.ymax < y then chad.ymax = y end
    if chad.xmin == nil or x1 < chad.xmin then chad.xmin = x1 end
    if chad.xmax == nil or chad.xmax < x2 then chad.xmax = x2 end
    -- recurse to adjacent spans
    local spanlist = spans[y-1]
    if spanlist then
        for _, other in ipairs(spanlist) do
            if not visited[other] and overlap(other, span) then
                expand(chad, y-1, other, visited)
            end
        end
    end
    spanlist = spans[y+1]
    if spanlist then
        for _, other in ipairs(spanlist) do
            if not visited[other] and overlap(other, span) then
                expand(chad, y+1, other, visited)
            end
        end
    end
end

-- builds a chad for each contiguous area of spans
function preparechads()
    print("preparing chads...")
    local visited = {}
    for y = 0, h-1 do
        local spanlist = spans[y]
        if spanlist ~= nil then
            for _, span in ipairs(spanlist) do
                if not visited[span] then
                    local chad = { area=0, spans={} }
                    expand(chad, y, span, visited)
                    chads[#chads+1] = chad
                end
            end
        end
    end
    print("chads:", #chads)
end

-- removes small chads into an unused chad list
function cullchads()
    print("culling chads...")
    local temp = chads
    chads = {}
    local cullcount = 0
    for _, chad in ipairs(temp) do
        local w, h = chad.xmax - chad.xmin + 1, chad.ymax - chad.ymin + 1
        if 50 <= w and w <= 150 and 300 <= h and h <= 600 then
            chads[#chads+1] = chad
        else
            unusedchads[#unusedchads+1] = chad
            -- blank out pixels
            for y, spanlist in pairs(chad.spans) do
                for _, span in ipairs(spanlist) do
                    for x = span[1], span[2] do
                        data:setPixel(x, y, 128, 128, 128, 0)
                    end
                    removespan(spans, y, span)
                end
            end
        end
    end
    print("chads:", #chads)
end

function love.load()
    print("loading image...")
    data = love.image.newImageData("puzzle1/puzzle1_(1 of 1)_400dpi.png")
    w, h = data:getWidth(), data:getHeight()
    print("image:", w, h)

    print("analyzing pixels...")
    data:mapPixel(filter)

    indexspans()
    preparechads()
    cullchads()

    -- color each chad for fun
    --for i, chad in ipairs(chads) do
    --    local function func()
    --        return i*32%256, i*64%256, i*128%256, 255
    --    end
    --    mapchad(chad, func)
    --end

    img = love.graphics.newImage(data)

    love.graphics.setBackgroundColor(128, 128, 128)
    love.graphics.setColor(255, 255, 255, 255)
end

function love.update(dt)
end

function love.draw()
    love.graphics.draw(img, 0, 0, 0, sx, sy)
end

function love.keypressed(k)
    if k == "r" then
        love.filesystem.load("main.lua")()
    end
end

function love.mousepressed(x, y, button)
    if button == "l" then
        print("chadat:", chadat(x/sx, y/sy))
    end
end
