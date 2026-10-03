--// Game

local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
local Lower = string.lower

local function Fetch(Path, Retries)
    Retries = Retries or 3

    for Attempt = 1, Retries do
        local Success, Body = pcall(game.HttpGet, game, BASE_URL .. Path)

        if Success and type(Body) == "string" and Body ~= "" then
            local Chunk = loadstring(Body)
            if Chunk then
                local Loaded, Result = pcall(Chunk)
                if Loaded then
                    return Result
                end
            end
        end

        if Attempt < Retries then
            task.wait(0.5 * Attempt)
        end
    end

    return nil
end

local Games = Fetch("Games/games.lua")
local Game = type(Games) == "table" and (Games[game.PlaceId] or Games[game.GameId])

--// Translation

local Translation = {}
local Dictionaries = {}

local function AddDictionary(Loaded)
    if type(Loaded) ~= "table" then
        return
    end

    for Language, Entries in pairs(Loaded) do
        if type(Language) == "string" and type(Entries) == "table" then
            local LanguageKey = Lower(Language)
            local Dictionary = Dictionaries[LanguageKey]

            if not Dictionary then
                Dictionary = {}
                Dictionaries[LanguageKey] = Dictionary
            end

            for Key, Value in pairs(Entries) do
                if type(Key) == "string" and type(Value) == "string" then
                    Dictionary[Lower(Key)] = Value
                end
            end
        end
    end
end

AddDictionary(Fetch("Core/translation.lua"))
if Game then
    AddDictionary(Fetch("Games/" .. Game .. "/translation.lua", 2))
end

function Translation:Translate(Text, Language)
    if type(Text) ~= "string" or type(Language) ~= "string" then
        return Text
    end

    local Dictionary = Dictionaries[Lower(Language)]
    return Dictionary and Dictionary[Lower(Text)] or Text
end

return Translation
