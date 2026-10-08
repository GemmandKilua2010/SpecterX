local Hub, Config = ...

local Addons = {
    Themes = {},
    Languages = {},
    Sounds = {}
}

if type(Hub) ~= "table" or type(Config) ~= "table" then
    return Addons
end

local Templates = {
    theme = [=[--[[
PT-BR: Troque "return {}" pelo exemplo para criar um tema.
EN: Replace "return {}" with the example to create a theme.
ES: Sustituye "return {}" por el ejemplo para crear un tema.

Exemplo / Example / Ejemplo:
return {
    MyTheme = { Base = "Dark", ["Color Theme"] = Color3.fromRGB(40, 170, 255) }
}
]]
return {}
]=],
    language = [=[--[[
PT-BR: Troque "return {}" pelo exemplo para mudar traduções (BR = português).
EN: Replace "return {}" with the example to change translations (BR = Portuguese).
ES: Sustituye "return {}" por el ejemplo para cambiar traducciones (BR = portugués).

Exemplo / Example / Ejemplo:
return {
    BR = { Name = "Português (Brasil)", Translations = { ["Settings"] = "Ajustes" } }
}
]]
return {}
]=],
    sound = [=[--[[
PT-BR: Troque "return {}" pelo exemplo e use o ID de um áudio permitido.
EN: Replace "return {}" with the example and use an allowed audio ID.
ES: Sustituye "return {}" por el ejemplo y usa un ID de audio permitido.

Exemplo / Example / Ejemplo:
return {
    { Name = "MySound", Id = 1234567890 }
}
]]
return {}
]=]
}

local function Warn(Message)
    if type(Hub.Warn) == "function" then
        Hub:Warn("[Addon] " .. tostring(Message))
    end
end

local Created = Hub:CreateFolder("Addon")
if not Created then
    return Addons
end

local Environment = getfenv()
local ReadApi = Environment.readfile

if type(ReadApi) ~= "function" and type(Environment.getgenv) == "function" then
    local Success, Global = pcall(Environment.getgenv)
    if Success and type(Global) == "table" then
        ReadApi = Global.readfile
    end
end

if type(ReadApi) ~= "function" then
    return Addons
end

local function Load(Name)
    local Path = "Addon/" .. Name .. ".lua"
    local Source, ReadError = Hub:ReadFile(Path)

    if type(Source) ~= "string" then
        if Hub:FileExists(Path) then
            Warn("Could not read " .. Path .. ": " .. tostring(ReadError))
            return nil
        end

        if type(ReadError) == "string" and ReadError:find("read API is unavailable", 1, true) then
            return nil
        end

        local Written, Error = Hub:CreateFile(Path, Templates[Name])
        if not Written then
            Warn("Could not create " .. Path .. ": " .. tostring(Error))
            return nil
        end

        Source, ReadError = Hub:ReadFile(Path)
        if type(Source) ~= "string" then
            Warn("Could not read " .. Path .. ": " .. tostring(ReadError))
            return nil
        end
    end

    local Chunk, CompileError = Hub:Compile(Source, "@" .. Path)
    if type(Chunk) ~= "function" then
        Warn("Invalid " .. Path .. ": " .. tostring(CompileError))
        return nil
    end

    local Success, Data = pcall(Chunk)
    if not Success or type(Data) ~= "table" then
        Warn("Invalid " .. Path .. ": " .. tostring(Data))
        return nil
    end

    return Data
end

local ThemeFields = {
    ["Color Hub 1"] = "ColorSequence",
    ["Color Hub 2"] = "Color3",
    ["Color Stroke"] = "Color3",
    ["Color Theme"] = "Color3",
    ["Color Text"] = "Color3",
    ["Color Dark Text"] = "Color3"
}

local ThemeData = Load("theme")
if ThemeData then
    Config.Themes = type(Config.Themes) == "table" and Config.Themes or {}

    for Name, Definition in pairs(ThemeData) do
        if type(Name) == "string" and Name ~= "" and type(Definition) == "table" then
            local BasedOn = type(Definition.Base) == "string" and Definition.Base or Name
            local Original = Config.Themes[BasedOn] or Config.Themes.MetalRed
            local Palette = {}

            if type(Original) == "table" then
                for Key, Value in pairs(Original) do
                    Palette[Key] = Value
                end
            end

            local Valid = true

            for Key, Value in pairs(Definition) do
                local Expected = ThemeFields[Key]
                if Expected then
                    if typeof(Value) ~= Expected then
                        Valid = false
                        break
                    end
                    Palette[Key] = Value
                end
            end

            for Key, Expected in pairs(ThemeFields) do
                if typeof(Palette[Key]) ~= Expected then
                    Valid = false
                    break
                end
            end

            if Valid then
                Config.Themes[Name] = Palette
                Addons.Themes[#Addons.Themes + 1] = Name
            else
                Warn("Invalid theme: " .. Name)
            end
        end
    end
end

local LanguageData = Load("language")
if LanguageData then
    Config.Language = type(Config.Language) == "table" and Config.Language or {}
    local Names = type(Config.Language.Names) == "table" and Config.Language.Names or {}
    Config.Language.Names = Names

    local Dictionaries = {}

    for Code, Definition in pairs(LanguageData) do
        if type(Code) == "string" and Code:match("^[%w_%-]+$") and type(Definition) == "table" then
            local Language = Code:upper()
            local Translations = Definition.Translations or Definition.Dictionary or Definition
            if type(Translations) == "table" then
                local Dictionary = {}
                for Key, Value in pairs(Translations) do
                    if type(Key) == "string" and type(Value) == "string" and Key ~= "Name" then
                        Dictionary[Key] = Value
                    end
                end

                Names[Language] = type(Definition.Name) == "string" and Definition.Name ~= ""
                    and Definition.Name or Names[Language] or Language
                Dictionaries[Language] = Dictionary
                Addons.Languages[#Addons.Languages + 1] = Language
            end
        end
    end

    if next(Dictionaries) and type(Hub.RegisterTranslations) == "function" then
        Hub:RegisterTranslations(Dictionaries)
    end
end

local SoundData = Load("sound")
if SoundData then
    Config.Library = type(Config.Library) == "table" and Config.Library or {}
    Config.Library.Audio = type(Config.Library.Audio) == "table" and Config.Library.Audio or {}

    local Presets = type(Config.Library.Audio.Presets) == "table" and Config.Library.Audio.Presets or {}
    Config.Library.Audio.Presets = Presets

    local function NormalizeId(Value)
        if type(Value) ~= "string" and type(Value) ~= "number" then
            return nil
        end

        local Raw = tostring(Value)
        return Raw:match("^rbxassetid://(%d+)$") or Raw:match("^(%d+)$")
    end

    for _, Definition in ipairs(SoundData) do
        if type(Definition) == "table" and type(Definition.Name) == "string" and Definition.Name ~= "" then
            local Id = NormalizeId(Definition.Id or Definition.SoundId)
            if Id then
                local Entry = {Name = Definition.Name, Id = Id}
                local Found

                for Index, Preset in ipairs(Presets) do
                    if Preset.Name == Entry.Name or NormalizeId(Preset.Id or Preset.SoundId) == Id then
                        Found = Index
                        break
                    end
                end

                if Found then
                    Presets[Found] = Entry
                else
                    Presets[#Presets + 1] = Entry
                end

                Addons.Sounds[#Addons.Sounds + 1] = Entry.Name
            end
        end
    end
end

table.sort(Addons.Themes)
table.sort(Addons.Languages)
return Addons
