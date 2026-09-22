local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
local DEFAULTS = {
    Title = "SpecterX",
    SubTitle = "By Specter",
    Icon = 94800455817009,
}

-- =================================================
-- LOADER
-- =================================================

local function LoadRequire(url, retries)
    retries = retries or 3
    local lastError

    for attempt = 1, retries do
        local ok, result = pcall(function()
            local source = game:HttpGet(url)
            local chunk, compileError = loadstring(source)

            if not chunk then
                error(compileError, 0)
            end

            return chunk()
        end)

        if ok then
            return result
        end

        lastError = result
        task.wait(0.5 * attempt)
    end

    warn(("[SpecterX] Falha ao carregar %s: %s"):format(url, tostring(lastError)))
    return nil
end

-- =================================================
-- HELPERS
-- =================================================

local function BuildLookup(tbl)
    local lookup = {}

    if type(tbl) == "table" then
        for key, value in pairs(tbl) do
            lookup[tostring(key):lower()] = value
        end
    end

    return lookup
end

-- =================================================
-- REQUIRE
-- =================================================

local Games = LoadRequire(BASE_URL .. "Games/games.lua")
local Configs = BuildLookup(LoadRequire(BASE_URL .. "Core/config.lua"))

local function GetGame(placeId)
    if type(Games) ~= "table" then
        return "Universal"
    end

    return Games[placeId] or Games[tostring(placeId)] or "Universal"
end

local function GetConfig(name)
    local value = Configs[tostring(name):lower()]
    if value == nil then
        return DEFAULTS[name]
    end 

    return value
end

-- =================================================
-- BUILD
-- =================================================

local function ParseIcon(icon)
    if type(icon) == "number" then
        return icon
    end

    return tonumber(icon) or tonumber(tostring(icon):match("%d+"))
end

-- =================================================
-- BASE
-- =================================================

local lib = LoadRequire("https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/Library/library.lua")
local Base = {
    Library = lib,
    
    Title = ("%s | %s"):format(tostring(GetConfig("Title")), tostring(GetGame(game.PlaceId))),
    SubTitle = tostring(GetConfig("SubTitle")),
    Image = ParseIcon(GetConfig("Icon"))
}

return Base
