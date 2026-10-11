--// Services

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

--// Context

local InjectedConfig, InjectedBaseUrl = ...

--// Variables

local Lower = string.lower
local Regions = setmetatable({}, {__mode = "k"})
local ScriptEnvironment = getfenv()
local RuntimeTitle = tostring(type(InjectedConfig) == "table" and InjectedConfig.Title or "Hub")
local TranslateLoaded = function(Text)
    return Text
end

local RNG = Random.new()
local Chars = table.create(62)

for Char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"):gmatch(".") do
    Chars[#Chars + 1] = string.byte(Char)
end

--// Functions

local function BuildBaseUrl(Config)
    if type(Config) ~= "table" or type(Config.Repository) ~= "table" then
        return nil
    end

    local Repository = Config.Repository
    local Author = Repository.Author
    local Name = Repository.RepositoryName
    local Branch = Repository.Branch

    if Author == nil or Name == nil or Branch == nil then
        return nil
    end

    return ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/"):format(
        tostring(Author),
        tostring(Name),
        tostring(Branch)
    )
end

local BASE_URL = type(InjectedBaseUrl) == "string" and InjectedBaseUrl or BuildBaseUrl(InjectedConfig)
assert(BASE_URL, "Repository configuration is required.")

local function LoadRequire(Url, Base, Retries, ...)
    Retries = Retries or 3

    local Arguments = table.pack(...)
    local LastError

    for Attempt = 1, Retries do
        local Success, Result = pcall(function()
            local Source = game:HttpGet((Base or BASE_URL) .. Url)
            local Chunk = assert(loadstring(Source))
            return Chunk(table.unpack(Arguments, 1, Arguments.n))
        end)

        if Success then
            return Result
        end

        LastError = Result

        if Attempt < Retries then
            task.wait(0.5 * Attempt)
        end
    end

    warn(("[%s] %s"):format(RuntimeTitle, TranslateLoaded("Failed to load {Path}: {Error}", {
        Path = Url,
        Error = tostring(LastError)
    })))
end

local function BuildLookup(Table)
    local Lookup = {}

    if type(Table) == "table" then
        for Key, Value in pairs(Table) do
            Lookup[Lower(tostring(Key))] = Value
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

local function Format(Text, Values)
    if type(Text) ~= "string" or type(Values) ~= "table" then
        return Text
    end

    return (Text:gsub("{([%w_]+)}", function(Key)
        local Value = Values[Key]
        return Value == nil and ("{" .. Key .. "}") or tostring(Value)
    end))
end

local function NormalizePath(Path)
    Path = tostring(Path or ""):gsub("\\", "/")
    Path = Path:gsub("^/+", ""):gsub("/+$", "")
    return Path
end

local function GetGlobal(Name)
    local Value = ScriptEnvironment[Name]
    if Value ~= nil then
        return Value
    end

    local GetGenv = ScriptEnvironment.getgenv
    if type(GetGenv) == "function" then
        local Success, Environment = pcall(GetGenv)
        if Success and type(Environment) == "table" then
            return Environment[Name]
        end
    end

    return nil
end

local function GetWorkspaceRoot()
    local Title = tostring(type(InjectedConfig) == "table" and InjectedConfig.Title or "Hub")
    Title = Title:gsub('[<>:"/\\|?*%c]', "_")
    Title = Title:gsub("^%s+", ""):gsub("%s+$", "")
    return Title ~= "" and Title or "Hub"
end

local function NormalizeWorkspacePath(Path)
    local Parts = {}

    for Part in NormalizePath(Path):gmatch("[^/]+") do
        if Part == ".." then
            return nil
        elseif Part ~= "." and Part ~= "" then
            Parts[#Parts + 1] = Part
        end
    end

    return table.concat(Parts, "/")
end

local function ResolveWorkspacePath(Path)
    local Root = GetWorkspaceRoot()
    local Relative = NormalizeWorkspacePath(Path)

    if Relative == nil then
        return nil
    end

    if Relative == "" or Relative == Root then
        return Root
    end

    if Relative:sub(1, #Root + 1) == Root .. "/" then
        return Relative
    end

    return Root .. "/" .. Relative
end

local function EnsureFolder(Path)
    local MakeFolder = GetGlobal("makefolder")
    local IsFolder = GetGlobal("isfolder")

    if type(MakeFolder) ~= "function" then
        return false, "Filesystem folder API is unavailable."
    end

    local Resolved = ResolveWorkspacePath(Path)
    if not Resolved then
        return false, "Invalid workspace path."
    end

    local Current = ""

    for Part in Resolved:gmatch("[^/]+") do
        Current = Current == "" and Part or (Current .. "/" .. Part)

        local Exists = false
        if type(IsFolder) == "function" then
            local Success, Result = pcall(IsFolder, Current)
            Exists = Success and Result == true
        end

        if not Exists then
            local Success, Error = pcall(MakeFolder, Current)
            if not Success and type(IsFolder) == "function" then
                local CheckSuccess, Result = pcall(IsFolder, Current)
                if CheckSuccess and Result == true then
                    Success = true
                end
            end

            if not Success then
                return false, Error
            end
        end
    end

    return true, Resolved
end

--// Require

local Configs = BuildLookup(InjectedConfig)
local Games = LoadRequire("Games/games.lua")
Games = type(Games) == "table" and Games or {}

local Translation = LoadRequire(
    "Core/Modules/Hub/Translation/script.lua",
    nil,
    nil,
    BASE_URL,
    Games
)

if type(Translation) ~= "table" then
    Translation = {
        Translate = function(_, Text)
            return Text
        end
    }
end

TranslateLoaded = function(Text, Values)
    local LanguageConfig = type(InjectedConfig) == "table" and InjectedConfig.Language or nil
    local Language = type(LanguageConfig) == "table" and tostring(LanguageConfig.Default or "US") or "US"
    return Format(Translation:Translate(Text, Language), Values)
end

local function ResolveConfig(Value, Language, Key)
    local ValueType = type(Value)

    if ValueType == "string" then
        return Translation:Translate(Value, Language)
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

--// Main Module

local Main = {}

--// Require

function Main:LoadRequire(Url, Base, Retries, ...)
    return LoadRequire(Url, Base, Retries, ...)
end

function Main:GetGamePath(Path, GameName)
    GameName = GameName or self:GetGame()

    if GameName == "Universal" then
        return nil
    end

    Path = NormalizePath(Path)

    if Path == "" then
        return "Games/" .. GameName
    end

    return "Games/" .. GameName .. "/" .. Path
end

function Main:LoadGameRequire(Path, Retries, ...)
    local GamePath = self:GetGamePath(Path)

    if not GamePath then
        return nil
    end

    return LoadRequire(GamePath, nil, Retries, ...)
end

--// Config

function Main:GetConfig(Name)
    return ResolveConfig(Configs[Lower(tostring(Name))], self:GetLanguage())
end

function Main:GetGenv()
    local GetGenv = GetGlobal("getgenv")
    local Env = ScriptEnvironment

    if type(GetGenv) == "function" then
        local Success, Result = pcall(GetGenv)
        if Success and type(Result) == "table" then
            Env = Result
        end
    end

    local Title = tostring(Configs.title or "Hub")
    Env[Title] = Env[Title] or {}
    return Env[Title]
end

--// Runtime

local function GetRuntime(Self)
    local Genv = Self:GetGenv()
    Genv.Runtime = Genv.Runtime or {}
    return Genv.Runtime
end

local function ResolveLanguage(Config, Value)
    if type(Config) ~= "table" then
        return nil
    end

    local Names = type(Config.Names) == "table" and Config.Names or {}
    local Target = Lower(tostring(Value or ""))

    for Code, Name in pairs(Names) do
        if Lower(tostring(Code)) == Target or Lower(tostring(Name)) == Target then
            return tostring(Code):upper()
        end
    end

    local Countries = type(Config.Countries) == "table" and Config.Countries or {}
    for _, Code in pairs(Countries) do
        if Lower(tostring(Code)) == Target then
            return tostring(Code):upper()
        end
    end

    local Default = tostring(Config.Default or "US"):upper()
    if Lower(Default) == Target then
        return Default
    end

    return nil
end

function Main:GetLanguage()
    local Runtime = GetRuntime(self)
    if type(Runtime.Language) == "string" then
        return Runtime.Language
    end

    local LanguageConfig = type(Configs.language) == "table" and Configs.language or {}
    local Language

    if LanguageConfig.AutoDetect ~= false then
        local Region = self:GetPlayerRegion()
        local Countries = type(LanguageConfig.Countries) == "table" and LanguageConfig.Countries or {}
        Language = Region and Countries[Region]
    end

    Language = ResolveLanguage(LanguageConfig, Language or LanguageConfig.Default) or "US"
    Runtime.Language = Language
    return Language
end

function Main:SetLanguage(Language)
    local LanguageConfig = type(Configs.language) == "table" and Configs.language or {}
    local Resolved = ResolveLanguage(LanguageConfig, Language)

    if not Resolved then
        return false, self:Translate("Unsupported language.")
    end

    local Runtime = GetRuntime(self)
    if Runtime.Language == Resolved then
        return true, Resolved
    end

    Runtime.Language = Resolved

    if typeof(Runtime.LanguageChanged) == "Instance" then
        Runtime.LanguageChanged:Fire(Resolved)
    end

    return true, Resolved
end

function Main:GetLanguages()
    local LanguageConfig = type(Configs.language) == "table" and Configs.language or {}
    local Names = type(LanguageConfig.Names) == "table" and LanguageConfig.Names or {}
    local Result = {}

    for Code, Name in pairs(Names) do
        Result[tostring(Code):upper()] = tostring(Name)
    end

    return Result
end

function Main:OnLanguageChanged(Callback)
    if type(Callback) ~= "function" then
        return nil
    end

    local Runtime = GetRuntime(self)
    if typeof(Runtime.LanguageChanged) ~= "Instance" then
        Runtime.LanguageChanged = Instance.new("BindableEvent")
        Runtime.LanguageChanged.Name = self:GenerateName(12)
    end

    return Runtime.LanguageChanged.Event:Connect(Callback)
end

function Main:GetThemes()
    local Themes = type(Configs.themes) == "table" and Configs.themes or {}
    return Themes
end

function Main:GetTheme()
    local Runtime = GetRuntime(self)
    local Themes = self:GetThemes()

    if type(Runtime.Theme) == "string" and type(Themes[Runtime.Theme]) == "table" then
        return Runtime.Theme
    end

    local Default = tostring(Configs.theme or "MetalRed")
    Runtime.Theme = type(Themes[Default]) == "table" and Default or next(Themes)
    return Runtime.Theme
end

function Main:GetThemeData(Name)
    local Themes = self:GetThemes()
    return Themes[Name or self:GetTheme()]
end

function Main:SetTheme(Name)
    local Themes = self:GetThemes()
    if type(Name) ~= "string" or type(Themes[Name]) ~= "table" then
        return false, self:Translate("Unsupported theme.")
    end

    local Runtime = GetRuntime(self)
    if Runtime.Theme == Name then
        return true, Name
    end

    Runtime.Theme = Name

    if typeof(Runtime.ThemeChanged) == "Instance" then
        Runtime.ThemeChanged:Fire(Name, Themes[Name])
    end

    return true, Name
end

function Main:OnThemeChanged(Callback)
    if type(Callback) ~= "function" then
        return nil
    end

    local Runtime = GetRuntime(self)
    if typeof(Runtime.ThemeChanged) ~= "Instance" then
        Runtime.ThemeChanged = Instance.new("BindableEvent")
        Runtime.ThemeChanged.Name = self:GenerateName(12)
    end

    return Runtime.ThemeChanged.Event:Connect(Callback)
end

--// Filesystem

function Main:GetWorkspacePath(Path)
    return ResolveWorkspacePath(Path)
end

function Main:CreateFolder(Path)
    local Success, Result = EnsureFolder(Path)
    if not Success and type(Result) == "string" then
        Result = self:Translate(Result)
    end
    return Success, Result
end

function Main:FolderExists(Path)
    local IsFolder = GetGlobal("isfolder")
    local Resolved = ResolveWorkspacePath(Path)

    if type(IsFolder) ~= "function" or not Resolved then
        return false
    end

    local Success, Result = pcall(IsFolder, Resolved)
    return Success and Result == true
end

function Main:FileExists(Path)
    local IsFile = GetGlobal("isfile")
    local Resolved = ResolveWorkspacePath(Path)

    if type(IsFile) ~= "function" or not Resolved then
        return false
    end

    local Success, Result = pcall(IsFile, Resolved)
    return Success and Result == true
end

function Main:CreateFile(Path, Content)
    local WriteFile = GetGlobal("writefile")
    local Relative = NormalizeWorkspacePath(Path)

    if type(WriteFile) ~= "function" then
        return false, self:Translate("Filesystem write API is unavailable.")
    end

    if Relative == nil or Relative == "" then
        return false, self:Translate("Invalid file path.")
    end

    local Parent = Relative:match("^(.*)/[^/]+$")
    local Success, Error = EnsureFolder(Parent or "")
    if not Success then
        return false, type(Error) == "string" and self:Translate(Error) or Error
    end

    local Resolved = ResolveWorkspacePath(Relative)
    local WriteSuccess, WriteError = pcall(WriteFile, Resolved, tostring(Content or ""))

    if not WriteSuccess then
        return false, WriteError
    end

    return true, Resolved
end

function Main:WriteFile(Path, Content)
    return self:CreateFile(Path, Content)
end

function Main:ReadFile(Path)
    local ReadFile = GetGlobal("readfile")
    local Resolved = ResolveWorkspacePath(Path)

    if not Resolved then
        return nil, self:Translate("Invalid workspace path.")
    end

    if type(ReadFile) ~= "function" then
        return nil, self:Translate("Filesystem read API is unavailable.")
    end

    local Success, Content = pcall(ReadFile, Resolved)
    if not Success then
        return nil, Content
    end

    return Content, Resolved
end

function Main:DeleteFile(Path)
    local DeleteFile = GetGlobal("delfile")
    local Resolved = ResolveWorkspacePath(Path)

    if not Resolved then
        return false, self:Translate("Invalid workspace path.")
    end

    if type(DeleteFile) ~= "function" then
        return false, self:Translate("Filesystem delete API is unavailable.")
    end

    if not self:FileExists(Path) then
        return true, Resolved
    end

    local Success, Error = pcall(DeleteFile, Resolved)
    if not Success then
        return false, Error
    end

    return true, Resolved
end

--// Game

function Main:GetGames()
    return Games
end

function Main:GetGame(PlaceId, GameId)
    PlaceId = tonumber(PlaceId) or game.PlaceId
    GameId = tonumber(GameId) or game.GameId

    return Games[PlaceId] or Games[GameId] or "Universal"
end

function Main:IsGame(Name)
    return Lower(self:GetGame()) == Lower(tostring(Name))
end

--// Utility

function Main:Format(Text, Values)
    return Format(Text, Values)
end

function Main:GenerateName(Len: number?): string
    local Size = math.clamp(math.floor(tonumber(Len) or 12), 1, 256)
    local Buf = buffer.create(Size)

    for Index = 0, Size - 1 do
        buffer.writeu8(Buf, Index, Chars[RNG:NextInteger(1, #Chars)])
    end

    return buffer.tostring(Buf)
end

function Main:SetClipboard(Text)
    local Clipboard = GetGlobal("setclipboard") or GetGlobal("toclipboard")

    if type(Clipboard) ~= "function" then
        return false, self:Translate("Clipboard API is unavailable.")
    end

    local Success, Error = pcall(Clipboard, tostring(Text or ""))
    return Success, Success and nil or Error
end

function Main:Compile(Source, ChunkName)
    local Compiler = GetGlobal("loadstring") or ScriptEnvironment.loadstring

    if type(Compiler) ~= "function" then
        return nil, self:Translate("Code execution API is unavailable.")
    end

    Source = tostring(Source or "")
    ChunkName = type(ChunkName) == "string" and ChunkName or "HubCode"

    local Success, Chunk, CompileError = pcall(Compiler, Source, ChunkName)
    if not Success then
        Success, Chunk, CompileError = pcall(Compiler, Source)
    end

    if not Success then
        return nil, Chunk
    end

    if type(Chunk) ~= "function" then
        return nil, CompileError or self:Translate("Failed to compile code.")
    end

    return Chunk
end

function Main:Execute(Source, ChunkName)
    local Chunk, CompileError = self:Compile(Source, ChunkName)
    if not Chunk then
        return false, CompileError
    end

    local Results = table.pack(pcall(Chunk))
    if not Results[1] then
        return false, Results[2]
    end

    return true, table.unpack(Results, 2, Results.n)
end

--// Translation

function Main:GetPlayerRegion(Plr)
    Plr = Plr or Players.LocalPlayer

    if not Plr then
        self:Warn("No player found.")
        return nil
    end

    local Cached = Regions[Plr]
    if Cached then
        return Cached
    end

    local Success, Region = pcall(
        LocalizationService.GetCountryRegionForPlayerAsync,
        LocalizationService,
        Plr
    )

    if not Success or type(Region) ~= "string" then
        return nil
    end

    Regions[Plr] = Region
    return Region
end

function Main:Translate(Text, Language)
    return Translation:Translate(Text, Language or self:GetLanguage())
end

function Main:RegisterTranslations(Dictionaries)
    if type(Translation.AddDictionary) ~= "function" then
        return false
    end

    return Translation:AddDictionary(Dictionaries)
end

--// Console

function Main:Console(Level, Message, Values)
    local Text = self:Format(self:Translate(tostring(Message or "")), Values)
    local Output = ("[%s] %s"):format(tostring(Configs.title or "Hub"), Text)
    local Mode = Lower(tostring(Level or "print"))

    if Mode == "warn" or Mode == "warning" then
        warn(Output)
    elseif Mode == "error" then
        error(Output, 0)
    else
        print(Output)
    end

    return Text
end

function Main:Print(Message, Values)
    return self:Console("print", Message, Values)
end

function Main:Warn(Message, Values)
    return self:Console("warn", Message, Values)
end

function Main:ConsoleError(Message, Values)
    return self:Console("error", Message, Values)
end

--// Return

return Main
