local Player = {}

-- Player expects an optional spritesheet image passed to new().
-- Spritesheet layout: 4 rows (top=down,2=up,3=right,4=left), N columns (frames per row).
function Player:new(x,y,spritesheet,scale)
    local defaultScale = scale or (spritesheet and 1.6 or 1.4)
    local o = {
        x = x or 100,
        y = y or 100,
        w = 28,
        h = 36,
        speed = 180,
        vx = 0,
        vy = 0,
        lives = 3,
        score = 0,
        spawnX = x or 100,
        spawnY = y or 100,
        color = {0.2,0.6,1},
        animTimer = 0,
        animFrame = 1,
        moving = false,
        dirRow = 1, -- 1=down,2=up,3=right,4=left
        sprite = spritesheet,
        quads = nil,
        framesPerRow = 3,
        frameW = nil,
        frameH = nil,
        scale = defaultScale
    }
    setmetatable(o, {__index = self})
    if spritesheet then
        o:setupQuads()
    else
        -- scale the simple rectangle player when no sprite provided
        o.w = math.floor(o.w * o.scale)
        o.h = math.floor(o.h * o.scale)
    end
    return o
end

function Player:setupQuads()
    local img = self.sprite
    local rows = 4
    -- attempt to auto-detect frames per row by assuming square frames
    local imgW, imgH = img:getWidth(), img:getHeight()
    local frameH = math.floor(imgH / rows)
    local frames = math.floor((imgW / frameH) + 0.5)
    if frames < 1 then frames = self.framesPerRow or 3 end
    self.framesPerRow = frames
    local frameW = math.floor(imgW / frames)
    self.frameW = frameW
    self.frameH = frameH
    self.w = math.floor(frameW * self.scale)
    self.h = math.floor(frameH * self.scale)
    self.quads = {}
    for r=1,rows do
        self.quads[r] = {}
        for f=1,frames do
            self.quads[r][f] = love.graphics.newQuad((f-1)*frameW, (r-1)*frameH, frameW, frameH, imgW, imgH)
        end
    end
end

function Player:update(dt, Game) -- The second argument is now the Game object
    local moveX, moveY = 0,0
    if love.keyboard.isDown('left') or love.keyboard.isDown('a') then moveX = moveX -1 end
    if love.keyboard.isDown('right') or love.keyboard.isDown('d') then moveX = moveX +1 end
    if love.keyboard.isDown('up') or love.keyboard.isDown('w') then moveY = moveY -1 end
    if love.keyboard.isDown('down') or love.keyboard.isDown('s') then moveY = moveY +1 end

    local nx = self.x + moveX * self.speed * dt
    local ny = self.y + moveY * self.speed * dt

    -- Reverted to simple AABB collision with walls since color collision is disabled
    local function collidesWithWalls(px,py)
        for _,w in ipairs(Game.world.walls) do
            if px < w.x + w.w and px + self.w > w.x and py < w.y + w.h and py + self.h > w.y then
                return true
            end
        end
        return false
    end

    if not collidesWithWalls(nx, self.y) then self.x = nx end
    if not collidesWithWalls(self.x, ny) then self.y = ny end

    local wasMoving = (moveX ~= 0 or moveY ~= 0)
    -- determine facing direction (prefer horizontal if horizontal movement bigger)
    if wasMoving then
        if math.abs(moveX) >= math.abs(moveY) then
            if moveX > 0 then self.dirRow = 3 else self.dirRow = 4 end
        else
            if moveY > 0 then self.dirRow = 1 else self.dirRow = 2 end
        end
    end

    -- animation
    self.moving = wasMoving
    if self.moving then
        self.animTimer = self.animTimer + dt
        if self.animTimer > 0.12 then
            self.animTimer = 0
            self.animFrame = (self.animFrame % (self.framesPerRow)) + 1
        end
    else
        -- idle frame (middle frame)
        self.animFrame = math.max(1, math.ceil(self.framesPerRow/2))
        self.animTimer = 0
    end
end

function Player:draw()
    if self.sprite and self.quads then
        love.graphics.setColor(1,1,1)
        local quad = self.quads[self.dirRow][self.animFrame]
        love.graphics.draw(self.sprite, quad, math.floor(self.x), math.floor(self.y), 0, self.scale, self.scale)
    else
        love.graphics.setColor(self.color)
        love.graphics.rectangle('fill', self.x, self.y, self.w, self.h, 6,6)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("P", self.x, self.y + 6, self.w, 'center')
    end
end

function Player:reset()
    self.x = self.spawnX
    self.y = self.spawnY
    self.vx = 0
    self.vy = 0
end

function Player:getRect()
    return {x=self.x, y=self.y, w=self.w, h=self.h}
end

function Player:takeDamage()
    self.lives = self.lives - 1
    self:reset()
end

return Player
