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
    local value = Configs[tostring(name):lower()]
    if value == nil then
        return DEFAULTS[name]
    end 

    return value
end

-- =================================================
-- BUILD
-- =================================================

local IconFormat = {
    NUMBER = "number",
    RBX = "rbx",
}

local function ParseIcon(icon, returnType)
    returnType = returnType or IconFormat.NUMBER

    if icon == nil then
        return nil
    end

    local id
    if type(icon) == "number" then
        id = icon
    else
        local str = tostring(icon)
        id = tonumber(str) or tonumber(str:match("%d+"))
    end

    if not id then
        return nil
    end

    if returnType == IconFormat.RBX then
        return "rbxassetid://" .. tostring(id)
    elseif returnType == IconFormat.NUMBER then
        return id
    end

    warn(("[ParseIcon] returnType desconhecido: %s"):format(tostring(returnType)))
    return id
end

-- =================================================
-- BASE
-- =================================================

local lib = LoadRequire("Core/Library/library.lua")
if type(lib) ~= "table" then
    error("[SpecterX] Falha crítica: não foi possível carregar a Library. Abortando.", 0)
end

local Image = ParseIcon(GetConfig("Icon"), "rbx")
local Base = {
    Library = lib,
    
    Title = ("%s | %s"):format(tostring(GetConfig("Title")), tostring(GetGame(game.PlaceId))),
    SubTitle = tostring(GetConfig("SubTitle")),
    
    Icon = {
        Image = Image,
        Transparency = 0,
        Corner = 5
    },

    DiscordInvite = {
        Name = tostring(GetConfig("Title")),
        Desc = "Entre no nosso Discord e acompanhe todas as atualizações do SpecterX.",
        
        Logo = Image,
        Invite = "Em Breve!",

        RPC = false
    }
}

setmetatable(Base, {
    __index = lib,
})

return Base
