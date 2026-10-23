--// Services

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

--// Constants

local FADE_PROPS = {
    TextLabel = "TextTransparency",
    UIStroke = "Transparency",
    Frame = "BackgroundTransparency",
}

local FONT_FAMILY = "rbxasset://fonts/families/BuilderSans.json"
local FontCache = {}
local RuntimeHub

--// Helpers

local function New(Class, Props, Parent)
    local Obj = RuntimeHub:CreateInstance(Class, Props)
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


local function Tween(Obj, Time, Props, Style, Direction)
    local Animation = TweenService:Create(
        Obj,
        TweenInfo.new(Time, Style or Enum.EasingStyle.Quad, Direction or Enum.EasingDirection.Out),
        Props
    )

    Animation:Play()
    return Animation
end

local function DestroyObject(Object)
    if Object then
        pcall(Object.Destroy, Object)
    end
end

local function CleanupState(State)
    if type(State) ~= "table" then
        return
    end

    if State.Conn then
        State.Conn:Disconnect()
        State.Conn = nil
    end

    if State.CurrentCameraConnection then
        State.CurrentCameraConnection:Disconnect()
        State.CurrentCameraConnection = nil
    end

    for _, Key in ipairs({"Gui", "Blur", "Music"}) do
        local Object = State[Key]

        if Object then
            DestroyObject(Object)
            State[Key] = nil
        end
    end

    State.Running = false
end

--// Loader

local Loader = {}
Loader.__index = Loader

function Loader.new()
    return setmetatable({}, Loader)
end

function Loader:IsRunning()
    return self._running == true
end

function Loader:_Complete()
    if self._completed then
        return
    end

    self._completed = true
    self._running = false

    local State = self._state
    if State then
        State.Running = false
    end

    local Done = self._done
    self._done = nil

    if Done then
        Done:Fire()
        task.defer(Done.Destroy, Done)
    end
end

function Loader:_TryClose()
    if not self._running
        or self._closing
        or not self._animationDone
        or not self._finishRequested
    then
        return
    end

    self._closing = true

    task.spawn(function()
        local State = self._state
        local ScreenGui = self._screenGui
        local Window = self._window
        local Blur = self._blur
        local Music = self._music
        local Cfg = self._config

        if not ScreenGui or not ScreenGui.Parent then
            self:_Complete()
            return
        end

        if Blur and Blur.Parent then
            Tween(Blur, Cfg.BlurFadeTime, {Size = 0}).Completed:Once(function()
                if State and State.Blur == Blur then
                    State.Blur = nil
                end

                DestroyObject(Blur)
            end)
        end

        if Music and Music.Parent then
            Tween(Music, Cfg.MusicFadeTime, {Volume = 0}).Completed:Once(function()
                if State and State.Music == Music then
                    State.Music = nil
                end

                Music:Stop()
                DestroyObject(Music)
            end)
        end

        local FadeInfo = TweenInfo.new(Cfg.GuiFadeTime)
        local CloseTween = Tween(
            Window,
            Cfg.GuiFadeTime,
            {BackgroundTransparency = 1},
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In
        )

        for _, Obj in ipairs(Window:GetDescendants()) do
            local Prop = FADE_PROPS[Obj.ClassName]

            if Prop then
                TweenService:Create(Obj, FadeInfo, {[Prop] = 1}):Play()
            end
        end

        CloseTween.Completed:Wait()

        if State and State.Gui == ScreenGui then
            if State.Conn then
                State.Conn:Disconnect()
                State.Conn = nil
            end

            if State.CurrentCameraConnection then
                State.CurrentCameraConnection:Disconnect()
                State.CurrentCameraConnection = nil
            end

            State.Gui = nil
        end

        DestroyObject(ScreenGui)
        self:_Complete()
    end)
end

function Loader:Run(Context, RawConfig)
    if type(Context) ~= "table" or type(Context.Hub) ~= "table" then
        return false, "Loader context is invalid."
    end

    if self._running then
        self:Destroy()
    end

    local Hub = Context.Hub
    RuntimeHub = Hub
    local Genv = Context.Genv or Hub:GetGenv()
    local LibraryConfig = assert(Hub:GetConfig("Library"), "Config.Library is required.")
    local FallbackViewportSize = assert(LibraryConfig.FallbackViewportSize,
        "Config.Library.FallbackViewportSize is required.")
    local FallbackViewport = Vector2.new(table.unpack(FallbackViewportSize))

    local Title = tostring(Context.Title or Hub:GetConfig("Title") or "Hub")
    local SubTitle = tostring(Context.SubTitle or Hub:GetConfig("SubTitle") or "")
    local Palette = type(Hub.GetThemeData) == "function" and Hub:GetThemeData() or nil
    Palette = type(Palette) == "table" and Palette or {}

    assert(next(Palette), "Config.Theme must name a configured theme.")
    local HubGradient = Palette["Color Hub 1"]
    local HubColor = Palette["Color Hub 2"]
    local StrokeColor = Palette["Color Stroke"]
    local AccentColor = Palette["Color Theme"]
    local TextColor = Palette["Color Text"]
    local DarkTextColor = Palette["Color Dark Text"]

    local function Translate(Text, Values)
        local Result = type(Hub.Translate) == "function" and Hub:Translate(Text) or Text
        if type(Values) == "table" and type(Hub.Format) == "function" then
            Result = Hub:Format(Result, Values)
        end
        return Result
    end

    local Defaults = assert(Hub:GetConfig("Loader"), "Config.Loader is required.")
    local Cfg = Hub:MergeTables(Defaults, type(RawConfig) == "table" and RawConfig or {})
    Cfg.Title = Translate(Cfg.Title or Title, {Title = Title})
    Cfg.Subtitle = Translate(Cfg.Subtitle or SubTitle, {Title = Title})

    for _, Step in ipairs(Cfg.Steps) do
        Step[1] = Translate(Step[1], {Title = Title})
    end

    Genv.Loading = Genv.Loading or {}
    local State = Genv.Loading

    CleanupState(State)

    State.Running = true

    self._state = State
    self._config = Cfg
    self._running = true
    self._completed = false
    self._closing = false
    self._animationDone = false
    self._finishRequested = false
    self._done = Hub:CreateInstance("BindableEvent")

    local ScreenGui = New("ScreenGui", {
        IgnoreGuiInset = true,
        ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
    }, CoreGui)

    State.Name = ScreenGui.Name
    State.Gui = ScreenGui
    self._screenGui = ScreenGui

    local Blur
    if Cfg.Blur then
        Blur = New("BlurEffect", {
            Size = 0,
        }, Lighting)

        State.Blur = Blur
        self._blur = Blur
        Tween(Blur, Cfg.BlurInTime, {Size = Cfg.BlurSize})
    end

    local Window = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(725, 380),
        BackgroundColor3 = HubColor,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, ScreenGui)

    self._window = Window

    New("UICorner", {CornerRadius = UDim.new(0, 28)}, Window)

    New("UIGradient", {
        Rotation = 135,
        Color = HubGradient,
    }, Window)

    New("UIStroke", {
        Transparency = 0.25,
        Color = StrokeColor,
    }, Window)

    local UIScale = New("UIScale", {}, Window)

    local function UpdateScale()
        local Camera = workspace.CurrentCamera
        local Viewport = Camera and Camera.ViewportSize or FallbackViewport
        UIScale.Scale = math.clamp(math.min(Viewport.X / 725, Viewport.Y / 380, 1), 0.55, 1)
    end

    local function BindCamera()
        if State.Conn then
            State.Conn:Disconnect()
            State.Conn = nil
        end

        local Camera = workspace.CurrentCamera
        if Camera then
            State.Conn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
        end

        UpdateScale()
    end

    State.CurrentCameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindCamera)
    BindCamera()

    local TopHighlight = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0.7, 0, 0, 2),
        Position = UDim2.fromScale(0.5, 0),
        BackgroundColor3 = AccentColor,
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
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(500, 60),
        Position = UDim2.fromScale(0.49448, 0.04368),
        BackgroundTransparency = 1,
        Text = Cfg.Title,
        TextSize = 48,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = TextColor,
    }, Window)

    New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.fromOffset(400, 28),
        Position = UDim2.fromScale(0.49448, 0.17),
        BackgroundTransparency = 1,
        Text = Cfg.Subtitle,
        TextSize = 17,
        FontFace = MakeFont(Enum.FontWeight.Medium),
        TextColor3 = DarkTextColor,
    }, Window)

    local Status = New("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.fromOffset(350, 25),
        Position = UDim2.new(0, 88, 0.75632, 0),
        BackgroundTransparency = 1,
        Text = Cfg.Steps[1] and Cfg.Steps[1][1] or "",
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = MakeFont(Enum.FontWeight.Regular),
        TextColor3 = DarkTextColor,
    }, Window)

    local Percentage = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.fromOffset(50, 25),
        Position = UDim2.new(1, -88, 0.75632, 0),
        BackgroundTransparency = 1,
        Text = "0%",
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = TextColor,
    }, Window)

    local ProgressBackground = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(550, 8),
        Position = UDim2.fromScale(0.5, 0.82),
        BackgroundColor3 = StrokeColor,
        BorderSizePixel = 0,
    }, Window)

    New("UICorner", {CornerRadius = UDim.new(1, 0)}, ProgressBackground)

    local Progress = New("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = AccentColor,
        BorderSizePixel = 0,
    }, ProgressBackground)

    New("UICorner", {CornerRadius = UDim.new(1, 0)}, Progress)

    New("UIGradient", {
        Color = ColorSequence.new(AccentColor),
    }, Progress)

    New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        Size = UDim2.fromOffset(725, 20),
        Position = UDim2.new(0.5, 0, 1, -18),
        BackgroundTransparency = 1,
        Text = Translate("LOADING SYSTEM"),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        FontFace = MakeFont(Enum.FontWeight.Bold),
        TextColor3 = DarkTextColor,
    }, Window)

    local Music
    if Cfg.Music and Cfg.Music ~= "" and Cfg.Music ~= "rbxassetid://0" then
        Music = New("Sound", {
            SoundId = Cfg.Music,
            Volume = Cfg.MusicVolume,
            Looped = Cfg.MusicLooped,
        }, CoreGui)

        State.Music = Music
        self._music = Music
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
            if not self._running or not ScreenGui.Parent then
                return
            end

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
                    if not self._running or not ScreenGui.Parent then
                        return
                    end

                    Alpha = math.min((os.clock() - Start) / StepTime, 1)
                    UpdateLoading(Previous + Difference * Alpha)
                    task.wait()
                until Alpha >= 1
            end

            Previous = Target
        end

        if not self._running or not ScreenGui.Parent then
            return
        end

        UpdateLoading(100)
        self._animationDone = true
        self:_TryClose()
    end)

    return true
end

function Loader:Finish()
    if not self._running then
        return self
    end

    self._finishRequested = true
    self:_TryClose()
    return self
end

function Loader:Wait()
    if not self._running then
        return true
    end

    local Done = self._done
    if Done then
        Done.Event:Wait()
    end

    return true
end

function Loader:Destroy()
    if not self._running and not self._state then
        return
    end

    self._running = false
    CleanupState(self._state)
    self:_Complete()
end

--// Return

return Loader.new()
