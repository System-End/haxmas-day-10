local player = {
    x = 80,
    y = 0,
    width = 1,
    height = 1,
    standingHeight = 1,
    duckingHeight = 1,
    velocityY = 0,
    isJumping = false,
    isDucking = false
}

local ground = { y = 0, height = 40 }
local obstacles = {}
local powerups = {}
local particles = {}

local bgLayers = {
    {x = 0, speed = 0.2, color = {0.9, 0.9, 0.95}},
    {x = 0, speed = 0.4, color = {0.8, 0.85, 0.9}},
    {x = 0, speed = 0.6, color = {0.7, 0.75, 0.8}}
}

local spawnTimer = 0
local spawnInterval = 1.5
local powerupSpawnTimer = 0
local powerupSpawnInterval = 8
local gameSpeed = 300
local score = 0
local highScore = 0
local gameOver = false

local gravity = 1200
local jumpForce = -500

local invincible = false
local invincibleTimer = 0
local slowMotion = false
local slowMotionTimer = 0

local images = {}
local dinoScale = 1

local themes = {
    desert = {
        bg = {0.95, 0.9, 0.8},
        ground = {0.8, 0.7, 0.5},
        name = "Desert"
    },
    space = {
        bg = {0.05, 0.05, 0.15},
        ground = {0.2, 0.2, 0.3},
        name = "Space"
    },
    underwater = {
        bg = {0.2, 0.4, 0.6},
        ground = {0.1, 0.3, 0.5},
        name = "Underwater"
    },
    forest = {
        bg = {0.6, 0.8, 0.6},
        ground = {0.3, 0.5, 0.3},
        name = "Forest"
    }
}
local currentTheme = themes.desert
local themeIndex = 1
local themeNames = {"desert", "space", "underwater", "forest"}

function love.load()
    love.window.setTitle("Enhanced Runner")

    images.dino = love.graphics.newImage("assets/dino.png")
    images.cactus = love.graphics.newImage("assets/cactus.png")

    local targetHeight = 60
    dinoScale = targetHeight / images.dino:getHeight()
    player.width = images.dino:getWidth() * dinoScale
    player.standingHeight = targetHeight
    player.duckingHeight = targetHeight * 0.5
    player.height = player.standingHeight

    ground.y = love.graphics.getHeight() - ground.height
    player.y = ground.y - player.height + 1

    love.graphics.setFont(love.graphics.newFont(20))
end

function love.update(dt)
    if gameOver then return end

    local timeScale = slowMotion and 0.5 or 1.0
    dt = dt * timeScale

    score = score + dt * 10
    gameSpeed = 300 + score * 0.5

    if invincible then
        invincibleTimer = invincibleTimer - dt
        if invincibleTimer <= 0 then
            invincible = false
        end
    end

    if slowMotion then
        slowMotionTimer = slowMotionTimer - dt
        if slowMotionTimer <= 0 then
            slowMotion = false
        end
    end

    if love.keyboard.isDown("down") and not player.isJumping then
        if not player.isDucking then
            local heightDiff = player.standingHeight - player.duckingHeight
            player.y = player.y + heightDiff
            player.height = player.duckingHeight
            player.isDucking = true
        end
    else
        if player.isDucking then
            local heightDiff = player.standingHeight - player.duckingHeight
            player.y = player.y - heightDiff
            player.height = player.standingHeight
            player.isDucking = false
        end
    end

    if player.isJumping then
        player.velocityY = player.velocityY + gravity * dt
        player.y = player.y + player.velocityY * dt

        local landingY = ground.y - player.height
        if player.y >= landingY then
            player.y = landingY + 1
            player.isJumping = false
            player.velocityY = 0
            createLandingParticles()
        end
    end

    for _, layer in ipairs(bgLayers) do
        layer.x = layer.x - gameSpeed * layer.speed * dt
        if layer.x <= -love.graphics.getWidth() then
            layer.x = 0
        end
    end

    spawnTimer = spawnTimer + dt
    if spawnTimer >= spawnInterval then
        spawnTimer = 0
        spawnInterval = math.random(10, 20) / 10
        spawnObstacle()
    end

    powerupSpawnTimer = powerupSpawnTimer + dt
    if powerupSpawnTimer >= powerupSpawnInterval then
        powerupSpawnTimer = 0
        powerupSpawnInterval = math.random(60, 100) / 10
        spawnPowerup()
    end

    for i = #obstacles, 1, -1 do
        local obs = obstacles[i]
        obs.x = obs.x - gameSpeed * dt

        if obs.x + obs.width < 0 then
            table.remove(obstacles, i)
        elseif not invincible and checkCollision(player, obs) then
            gameOver = true
            if score > highScore then
                highScore = score
            end
        end
    end

    for i = #powerups, 1, -1 do
        local pw = powerups[i]
        pw.x = pw.x - gameSpeed * dt
        pw.bobTimer = pw.bobTimer + dt * 3
        pw.bobOffset = math.sin(pw.bobTimer) * 10

        if pw.x + pw.width < 0 then
            table.remove(powerups, i)
        elseif checkCollision(player, pw) then
            activatePowerup(pw.type)
            table.remove(powerups, i)
        end
    end

    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 300 * dt

        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function love.draw()
    love.graphics.clear(currentTheme.bg)

    for i, layer in ipairs(bgLayers) do
        love.graphics.setColor(layer.color)
        local numShapes = 5
        for j = 0, numShapes do
            local baseX = layer.x + (j * love.graphics.getWidth() / numShapes)
            local height = 50 + i * 30
            love.graphics.rectangle("fill", baseX, ground.y - height,
                                   love.graphics.getWidth() / numShapes, height)
        end
    end

    love.graphics.setColor(currentTheme.ground)
    love.graphics.rectangle("fill", 0, ground.y, love.graphics.getWidth(), ground.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.line(0, ground.y, love.graphics.getWidth(), ground.y)

    for _, p in ipairs(particles) do
        love.graphics.setColor(p.r, p.g, p.b, p.life)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    if invincible then
        if math.floor(invincibleTimer * 10) % 2 == 0 then
            love.graphics.setColor(1, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
    else
        love.graphics.setColor(1, 1, 1)
    end

    local scaleY = player.isDucking and dinoScale * 0.5 or dinoScale
    love.graphics.draw(images.dino, player.x, player.y, 0, dinoScale, scaleY)

    love.graphics.setColor(1, 1, 1)
    for _, obs in ipairs(obstacles) do
        if obs.type == "ground" then
            love.graphics.draw(images.cactus, obs.x, obs.y, 0,
                obs.width / images.cactus:getWidth(),
                obs.height / images.cactus:getHeight())
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.polygon("fill",
                obs.x + obs.width/2, obs.y,
                obs.x, obs.y + obs.height,
                obs.x + obs.width, obs.y + obs.height)
            love.graphics.setColor(1, 1, 1)
        end
    end

    for _, pw in ipairs(powerups) do
        local y = pw.y + pw.bobOffset
        if pw.type == "invincible" then
            love.graphics.setColor(1, 0.8, 0)
            drawStar(pw.x + pw.width/2, y + pw.height/2, 5, pw.width/2, pw.width/4)
        else
            love.graphics.setColor(0.3, 0.7, 1)
            love.graphics.circle("line", pw.x + pw.width/2, y + pw.height/2, pw.width/2)
            love.graphics.line(pw.x + pw.width/2, y + pw.height/2,
                             pw.x + pw.width/2, y + 5)
        end
    end

    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Score: " .. math.floor(score), 10, 10)
    love.graphics.print("High Score: " .. math.floor(highScore), 10, 35)
    love.graphics.print("Theme: " .. currentTheme.name .. " (T to change)", 10, 60)

    if invincible then
        love.graphics.setColor(1, 0.8, 0)
        love.graphics.print("INVINCIBLE: " .. math.ceil(invincibleTimer) .. "s", 10, 85)
    end
    if slowMotion then
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.print("SLOW MOTION: " .. math.ceil(slowMotionTimer) .. "s", 10, 110)
    end

    if gameOver then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        love.graphics.setColor(1, 1, 1)
        love.graphics.print("GAME OVER", love.graphics.getWidth() / 2 - 60, love.graphics.getHeight() / 2 - 30)
        love.graphics.print("Press SPACE to restart", love.graphics.getWidth() / 2 - 100, love.graphics.getHeight() / 2 + 10)
    end
end

function love.keypressed(key)
    if key == "space" or key == "up" then
        if gameOver then
            restartGame()
        elseif not player.isJumping and not player.isDucking then
            player.isJumping = true
            player.velocityY = jumpForce
        end
    end

    if key == "t" then
        themeIndex = (themeIndex % #themeNames) + 1
        currentTheme = themes[themeNames[themeIndex]]
    end

    if key == "escape" then
        love.event.quit()
    end
end

function spawnObstacle()
    local obsType = math.random() > 0.6 and "flying" or "ground"

    local obstacle = {
        x = love.graphics.getWidth(),
        type = obsType
    }

    if obsType == "ground" then
        obstacle.width = 30
        obstacle.height = 50
        obstacle.y = ground.y - obstacle.height + 1
    else
        obstacle.width = 40
        obstacle.height = 30
        obstacle.y = ground.y - 80
    end

    table.insert(obstacles, obstacle)
end

function spawnPowerup()
    local pwType = math.random() > 0.5 and "invincible" or "slowmo"

    local powerup = {
        x = love.graphics.getWidth(),
        y = ground.y - 100,
        width = 25,
        height = 25,
        type = pwType,
        bobTimer = 0,
        bobOffset = 0
    }

    table.insert(powerups, powerup)
end

function activatePowerup(type)
    if type == "invincible" then
        invincible = true
        invincibleTimer = 5
    else
        slowMotion = true
        slowMotionTimer = 5
    end
end

function createLandingParticles()
    for i = 1, 8 do
        table.insert(particles, {
            x = player.x + player.width / 2,
            y = ground.y,
            vx = math.random(-100, 100),
            vy = math.random(-150, -50),
            life = math.random(3, 8) / 10,
            size = math.random(2, 5),
            r = 0.7,
            g = 0.6,
            b = 0.5
        })
    end
end

function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function drawStar(cx, cy, points, outerR, innerR)
    local angle = math.pi / points
    local vertices = {}
    for i = 0, points * 2 - 1 do
        local r = i % 2 == 0 and outerR or innerR
        local a = i * angle - math.pi / 2
        table.insert(vertices, cx + math.cos(a) * r)
        table.insert(vertices, cy + math.sin(a) * r)
    end
    love.graphics.polygon("fill", vertices)
end

function restartGame()
    gameOver = false
    score = 0
    obstacles = {}
    powerups = {}
    particles = {}
    spawnTimer = 0
    gameSpeed = 300
    player.y = ground.y - player.standingHeight + 1
    player.height = player.standingHeight
    player.isJumping = false
    player.isDucking = false
    player.velocityY = 0
    invincible = false
    slowMotion = false
    invincibleTimer = 0
    slowMotionTimer = 0

    for _, layer in ipairs(bgLayers) do
        layer.x = 0
    end
end
