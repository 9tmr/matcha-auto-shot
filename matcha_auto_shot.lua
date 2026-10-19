-- Matcha Auto Shot Meter
-- Video-calibrated timed-release helper for Roblox basketball games.
-- Default timing was measured from 20261019-0351-30.1474525.mp4.

local SCRIPT_NAME = "Matcha Auto Shot"
local SCRIPT_VERSION = "1.0.0"

assert(type(UI) == "table" and type(UI.AddTab) == "function", "Matcha UI binding is unavailable")
assert(type(notify) == "function", "Matcha notify() is unavailable")
assert(type(tick) == "function", "Matcha tick() is unavailable")
assert(type(iskeypressed) == "function", "Matcha keyboard input is unavailable")
assert(type(keypress) == "function" and type(keyrelease) == "function", "Matcha key injection is unavailable")

local gameName = type(getgamename) == "function" and tostring(getgamename()) or "Unknown"
local executorName, executorVersion = identifyexecutor()

local state = {
    busy = false,
    lastTriggerDown = false,
    shots = 0,
    lastHoldMs = 0,
    status = "Ready. Press the trigger key to take a timed shot.",
}

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function parseVirtualKey(value, fallback)
    local text = tostring(value or "")
    local prefix = string.sub(text, 1, 2)
    local parsed
    if prefix == "0x" or prefix == "0X" then
        parsed = tonumber(string.sub(text, 3), 16)
    else
        parsed = tonumber(text)
    end
    if not parsed then return fallback end
    parsed = math.floor(parsed)
    if parsed < 1 or parsed > 255 then return fallback end
    return parsed
end

local function readNumber(id, fallback)
    local value = tonumber(UI.GetValue(id))
    if value == nil then return fallback end
    return value
end

local function sleepPrecisely(seconds)
    local deadline = tick() + seconds
    while tick() < deadline do
        task.wait(0.001)
    end
end

local function pressShot(mode, shotKey)
    if mode == 2 then
        mouse1press()
    elseif mode == 3 then
        mouse2press()
    else
        keypress(shotKey)
    end
end

local function releaseShot(mode, shotKey)
    if mode == 2 then
        mouse1release()
    elseif mode == 3 then
        mouse2release()
    else
        keyrelease(shotKey)
    end
end

local function fireTimedShot()
    if state.busy then return end
    state.busy = true

    local mode = tonumber(UI.GetValue("mas_input_mode")) or 1
    local shotKey = parseVirtualKey(UI.GetValue("mas_shot_key"), 0x45)
    local baseDelay = readNumber("mas_release_delay", 0.98)
    local trimMs = readNumber("mas_trim_ms", 0)
    local pingScale = readNumber("mas_ping_scale", 0)
    local ping = type(GetPingValue) == "function" and GetPingValue() or 0
    local holdSeconds = baseDelay + (trimMs / 1000) + ((ping * pingScale) / 100000)
    holdSeconds = clamp(holdSeconds, 0.35, 1.75)

    state.status = "Holding shot input..."
    local pressed = false
    local ok, problem = pcall(function()
        setrobloxinput(true)
        pressShot(mode, shotKey)
        pressed = true
        sleepPrecisely(holdSeconds)
        releaseShot(mode, shotKey)
        pressed = false
    end)

    if pressed then
        pcall(releaseShot, mode, shotKey)
    end

    if ok then
        state.shots = state.shots + 1
        state.lastHoldMs = math.floor(holdSeconds * 1000 + 0.5)
        state.status = "Released at " .. tostring(state.lastHoldMs) .. " ms."
    else
        state.status = "Input error: " .. tostring(problem)
        notify(state.status, SCRIPT_NAME, 6)
    end

    task.wait(0.15)
    state.busy = false
end

task.spawn(function()
    while true do
        local triggerKey = parseVirtualKey(UI.GetValue("mas_trigger_key"), 0x46)
        local triggerDown = iskeypressed(triggerKey)
        local enabled = UI.GetValue("mas_enabled") == true

        if enabled and triggerDown and not state.lastTriggerDown and not state.busy and isrbxactive() then
            task.spawn(fireTimedShot)
        end

        state.lastTriggerDown = triggerDown
        task.wait(0.005)
    end
end)

UI.AddTab("Auto Shot", function(tab)
    local controls = tab:Section("Timed Release", "Left")
    controls:Toggle("mas_enabled", "Enable auto shot", false)
    controls:InputText("mas_trigger_key", "Trigger VK", "0x46")
    controls:InputText("mas_shot_key", "Game shoot VK", "0x45")
    controls:Combo("mas_input_mode", "Shot input", {
        "Keyboard key",
        "Mouse button 1",
        "Mouse button 2",
    }, 1)
    controls:SliderFloat("mas_release_delay", "Release delay", 0.70, 1.30, 0.98, "%.3f s")
    controls:SliderInt("mas_trim_ms", "Fine trim", -150, 150, 0)
    controls:SliderFloat("mas_ping_scale", "Ping adjustment", -1, 1, 0, "%.2f")
    controls:Button("Test one shot", function()
        if not state.busy then task.spawn(fireTimedShot) end
    end)
    controls:Tip("Defaults: F triggers a timed E press. Do not hold the game's normal shoot key at the same time.")

    local status = tab:Section("Calibration", "Right")
    status:Text("Game: " .. gameName)
    status:Text("Status: " .. state.status)
    status:Text("Timed shots: " .. tostring(state.shots))
    status:Text("Last hold: " .. tostring(state.lastHoldMs) .. " ms")
    status:Spacing()
    status:Text("Video baseline: 0.98 seconds")
    status:Text("If feedback is EARLY: add 10-25 ms")
    status:Text("If feedback is LATE: subtract 10-25 ms")
    status:Spacing()
    status:Button("Copy diagnostics", function()
        local report = SCRIPT_NAME .. " " .. SCRIPT_VERSION
            .. " | Game=" .. gameName
            .. " | Executor=" .. tostring(executorName) .. " " .. tostring(executorVersion)
            .. " | Ping=" .. tostring(type(GetPingValue) == "function" and GetPingValue() or "n/a")
            .. " | Delay=" .. tostring(UI.GetValue("mas_release_delay") or 0.98)
            .. " | TrimMs=" .. tostring(UI.GetValue("mas_trim_ms") or 0)
        setclipboard(report)
        notify("Diagnostics copied.", SCRIPT_NAME, 3)
    end)
    status:Tip("Matcha cannot read screen pixels. Different jumpers or special gathers may require separate trim values.")
end)

notify(SCRIPT_NAME .. " " .. SCRIPT_VERSION .. " loaded for " .. gameName .. ".", SCRIPT_NAME, 5)
