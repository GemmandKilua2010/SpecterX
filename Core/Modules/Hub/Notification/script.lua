local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

--// Context

local Hub, RootConfig = ...

--// Runtime

local FallbackRNG = Random.new()
local FallbackCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local FallbackCharacterCount = #FallbackCharacters

local function GenerateName(Length)
    if type(Hub) == "table" and type(Hub.GenerateName) == "function" then
        return Hub:GenerateName(Length)
    end

    Length = math.clamp(math.floor(tonumber(Length) or 12), 1, 256)
    local Parts = table.create(Length)

    for Index = 1, Length do
        local Position = FallbackRNG:NextInteger(1, FallbackCharacterCount)
        Parts[Index] = FallbackCharacters:sub(Position, Position)
    end

    return table.concat(Parts)
end
local Notify = {}
local Controller = {}
Controller.__index = Controller
local Config = {
    Width = 320,
    MinWidth = 220,
    MaxGrowWidth = 460,
    AutoGrow = true,
    GrowMaxLines = 3,
    MaxTitleLength = 120,
    MaxTextLength = 500,
    Padding = 14,
    Gap = 6,
    IconSize = 32,
    TitleSize = 15,
    TextSize = 13,
    ProgressHeight = 3,
    DefaultTitle = "Notification",
    DefaultDescription = "Description",
    Duration = 3,
    MaxNotification = 5,
    QueueLimit = 40,
    QueueOverflow = "DropOldest",
    NewestOnTop = true,
    PreventDuplicates = false,
    Priority = 0,
    DisplayTime = true,
    CloseBtn = true,
    PauseOnHover = false,
    Clickable = false,
    Shadow = true,
    RichText = false,
    Position = "BottomRight",
    Margin = Vector2.new(14, 36),
    Animation = "SlideFade",
    AnimationTime = 0.3,
    CloseAnimationTime = 0.22,
    CornerRadius = UDim.new(0, 10),
    CloseIcon = "rbxassetid://10747384394",
    CloseIconSize = 14,
    TitleFont = Enum.Font.GothamBold,
    TextFont = Enum.Font.Gotham,
    DisplayOrder = 1000,
    Responsive = true,
    CompactBreakpoint = 640,
    MobileMargin = Vector2.new(10, 10),
    MobileCenter = true,
    TouchCloseSize = 32,
    TypeColors = {
        Info = Color3.fromRGB(88, 160, 255),
        Success = Color3.fromRGB(66, 211, 135),
        Warning = Color3.fromRGB(255, 187, 66),
        Error = Color3.fromRGB(255, 95, 109),
    },
    TypeGlyphs = {},
    TypeIcons = {
        Info = "rbxassetid://10723415903",
        Success = "rbxassetid://10709790298",
        Warning = "rbxassetid://10709753149",
        Error = "rbxassetid://10747383819",
    },
}
local configAliases = {
    defaultduration = "duration",
    animationstyle = "animation",
    view = "displaytime",
    maxwidth = "width",
    animtime = "animationtime",
    closeanimtime = "closeanimationtime",
    closebutton = "closebtn",
    maxvisible = "maxnotification",
}
local configKeys = {}
for key in pairs(Config) do
    configKeys[key:lower()] = key
end
local function new(class, parent, props)
    local obj = Instance.new(class)

    for k, v in pairs(props) do
        if k ~= "Name" then
            obj[k] = v
        end
    end

    obj.Name = GenerateName(12)
    obj.Parent = parent
    return obj
end

local function RandomizeTree(Root)
    Root.Name = GenerateName(12)

    for _, Descendant in ipairs(Root:GetDescendants()) do
        Descendant.Name = GenerateName(12)
    end
end
local function copy(t)
    local r = {}
    for k, v in pairs(t) do r[k] = type(v) == "table" and copy(v) or v end
    return r
end
local function merge(a, b)
    local r = copy(a)
    for k, v in pairs(b or {}) do
        if type(v) == "table" and type(r[k]) == "table" then
            r[k] = merge(r[k], v)
        else
            r[k] = v
        end
    end
    return r
end
local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        if type(Hub) == "table" and type(Hub.Warn) == "function" then
            Hub:Warn("Notification callback failed: {Error}", {
                Error = tostring(err)
            })
        else
            warn(tostring(err))
        end
    end
end
local function remove(list, value)
    local i = table.find(list, value)
    if i then table.remove(list, i) end
end
local function cancelTask(thread)
    if thread then pcall(task.cancel, thread) end
end
local function cancelTween(tween)
    if tween then pcall(tween.Cancel, tween) end
end
local function asset(value)
    if value == nil or value == false or value == true or value == "" then return nil end
    if type(value) == "number" then return "rbxassetid://" .. math.floor(value) end
    return tostring(value)
end
local typeMap = {info = "Info", success = "Success", warning = "Warning", warn = "Warning", error = "Error"}
local function kind(value)
    if type(value) ~= "string" or value == "" then return nil end
    return typeMap[value:lower()] or value
end
local function indexOf(data)
    local map = {}
    for k, v in pairs(data) do
        if type(k) == "string" then map[k:lower()] = v end
    end
    return map
end
local function get(map, names)
    for _, name in ipairs(names) do
        local v = map[name]
        if v ~= nil then return v end
    end
    return nil
end
local function option(map, names, default)
    local v = get(map, names)
    if v == nil then return default end
    return v
end
local function clip(value, limit)
    if not limit or limit <= 0 or Config.RichText then return value end
    local len = utf8.len(value)
    if len and len > limit then
        return value:sub(1, utf8.offset(value, limit + 1) - 1) .. "…"
    end
    return value
end
local Style = {
    Background = Color3.fromRGB(24, 24, 29),
    BackgroundTransparency = 0.02,
    Stroke = Color3.fromRGB(72, 72, 84),
    StrokeTransparency = 0.35,
    Title = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(176, 176, 190),
    Accent = Color3.fromRGB(122, 122, 255),
    Progress = Color3.fromRGB(122, 122, 255),
    CloseButton = Color3.fromRGB(176, 176, 190),
    CloseButtonHover = Color3.fromRGB(255, 255, 255),
}
local function currentTheme()
    return Style
end
local function hubThemeColor(Palette)
    local Data = Palette
    if type(Data) ~= "table" and type(Hub) == "table" and type(Hub.GetThemeData) == "function" then
        Data = Hub:GetThemeData()
    end

    local Color = type(Data) == "table" and Data["Color Theme"] or nil
    return typeof(Color) == "Color3" and Color or Style.Progress
end
local runtime = {}

if type(Hub) == "table" and type(Hub.GetGenv) == "function" then
    local Genv = Hub:GetGenv()
    Genv.Runtime = Genv.Runtime or {}
    Genv.Runtime.Notification = Genv.Runtime.Notification or {}
    runtime = Genv.Runtime.Notification
end

if type(runtime.Owner) == "table" and type(runtime.Owner.Destroy) == "function" then
    pcall(runtime.Owner.Destroy, runtime.Owner)
elseif typeof(runtime.Gui) == "Instance" or runtime.InputConnection or runtime.ThemeConnection or runtime.LanguageConnection then
    for _, List in ipairs({runtime.Active or {}, runtime.Queue or {}}) do
        for _, ControllerObject in ipairs(List) do
            local State = type(ControllerObject) == "table" and ControllerObject._state
            if type(State) == "table" then
                if State.TimerTask then pcall(task.cancel, State.TimerTask) end
                if State.ProgressTween then pcall(State.ProgressTween.Cancel, State.ProgressTween) end
                for _, Connection in ipairs(State.Connections or {}) do
                    pcall(Connection.Disconnect, Connection)
                end
                State.Status = "Closed"
            end
        end
        table.clear(List)
    end

    for _, Name in ipairs({"InputConnection", "ContainerConnection", "ThemeConnection", "LanguageConnection"}) do
        local Connection = runtime[Name]
        if Connection then pcall(Connection.Disconnect, Connection) end
        runtime[Name] = nil
    end

    if typeof(runtime.Gui) == "Instance" then
        pcall(runtime.Gui.Destroy, runtime.Gui)
    end
    runtime.Gui, runtime.Container, runtime.Layout, runtime.ProcessQueue = nil, nil, nil, nil
end

runtime.Active = runtime.Active or {}
runtime.Queue = runtime.Queue or {}
runtime.Sequence = tonumber(runtime.Sequence) or 0

local active, queue = runtime.Active, runtime.Queue
local gui = typeof(runtime.Gui) == "Instance" and runtime.Gui or nil
local container = typeof(runtime.Container) == "Instance" and runtime.Container or nil
local layout = typeof(runtime.Layout) == "Instance" and runtime.Layout or nil

if gui and gui.Parent then
    RandomizeTree(gui)
end
local cameraConnection, workspaceConnection, inputConnection
local destroyed = false
local closing = {}
local relayoutQueued = false
local processQueue, closeState, onViewportChanged
local TITLE_KEYS = {"title", "header", "name", "heading", "titulo", "título", "label"}
local TEXT_KEYS = {"text", "desc", "description", "content", "message", "msg", "body", "subtitle", "descricao", "descrição", "texto", "mensagem"}
local DURATION_KEYS = {"duration", "timeout", "delay", "length", "time", "tempo", "duracao", "duração"}
local ICON_KEYS = {"icon", "image"}
local function readText(data, map)
    local title = get(map, TITLE_KEYS)
    local desc = get(map, TEXT_KEYS)
    if title == nil then title = data[1] end
    if desc == nil then desc = data[2] end
    if title == nil then
        title = type(Hub) == "table" and type(Hub.Translate) == "function"
            and Hub:Translate(Config.DefaultTitle)
            or Config.DefaultTitle
    end
    if desc == nil then
        desc = type(Hub) == "table" and type(Hub.Translate) == "function"
            and Hub:Translate(Config.DefaultDescription)
            or Config.DefaultDescription
    end
    return clip(tostring(title), Config.MaxTitleLength), clip(tostring(desc), Config.MaxTextLength)
end
local function readDuration(data, map)
    local raw = get(map, DURATION_KEYS)
    local value = raw ~= nil and tonumber(raw) or nil
    if value == nil and type(data[4]) == "number" then value = data[4] end
    if value == nil or value < 0 then value = Config.Duration end
    if value == math.huge then return 0 end
    return value
end
local function readIcon(data, map)
    local icon = get(map, ICON_KEYS)
    if icon == nil then icon = data[3] end
    return icon
end
local function normalize(...)
    local offset = select(1, ...) == Notify and 1 or 0
    local title = select(offset + 1, ...)
    if type(title) == "table" then return table.clone(title) end
    return {
        Title = title,
        Text = select(offset + 2, ...),
        Icon = select(offset + 3, ...),
        Duration = select(offset + 4, ...),
    }
end
local function viewportSize()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end
local function isCompact()
    if not Config.Responsive then return false end
    if viewportSize().X < Config.CompactBreakpoint then return true end
    return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end
local function isCentered()
    return Config.MobileCenter == true and isCompact()
end
local function currentMargin()
    return isCompact() and Config.MobileMargin or Config.Margin
end
local function maxVisible()
    return math.max(1, tonumber(Config.MaxNotification) or 1)
end
local function placement()
    local p = tostring(Config.Position):lower()
    return p:find("top") ~= nil, p:find("left") ~= nil
end
local function closeSize()
    return isCompact() and Config.TouchCloseSize or 24
end
local function availableWidth()
    return math.max(160, viewportSize().X - currentMargin().X * 2)
end
local function containerWidth()
    return math.min(math.max(Config.MaxGrowWidth, Config.Width), availableWidth())
end
local lineCache = {}
local function lineHeight(size, font)
    local key = size .. font.Name
    local h = lineCache[key]
    if not h then
        local ok, result = pcall(TextService.GetTextSize, TextService, "A", size, font, Vector2.new(1e5, 1e5))
        h = ok and result.Y or size
        lineCache[key] = h
    end
    return h
end
local function measure(text, size, font, width)
    if Config.RichText then text = text:gsub("<[^>]+>", "") end
    local ok, result = pcall(TextService.GetTextSize, TextService, text, size, font, Vector2.new(width, 1e5))
    return ok and result or Vector2.zero
end
local function computeWidth(s)
    local available = availableWidth()
    local base = math.clamp(Config.Width, math.min(Config.MinWidth, available), available)
    local maxW = math.clamp(math.max(Config.MaxGrowWidth, base), base, available)
    if not Config.AutoGrow or maxW <= base then return base end
    local overhead = Config.Padding * 2
        + (s.IconKind and (Config.IconSize + 12) or 0)
        + (s.Options.CloseBtn and (closeSize() + 2) or 0)
    local baseBox = base - overhead
    local titleEst = (utf8.len(s.Title) or #s.Title) * Config.TitleSize * 0.62
    local textEst = (utf8.len(s.Text) or #s.Text) * Config.TextSize * 0.6
    if titleEst <= baseBox and textEst <= baseBox then return base end
    local titleH = lineHeight(Config.TitleSize, Config.TitleFont)
    local textH = lineHeight(Config.TextSize, Config.TextFont)
    local function fits(w)
        local box = w - overhead
        if s.Title ~= "" and measure(s.Title, Config.TitleSize, Config.TitleFont, box).Y > titleH * 2 + 1 then
            return false
        end
        if s.Text ~= "" and measure(s.Text, Config.TextSize, Config.TextFont, box).Y > textH * Config.GrowMaxLines + 1 then
            return false
        end
        return true
    end
    local w = base
    while w < maxW and not fits(w) do
        w = math.min(w + 20, maxW)
    end
    return w
end
local function relayoutState(s)
    local r = s.Refs
    if not r or not r.Slot then return end
    s.Width = computeWidth(s)
    r.Slot.Size = UDim2.new(0, s.Width, 0, 0)
end
local function hiddenOffset(s)
    local top, left = placement()
    if isCentered() then
        local h = s.Refs and s.Refs.Holder and s.Refs.Holder.AbsoluteSize.Y or 0
        return Vector2.new(0, (top and -1 or 1) * (math.max(h, 80) + 40))
    end
    return Vector2.new((left and -1 or 1) * ((s.Width or Config.Width) + 40), 0)
end
local function animFlags()
    local style = tostring(Config.Animation):lower()
    local slide = style == "slide" or style == "slidefade"
    local fade = style == "fade" or style == "slidefade" or style == "scale"
    local scale = style == "scale"
    return slide, fade, scale, style ~= "none"
end
local function resolveGuiParent()
    local RobloxGui

    local Success, Result = pcall(CoreGui.FindFirstChild, CoreGui, "RobloxGui")
    if Success then
        RobloxGui = Result
    end

    if not RobloxGui then
        Success, Result = pcall(CoreGui.WaitForChild, CoreGui, "RobloxGui", 1)
        if Success then
            RobloxGui = Result
        end
    end

    return typeof(RobloxGui) == "Instance" and RobloxGui or CoreGui
end
local function parentForGui()
    local LibraryRuntime

    if type(Hub) == "table" and type(Hub.GetGenv) == "function" then
        local Success, Genv = pcall(Hub.GetGenv, Hub)
        if Success and type(Genv) == "table" then
            Genv.Runtime = Genv.Runtime or {}
            Genv.Runtime.Library = Genv.Runtime.Library or {}
            LibraryRuntime = Genv.Runtime.Library
        end
    end

    if LibraryRuntime then
        local Shared = LibraryRuntime.GuiContainer
        if typeof(Shared) == "Instance" and Shared:IsA("Folder") and Shared.Parent then
            return Shared
        end

        local LibraryGui = LibraryRuntime.Gui
        if typeof(LibraryGui) == "Instance" and LibraryGui.Parent then
            LibraryRuntime.GuiContainer = LibraryGui.Parent
            return LibraryGui.Parent
        end

        local TargetParent = resolveGuiParent()
        local Success, Result = pcall(new, "Folder", TargetParent, {Archivable = false})

        if (not Success or typeof(Result) ~= "Instance") and TargetParent ~= CoreGui then
            Success, Result = pcall(new, "Folder", CoreGui, {Archivable = false})
        end

        if Success and typeof(Result) == "Instance" then
            LibraryRuntime.GuiContainer = Result
            return Result
        end
    end

    return resolveGuiParent()
end
local function updateContainer()
    if not (container and gui and layout) then return end
    local top, left = placement()
    local centered = isCentered()
    local margin = currentMargin()
    local anchorX = centered and 0.5 or (left and 0 or 1)
    local offsetX = centered and 0 or (left and margin.X or -margin.X)
    gui.DisplayOrder = Config.DisplayOrder
    container.AnchorPoint = Vector2.new(anchorX, top and 0 or 1)
    container.Position = UDim2.new(anchorX, offsetX, top and 0 or 1, top and margin.Y or -margin.Y)
    container.Size = UDim2.new(0, containerWidth(), 1, -margin.Y * 2)
    layout.Padding = UDim.new(0, Config.Gap)
    layout.HorizontalAlignment = centered and Enum.HorizontalAlignment.Center
        or (left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right)
    layout.VerticalAlignment = top and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
end
local function bindCamera()
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    local camera = workspace.CurrentCamera
    if camera then
        cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportChanged)
    end
    if not workspaceConnection then
        workspaceConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            bindCamera()
            onViewportChanged()
        end)
    end
end
local function bindQueue()
    if runtime.ContainerConnection then
        pcall(function() runtime.ContainerConnection:Disconnect() end)
        runtime.ContainerConnection = nil
    end
    if container then
        runtime.ContainerConnection = container.ChildRemoved:Connect(function(child)
            if child:IsA("Frame") then
                task.defer(function()
                    local fn = runtime.ProcessQueue
                    if fn then fn() end
                end)
            end
        end)
    end
end
local function getContainer()
    if destroyed then return false end
    if gui and gui.Parent and container and container.Parent and layout and layout.Parent then
        if not runtime.ContainerConnection then bindQueue() end
        return true
    end

    if gui then
        pcall(gui.Destroy, gui)
    end

    gui = nil
    container = nil
    layout = nil

    local parent = parentForGui()
    if not parent then return false end

    local Success, Result = pcall(new, "ScreenGui", parent, {
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = Config.DisplayOrder,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })

    if (not Success or typeof(Result) ~= "Instance") and parent ~= CoreGui then
        Success, Result = pcall(new, "ScreenGui", CoreGui, {
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = Config.DisplayOrder,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
    end

    if not Success or typeof(Result) ~= "Instance" then return false end
    gui = Result

    container = new("Frame", gui, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })

    layout = new("UIListLayout", container, {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    runtime.Gui = gui
    runtime.Container = container
    runtime.Layout = layout

    pcall(function()
        gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    end)

    bindQueue()
    updateContainer()
    bindCamera()
    return true
end
onViewportChanged = function()
    if relayoutQueued then return end
    relayoutQueued = true
    task.defer(function()
        relayoutQueued = false
        if not gui then return end
        updateContainer()
        for _, c in ipairs(active) do relayoutState(c._state) end
        processQueue()
    end)
end

if runtime.InputConnection then
    pcall(function() runtime.InputConnection:Disconnect() end)
    runtime.InputConnection = nil
end

inputConnection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(onViewportChanged)
runtime.InputConnection = inputConnection
local function leftTime(s)
    if s.Duration <= 0 then return 0 end
    if s.StartedAt then return math.max(s.Remaining - (os.clock() - s.StartedAt), 0) end
    return math.max(s.Remaining, 0)
end
local function stopRuntime(s)
    cancelTask(s.TimerTask)
    cancelTween(s.ProgressTween)
    s.TimerTask, s.ProgressTween = nil, nil
end
local function startRuntime(s)
    stopRuntime(s)
    if s.Status ~= "Active" or s.Paused or s.Duration <= 0 or not s.Refs then return end
    s.StartedAt = os.clock()
    s.TimerTask = task.delay(s.Remaining, function()
        s.TimerTask = nil
        if s.Status == "Active" and not s.Paused then closeState(s, true) end
    end)
    local fill = s.Refs.Fill
    if fill then
        fill.Size = UDim2.fromScale(math.clamp(s.Remaining / s.Duration, 0, 1), 1)
        s.ProgressTween = TweenService:Create(fill, TweenInfo.new(math.max(s.Remaining, 0.01), Enum.EasingStyle.Linear), {Size = UDim2.fromScale(0, 1)})
        s.ProgressTween:Play()
    end
end
local function pause(s, value)
    if not s or s.Status ~= "Active" or s.Paused == value then return end
    if value then
        s.Remaining, s.StartedAt, s.Paused = leftTime(s), nil, true
        stopRuntime(s)
    else
        s.Paused = false
        startRuntime(s)
    end
end
local function iconOf(icon, t)
    if icon == false then return nil, nil end
    local custom = asset(icon)
    if custom then return custom, "Custom" end
    local typed = t and asset(Config.TypeIcons[t])
    if typed then return typed, "Type" end
    local glyph = t and Config.TypeGlyphs[t]
    if glyph then return glyph, "Glyph" end
end
local function accentColors(s, t)
    local custom = s.Accent
    if not custom and s.Type then custom = Config.TypeColors[s.Type] end
    return custom or t.Accent, s.ProgressColor or hubThemeColor()
end
local function applyTheme(s)
    local r = s.Refs
    if not r then return end
    local t = currentTheme(s)
    local accent, progress = accentColors(s, t)
    r.Card.BackgroundColor3 = t.Background
    r.Card.BackgroundTransparency = t.BackgroundTransparency
    r.Stroke.Color = t.Stroke
    r.Stroke.Transparency = t.StrokeTransparency
    if r.Title then r.Title.TextColor3 = t.Title end
    if r.Text then r.Text.TextColor3 = t.Text end
    if r.Bubble then r.Bubble.BackgroundColor3 = accent end
    if r.Glyph then r.Glyph.TextColor3 = accent end
    if r.Icon and s.IconKind == "Type" then r.Icon.ImageColor3 = accent end
    if r.Track then r.Track.BackgroundColor3 = t.Title end
    if r.Fill then r.Fill.BackgroundColor3 = progress end
    if r.CloseIcon then r.CloseIcon.ImageColor3 = t.CloseButton end
end
local function syncLabel(s, key, value, font, size, order)
    local r = s.Refs
    local current = r[key]
    if value == "" then
        if current then
            current:Destroy()
            r[key] = nil
        end
        return
    end
    if not current then
        current = new("TextLabel", r.Column, {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = order,
            ZIndex = 5,
        })
        r[key] = current
    end
    current.RichText = Config.RichText == true
    current.Text = value
    current.Font = font
    current.TextSize = size
    current.TextColor3 = currentTheme(s)[key]
end
local function build(s)
    local pad = Config.Padding
    local r = {}
    s.Refs = r
    s.Width = computeWidth(s)
    r.Slot = new("Frame", container, {
        Size = UDim2.new(0, s.Width, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = Config.NewestOnTop and -s.Sequence or s.Sequence,
    })
    r.Holder = new("Frame", r.Slot, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    r.Card = new("CanvasGroup", r.Holder, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    new("UICorner", r.Card, {CornerRadius = Config.CornerRadius})
    r.Stroke = new("UIStroke", r.Card, {Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    if s.Options.Shadow then
        r.Shadow = new("Frame", r.Holder, {
            Position = UDim2.fromOffset(0, 3),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.75,
            BorderSizePixel = 0,
            ZIndex = 1,
        })
        new("UICorner", r.Shadow, {CornerRadius = Config.CornerRadius})
        local function syncShadow()
            local size = r.Card.AbsoluteSize
            r.Shadow.Size = UDim2.fromOffset(size.X, size.Y)
        end
        syncShadow()
        table.insert(s.Connections, r.Card:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncShadow))
    end
    local body = new("Frame", r.Card, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    new("UIPadding", body, {
        PaddingTop = UDim.new(0, pad),
        PaddingBottom = UDim.new(0, pad),
        PaddingLeft = UDim.new(0, pad),
        PaddingRight = UDim.new(0, pad),
    })
    new("UIListLayout", body, {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
    })
    local row = new("Frame", body, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    })
    local closeBtnSize = closeSize()
    local leftOffset = s.IconKind and (Config.IconSize + 12) or 0
    local rightReserve = s.Options.CloseBtn and (closeBtnSize + 2) or 0
    if s.IconKind then
        new("UISizeConstraint", row, {MinSize = Vector2.new(0, Config.IconSize)})
        r.Bubble = new("Frame", row, {
            Size = UDim2.fromOffset(Config.IconSize, Config.IconSize),
            BorderSizePixel = 0,
            BackgroundTransparency = s.IconKind == "Custom" and 1 or 0.82,
            ZIndex = 4,
        })
        new("UICorner", r.Bubble, {CornerRadius = UDim.new(1, 0)})
        if s.IconKind == "Glyph" then
            r.Glyph = new("TextLabel", r.Bubble, {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = s.Icon,
                Font = Enum.Font.GothamBold,
                TextSize = 17,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 5,
            })
        else
            r.Icon = new("ImageLabel", r.Bubble, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = s.IconKind == "Custom" and UDim2.fromScale(1, 1) or UDim2.fromScale(0.58, 0.58),
                BackgroundTransparency = 1,
                Image = s.Icon,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 5,
            })
        end
    end
    r.Column = new("Frame", row, {
        Position = UDim2.fromOffset(leftOffset, 0),
        Size = UDim2.new(1, -(leftOffset + rightReserve), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    new("UIListLayout", r.Column, {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    })
    syncLabel(s, "Title", s.Title, Config.TitleFont, Config.TitleSize, 1)
    syncLabel(s, "Text", s.Text, Config.TextFont, Config.TextSize, 2)
    if s.Options.DisplayTime and s.Duration > 0 then
        r.Track = new("Frame", body, {
            Size = UDim2.new(1, 0, 0, Config.ProgressHeight),
            BackgroundTransparency = 0.88,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = 2,
        })
        new("UICorner", r.Track, {CornerRadius = UDim.new(1, 0)})
        r.Fill = new("Frame", r.Track, {
            Size = UDim2.fromScale(math.clamp(leftTime(s) / s.Duration, 0, 1), 1),
            BorderSizePixel = 0,
        })
        new("UICorner", r.Fill, {CornerRadius = UDim.new(1, 0)})
    end
    if s.Options.CloseBtn then
        local inset = 8 - (closeBtnSize - 24) / 2
        local close = new("ImageButton", r.Card, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -inset, 0, inset),
            Size = UDim2.fromOffset(closeBtnSize, closeBtnSize),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Image = "",
            ZIndex = 10,
        })
        r.CloseIcon = new("ImageLabel", close, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(Config.CloseIconSize, Config.CloseIconSize),
            BackgroundTransparency = 1,
            Image = asset(Config.CloseIcon) or "",
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 11,
        })
        table.insert(s.Connections, close.Activated:Connect(function() closeState(s, true) end))
        if UserInputService.MouseEnabled then
            table.insert(s.Connections, close.MouseEnter:Connect(function()
                TweenService:Create(r.CloseIcon, TweenInfo.new(0.12), {ImageColor3 = currentTheme(s).CloseButtonHover}):Play()
            end))
            table.insert(s.Connections, close.MouseLeave:Connect(function()
                TweenService:Create(r.CloseIcon, TweenInfo.new(0.12), {ImageColor3 = currentTheme(s).CloseButton}):Play()
            end))
        end
    end
    if s.Options.Clickable then
        r.Card.Active = true
        table.insert(s.Connections, r.Card.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                safe(s.OnClick, s.Controller)
            end
        end))
    end
    if s.Options.PauseOnHover and UserInputService.MouseEnabled then
        table.insert(s.Connections, r.Card.MouseEnter:Connect(function() pause(s, true) end))
        table.insert(s.Connections, r.Card.MouseLeave:Connect(function() pause(s, false) end))
    end
    applyTheme(s)
end
local function cleanup(s)
    stopRuntime(s)
    for _, c in ipairs(s.Connections) do c:Disconnect() end
    table.clear(s.Connections)
    if s.Refs and s.Refs.Slot then s.Refs.Slot:Destroy() end
    s.Refs = nil
end
local function rebuild(s)
    if not s or s.Status ~= "Active" or not s.Refs then return end
    s.Remaining, s.StartedAt = leftTime(s), nil
    cleanup(s)
    build(s)
    startRuntime(s)
end
local function refreshContent(s)
    local r = s.Refs
    if not r then return end
    syncLabel(s, "Title", s.Title, Config.TitleFont, Config.TitleSize, 1)
    syncLabel(s, "Text", s.Text, Config.TextFont, Config.TextSize, 2)
    relayoutState(s)
end
closeState = function(s, animated)
    if destroyed or not s or s.Status == "Closed" or s.Status == "Closing" then return false end
    closing[s] = true
    local wasActive = s.Status == "Active"
    s.Remaining, s.StartedAt, s.Status = leftTime(s), nil, "Closing"
    stopRuntime(s)
    remove(active, s.Controller)
    remove(queue, s.Controller)
    local finished = false
    local function finish()
        if finished or s.Status == "Closed" then return end
        finished = true
        cancelTask(s.CloseTask)
        s.CloseTask = nil
        closing[s] = nil
        cleanup(s)
        s.Status = "Closed"
        safe(s.OnClose, s.Controller)
        processQueue()
    end
    local refs = s.Refs
    local slide, _, scale, animEnabled = animFlags()
    if animated and animEnabled and wasActive and refs and refs.Holder then
        local time = Config.CloseAnimationTime
        local info = TweenInfo.new(time, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        local fadeTween = TweenService:Create(refs.Card, info, {GroupTransparency = 1})
        local main = fadeTween
        if slide then
            local off = hiddenOffset(s)
            main = TweenService:Create(refs.Holder, info, {Position = UDim2.fromOffset(off.X, off.Y)})
            fadeTween:Play()
        end
        if scale and refs.Scale then
            TweenService:Create(refs.Scale, info, {Scale = 0.88}):Play()
        end
        if refs.Shadow then
            TweenService:Create(refs.Shadow, TweenInfo.new(time), {BackgroundTransparency = 1}):Play()
        end
        main.Completed:Once(function()
            if finished then return end
            local slot = refs.Slot
            if not slot or not slot.Parent then
                finish()
                return
            end
            local height = slot.AbsoluteSize.Y
            local width = s.Width or Config.Width
            slot.AutomaticSize = Enum.AutomaticSize.None
            slot.Size = UDim2.new(0, width, 0, height)
            local collapse = TweenService:Create(slot, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, width, 0, 0)})
            collapse.Completed:Once(finish)
            collapse:Play()
        end)
        main:Play()
        s.CloseTask = task.delay(time + 0.6, finish)
    else
        finish()
    end
    processQueue()
    return true
end
local function activate(c)
    local s = c._state
    if not s or s.Status ~= "Queued" or not getContainer() then return false end
    s.Status = "Active"
    s.Remaining = s.Duration
    build(s)
    table.insert(active, c)
    local refs = s.Refs
    local slide, fade, scale, animEnabled = animFlags()
    if animEnabled then
        local info = TweenInfo.new(Config.AnimationTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if slide then
            local off = hiddenOffset(s)
            refs.Holder.Position = UDim2.fromOffset(off.X, off.Y)
            TweenService:Create(refs.Holder, info, {Position = UDim2.fromOffset(0, 0)}):Play()
        end
        if scale then
            refs.Scale = new("UIScale", refs.Holder, {Scale = 0.88})
            TweenService:Create(refs.Scale, info, {Scale = 1}):Play()
        end
        if fade then
            refs.Card.GroupTransparency = 1
            TweenService:Create(refs.Card, info, {GroupTransparency = 0}):Play()
            if refs.Shadow then
                refs.Shadow.BackgroundTransparency = 1
                TweenService:Create(refs.Shadow, info, {BackgroundTransparency = 0.75}):Play()
            end
        end
    end
    safe(s.OnOpen, c)
    startRuntime(s)
    return true
end
local function visibleCount()
    local count = 0
    if not container then return count end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") then
            count += 1
        end
    end
    return count
end
processQueue = function()
    if destroyed or #queue == 0 or not getContainer() then return end
    local limit = maxVisible()
    while visibleCount() < limit and #queue > 0 do
        local c = table.remove(queue, 1)
        if c and c._state and c._state.Status == "Queued" then activate(c) end
    end
end
runtime.ProcessQueue = processQueue
local function keyOf(map, title, desc)
    local key = get(map, {"duplicatekey"})
    if key ~= nil then return tostring(key) end
    local id = get(map, {"id"})
    if id ~= nil then return tostring(id) end
    return title .. "\0" .. desc
end
local function findDuplicate(key)
    for _, list in ipairs({active, queue}) do
        for _, c in ipairs(list) do
            local s = c._state
            if s and s.Status ~= "Closed" and s.Status ~= "Closing" and s.Key == key then return c end
        end
    end
end
local function createController(data, map)
    local title, desc = readText(data, map)
    local t = kind(get(map, {"type", "kind", "level"}))
    local iconInput = readIcon(data, map)
    local icon, iconKind = iconOf(iconInput, t)
    local duration = readDuration(data, map)
    local accent = get(map, {"accent", "accentcolor", "color"})
    local progressColor = get(map, {"progresscolor"})
    local onClick = get(map, {"onclick", "callback"})
    local clickable = get(map, {"clickable"})
    if clickable == nil then
        clickable = type(onClick) == "function" or Config.Clickable
    end
    runtime.Sequence += 1
    local s = {
        Data = data,
        Status = "Queued",
        Sequence = runtime.Sequence,
        Priority = tonumber(option(map, {"priority"}, Config.Priority)) or 0,
        Title = title,
        Text = desc,
        Type = t,
        IconInput = iconInput,
        Icon = icon,
        IconKind = iconKind,
        Accent = typeof(accent) == "Color3" and accent or nil,
        ProgressColor = typeof(progressColor) == "Color3" and progressColor or nil,
        OnClick = onClick,
        OnOpen = get(map, {"onopen"}),
        OnClose = get(map, {"onclose"}),
        Duration = duration,
        Remaining = duration,
        Paused = false,
        Width = Config.Width,
        Connections = {},
        Options = {
            DisplayTime = option(map, {"displaytime", "view", "progress"}, Config.DisplayTime) == true,
            CloseBtn = option(map, {"closebtn", "closebutton", "closable"}, Config.CloseBtn) == true,
            PauseOnHover = option(map, {"pauseonhover"}, Config.PauseOnHover) == true,
            Clickable = clickable == true,
            Shadow = option(map, {"shadow"}, Config.Shadow) ~= false,
        },
    }
    s.Key = keyOf(map, title, desc)
    local c = setmetatable({_state = s}, Controller)
    s.Controller = c
    return c
end
local function alive(s)
    return s and s.Status ~= "Closed" and s.Status ~= "Closing"
end
function Controller:Close() return closeState(self._state, true) end
function Controller:Destroy() return closeState(self._state, false) end
function Controller:Pause() pause(self._state, true) return self end
function Controller:Resume() pause(self._state, false) return self end
function Controller:SetTitle(value)
    local s = self._state
    if alive(s) then
        s.Title = clip(tostring(value or ""), Config.MaxTitleLength)
        s.Data.Title = s.Title
        refreshContent(s)
    end
    return self
end
function Controller:SetText(value)
    local s = self._state
    if alive(s) then
        s.Text = clip(tostring(value or ""), Config.MaxTextLength)
        s.Data.Text = s.Text
        refreshContent(s)
    end
    return self
end
function Controller:SetDuration(value)
    local s = self._state
    if alive(s) then
        local d = math.max(tonumber(value) or 0, 0)
        if d == math.huge then d = 0 end
        s.Duration, s.Remaining, s.StartedAt, s.Data.Duration = d, d, nil, d
        if s.Status == "Active" and s.Refs then
            local needsTrack = s.Options.DisplayTime and d > 0
            if needsTrack ~= (s.Refs.Track ~= nil) then
                rebuild(s)
            else
                startRuntime(s)
            end
        end
    end
    return self
end
function Controller:SetType(value)
    local s = self._state
    if alive(s) then
        s.Type = kind(value)
        s.Icon, s.IconKind = iconOf(s.IconInput, s.Type)
        rebuild(s)
    end
    return self
end
function Controller:SetIcon(value)
    local s = self._state
    if alive(s) then
        s.IconInput = value
        s.Icon, s.IconKind = iconOf(value, s.Type)
        rebuild(s)
    end
    return self
end
function Controller:GetStatus() return self._state and self._state.Status or "Closed" end
function Controller:GetRemainingTime() return self._state and leftTime(self._state) or 0 end
function Notify.Notify(...)
    if destroyed then return nil end
    local data = normalize(...)
    local map = indexOf(data)
    local title, desc = readText(data, map)
    local prevent = get(map, {"preventduplicates"})
    if prevent == nil then prevent = Config.PreventDuplicates end
    if prevent then
        local old = findDuplicate(keyOf(map, title, desc))
        if old then
            old:SetDuration(readDuration(data, map))
            return old
        end
    end
    local c = createController(data, map)
    if #queue >= Config.QueueLimit then
        if Config.QueueOverflow == "RejectNew" then
            c._state.Status = "Closed"
            return c
        end
        local oldest = table.remove(queue, 1)
        if oldest then oldest:Destroy() end
    end
    local inserted = false
    for i, q in ipairs(queue) do
        if c._state.Priority > q._state.Priority then
            table.insert(queue, i, c)
            inserted = true
            break
        end
    end
    if not inserted then table.insert(queue, c) end
    processQueue()
    return c
end
function Notify.SendNotification(...) return Notify.Notify(...) end
local function typed(t)
    return function(...)
        local data = normalize(...)
        if get(indexOf(data), {"type", "kind", "level"}) == nil then data.Type = t end
        return Notify.Notify(data)
    end
end
Notify.Info = typed("Info")
Notify.Success = typed("Success")
Notify.Warning = typed("Warning")
Notify.Error = typed("Error")
function Notify:GetActiveCount() return #active end
function Notify:GetQueueCount() return #queue end
function Notify:GetConfig() return copy(Config) end
function Notify:Configure(values)
    if type(values) ~= "table" then return self end
    for k, v in pairs(values) do
        local lower = tostring(k):lower()
        local configKey = configKeys[configAliases[lower] or lower]
        if configKey then
            if type(Config[configKey]) == "table" and type(v) == "table" then
                Config[configKey] = merge(Config[configKey], v)
            else
                Config[configKey] = v
            end
        end
    end
    if gui then updateContainer() end
    for _, c in ipairs(active) do rebuild(c._state) end
    processQueue()
    return self
end
function Notify:Clear()
    local all = {}
    for _, c in ipairs(active) do all[#all + 1] = c end
    for _, c in ipairs(queue) do all[#all + 1] = c end
    table.clear(active)
    table.clear(queue)
    for _, c in ipairs(all) do
        local s = c._state
        if s and s.Status ~= "Closed" then
            s.Status = "Closing"
            cleanup(s)
            s.Status = "Closed"
            safe(s.OnClose, c)
        end
    end
    return self
end
function Notify:ClearAll() return self:Clear() end
function Notify:Destroy()
    if destroyed then return self end
    destroyed = true
    self:Clear()
    for State in pairs(closing) do
        State.Status = "Closed"
        cancelTask(State.CloseTask)
        State.CloseTask = nil
        cleanup(State)
        closing[State] = nil
    end
    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end
    if workspaceConnection then
        workspaceConnection:Disconnect()
        workspaceConnection = nil
    end
    if inputConnection then
        inputConnection:Disconnect()
        if runtime.InputConnection == inputConnection then
            runtime.InputConnection = nil
        end
        inputConnection = nil
    end
    if runtime.ContainerConnection then
        pcall(function() runtime.ContainerConnection:Disconnect() end)
        runtime.ContainerConnection = nil
    end
    if runtime.ThemeConnection then
        pcall(function() runtime.ThemeConnection:Disconnect() end)
        runtime.ThemeConnection = nil
    end
    if runtime.LanguageConnection then
        pcall(function() runtime.LanguageConnection:Disconnect() end)
        runtime.LanguageConnection = nil
    end
    if runtime.ProcessQueue == processQueue then runtime.ProcessQueue = nil end
    if runtime.Owner == self then runtime.Owner = nil end

    if runtime.Gui == gui then
        runtime.Gui = nil
        runtime.Container = nil
        runtime.Layout = nil
    end

    if gui then gui:Destroy() end
    gui, container, layout = nil, nil, nil
    return self
end
if type(Hub) == "table" and type(Hub.OnThemeChanged) == "function" then
    if runtime.ThemeConnection then
        pcall(function() runtime.ThemeConnection:Disconnect() end)
        runtime.ThemeConnection = nil
    end

    runtime.ThemeConnection = Hub:OnThemeChanged(function(_, Palette)
        local Color = hubThemeColor(Palette)
        for _, ControllerObject in ipairs(active) do
            local State = ControllerObject._state
            if alive(State) and State.Refs and State.Refs.Fill and not State.ProgressColor then
                State.Refs.Fill.BackgroundColor3 = Color
            end
        end
    end)
end

if type(Hub) == "table" and type(Hub.OnLanguageChanged) == "function" and type(Hub.Translate) == "function" then
    if runtime.LanguageConnection then
        pcall(function() runtime.LanguageConnection:Disconnect() end)
        runtime.LanguageConnection = nil
    end

    runtime.LanguageConnection = Hub:OnLanguageChanged(function()
        for _, List in ipairs({active, queue}) do
            for _, ControllerObject in ipairs(List) do
                local State = ControllerObject._state

                if alive(State) then
                    local NewTitle = clip(tostring(Hub:Translate(State.Title)), Config.MaxTitleLength)
                    local NewText = clip(tostring(Hub:Translate(State.Text)), Config.MaxTextLength)

                    if NewTitle ~= State.Title or NewText ~= State.Text then
                        State.Title = NewTitle
                        State.Text = NewText

                        if State.Data then
                            State.Data.Title = NewTitle
                            State.Data.Text = NewText
                        end

                        if State.Refs then
                            refreshContent(State)
                        end
                    end
                end
            end
        end
    end)
end

runtime.Owner = Notify

setmetatable(Notify, {
    __call = function(_, ...)
        return Notify.Notify(...)
    end,
})
return Notify