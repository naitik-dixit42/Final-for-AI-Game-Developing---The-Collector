local Player = require("lib.player")
local Enemy = require("lib.enemy")
local Item = require("lib.item")
local Trap = require("lib.trap")
local Game = require("lib.gamemanager")

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    math.randomseed(os.time())
    Game:load()
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    Game:draw()
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end
    Game:keypressed(key)
end

function love.mousepressed(x,y,button)
    Game:mousepressed(x,y,button)
end
