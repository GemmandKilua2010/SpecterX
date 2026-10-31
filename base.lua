--// Services

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ScriptEnvironment = getfenv()

--// Bootstrap

local CONFIG_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/config.lua"
local ConfigData = assert(loadstring(game:HttpGet(CONFIG_URL .. "?sx=" .. HttpService:GenerateGUID(false))))()

--// Repository

local Repository = ConfigData.Repository or {}
local RepositoryAuthor = tostring(assert(Repository.Author, "Repository.Author is required."))
local RepositoryName = tostring(assert(Repository.RepositoryName, "Repository.RepositoryName is required."))
local RepositoryBranch = tostring(assert(Repository.Branch, "Repository.Branch is required."))
local BaseUrl = ("https://raw.githubusercontent.com/%s/%s/refs/heads/%s/"):format(
    RepositoryAuthor,
    RepositoryName,
    RepositoryBranch
)

--// Hub

local HubChunk = assert(loadstring(game:HttpGet(BaseUrl .. "Core/Modules/Hub/script.lua?sx=" .. HttpService:GenerateGUID(false))))
local Hub = HubChunk(ConfigData, BaseUrl)

--// Global

local Genv = Hub:GetGenv()
Genv.State = Genv.State or {}

if Genv.State.Loading then
    Hub:Warn("Script is already loading. Please wait until the current loading process is complete.")
    return Genv.State.Base
end

--// Preferences

local LibraryConfig = assert(type(ConfigData.Library) == "table" and ConfigData.Library, "Config.Library is required.")
local SettingsFolder = assert(type(LibraryConfig.SettingsFolder) == "string" and LibraryConfig.SettingsFolder ~= "" and LibraryConfig.SettingsFolder,
    "Config.Library.SettingsFolder must be a nonempty path.")
local SettingsFile = assert(type(LibraryConfig.SettingsFile) == "string" and LibraryConfig.SettingsFile ~= "" and LibraryConfig.SettingsFile,
    "Config.Library.SettingsFile must be a nonempty filename.")
local SettingsPath = SettingsFolder .. "/" .. SettingsFile
local SavedSettings

if Hub:FileExists(SettingsPath) then
    local Source = Hub:ReadFile(SettingsPath)
    if type(Source) == "string" then
        local Success, Saved = pcall(HttpService.JSONDecode, HttpService, Source)
        if Success and type(Saved) == "table" then
            SavedSettings = Saved
        end
    end
end

--// Whitelist

local WhitelistEntries = Hub:LoadRequire("Core/Modules/whitelist.lua")
local WhitelistManager
local WhitelistSession = Genv.State.WhitelistSession
if type(WhitelistSession) ~= "table" or WhitelistSession.JobId ~= game.JobId or WhitelistSession.PlaceId ~= game.PlaceId then
    WhitelistSession = {JobId = game.JobId, PlaceId = game.PlaceId}
end

if type(WhitelistEntries) == "table" then
    WhitelistManager = Hub:LoadRequire(
        "Core/Modules/Hub/Whitelist/script.lua",
        nil,
        nil,
        WhitelistEntries,
        WhitelistSession
    )
end

if type(WhitelistManager) ~= "table"
    or type(WhitelistManager.Whitelist) ~= "function"
    or type(WhitelistManager.AddWhitelist) ~= "function"
    or type(WhitelistManager.RemoveWhitelist) ~= "function"
    or type(WhitelistManager.ResetWhitelist) ~= "function"
    or type(WhitelistManager.AddGroup) ~= "function"
    or type(WhitelistManager.RemoveGroup) ~= "function"
    or type(WhitelistManager.ResetGroups) ~= "function"
    or type(WhitelistManager.WhitelistInfo) ~= "function"
    or type(WhitelistManager.Group) ~= "function"
    or type(WhitelistManager.Permission) ~= "function"
    or type(WhitelistManager.CanManage) ~= "function"
    or type(WhitelistManager.CanAccessAdminHub) ~= "function"
    or type(WhitelistManager.ObserveAccess) ~= "function" then
    if ConfigData.Whitelist == true then
        local Player = Players.LocalPlayer
        if Player then
            pcall(Player.Kick, Player, Hub:Translate("Whitelist verification is unavailable. Please try again later."))
        end
        return nil
    end
    error("Failed to load the whitelist module.", 0)
end

if ConfigData.Whitelist == true then
    local Success, Allowed = pcall(WhitelistManager.Whitelist, WhitelistManager, Players.LocalPlayer)
    if not Success or Allowed ~= true then
        local Player = Players.LocalPlayer
        if Player then
            local Message = Success and "You are not on the whitelist."
                or "Whitelist verification is unavailable. Please try again later."
            pcall(Player.Kick, Player, Hub:Translate(Message))
        end
        return nil
    end
end

Genv.State.WhitelistSession = WhitelistSession

local ActiveBase
local AccessRevoked = false

local function RevokeLocalAccess(Reason)
    if AccessRevoked then return end
    AccessRevoked = true

    local RunningBase = ActiveBase or Genv.State.Base
    if type(RunningBase) == "table" and type(RunningBase.Destroy) == "function" then
        local Success, Error = pcall(RunningBase.Destroy, RunningBase)
        if not Success then
            warn("[SpecterX] Failed to close the hub: " .. tostring(Error))
        end
    else
        local Window = Genv.State.Window
        if typeof(Window) == "Instance" then
            pcall(Window.Destroy, Window)
        end
    end

    local Player = Players.LocalPlayer
    if not Player then return end

    local Message = Reason == "revoked" and "Your SpecterX access was revoked."
        or "Your SpecterX access has expired."
    local Success, Error = pcall(Player.Kick, Player, Hub:Translate(Message))
    if not Success then
        warn("[SpecterX] Could not kick the local player: " .. tostring(Error))
    end
end

if ConfigData.Whitelist == true then
    WhitelistManager:ObserveAccess(RevokeLocalAccess)
end

local Addons = Hub:LoadRequire("Core/Modules/Hub/Addon/script.lua", nil, nil, Hub, ConfigData)
Addons = type(Addons) == "table" and Addons or {}

-- Load addon locale codes before resolving the saved language preference.
if type(SavedSettings) == "table" and type(SavedSettings.Language) == "string" then
    Hub:SetLanguage(SavedSettings.Language)
end

local ThemeReady, ThemeError = Hub:SetTheme(ConfigData.Theme)
assert(ThemeReady, ThemeError or "Config.Theme must name a configured theme.")

if type(SavedSettings) == "table" and type(SavedSettings.Theme) == "string" then
    Hub:SetTheme(SavedSettings.Theme)
end

--// State

local PreviousBase = Genv.State.Base
if type(PreviousBase) == "table" and type(PreviousBase.Destroy) == "function" then
    pcall(PreviousBase.Destroy, PreviousBase)
end

Genv.State.Loading = true

--// Require

local Load = function(...)
    return Hub:LoadRequire(...)
end

local Config = function(...)
    return Hub:GetConfig(...)
end

--// Loader

local UseLoader = ...
UseLoader = UseLoader == nil and Config("LoadingScreen") or UseLoader

local Loader

if UseLoader then
    Loader = Load("Core/Modules/Hub/Loader/script.lua")

    if type(Loader) == "table" and type(Loader.Run) == "function" then
        local Success = Loader:Run({
            Hub = Hub,
            Genv = Genv,
            Title = Config("Title"),
            SubTitle = Config("SubTitle"),
        }, Config("Loader"))

        if not Success then
            Loader = nil
        end
    else
        Loader = nil
    end
end

--// Assets

local Icons
local IconsLoaded = false
local IconsReady = Hub:CreateInstance("BindableEvent")

task.spawn(function()
    Icons = Load("Core/Library/Assets/icons.lua")
    IconsLoaded = true
    IconsReady:Fire()
end)

--// Modules

local Notify = Load("Core/Modules/Hub/Notification/script.lua", nil, nil, Hub, ConfigData)
if type(Notify) ~= "table" then
    Notify = {}
end

--// Library

local Lib = Load("Core/Library/lib.lua", nil, nil, Hub, ConfigData)

if not IconsLoaded then
    IconsReady.Event:Wait()
end

IconsReady:Destroy()

if type(Lib) == "table" and type(Lib.SetIcons) == "function" then
    Lib:SetIcons(type(Icons) == "table" and Icons or {})
end

if type(Lib) ~= "table" then
    if Loader and type(Loader.Destroy) == "function" then
        Loader:Destroy()
    end

    if type(Notify.Destroy) == "function" then
        pcall(Notify.Destroy, Notify)
    end

    Genv.State.Loading = false
    Hub:ConsoleError("Critical failure: Library could not be loaded. Aborting.")
end

--// Config

local Title = tostring(Config("Title") or "Hub")
local Image = Config("Image")

local Icon = Config("Icon") or {}
if Icon.Image == nil then
    Icon.Image = Image
end

local DiscordInvite = Config("DiscordInvite") or {}
if DiscordInvite.Name == nil then
    DiscordInvite.Name = Title
end
if DiscordInvite.Image == nil then
    DiscordInvite.Image = Image
end
if DiscordInvite.Desc then
    DiscordInvite.Desc = Hub:Format(DiscordInvite.Desc, {
        Title = Title,
    })
end

--// Base

local Base = {
    Library = Lib,
    Addons = Addons,

    Title = ("%s | %s"):format(Title, tostring(Hub:GetGame())),
    SubTitle = tostring(Config("SubTitle") or ""),

    Icon = Icon,
    DiscordInvite = DiscordInvite,
}

setmetatable(Base, {__index = Lib})
ActiveBase = Base

local Destroyed = false
local PublishedGlobals = {}
local OwnedRuntime = Genv.Runtime
local OwnedLibraryRuntime = type(OwnedRuntime) == "table" and OwnedRuntime.Library
local OwnedNotificationRuntime = type(OwnedRuntime) == "table" and OwnedRuntime.Notification
local OwnedEvents = {}
if type(OwnedRuntime) == "table" then
    OwnedEvents.ThemeChanged = OwnedRuntime.ThemeChanged
    OwnedEvents.LanguageChanged = OwnedRuntime.LanguageChanged
end

local function Cleanup()
    if Destroyed then return end
    Destroyed = true

    for _, Entry in ipairs(PublishedGlobals) do
        for Index, Environment in ipairs(Entry.Environments) do
            pcall(function()
                if Environment[Entry.Name] == Entry.Wrapper then
                    Environment[Entry.Name] = Entry.Previous[Index]
                end
            end)
        end
    end
    table.clear(PublishedGlobals)

    WhitelistManager:Destroy()

    if type(Notify.Destroy) == "function" then
        pcall(Notify.Destroy, Notify)
    end

    if Loader and type(Loader.Destroy) == "function" then
        pcall(Loader.Destroy, Loader)
        if type(Genv.Loading) == "table" and Genv.Loading.Running ~= true then
            Genv.Loading = nil
        end
    end

    local Runtime = Genv.Runtime
    if type(Runtime) == "table" and Runtime == OwnedRuntime then
        local GuiContainer = type(OwnedLibraryRuntime) == "table" and OwnedLibraryRuntime.GuiContainer

        if Runtime.Library == OwnedLibraryRuntime then
            Runtime.Library = nil
        end
        if Runtime.Notification == OwnedNotificationRuntime then
            Runtime.Notification = nil
        end

        for _, Name in ipairs({"ThemeChanged", "LanguageChanged"}) do
            local Event = OwnedEvents[Name]
            if typeof(Event) == "Instance" and Runtime[Name] == Event then
                pcall(Event.Destroy, Event)
                Runtime[Name] = nil
            end
        end

        if typeof(GuiContainer) == "Instance" and GuiContainer:IsA("Folder") then
            task.defer(function()
                if GuiContainer.Parent and #GuiContainer:GetChildren() == 0 then
                    pcall(GuiContainer.Destroy, GuiContainer)
                end
            end)
        end
    end

    if Genv.State.Base == Base then
        Genv.State.Base = nil
    end
    if Genv.State.Window == Lib.Window then
        Genv.State.Window = nil
    end
end

function Base:Destroy()
    Cleanup()
    if typeof(Lib.Window) == "Instance" and Lib.Window.Parent then
        pcall(Lib.Window.Destroy, Lib.Window)
    end
end

Lib._BeforeClose = Cleanup
if typeof(Lib.Window) == "Instance" then
    Lib.Window.Destroying:Connect(Cleanup)
end

--// Window

if Genv.State.Window then
    Genv.State.Window:Destroy()
    Genv.State.Window = nil
end

Genv.State.Window = Lib.Window

--// API

Base.Whitelist = function(_, ...)
    return WhitelistManager:Whitelist(...)
end

Base.AddWhitelist = function(_, ...)
    return WhitelistManager:AddWhitelist(...)
end

Base.RemoveWhitelist = function(_, ...)
    local Success, Error = WhitelistManager:RemoveWhitelist(...)
    if Success and ConfigData.Whitelist == true and not WhitelistManager:Whitelist(Players.LocalPlayer) then
        RevokeLocalAccess("revoked")
    end
    return Success, Error
end

Base.Group = function(_, ...)
    return WhitelistManager:Group(...)
end

Base.AddGroup = function(_, ...)
    return WhitelistManager:AddGroup(...)
end

Base.RemoveGroup = function(_, ...)
    return WhitelistManager:RemoveGroup(...)
end

Base.ResetGroups = function(_, ...)
    return WhitelistManager:ResetGroups(...)
end

Base.ResetWhitelist = function(_, ...)
    return WhitelistManager:ResetWhitelist(...)
end

Base.WhitelistInfo = function(_, ...)
    return WhitelistManager:WhitelistInfo(...)
end

Base.Permission = function(_, ...)
    return WhitelistManager:Permission(...)
end

Base.CanManage = function(_, ...)
    return WhitelistManager:CanManage(...)
end

Base.CanAccessAdminHub = function(_)
    return WhitelistManager:CanAccessAdminHub()
end

Base.GetConfig = function(_, ...)
    return Config(...)
end

Base.LoadRequire = function(_, ...)
    return Load(...)
end

Base.LoadGameRequire = function(_, ...)
    return Hub:LoadGameRequire(...)
end

Base.GetGames = function(_)
    return Hub:GetGames()
end

Base.GetGame = function(_, ...)
    return Hub:GetGame(...)
end

Base.GetGameInfo = function(_, ...)
    return Hub:GetGameInfo(...)
end

Base.IsGame = function(_, ...)
    return Hub:IsGame(...)
end

Base.GetGamePath = function(_, ...)
    return Hub:GetGamePath(...)
end

Base.Format = function(_, ...)
    return Hub:Format(...)
end

Base.Translate = function(_, ...)
    return Hub:Translate(...)
end

Base.Console = function(_, ...)
    return Hub:Console(...)
end

Base.Print = function(_, ...)
    return Hub:Print(...)
end

Base.Warn = function(_, ...)
    return Hub:Warn(...)
end

Base.ConsoleError = function(_, ...)
    return Hub:ConsoleError(...)
end

Base.GetLanguage = function(_)
    return Hub:GetLanguage()
end

Base.GetLanguages = function(_)
    return Hub:GetLanguages()
end

Base.SetLanguage = function(_, ...)
    return Lib:SetLanguage(...)
end

Base.GetThemes = function(_)
    return Lib:GetThemes()
end

Base.GetTheme = function(_)
    return Lib:GetTheme()
end

Base.SetTheme = function(_, ...)
    return Lib:SetTheme(...)
end

Base.GetWorkspacePath = function(_, ...)
    return Hub:GetWorkspacePath(...)
end

Base.CreateFolder = function(_, ...)
    return Hub:CreateFolder(...)
end

Base.CreateFile = function(_, ...)
    return Hub:CreateFile(...)
end

Base.WriteFile = function(_, ...)
    return Hub:WriteFile(...)
end

Base.ReadFile = function(_, ...)
    return Hub:ReadFile(...)
end

Base.FileExists = function(_, ...)
    return Hub:FileExists(...)
end

Base.FolderExists = function(_, ...)
    return Hub:FolderExists(...)
end

Base.DeleteFile = function(_, ...)
    return Hub:DeleteFile(...)
end

local function ResolveDataPath(Path)
    if type(Path) ~= "string" or Path:gsub("%s", "") == "" then
        return nil, "Invalid data path."
    end

    local GameName = Hub:GetGame()
    if type(GameName) ~= "string" or GameName == "" then
        GameName = "Universal"
    end

    local GamePath = Hub:GetGamePath(Path, GameName)
    if not GamePath then
        return nil, "Invalid data path."
    end

    return Hub:GetWorkspacePath(GamePath)
end

Base.GetDataPath = function(_, Path)
    return ResolveDataPath(Path)
end

Base.Save = function(_, Path, Value)
    local DataPath, PathError = ResolveDataPath(Path)
    if not DataPath then
        return false, PathError
    end

    local Content
    if type(Value) == "string" then
        Content = Value
    else
        local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Value)
        if not Success then
            return false, Encoded
        end
        Content = Encoded
    end

    return Hub:CreateFile(DataPath, Content)
end

Base.Load = function(_, Path)
    local DataPath, PathError = ResolveDataPath(Path)
    if not DataPath then
        return nil, PathError
    end

    local Content, ReadError = Hub:ReadFile(DataPath)
    if type(Content) ~= "string" then
        return nil, ReadError
    end

    local Success, Value = pcall(HttpService.JSONDecode, HttpService, Content)
    if Success then
        return Value, DataPath
    end

    -- Keep compatibility with files written as raw text using Save.
    return Content, DataPath
end

local function ParseDataSelector(Selector)
    if type(Selector) ~= "string" or Selector == "" then
        return {}
    end

    local Parts = {}
    local Position = 1
    while Position <= #Selector do
        local Character = Selector:sub(Position, Position)
        if Character == "." then
            Position += 1
        elseif Character == "[" then
            local Remaining = Selector:sub(Position)
            local NumberBracket = Remaining:match("^(%[%d+%])")
            if NumberBracket then
                Parts[#Parts + 1] = tonumber(NumberBracket:sub(2, -2))
                Position += #NumberBracket
            else
                local StringBracket = Remaining:match('^(%[%s*".-"%s*%])')
                    or Remaining:match("^(%[%s*'.-'%s*%])")
                if not StringBracket then
                    return nil, "Invalid data selector near: " .. Selector:sub(Position)
                end
                local Key = StringBracket:match('^%[%s*"(.-)"%s*%]')
                    or StringBracket:match("^%[%s*'(.-)'%s*%]")
                Parts[#Parts + 1] = Key
                Position += #StringBracket
            end
        else
            local Name = Selector:sub(Position):match("^([%a_][%w_]*)")
            if not Name then
                return nil, "Invalid data selector near: " .. Selector:sub(Position)
            end
            Parts[#Parts + 1] = Name
            Position += #Name
        end
    end

    return Parts
end

Base.Get = function(_, Path, Selector)
    local Value, DataPathOrError = Base.Load(Base, Path)
    if Value == nil then
        return nil, DataPathOrError
    end

    if Selector == nil or Selector == "" then
        return Value, DataPathOrError
    end

    local Parts, SelectorError = ParseDataSelector(Selector)
    if not Parts then
        return nil, SelectorError
    end

    for _, Key in ipairs(Parts) do
        if type(Value) ~= "table" then
            return nil, "Data selector does not match a table at: " .. tostring(Key)
        end
        Value = Value[Key]
        if Value == nil then
            return nil, "Data value not found at: " .. tostring(Key)
        end
    end

    return Value, DataPathOrError
end

Base.Exists = function(_, Path)
    local DataPath = ResolveDataPath(Path)
    return DataPath ~= nil and Hub:FileExists(DataPath) or false
end

Base.Del = function(_, Path)
    local DataPath, PathError = ResolveDataPath(Path)
    if not DataPath then
        return false, PathError
    end

    return Hub:DeleteFile(DataPath)
end

Base.Delete = Base.Del

Base.SetClipboard = function(_, ...)
    return Hub:SetClipboard(...)
end

Base.Compile = function(_, ...)
    return Hub:Compile(...)
end

Base.Execute = function(_, ...)
    return Hub:Execute(...)
end

function Base:GenerateName(...)
    return Hub:GenerateName(...)
end

function Base:Genv()
    return Genv
end

for Name, Value in pairs(Notify) do
    if type(Value) == "function" and Name ~= "Destroy" and Base[Name] == nil then
        local Method = Value

        Base[Name] = function(...)
            if ... == Base then
                return Method(Notify, select(2, ...))
            end

            return Method(Notify, ...)
        end
    end
end

--// Version tracking

local VersionConfig = type(ConfigData.Version) == "table" and ConfigData.Version or {}
local CurrentVersion = tostring(VersionConfig.Current or "unknown")
local RunningVersion = tostring(Lib.Info and Lib.Info.Version or "unknown")
local VersionInfo = {
    Version = RunningVersion,
    LatestVersion = CurrentVersion,
    Branch = RepositoryBranch,
    Status = "NotChecked",
    CheckedAt = nil,
    Outdated = false,
    NotifiedOutdated = false
}
Base.VersionInfo = VersionInfo

function Base:GetVersionInfo()
    return table.clone(VersionInfo)
end

local VersionCheckGeneration = (tonumber(Genv.State.VersionCheckGeneration) or 0) + 1
Genv.State.VersionCheckGeneration = VersionCheckGeneration
Genv.State.VersionInfo = VersionInfo

local function NotifyOutdatedVersion()
    if Destroyed or Genv.State.VersionCheckGeneration ~= VersionCheckGeneration then
        return
    end

    local Title = Hub:Translate("SpecterX outdated")
    local Description = Hub:Format(Hub:Translate(
        "SpecterX is outdated. Running version: {RunningVersion}; latest version: {LatestVersion}. Execute the hub again to update."
    ), {
        RunningVersion = RunningVersion,
        LatestVersion = CurrentVersion
    })
    if type(Notify.Notify) == "function" then
        pcall(Notify.Notify, {
            Title = Title,
            Text = Description,
            Type = "Warning"
        })
    else
        Hub:Print(Description)
    end
end

local function ParseSemanticVersion(Value)
    local Major, Minor, Patch = tostring(Value):match("^v?(%d+)%.(%d+)%.(%d+)$")
    if not Major then return nil end
    return {tonumber(Major), tonumber(Minor), tonumber(Patch)}
end

local function IsOutdated(Running, Latest)
    local RunningParts = ParseSemanticVersion(Running)
    local LatestParts = ParseSemanticVersion(Latest)
    if not RunningParts or not LatestParts then
        return Running ~= Latest
    end

    for Index = 1, 3 do
        if RunningParts[Index] ~= LatestParts[Index] then
            return RunningParts[Index] < LatestParts[Index]
        end
    end
    return false
end

local function CheckForUpdates()
    if VersionConfig.WarnWhenOutdated == false then
        VersionInfo.Status = "Disabled"
        VersionInfo.CheckedAt = os.time()
        return true
    end

    VersionInfo.CheckedAt = os.time()
    VersionInfo.Outdated = IsOutdated(RunningVersion, CurrentVersion)
    VersionInfo.Status = VersionInfo.Outdated and "Outdated" or "Current"

    if VersionInfo.Outdated and not VersionInfo.NotifiedOutdated then
        VersionInfo.NotifiedOutdated = true
        NotifyOutdatedVersion()
    end

    return true
end

function Base:CheckForUpdates(Force)
    return CheckForUpdates(Force == true)
end

--// Global developer API

local GlobalEnvironments = {ScriptEnvironment}
local GetGlobalEnvironment = ScriptEnvironment.getgenv
if type(GetGlobalEnvironment) == "function" then
    local Success, Environment = pcall(GetGlobalEnvironment)
    if Success and type(Environment) == "table" and Environment ~= ScriptEnvironment then
        GlobalEnvironments[#GlobalEnvironments + 1] = Environment
    end
end

for Name, Method in pairs(Base) do
    if type(Method) == "function" then
        local BoundMethod = Method
        local Wrapper = function(...)
            if ... == Base then
                return BoundMethod(Base, select(2, ...))
            end
            return BoundMethod(Base, ...)
        end

        local Previous = {}
        for Index, Environment in ipairs(GlobalEnvironments) do
            local Success, Value = pcall(function()
                return Environment[Name]
            end)
            if Success then
                Previous[Index] = Value
            end
        end
        local Entry = {
            Name = Name,
            Wrapper = Wrapper,
            Previous = Previous,
            Environments = GlobalEnvironments,
        }

        for _, Environment in ipairs(GlobalEnvironments) do
            pcall(function()
                Environment[Name] = Wrapper
            end)
        end

        PublishedGlobals[#PublishedGlobals + 1] = Entry
    end
end

--// Finish

Genv.State.Base = Base

local GameInfo = Hub:GetGameInfo()
local GameScript = GameInfo and GameInfo.Loadstring

if type(GameScript) == "string" and GameScript:match("%S") and GameScript:lower() ~= "none" then
    Load(GameScript, nil, nil, Base)
end

if Loader then
    Loader:Finish()
    Loader:Wait()
end

Genv.State.Loading = false

if VersionConfig.WarnWhenOutdated ~= false then
    CheckForUpdates(false)
end

--// Return

return Base
