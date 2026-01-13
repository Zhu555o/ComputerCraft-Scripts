-- netmusicplus.lua (Modified for UTF-8 Support using utf8display)
-- 作者: Zhu555o (原始), Assistant (修改以支持 UTF-8)
-- 依赖: utf8display library (https://git.liulikeji.cn/xingluo/ComputerCraft-Utf8/src/branch/main/utf8display)

-- 尝试加载 utf8display 库
local utf8display
local load_success = false
local status, err_msg = pcall(function()
    utf8display = require("utf8display")
    load_success = true
end)

if not load_success then
    printError("无法加载 utf8display 库。")
    printError("请确保 utf8display.lua 文件存在于计算机中。")
    printError("例如，运行: wget https://git.liulikeji.cn/xingluo/ComputerCraft-Utf8/raw/branch/main/utf8display/utf8display.lua utf8display.lua")
    return
end

-- 加载 HTTP API
if not http then
    printError("HTTP API 不可用。请在计算机中安装并启用 Modem。")
    return
end

-- 全局变量
local currentMusic = nil
local isPlaying = false
local playbackThread = nil
local volume = 50 -- 音量百分比 (0-100)
local musicList = {}
local totalMusic = 0
local currentPlayIndex = 1
local playMode = 1 -- 1: 列表循环, 2: 单曲循环, 3: 随机播放

-- 播放模式名称映射
local playModeNames = {
    [1] = "列表循环",
    [2] = "单曲循环",
    [3] = "随机播放"
}

-- 颜色定义 (使用 ComputerCraft 的颜色常量)
local COLORS = {
    text_default = colors.white,
    bg_default = colors.black,
    text_title = colors.yellow,
    text_info = colors.green,
    text_highlight = colors.lime,
    text_error = colors.red,
    bg_playing = colors.blue,
    bg_selected = colors.gray
}

-- --- 工具函数 ---

-- 从 URL 获取 JSON 数据
local function getJsonFromUrl(url)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        local json_data = textutils.unserializeJSON(content)
        if json_data then
            return json_data
        else
            printError("解析 JSON 失败")
            printError("收到的内容: " .. content)
        end
    else
        printError("获取数据失败: " .. url)
    end
    return nil
end

-- 检查音乐是否有效
local function isValidMusic(music)
    return music and music.url and music.name and music.artists and music.album
end

-- --- 播放控制逻辑 ---

-- 播放下一首
local function playNext()
    if totalMusic == 0 then return end
    if playMode == 3 then -- 随机播放
        currentPlayIndex = math.random(1, totalMusic)
    else -- 列表循环或单曲循环
        currentPlayIndex = currentPlayIndex + 1
        if currentPlayIndex > totalMusic then
            currentPlayIndex = 1
        end
    end
    currentMusic = musicList[currentPlayIndex]
    isPlaying = true
    -- 在后台启动新的播放线程
    if playbackThread then coroutine.close(playbackThread) end
    playbackThread = coroutine.create(function()
        local soundCard = peripheral.find("speaker")
        if soundCard then
            soundCard.playSound(currentMusic.url, volume / 100)
            -- 等待播放结束 (这是一个简化的方式，实际播放时间可能不同)
            -- 更精确的控制需要更复杂的逻辑
            sleep(10) -- 或者根据 metadata 获取时长
        else
            printError("未找到扬声器设备。")
            isPlaying = false
        end
    end)
    coroutine.resume(playbackThread)
end

-- 播放上一首
local function playPrevious()
    if totalMusic == 0 then return end
    if playMode == 3 then -- 随机播放
        currentPlayIndex = math.random(1, totalMusic)
    else -- 列表循环或单曲循环
        currentPlayIndex = currentPlayIndex - 1
        if currentPlayIndex < 1 then
            currentPlayIndex = totalMusic
        end
    end
    currentMusic = musicList[currentPlayIndex]
    isPlaying = true
    -- 重启播放线程
    if playbackThread then coroutine.close(playbackThread) end
    playbackThread = coroutine.create(function()
        local soundCard = peripheral.find("speaker")
        if soundCard then
            soundCard.playSound(currentMusic.url, volume / 100)
            sleep(10) -- 同上
        else
            printError("未找到扬声器设备。")
            isPlaying = false
        end
    end)
    coroutine.resume(playbackThread)
end

-- 暂停/恢复播放
local function togglePauseResume()
    if not currentMusic or not isPlaying then return end
    local soundCard = peripheral.find("speaker")
    if soundCard then
        -- ComputerCraft 的 speaker API 没有直接的暂停/恢复功能
        -- 此处模拟：暂停时停止，恢复时重新开始
        soundCard.stopAllSounds()
        isPlaying = not isPlaying
        if isPlaying then -- 恢复
            -- 重新启动播放线程
            if playbackThread then coroutine.close(playbackThread) end
            playbackThread = coroutine.create(function()
                soundCard.playSound(currentMusic.url, volume / 100)
                sleep(10)
            end)
            coroutine.resume(playbackThread)
        end
    end
end

-- 搜索音乐
local function searchMusic(keyword)
    term.clear()
    utf8display.print({success=true, startX=1, startY=1, endX=1, endY=1, charCount=0, fontHeight=utf8display.getFontHeight()}, "搜索中: " .. keyword, COLORS.text_info, COLORS.bg_default)

    local searchUrl = "https://music-api-by-zhu555o.vercel.app/search?keywords=" .. textutils.urlEncode(keyword)
    local searchData = getJsonFromUrl(searchUrl)

    if not searchData or not searchData.result or not searchData.result.songs then
        utf8display.print({success=true, startX=1, startY=2, endX=1, endY=2, charCount=0, fontHeight=utf8display.getFontHeight()}, "搜索失败或无结果。", COLORS.text_error, COLORS.bg_default)
        sleep(2)
        return
    end

    musicList = {}
    for _, song in ipairs(searchData.result.songs) do
        table.insert(musicList, {
            name = song.name or "未知歌曲",
            artists = song.artists and song.artists[1].name or "未知艺术家",
            album = song.album and song.album.name or "未知专辑",
            url = song.url or ""
        })
    end
    totalMusic = #musicList
    currentPlayIndex = 1
    currentMusic = musicList[1]

    if currentMusic and isValidMusic(currentMusic) then
        isPlaying = true
        playNext() -- 开始播放第一首
    end
    -- 搜索完成后回到主界面
    -- (主界面循环会继续显示)
end

-- --- UI 渲染 ---

-- 渲染主界面
local function renderUI()
    term.clear()

    -- 标题
    utf8display.write({success=true, startX=1, startY=1, endX=1, endY=1, charCount=0, fontHeight=utf8display.getFontHeight()}, "=== 网易云音乐播放器 Plus ===", COLORS.text_title, COLORS.bg_default)
    term.setCursorPos(1, 3)

    -- 当前播放信息
    if currentMusic and isValidMusic(currentMusic) then
        utf8display.print({success=true, startX=1, startY=3, endX=1, endY=3, charCount=0, fontHeight=utf8display.getFontHeight()}, "正在播放:", COLORS.text_info, COLORS.bg_default)
        utf8display.print({success=true, startX=1, startY=4, endX=1, endY=4, charCount=0, fontHeight=utf8display.getFontHeight()}, "歌曲: " .. currentMusic.name, COLORS.text_default, COLORS.bg_default)
        utf8display.print({success=true, startX=1, startY=5, endX=1, endY=5, charCount=0, fontHeight=utf8display.getFontHeight()}, "艺术家: " .. currentMusic.artists, COLORS.text_default, COLORS.bg_default)
        utf8display.print({success=true, startX=1, startY=6, endX=1, endY=6, charCount=0, fontHeight=utf8display.getFontHeight()}, "专辑: " .. currentMusic.album, COLORS.text_default, COLORS.bg_default)
        utf8display.print({success=true, startX=1, startY=7, endX=1, endY=7, charCount=0, fontHeight=utf8display.getFontHeight()}, "状态: " .. (isPlaying and "播放中" or "已暂停"), COLORS.text_highlight, COLORS.bg_default)
    else
        utf8display.print({success=true, startX=1, startY=3, endX=1, endY=3, charCount=0, fontHeight=utf8display.getFontHeight()}, "当前无音乐。", COLORS.text_error, COLORS.bg_default)
    end

    term.setCursorPos(1, 9)
    utf8display.print({success=true, startX=1, startY=9, endX=1, endY=9, charCount=0, fontHeight=utf8display.getFontHeight()}, "播放列表 (" .. totalMusic .. " 首):", COLORS.text_info, COLORS.bg_default)

    -- 播放列表预览 (最多显示 5 首)
    local listStartY = 10
    local maxListItems = math.min(5, totalMusic)
    for i = 1, maxListItems do
        local idx = (currentPlayIndex - 2 + i) % totalMusic + 1 -- 循环计算显示的索引
        local item = musicList[idx]
        if item then
            local prefix = ""
            local bgColor = COLORS.bg_default
            if idx == currentPlayIndex then
                prefix = "> "
                bgColor = COLORS.bg_playing
            elseif i == 1 then -- 上一首
                prefix = "  "
            elseif i == maxListItems then -- 下一首
                prefix = "  "
            else -- 其他
                prefix = "  "
            end
            -- 构建显示行
            local displayLine = prefix .. idx .. ". " .. item.name .. " - " .. item.artists
            utf8display.print({success=true, startX=1, startY=listStartY + i - 1, endX=1, endY=listStartY + i - 1, charCount=0, fontHeight=utf8display.getFontHeight()}, displayLine, COLORS.text_default, bgColor)
        end
    end

    -- 控制说明和状态
    local controlY = listStartY + maxListItems + 2
    utf8display.print({success=true, startX=1, startY=controlY, endX=1, endY=controlY, charCount=0, fontHeight=utf8display.getFontHeight()}, "控制: [N]ext, [P]rev, [Space]Pause/Resume, [S]earch, [M]ode, [V+]olume Up, [B]ack Volume Down, [Q]uit", COLORS.text_info, COLORS.bg_default)
    term.setCursorPos(1, controlY + 1)
    utf8display.print({success=true, startX=1, startY=controlY + 1, endX=1, endY=controlY + 1, charCount=0, fontHeight=utf8display.getFontHeight()}, "当前模式: " .. playModeNames[playMode], COLORS.text_info, COLORS.bg_default)
    term.setCursorPos(1, controlY + 2)
    utf8display.print({success=true, startX=1, startY=controlY + 2, endX=1, endY=controlY + 2, charCount=0, fontHeight=utf8display.getFontHeight()}, "当前音量: " .. volume .. "%", COLORS.text_info, COLORS.bg_default)
end


-- --- 主程序入口 ---

-- 初始化随机数生成器
math.randomseed(os.time())

-- 欢迎信息
print("正在加载网易云音乐播放器 Plus...")
sleep(1)

-- 主循环
while true do
    renderUI()
    local event, key = os.pullEvent("key")

    if event == "key" then
        if key == keys.q then -- 退出
            if playbackThread then coroutine.close(playbackThread) end
            term.clear()
            utf8display.print({success=true, startX=1, startY=1, endX=1, endY=1, charCount=0, fontHeight=utf8display.getFontHeight()}, "再见!", COLORS.text_info, COLORS.bg_default)
            sleep(1)
            break
        elseif key == keys.n then -- 下一首
            playNext()
        elseif key == keys.p then -- 上一首
            playPrevious()
        elseif key == keys.space then -- 暂停/恢复
            togglePauseResume()
        elseif key == keys.s then -- 搜索
            term.clear()
            utf8display.print({success=true, startX=1, startY=1, endX=1, endY=1, charCount=0, fontHeight=utf8display.getFontHeight()}, "请输入搜索关键词: ", COLORS.text_info, COLORS.bg_default)
            local keyword = io.read("*line")
            if keyword and #keyword:gsub("%s+", "") > 0 then
                searchMusic(keyword)
            else
                utf8display.print({success=true, startX=1, startY=2, endX=1, endY=2, charCount=0, fontHeight=utf8display.getFontHeight()}, "无效的搜索词。", COLORS.text_error, COLORS.bg_default)
                sleep(1)
            end
        elseif key == keys.m then -- 切换播放模式
            playMode = playMode + 1
            if playMode > 3 then playMode = 1 end
            utf8display.print({success=true, startX=1, startY=20, endX=1, endY=20, charCount=0, fontHeight=utf8display.getFontHeight()}, "播放模式已切换为: " .. playModeNames[playMode], COLORS.text_highlight, COLORS.bg_default) -- 简单提示
            sleep(1)
        elseif key == keys.v then -- 音量增加
            volume = math.min(100, volume + 10)
            utf8display.print({success=true, startX=1, startY=20, endX=1, endY=20, charCount=0, fontHeight=utf8display.getFontHeight()}, "音量已调整为: " .. volume .. "%", COLORS.text_highlight, COLORS.bg_default)
            sleep(1)
        elseif key == keys.b then -- 音量减少
            volume = math.max(0, volume - 10)
            utf8display.print({success=true, startX=1, startY=20, endX=1, endY=20, charCount=0, fontHeight=utf8display.getFontHeight()}, "音量已调整为: " .. volume .. "%", COLORS.text_highlight, COLORS.bg_default)
            sleep(1)
        end
    end
end
