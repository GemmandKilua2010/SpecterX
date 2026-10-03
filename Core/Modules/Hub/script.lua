--// Services

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

--// Variables

local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
local Lower = string.lower
local Regions = setmetatable({}, {__mode = "k"})

local RNG = Random.new()
local Chars = table.create(62)

for Char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"):gmatch(".") do
    Chars[#Chars + 1] = string.byte(Char)
end

--// Functions

local function LoadRequire(Url, Base, Retries)
    Retries = Retries or 3
    local LastError

    for Attempt = 1, Retries do
        local Success, Result = pcall(function()
            return assert(loadstring(game:HttpGet((Base or BASE_URL) .. Url)))()
        end)

        if Success then
            return Result
        end

        LastError = Result

        if Attempt < Retries then
            task.wait(0.5 * Attempt)
        end
    end

    warn(("Falha ao carregar %s: %s"):format(Url, tostring(LastError)))
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

--// Require

local Configs = BuildLookup(LoadRequire("Core/config.lua"))
local Translation = LoadRequire("Core/Modules/Hub/Translation/script.lua")

local Notify = LoadRequire("Core/Modules/Hub/Notify/script.lua")

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

--// Main Functions

function Main:LoadRequire(Url, Base, Retries)
    return LoadRequire(Url, Base, Retries)
end

function Main:GetConfig(Name)
    return ResolveConfig(Configs[Lower(tostring(Name))], self:GetPlayerRegion())
end

function Main:GetGenv()
    local Env = getgenv()
    local Title = tostring(Configs.title or "SpecterX")

    Env[Title] = Env[Title] or {}
    return Env[Title]
end

function Main:GenerateName(Len: number?): string
    local Size = math.clamp(math.floor(tonumber(Len) or 12), 1, 256)
    local Buf = buffer.create(Size)

    for Index = 0, Size - 1 do
        buffer.writeu8(Buf, Index, Chars[RNG:NextInteger(1, #Chars)])
    end

    return buffer.tostring(Buf)
end

--// Translation

function Main:GetPlayerRegion(Plr)
    Plr = Plr or Players.LocalPlayer
    if not Plr then
        warn("ScriptHub: No player found.")
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
    return Translation:Translate(Text, Language or self:GetPlayerRegion())
end

--// Notify

for Name, Value in Notify do
	if type(Value) == "function" then
		Main[Name] = function(...)
			if ... == Main then
				return Value(Notify, select(2, ...))
			end
			return Value(Notify, ...)
		end
	end
end

--// Return

return Main
