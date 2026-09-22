local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local Lighting      = game:GetService("Lighting")
local CoreGui       = game:GetService("CoreGui")

local DEFAULT_STEPS = {
    {"Connecting to SpecterX...", 15},
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
    Title         = "SpecterX",
    Subtitle      = "By Specter",
}

local function New(Class, Props, Parent)
    local Obj = Instance.new(Class)
    for Prop, Value in pairs(Props) do
        Obj[Prop] = Value
    end
    Obj.Parent = Parent
    return Obj
end

local function MakeFont(Weight)
    return Font.new("rbxasset://fonts/families/GothamSSm.json", Weight, Enum.FontStyle.Normal)
end

local function CopySteps(Steps)
    local Copy = {}
    for i, Step in ipairs(Steps) do
        Copy[i] = {Step[1], Step[2]}
    end
    return Copy
end

local function Merge(Config)
    Config = Config or {}
    local Final = {}
    for K, V in pairs(DEFAULTS) do
        local Provided = Config[K]
        Final[K] = (Provided ~= nil) and Provided or V
    end

    Final.Steps = CopySteps(Final.Steps)
    return Final
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
    local Cfg = Merge(RawConfig)

    local Old = CoreGui:FindFirstChild("SpecterXLoading")
    if Old then Old:Destroy() end

    local OldBlur = Lighting:FindFirstChild("SpecterXLoadingBlur")
    if OldBlur then OldBlur:Destroy() end

    local OldMusic = CoreGui:FindFirstChild("SpecterXLoadingMusic")
    if OldMusic then OldMusic:Destroy() end

    local ScreenGui = New("ScreenGui", {
        Name = "SpecterXLoading",
        IgnoreGuiInset = true,
        ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    }, CoreGui)

    local Blur
    if Cfg.Blur then
        Blur = New("BlurEffect", { Name = "SpecterXLoadingBlur", Size = 0 }, Lighting)
        TweenService:Create(Blur, TweenInfo.new(Cfg.BlurInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Cfg.BlurSize }):Play()
    end

    local Window = New("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 725, 0, 380),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, ScreenGui)

    New("UICorner", { CornerRadius = UDim.new(0, 28) }, Window)
    New("UIGradient", {
        Rotation = 135,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 12, 12)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        }),
    }, Window)

    New("UIStroke", { Transparency = 0.25, Color = Color3.fromRGB(66, 66, 66) }, Window)

    local UIScale = New("UIScale", {}, Window)
    local Camera = workspace.CurrentCamera

    local function UpdateScale()
        if not Camera then return end
        local Viewport = Camera.ViewportSize
        local Scale = math.clamp(math.min(Viewport.X / 725, Viewport.Y / 380, 1), 0.55, 1)
        UIScale.Scale = Scale
    end

    UpdateScale()
    if Camera then
        Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
    end

    local TopHighlight = New("Frame", {
        Name = "TopHighlight",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.7, 0, 0, 2),
        Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, Window)

    New("UICorner", { CornerRadius = UDim.new(1, 0) }, TopHighlight)

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
        Size = UDim2.new(0, 500, 0, 60),
        Position = UDim2.new(0.49448, 0, 0.04368, 0),
        BackgroundTransparency = 1,
        Text = Cfg.Title,
        TextSize = 48,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = Color3.fromRGB(255, 255, 255),
    }, Window)

    New("TextLabel", {
        Name = "Subtitle",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 400, 0, 28),
        Position = UDim2.new(0.49448, 0, 0.17, 0),
        BackgroundTransparency = 1,
        Text = Cfg.Subtitle,
        TextSize = 17,
        FontFace = MakeFont(Enum.FontWeight.Medium),
        TextColor3 = Color3.fromRGB(146, 146, 146),
    }, Window)

    local Status = New("TextLabel", {
        Name = "Status",
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 350, 0, 25),
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
        Size = UDim2.new(0, 50, 0, 25),
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
        Size = UDim2.new(0, 550, 0, 8),
        Position = UDim2.new(0.5, 0, 0.82, 0),
        BackgroundColor3 = Color3.fromRGB(36, 36, 36),
        BorderSizePixel = 0,
    }, Window)

    New("UICorner", { CornerRadius = UDim.new(1, 0) }, ProgressBackground)

    local Progress = New("Frame", {
        Name = "Progress",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
    }, ProgressBackground)

    New("UICorner", { CornerRadius = UDim.new(1, 0) }, Progress)

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
        Size = UDim2.new(0, 725, 0, 20),
        Position = UDim2.new(0.5, 0, 1, -18),
        BackgroundTransparency = 1,
        Text = "SPECTERX  •  " .. os.date("%Y") .. "  |  TODOS OS DIREITOS RESERVADOS",
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = Color3.fromRGB(81, 81, 81),
    }, Window)

    local Music
    if Cfg.Music and Cfg.Music ~= "rbxassetid://0" then
        Music = New("Sound", {
            Name = "SpecterXLoadingMusic",
            SoundId = Cfg.Music,
            Volume = Cfg.MusicVolume,
            Looped = Cfg.MusicLooped,
        }, CoreGui)
        Music:Play()
    end

    local function UpdateLoading(Percent)
        Percent = math.clamp(Percent, 0, 100)
        Percentage.Text = math.floor(Percent) .. "%"
        TweenService:Create(Progress, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {
            Size = UDim2.new(Percent / 100, 0, 1, 0),
        }):Play()
    end

    task.spawn(function()
        local Previous = 0

        for _, Step in ipairs(Cfg.Steps) do
            local Message, Target = Step[1], Step[2]
            Status.Text = Message

            local Difference = Target - Previous
            local StepTime = Cfg.Time * (Difference / 100)
            local Start = os.clock()

            if StepTime <= 0 then
                UpdateLoading(Target)
            else
                local Alpha = 0
                repeat
                    Alpha = math.clamp((os.clock() - Start) / StepTime, 0, 1)
                    UpdateLoading(Previous + Difference * Alpha)
                    task.wait()
                until Alpha >= 1
            end

            Previous = Target
        end

        UpdateLoading(100)
        Status.Text = "Finalizing..."
        task.wait(0.3)

        if Blur then
            local Tween = TweenService:Create(Blur, TweenInfo.new(Cfg.BlurFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = 0 })
            Tween:Play()
            Tween.Completed:Connect(function() Blur:Destroy() end)
        end

        if Music then
            local Tween = TweenService:Create(Music, TweenInfo.new(Cfg.MusicFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
            Tween:Play()
            Tween.Completed:Connect(function() Music:Stop() Music:Destroy() end)
        end

        local CloseTween = TweenService:Create(Window, TweenInfo.new(Cfg.GuiFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
        CloseTween:Play()

        for _, Obj in ipairs(Window:GetDescendants()) do
            if Obj:IsA("TextLabel") then
                TweenService:Create(Obj, TweenInfo.new(Cfg.GuiFadeTime), { TextTransparency = 1 }):Play()
            elseif Obj:IsA("UIStroke") then
                TweenService:Create(Obj, TweenInfo.new(Cfg.GuiFadeTime), { Transparency = 1 }):Play()
            elseif Obj:IsA("Frame") then
                TweenService:Create(Obj, TweenInfo.new(Cfg.GuiFadeTime), { BackgroundTransparency = 1 }):Play()
            end
        end

        CloseTween.Completed:Wait()
        ScreenGui:Destroy()
    end)
end

local Config = ...
if typeof(Config) == "table" then
    Loader.new():Run(Config)
    return
end

return Loader.new()
