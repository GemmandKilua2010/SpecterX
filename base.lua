local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
local Hub = loadstring(game:HttpGet(BASE_URL .. "Core/Modules/Hub/script.lua"))()

-- =================================================
-- REQUIRE
-- =================================================

local function LoadRequire(url, retries)
    return Hub:LoadRequire(url, retries)
end

local function GetConfig(name)
    return Hub:GetConfig(name)
end

local Games = LoadRequire("Games/games.lua")
local function GetGame(placeId)
    if type(Games) ~= "table" then
        return "Universal"
    end

    return Games[placeId] or Games[tostring(placeId)] or "Universal"
end

-- =================================================
-- BUILD
-- =================================================

local lib = LoadRequire("Core/Library/library.lua")
if type(lib) ~= "table" then
    error("Falha crítica: não foi possível carregar a Library. Abortando.",0)
end

local Base = {
    Library = lib,

    Title = ("%s | %s"):format(tostring(GetConfig("Title")), tostring(GetGame(game.PlaceId))),
    SubTitle = tostring(GetConfig("SubTitle")),

    Icon = GetConfig("Icon"),
    DiscordInvite = GetConfig("DiscordInvite")
}

-- =================================================
-- ADDONS
-- =================================================

function Base:GetConfig(name)
    return GetConfig(name)
end

function Base:LoadRequire(url, retries)
    return LoadRequire(url, retries)
end

-- =================================================
-- RETURN
-- =================================================

setmetatable(Base, {
    __index = lib
})
return Base
