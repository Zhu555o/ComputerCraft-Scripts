-- 贪吃蛇 for ComputerCraft / CC: Tweaked
-- 支持外部显示器（自动检测），控制仍通过电脑终端

-- === 检测显示器 ===
local termScreen = term.current()  -- 默认是电脑终端
local monitor = nil

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitor = peripheral.wrap(name)
        termScreen = monitor  -- 游戏画面输出到显示器
        break
    end
end

-- === 游戏配置 ===
local w, h = termScreen.getSize()
local GAME_WIDTH = math.min(30, w)
local GAME_HEIGHT = math.min(15, h - 2)

-- 初始化状态
local snake = {{x = 5, y = 5}}
local direction = "right"
local nextDirection = "right"
local food = {x = 10, y = 5}
local score = 0
local gameOver = false

-- 生成食物
local function generateFood()
    local tries = 0
    repeat
        food.x = math.random(1, GAME_WIDTH)
        food.y = math.random(1, GAME_HEIGHT)
        tries = tries + 1
        local onSnake = false
        for _, seg in ipairs(snake) do
            if seg.x == food.x and seg.y == food.y then
                onSnake = true
                break
            end
        end
        if tries > 100 then break end
    until not onSnake
end

-- 绘制画面（输出到 termScreen，可能是显示器或终端）
local function draw()
    termScreen.clear()
    termScreen.setCursorPos(1, 1)
    termScreen.write("Score: " .. score .. " | Use arrow keys. Press 'q' to quit.")

    -- 边界
    for x = 1, GAME_WIDTH + 2 do
        termScreen.setCursorPos(x, 2)
        termScreen.write("-")
        termScreen.setCursorPos(x, GAME_HEIGHT + 3)
        termScreen.write("-")
    end
    for y = 1, GAME_HEIGHT + 1 do
        termScreen.setCursorPos(1, y + 2)
        termScreen.write("|")
        termScreen.setCursorPos(GAME_WIDTH + 2, y + 2)
        termScreen.write("|")
    end

    -- 蛇
    for i, seg in ipairs(snake) do
        termScreen.setCursorPos(seg.x + 1, seg.y + 2)
        if i == #snake then
            termScreen.write("#")  -- 头
        else
            termScreen.write("o")  -- 身体
        end
    end

    -- 食物
    termScreen.setCursorPos(food.x + 1, food.y + 2)
    termScreen.write("*")

    if gameOver then
        termScreen.setCursorPos(1, GAME_HEIGHT + 5)
        termScreen.write("GAME OVER! Final Score: " .. score)
        termScreen.setCursorPos(1, GAME_HEIGHT + 6)
        termScreen.write("Press any key to restart...")
    end
end

-- 碰撞检测
local function checkCollision(newHead)
    if newHead.x < 1 or newHead.x > GAME_WIDTH or newHead.y < 1 or newHead.y > GAME_HEIGHT then
        return true
    end
    for i = 1, #snake - 1 do
        if snake[i].x == newHead.x and snake[i].y == newHead.y then
            return true
        end
    end
    return false
end

-- 主循环（输入仍从电脑终端监听！）
local function gameLoop()
    while true do
        -- ⚠️ 关键：事件监听必须用 term.current()（即电脑终端）
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
            os.pullEvent("key")  -- 等待任意键（从电脑终端）
            snake = {{x = 5, y = 5}}
            direction = "right"
            nextDirection = "right"
            score = 0
            gameOver = false
            generateFood()
        else
            direction = nextDirection
            local head = snake[#snake]
            local newHead = {x = head.x, y = head.y}
            if direction == "up" then newHead.y = newHead.y - 1
            elseif direction == "down" then newHead.y = newHead.y + 1
            elseif direction == "left" then newHead.x = newHead.x - 1
            else newHead.x = newHead.x + 1 end

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
                local delay = math.max(0.1, 0.3 - (score / 500))
                sleep(delay)
            end
        end
    end
end

-- 启动
term.clear()
print("Starting Snake Game...")
if monitor then
    print("Game will display on connected monitor.")
else
    print("No monitor found. Playing on terminal.")
end
sleep(1)

generateFood()
draw()
gameLoop()

-- 恢复终端（可选）
term.redirect(term.native())
