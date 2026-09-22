local HttpService = game:GetService("HttpService")

local DiscordRPC = {}
local RPC_URL = "http://127.0.0.1:6463/rpc?v=1"

local function ExtractInviteCode(Invite)
    assert(type(Invite) == "string" and #Invite > 0, "ERRO: Invite precisa ser uma string não vazia")
    local Cleaned = Invite:gsub("%s+", "")

    local Code = Cleaned:match("discord%.gg/([%w%-_]+)")
        or Cleaned:match("discord%.com/invite/([%w%-_]+)")

    if not Code then
        Code = Cleaned:match("^https?://") and nil or Cleaned
    end

    if not Code or Code == "" then
        return nil, "Não foi possível extrair um código válido de: " .. tostring(Invite)
    end

    return Code
end

function DiscordRPC:OpenInvite(Invite)
    local Code, ExtractError = ExtractInviteCode(Invite)
    if not Code then
        warn("Discord RPC:", ExtractError)
        return false, ExtractError
    end

    local Body = {
        args = { code = Code },
        cmd = "INVITE_BROWSER",
        nonce = HttpService:GenerateGUID(false)
    }

    local Ok, EncodedBody = pcall(function()
        return HttpService:JSONEncode(Body)
    end)

    if not Ok then
        warn("Discord RPC: falha ao codificar JSON:", EncodedBody)
        return false, EncodedBody
    end

    local Success, Response = pcall(function()
        return request({
            Url = RPC_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Origin"] = "https://discord.com"
            },
            Body = EncodedBody
        })
    end)

    if not Success then
        warn("Discord RPC: request falhou:", Response)
        return false, Response
    end

    if Response and Response.StatusCode and Response.StatusCode ~= 200 then
        warn("Discord RPC: status inesperado:", Response.StatusCode, Response.Body)
        return false, Response
    end

    local ClipboardOk, ClipboardErr = pcall(function()
        setclipboard("https://discord.gg/" .. Code)
    end)

    if not ClipboardOk then
        warn("Discord RPC: falha ao copiar para o clipboard:", ClipboardErr)
    end

    return true, Response
end

return DiscordRPC
