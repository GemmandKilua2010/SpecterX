--// Services

local HttpService = game:GetService("HttpService")

--// Bootstrap

local CONFIG_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/config.lua"
local ConfigData = assert(loadstring(game:HttpGet(CONFIG_URL)))()

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

local HubChunk = assert(loadstring(game:HttpGet(BaseUrl .. "Core/Modules/Hub/script.lua")))
local Hub = HubChunk(ConfigData, BaseUrl)

--// Global

local Genv = Hub:GetGenv()
Genv.State = Genv.State or {}

--// Preferences

local LibraryConfig = type(ConfigData.Library) == "table" and ConfigData.Library or {}
local SettingsFolder = type(LibraryConfig.SettingsFolder) == "string" and LibraryConfig.SettingsFolder or "Library"
local SettingsFile = type(LibraryConfig.SettingsFile) == "string" and LibraryConfig.SettingsFile or "settings.json"
local SettingsPath = SettingsFolder .. "/" .. SettingsFile

if Hub:FileExists(SettingsPath) then
    local Source = Hub:ReadFile(SettingsPath)
    if type(Source) == "string" then
        local Success, Saved = pcall(HttpService.JSONDecode, HttpService, Source)
        if Success and type(Saved) == "table" then
            if type(Saved.Language) == "string" then
                Hub:SetLanguage(Saved.Language)
            end

            if type(Saved.Theme) == "string" then
                Hub:SetTheme(Saved.Theme)
            end
        end
    end
end

--// State

if Genv.State.Loading then
    Hub:Warn("Script is already loading. Please wait until the current loading process is complete.")
    return Genv.State.Base
end

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
    Loader = Load("Core/Modules/Loader/script.lua")

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
local IconsReady = Instance.new("BindableEvent")
IconsReady.Name = Hub:GenerateName(12)

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

    Title = ("%s | %s"):format(Title, tostring(Hub:GetGame())),
    SubTitle = tostring(Config("SubTitle") or ""),

    Icon = Icon,
    DiscordInvite = DiscordInvite,
}

setmetatable(Base, {__index = Lib})

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

--// Finish

Genv.State.Base = Base

if Loader then
    Loader:Finish()
    Loader:Wait()
end

if type(Icons) == "table" and type(Notify.Notify) == "function" then
    Base:Notify({
        Title = Config("Title"),
        Description = Hub:Format(
            Hub:Translate("{Title} is ready. Enjoy your experience!"),
            {Title = Title}
        ),
        Time = 3
    })
end

Genv.State.Loading = false

--// Return

return Base
