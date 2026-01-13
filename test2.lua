local args = {...}
local utf8display = require("utf8display")
local function isDiskInv(name, wrapped)
    if peripheral.getType(name) == "netmusic:music_player" then
        return false
    end
    for slot, item in pairs(wrapped.list()) do
        if item and item.name == "netmusic:music_cd" then
            return true
        end
    end
end

-- 尝试获取一个连接的显示器（优先使用命名的，或任意一个）
local function findMonitor()
    local monName = nil
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            monName = name
            break
        end
    end
    if monName then
        return peripheral.wrap(monName)
    end
    return nil
end

local function displayPlaylistOnMonitor(monitor, diskSlots, disks, currentIdx)
    if not monitor or not monitor.isColor then
        -- 基础支持：即使不是彩色显示器也尝试显示
    end

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("Music Playlist:")

    for i, slot in ipairs(diskSlots) do
        local itemDetail = disks.getItemDetail(slot)
        local name = itemDetail and itemDetail.displayName or "Unknown CD"
        local line = i .. ": " .. name

        if i == currentIdx then
            -- 高亮当前播放项（如果支持颜色）
            if monitor.isColor and monitor.setTextColour then
                monitor.setTextColour(colors.green)
                monitor.write("> " .. line)
                monitor.setTextColour(colors.white)
            else
                monitor.write("> " .. line)
            end
        else
            monitor.write("  " .. line)
        end

        -- 防止超出屏幕
        local _, maxY = monitor.getSize()
        if i >= maxY - 1 then break end
        monitor.setCursorPos(1, i + 2)
    end
end

local function main()
    local mode = "seq"
    if #args >= 1 then
        mode = args[1]
    end

    local music = peripheral.find("netmusic:music_player")
    local disks = peripheral.find("inventory", isDiskInv)
    local monitor = findMonitor()  -- 新增：查找显示器

    if not music then
        utf8display.print("Music player not found.")
        return
    end

    if not disks then
        utf8display.print("Disks not found.")
        return
    end

    -- 清空唱片机
    if music.getItemDetail(1) then
        music.pushItems(peripheral.getName(disks), 1)
    end

    while true do
        local diskSlots = {}
        for slot, item in pairs(disks.list()) do
            if item and item.name == "netmusic:music_cd" then
                diskSlots[#diskSlots + 1] = slot
            end
        end

        if #diskSlots == 0 then
            utf8display.print("No CDs found in inventory.")
            if monitor then
                monitor.clear()
                monitor.setCursorPos(1, 1)
                monitor.write("No CDs found.")
            end
            sleep(5)
            goto continue_loop
        end

        if mode == "rand" then
            local shuffled = {}
            while #diskSlots > 0 do
                local idx = math.random(#diskSlots)
                shuffled[#shuffled + 1] = table.remove(diskSlots, idx)
            end
            diskSlots = shuffled
        end

        -- 打印到终端
        utf8display.print("Music List:")
        for i, n in ipairs(diskSlots) do
            local name = disks.getItemDetail(n).displayName or "Unknown"
            utf8display.print(i, ":", name)
        end

        -- 显示到显示器（如果有）
        if monitor then
            displayPlaylistOnMonitor(monitor, diskSlots, disks, 1)
        end

        local idx = 1
        local slot = diskSlots[idx]
        while slot do
            -- 放入唱片
            music.pullItems(peripheral.getName(disks), slot)

            -- 短脉冲启动唱片机
            redstone.setOutput(peripheral.getName(music), true)
            sleep(0.05)
            redstone.setOutput(peripheral.getName(music), false)

            -- 更新显示器：高亮当前歌曲
            if monitor then
                displayPlaylistOnMonitor(monitor, diskSlots, disks, idx)
            end

            -- 等待下降沿触发切歌
            local rs_state = {}
            for _, side in ipairs(redstone.getSides()) do
                rs_state[side] = redstone.getAnalogInput(side)
            end
            repeat
                os.pullEvent("redstone")
                local closed = false
                for _, side in ipairs(redstone.getSides()) do
                    if rs_state[side] - redstone.getAnalogInput(side) > 0 then
                        closed = true
                        break
                    end
                end
                for _, side in ipairs(redstone.getSides()) do
                    rs_state[side] = redstone.getAnalogInput(side)
                end
            until closed

            -- 原唱片回收
            if music.getItemDetail(1) then
                music.pushItems(peripheral.getName(disks), 1)
            end
            
            idx = idx + 1
            slot = diskSlots[idx]
            sleep(1)
        end

        ::continue_loop::
    end
end

main()
