local HttpService = game:GetService("HttpService")
local Root = "SpecterX"

-- ================================================= 
-- FUNÇÕES
-- ================================================= 

local function EnsureFileSystemSupport()
    local required = {"isfolder", "makefolder", "isfile", "writefile", "readfile"}
    for _, fn in ipairs(required) do
        if not (getgenv and getgenv()[fn] or _G[fn] or rawget(_G, fn)) and not (type(_G[fn]) == "function") then
        end
    end
end

local function Path(...)
    return Root .. "/" .. table.concat({...}, "/")
end

local function CreateFolder(...)
    local Folder = Path(...)
    if not isfolder(Folder) then
        makefolder(Folder)
    end
    return Folder
end

local function CreateFile(Content, ...)
    local File = Path(...)
    if not isfile(File) then
        writefile(File, Content or "")
    end
    return File
end

local function Encode(Data)
    local success, result = pcall(HttpService.JSONEncode, HttpService, Data)
    if success then
        return result
    else
        warn("Falha ao codificar JSON:", result)
        return "{}"
    end
end

local function Decode(Data)
    local success, result = pcall(HttpService.JSONDecode, HttpService, Data)
    if success then
        return result
    else
        warn("Falha ao decodificar JSON:", result)
        return {}
    end
end

local function LoadConfig(defaultConfig, ...)
    local File = Path(...)
    if isfile(File) then
        local content = readfile(File)
        local ok, decoded = pcall(Decode, content)
        if ok and type(decoded) == "table" then
            return decoded
        end
    end

    writefile(File, Encode(defaultConfig))
    return defaultConfig
end

local function SaveConfig(config, ...)
    local File = Path(...)
    writefile(File, Encode(config))
end

-- ================================================= 
-- FOLDERS
-- ================================================= 

CreateFolder("Library")
CreateFolder("Games")

-- ================================================= 
-- SUB FOLDERS
-- ================================================= 

CreateFolder("Library", "Assets")
