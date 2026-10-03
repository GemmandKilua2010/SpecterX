local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local CoreGui      = game:GetService("CoreGui")

local Hub = loadstring(game:HttpGet("https://raw.githubusercontent.com/GemmandKilua2010/SpecterX/refs/heads/main/Core/Modules/Hub/script.lua"))()
local Genv = Hub:GetGenv()

local function GenerateName(...)
    return Hub:GenerateName(...)
end

Genv.Loading = Genv.Loading or {
    Name = GenerateName(12),
}

local Title    = Hub:GetConfig("Title")
local SubTitle = Hub:GetConfig("SubTitle")

local DEFAULT_STEPS = {
    {("Connecting to %s..."):format(Title), 15},
    {"Loading modules...", 30},
    {"Initializing components...", 50},
    {"Preparing interface...", 70},
    {"Optimizing system...", 85},
    {"Finalizing...", 100},
}

local DEFAULTS = {
    Time          = 4.3,
    Steps         = DEFAULT_STEPS,
    Music         = "rbxassetid://0",
    MusicVolume   = 0.5,
    MusicLooped   = true,
    Blur          = true,
    BlurSize      = 18,
    BlurInTime    = 0.35,
    BlurFadeTime  = 0.45,
    MusicFadeTime = 1.2,
    GuiFadeTime   = 0.45,
    Title         = Title,
    Subtitle      = SubTitle,
}

local FADE_PROPS = {
    TextLabel = "TextTransparency",
    UIStroke  = "Transparency",
    Frame     = "BackgroundTransparency",
}

local FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local FontCache = {}

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

local function Cleanup()
    local State = Genv.Loading

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

local Loader = {}
Loader.__index = Loader

function Loader.new()
    return setmetatable({}, Loader)
end

function Loader:SaveSettings(Config)
    self:Run(Config)
end

function Loader:Run(RawConfig)
    local Cfg   = Merge(RawConfig)
    local State = Genv.Loading

    Cleanup()

    local ScreenGui = New("ScreenGui", {
        Name = State.Name,
        IgnoreGuiInset = true,
        ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    }, CoreGui)

    State.Gui = ScreenGui

    local Blur
    if Cfg.Blur then
        Blur = New("BlurEffect", {
            Name = GenerateName(12),
            Size = 0,
        }, Lighting)

        State.Blur = Blur
        Tween(Blur, Cfg.BlurInTime, {Size = Cfg.BlurSize})
    end

    local Window = New("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(725, 380),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, ScreenGui)

    New("UICorner", {CornerRadius = UDim.new(0, 28)}, Window)

    New("UIGradient", {
        Rotation = 135,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 12, 12)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        }),
    }, Window)

    New("UIStroke", {
        Transparency = 0.25,
        Color = Color3.fromRGB(66, 66, 66),
    }, Window)

    local UIScale = New("UIScale", {}, Window)
    local Camera = workspace.CurrentCamera

    if Camera then
        local function UpdateScale()
            local Viewport = Camera.ViewportSize
            UIScale.Scale = math.clamp(math.min(Viewport.X / 725, Viewport.Y / 380, 1), 0.55, 1)
        end

        UpdateScale()
        State.Conn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
    end

    local TopHighlight = New("Frame", {
        Name = "TopHighlight",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.7, 0, 0, 2),
        Position = UDim2.fromScale(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.15,
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
        TextColor3 = Color3.fromRGB(255, 255, 255),
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
        TextColor3 = Color3.fromRGB(146, 146, 146),
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
        TextColor3 = Color3.fromRGB(176, 176, 176),
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
        TextColor3 = Color3.fromRGB(255, 255, 255),
    }, Window)

    local ProgressBackground = New("Frame", {
        Name = "ProgressBackground",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(550, 8),
        Position = UDim2.fromScale(0.5, 0.82),
        BackgroundColor3 = Color3.fromRGB(36, 36, 36),
        BorderSizePixel = 0,
    }, Window)

    New("UICorner", {CornerRadius = UDim.new(1, 0)}, ProgressBackground)

    local Progress = New("Frame", {
        Name = "Progress",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, ProgressBackground)

    New("UICorner", {CornerRadius = UDim.new(1, 0)}, Progress)

    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(191, 191, 191)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(191, 191, 191)),
        }),
    }, Progress)

    New("TextLabel", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0.5, 1),
        Size = UDim2.fromOffset(725, 20),
        Position = UDim2.new(0.5, 0, 1, -18),
        BackgroundTransparency = 1,
        Text = "LOADING SYSTEM",
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = Color3.fromRGB(81, 81, 81),
    }, Window)

    local Music
    if Cfg.Music and Cfg.Music ~= "" and Cfg.Music ~= "rbxassetid://0" then
        Music = New("Sound", {
            Name = GenerateName(12),
            SoundId = Cfg.Music,
            Volume = Cfg.MusicVolume,
            Looped = Cfg.MusicLooped,
        }, CoreGui)

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
                    -- abortado: Run() foi chamado de novo e destruiu esta GUI
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
        Status.Text = "Finalizing..."
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

local Config = ...
if typeof(Config) == "table" then
    Loader.new():Run(Config)
    return
end

return Loader.new()