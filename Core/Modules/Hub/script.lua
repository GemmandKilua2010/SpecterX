--// Services
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local CoreGui = game:GetService("CoreGui")

--// Context
local Context = ...
Context = type(Context) == "table" and Context or {}

local RawConfig = type(Context.Config) == "table" and Context.Config or {}
local BASE_URL = type(Context.BaseUrl) == "string" and Context.BaseUrl or ""
local Paths = type(RawConfig.Paths) == "table" and RawConfig.Paths or {}

--// Cache
local Lower = string.lower
local Upper = string.upper
local Regions = setmetatable({}, {__mode = "k"})
local RNG = Random.new()
local Characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local CharacterCount = #Characters
local ScriptEnvironment = getfenv()
local GetGenv = ScriptEnvironment.getgenv
local GlobalEnvironment = ScriptEnvironment

if type(GetGenv) == "function" then
    local Success, Environment = pcall(GetGenv)
    if Success and type(Environment) == "table" then
        GlobalEnvironment = Environment
    end
end

--// Bootstrap Translation
local BootstrapMessages = {
    US = {
        ["Console.InvalidUrl"] = "Invalid URL.",
        ["Console.HttpUnavailable"] = "No available HTTP API could load {Url}{Details}.",
        ["Console.LoadstringUnavailable"] = "loadstring is not available in this environment.",
        ["Console.CompileFailed"] = "Failed to compile {Path}: {Error}",
        ["Console.ModuleLoadFailed"] = "Failed to load {Path}: {Error}",
        ["Console.RequestFailed"] = "request failed",
        ["Console.UnknownCompileError"] = "unknown compile error",
        ["Environment.SetClipboardUnavailable"] = "setclipboard is not available.",
        ["Environment.ReadFileUnavailable"] = "readfile is not available.",
        ["Environment.WriteFileUnavailable"] = "writefile is not available."
    },
    BR = {
        ["Console.InvalidUrl"] = "URL inválida.",
        ["Console.HttpUnavailable"] = "Nenhuma API HTTP disponível conseguiu carregar {Url}{Details}.",
        ["Console.LoadstringUnavailable"] = "loadstring não está disponível neste ambiente.",
        ["Console.CompileFailed"] = "Falha ao compilar {Path}: {Error}",
        ["Console.ModuleLoadFailed"] = "Falha ao carregar {Path}: {Error}",
        ["Console.RequestFailed"] = "falha na requisição",
        ["Console.UnknownCompileError"] = "erro de compilação desconhecido",
        ["Environment.SetClipboardUnavailable"] = "setclipboard não está disponível.",
        ["Environment.ReadFileUnavailable"] = "readfile não está disponível.",
        ["Environment.WriteFileUnavailable"] = "writefile não está disponível."
    },
    ES = {
        ["Console.InvalidUrl"] = "URL no válida.",
        ["Console.HttpUnavailable"] = "Ninguna API HTTP disponible pudo cargar {Url}{Details}.",
        ["Console.LoadstringUnavailable"] = "loadstring no está disponible en este entorno.",
        ["Console.CompileFailed"] = "No se pudo compilar {Path}: {Error}",
        ["Console.ModuleLoadFailed"] = "No se pudo cargar {Path}: {Error}",
        ["Console.RequestFailed"] = "falló la solicitud",
        ["Console.UnknownCompileError"] = "error de compilación desconocido",
        ["Environment.SetClipboardUnavailable"] = "setclipboard no está disponible.",
        ["Environment.ReadFileUnavailable"] = "readfile no está disponible.",
        ["Environment.WriteFileUnavailable"] = "writefile no está disponible."
    }
}

--// Helpers
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

local BootstrapLanguage
local function GetBootstrapLanguage()
    if BootstrapLanguage then
        return BootstrapLanguage
    end

    BootstrapLanguage = "US"
    local Player = Players.LocalPlayer
    if not Player then
        return BootstrapLanguage
    end

    local Success, Region = pcall(
        LocalizationService.GetCountryRegionForPlayerAsync,
        LocalizationService,
        Player
    )

    if Success and type(Region) == "string" then
        Region = Upper(Region)
        if BootstrapMessages[Region] then
            BootstrapLanguage = Region
        end
    end

    return BootstrapLanguage
end

local MessageResolver = function(Key, Params)
    local Language = GetBootstrapLanguage()
    local Dictionary = BootstrapMessages[Language] or BootstrapMessages.US
    local Text = Dictionary[Key] or BootstrapMessages.US[Key] or Key
    return Interpolate(Text, Params)
end

local TitleResolver = function()
    return nil
end

local function FormatConsole(Key, Params)
    local Message = MessageResolver(Key, Params)
    local Title = TitleResolver()
    return Title and ("[%s] %s"):format(Title, Message) or Message
end

--// Environment
local Environment = {}

local function GetGlobalValue(Name)
    local Value = ScriptEnvironment[Name]
    if Value ~= nil then
        return Value
    end

    if GlobalEnvironment ~= ScriptEnvironment then
        return GlobalEnvironment[Name]
    end

    return nil
end

local function GetGlobalFunction(Name)
    local Value = GetGlobalValue(Name)
    return type(Value) == "function" and Value or nil
end

function Environment:GetGlobalEnvironment()
    return GlobalEnvironment
end

function Environment:GetFunction(Name)
    return GetGlobalFunction(Name)
end

function Environment:HttpGet(Url, NoCache)
    if type(Url) ~= "string" or Url == "" then
        error(FormatConsole("Console.InvalidUrl"), 2)
    end

    local Errors = {}
    local Success, Result = pcall(function()
        return game:HttpGet(Url, NoCache)
    end)

    if Success and type(Result) == "string" then
        return Result
    end

    if not Success then
        Errors[#Errors + 1] = tostring(Result)
    end

    local HttpGet = GetGlobalFunction("httpget")
    if HttpGet then
        Success, Result = pcall(HttpGet, game, Url, NoCache == true)
        if not Success then
            Success, Result = pcall(HttpGet, Url, NoCache == true)
        end
        if Success and type(Result) == "string" then
            return Result
        end
        if not Success then
            Errors[#Errors + 1] = tostring(Result)
        end
    end

    local Request = GetGlobalFunction("request") or GetGlobalFunction("http_request")
    local Http = GetGlobalValue("http")
    local Syn = GetGlobalValue("syn")

    if not Request and type(Http) == "table" and type(Http.request) == "function" then
        Request = Http.request
    end

    if not Request and type(Syn) == "table" and type(Syn.request) == "function" then
        Request = Syn.request
    end

    if Request then
        Success, Result = pcall(Request, {
            Url = Url,
            Method = "GET",
        })

        if Success and type(Result) == "table" then
            local StatusCode = tonumber(Result.StatusCode)
            if Result.Success ~= false and (not StatusCode or (StatusCode >= 200 and StatusCode < 300)) and type(Result.Body) == "string" then
                return Result.Body
            end

            Errors[#Errors + 1] = tostring(Result.StatusMessage or StatusCode or MessageResolver("Console.RequestFailed"))
        elseif not Success then
            Errors[#Errors + 1] = tostring(Result)
        end
    end

    local Details = #Errors > 0 and (": " .. table.concat(Errors, " | ")) or ""
    error(FormatConsole("Console.HttpUnavailable", {Url = Url, Details = Details}), 2)
end

function Environment:Compile(Source, ChunkName)
    local Compiler = GetGlobalFunction("loadstring")
    if not Compiler then
        error(FormatConsole("Console.LoadstringUnavailable"), 2)
    end

    return Compiler(Source, ChunkName)
end

function Environment:GetUIParent()
    local GetHui = GetGlobalFunction("gethui")
    if GetHui then
        local Success, Parent = pcall(GetHui)
        if Success and typeof(Parent) == "Instance" then
            return Parent
        end
    end

    local Success = pcall(function()
        local Probe = Instance.new("Folder")
        Probe.Parent = CoreGui
        Probe:Destroy()
    end)

    if Success then
        return CoreGui
    end

    local Player = Players.LocalPlayer
    return Player and (Player:FindFirstChildOfClass("PlayerGui") or Player:WaitForChild("PlayerGui", 10)) or nil
end

function Environment:SetClipboard(Text)
    local SetClipboard = GetGlobalFunction("setclipboard")
    if not SetClipboard then
        return false, MessageResolver("Environment.SetClipboardUnavailable")
    end

    local Success, Error = pcall(SetClipboard, tostring(Text or ""))
    return Success, Success and nil or Error
end

function Environment:IsFile(Path)
    local IsFile = GetGlobalFunction("isfile")
    if not IsFile then
        return false
    end

    local Success, Result = pcall(IsFile, Path)
    return Success and Result == true
end

function Environment:ReadFile(Path)
    local ReadFile = GetGlobalFunction("readfile")
    if not ReadFile then
        return nil, MessageResolver("Environment.ReadFileUnavailable")
    end

    local Success, Result = pcall(ReadFile, Path)
    if Success then
        return Result
    end

    return nil, Result
end

function Environment:WriteFile(Path, Content)
    local WriteFile = GetGlobalFunction("writefile")
    if not WriteFile then
        return false, MessageResolver("Environment.WriteFileUnavailable")
    end

    local Success, Error = pcall(WriteFile, Path, Content)
    return Success, Success and nil or Error
end

--// Require
local NetworkConfig = type(RawConfig.Network) == "table" and RawConfig.Network or {}

local function LoadRequire(Url, Base, Retries, ...)
    Retries = math.max(1, math.floor(tonumber(Retries) or tonumber(NetworkConfig.Retries) or 3))
    local FullUrl = (Base or BASE_URL) .. Url
    local Arguments = table.pack(...)
    local LastError

    for Attempt = 1, Retries do
        local Success, Result = pcall(function()
            local Source = Environment:HttpGet(FullUrl, NetworkConfig.NoCache == true)
            local Chunk, CompileError = Environment:Compile(Source, "=" .. Url)
            if not Chunk then
                error(FormatConsole("Console.CompileFailed", {
                    Path = Url,
                    Error = tostring(CompileError or MessageResolver("Console.UnknownCompileError"))
                }), 0)
            end
            return Chunk(table.unpack(Arguments, 1, Arguments.n))
        end)

        if Success then
            return Result
        end

        LastError = Result
        if Attempt < Retries then
            local Delay = math.max(0, tonumber(NetworkConfig.RetryDelay) or 0.5)
            task.wait(Delay * Attempt)
        end
    end

    warn(FormatConsole("Console.ModuleLoadFailed", {
        Path = Url,
        Error = tostring(LastError)
    }))
    return nil
end

local function BuildLookup(Value)
    local Lookup = {}

    if type(Value) == "table" then
        for Key, Item in pairs(Value) do
            Lookup[Lower(tostring(Key))] = Item
        end
    end

    return Lookup
end

local function IsImageKey(Key)
    if Key == nil then
        return false
    end

    Key = Lower(tostring(Key))
    return Key:find("image", 1, true) ~= nil
        or Key:find("logo", 1, true) ~= nil
        or Key:find("icon", 1, true) ~= nil
end

--// Config
local Configs = BuildLookup(RawConfig)
local ConfigTitle = tostring(Configs.title or "Script")
TitleResolver = function()
    return ConfigTitle
end

--// Games
local Games = LoadRequire(Paths.Games or "Games/games.lua")
if type(Games) ~= "table" then
    Games = {}
end

--// Translation
local Translation = LoadRequire(Paths.TranslationModule or "Core/Modules/Hub/Translation/script.lua", nil, nil, {
    Environment = Environment,
    LoadRequire = LoadRequire,
    Games = Games,
    BaseUrl = BASE_URL,
    TranslationPath = Paths.Translation or "Core/translation.lua"
})

if type(Translation) ~= "table" or type(Translation.Translate) ~= "function" then
    Translation = {
        Translate = function(_, Text, _, Params)
            return Interpolate(Text, Params)
        end,
        HasLanguage = function(_, Language)
            return type(Language) == "string" and Upper(Language) == "US"
        end,
    }
end

local function LanguageConfig()
    local Value = Configs.language
    return type(Value) == "table" and Value or {}
end

local function LanguageValue(Table, Name, Default)
    if type(Table) ~= "table" then
        return Default
    end

    local Value = Table[Name]
    if Value == nil then
        Value = Table[Lower(Name)]
    end
    return Value == nil and Default or Value
end

--// Hub
local Main = {
    Environment = Environment
}

function Main:GetTitle()
    return ConfigTitle
end

function Main:GetDefaultLanguage()
    local Config = LanguageConfig()
    local Default = tostring(LanguageValue(Config, "Default", "US"))
    return Upper(Default)
end

function Main:GetPlayerRegion(Player, Silent)
    Player = Player or Players.LocalPlayer
    if not Player then
        if not Silent then
            self:Warn("Console.NoLocalPlayer", nil, self:GetDefaultLanguage())
        end
        return nil
    end

    local Cached = Regions[Player]
    if Cached then
        return Cached
    end

    local Success, Region = pcall(
        LocalizationService.GetCountryRegionForPlayerAsync,
        LocalizationService,
        Player
    )

    if not Success or type(Region) ~= "string" then
        return nil
    end

    Region = Upper(Region)
    Regions[Player] = Region
    return Region
end

function Main:GetLanguage(Player)
    local Config = LanguageConfig()
    local Default = self:GetDefaultLanguage()

    if LanguageValue(Config, "AutoDetect", true) == false then
        return Default
    end

    local Region = self:GetPlayerRegion(Player, true)
    if not Region then
        return Default
    end

    local Countries = LanguageValue(Config, "Countries", {})
    local Language = type(Countries) == "table" and (Countries[Region] or Countries[Lower(Region)]) or nil
    Language = type(Language) == "string" and Upper(Language) or Default

    if type(Translation.HasLanguage) == "function" and not Translation:HasLanguage(Language) then
        return Default
    end

    return Language
end

function Main:Translate(Text, Language, Params)
    local FinalParams = {
        Title = self:GetTitle(),
        Author = tostring(RawConfig.Author or "")
    }
    if type(Params) == "table" then
        for Key, Value in pairs(Params) do
            FinalParams[Key] = Value
        end
    end

    return Translation:Translate(Text, Language or self:GetLanguage(), FinalParams)
end

function Main:FormatConsole(Text, Params, Language)
    return ("[%s] %s"):format(self:GetTitle(), self:Translate(Text, Language, Params))
end

function Main:Print(Text, Params, Language)
    print(self:FormatConsole(Text, Params, Language))
end

function Main:Warn(Text, Params, Language)
    warn(self:FormatConsole(Text, Params, Language))
end

function Main:Error(Text, Params, Level, Language)
    error(self:FormatConsole(Text, Params, Language), tonumber(Level) or 2)
end

function Main:Console(Level, Text, Params, Language)
    Level = type(Level) == "string" and Lower(Level) or "print"

    if Level == "warn" or Level == "warning" then
        return self:Warn(Text, Params, Language)
    end

    if Level == "error" then
        return self:Error(Text, Params, 3, Language)
    end

    return self:Print(Text, Params, Language)
end

MessageResolver = function(Key, Params)
    return Main:Translate(Key, nil, Params)
end

TitleResolver = function()
    return Main:GetTitle()
end

local function ResolveConfig(Value, Language, Key)
    local ValueType = type(Value)

    if ValueType == "string" then
        return Main:Translate(Value, Language)
    end

    if ValueType == "number" then
        return IsImageKey(Key) and "rbxassetid://" .. Value or Value
    end

    if ValueType ~= "table" then
        return Value
    end

    local Result = {}
    for ItemKey, ItemValue in pairs(Value) do
        Result[ItemKey] = ResolveConfig(ItemValue, Language, ItemKey)
    end

    return Result
end

function Main:LoadRequire(Url, Base, Retries, ...)
    return LoadRequire(Url, Base, Retries, ...)
end

function Main:GetEnvironment()
    return Environment
end

function Main:GetGame()
    return Games[game.PlaceId] or Games[game.GameId] or "Universal"
end

function Main:GetConfig(Name)
    return ResolveConfig(Configs[Lower(tostring(Name))], self:GetLanguage())
end

function Main:GetRawConfig(Name)
    if Name == nil then
        return RawConfig
    end
    return Configs[Lower(tostring(Name))]
end

function Main:GetPath(Name)
    if type(Name) ~= "string" then
        return nil
    end
    return Paths[Name] or Paths[Lower(Name)]
end

--// Runtime
function Main:GetGenv()
    local Title = self:GetTitle()
    GlobalEnvironment[Title] = GlobalEnvironment[Title] or {}
    return GlobalEnvironment[Title]
end

function Main:GetRuntime(Name)
    local Genv = self:GetGenv()
    Genv.Runtime = Genv.Runtime or {}

    if Name == nil then
        return Genv.Runtime
    end

    Name = tostring(Name)
    Genv.Runtime[Name] = Genv.Runtime[Name] or {}
    return Genv.Runtime[Name]
end

--// Utils
function Main:GenerateName(Length: number?): string
    local Size = math.clamp(math.floor(tonumber(Length) or 12), 1, 256)
    local Result = table.create(Size)

    for Index = 1, Size do
        local Position = RNG:NextInteger(1, CharacterCount)
        Result[Index] = Characters:sub(Position, Position)
    end

    return table.concat(Result)
end

return Main
