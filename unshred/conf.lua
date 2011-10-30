-- DARPA Shredder Challenge http://www.shredderchallenge.com/
-- Copyright (C) 2011 Marc Lepage

function love.conf(t)
    t.title = "Unshred"
    local w, h = 4676/6, 3609/6
    if w ~= math.floor(w) then w = math.ceil(w) end
    if h ~= math.floor(h) then h = math.ceil(h) end
    t.screen.width = w
    t.screen.height = h
    t.modules.audio = false
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.sound = false
end
