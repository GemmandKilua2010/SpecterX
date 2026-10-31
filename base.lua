--// Services

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

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
            if type(Saved.Language) == "string" then
                Hub:SetLanguage(Saved.Language)
            end
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
local CurrentVersion = tostring(VersionConfig.Current or (Lib.Info and Lib.Info.Version) or "unknown")
local VersionStatePath = type(VersionConfig.StateFile) == "string" and VersionConfig.StateFile ~= ""
    and VersionConfig.StateFile or "Version/last-seen.json"
local VersionInfo = {
    Version = CurrentVersion,
    Branch = RepositoryBranch,
    Status = "NotChecked",
    CurrentCommit = nil,
    PreviousCommit = nil,
    CommitMessage = nil,
    CheckedAt = nil,
    PersistenceAvailable = nil
}
Base.VersionInfo = VersionInfo

function Base:GetVersionInfo()
    return table.clone(VersionInfo)
end

local VersionCheckGeneration = (tonumber(Genv.State.VersionCheckGeneration) or 0) + 1
Genv.State.VersionCheckGeneration = VersionCheckGeneration
Genv.State.VersionInfo = VersionInfo
local VersionCheckRunning = false

local function ReadVersionRecord()
    local ReadSuccess, Source = pcall(Hub.ReadFile, Hub, VersionStatePath)
    if not ReadSuccess or type(Source) ~= "string" then
        return nil
    end

    local DecodeSuccess, Record = pcall(HttpService.JSONDecode, HttpService, Source)
    return DecodeSuccess and type(Record) == "table" and Record or nil
end

local function NotifyVersionStatus(Status, Description)
    if Destroyed or Genv.State.VersionCheckGeneration ~= VersionCheckGeneration then
        return
    end

    local Titles = {
        Changed = "SpecterX changes detected",
        Unchanged = "SpecterX is up to date",
        Baseline = "SpecterX version tracking started",
        Cached = "SpecterX version status",
        Unavailable = "SpecterX update check unavailable"
    }
    if type(Notify.Notify) == "function" then
        pcall(Notify.Notify, {
            Title = Titles[Status] or "SpecterX version",
            Text = Description,
            Type = Status == "Unavailable" and "Warning" or "Info"
        })
    else
        Hub:Print((Titles[Status] or "SpecterX version") .. ": " .. Description)
    end
end

local function CheckForUpdates(Force)
    if VersionCheckRunning then
        return false, "A version check is already running."
    end

    VersionCheckRunning = true
    VersionInfo.Status = "Checking"

    task.spawn(function()
        local Previous = ReadVersionRecord()
        local Now = os.time()
        local Interval = math.clamp(math.floor(tonumber(VersionConfig.CheckInterval) or 300), 60, 86400)
        local PreviousCheckedAt = type(Previous) == "table" and tonumber(Previous.CheckedAt) or nil
        local PreviousCommit = type(Previous) == "table" and Previous.Commit or nil
        local SameBranch = type(Previous) == "table" and Previous.Branch == RepositoryBranch
        local HasPreviousCommit = type(PreviousCommit) == "string"
            and #PreviousCommit >= 7 and PreviousCommit:match("^[%da-fA-F]+$") ~= nil

        if not Force and SameBranch and Previous.Version == CurrentVersion and HasPreviousCommit and PreviousCheckedAt
            and Now >= PreviousCheckedAt and Now - PreviousCheckedAt < Interval then
            VersionInfo.Status = "Cached"
            VersionInfo.CurrentCommit = PreviousCommit
            VersionInfo.PreviousCommit = PreviousCommit
            VersionInfo.CommitMessage = type(Previous.Message) == "string" and Previous.Message or nil
            VersionInfo.CheckedAt = PreviousCheckedAt
            VersionInfo.PersistenceAvailable = true
            VersionCheckRunning = false
            NotifyVersionStatus("Cached", ("Version %s | branch %s | commit %s (checked recently).")
                :format(CurrentVersion, RepositoryBranch, PreviousCommit:sub(1, 8)))
            return
        end

        local Owner = HttpService:UrlEncode(RepositoryAuthor)
        local Name = HttpService:UrlEncode(RepositoryName)
        local Branch = HttpService:UrlEncode(RepositoryBranch)
        local Url = ("https://api.github.com/repos/%s/%s/commits?sha=%s&per_page=1")
            :format(Owner, Name, Branch)
        local HttpSuccess, Body = pcall(game.HttpGet, game, Url)
        local LatestCommit

        if HttpSuccess and type(Body) == "string" then
            local DecodeSuccess, Commits = pcall(HttpService.JSONDecode, HttpService, Body)
            if DecodeSuccess and type(Commits) == "table" and type(Commits[1]) == "table" then
                LatestCommit = Commits[1]
            end
        end

        local Commit = type(LatestCommit) == "table" and LatestCommit.sha or nil
        local CommitData = type(LatestCommit) == "table" and LatestCommit.commit or nil
        if type(Commit) ~= "string" or #Commit < 7 or not Commit:match("^[%da-fA-F]+$") then
            VersionInfo.Status = "Unavailable"
            VersionInfo.CurrentCommit = HasPreviousCommit and PreviousCommit or nil
            VersionInfo.PreviousCommit = HasPreviousCommit and PreviousCommit or nil
            VersionInfo.CheckedAt = PreviousCheckedAt
            VersionInfo.PersistenceAvailable = nil
            VersionCheckRunning = false
            NotifyVersionStatus("Unavailable", "GitHub could not be reached. No saved version data was changed.")
            return
        end

        if Genv.State.VersionCheckGeneration ~= VersionCheckGeneration or Destroyed then
            VersionCheckRunning = false
            return
        end

        local RawMessage = type(CommitData) == "table" and CommitData.message or ""
        local CommitMessage = type(RawMessage) == "string" and RawMessage:match("([^\r\n]+)") or ""
        CommitMessage = tostring(CommitMessage):gsub("[%c]", " "):gsub("%s+", " "):sub(1, 180)
        local VersionChanged = SameBranch and type(Previous.Version) == "string"
            and Previous.Version ~= CurrentVersion
        local CommitChanged = SameBranch and HasPreviousCommit and PreviousCommit ~= Commit
        local HasChanges = CommitChanged or VersionChanged
        local Status = HasChanges and "Changed" or "Unchanged"
        if not SameBranch or not HasPreviousCommit then
            Status = "Baseline"
        end

        VersionInfo.Status = Status
        VersionInfo.CurrentCommit = Commit
        VersionInfo.PreviousCommit = HasPreviousCommit and PreviousCommit or nil
        VersionInfo.CommitMessage = CommitMessage
        VersionInfo.CheckedAt = Now

        local Record = {
            Version = CurrentVersion,
            Branch = RepositoryBranch,
            Commit = Commit,
            Message = CommitMessage,
            CheckedAt = Now
        }
        local EncodeSuccess, Encoded = pcall(HttpService.JSONEncode, HttpService, Record)
        local WriteSuccess, Written = false, false
        if EncodeSuccess and type(Encoded) == "string" then
            WriteSuccess, Written = pcall(Hub.CreateFile, Hub, VersionStatePath, Encoded)
        end
        VersionInfo.PersistenceAvailable = WriteSuccess and Written == true
        VersionCheckRunning = false

        if Status == "Changed" then
            local PreviousShort = HasPreviousCommit and PreviousCommit:sub(1, 8) or "unknown"
            local Description = ("Version %s | %s: %s → %s")
                :format(CurrentVersion, RepositoryBranch, PreviousShort, Commit:sub(1, 8))
            if CommitMessage ~= "" then
                Description ..= "\n" .. CommitMessage
            end
            if not VersionInfo.PersistenceAvailable then
                Description ..= "\nCould not save the last-seen version."
            end
            NotifyVersionStatus(Status, Description)
        elseif Status == "Baseline" then
            local Description = ("Version %s | branch %s | commit %s")
                :format(CurrentVersion, RepositoryBranch, Commit:sub(1, 8))
            if not VersionInfo.PersistenceAvailable then
                Description ..= "\nCould not save the last-seen version."
            end
            NotifyVersionStatus(Status, Description)
        else
            NotifyVersionStatus(Status, ("Version %s | no new commits on %s | %s")
                :format(CurrentVersion, RepositoryBranch, Commit:sub(1, 8)))
        end
    end)

    return true
end

function Base:CheckForUpdates(Force)
    return CheckForUpdates(Force == true)
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

if VersionConfig.CheckForChanges ~= false then
    CheckForUpdates(false)
end

--// Return

return Base
