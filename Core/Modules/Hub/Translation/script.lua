local BASE_URL, InjectedGames, Game = ...
assert(type(BASE_URL) == "string", "Translation base URL is required.")

local HttpService = game:GetService("HttpService")
local Lower = string.lower

local function Fetch(Path, Retries)
    Retries = Retries or 3

    for Attempt = 1, Retries do
        -- Each dictionary request needs a fresh URL; cached raw responses may
        -- lack recently added translations even when the repository is updated.
        local Url = BASE_URL .. Path
        Url ..= (Url:find("?", 1, true) and "&" or "?") .. "sx=" .. HttpService:GenerateGUID(false)
        local Success, Body = pcall(game.HttpGet, game, Url)

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

Game = type(Game) == "string" and Game ~= "Universal" and Game or nil

local Translation = {}
local Dictionaries = {}
local Aliases = {}
local AnyLanguageAliases = {}
local Templates = {}
local TemplateLookup = {}
local BuiltInLanguageAliases = {pt = "br", en = "us", es = "es"}

local function NormalizeLanguageTag(Value)
    return Lower(tostring(Value or "")):gsub("^%s+", ""):gsub("%s+$", ""):gsub("_", "-")
end

local function NormalizeText(Value)
    return Lower(tostring(Value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ResolveDictionaryKey(Language)
    local Key = NormalizeLanguageTag(Language)
    if Dictionaries[Key] then return Key end

    local Base = Key:match("^([^-]+)")
    if Base and Dictionaries[Base] then return Base end

    local BaseAlias = Base and BuiltInLanguageAliases[Base]
    if BaseAlias and Dictionaries[BaseAlias] then return BaseAlias end

    local Region = Key:match("%-([^-]+)$")
    if Region and Dictionaries[Region] then return Region end
    return nil
end

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

local function AddTemplate(LanguageKey, Canonical, Variant)
    local Pattern, Names = BuildTemplatePattern(Variant)
    if not Pattern then
        return
    end

    local Signature = NormalizeText(Canonical) .. "\0" .. Variant
    local LanguageLookup = TemplateLookup[LanguageKey]
    if not LanguageLookup then
        LanguageLookup = {}
        TemplateLookup[LanguageKey] = LanguageLookup
    end
    if LanguageLookup[Signature] then
        return
    end

    LanguageLookup[Signature] = true
    local LanguageTemplates = Templates[LanguageKey]
    if not LanguageTemplates then
        LanguageTemplates = {}
        Templates[LanguageKey] = LanguageTemplates
    end
    local PlaceholderCount = #Names
    local Candidates = LanguageTemplates[PlaceholderCount]
    if not Candidates then
        Candidates = {}
        LanguageTemplates[PlaceholderCount] = Candidates
    end
    Candidates[#Candidates + 1] = {
        Canonical = NormalizeText(Canonical),
        Pattern = Pattern,
        Names = Names,
        Specificity = #Variant - PlaceholderCount
    }
end

local function AddDictionary(Loaded)
    if type(Loaded) ~= "table" then
        return
    end

    for Language, Entries in pairs(Loaded) do
        if type(Language) == "string" and type(Entries) == "table" then
            local LanguageKey = NormalizeLanguageTag(Language)
            local Dictionary = Dictionaries[LanguageKey]

            if not Dictionary then
                Dictionary = {}
                Dictionaries[LanguageKey] = Dictionary
            end

            local LanguageAliases = Aliases[LanguageKey]
            if not LanguageAliases then
                LanguageAliases = {}
                Aliases[LanguageKey] = LanguageAliases
            end

            for Key, Value in pairs(Entries) do
                if type(Key) == "string" and type(Value) == "string" then
                    local Canonical = NormalizeText(Key)
                    if Canonical == "" then continue end
                    Dictionary[Canonical] = Value
                    LanguageAliases[Canonical] = Canonical
                    local ExistingCanonical = AnyLanguageAliases[Canonical]
                    if ExistingCanonical == nil then
                        AnyLanguageAliases[Canonical] = Canonical
                    elseif ExistingCanonical ~= Canonical then
                        AnyLanguageAliases[Canonical] = false
                    end
                    local Alias = NormalizeText(Value)
                    if Alias ~= "" then
                        local Existing = LanguageAliases[Alias]
                        if Existing == nil then
                            LanguageAliases[Alias] = Canonical
                        elseif Existing ~= Canonical then
                            -- A translated phrase that maps to multiple source
                            -- keys is ambiguous; leave it untouched.
                            LanguageAliases[Alias] = false
                        end

                        local ExistingAnyLanguage = AnyLanguageAliases[Alias]
                        if ExistingAnyLanguage == nil then
                            AnyLanguageAliases[Alias] = Canonical
                        elseif ExistingAnyLanguage ~= Canonical then
                            AnyLanguageAliases[Alias] = false
                        end
                    end
                    AddTemplate(LanguageKey, Canonical, Key)
                    AddTemplate(LanguageKey, Canonical, Value)
                end
            end

            for _, Candidates in pairs(Templates[LanguageKey] or {}) do
                table.sort(Candidates, function(Left, Right)
                    return Left.Specificity > Right.Specificity
                end)
            end
        end
    end
end

AddDictionary(Fetch("Core/translation.lua"))

if Game then
    AddDictionary(Fetch("Games/" .. Game .. "/translation.lua", 2))
end

function Translation:AddDictionary(Data)
    if type(Data) ~= "table" then
        return false
    end

    AddDictionary(Data)
    return true
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

    local Leading, Content, Trailing = Text:match("^(%s*)(.-)(%s*)$")
    Content = Content or Text
    local LanguageKey = ResolveDictionaryKey(Language)
    local Dictionary = LanguageKey and Dictionaries[LanguageKey]
    if not Dictionary then
        return Text
    end

    local Lookup = NormalizeText(Content)
    local Direct = Dictionary[Lookup]
    if Direct == nil then
        local AliasesForLanguage = Aliases[LanguageKey]
        local Canonical = AliasesForLanguage and AliasesForLanguage[Lookup]
        Direct = Canonical and Dictionary[Canonical] or nil
    end
    if Direct == nil then
        local Canonical = AnyLanguageAliases[Lookup]
        Direct = Canonical and Dictionary[Canonical] or nil
    end

    -- Incomplete addon or game dictionaries fall back to the English source
    -- dictionary before returning the caller's original text.
    if Direct == nil and LanguageKey ~= "us" then
        local English = Dictionaries.us
        if English then
            Direct = English[Lookup]
            if Direct == nil then
                local EnglishAlias = Aliases.us and Aliases.us[Lookup]
                Direct = EnglishAlias and English[EnglishAlias] or nil
            end
            if Direct == nil then
                local EnglishCanonical = AnyLanguageAliases[Lookup]
                Direct = EnglishCanonical and English[EnglishCanonical] or nil
            end
        end
    end

    if Direct ~= nil then
        return (Leading or "") .. Direct .. (Trailing or "")
    end

    local _, PlaceholderCount = Content:gsub("{[%w_]+}", "")
    local Candidates = Templates[LanguageKey] and Templates[LanguageKey][PlaceholderCount]
    local function MatchTemplate(TemplateList, TargetDictionary)
        for _, Template in ipairs(TemplateList or {}) do
            local Captures = {Content:match(Template.Pattern)}
            if #Captures == #Template.Names and #Captures > 0 then
                local Target = TargetDictionary[Template.Canonical]
                if Target then
                    local Values = {}
                    for Index, Name in ipairs(Template.Names) do
                        Values[Name] = Captures[Index]
                    end
                    local Translated = Target:gsub("{([%w_]+)}", function(Name)
                        local Value = Values[Name]
                        return Value == nil and "{" .. Name .. "}" or tostring(Value)
                    end)
                    return (Leading or "") .. Translated .. (Trailing or "")
                end
            end
        end
    end

    local Matched = MatchTemplate(Candidates, Dictionary)
    if Matched then return Matched end

    if LanguageKey ~= "us" and Dictionaries.us then
        Matched = MatchTemplate(Templates.us and Templates.us[PlaceholderCount], Dictionaries.us)
        if Matched then return Matched end
    end

    return Text
end

return Translation
