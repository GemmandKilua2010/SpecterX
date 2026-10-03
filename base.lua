--// Services
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

--// Bootstrap
local DEFAULT_CONFIG_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/config.lua"
local Argument = ...
local Bootstrap = type(Argument) == "table" and Argument or {}
local ConfigUrl = type(Bootstrap.ConfigUrl) == "string" and Bootstrap.ConfigUrl or DEFAULT_CONFIG_URL
local UseLoaderArgument = type(Argument) == "boolean" and Argument or Bootstrap.LoadingScreen

local BootstrapMessages = {
    US = {
        Http = "Failed to load {Url}.",
        Compile = "Failed to compile {Path}: {Error}",
        Config = "Critical failure: invalid Config.",
        Hub = "Critical failure: invalid Hub.",
        Loadstring = "loadstring is not available in this environment."
    },
    BR = {
        Http = "Falha ao carregar {Url}.",
        Compile = "Falha ao compilar {Path}: {Error}",
        Config = "Falha crítica: Config inválido.",
        Hub = "Falha crítica: Hub inválido.",
        Loadstring = "loadstring não está disponível neste ambiente."
    },
    ES = {
        Http = "No se pudo cargar {Url}.",
        Compile = "No se pudo compilar {Path}: {Error}",
        Config = "Fallo crítico: Config no válido.",
        Hub = "Fallo crítico: Hub no válido.",
        Loadstring = "loadstring no está disponible en este entorno."
    }
}

local function GetBootstrapLanguage()
    local Player = Players.LocalPlayer
    if not Player then
        return "US"
    end

    local Success, Region = pcall(
        LocalizationService.GetCountryRegionForPlayerAsync,
        LocalizationService,
        Player
    )

    Region = Success and type(Region) == "string" and string.upper(Region) or "US"
    return BootstrapMessages[Region] and Region or "US"
end

local BootstrapLanguage = GetBootstrapLanguage()

local function BootstrapText(Key, Params)
    local Dictionary = BootstrapMessages[BootstrapLanguage] or BootstrapMessages.US
    local Text = Dictionary[Key] or BootstrapMessages.US[Key] or Key

    if type(Params) == "table" then
        Text = Text:gsub("{([%w_]+)}", function(Name)
            local Value = Params[Name]
            return Value == nil and ("{" .. Name .. "}") or tostring(Value)
        end)
    end

    return Text
end

local ScriptEnvironment = getfenv()

local function GetGlobalEnvironment()
    local GetGenv = ScriptEnvironment.getgenv
    if type(GetGenv) == "function" then
        local Success, Environment = pcall(GetGenv)
        if Success and type(Environment) == "table" then
            return Environment
        end
    end

    return ScriptEnvironment
end

local function GetGlobal(Name)
    local Value = ScriptEnvironment[Name]
    if Value ~= nil then
        return Value
    end

    local Environment = GetGlobalEnvironment()
    if Environment ~= ScriptEnvironment then
        return Environment[Name]
    end

    return nil
end

local function HttpGet(Url)
    local Success, Result = pcall(function()
        return game:HttpGet(Url)
    end)

    if Success and type(Result) == "string" then
        return Result
    end

    local Global = GetGlobalEnvironment()
    local HttpGetFunction = GetGlobal("httpget")

    if type(HttpGetFunction) == "function" then
        Success, Result = pcall(HttpGetFunction, game, Url, false)
        if not Success then
            Success, Result = pcall(HttpGetFunction, Url, false)
        end
        if Success and type(Result) == "string" then
            return Result
        end
    end

    local Request = GetGlobal("request") or GetGlobal("http_request")
    local Http = GetGlobal("http")
    local Syn = GetGlobal("syn")

    if type(Request) ~= "function" and type(Http) == "table" then
        Request = Http.request
    end

    if type(Request) ~= "function" and type(Syn) == "table" then
        Request = Syn.request
    end

    if type(Request) == "function" then
        Success, Result = pcall(Request, {
            Url = Url,
            Method = "GET"
        })

        if Success and type(Result) == "table" and type(Result.Body) == "string" then
            local StatusCode = tonumber(Result.StatusCode)
            if Result.Success ~= false and (not StatusCode or (StatusCode >= 200 and StatusCode < 300)) then
                return Result.Body
            end
        end
    end

    error(BootstrapText("Http", {Url = Url}), 0)
end

local function Compile(Source, Path)
    local Compiler = GetGlobal("loadstring")
    if type(Compiler) ~= "function" then
        error(BootstrapText("Compile", {Path = Path, Error = BootstrapText("Loadstring")}), 0)
    end

    local Chunk, CompileError = Compiler(Source, "=" .. Path)
    if not Chunk then
        error(BootstrapText("Compile", {Path = Path, Error = tostring(CompileError)}), 0)
    end

    return Chunk
end

local function BuildBaseUrl(Repository)
    if type(Repository) ~= "table" then
        return nil
    end

    if type(Repository.BaseUrl) == "string" and Repository.BaseUrl ~= "" then
        return Repository.BaseUrl:sub(-1) == "/" and Repository.BaseUrl or (Repository.BaseUrl .. "/")
    end

    local Owner = tostring(Repository.Owner or "")
    local Name = tostring(Repository.Name or "")
    local Branch = tostring(Repository.Branch or "main")

    if Owner == "" or Name == "" or Branch == "" then
        return nil
    end

    return ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/"):format(Owner, Name, Branch)
end

--// Config
local Config = Compile(HttpGet(ConfigUrl), "Core/config.lua")()
if type(Config) ~= "table" then
    error(BootstrapText("Config"), 0)
end

local BaseUrl = BuildBaseUrl(Config.Repository)
if not BaseUrl then
    error(BootstrapText("Config"), 0)
end

local Paths = type(Config.Paths) == "table" and Config.Paths or {}
local HubPath = tostring(Paths.Hub or "Core/Modules/Hub/script.lua")

--// Hub
local Hub = Compile(HttpGet(BaseUrl .. HubPath), HubPath)({
    BaseUrl = BaseUrl,
    Config = Config
})

if type(Hub) ~= "table" then
    error(BootstrapText("Hub"), 0)
end

local Environment = Hub:GetEnvironment()
local Genv = Hub:GetGenv()
Genv.State = Genv.State or {}

if Genv.State.Loading then
    Hub:Warn("Console.AlreadyLoading")
    return Genv.State.Base
end

Genv.State.Loading = true

--// Build
local function Build()
    local PreviousBase = Genv.State.Base
    if type(PreviousBase) == "table" and type(PreviousBase.Destroy) == "function" then
        pcall(PreviousBase.Destroy, PreviousBase)
    end

    Genv.State.Base = nil
    Genv.State.Window = nil

    local function Load(Path, ...)
        return Hub:LoadRequire(Path, nil, nil, ...)
    end

    local function GetConfig(Name)
        return Hub:GetConfig(Name)
    end

    local ModuleContext = {
        Environment = Environment,
        Hub = Hub
    }

    local Notification = Load(Paths.Notification or "Core/Modules/Hub/Notification/script.lua", ModuleContext)
    if type(Notification) ~= "table" then
        Notification = {}
    end

    local LoaderConfig = GetConfig("Loader") or {}
    local UseLoader = UseLoaderArgument
    if UseLoader == nil then
        UseLoader = LoaderConfig.Enabled == true
    end

    if UseLoader then
        local Loader = Load(Paths.Loader or "Core/Modules/Loader/script.lua", {Hub = Hub})
        if type(Loader) == "table" and type(Loader.Run) == "function" then
            Loader:Run(LoaderConfig)
        end
    end

    local Library = Load(Paths.Library or "Core/Library/lib.lua", ModuleContext)
    if type(Library) ~= "table" then
        Hub:Error("Console.LibraryLoadFailed", nil, 0)
    end

    local Base = {
        Library = Library,
        Notification = Notification,
        Hub = Hub,
        Title = ("%s | %s"):format(tostring(GetConfig("Title")), tostring(Hub:GetGame())),
        SubTitle = tostring(GetConfig("SubTitle")),
        Icon = GetConfig("Icon"),
        DiscordInvite = GetConfig("DiscordInvite")
    }

    setmetatable(Base, {__index = Library})

    --// API
    Base.GetConfig = function(_, ...)
        return GetConfig(...)
    end

    Base.LoadRequire = function(_, ...)
        return Hub:LoadRequire(...)
    end

    Base.Translate = function(_, ...)
        return Hub:Translate(...)
    end

    Base.GetLanguage = function(_, ...)
        return Hub:GetLanguage(...)
    end

    Base.Print = function(_, ...)
        return Hub:Print(...)
    end

    Base.Log = Base.Print

    Base.Warn = function(_, ...)
        return Hub:Warn(...)
    end

    Base.ConsoleError = function(_, ...)
        return Hub:Error(...)
    end

    Base.Console = function(_, ...)
        return Hub:Console(...)
    end

    function Base:GetGame()
        return Hub:GetGame()
    end

    function Base:GenerateName(...)
        return Hub:GenerateName(...)
    end

    function Base:Genv()
        return Genv
    end

    function Base:MakeWindow(WindowConfig)
        WindowConfig = WindowConfig or {}

        local LibraryConfig = GetConfig("Library") or {}
        if WindowConfig.Keybind == nil and WindowConfig[3] == nil then
            WindowConfig.Keybind = LibraryConfig.Keybind
        end

        local Window = Library:MakeWindow(WindowConfig)
        Genv.State.Window = Window

        if type(Window) == "table" and type(Window.Destroy) == "function" then
            local DestroyWindow = Window.Destroy
            function Window:Destroy(...)
                if Genv.State.Window == self then
                    Genv.State.Window = nil
                end
                return DestroyWindow(self, ...)
            end
        end

        return Window
    end

    for Name, Value in pairs(Notification) do
        if type(Value) == "function" and Name ~= "Destroy" and Base[Name] == nil then
            local Method = Value
            Base[Name] = function(...)
                if ... == Base then
                    return Method(Notification, select(2, ...))
                end
                return Method(Notification, ...)
            end
        end
    end

    --// Cleanup
    function Base:Destroy()
        if type(Notification.Destroy) == "function" then
            pcall(Notification.Destroy, Notification)
        end

        if type(Library.Destroy) == "function" then
            pcall(Library.Destroy, Library)
        end

        if Genv.State.Base == self then
            Genv.State.Base = nil
        end

        Genv.State.Window = nil
    end

    return Base
end

--// Start
local Success, Result = xpcall(Build, function(Error)
    if debug and type(debug.traceback) == "function" then
        return debug.traceback(tostring(Error), 2)
    end
    return tostring(Error)
end)

Genv.State.Loading = false

if not Success then
    Hub:Error("Console.BuildFailed", {Error = Result}, 0)
end

Genv.State.Base = Result
return Result
