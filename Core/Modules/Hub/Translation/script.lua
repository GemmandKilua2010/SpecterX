local BASE_URL, InjectedGames = ...
assert(type(BASE_URL) == "string", "Translation base URL is required.")

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

local Games = type(InjectedGames) == "table" and InjectedGames or Fetch("Games/games.lua")
Games = type(Games) == "table" and Games or {}

local Game = Games[game.PlaceId] or Games[game.GameId]

local Translation = {}
local Dictionaries = {}
local Aliases = {}
local Templates = {}
local TemplateLookup = {}

local function EscapePattern(Text)
    return (Text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function BuildTemplatePattern(Text)
    local Names = {}
    local Parts = {"^"}
    local Position = 1

    while true do
        local StartPosition, EndPosition, Name = Text:find("{([%w_]+)}", Position)

        if not StartPosition then
            Parts[#Parts + 1] = EscapePattern(Text:sub(Position))
            break
        end

        Parts[#Parts + 1] = EscapePattern(Text:sub(Position, StartPosition - 1))
        Parts[#Parts + 1] = "(.-)"
        Names[#Names + 1] = Name
        Position = EndPosition + 1
    end

    if #Names == 0 then
        return nil
    end

    Parts[#Parts + 1] = "$"
    return table.concat(Parts), Names
end

local function AddTemplate(Canonical, Variant)
    local Pattern, Names = BuildTemplatePattern(Variant)
    if not Pattern then
        return
    end

    local Signature = Canonical .. "\0" .. Variant
    if TemplateLookup[Signature] then
        return
    end

    TemplateLookup[Signature] = true
    Templates[#Templates + 1] = {
        Canonical = Canonical,
        Pattern = Pattern,
        Names = Names
    }
end

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
                    local Canonical = Lower(Key)
                    Dictionary[Canonical] = Value
                    Aliases[Canonical] = Canonical
                    local Alias = Lower(Value)
                    if Aliases[Alias] == nil then
                        Aliases[Alias] = Canonical
                    end
                    AddTemplate(Canonical, Key)
                    AddTemplate(Canonical, Value)
                end
            end
        end
    end
end

AddDictionary(Fetch("Core/translation.lua"))

if Game then
    AddDictionary(Fetch("Games/" .. Game .. "/translation.lua", 2))
end

function Translation:GetGames()
    return Games
end

function Translation:GetGame()
    return Game or "Universal"
end

function Translation:Translate(Text, Language)
    if type(Text) ~= "string" or type(Language) ~= "string" then
        return Text
    end

    local Dictionary = Dictionaries[Lower(Language)]
    if not Dictionary then
        return Text
    end

    local Lookup = Lower(Text)
    local Canonical = Aliases[Lookup] or Lookup
    local Direct = Dictionary[Canonical]

    if Direct then
        return Direct
    end

    for _, Template in ipairs(Templates) do
        local Captures = {Text:match(Template.Pattern)}

        if #Captures == #Template.Names and #Captures > 0 then
            local Target = Dictionary[Template.Canonical]

            if Target then
                local Values = {}

                for Index, Name in ipairs(Template.Names) do
                    Values[Name] = Captures[Index]
                end

                return (Target:gsub("{([%w_]+)}", function(Name)
                    return Values[Name] or "{" .. Name .. "}"
                end))
            end
        end
    end

    return Text
end

return Translation
