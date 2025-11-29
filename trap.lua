local Trap = {}
Trap.__index = Trap

-- Define different types of traps
Trap.types = {
    spike = {
        frames = 8,
        animSpeed = 8,
        damageFrame = 4, -- Frame when damage is applied
        scale = 1.5,
        row = 2 -- Which row on the spritesheet to use (1, 2, or 3)
    },
    fire = {
        frames = 29, -- From looking at Fire_Trap.png
        animSpeed = 12,
        damageFrame = 15, -- A frame in the middle of the big fire animation
        scale = 1.5
    }
}

function Trap:new(x, y, type, sprite)
    local t = setmetatable({}, Trap)
    t.x = x
    t.y = y
    t.type = type
    t.sprite = sprite

    local props = Trap.types[type] or {}
    t.frames = props.frames or 1
    t.animSpeed = props.animSpeed or 10
    t.damageFrame = props.damageFrame or 1
    t.scale = props.scale or 1
    t.row = props.row or 1

    t.currentFrame = 1
    t.animTimer = 0
    t.damaging = false

    if t.sprite then
        -- The spritesheet has 25 frames horizontally. Each frame is 40px wide (1000/25).
        local frameW = 40
        local frameH = t.sprite:getHeight() / 3 -- Assuming 3 rows in the spritesheet
        t.w = frameW * t.scale
        t.h = frameH * t.scale
        -- The spike animation starts after the first 12 frames (12 * 40 = 480px)
        local animationStartX = 480
        t.quad = love.graphics.newQuad(animationStartX, 0, frameW, frameH, t.sprite:getWidth(), t.sprite:getHeight())
    end

    return t
end

function Trap:update(dt)
    self.animTimer = self.animTimer + dt * self.animSpeed
    self.currentFrame = (math.floor(self.animTimer) % self.frames) + 1
    self.damaging = (self.currentFrame == self.damageFrame)
    local frameW = 40 -- Each frame is 40px wide
    local frameH = self.sprite:getHeight() / 3 -- Assuming 3 rows
    local animationStartX = 480 -- Spike animation starts at pixel 480
    self.quad:setViewport(animationStartX + (self.currentFrame - 1) * frameW, (self.row - 1) * frameH, frameW, frameH)
end

function Trap:draw()
    if self.sprite then love.graphics.draw(self.sprite, self.quad, self.x, self.y, 0, self.scale, self.scale) end
end

function Trap:getRect() return {x=self.x, y=self.y, w=self.w, h=self.h} end

return Trap