local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
local DEFAULTS = {
    Title = "SpecterX",
    SubTitle = "By Specter",

    Icon = {
        Image = 94800455817009,
        Transparency = 0,
        Corner = 5
    },

    DiscordInvite = {
        Name = "SpecterX",
        Desc = "Entre no nosso Discord e acompanhe todas as atualizações do SpecterX.",
        Logo = 94800455817009,
        Invite = "Em Breve!",
        RPC = false
    }
}

-- =================================================
-- LOADER
-- =================================================

local function LoadRequire(url, retries)
    retries = retries or 3
    local lastError

    for attempt = 1, retries do
        local ok, result = pcall(function()
            local source = game:HttpGet(BASE_URL .. url)
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

local Games = LoadRequire("Games/games.lua")
local Configs = BuildLookup(LoadRequire("Core/config.lua"))

local function GetGame(placeId)
    if type(Games) ~= "table" then
        return "Universal"
    end

    return Games[placeId] or Games[tostring(placeId)] or "Universal"
end

local function GetConfig(name)
    local key = tostring(name):lower()
    local value = Configs[key]

    if value ~= nil then
        return value
    end

    return DEFAULTS[name]
end

-- =================================================
-- BUILD
-- =================================================

local lib = LoadRequire("Core/Library/library.lua")
if type(lib) ~= "table" then
    error("[SpecterX] Falha crítica: não foi possível carregar a Library. Abortando.", 0)
end

local Base = {
    Library = lib,

    Title = ("%s | %s"):format(tostring(GetConfig("Title")), tostring(GetGame(game.PlaceId))),
    SubTitle = tostring(GetConfig("SubTitle")),

    Icon = GetConfig("Icon"),
    DiscordInvite = GetConfig("DiscordInvite")
}

setmetatable(Base, {
    __index = lib
})

return Base
