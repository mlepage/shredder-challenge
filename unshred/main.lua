-- DARPA Shredder Challenge http://www.shredderchallenge.com/
-- Copyright (C) 2011 Marc Lepage

local abs, floor, max, min = math.abs, math.floor, math.max, math.min
local asin, sqrt = math.asin, math.sqrt

local data, img
local sx, sy, w, h = 1/6, 1/6
local spans, spancount = {}, 0
local chads, unusedchads = {}, {}
local frame = 0

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

local function chadcontains(chad, x, y)
    local spanlist = chad.spans[y]
    if spanlist then
        for _, span in ipairs(spanlist) do
            if span[1] <= x and x <= span[2] then
                return true
            end
        end
    end
    return false
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
                    local chad = { area=0, spans={}, r=0 }
                    expand(chad, y, span, visited)
                    chads[#chads+1] = chad
                    chad.ox, chad.oy = (chad.xmax - chad.xmin + 1)/2,
                            (chad.ymax - chad.ymin + 1)/2
                    chad.x, chad.y = chad.xmin + chad.ox, chad.ymin + chad.oy
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
            chad.id = #chads
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

function linearregression(points)
    local n, sumx, sumy, sumxy, sumxx = #points, 0, 0, 0, 0
    for _, point in ipairs(points) do
        local x, y = point[1], point[2]
        sumx, sumy = sumx + x, sumy + y
        sumxy, sumxx = sumxy + x*y, sumxx + x*x
    end
    local slope = (n*sumxy - sumx*sumy) / (n*sumxx - sumx*sumx)
    return slope
end

function analyzechads()
    for _, chad in ipairs(chads) do
        -- get span widths
        local widths = {}
        for _, spanlist in pairs(chad.spans) do
            widths[#widths+1] = spanlist[#spanlist][2] - spanlist[1][1] + 1
        end
        -- get median span width
        table.sort(widths)
        if #widths % 2 == 0 then
            chad.swmed = (widths[#widths/2] + widths[#widths/2+1]) / 2
        else
            chad.swmed = widths[(#widths+1)/2]
        end
        -- try to correct orientation to vertical
        local tol = 0.1 * chad.swmed
        local points = {}
        for y = chad.ymin, chad.ymax do
            local spanlist = chad.spans[y]
            local xmin, xmax = spanlist[1][1], spanlist[#spanlist][2]
            local sw = xmax - xmin + 1
            if abs(sw - chad.swmed) <= tol then
                -- get point in chad's coordinte system, but flip x and y
                local xcenter = xmin + sw/2
                points[#points+1] = { y - chad.oy, xcenter - chad.ox }
            --else
                -- color out rows that are ignored
                --for x = xmin, xmax do
                --    data:setPixel(x, y, 255, 0, 255, 255)
                --end
            end
        end
        local slope = linearregression(points)
        local norm = sqrt(1 + slope*slope)
        chad.rot = asin(slope/norm)
        chad.r = chad.rot
    end
end

-- makes an image for each chad
function makechadimages()
    for _, chad in ipairs(chads) do
        local w, h = chad.xmax - chad.xmin + 1, chad.ymax - chad.ymin + 1
        local data2 = love.image.newImageData(w, h)
        data2:paste(data, 0, 0, chad.xmin, chad.ymin, w, h)
        for y = chad.ymin, chad.ymax do
            for x = chad.xmin, chad.xmax do
                if not chadcontains(chad, x, y) then
                    data2:setPixel(x - chad.xmin, y - chad.ymin, 128, 128, 128, 0)
                end
            end
        end
        local image = love.graphics.newImage(data2)
        chad.image = image
    end
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
    analyzechads()
    makechadimages()

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
    frame = frame + 1
    local alt = frame%120 < 60
    for i, chad in ipairs(chads) do
        chad.r = alt and chad.rot or 0
    end
end

function love.draw()
    for i, chad in ipairs(chads) do
        love.graphics.draw(chad.image, chad.x*sx, chad.y*sy,
                chad.r, sx, sy, chad.ox, chad.oy)
    end
    --love.graphics.draw(img, 0, 0, 0, sx, sy)
end

function love.keypressed(k)
    if k == "r" then
        love.filesystem.load("main.lua")()
    end
end

function love.mousepressed(x, y, button)
    if button == "l" then
        local chad = chadat(x/sx, y/sy)
        if chad then
            print("chadat:", chad.id, chad.swmed, chad.slope, chad.rot)
        end
    end
end
