local SCRIPT_NAME = "Matcha Auto Shot"
local LOCAL_FILE = "matcha_auto_shot.lua"
local RAW_URL = "https://raw.githubusercontent.com/9tmr/matcha-auto-shot/main/matcha_auto_shot.lua"

local source
local ok, result = pcall(httpget, RAW_URL)
if ok then source = result end

if type(source) ~= "string" or #source < 100 then
    if isfile(LOCAL_FILE) then
        source = readfile(LOCAL_FILE)
    end
end

if type(source) ~= "string" or #source < 100 then
    notify("Could not load the local or GitHub auto-shot script.", SCRIPT_NAME, 7)
    return
end

local compiled = loadstring(source, "@MatchaAutoShot")
if not compiled then
    notify("The auto-shot script could not be compiled.", SCRIPT_NAME, 7)
    return
end

local ok, problem = pcall(compiled)
if not ok then
    notify("Startup failed: " .. tostring(problem), SCRIPT_NAME, 8)
end
