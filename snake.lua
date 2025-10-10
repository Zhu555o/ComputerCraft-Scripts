local outputTerm = term.current()
local monitor = nil

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        local m = peripheral.wrap(name)
        if not monitor or (m.getSize and select(1, m.getSize()) * select(2, m.getSize()) > select(1, monitor.getSize()) * select(2, monitor.getSize())) then
            monitor = m
        end
    end
end

if monitor then
    outputTerm = monitor
end

local w, h = outputTerm.getSize()
local GAME_WIDTH = math.max(10, w - 2)
local GAME_HEIGHT = math.max(8, h - 3)

local snake = {{x = math.floor(GAME_WIDTH/2), y = math.floor(GAME_HEIGHT/2)}}
local direction = "right"
local nextDirection = "right"
local food = {x = GAME_WIDTH - 5, y = math.floor(GAME_HEIGHT/2)}
local score = 0
local gameOver = false

local function generateFood()
    local tries = 0
    repeat
        food.x = math.random(1, GAME_WIDTH)
        food.y = math.random(1, GAME_HEIGHT)
        tries = tries + 1
        local conflict = false
        for _, seg in ipairs(snake) do
            if seg.x == food.x and seg.y == food.y then
                conflict = true
                break
            end
        end
        if tries > 200 then break end
    until not conflict
end

local function draw()
    outputTerm.clear()
    outputTerm.setCursorPos(1, 1)
    outputTerm.write("Snake | Score: " .. score .. " | Arrows to move, Q to quit")

    for x = 1, GAME_WIDTH + 2 do
        outputTerm.setCursorPos(x, 2)
        outputTerm.write("#")
        outputTerm.setCursorPos(x, GAME_HEIGHT + 3)
        outputTerm.write("#")
    end
    for y = 1, GAME_HEIGHT + 1 do
        outputTerm.setCursorPos(1, y + 2)
        outputTerm.write("#")
        outputTerm.setCursorPos(GAME_WIDTH + 2, y + 2)
        outputTerm.write("#")
    end

    for i, seg in ipairs(snake) do
        outputTerm.setCursorPos(seg.x + 1, seg.y + 2)
        if i == #snake then
            outputTerm.write("@")
        else
            outputTerm.write("O")
        end
    end

    outputTerm.setCursorPos(food.x + 1, food.y + 2)
    outputTerm.write("*")

    if gameOver then
        local msg = "GAME OVER! Final Score: " .. score
        local x = math.max(1, math.floor((w - #msg) / 2))
        outputTerm.setCursorPos(x, math.floor(h / 2))
        outputTerm.write(msg)
        outputTerm.setCursorPos(1, h)
        outputTerm.write("Press any key to restart...")
    end
end

local function checkCollision(head)
    if head.x < 1 or head.x > GAME_WIDTH or head.y < 1 or head.y > GAME_HEIGHT then
        return true
    end
    for i = 1, #snake - 1 do
        if snake[i].x == head.x and snake[i].y == head.y then
            return true
        end
    end
    return false
end

local function gameLoop()
    while true do
        local event = {os.pullEventRaw("key")}
        if event[1] == "key" then
            local key = event[2]
            if key == keys.q then
                return
            elseif key == keys.up and direction ~= "down" then
                nextDirection = "up"
            elseif key == keys.down and direction ~= "up" then
                nextDirection = "down"
            elseif key == keys.left and direction ~= "right" then
                nextDirection = "left"
            elseif key == keys.right and direction ~= "left" then
                nextDirection = "right"
            end
        end

        if gameOver then
            os.pullEvent("key")
            snake = {{x = math.floor(GAME_WIDTH/2), y = math.floor(GAME_HEIGHT/2)}}
            direction = "right"
            nextDirection = "right"
            score = 0
            gameOver = false
            generateFood()
        else
            direction = nextDirection
            local head = snake[#snake]
            local newHead = {x = head.x, y = head.y}
            if direction == "up" then
                newHead.y = newHead.y - 1
            elseif direction == "down" then
                newHead.y = newHead.y + 1
            elseif direction == "left" then
                newHead.x = newHead.x - 1
            else
                newHead.x = newHead.x + 1
            end

            if checkCollision(newHead) then
                gameOver = true
                draw()
            else
                table.insert(snake, newHead)
                if newHead.x == food.x and newHead.y == food.y then
                    score = score + 10
                    generateFood()
                else
                    table.remove(snake, 1)
                end
                draw()
                local delay = math.max(0.05, 0.25 - (score / 1000))
                sleep(delay)
            end
        end
    end
end

term.clear()
generateFood()
draw()
gameLoop()
