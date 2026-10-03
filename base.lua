--// Hub

local Hub = loadstring(game:HttpGet("https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/Modules/Hub/script.lua"))()

--// Global

local Genv = Hub:GetGenv()
Genv.State = Genv.State or {}

--// Loader

if Genv.State.Loading then
    warn("Script is already loading. Please wait until the current loading process is complete.")
    return Genv.State.Base
end
Genv.State.Loading = true

--// Require

local Load = function(...) return Hub:LoadRequire(...) end
local Config = function(...) return Hub:GetConfig(...) end

local Notify = Load("Core/Modules/Hub/Notification/script.lua")
if type(Notify) ~= "table" then
	Notify = {}
end

local Games = Load("Games/games.lua")
if type(Games) ~= "table" then
    Games = {}
end

local UseLoader = ...
UseLoader = UseLoader == nil and Config("LoadingScreen") or UseLoader

if UseLoader then
    local Loader = Load("Core/Modules/Loader/script.lua")
    if type(Loader) == "table" and type(Loader.Run) == "function" then
        Loader:Run()
    end
end

local function GetGame()
    return Games[game.PlaceId] or Games[game.GameId] or "Universal"
end

--// Build

local Lib = Load("Core/Library/lib.lua")
if type(Lib) ~= "table" then
    Genv.State.Loading = false
    error("Falha crítica: não foi possível carregar a Library. Abortando.", 0)
end

local Base = {
    Library = Lib,

    Title = ("%s | %s"):format(tostring(Config("Title")), tostring(GetGame())),
    SubTitle = tostring(Config("SubTitle")),

    Icon = Config("Icon"),
    DiscordInvite = Config("DiscordInvite")
}
setmetatable(Base, {__index = Lib})

--// State

if Genv.State.Window then
    Genv.State.Window:Destroy()
    Genv.State.Window = nil
end
Genv.State.Window = Lib.Window

--// Addons

Base.GetConfig = function(_, ...) return Config(...) end
Base.LoadRequire = function(_, ...) return Load(...) end

Base.Translate = function(_, ...) return Hub:Translate(...) end

function Base:GenerateName(...)
    return Hub:GenerateName(...)
end

function Base:Genv()
    return Genv
end

for Name, Value in pairs(Notify) do
	if type(Value) == "function" then
		Base[Name] = function(...)
			if ... == Base then
				return Value(Notify, select(2, ...))
			end

			return Value(Notify, ...)
		end
	end
end

--// Return

Genv.State.Base = Base
Genv.State.Loading = false

return Base