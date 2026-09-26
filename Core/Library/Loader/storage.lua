local HttpService = game:GetService("HttpService")

local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
local Hub = loadstring(game:HttpGet(BASE_URL .. "Core/Modules/Hub/script.lua"))()

local Root = Hub:GetConfig("Title")

-- =================================================
-- REQUIRE
-- =================================================

local Games = Hub:LoadRequire("Games/games.lua")
local function GetGame(placeId)
    if type(Games) ~= "table" then
        return "Universal"
    end

    return Games[placeId] or Games[tostring(placeId)] or "Universal"
end

-- =================================================
-- FUNÇÕES
-- =================================================

local function Path(...)
    return Root .. "/" .. table.concat({...}, "/")
end

local function CreateFolder(...)
    local Folder = Path(...)
    if not isfolder(Folder) then
        makefolder(Folder)
    end

    return Folder
end

local function CreateFile(Content, ...)
    local File = Path(...)
    if not isfile(File) then
        writefile(File, Content or "")
    end

    return File
end

local function Encode(Data)
    local success, result = pcall(HttpService.JSONEncode, HttpService, Data)
    if success then
        return result
    else
        warn("Falha ao codificar JSON:", result)
        return "{}"
    end
end

local function Decode(Data)
    local success, result = pcall(HttpService.JSONDecode, HttpService, Data)
    if success then
        return result
    else
        warn("Falha ao decodificar JSON:", result)
        return {}
    end
end

local function LoadConfig(defaultConfig, ...)
    local File = Path(...)
    if isfile(File) then
        local decoded = Decode(readfile(File))
        if type(decoded) == "table" then
            return decoded
        end
    end

    writefile(File, Encode(defaultConfig))
    return defaultConfig
end

local function SaveConfig(config, ...)
    local File = Path(...)
    writefile(File, Encode(config))
end

-- =================================================
-- GAME
-- =================================================

local GameName = GetGame(game.PlaceId)

-- =================================================
-- FOLDERS
-- =================================================

CreateFolder("Library")
CreateFolder("Library", "Assets")

CreateFolder("Games")
CreateFolder("Games", GameName)
