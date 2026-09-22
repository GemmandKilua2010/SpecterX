local function LoadRequire(url, retries)
    retries = retries or 3
    local lastError

    for attempt = 1, retries do
        local ok, result = pcall(function()
            local source = game:HttpGet(url)
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

    warn(("[SpecterX] Falha ao carregar %s: %s"):format(url, tostring(lastError)))
    return nil
end

local libraly = LoadRequire("https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/Library/library.lua")
if libraly.Window then
    libraly.Window:Destroy()
end

local loader = LoadRequire("https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/Library/Loader/Main/loading.lua")
local paste = LoadRequire("https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/Library/Loader/Main/paste.lua")

loader:Run()

repeat
    task.wait()
until not game:GetService("CoreGui"):FindFirstChild("SpecterXLoading")

return libraly
