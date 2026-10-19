local SCRIPT_NAME = "Matcha Auto Shot"
local LOCAL_FILE = "matcha_auto_shot.lua"

if not isfile(LOCAL_FILE) then
    notify("Missing " .. LOCAL_FILE .. " in the Matcha workspace.", SCRIPT_NAME, 7)
    return
end

local source = readfile(LOCAL_FILE)
local compiled = loadstring(source, "@MatchaAutoShot")
if not compiled then
    notify("The auto-shot script could not be compiled.", SCRIPT_NAME, 7)
    return
end

local ok, problem = pcall(compiled)
if not ok then
    notify("Startup failed: " .. tostring(problem), SCRIPT_NAME, 8)
end
