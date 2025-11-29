local Item = {}

Item.types = {
    -- All gems are now static images, using only the first frame of their spritesheet.
    green_gem       = { frames = 1, scale = 1.5 },
    red_gem         = { frames = 1, scale = 1.5 },
    dark_purple_gem = { frames = 1, scale = 1.5 },
    purple_gem      = { frames = 1, scale = 1.5 },
    blue_gem        = { frames = 1, scale = 1.5 }
}

function Item:new(type, x, y, sprite)
    local t = Item.types[type]
    local o = {
        x = x or 0,
        y = y or 0,
        type = type or 'coin',
        color = t.color,
        w = t.w or 0, -- Base width for non-sprite items, default to 0
        h = t.h or 0, -- Base height for non-sprite items, default to 0
        sprite = sprite,
        scale = t.scale or 1.0,
        frames = t.frames or 1, -- Use frames from type definition directly
        collected = false,
        quads = {},
        animTimer = math.random() * 0.5,
        animFrame = 1,
        -- Store the original frame size from the spritesheet
        frameW = 0,
        frameH = 0
    } 
    o.props = t -- Keep a reference to the type properties
    setmetatable(o, {__index = self})
    if o.sprite then
        o:setupQuads()
    end
    return o
end

function Item:setupQuads()
    local img = self.sprite
    if not img then return end

    local imgW, imgH = img:getWidth(), img:getHeight()
    -- Each gem is a vertical spritesheet
    self.frameW = imgW
    self.frameH = math.floor(imgH / self.frames)

    for f=1,self.frames do
        self.quads[f] = love.graphics.newQuad(0, (f-1) * self.frameH, self.frameW, self.frameH, imgW, imgH)
    end
    self.w = self.frameW * self.scale
    self.h = self.frameH * self.scale
end

function Item:update(dt)
    -- No animation needed anymore.
end

function Item:draw()
    if self.collected then return end
    
    local defaultFilter = love.graphics.getDefaultFilter()
    love.graphics.setDefaultFilter("nearest", "nearest")

    if self.sprite then
        love.graphics.setColor(1,1,1)
        -- Always draw the first (and only) frame.
        if self.quads[1] then
            local quad = self.quads[1] 
            love.graphics.draw(self.sprite, quad, math.floor(self.x), math.floor(self.y), 0, self.scale, self.scale)
        end
    else
        love.graphics.rectangle('fill', self.x, self.y, self.w, self.h, 6,6)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(string.sub(self.type,1,1):upper(), self.x, self.y + 4, self.w, 'center')
    end

    love.graphics.setDefaultFilter(defaultFilter)
end

function Item:getRect()
    return {x = self.x, y = self.y, w = self.w, h = self.h}
end

return Item
