--// Services
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

--// Context
local Context = ...
Context = type(Context) == "table" and Context or {}

local Hub = Context.Hub
if type(Hub) ~= "table" then
    return nil
end

--// Config
local Environment = Hub:GetEnvironment()
local UIParent = Environment:GetUIParent() or CoreGui
local Runtime = Hub:GetRuntime("Loader")
local Title = Hub:GetConfig("Title")
local SubTitle = Hub:GetConfig("SubTitle")
local LoaderConfig = Hub:GetConfig("Loader") or {}
local Theme = type(LoaderConfig.Theme) == "table" and LoaderConfig.Theme or {}

local function T(Key, Params)
    return Hub:Translate(Key, nil, Params)
end

local function GenerateName(...)
    return Hub:GenerateName(...)
end

Runtime.Name = Runtime.Name or (tostring(Title) .. "_Loader_" .. GenerateName(6))

local DEFAULTS = {
    Time = LoaderConfig.Time or 4.3,
    Steps = LoaderConfig.Steps or {},
    Music = LoaderConfig.Music or "rbxassetid://0",
    MusicVolume = LoaderConfig.MusicVolume or 0.5,
    MusicLooped = LoaderConfig.MusicLooped ~= false,
    Blur = LoaderConfig.Blur ~= false,
    BlurSize = LoaderConfig.BlurSize or 18,
    BlurInTime = LoaderConfig.BlurInTime or 0.35,
    BlurFadeTime = LoaderConfig.BlurFadeTime or 0.45,
    MusicFadeTime = LoaderConfig.MusicFadeTime or 1.2,
    GuiFadeTime = LoaderConfig.GuiFadeTime or 0.45,
    ScaleMin = LoaderConfig.ScaleMin or 0.55,
    Size = LoaderConfig.Size or Vector2.new(725, 380),
    Title = Title,
    Subtitle = SubTitle
}

--// Fade
local FADE_PROPS = {
    TextLabel = "TextTransparency",
    UIStroke  = "Transparency",
    Frame     = "BackgroundTransparency",
}

--// Font
local FONT_FAMILY = LoaderConfig.FontFamily or "rbxasset://fonts/families/GothamSSm.json"
local FontCache = {}

--// Helpers
local function New(Class, Props, Parent)
    local Obj = Instance.new(Class)

    for Prop, Value in next, Props do
        Obj[Prop] = Value
    end

    Obj.Parent = Parent
    return Obj
end

local function MakeFont(Weight)
    local Cached = FontCache[Weight]

    if not Cached then
        Cached = Font.new(FONT_FAMILY, Weight, Enum.FontStyle.Normal)
        FontCache[Weight] = Cached
    end

    return Cached
end

local function Merge(Config)
    Config = Config or {}

    local Final = {}

    for K, V in next, DEFAULTS do
        local Provided = Config[K]

        if Provided == nil then
            Final[K] = V
        else
            Final[K] = Provided
        end
    end

    return Final
end

local function Tween(Obj, Time, Props, Style, Direction)
    local T = TweenService:Create(
        Obj,
        TweenInfo.new(Time, Style or Enum.EasingStyle.Quad, Direction or Enum.EasingDirection.Out),
        Props
    )

    T:Play()
    return T
end

--// Cleanup
local function Cleanup()
    local State = Runtime

    if State.Conn then
        State.Conn:Disconnect()
        State.Conn = nil
    end

    for _, Key in ipairs({"Gui", "Blur", "Music"}) do
        local Obj = State[Key]

        if Obj then
            Obj:Destroy()
            State[Key] = nil
        end
    end
end

--// Loader
local Loader = {}
Loader.__index = Loader

function Loader.new()
    return setmetatable({}, Loader)
end

function Loader:SaveSettings(Config)
    self:Run(Config)
end

function Loader:Run(RawConfig)
    local Cfg = Merge(RawConfig)
    local State = Runtime
    local ActiveTheme = type(Cfg.Theme) == "table" and Cfg.Theme or Theme

    Cleanup()

    local ScreenGui = New("ScreenGui", {
        Name = State.Name,
        IgnoreGuiInset = true,
        ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    }, UIParent)

    State.Gui = ScreenGui

    local Blur
    if Cfg.Blur then
        Blur = New("BlurEffect", {
            Name = tostring(Title) .. "_LoaderBlur_" .. GenerateName(6),
            Size = 0,
        }, Lighting)

        State.Blur = Blur
        Tween(Blur, Cfg.BlurInTime, {Size = Cfg.BlurSize})
    end

    local Window = New("Frame", {
        Name = tostring(Title) .. "_LoaderWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Cfg.Size.X, Cfg.Size.Y),
        BackgroundColor3 = ActiveTheme.Window or Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = LoaderConfig.WindowTransparency or 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, ScreenGui)

    New("UICorner", {CornerRadius = LoaderConfig.CornerRadius or UDim.new(0, 28)}, Window)

    New("UIGradient", {
        Rotation = 135,
        Color = ActiveTheme.Gradient or ColorSequence.new(Color3.fromRGB(12, 12, 12), Color3.fromRGB(0, 0, 0)),
    }, Window)

    New("UIStroke", {
        Transparency = LoaderConfig.StrokeTransparency or 0.25,
        Color = ActiveTheme.Stroke or Color3.fromRGB(66, 66, 66),
    }, Window)

    local UIScale = New("UIScale", {}, Window)
    local Camera = workspace.CurrentCamera

    if Camera then
        local function UpdateScale()
            local Viewport = Camera.ViewportSize
            UIScale.Scale = math.clamp(math.min(Viewport.X / Cfg.Size.X, Viewport.Y / Cfg.Size.Y, 1), Cfg.ScaleMin, 1)
        end

        UpdateScale()
        State.Conn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
    end

    local TopHighlight = New("Frame", {
        Name = "TopHighlight",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.7, 0, 0, 2),
        Position = UDim2.fromScale(0.5, 0),
        BackgroundColor3 = ActiveTheme.Highlight or Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = LoaderConfig.HighlightTransparency or 0.15,
        BorderSizePixel = 0,
    }, Window)

    New("UICorner", {CornerRadius = UDim.new(1, 0)}, TopHighlight)

    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, TopHighlight)

    New("TextLabel", {
        Name = "Title",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(500, 60),
        Position = UDim2.fromScale(0.49448, 0.04368),
        BackgroundTransparency = 1,
        Text = Cfg.Title,
        TextSize = 48,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = ActiveTheme.Title or Color3.fromRGB(255, 255, 255),
    }, Window)

    New("TextLabel", {
        Name = "Subtitle",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(400, 28),
        Position = UDim2.fromScale(0.49448, 0.17),
        BackgroundTransparency = 1,
        Text = Cfg.Subtitle,
        TextSize = 17,
        FontFace = MakeFont(Enum.FontWeight.Medium),
        TextColor3 = ActiveTheme.Subtitle or Color3.fromRGB(146, 146, 146),
    }, Window)

    local Status = New("TextLabel", {
        Name = "Status",
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.fromOffset(350, 25),
        Position = UDim2.new(0, 88, 0.75632, 0),
        BackgroundTransparency = 1,
        Text = Cfg.Steps[1] and Cfg.Steps[1][1] or "",
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = MakeFont(Enum.FontWeight.Regular),
        TextColor3 = ActiveTheme.Status or Color3.fromRGB(176, 176, 176),
    }, Window)

    local Percentage = New("TextLabel", {
        Name = "Percentage",
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.fromOffset(50, 25),
        Position = UDim2.new(1, -88, 0.75632, 0),
        BackgroundTransparency = 1,
        Text = "0%",
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = ActiveTheme.Percentage or Color3.fromRGB(255, 255, 255),
    }, Window)

    local ProgressBackground = New("Frame", {
        Name = "ProgressBackground",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(550, 8),
        Position = UDim2.fromScale(0.5, 0.82),
        BackgroundColor3 = ActiveTheme.ProgressBackground or Color3.fromRGB(36, 36, 36),
        BorderSizePixel = 0,
    }, Window)

    New("UICorner", {CornerRadius = UDim.new(1, 0)}, ProgressBackground)

    local Progress = New("Frame", {
        Name = "Progress",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = ActiveTheme.Highlight or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, ProgressBackground)

    New("UICorner", {CornerRadius = UDim.new(1, 0)}, Progress)

    New("UIGradient", {
        Color = ActiveTheme.Progress or ColorSequence.new(Color3.fromRGB(191, 191, 191), Color3.fromRGB(255, 255, 255)),
    }, Progress)

    New("TextLabel", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0.5, 1),
        Size = UDim2.fromOffset(Cfg.Size.X, 20),
        Position = UDim2.new(0.5, 0, 1, -18),
        BackgroundTransparency = 1,
        Text = LoaderConfig.Footer or T("Loader.Footer"),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = ActiveTheme.Footer or Color3.fromRGB(81, 81, 81),
    }, Window)

    local Music
    if Cfg.Music and Cfg.Music ~= "" and Cfg.Music ~= "rbxassetid://0" then
        Music = New("Sound", {
            Name = tostring(Title) .. "_LoaderMusic_" .. GenerateName(6),
            SoundId = Cfg.Music,
            Volume = Cfg.MusicVolume,
            Looped = Cfg.MusicLooped,
        }, UIParent)

        State.Music = Music
        Music:Play()
    end

    local LastShown = -1

    local function UpdateLoading(Percent)
        Percent = math.clamp(Percent, 0, 100)
        Progress.Size = UDim2.fromScale(Percent / 100, 1)

        local Shown = math.floor(Percent)
        if Shown ~= LastShown then
            LastShown = Shown
            Percentage.Text = Shown .. "%"
        end
    end

    task.spawn(function()
        local Previous = 0

        for _, Step in ipairs(Cfg.Steps) do
            local Message, Target = Step[1], Step[2]

            Status.Text = Message

            local Difference = Target - Previous
            local StepTime = Cfg.Time * (Difference / 100)

            if StepTime <= 0 then
                UpdateLoading(Target)
            else
                local Start = os.clock()
                local Alpha

                repeat
                    if not ScreenGui.Parent then return end

                    Alpha = math.min((os.clock() - Start) / StepTime, 1)
                    UpdateLoading(Previous + Difference * Alpha)
                    task.wait()
                until Alpha >= 1
            end

            Previous = Target
        end

        if not ScreenGui.Parent then return end

        UpdateLoading(100)
        Status.Text = T("Loader.Finalizing")
        task.wait(0.3)

        if Blur then
            Tween(Blur, Cfg.BlurFadeTime, {Size = 0}).Completed:Once(function()
                if State.Blur == Blur then
                    State.Blur = nil
                end

                Blur:Destroy()
            end)
        end

        if Music then
            Tween(Music, Cfg.MusicFadeTime, {Volume = 0}).Completed:Once(function()
                if State.Music == Music then
                    State.Music = nil
                end

                Music:Stop()
                Music:Destroy()
            end)
        end

        local FadeInfo = TweenInfo.new(Cfg.GuiFadeTime)
        local CloseTween = Tween(Window, Cfg.GuiFadeTime, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

        for _, Obj in ipairs(Window:GetDescendants()) do
            local Prop = FADE_PROPS[Obj.ClassName]

            if Prop then
                TweenService:Create(Obj, FadeInfo, {[Prop] = 1}):Play()
            end
        end

        CloseTween.Completed:Wait()

        if State.Gui == ScreenGui then
            if State.Conn then
                State.Conn:Disconnect()
                State.Conn = nil
            end

            State.Gui = nil
        end

        ScreenGui:Destroy()
    end)
end

return Loader.new()
