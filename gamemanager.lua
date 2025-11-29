local Player = require('lib.player')
local Enemy = require('lib.enemy')
local Item = require('lib.item')

local Game = {}

function Game:load()
    self.width = love.graphics.getWidth()
    self.height = love.graphics.getHeight()

    -- Load the new background image
    -- Try to load the background, checking for both lowercase and uppercase extensions
    -- to solve the file loading error.
    -- TEMPORARILY DISABLED color collision to fix loading error.
    -- We will only use the hard-coded walls for now.
    -- Load a separate collision map for detecting spike damage.
    self.collisionMapData = love.image.newImageData('collision_map.png')
    self.background = love.graphics.newImage('background.png')

    -- Load new individual UI images
    self.ui = {}
    self.ui.playButton = love.graphics.newImage('Play_UI.png')
    self.ui.titleBG = love.graphics.newImage('Title_UI.png')
    self.ui.questionMark = love.graphics.newImage('questionmark_UI.png')

    -- Add checks for critical UI images
    if not self.ui.playButton then error("Could not load 'Play_UI.png'. Make sure it is in the correct folder.") end
    if not self.ui.titleBG then error("Could not load 'Title_UI.png'. Make sure it is in the correct folder.") end

    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local image_width = self.background:getWidth()
    local image_height = self.background:getHeight()

    self.bgScaleX = window_width / image_width
    self.bgScaleY = window_height / image_height

    -- simple world with walls
    self.world = {walls = {}}
    -- KEEPING Wall 1 and Wall 2 as requested
    -- Wall 1 (Top row of boxes)
    table.insert(self.world.walls, {x=197, y=230.25, w=282.5, h=57.5})
    -- Wall 2 (Bottom row of boxes)
    table.insert(self.world.walls, {x=583.125, y=374.25, w=281.625, h=61.25})
    -- Wall 3 (borders and archway) re-added as physical walls since color collision is disabled.
    table.insert(self.world.walls, {x=0,y=0,w=self.width,h=90}) -- Top border, height changed
    table.insert(self.world.walls, {x=0,y=self.height-50,w=self.width,h=50}) -- Bottom border
    table.insert(self.world.walls, {x=0,y=0,w=10,h=self.height}) -- Left border, width changed
    table.insert(self.world.walls, {x=self.width-10,y=0,w=10,h=self.height}) -- Right border, width and x-pos changed
    
    -- player (use spritesheet if available)
    local okImg
    if love.filesystem.getInfo('player_spritesheet.png') then
        okImg = love.graphics.newImage('player_spritesheet.png')
    end
    -- pass a scale to make the player larger on screen
    -- make player a little bigger
    self.player = Player:new(self.width / 2, self.height - 160, okImg, 1.5) -- Start in front of the bottom door, moved up more

    -- enemies (load directional sprites if present)
    local enemySprites = {}
    local function tryLoad(name)
        if love.filesystem.getInfo(name) then
            return love.graphics.newImage(name)
        end 
        return nil
    end
    enemySprites.up = tryLoad('enemy_up.png')
    enemySprites.down = tryLoad('enemy_down.png')
    enemySprites.right = tryLoad('enemy_right.png')
    enemySprites.left = tryLoad('enemy_left.png')

    self.enemies = {}
    -- Enemy 1: Patrols the top corridor
    local path1 = {{x=420,y=180},{x=680,y=180}}
    table.insert(self.enemies, Enemy:new(path1, 110, enemySprites, 1.2))

    -- Enemy 2: Patrols the bottom area
    local path2 = {{x=300,y=480},{x=650,y=480},{x=650,y=380},{x=300,y=380}} -- Adjusted path to avoid bottom-left rock
    table.insert(self.enemies, Enemy:new(path2, 100, enemySprites, 1.2))

    -- Enemy 3: Patrols vertically on the left side
    table.insert(self.enemies, Enemy:new({{x=100,y=100},{x=100,y=500}}, 80, enemySprites, 1.2)) -- This path is clear

    for _,e in ipairs(self.enemies) do
        -- clamp enemy position inside playable area (avoid overlapping border walls)
        local minX = 10 + 2
        local minY = 10 + 2
        local maxX = self.width - 10 - e.w - 2
        local maxY = self.height - 10 - e.h - 2
        e.x = math.max(minX, math.min(maxX, e.x))
        e.y = math.max(minY, math.min(maxY, e.y))
        -- also clamp path waypoints so the enemy can move between valid points
        for _,pt in ipairs(e.path) do
            pt.x = math.max(minX, math.min(maxX, pt.x))
            pt.y = math.max(minY, math.min(maxY, pt.y))
        end
    end
    -- make enemies a lot bigger than the player by scaling the target size
    local enemySizeMultiplier = 1.8 -- Reduced size to help with navigation
    for _,e in ipairs(self.enemies) do
        if self.player and self.player.w then
            e:matchSize(self.player.w * enemySizeMultiplier, self.player.h * enemySizeMultiplier)
        end
    end

    -- items container
    self.items = {}

    -- load item sprites
    self.itemSprites = {}
    self.uiItemQuads = {}
    -- Load individual gem sprites
    local gemNames = {
        green_gem = 'gem_green.png',
        red_gem = 'gem_red.png',
        dark_purple_gem = 'gem_violet.png', -- Assuming violet is dark purple
        purple_gem = 'gem_purple.png',
        blue_gem = 'gem_blue.png'
    }
    for itemType, filename in pairs(gemNames) do
        if love.filesystem.getInfo(filename) then
            self.itemSprites[itemType] = love.graphics.newImage(filename)
        end
    end

    -- required counts
    self.requirements = {
        green_gem = 5, red_gem = 4, dark_purple_gem = 3, purple_gem = 2, blue_gem = 1 -- Note: dark_purple_gem uses gem_violet.png
    }
    self.collected = {
        green_gem = 0, red_gem = 0, dark_purple_gem = 0, purple_gem = 0, blue_gem = 0
    }
    -- List of item types that can spawn
    self.itemTypesToSpawn = {'green_gem', 'red_gem', 'dark_purple_gem', 'purple_gem', 'blue_gem'}

    self.spawnTimer = 0
    self.spawnInterval = 1.0
    self.maxItems = 12
    self.elapsedTime = 0

    self.state = 'start' -- 'start', 'playing', 'win', 'gameover', 'help'

    -- synth sounds
    self.sounds = {}
    self.sounds.collect = self:makeBeep(880, 0.08)
    self.sounds.hit = self:makeBeep(220, 0.16)
    self.sounds.win = self:makeBeep(1320, 0.5)

    -- Load music from mp3 files
    self.music = {}
    self.music.intro = love.audio.newSource('intro.mp3', 'stream')
    self.music.game = love.audio.newSource('music.mp3', 'stream')
    self.musicEnabled = true
    self.music.intro:setLooping(true)
    self.music.game:setLooping(true)

    -- Fonts for UI
    self.defaultFont = love.graphics.newFont('BungeeSpice-Regular.ttf', 14)
    self.titleFont = love.graphics.newFont('BungeeSpice-Regular.ttf', 32) -- Reduced title font size
    self.instructFont = love.graphics.newFont('BungeeSpice-Regular.ttf', 20) -- Slightly smaller for instructions
    love.graphics.setFont(self.defaultFont) -- Set the default font for the game

    -- Play intro music on start screen
    if self.musicEnabled then
        self.music.intro:play()
    end
end

function Game:update(dt)
    -- Only update game logic when in the 'playing' state
    if self.state ~= 'playing' then
        -- We still want item animations to play in the background on win/gameover screens
        if self.state == 'win' or self.state == 'gameover' then self:updateItems(dt) end
        return
    end

    -- update player
    self.player:update(dt, self) -- Pass the whole Game object to the player
    self.elapsedTime = self.elapsedTime + dt

    -- update enemies
    for _,e in ipairs(self.enemies) do
        e:update(dt, self.player, self) -- Pass the whole Game object, not just self.world
    end

    self:updateItems(dt)
    -- spawn items
    self.spawnTimer = self.spawnTimer + dt
    if self.spawnTimer >= self.spawnInterval then
        self.spawnTimer = 0
        if #self.items < self.maxItems then
            self:spawnRandomItem()
        end
    end

    -- check collisions item<->player
    for i=#self.items,1,-1 do
        local it = self.items[i]
        if not it.collected and self:rectsOverlap(it:getRect(), self.player:getRect()) then
            it.collected = true
            self.collected[it.type] = (self.collected[it.type] or 0) + 1
            self.player.score = self.player.score + 10
            self.sounds.collect:stop()
            self.sounds.collect:play()
            table.remove(self.items, i)
        end
    end

    -- player <-> enemy
    for _,e in ipairs(self.enemies) do
        if self:rectsOverlap(e:getRect(), self.player:getRect()) then
            self.player:takeDamage()
            self.sounds.hit:stop()
            self.sounds.hit:play()
            if self.player.lives <= 0 then
                self.state = 'gameover'
                self.music.game:stop()
            end
        end
    end

    -- Check for spike tile collision
    if self:checkSpikeCollision() then
        self.player:takeDamage()
        self.sounds.hit:stop()
        self.sounds.hit:play()
        if self.player.lives <= 0 then
            self.state = 'gameover'
            self.music.game:stop()
        end
    end

    -- win condition
    local allok = true
    for k,v in pairs(self.requirements) do
        if (self.collected[k] or 0) < v then allok = false end
    end
    if allok then
        self.state = 'win'
        self.music.game:stop()
        self.sounds.win:play()
    end
end

function Game:draw()
    -- background
    love.graphics.setColor(1,1,1)
    love.graphics.draw(self.background, 0, 0, 0, self.bgScaleX, self.bgScaleY)

    -- DEBUG: Draw wall hitboxes. You can remove this when you are done positioning them.
    -- REMOVED: Debug drawing of wall hitboxes
    -- love.graphics.setColor(1, 0, 0, 0.4) -- Semi-transparent red
    -- for _, wall in ipairs(self.world.walls) do
    --     love.graphics.rectangle('fill', wall.x, wall.y, wall.w, wall.h)
    -- end

    -- draw items
    for _,it in ipairs(self.items) do it:draw() end

    -- draw enemies
    for _,e in ipairs(self.enemies) do e:draw() end

    -- draw player
    self.player:draw()

    -- UI
    -- Draw a semi-transparent panel behind the UI for readability
    love.graphics.setColor(0,0,0,0.4)
    love.graphics.rectangle('fill', 10, 10, 180, 215, 10, 10)

    love.graphics.setColor(0,0,0)
    
    -- Draw Lives
    love.graphics.setColor(1,1,1) -- White text for readability
    love.graphics.print(string.format("Lives: %d", self.player.lives), 22, 22)

    love.graphics.print(string.format("Score: %d", self.player.score), 22, 45)

    -- Draw Timer
    local minutes = math.floor(self.elapsedTime / 60)
    local seconds = math.floor(self.elapsedTime % 60)
    love.graphics.print(string.format("Time: %02d:%02d", minutes, seconds), 22, 68)

    local y = 93
    local itemOrder = self.itemTypesToSpawn -- Control display order
    for _, k in ipairs(itemOrder) do
        local v = self.requirements[k]
        if v then
            -- Use the dedicated UI coin icon for coins, otherwise use the item's own sprite
            local spriteToDraw = self.itemSprites[k]

            -- Use animated quads for UI icons
            if spriteToDraw then
                local itemInfo = Item.types[k]
                local w, h = spriteToDraw:getDimensions()
                local frameH = math.floor(h / (itemInfo.frames or 1))
                local quadToDraw = love.graphics.newQuad(0, 0, w, frameH, w, h)
                local qW, qH = w, frameH
                local targetSize = 24 -- Set a standard size for all gem icons in the UI
                local scale = targetSize / qW
                -- Calculate vertical offset to center the icon with the text line
                local iconHeight = qH * scale
                local fontHeight = love.graphics.getFont():getHeight()
                local yOffset = (fontHeight - iconHeight) / 2
                love.graphics.draw(spriteToDraw, quadToDraw, 20, y + yOffset, 0, scale, scale)
            end
            love.graphics.setColor(1,1,1) -- White text for readability
            love.graphics.print(string.format(": %d / %d", (self.collected[k] or 0), v), 50, y)
            y = y + 28
        end
    end
    
    if self.state == 'start' then
        love.graphics.setColor(0,0,0,0.7)
        love.graphics.rectangle('fill', 0,0,self.width,self.height)
        love.graphics.setColor(1,1,1)

        -- Draw Title with background
        local titleX = self.width / 2
        local titleY = self.height/2 - 120
        love.graphics.draw(self.ui.titleBG, titleX, titleY, 0, 1.5, 1.5, self.ui.titleBG:getWidth()/2, self.ui.titleBG:getHeight()/2) -- Made title background smaller
        love.graphics.setFont(self.titleFont)
        love.graphics.printf('The Collector', 0, titleY - 16, self.width, 'center') -- Adjusted Y for smaller title

        -- Draw Play Button
        local buttonX = self.width / 2
        local buttonY = self.height/2 + 20
        love.graphics.draw(self.ui.playButton, buttonX, buttonY, 0, 1.2, 1.2, self.ui.playButton:getWidth()/2, self.ui.playButton:getHeight()/2) -- Made play button smaller

        -- Draw Question Mark Button
        local qX = self.width - 120  -- Moved 80px more from the right
        local qY = self.height - 120 -- Moved 80px more from the bottom
        love.graphics.draw(self.ui.questionMark, qX, qY, 0, 1.2, 1.2) -- Made question mark smaller

        love.graphics.setFont(self.instructFont)
        love.graphics.printf('Press Enter or Click Play', 0, buttonY + 60, self.width, 'center')

        -- Draw Music Toggle
        local musicText = "Music: " .. (self.musicEnabled and "ON" or "OFF")
        love.graphics.printf(musicText, 0, self.height - 40, self.width, 'center')

        love.graphics.setFont(self.defaultFont) -- Reset to default font

    elseif self.state == 'help' then
        love.graphics.setColor(0,0,0,0.8)
        love.graphics.rectangle('fill', 0,0,self.width,self.height)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(self.instructFont)
        love.graphics.printf("How to Play\n\nUse WASD or Arrow Keys to move.\n\nCollect all the required items to win!\n\nAvoid the enemies and traps.\n\n\n(Press Enter or Click to return)", 0, self.height/3, self.width, 'center')
    elseif self.state == 'win' then
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle('fill', 0,0,self.width,self.height)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(self.titleFont)
        love.graphics.printf('You Win!', 0, self.height/2 - 80, self.width, 'center')
        love.graphics.setFont(self.instructFont)
        love.graphics.printf('Press R to Play Again', 0, self.height/2 + 20, self.width, 'center')
        love.graphics.printf('Press Enter for Title Screen', 0, self.height/2 + 50, self.width, 'center')
        love.graphics.setFont(self.defaultFont)
    elseif self.state == 'gameover' then
        love.graphics.setColor(0.4, 0, 0, 0.7) -- Dark red overlay
        love.graphics.rectangle('fill', 0,0,self.width,self.height)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(self.titleFont)
        love.graphics.printf('Game Over', 0, self.height/2 - 80, self.width, 'center')
        love.graphics.setFont(self.instructFont)
        love.graphics.printf('Press R to Retry', 0, self.height/2 + 20, self.width, 'center')
        love.graphics.printf('Press Enter for Title Screen', 0, self.height/2 + 50, self.width, 'center')
        love.graphics.setFont(self.defaultFont)
    end
end

function Game:keypressed(key)
    if self.state == 'start' and key == 'return' then
        self:startGame()
    elseif self.state == 'help' and key == 'return' then
        self.state = 'start'
    elseif self.state == 'win' and key == 'return' then
        self:returnToTitle()
    elseif self.state == 'gameover' and key == 'return' then
        self:returnToTitle()
    end
    if key == 'r' then
        self:restart()
    end
end

function Game:startGame()
    if self.state == 'start' then
        self.state = 'playing'
        self.music.intro:stop()
        if self.musicEnabled then
            self.music.game:play()
        end
    end
end

function Game:isOver(x, y, image, scale)
    scale = scale or 1
    local w, h = image:getDimensions()
    w, h = w * scale, h * scale
    local mX, mY = love.mouse.getPosition()
    -- Check if mouse is within the scaled image's bounding box
    if mX > x and mX < x + w and mY > y and mY < y + h then
        return true
    end
end

function Game:mousepressed(x,y,button)
    -- future UI support
end

function Game:mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        if self.state == 'start' then
            -- Check if play button is clicked
            local buttonX = self.width / 2
            local buttonY = self.height / 2 + 20
            local scale = 1.2
            local btnW, btnH = self.ui.playButton:getDimensions()
            if self:isOver(buttonX - (btnW * scale / 2), buttonY - (btnH * scale / 2), self.ui.playButton, scale) then
                self:startGame()
            end
            -- Check if question mark is clicked
            local qX = self.width - 120
            local qY = self.height - 120
            if self:isOver(qX, qY, self.ui.questionMark, 1.2) then
                self.state = 'help'
            end

            -- Check if music toggle is clicked
            local musicText = "Music: " .. (self.musicEnabled and "ON" or "OFF")
            local textWidth = self.instructFont:getWidth(musicText)
            local textHeight = self.instructFont:getHeight()
            local musicX = (self.width - textWidth) / 2
            local musicY = self.height - 40
            if x > musicX and x < musicX + textWidth and y > musicY and y < musicY + textHeight then
                self.musicEnabled = not self.musicEnabled
                if self.musicEnabled then
                    self.music.intro:play()
                else
                    self.music.intro:stop()
                    self.music.game:stop()
                end
            end
        elseif self.state == 'help' then
            self.state = 'start'
        end
    end
end

function Game:returnToTitle()
    local musicWasEnabled = self.musicEnabled -- Store the current music setting
    if self.music.game then self.music.game:stop() end
    if self.music.intro then self.music.intro:stop() end
    self:load()
    self.musicEnabled = musicWasEnabled -- Restore the music setting after load() resets it
end

function Game:restart()
    local musicWasEnabled = self.musicEnabled -- Store the current music setting
    if self.music.game then self.music.game:stop() end
    if self.music.intro then self.music.intro:stop() end
    self:load()
    self.musicEnabled = musicWasEnabled -- Restore the music setting after load() resets it
    self:startGame()
end

function Game:spawnRandomItem()
    local t = self.itemTypesToSpawn[math.random(1,#self.itemTypesToSpawn)]
    local attempts = 0
    while attempts < 60 do
        attempts = attempts + 1
        local x = math.random(32, self.width-64)
        local y = math.random(32, self.height-64)
        local sprite = self.itemSprites[t]
        local item = Item:new(t, x, y, sprite) -- Create item first
        if not self:_overlapsWorld(item:getRect()) and not self:_overlapsPlayer(item:getRect()) then
            table.insert(self.items, item)
            return
        end
    end
end

function Game:updateItems(dt)
    -- update items for animations
    for _,it in ipairs(self.items) do
        if it.update then it:update(dt) end
    end
end

function Game:_overlapsWorld(rect)
    -- First, check against the original walls (Wall 1 and Wall 2)
    for _,w in ipairs(self.world.walls) do
        if rect.x < w.x + w.w and rect.x + rect.w > w.x and rect.y < w.y + w.h and rect.y + rect.h > w.y then return true end
    end

    return false
end

-- We need to update the enemy collision check to use the new system
function Game:enemyCollides(rect)
    -- Check against Wall 1 and Wall 2
    for _,w in ipairs(self.world.walls) do
        if rect.x < w.x + w.w and rect.x + rect.w > w.x and rect.y < w.y + w.h and rect.y + rect.h > w.y then return true end
    end

    return false
end

function Game:checkSpikeCollision()
    if not self.collisionMapData then return false end
    local p = self.player:getRect()

    -- Check multiple points along the player's bottom edge for more reliable collision.
    local pointsToCheck = {
        {x = p.x + p.w * 0.25, y = p.y + p.h}, -- Left side of feet
        {x = p.x + p.w * 0.50, y = p.y + p.h}, -- Center of feet
        {x = p.x + p.w * 0.75, y = p.y + p.h}  -- Right side of feet
    }

    for _, point in ipairs(pointsToCheck) do
        local checkX = math.floor(point.x / self.bgScaleX)
        local checkY = math.floor(point.y / self.bgScaleY)

        -- Make sure the check is within the bounds of the map to prevent errors
        if checkX >= 0 and checkX < self.collisionMapData:getWidth() and checkY >= 0 and checkY < self.collisionMapData:getHeight() then
            local r, g, b = self.collisionMapData:getPixel(checkX, checkY)
            -- Check for pure red (r=1, g=0, b=0), which indicates a spike tile on the collision map.
            if r > 0.99 and g < 0.01 and b < 0.01 then
                return true -- Spike detected!
            end
        end
    end

    return false -- No spike detected at any point.
end

function Game:_overlapsPlayer(rect)
    local p = self.player:getRect()
    if rect.x < p.x + p.w and rect.x + rect.w > p.x and rect.y < p.y + p.h and rect.y + rect.h > p.y then return true end
    return false
end

function Game:rectsOverlap(a,b)
    return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

-- simple synthesized beep generator
function Game:makeBeep(freq, dur)
    local sampleRate = 22050
    local len = math.floor(dur * sampleRate)
    local sd = love.sound.newSoundData(len, sampleRate, 16, 1)
    for i=0,len-1 do
        local t = i / sampleRate
        local v = math.sin(2*math.pi*freq*t) * 0.35
        sd:setSample(i, v)
    end
    return love.audio.newSource(sd, 'static')
end

function Game:makeMelody()
    -- short melody loop
    local sampleRate = 22050
    local dur = 2.0
    local len = math.floor(dur * sampleRate)
    local sd = love.sound.newSoundData(len, sampleRate, 16, 1)
    local notes = {440, 550, 660, 880}
    for i=0,len-1 do
        local t = i / sampleRate
        local beat = (t * 4) % 4
        local note = notes[math.floor((t*2)%#notes)+1]
        local v = 0
        for k=1,3 do
            v = v + 0.12 * math.sin(2*math.pi*(note * k)*t)
        end
        v = v * 0.6 * (1 - (t/dur))
        sd:setSample(i, v)
    end
    return love.audio.newSource(sd, 'static')
end

return Game
