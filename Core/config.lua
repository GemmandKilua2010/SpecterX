local Config = {
    --// Hub
    Title = "SpecterX",
    SubTitle = "By Specter",
    Theme = "Obsidian",
    Image = 108120493027251,
    LoadingScreen = false,

    --// Version and update checks
    Version = {
        -- Latest released version. Bump Current for each public release.
        Current = "1.1.7",
        -- Warn only when the loaded library is older than Current.
        WarnWhenOutdated = true
    },

    --// Startup dialog
    StartupGreeting = {
        Enabled = true,
        Description = "Good to see you, {Player}! {Title} is ready. Make yourself at home and enjoy!"
    },

    Whitelist = false,

    --// Icon
    Icon = {
        Transparency = 0,
        Corner = 10
    },

    --// Discord
    DiscordInvite = {
        Desc = "Join our Discord and keep up with all {Title} updates.",
        Invite = "Coming soon"
    },

    --// Repository
    Repository = {
        Author = "GemmandKilua2010",
        RepositoryName = "SpecterX",
        Branch = "main"
    },

    --// Language
    Language = {
        Default = "US",
        AutoDetect = true,
        Countries = {
            BR = "BR",
            US = "US",
            ES = "ES"
        },
        Names = {
            BR = "Português",
            US = "English",
            ES = "Español"
        }
    },

    --// Library
    Library = {
        Scale = 1.9636363983154297,
        Size = {534, 281},
        MinSize = {500, 280},
        MaxSize = {580, 350},
        TabSize = 160,
        MinTabSize = 140,
        MaxTabSize = 220,
        ScreenPadding = 16,
        FallbackViewportSize = {1280, 720},
        Draggable = true,
        Resizable = true,
        TabResizable = true,
        DragThreshold = 3,
        ResizeHandleSize = 35,
        TabResizeHandleWidth = 20,
        Keybind = "G",
        Transparency = 3,
        LockedMessage = "This element is unavailable.",
        SettingsFolder = "Library",
        SettingsFile = "settings.json",
        -- Legacy key: optional flags JSON file path, e.g. "Library/flags.json".
        SaveFolder = false,
        SettingsSaveDelay = 0.5,
        SavePosition = true,
        FlagsSaveDelay = 0.1,
        ConfigButton = true,
        MinimizedWidth = 220,
        ColorPickerSmoothTime = 0.06,

        Appearance = {
            CornerRadius = 10,
            ElementCornerRadius = 6,
            StrokeThickness = 1,
            ButtonHoverTransparency = 0.4,
            GradientRotation = 45,
            ControlColors = {
                White = Color3.fromRGB(255, 255, 255),
                Light = Color3.fromRGB(220, 220, 220),
                Handle = Color3.fromRGB(230, 230, 230),
                Link = Color3.fromRGB(40, 150, 255),
                JoinText = Color3.fromRGB(220, 220, 220),
                Join = Color3.fromRGB(50, 150, 50),
                JoinDisabled = Color3.fromRGB(100, 100, 100),
                JoinDisabledText = Color3.fromRGB(150, 150, 150)
            }
        },

        Controls = {
            Dialog = {
                Width = 398,
                MinHeight = 145,
                MaxHeight = 300,
                HorizontalPadding = 12,
                PaddingTop = 14,
                PaddingBottom = 14,
                TitleGap = 4,
                ContentGap = 16,
                CornerRadius = 11,
                ButtonHeight = 38,
                ButtonSpacing = 10,
                ButtonCornerRadius = 8,
                ButtonMaxWidth = 124,
                SingleButtonMaxWidth = 196,
                ButtonColor = "Color Stroke",
                ButtonTextColor = "Color Text",
                ButtonAlignment = "Center"
            },
            Titles = {
                Dialog = "Dialog",
                DialogText = "This is a Dialog",
                Tab = "Tab!",
                Section = "Section",
                Paragraph = "Paragraph",
                Button = "Button!",
                Toggle = "Toggle",
                Dropdown = "Dropdown",
                Players = "Players",
                Selector = "Selector",
                Slider = "Slider!",
                TextBox = "Text Box",
                Keybind = "Keybind",
                ColorPicker = "Custom color",
                Discord = "Discord",
                Locked = "Locked"
            },
            Slider = {
                Min = 10,
                Max = 100,
                Step = 1,
                Default = 25
            },
            TextBox = {
                Default = "",
                Placeholder = "Input",
                ClearText = false
            },
            Keybind = {
                ShowIcon = false,
                Width = 48,
                HighlightActive = true,
                RightClickCapture = true
            },
            ColorPicker = {
                Default = "#137D81",
                MaxRecent = 8,
                Display = "Hex",
                ReturnFormat = "Color3",
                Presets = {
                    Color3.fromRGB(108, 99, 255),
                    Color3.fromRGB(33, 150, 243),
                    Color3.fromRGB(67, 181, 129),
                    Color3.fromRGB(255, 193, 7),
                    Color3.fromRGB(255, 107, 107),
                    Color3.fromRGB(233, 30, 140),
                    Color3.fromRGB(156, 106, 222),
                    Color3.fromRGB(255, 255, 255)
                }
            },
            Dropdown = {
                Placeholder = "...",
                MultiMin = 0
            },
            TopBarIcon = "circle"
        },

        TopBar = {
            Height = 28,
            TitleTextSize = 12,
            SubTitleTextSize = 8,
            TitlePadding = 15,
            ControlsRightPadding = 9,
            ControlsSpacing = 10,
            ButtonTransparency = 0.15
        },

        Tabs = {
            Padding = 10,
            Spacing = 5,
            ButtonHeight = 24,
            TextSize = 10,
            IconSize = 13,
            IconOffset = 8,
            TextOffset = 15,
            TextIconOffset = 25,
            InactiveTransparency = 0.3,
            IndicatorWidth = 4,
            IndicatorHeight = 13,
            IndicatorIdleSize = 4
        },

        Elements = {
            Height = 25,
            TitleTextSize = 10,
            DescriptionTextSize = 8,
            HorizontalPadding = 10,
            VerticalPadding = 5,
            Spacing = 2
        },

        Section = {
            Indicator = false,
            Height = 18,
            TextSize = 11,
            Thickness = 3,
            IndicatorHeight = 10,
            Spacing = 7
        },

        Scroll = {
            Thickness = 1.5,
            Transparency = 0.2
        },

        Background = {
            Enabled = true,
            Default = "None",
            Image = false,
            ImageTransparency = 35,
            ImageBrightness = 100,
            ScaleType = "Crop",
            TileSize = 128,
            Presets = {
                {Key = "None", Name = "None", Id = false},
                {Key = "PurpleGradient", Name = "Purple gradient", Id = 13775967663},
                {Key = "DarkNebula", Name = "Dark nebula", Id = 10782430528},
                {Key = "MonoGradient", Name = "Monochrome gradient", Id = 11526322561},
                {Key = "RedBlack", Name = "Red black texture", Id = 52892529},
                {Key = "BlackGold", Name = "Black gold abstract", Id = 18254645055},
                {Key = "Custom", Name = "Custom", Id = false}
            }
        },

        Audio = {
            Enabled = false,
            SoundId = 179235828,
            Volume = 35,
            Presets = {
                {Name = "Classic Click", Id = 179235828},
                {Name = "Menu Click", Id = 17628141786},
                {Name = "Open Click", Id = 70452176150315},
                {Name = "High Beep", Id = 9119144736},
                {Name = "Synth Click", Id = 9120132783},
                {Name = "Hard Click", Id = 9126036592},
                {Name = "Thuddy Click", Id = 9126042506},
                {Name = "Tonal Click", Id = 9126106016}
            }
        },

        Dropdown = {
            Search = false,
            PrefixOnly = true,
            CloseOnSelect = false,
            MaxVisibleOptions = 10,
            SearchConfig = {
                TextSize = 11,
                MinTextSize = 8,
                SearchFrameHeight = 21,
                SearchFrameOffset = 5,
                IconSize = 12,
                IconPosition = 6,
                InputOffset = 23,
                NoResultTextSize = 9
            }
        },

        Notification = {
            Width = 300,
            Height = 32,
            MaxWidth = 420,
            Margin = 8,
            CornerRadius = 7,
            StrokeTransparency = 0.4,
            Duration = 3,
            TextSize = 10,
            TextPaddingX = 10,
            TextPaddingY = 7,
            TextHeightPadding = 16,
            ZIndex = 2000
        },

        Code = {
            Title = "Code",
            Source = "",
            Language = "Lua",
            Edit = false,
            Execute = false,
            ExecuteSpinDuration = 0.55,
            Copy = true,
            Error = false,
            BlockOnError = true,
            MaxDiagnostics = 12,
            SmoothCaret = true,
            CaretWidth = 1,
            CaretOffset = 0,
            CaretColor = Color3.fromRGB(255, 255, 255),
            CaretCornerRadius = 1,
            CaretHeightPadding = 1,
            CaretHeightRatio = 0.75,
            CaretEndGap = 2,
            CaretMoveDuration = 0.07,
            CaretBlinkOnDuration = 0.55,
            CaretBlinkOffDuration = 0.5,
            CaretBlinkFadeDuration = 0.14,
            IndentUnit = "\t",
            FontSize = 13,
            LineSpacing = 1.16,
            MaxVisibleLines = 8,
            HeaderHeight = 30,
            Padding = 5,
            BottomPadding = 6,
            GutterWidth = 20,
            GutterPaddingLeft = 3,
            GutterPaddingRight = 5,
            GutterNumberTransparency = 0.12,
            GutterActiveNumberTransparency = 0,
            GutterErrorNumberTransparency = 0.05,
            GutterActiveLine = true,
            PaletteLightThreshold = 0.55,
            ErrorTip = {
                MaxWidth = 280,
                Margin = 4,
                Padding = 8,
                TextSize = 10,
                Duration = 4,
                CornerRadius = 6,
                StrokeTransparency = 0
            },
            ErrorColor = {
                Dark = Color3.fromRGB(255, 92, 92),
                Light = Color3.fromRGB(205, 38, 38)
            },
            Palette = {
                Dark = {
                    Keyword = Color3.fromRGB(198, 120, 221),
                    Global = Color3.fromRGB(86, 182, 194),
                    Function = Color3.fromRGB(97, 175, 239),
                    Property = Color3.fromRGB(171, 201, 229),
                    Type = Color3.fromRGB(229, 192, 123),
                    String = Color3.fromRGB(152, 195, 121),
                    Escape = Color3.fromRGB(209, 154, 102),
                    Number = Color3.fromRGB(209, 154, 102),
                    Literal = Color3.fromRGB(209, 154, 102),
                    Comment = Color3.fromRGB(127, 143, 159),
                    Operator = Color3.fromRGB(198, 120, 221),
                    Punctuation = Color3.fromRGB(171, 178, 191),
                    Attribute = Color3.fromRGB(229, 192, 123)
                },
                Light = {
                    Keyword = Color3.fromRGB(133, 55, 164),
                    Global = Color3.fromRGB(0, 109, 125),
                    Function = Color3.fromRGB(37, 100, 166),
                    Property = Color3.fromRGB(42, 85, 125),
                    Type = Color3.fromRGB(139, 86, 16),
                    String = Color3.fromRGB(66, 121, 48),
                    Escape = Color3.fromRGB(156, 80, 29),
                    Number = Color3.fromRGB(156, 80, 29),
                    Literal = Color3.fromRGB(156, 80, 29),
                    Comment = Color3.fromRGB(92, 108, 120),
                    Operator = Color3.fromRGB(133, 55, 164),
                    Punctuation = Color3.fromRGB(65, 75, 90),
                    Attribute = Color3.fromRGB(139, 86, 16)
                }
            }
        },

        Animation = {
            Default = 0.5,
            Window = 0.22,
            TopBar = 0.12,
            TabOpen = 0.3,
            Tab = 0.35,
            Toggle = 0.25,
            Dropdown = 0.2,
            DropdownPosition = 0.1,
            Slider = 0.3,
            Dialog = 0.2,
            DialogFade = 0.15
        },

        Responsive = {
            Enabled = true,
            CompactBreakpoint = 640,
            CompactTabSize = 128,
            MinScale = 0.5,
            MaxScale = 1,
            SmallScreenPadding = 8,
            TouchTopbarButtonSize = 18,
            DesktopTopbarButtonSize = 14
        }
    },

    --// Loader
    Loader = {
        Time = 4.3,
        Steps = {
            {"Connecting to {Title}...", 15},
            {"Loading modules...", 30},
            {"Initializing components...", 50},
            {"Preparing interface...", 70},
            {"Optimizing system...", 85},
            {"Finalizing...", 100}
        },
        Music = "rbxassetid://0",
        MusicVolume = 0.5,
        MusicLooped = true,
        Blur = true,
        BlurSize = 18,
        BlurInTime = 0.35,
        BlurFadeTime = 0.45,
        MusicFadeTime = 1.2,
        GuiFadeTime = 0.45
    },

    --// Addons
    Addon = {
        Folder = "Addon"
    },

    --// Themes
    Themes = {
        Darker = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(18, 18, 22)),
                ColorSequenceKeypoint.new(0.30, Color3.fromRGB(25, 25, 32)),
                ColorSequenceKeypoint.new(0.55, Color3.fromRGB(32, 32, 42)),
                ColorSequenceKeypoint.new(0.80, Color3.fromRGB(24, 24, 31)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(16, 16, 20))
            }),
            ["Color Hub 2"] = Color3.fromRGB(24, 24, 30),
            ["Color Stroke"] = Color3.fromRGB(47, 47, 58),
            ["Color Theme"] = Color3.fromRGB(88, 101, 242),
            ["Color Text"] = Color3.fromRGB(245, 245, 248),
            ["Color Dark Text"] = Color3.fromRGB(170, 170, 182)
        },

        Dark = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(31, 32, 38)),
                ColorSequenceKeypoint.new(0.28, Color3.fromRGB(42, 43, 52)),
                ColorSequenceKeypoint.new(0.55, Color3.fromRGB(50, 51, 61)),
                ColorSequenceKeypoint.new(0.78, Color3.fromRGB(39, 40, 48)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(29, 30, 36))
            }),
            ["Color Hub 2"] = Color3.fromRGB(39, 40, 47),
            ["Color Stroke"] = Color3.fromRGB(67, 68, 80),
            ["Color Theme"] = Color3.fromRGB(78, 148, 255),
            ["Color Text"] = Color3.fromRGB(248, 248, 250),
            ["Color Dark Text"] = Color3.fromRGB(190, 190, 200)
        },

        Purple = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(20, 14, 30)),
                ColorSequenceKeypoint.new(0.25, Color3.fromRGB(35, 20, 52)),
                ColorSequenceKeypoint.new(0.52, Color3.fromRGB(55, 27, 78)),
                ColorSequenceKeypoint.new(0.77, Color3.fromRGB(32, 18, 48)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(18, 13, 27))
            }),
            ["Color Hub 2"] = Color3.fromRGB(29, 22, 38),
            ["Color Stroke"] = Color3.fromRGB(73, 50, 95),
            ["Color Theme"] = Color3.fromRGB(170, 85, 255),
            ["Color Text"] = Color3.fromRGB(248, 244, 255),
            ["Color Dark Text"] = Color3.fromRGB(190, 170, 205)
        },

        MetalRed = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(12, 12, 14)),
                ColorSequenceKeypoint.new(0.25, Color3.fromRGB(35, 15, 18)),
                ColorSequenceKeypoint.new(0.52, Color3.fromRGB(75, 20, 25)),
                ColorSequenceKeypoint.new(0.78, Color3.fromRGB(38, 14, 18)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(10, 10, 12))
            }),
            ["Color Hub 2"] = Color3.fromRGB(26, 18, 20),
            ["Color Stroke"] = Color3.fromRGB(92, 38, 44),
            ["Color Theme"] = Color3.fromRGB(235, 62, 72),
            ["Color Text"] = Color3.fromRGB(250, 242, 243),
            ["Color Dark Text"] = Color3.fromRGB(195, 165, 170)
        },

        Midnight = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(8, 12, 24)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(15, 24, 48)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(24, 39, 73)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(14, 27, 52)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(7, 11, 22))
            }),
            ["Color Hub 2"] = Color3.fromRGB(15, 22, 39),
            ["Color Stroke"] = Color3.fromRGB(45, 63, 98),
            ["Color Theme"] = Color3.fromRGB(92, 135, 255),
            ["Color Text"] = Color3.fromRGB(240, 245, 255),
            ["Color Dark Text"] = Color3.fromRGB(155, 171, 200)
        },

        Aurora = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(9, 22, 28)),
                ColorSequenceKeypoint.new(0.20, Color3.fromRGB(12, 43, 49)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(22, 63, 62)),
                ColorSequenceKeypoint.new(0.70, Color3.fromRGB(27, 46, 67)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(17, 23, 40))
            }),
            ["Color Hub 2"] = Color3.fromRGB(15, 31, 37),
            ["Color Stroke"] = Color3.fromRGB(47, 88, 90),
            ["Color Theme"] = Color3.fromRGB(72, 234, 191),
            ["Color Text"] = Color3.fromRGB(236, 255, 250),
            ["Color Dark Text"] = Color3.fromRGB(155, 199, 191)
        },

        Ocean = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(6, 19, 32)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(7, 35, 55)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(9, 59, 82)),
                ColorSequenceKeypoint.new(0.75, Color3.fromRGB(7, 39, 62)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(5, 18, 30))
            }),
            ["Color Hub 2"] = Color3.fromRGB(9, 29, 43),
            ["Color Stroke"] = Color3.fromRGB(31, 79, 106),
            ["Color Theme"] = Color3.fromRGB(42, 180, 255),
            ["Color Text"] = Color3.fromRGB(236, 249, 255),
            ["Color Dark Text"] = Color3.fromRGB(147, 190, 210)
        },

        Nebula = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(17, 10, 31)),
                ColorSequenceKeypoint.new(0.20, Color3.fromRGB(37, 18, 59)),
                ColorSequenceKeypoint.new(0.46, Color3.fromRGB(65, 27, 82)),
                ColorSequenceKeypoint.new(0.70, Color3.fromRGB(46, 25, 70)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(18, 12, 34))
            }),
            ["Color Hub 2"] = Color3.fromRGB(30, 18, 44),
            ["Color Stroke"] = Color3.fromRGB(83, 53, 108),
            ["Color Theme"] = Color3.fromRGB(195, 96, 255),
            ["Color Text"] = Color3.fromRGB(250, 242, 255),
            ["Color Dark Text"] = Color3.fromRGB(200, 166, 218)
        },

        Sakura = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(30, 18, 26)),
                ColorSequenceKeypoint.new(0.24, Color3.fromRGB(52, 27, 43)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(75, 36, 58)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(50, 26, 42)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(29, 18, 26))
            }),
            ["Color Hub 2"] = Color3.fromRGB(40, 24, 34),
            ["Color Stroke"] = Color3.fromRGB(91, 53, 73),
            ["Color Theme"] = Color3.fromRGB(255, 112, 171),
            ["Color Text"] = Color3.fromRGB(255, 244, 249),
            ["Color Dark Text"] = Color3.fromRGB(214, 174, 193)
        },

        Emerald = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(7, 20, 16)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(11, 38, 29)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(17, 58, 42)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(10, 38, 29)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(6, 19, 15))
            }),
            ["Color Hub 2"] = Color3.fromRGB(13, 31, 24),
            ["Color Stroke"] = Color3.fromRGB(39, 82, 63),
            ["Color Theme"] = Color3.fromRGB(52, 211, 153),
            ["Color Text"] = Color3.fromRGB(237, 255, 248),
            ["Color Dark Text"] = Color3.fromRGB(151, 201, 181)
        },

        Sunset = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(31, 17, 25)),
                ColorSequenceKeypoint.new(0.20, Color3.fromRGB(58, 27, 39)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(82, 40, 40)),
                ColorSequenceKeypoint.new(0.70, Color3.fromRGB(71, 34, 30)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(34, 20, 22))
            }),
            ["Color Hub 2"] = Color3.fromRGB(43, 25, 29),
            ["Color Stroke"] = Color3.fromRGB(100, 57, 56),
            ["Color Theme"] = Color3.fromRGB(255, 122, 76),
            ["Color Text"] = Color3.fromRGB(255, 246, 240),
            ["Color Dark Text"] = Color3.fromRGB(218, 179, 164)
        },

        Gold = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(22, 19, 12)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(39, 32, 17)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(61, 49, 22)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(40, 33, 17)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(21, 18, 12))
            }),
            ["Color Hub 2"] = Color3.fromRGB(32, 27, 17),
            ["Color Stroke"] = Color3.fromRGB(83, 69, 35),
            ["Color Theme"] = Color3.fromRGB(245, 194, 66),
            ["Color Text"] = Color3.fromRGB(255, 251, 235),
            ["Color Dark Text"] = Color3.fromRGB(211, 194, 146)
        },

        Cyber = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(8, 12, 18)),
                ColorSequenceKeypoint.new(0.20, Color3.fromRGB(8, 27, 31)),
                ColorSequenceKeypoint.new(0.46, Color3.fromRGB(12, 47, 49)),
                ColorSequenceKeypoint.new(0.72, Color3.fromRGB(15, 31, 44)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(8, 12, 20))
            }),
            ["Color Hub 2"] = Color3.fromRGB(11, 23, 28),
            ["Color Stroke"] = Color3.fromRGB(30, 78, 81),
            ["Color Theme"] = Color3.fromRGB(0, 245, 212),
            ["Color Text"] = Color3.fromRGB(235, 255, 253),
            ["Color Dark Text"] = Color3.fromRGB(143, 200, 194)
        },

        Crimson = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(24, 9, 14)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(47, 13, 22)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(74, 18, 30)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(45, 12, 21)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(22, 8, 13))
            }),
            ["Color Hub 2"] = Color3.fromRGB(35, 13, 20),
            ["Color Stroke"] = Color3.fromRGB(91, 31, 45),
            ["Color Theme"] = Color3.fromRGB(255, 67, 101),
            ["Color Text"] = Color3.fromRGB(255, 241, 244),
            ["Color Dark Text"] = Color3.fromRGB(211, 163, 174)
        },

        Glacier = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(12, 21, 29)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(20, 38, 51)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(29, 56, 72)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(19, 39, 52)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(11, 21, 29))
            }),
            ["Color Hub 2"] = Color3.fromRGB(18, 32, 42),
            ["Color Stroke"] = Color3.fromRGB(53, 92, 112),
            ["Color Theme"] = Color3.fromRGB(114, 220, 255),
            ["Color Text"] = Color3.fromRGB(242, 252, 255),
            ["Color Dark Text"] = Color3.fromRGB(172, 209, 221)
        },

        Obsidian = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(10, 10, 13)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(19, 20, 26)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(30, 31, 40)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(18, 19, 25)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(8, 8, 11))
            }),
            ["Color Hub 2"] = Color3.fromRGB(18, 18, 23),
            ["Color Stroke"] = Color3.fromRGB(52, 53, 66),
            ["Color Theme"] = Color3.fromRGB(150, 160, 190),
            ["Color Text"] = Color3.fromRGB(246, 246, 250),
            ["Color Dark Text"] = Color3.fromRGB(167, 168, 181)
        },

        Royal = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(12, 9, 28)),
                ColorSequenceKeypoint.new(0.22, Color3.fromRGB(29, 17, 61)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(52, 28, 94)),
                ColorSequenceKeypoint.new(0.76, Color3.fromRGB(27, 17, 58)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(10, 8, 24))
            }),
            ["Color Hub 2"] = Color3.fromRGB(24, 17, 42),
            ["Color Stroke"] = Color3.fromRGB(73, 49, 112),
            ["Color Theme"] = Color3.fromRGB(139, 92, 246),
            ["Color Text"] = Color3.fromRGB(249, 245, 255),
            ["Color Dark Text"] = Color3.fromRGB(191, 171, 219)
        },

        Eclipse = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(7, 8, 14)),
                ColorSequenceKeypoint.new(0.20, Color3.fromRGB(15, 18, 33)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(33, 27, 57)),
                ColorSequenceKeypoint.new(0.70, Color3.fromRGB(20, 31, 51)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(6, 7, 12))
            }),
            ["Color Hub 2"] = Color3.fromRGB(15, 17, 26),
            ["Color Stroke"] = Color3.fromRGB(53, 52, 82),
            ["Color Theme"] = Color3.fromRGB(112, 104, 255),
            ["Color Text"] = Color3.fromRGB(245, 246, 255),
            ["Color Dark Text"] = Color3.fromRGB(166, 169, 198)
        },

        Inferno = {
            ["Color Hub 1"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(22, 7, 5)),
                ColorSequenceKeypoint.new(0.20, Color3.fromRGB(48, 13, 7)),
                ColorSequenceKeypoint.new(0.45, Color3.fromRGB(86, 27, 8)),
                ColorSequenceKeypoint.new(0.70, Color3.fromRGB(61, 15, 6)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(19, 6, 4))
            }),
            ["Color Hub 2"] = Color3.fromRGB(35, 13, 8),
            ["Color Stroke"] = Color3.fromRGB(101, 44, 21),
            ["Color Theme"] = Color3.fromRGB(255, 91, 37),
            ["Color Text"] = Color3.fromRGB(255, 245, 238),
            ["Color Dark Text"] = Color3.fromRGB(221, 175, 151)
        }
    }
}

return Config
