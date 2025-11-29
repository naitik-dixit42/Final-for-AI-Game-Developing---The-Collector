local Enemy = {}

-- Enemy supports optional directional sprites: table with keys 'up','down','left','right'
function Enemy:new(path, speed, sprites, scale)
    local o = {
        path = path or {{x=400,y=200},{x=600,y=200}},
        idx = 1,
        x = path and path[1].x or 400,
        y = path and path[1].y or 200,
        w = 30,
        h = 30,
        speed = speed or 100,
        chaseRange = 160,
        state = 'patrol',
        color = {1,0.3,0.3},
        sprites = sprites or {},
        quads = {},
        frameCounts = {},
        animTimer = 0,
        animFrame = 1,
        scale = scale or 1,
        prevX = nil,
        prevY = nil,
        facing = 'down'
    }
    setmetatable(o, {__index = self})
    o:setupSprites()
    o.prevX = o.x
    o.prevY = o.y
    return o
end

function Enemy:setupSprites()
    -- For each direction image, create quads horizontally (frames in a row)
    for _,dir in ipairs({'down','up','right','left'}) do
        local img = self.sprites[dir]
        if img then
            local imgW, imgH = img:getWidth(), img:getHeight()
            local frames = math.max(1, math.floor((imgW / imgH) + 0.5))
            self.frameCounts[dir] = frames
            self.quads[dir] = {}
            self.baseFrameW = self.baseFrameW or {}
            self.baseFrameH = self.baseFrameH or {}
            for f=1,frames do
                self.quads[dir][f] = love.graphics.newQuad((f-1)*(imgW/frames), 0, imgW/frames, imgH, imgW, imgH)
            end
            -- record base frame size for this direction
            self.baseFrameW[dir] = math.floor(imgW / frames)
            self.baseFrameH[dir] = math.floor(imgH)
            -- size from image frame (initial)
            self.w = math.floor(self.baseFrameW[dir] * self.scale)
            self.h = math.floor(self.baseFrameH[dir] * self.scale)
        else
            self.frameCounts[dir] = 0
            self.quads[dir] = nil
        end
    end
end

function Enemy:matchSize(targetW, targetH)
    -- Find first available base frame and compute scale so rendered width matches targetW
    for _,dir in ipairs({'down','up','right','left'}) do
        local baseW = self.baseFrameW and self.baseFrameW[dir]
        local baseH = self.baseFrameH and self.baseFrameH[dir]
        if baseW and baseW > 0 then
            -- match width primarily
            local newScale = targetW / baseW
            self.scale = newScale
            self.w = math.floor(baseW * self.scale)
            self.h = math.floor(baseH * self.scale)
            return
        end
    end
end

function Enemy:update(dt, player, world)
    -- distance to player
    local dx = player.x - self.x
    local dy = player.y - self.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < self.chaseRange then
        self.state = 'chase'
    else
        self.state = 'patrol'
    end

    local moveX, moveY = 0,0
    if self.state == 'chase' then
        if dist > 0 then
            moveX = (dx/dist) * self.speed * dt
            moveY = (dy/dist) * self.speed * dt
        end
    else
        local target = self.path[self.idx]
        local pdx = target.x - self.x
        local pdy = target.y - self.y
        local pdist = math.sqrt(pdx*pdx + pdy*pdy)
        if pdist < 6 then
            self.idx = self.idx % #self.path + 1
        else
            moveX = (pdx/pdist) * self.speed * dt
            moveY = (pdy/pdist) * self.speed * dt
        end
    end

    local nx = self.x + moveX
    local ny = self.y + moveY

    -- Use the Game object's collision check, which now handles both old walls and the new color map
    if not world:enemyCollides({x=nx, y=self.y, w=self.w, h=self.h}) then self.x = nx end
    if not world:enemyCollides({x=self.x, y=ny, w=self.w, h=self.h}) then self.y = ny end

    -- determine facing from movement vector
    local mvx = self.x - (self.prevX or self.x)
    local mvy = self.y - (self.prevY or self.y)

    -- animation
    local moving = (math.abs(mvx) + math.abs(mvy)) > 0.001
    if moving and (self.frameCounts[self.facing] or 0) > 1 then
        self.animTimer = self.animTimer + dt
        if self.animTimer > 0.14 then
            self.animTimer = 0
            local count = self.frameCounts[self.facing]
            self.animFrame = (self.animFrame % count) + 1
        end
    else
        -- idle to first frame
        self.animFrame = 1
        self.animTimer = 0
    end

    if moving then
        if math.abs(mvx) >= math.abs(mvy) then
            if mvx > 0 then self.facing = 'right' elseif mvx < 0 then self.facing = 'left' end
        else
            if mvy > 0 then self.facing = 'down' elseif mvy < 0 then self.facing = 'up' end
        end
    end

    self.prevX = self.x
    self.prevY = self.y
end

function Enemy:draw()
    if self.quads and self.quads[self.facing] then
        local img = self.sprites[self.facing]
        local frame = math.min(self.animFrame, math.max(1, self.frameCounts[self.facing]))
        local quad = self.quads[self.facing][frame]
        love.graphics.setColor(1,1,1)
        love.graphics.draw(img, quad, math.floor(self.x), math.floor(self.y), 0, self.scale, self.scale)
    else
        love.graphics.setColor(self.color)
        love.graphics.rectangle('fill', self.x, self.y, self.w, self.h, 6,6)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("E", self.x, self.y + 6, self.w, 'center')
    end
end

function Enemy:getRect()
    return {x=self.x, y=self.y, w=self.w, h=self.h}
end

return Enemy
