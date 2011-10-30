-- DARPA Shredder Challenge http://www.shredderchallenge.com/
-- Copyright (C) 2011 Marc Lepage

function love.conf(t)
    t.title = "Unshred"
    local w, h = 4676/4, 3609/4
    if w ~= math.floor(w) then w = math.ceil(w) end
    if h ~= math.floor(h) then w = math.ceil(h) end
    t.screen.width = w
    t.screen.height = h
    t.modules.audio = false
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.sound = false
end
