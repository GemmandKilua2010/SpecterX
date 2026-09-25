local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
local DEFAULTS = {
    Title = "SpecterX",
    SubTitle = "By Specter",

    Icon = {
        Image = 94800455817009,
        Transparency = 0,
        Corner = 5
    },

    DiscordInvite = {
        Name = "SpecterX",
        Desc = "Entre no nosso Discord e acompanhe todas as atualizações do SpecterX.",
        Logo = 94800455817009,
        Invite = "Em Breve!",
        RPC = false
    }
}

local function LoadRequire(url, retries)
    retries = retries or 3
    local lastError

    for attempt = 1, retries do
        local ok, result = pcall(function()
            local source = game:HttpGet(BASE_URL .. url)
            local chunk, compileError = loadstring(source)

            if not chunk then
                error(compileError, 0)
            end

            return chunk()
        end)

        if ok then
            return result
        end

        lastError = result
        task.wait(0.5 * attempt)
    end

    warn(("Falha ao carregar %s: %s"):format(url, tostring(lastError)))
    return nil
end

local function BuildLookup(tbl)
    local lookup = {}
    if type(tbl) ~= "table" then
        return lookup
    end

    for key, value in pairs(tbl) do
        lookup[tostring(key):lower()] = value
    end

    return lookup
end

local Configs = BuildLookup(LoadRequire("Core/config.lua"))
local function ParseConfig(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, value in pairs(value) do
        if type(value) == "table" then
            result[key] = ParseConfig(value)
        elseif type(value) == "number" then
            local keyName = tostring(key):lower()

            if keyName:find("image", 1, true)
                or keyName:find("logo", 1, true)
                or keyName:find("icon", 1, true) then
                result[key] = "rbxassetid://" .. tostring(value)
            else
                result[key] = value
            end
        else
            result[key] = value
        end
    end

    return result
end

local Main = {}

function Main:GetConfig(name)
    local key = tostring(name):lower()
    local value = Configs[key]

    if value == nil then
        value = DEFAULTS[key] or DEFAULTS[name]
    end

    return ParseConfig(value)
end

function Main:LoadRequire(url, retries)
    return LoadRequire(url, retries)
end

return Main
