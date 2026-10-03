local Config = {}

--// Hub
Config.Title = "SpecterX"
Config.Author = "Specter"
Config.SubTitle = "By {Author}"
Config.Image = 121730327067473

--// Repository
Config.Repository = {
    Owner = "GemmandKilua2010",
    Name = "SpecterX",
    Branch = "main"
}

Config.Paths = {
    Hub = "Core/Modules/Hub/script.lua",
    Loader = "Core/Modules/Loader/script.lua",
    Library = "Core/Library/lib.lua",
    Notification = "Core/Modules/Hub/Notification/script.lua",
    Translation = "Core/translation.lua",
    TranslationModule = "Core/Modules/Hub/Translation/script.lua",
    Games = "Games/games.lua"
}

--// Network
Config.Network = {
    Retries = 3,
    RetryDelay = 0.5,
    NoCache = false
}

--// Language
Config.Language = {
    Default = "US",
    AutoDetect = true,
    Countries = {
        BR = "BR",
        US = "US",
        ES = "ES"
    }
}

--// Icon
Config.Icon = {
    Image = Config.Image,
    Transparency = 0,
    Corner = 5
}

--// Discord
Config.DiscordInvite = {
    Name = Config.Title,
    Desc = "Join our Discord and keep up with all {Title} updates.",
    Image = Config.Image,
    Invite = "Coming soon"
}

--// Loader
Config.Loader = {
    Enabled = false,
    Time = 4.3,
    Steps = {
        {"Loader.Connecting", 15},
        {"Loader.LoadingModules", 30},
        {"Loader.InitializingComponents", 50},
        {"Loader.PreparingInterface", 70},
        {"Loader.OptimizingSystem", 85},
        {"Loader.Finalizing", 100}
    },
    Footer = "Loader.Footer",
    Music = "rbxassetid://0",
    MusicVolume = 0.5,
    MusicLooped = true,
    Blur = true,
    BlurSize = 18,
    BlurInTime = 0.35,
    BlurFadeTime = 0.45,
    MusicFadeTime = 1.2,
    GuiFadeTime = 0.45,
    ScaleMin = 0.55,
    Size = Vector2.new(725, 380),
    FontFamily = "rbxasset://fonts/families/GothamSSm.json",
    CornerRadius = UDim.new(0, 28),
    WindowTransparency = 0.02,
    StrokeTransparency = 0.25,
    HighlightTransparency = 0.15,
    Theme = {
        Window = Color3.fromRGB(255, 255, 255),
        Gradient = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 12, 12)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
        }),
        Stroke = Color3.fromRGB(66, 66, 66),
        Highlight = Color3.fromRGB(255, 255, 255),
        Title = Color3.fromRGB(255, 255, 255),
        Subtitle = Color3.fromRGB(146, 146, 146),
        Status = Color3.fromRGB(176, 176, 176),
        Percentage = Color3.fromRGB(255, 255, 255),
        ProgressBackground = Color3.fromRGB(36, 36, 36),
        Progress = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(191, 191, 191)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(191, 191, 191))
        }),
        Footer = Color3.fromRGB(81, 81, 81)
    }
}

--// Library
Config.Library = {
    Theme = "MetalRed",
    UISize = {534, 281},
    TabSize = 160,
    Keybind = Enum.KeyCode.G,
    Background = false,
    Transparency = 3,
    SettingsFile = "{Title}_Library.json",
    PersistSettings = true,
    Themes = {
        Darker = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(25, 25, 25)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(32, 32, 32)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(25, 25, 25))
            }),
            ["Color Hub 2"] = Color3.fromRGB(30, 30, 30),
            ["Color Stroke"] = Color3.fromRGB(40, 40, 40),
            ["Color Theme"] = Color3.fromRGB(88, 101, 242),
            ["Color Text"] = Color3.fromRGB(243, 243, 243),
            ["Color Dark Text"] = Color3.fromRGB(180, 180, 180)
        },
        Dark = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(40, 40, 40)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(47, 47, 47)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(40, 40, 40))
            }),
            ["Color Hub 2"] = Color3.fromRGB(45, 45, 45),
            ["Color Stroke"] = Color3.fromRGB(65, 65, 65),
            ["Color Theme"] = Color3.fromRGB(65, 150, 255),
            ["Color Text"] = Color3.fromRGB(245, 245, 245),
            ["Color Dark Text"] = Color3.fromRGB(190, 190, 190)
        },
        Purple = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(27, 25, 30)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(32, 32, 32)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(27, 25, 30))
            }),
            ["Color Hub 2"] = Color3.fromRGB(30, 30, 30),
            ["Color Stroke"] = Color3.fromRGB(40, 40, 40),
            ["Color Theme"] = Color3.fromRGB(150, 0, 255),
            ["Color Text"] = Color3.fromRGB(240, 240, 240),
            ["Color Dark Text"] = Color3.fromRGB(180, 180, 180)
        },
        MetalRed = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(80, 0, 0)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(180, 0, 0))
            }),
            ["Color Hub 2"] = Color3.fromRGB(20, 20, 20),
            ["Color Stroke"] = Color3.fromRGB(100, 0, 0),
            ["Color Theme"] = Color3.fromRGB(200, 30, 30),
            ["Color Text"] = Color3.fromRGB(220, 220, 220),
            ["Color Dark Text"] = Color3.fromRGB(170, 170, 170),
            ["Color Hover Text"] = Color3.fromRGB(220, 220, 220)
        }
    }
}

--// Notification
Config.Notification = {
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
    DefaultTitle = "Title",
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
    Theme = "Dark",
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
        Error = Color3.fromRGB(255, 95, 109)
    },
    TypeGlyphs = {},
    TypeIcons = {
        Info = "rbxassetid://10723415903",
        Success = "rbxassetid://10709790298",
        Warning = "rbxassetid://10709753149",
        Error = "rbxassetid://10747383819"
    },
    Themes = {
        Dark = {
            Background = Color3.fromRGB(24, 24, 29),
            Stroke = Color3.fromRGB(72, 72, 84),
            Title = Color3.fromRGB(255, 255, 255),
            Text = Color3.fromRGB(176, 176, 190),
            Accent = Color3.fromRGB(122, 122, 255)
        },
        Light = {
            Background = Color3.fromRGB(247, 247, 250),
            Stroke = Color3.fromRGB(205, 205, 216),
            Title = Color3.fromRGB(24, 24, 30),
            Text = Color3.fromRGB(88, 88, 100),
            Accent = Color3.fromRGB(82, 92, 255)
        },
        Blue = {
            Background = Color3.fromRGB(20, 28, 42),
            Stroke = Color3.fromRGB(55, 86, 130),
            Title = Color3.fromRGB(240, 247, 255),
            Text = Color3.fromRGB(170, 192, 220),
            Accent = Color3.fromRGB(68, 149, 255)
        },
        Purple = {
            Background = Color3.fromRGB(30, 23, 41),
            Stroke = Color3.fromRGB(91, 61, 118),
            Title = Color3.fromRGB(252, 244, 255),
            Text = Color3.fromRGB(196, 176, 210),
            Accent = Color3.fromRGB(173, 103, 255)
        },
        Red = {
            Background = Color3.fromRGB(40, 24, 27),
            Stroke = Color3.fromRGB(122, 59, 67),
            Title = Color3.fromRGB(255, 244, 245),
            Text = Color3.fromRGB(214, 180, 185),
            Accent = Color3.fromRGB(255, 91, 106)
        },
        Green = {
            Background = Color3.fromRGB(21, 36, 30),
            Stroke = Color3.fromRGB(56, 107, 82),
            Title = Color3.fromRGB(241, 255, 248),
            Text = Color3.fromRGB(176, 212, 194),
            Accent = Color3.fromRGB(69, 211, 139)
        }
    }
}

return Config
