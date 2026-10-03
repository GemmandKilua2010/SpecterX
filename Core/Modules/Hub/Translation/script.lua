--// Context
local Context = ...
Context = type(Context) == "table" and Context or {}

--// Cache
local Lower = string.lower
local LoadRequire = Context.LoadRequire

--// Require
local function Fetch(Path, Retries)
    if type(LoadRequire) ~= "function" then
        return nil
    end

    return LoadRequire(Path, nil, Retries)
end

--// Games
local Games = Context.Games
if type(Games) ~= "table" then
    Games = Fetch("Games/games.lua")
end

local Game = type(Games) == "table" and (Games[game.PlaceId] or Games[game.GameId])

--// Translation
local Dictionaries = {}
local Translation = {}

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

local function Interpolate(Text, Params)
    if type(Text) ~= "string" or type(Params) ~= "table" then
        return Text
    end

    return (Text:gsub("{([%w_]+)}", function(Key)
        local Value = Params[Key]
        if Value == nil then
            return "{" .. Key .. "}"
        end
        return tostring(Value)
    end))
end

AddDictionary(Fetch(Context.TranslationPath or "Core/translation.lua"))
if Game then
    AddDictionary(Fetch("Games/" .. Game .. "/translation.lua", 2))
end

function Translation:Translate(Text, Language, Params)
    if type(Text) ~= "string" then
        return Text
    end

    local LanguageKey = type(Language) == "string" and Lower(Language) or "us"
    local Key = Lower(Text)
    local Dictionary = Dictionaries[LanguageKey]
    local DefaultDictionary = Dictionaries.us
    local Result = Dictionary and Dictionary[Key]

    if Result == nil and DefaultDictionary then
        Result = DefaultDictionary[Key]
    end

    return Interpolate(Result or Text, Params)
end

function Translation:HasLanguage(Language)
    return type(Language) == "string" and Dictionaries[Lower(Language)] ~= nil
end

return Translation
