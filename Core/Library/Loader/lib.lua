local BASE_URL = "https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/"
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

local libraly = LoadRequire("Core/Library/library.lua")
local Window = libraly.Window
if Window then
    Window:Destroy()
end

local loader = LoadRequire("Core/Modules/Hub/loading.lua")
loader:Run()

return libraly
