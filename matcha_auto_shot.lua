-- Matcha Auto Shot Meter
-- Universal meter-aware release helper with a cached GC perfect-value lock.

local SCRIPT_NAME = "Matcha Auto Shot"
local SCRIPT_VERSION = "2.3.0"

assert(type(UI) == "table" and type(UI.AddTab) == "function", "Matcha UI binding is unavailable")
assert(type(notify) == "function", "Matcha notify() is unavailable")
assert(type(tick) == "function", "Matcha tick() is unavailable")
assert(type(iskeypressed) == "function", "Matcha keyboard input is unavailable")
assert(type(keypress) == "function" and type(keyrelease) == "function", "Matcha key injection is unavailable")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local gameName = type(getgamename) == "function" and tostring(getgamename()) or "Unknown"
local executorName, executorVersion = identifyexecutor()

local PERFECT_KEYS = {
    "PerfectRelease",
    "IsPerfectRelease",
    "GreenRelease",
    "IsGreenRelease",
    "GreenShot",
    "IsGreen",
    "ShotMeterValue",
    "ShotMeterProgress",
    "ShotPower",
    "ShotAccuracy",
    "TimingAccuracy",
    "ReleaseValue",
    "ReleasePercent",
    "GreenWindow",
    "GreenWindowSize",
    "PerfectWindow",
    "PerfectWindowSize",
    "PerfectReleaseWindow",
}

local BOOLEAN_KEYS = {
    PerfectRelease = true,
    IsPerfectRelease = true,
    GreenRelease = true,
    IsGreenRelease = true,
    GreenShot = true,
    IsGreen = true,
}

local PERCENT_KEYS = {
    ReleasePercent = true,
}

local state = {
    active = true,
    busy = false,
    lastTriggerDown = false,
    lastShotDown = false,
    lastControllerDown = false,
    controllerHook = false,
    shots = 0,
    meterShots = 0,
    gcMatches = 0,
    gcCache = nil,
    gcValues = {},
    forcedObjects = 0,
    inputGateActive = false,
    lastHoldMs = 0,
    lastMethod = "none",
    lastSource = "none",
    status = "Ready. Perfect mode uses the meter first, then the timer fallback.",
}

local environment = getfenv()
local previousState = rawget(environment, "__MATCHA_AUTO_SHOT_STATE")
if type(previousState) == "table" then
    previousState.active = false
end
rawset(environment, "__MATCHA_AUTO_SHOT_STATE", state)
pcall(setrobloxinput, true)

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

local function safeGet(object, property)
    local ok, value = pcall(function()
        return object[property]
    end)
    if ok then return value end
    return nil
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

local function countEntries(values)
    local total = 0
    for _ in pairs(values) do
        total = total + 1
    end
    return total
end

local function rebuildPerfectCache(showNotice)
    if type(getgc) ~= "function" or type(applygc) ~= "function" then
        state.gcCache = nil
        state.gcMatches = 0
        state.status = "GC lock unavailable; meter tracking is still active."
        if showNotice then notify(state.status, SCRIPT_NAME, 5) end
        return false
    end

    local ok, cache = pcall(getgc, PERFECT_KEYS)
    if not ok or type(cache) ~= "table" then
        state.gcCache = nil
        state.gcMatches = 0
        state.status = "GC scan failed; meter tracking is still active."
        if showNotice then notify(state.status, SCRIPT_NAME, 5) end
        return false
    end

    local values = {}
    local matches = 0
    for _, entry in ipairs(cache) do
        local key = type(entry) == "table" and entry.key or nil
        local current = type(entry) == "table" and entry.value or nil
        if type(key) == "string" then
            matches = matches + 1
            if BOOLEAN_KEYS[key] then
                values[key] = true
            elseif PERCENT_KEYS[key] then
                values[key] = 100
            elseif type(current) == "number" and math.abs(current) > 1 then
                values[key] = 100
            else
                values[key] = 1
            end
        end
    end

    state.gcCache = cache
    state.gcValues = values
    state.gcMatches = matches
    if matches > 0 then
        state.status = "Perfect lock found " .. tostring(matches) .. " client value(s)."
    else
        state.status = "No known perfect values found; using live meter tracking."
    end
    if showNotice then notify(state.status, SCRIPT_NAME, 5) end
    return matches > 0
end

local function applyPerfectLock()
    if not state.gcCache or state.gcMatches < 1 then return 0 end
    local ok, changed = pcall(applygc, state.gcCache, state.gcValues)
    if ok then return tonumber(changed) or 0 end
    return 0
end

local function meterNameScore(name)
    local lowered = string.lower(tostring(name or ""))
    local score = 0
    if string.find(lowered, "shot", 1, true) then score = score + 5 end
    if string.find(lowered, "meter", 1, true) then score = score + 5 end
    if string.find(lowered, "fill", 1, true) then score = score + 6 end
    if string.find(lowered, "power", 1, true) then score = score + 4 end
    if string.find(lowered, "timing", 1, true) then score = score + 4 end
    if string.find(lowered, "release", 1, true) then score = score + 3 end
    if string.find(lowered, "progress", 1, true) then score = score + 3 end
    if string.find(lowered, "green", 1, true) then score = score + 2 end
    if string.find(lowered, "bar", 1, true) then score = score + 2 end
    return score
end

local function isForceFillName(name)
    local lowered = string.lower(tostring(name or ""))
    if string.find(lowered, "fill", 1, true) then return true end
    if string.find(lowered, "progress", 1, true) then return true end
    if string.find(lowered, "amount", 1, true) then return true end
    if string.find(lowered, "value", 1, true) then return true end
    if string.find(lowered, "shot", 1, true) and string.find(lowered, "bar", 1, true) then return true end
    if string.find(lowered, "shot", 1, true) and string.find(lowered, "power", 1, true) then return true end
    return false
end

local function inheritedMeterScore(object)
    local cursor = safeGet(object, "Parent")
    local depth = 0
    while cursor and depth < 5 do
        local score = meterNameScore(safeGet(cursor, "Name"))
        if score >= 4 then return score end
        cursor = safeGet(cursor, "Parent")
        depth = depth + 1
    end
    return 0
end

local function readGuiSample(object)
    local visible = safeGet(object, "Visible")
    if visible == false then return nil end

    local size = safeGet(object, "Size")
    if size == nil then return nil end

    local ok, sample = pcall(function()
        local absoluteSize = safeGet(object, "AbsoluteSize")
        return {
            xs = tonumber(size.X.Scale) or 0,
            xo = tonumber(size.X.Offset) or 0,
            ys = tonumber(size.Y.Scale) or 0,
            yo = tonumber(size.Y.Offset) or 0,
            aw = absoluteSize and tonumber(absoluteSize.X) or 0,
            ah = absoluteSize and tonumber(absoluteSize.Y) or 0,
            ax = (safeGet(object, "AbsolutePosition") and tonumber(safeGet(safeGet(object, "AbsolutePosition"), "X"))) or 0,
            ay = (safeGet(object, "AbsolutePosition") and tonumber(safeGet(safeGet(object, "AbsolutePosition"), "Y"))) or 0,
            pw = (safeGet(safeGet(object, "Parent"), "AbsoluteSize") and tonumber(safeGet(safeGet(safeGet(object, "Parent"), "AbsoluteSize"), "X"))) or 0,
            ph = (safeGet(safeGet(object, "Parent"), "AbsoluteSize") and tonumber(safeGet(safeGet(safeGet(object, "Parent"), "AbsoluteSize"), "Y"))) or 0,
        }
    end)
    if not ok then return nil end

    local color = safeGet(object, "BackgroundColor3") or safeGet(object, "ImageColor3")
    if color ~= nil then
        local colorOk, green = pcall(function()
            return color.G > 0.42 and color.G > color.R * 1.18 and color.G > color.B * 1.08
        end)
        sample.green = colorOk and green or false
    else
        sample.green = false
    end
    return sample
end

local function sampleDelta(first, current)
    return math.max(
        math.abs(current.xs - first.xs),
        math.abs(current.ys - first.ys),
        math.abs(current.xo - first.xo) / 300,
        math.abs(current.yo - first.yo) / 300,
        math.abs(current.ax - first.ax) / 300,
        math.abs(current.ay - first.ay) / 300
    )
end

local function meterProgress(record, sample)
    local first = record.first
    local xDelta = math.max(
        math.abs(sample.xs - first.xs),
        math.abs(sample.xo - first.xo) / 300,
        math.abs(sample.aw - first.aw) / 300
    )
    local yDelta = math.max(
        math.abs(sample.ys - first.ys),
        math.abs(sample.yo - first.yo) / 300,
        math.abs(sample.ah - first.ah) / 300
    )

    if xDelta >= yDelta then
        if sample.xs > 0.001 then return sample.xs, xDelta end
        if sample.pw > 0 then return sample.aw / sample.pw, xDelta end
    else
        if sample.ys > 0.001 then return sample.ys, yDelta end
        if sample.ph > 0 then return sample.ah / sample.ph, yDelta end
    end
    return 0, math.max(xDelta, yDelta)
end

local function beginMeterTracking()
    return {
        objects = {},
        bestName = "none",
        bestScore = 0,
        lastScan = 0,
    }
end

local function refreshMeterObjects(tracker, now)
    if now - tracker.lastScan < 0.06 then return end
    tracker.lastScan = now

    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local ok, descendants = pcall(function()
        return playerGui:GetDescendants()
    end)
    if not ok or type(descendants) ~= "table" then return end

    for _, object in ipairs(descendants) do
        if tracker.objects[object] == nil then
            local name = safeGet(object, "Name")
            local nameScore = meterNameScore(name)
            local inheritedScore = inheritedMeterScore(object)
            local isGui = false
            pcall(function()
                isGui = object:IsA("GuiObject")
            end)
            if isGui and (nameScore > 0 or inheritedScore > 0) then
                local className = tostring(safeGet(object, "ClassName") or "")
                local isText = string.find(className, "Text", 1, true) ~= nil
                if not isText then
                    local sample = readGuiSample(object)
                    if sample then
                        tracker.objects[object] = {
                            first = sample,
                            last = sample,
                            name = tostring(name),
                            nameScore = math.max(nameScore, inheritedScore),
                            forceable = isForceFillName(name) or inheritedScore > 0,
                            changed = false,
                        }
                    end
                end
            end
        end
    end
end

local function forceMeterFull(tracker)
    if UI.GetValue("mas_force_fill") ~= true then return 0 end

    local changed = 0
    for object, record in pairs(tracker.objects) do
        if record.forceable then
            local sample = readGuiSample(object)
            local parent = safeGet(object, "Parent")
            local parentSize = parent and safeGet(parent, "AbsoluteSize") or nil
            local parentWidth = parentSize and tonumber(safeGet(parentSize, "X")) or 0
            local parentHeight = parentSize and tonumber(safeGet(parentSize, "Y")) or 0
            if sample and (sample.xs < 0.995 or sample.ys < 0.995) then
                local sizeOk = false
                if parentHeight > parentWidth * 1.20 and sample.ah < parentHeight * 0.995 then
                    sizeOk = pcall(function()
                        object.Size = UDim2.new(sample.xs, sample.xo, 1, 0)
                    end)
                elseif parentWidth > parentHeight * 1.20 and sample.aw < parentWidth * 0.995 then
                    sizeOk = pcall(function()
                        object.Size = UDim2.new(1, 0, sample.ys, sample.yo)
                    end)
                elseif isForceFillName(record.name) then
                    sizeOk = pcall(function()
                        object.Size = UDim2.new(1, 0, 1, 0)
                    end)
                end
                if sizeOk then
                    changed = changed + 1
                    pcall(function()
                        object.BackgroundColor3 = Color3.fromRGB(0, 255, 90)
                    end)
                    pcall(function()
                        object.ImageColor3 = Color3.fromRGB(0, 255, 90)
                    end)
                end
            end
        end
    end
    state.forcedObjects = state.forcedObjects + changed
    return changed
end

local function isControllerSquareDown()
    local ok, down = pcall(function()
        return UserInputService:IsGamepadButtonDown(
            Enum.UserInputType.Gamepad1,
            Enum.KeyCode.ButtonX
        )
    end)
    return ok and down == true
end

local function meterReady(tracker, elapsed, fullThreshold, armDelay)
    refreshMeterObjects(tracker, tick())

    local ready = false
    local reason = nil
    local winningScore = 0
    local samples = {}
    local greenZones = {}

    for object, record in pairs(tracker.objects) do
        local sample = readGuiSample(object)
        if sample then
            samples[object] = sample
            if sample.green and sample.aw > 1 and sample.ah > 1 then
                greenZones[#greenZones + 1] = {object = object, sample = sample}
            end
            local delta = sampleDelta(record.first, sample)
            if delta >= 0.015 then record.changed = true end

            local progress, axisDelta = meterProgress(record, sample)
            local directFull = axisDelta >= 0.015 and progress >= fullThreshold
            local changedGreen = record.changed and sample.green
            local score = record.nameScore + (record.changed and 8 or 0) + (sample.green and 8 or 0)

            if score > tracker.bestScore then
                tracker.bestScore = score
                tracker.bestName = record.name
            end

            if elapsed >= armDelay and (changedGreen or directFull) and score > winningScore then
                ready = true
                winningScore = score
                if changedGreen then
                    reason = "green meter: " .. record.name
                else
                    reason = "full meter: " .. record.name
                end
            end
            record.last = sample
        end
    end

    if elapsed >= armDelay and not ready then
        for object, record in pairs(tracker.objects) do
            local sample = samples[object]
            if sample and not sample.green then
                local moved = math.max(
                    math.abs(sample.ax - record.first.ax),
                    math.abs(sample.ay - record.first.ay)
                )
                if moved >= 2 then
                    local centerX = sample.ax + sample.aw / 2
                    local centerY = sample.ay + sample.ah / 2
                    for _, zone in ipairs(greenZones) do
                        if zone.object ~= object then
                            local green = zone.sample
                            if centerX >= green.ax and centerX <= green.ax + green.aw
                                and centerY >= green.ay and centerY <= green.ay + green.ah then
                                ready = true
                                reason = "green-zone contact: " .. record.name
                                break
                            end
                        end
                    end
                end
            end
            if ready then break end
        end
    end
    return ready, reason
end

local function sourceStillDown(source, triggerKey, shotKey)
    if source == "controller" then return isControllerSquareDown() end
    if source == "shoot-key" then return iskeypressed(shotKey) end
    if source == "trigger-key" then return iskeypressed(triggerKey) end
    return false
end

local function releaseAndBlockHeldInput(mode, shotKey, source, triggerKey)
    -- Send the release first, then stop a physically-held E/Square from
    -- immediately reasserting the shot until the player lets that input go.
    for _ = 1, 3 do
        pcall(releaseShot, mode, shotKey)
        task.wait(0.006)
    end

    if source ~= "shoot-key" and source ~= "controller" then return end

    state.inputGateActive = true
    pcall(setrobloxinput, false)
    local deadline = tick() + readNumber("mas_gate_timeout", 3.00)
    while state.active and sourceStillDown(source, triggerKey, shotKey) and tick() < deadline do
        task.wait(0.008)
    end
    pcall(setrobloxinput, true)
    state.inputGateActive = false
end

local firePerfectShot
firePerfectShot = function(source)
    if state.busy then return end
    state.busy = true

    local mode = tonumber(UI.GetValue("mas_input_mode")) or 1
    local strategy = tonumber(UI.GetValue("mas_strategy")) or 1
    local shotKey = parseVirtualKey(UI.GetValue("mas_shot_key"), 0x45)
    local baseDelay = readNumber("mas_release_delay", 1.15)
    local armDelay = readNumber("mas_arm_delay", 0.10)
    local trimMs = readNumber("mas_trim_ms", 0)
    local pingScale = readNumber("mas_ping_scale", 0)
    local fullThreshold = readNumber("mas_full_threshold", 1.00)
    local ping = type(GetPingValue) == "function" and GetPingValue() or 0
    local fallbackSeconds = baseDelay + (trimMs / 1000) + ((ping * pingScale) / 100000)
    armDelay = clamp(armDelay, 0.04, 0.40)
    fallbackSeconds = clamp(fallbackSeconds, armDelay + 0.10, 1.75)

    if strategy == 1 and state.gcCache == nil then
        rebuildPerfectCache(false)
    end

    local tracker = beginMeterTracking()
    local startedAt = tick()
    local releaseReason = "timer fallback"
    local pressed = false
    source = tostring(source or "manual")
    state.lastSource = source

    state.status = "Charging shot; watching for full/green meter..."
    local ok, problem = pcall(function()
        setrobloxinput(true)
        pressShot(mode, shotKey)
        pressed = true

        if strategy == 3 then
            sleepPrecisely(fallbackSeconds)
        else
            while true do
                local elapsed = tick() - startedAt
                if strategy == 1 then applyPerfectLock() end

                local ready, reason = meterReady(tracker, elapsed, fullThreshold, armDelay)
                if ready then
                    releaseReason = reason or "meter"
                    break
                end
                if elapsed >= fallbackSeconds then
                    break
                end
                task.wait(0.004)
            end
        end

        if strategy == 1 then applyPerfectLock() end
        -- Seal the visible meter at full green only at the actual release
        -- point. It can no longer create a false early-ready signal.
        forceMeterFull(tracker)
        local triggerKey = parseVirtualKey(UI.GetValue("mas_trigger_key"), 0x46)
        releaseAndBlockHeldInput(mode, shotKey, source, triggerKey)
        pressed = false
    end)

    if pressed then pcall(releaseShot, mode, shotKey) end

    if ok then
        state.shots = state.shots + 1
        state.lastHoldMs = math.floor((tick() - startedAt) * 1000 + 0.5)
        state.lastMethod = releaseReason
        if releaseReason ~= "timer fallback" then
            state.meterShots = state.meterShots + 1
        end
        state.status = "Released at " .. tostring(state.lastHoldMs) .. " ms via " .. releaseReason .. "."
    else
        state.status = "Input error: " .. tostring(problem)
        notify(state.status, SCRIPT_NAME, 6)
    end

    task.wait(0.15)
    state.busy = false
end

task.spawn(function()
    while state.active do
        local triggerKey = parseVirtualKey(UI.GetValue("mas_trigger_key"), 0x46)
        local shotKey = parseVirtualKey(UI.GetValue("mas_shot_key"), 0x45)
        local triggerDown = iskeypressed(triggerKey)
        local shotDown = iskeypressed(shotKey)
        local controllerDown = isControllerSquareDown()
        local enabled = UI.GetValue("mas_enabled") == true
        local directInput = UI.GetValue("mas_direct_input") == true

        local separateTrigger = triggerDown and not state.lastTriggerDown
        local directShotTrigger = directInput and shotDown and not state.lastShotDown
        local controllerTrigger = UI.GetValue("mas_controller_trigger") == true
            and controllerDown and not state.lastControllerDown
        if enabled and (separateTrigger or directShotTrigger or controllerTrigger)
            and not state.busy and isrbxactive() then
            local source = separateTrigger and "trigger-key"
                or (directShotTrigger and "shoot-key")
                or "controller"
            task.spawn(function() firePerfectShot(source) end)
        end

        state.lastTriggerDown = triggerDown
        state.lastShotDown = shotDown
        state.lastControllerDown = controllerDown
        task.wait(0.005)
    end
end)

local function connectControllerTrigger()
    local ok = pcall(function()
        UserInputService.InputBegan:Connect(function(input)
            if not state.active or state.busy then return end
            if UI.GetValue("mas_enabled") ~= true then return end
            if UI.GetValue("mas_controller_trigger") ~= true then return end
            if not isrbxactive() then return end

            local keyCode = safeGet(input, "KeyCode")
            local keyName = keyCode and safeGet(keyCode, "Name") or nil
            if keyName == "ButtonX" then
                task.spawn(function() firePerfectShot("controller") end)
            end
        end)
    end)
    state.controllerHook = ok
end

UI.AddTab("Auto Shot", function(tab)
    local controls = tab:Section("Perfect Release", "Left")
    controls:Toggle("mas_enabled", "Enable auto shot", true)
    controls:Toggle("mas_direct_input", "React to game shoot key", true)
    controls:Toggle("mas_controller_trigger", "Square / ButtonX trigger", true)
    controls:Toggle("mas_force_fill", "Force meter to 100% green", true)
    controls:InputText("mas_trigger_key", "Trigger VK", "0x46")
    controls:InputText("mas_shot_key", "Game shoot VK", "0x45")
    controls:Combo("mas_input_mode", "Shot input", {
        "Keyboard key",
        "Mouse button 1",
        "Mouse button 2",
    }, 1)
    controls:Combo("mas_strategy", "Release strategy", {
        "Perfect lock + live meter",
        "Live meter only",
        "Fixed timer fallback only",
    }, 1)
    controls:SliderFloat("mas_full_threshold", "Full meter threshold", 0.80, 1.00, 0.97, "%.2f")
    controls:SliderFloat("mas_arm_delay", "Meter arming delay", 0.04, 0.40, 0.10, "%.3f s")
    controls:SliderFloat("mas_release_delay", "Maximum hold timeout", 0.70, 1.70, 1.15, "%.3f s")
    controls:SliderFloat("mas_gate_timeout", "Held-input block timeout", 0.50, 5.00, 3.00, "%.2f s")
    controls:SliderInt("mas_trim_ms", "Fallback trim", -200, 200, 0)
    controls:SliderFloat("mas_ping_scale", "Ping adjustment", -1, 1, 0, "%.2f")
    controls:Button("Take one perfect shot", function()
        if not state.busy then task.spawn(function() firePerfectShot("manual") end) end
    end)
    controls:Button("Rescan perfect values", function()
        rebuildPerfectCache(true)
    end)
    controls:Tip("Tap or hold F, E, or Square/ButtonX. The script owns the charge, releases at the live green/full point, and blocks a still-held E/Square until you let go.")

    local status = tab:Section("Live Status", "Right")
    status:Text("Version: " .. SCRIPT_VERSION)
    status:Text("Game: " .. gameName)
    status:Text("Status: " .. state.status)
    status:Text("Shots: " .. tostring(state.shots))
    status:Text("Meter releases: " .. tostring(state.meterShots))
    status:Text("GC matches: " .. tostring(state.gcMatches))
    status:Text("Forced meter writes: " .. tostring(state.forcedObjects))
    status:Text("Controller hook: " .. (state.controllerHook and "ready" or "unavailable"))
    status:Text("Last hold: " .. tostring(state.lastHoldMs) .. " ms")
    status:Text("Last method: " .. state.lastMethod)
    status:Text("Last input: " .. state.lastSource)
    status:Text("Held-input gate: " .. (state.inputGateActive and "blocking" or "ready"))
    status:Spacing()
    status:Text("Live green/full detection releases immediately.")
    status:Text("Forced green is applied only at the release point.")
    status:Text("The maximum timer is fallback-only.")
    status:Text("Lower Full meter threshold only if release is late.")
    status:Spacing()
    status:Button("Copy diagnostics", function()
        local report = SCRIPT_NAME .. " " .. SCRIPT_VERSION
            .. " | Game=" .. gameName
            .. " | Executor=" .. tostring(executorName) .. " " .. tostring(executorVersion)
            .. " | Ping=" .. tostring(type(GetPingValue) == "function" and GetPingValue() or "n/a")
            .. " | Strategy=" .. tostring(UI.GetValue("mas_strategy") or 1)
            .. " | ArmDelay=" .. tostring(UI.GetValue("mas_arm_delay") or 0.10)
            .. " | GCMatches=" .. tostring(state.gcMatches)
            .. " | ForcedWrites=" .. tostring(state.forcedObjects)
            .. " | LastMethod=" .. state.lastMethod
            .. " | LastSource=" .. state.lastSource
            .. " | LastHoldMs=" .. tostring(state.lastHoldMs)
            .. " | KnownValues=" .. tostring(countEntries(state.gcValues))
        setclipboard(report)
        notify("Diagnostics copied.", SCRIPT_NAME, 3)
    end)
    status:Tip("If the game validates releases on its server, no client-side script can force every shot green.")
end)

task.spawn(function()
    task.wait(1)
    if state.active then rebuildPerfectCache(false) end
end)

connectControllerTrigger()

notify(SCRIPT_NAME .. " " .. SCRIPT_VERSION .. " loaded for " .. gameName .. ".", SCRIPT_NAME, 5)
