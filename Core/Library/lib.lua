---@diagnostic disable: undefined-global

--// Services

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

--// Context

local Hub, RootConfig = ...
local Player = Players.LocalPlayer
assert(type(Hub) == "table" and type(Hub.GenerateName) == "function", "The Hub module must be supplied to the library.")
assert(type(RootConfig) == "table", "Core/config.lua must be supplied to the library.")
local LibraryConfig = assert(RootConfig.Library, "Config.Library is required.")
local SharedThemes = assert(RootConfig.Themes, "Config.Themes is required.")
local RootTheme = RootConfig.Theme
assert(type(RootTheme) == "string" and type(SharedThemes[RootTheme]) == "table", "Config.Theme must name a theme in Config.Themes.")

local Library = {
	Themes = SharedThemes,
	Info = {
		Version = "1.2.0"
	},
	Save = {},
	Settings = {},
	Connection = {},
	Instances = {},
	Elements = {},
	Options = {},
	SectionIndicators = setmetatable({}, {__mode = "k"}),
	SectionRanges = {
		SectionHeight = {16, 28},
		SectionTextSize = {9, 16},
		SectionThickness = {2, 8},
		SectionIndicatorHeight = {6, 20},
		SectionSpacing = {2, 14}
	},
	Flags = {},
	Tabs = {},
	Icons = {}
}

--// Cache

local IconSearchCache = {}
local DropdownSearchListeners = setmetatable({}, {__mode = "k"})
local DropdownPrefixListeners = setmetatable({}, {__mode = "k"})
local DropdownSizeListeners = setmetatable({}, {__mode = "k"})
Library._KeybindSettings = {Listeners = setmetatable({}, {__mode = "k"})}
Library._PositionSettings = {Bindings = setmetatable({}, {__mode = "k"})}
function Library._PositionSettings.Normalize(Value, AllowOverflow)
    if type(Value) ~= "table" then return nil end
    local X, Y = tonumber(Value.X), tonumber(Value.Y)
    if not X or not Y or X ~= X or Y ~= Y or math.abs(X) == math.huge or math.abs(Y) == math.huge then return nil end
    return {X = AllowOverflow and X or math.clamp(X, 0, 1), Y = math.clamp(Y, 0, 1)}
end

--// Config

local function ConfigNumber(Source, Key)
    local Value = tonumber(Source[Key])
    assert(Value, "Config.Library requires a numeric " .. Key .. ".")
    return Value
end

local function ConfigSection(Key)
    local Value = LibraryConfig[Key]
    assert(type(Value) == "table", "Config.Library." .. Key .. " is required.")
    return Value
end

local function GetPair(Value, DefaultX, DefaultY)
    if type(Value) ~= "table" then
        return DefaultX, DefaultY
    end

    local X = tonumber(Value[1] or Value.X) or DefaultX
    local Y = tonumber(Value[2] or Value.Y) or DefaultY
    return X, Y
end

local function GetKeyCode(Value)
    if typeof(Value) == "EnumItem" and Value.EnumType == Enum.KeyCode then
        return Value
    end

    if type(Value) ~= "string" then
        return nil
    end

    local LowerValue = Value:lower()
    for _, Key in ipairs(Enum.KeyCode:GetEnumItems()) do
        if Key.Name:lower() == LowerValue then
            return Key
        end
    end

    return nil
end

local function NormalizeAssetId(Value)
    if Value == nil or Value == false then
        return ""
    end

    if type(Value) == "number" then
        if Value ~= Value or math.abs(Value) == math.huge or Value % 1 ~= 0 then return nil end
        if Value <= 0 then
            return ""
        end
        return tostring(math.floor(Value))
    end

    if type(Value) ~= "string" then
        return nil
    end

    local Text = Value:gsub("^%s*(.-)%s*$", "%1")
    if Text == "" or Text:lower() == "none" then
        return ""
    end

    local Id = Text:match("^rbxassetid://(%d+)$")
        or Text:match("^%d+$")
        or Text:match("[?&]id=(%d+)")
        or Text:match("/asset/(%d+)")
        or Text:match("/library/(%d+)")
        or Text:match("/catalog/(%d+)")

    if not Id and Text:match("^%d+$") then
        Id = Text
    end

    return Id
end

local function ToAssetContentId(Value)
    local Id = NormalizeAssetId(Value)
    if not Id or Id == "" then
        return ""
    end
    return "rbxassetid://" .. Id
end

local GuiImageCache = {}

local function ResolveGuiImage(Value)
    local Id = NormalizeAssetId(Value)
    if Id == "" then return "" end
    if not Id then return type(Value) == "string" and Value or "" end

    local Cached = GuiImageCache[Id]
    if Cached then return Cached end

    local Content = "rbxassetid://" .. Id
    -- Keep image resolution local and immediate. GetObjects can yield while an
    -- asset is fetched, which stalls the caller when a window builds its UI.
    GuiImageCache[Id] = Content
    return Content
end

local BackgroundScaleTypes = {
    Crop = Enum.ScaleType.Crop,
    Fit = Enum.ScaleType.Fit,
    Stretch = Enum.ScaleType.Stretch,
    Tile = Enum.ScaleType.Tile
}

local function NormalizeBackgroundScale(Value)
    if type(Value) == "string" then
        for Name in pairs(BackgroundScaleTypes) do
            if Name:lower() == Value:lower() then
                return Name
            end
        end
    end
    return ConfigSection("Background").ScaleType
end

local DefaultWidth, DefaultHeight = GetPair(LibraryConfig.Size)
local MinWidth, MinHeight = GetPair(LibraryConfig.MinSize)
local MaxWidth, MaxHeight = GetPair(LibraryConfig.MaxSize)
assert(DefaultWidth and DefaultHeight, "Config.Library.Size requires two numbers.")
assert(MinWidth and MinHeight, "Config.Library.MinSize requires two numbers.")
assert(MaxWidth and MaxHeight, "Config.Library.MaxSize requires two numbers.")

MinWidth = math.max(320, MinWidth)
MinHeight = math.max(200, MinHeight)
MaxWidth = math.max(MinWidth, MaxWidth)
MaxHeight = math.max(MinHeight, MaxHeight)

DefaultWidth = math.clamp(DefaultWidth, MinWidth, MaxWidth)
DefaultHeight = math.clamp(DefaultHeight, MinHeight, MaxHeight)

local MinTabSize = math.max(100, ConfigNumber(LibraryConfig, "MinTabSize"))
local MaxTabSize = math.max(MinTabSize, ConfigNumber(LibraryConfig, "MaxTabSize"))
local DefaultTabSize = math.clamp(ConfigNumber(LibraryConfig, "TabSize"), MinTabSize, MaxTabSize)
local ScreenPadding = math.max(0, ConfigNumber(LibraryConfig, "ScreenPadding"))
local SettingsFolder = assert(LibraryConfig.SettingsFolder, "Config.Library.SettingsFolder is required.")
local SettingsFile = assert(LibraryConfig.SettingsFile, "Config.Library.SettingsFile is required.")
local SettingsPath = SettingsFolder .. "/" .. SettingsFile
local DropdownFavoritesPath = "Library/Dropdown/favorites.json"
local DefaultKeybind = assert(GetKeyCode(LibraryConfig.Keybind), "Config.Library.Keybind is invalid.").Name
local DefaultTransparency = math.clamp(ConfigNumber(LibraryConfig, "Transparency"), 0, 100)
local DefaultMinimizedWidth = math.clamp(ConfigNumber(LibraryConfig, "MinimizedWidth"), 160, 320)
local ColorPickerSmoothTime = math.clamp(ConfigNumber(LibraryConfig, "ColorPickerSmoothTime"), 0, 0.2)
local ResponsiveConfig = ConfigSection("Responsive")
local ResponsiveEnabled = ResponsiveConfig.Enabled ~= false
local CompactBreakpoint = math.max(320, ConfigNumber(ResponsiveConfig, "CompactBreakpoint"))
local CompactTabSize = math.clamp(ConfigNumber(ResponsiveConfig, "CompactTabSize"), 100, MaxTabSize)
local ResponsiveMinScale = math.clamp(ConfigNumber(ResponsiveConfig, "MinScale"), 0.35, 1)
local ResponsiveMaxScale = math.clamp(ConfigNumber(ResponsiveConfig, "MaxScale"), ResponsiveMinScale, 1.5)
local SmallScreenPadding = math.max(0, ConfigNumber(ResponsiveConfig, "SmallScreenPadding"))
local TouchTopbarButtonSize = math.clamp(ConfigNumber(ResponsiveConfig, "TouchTopbarButtonSize"), 14, 28)
local DesktopTopbarButtonSize = math.clamp(ConfigNumber(ResponsiveConfig, "DesktopTopbarButtonSize"), 12, 24)
local Draggable = LibraryConfig.Draggable ~= false
local Resizable = LibraryConfig.Resizable ~= false
local TabResizable = LibraryConfig.TabResizable ~= false
local DragThreshold = math.max(0, ConfigNumber(LibraryConfig, "DragThreshold"))
local ResizeHandleSize = math.clamp(ConfigNumber(LibraryConfig, "ResizeHandleSize"), 12, 48)
local TabResizeHandleWidth = math.clamp(ConfigNumber(LibraryConfig, "TabResizeHandleWidth"), 6, 30)

local AppearanceConfig = ConfigSection("Appearance")
local ControlColors = AppearanceConfig.ControlColors
local ControlsConfig = ConfigSection("Controls")
function Library._KeybindSettings.NormalizeWidth(Value)
    Value = tonumber(Value)
    if not Value or Value ~= Value or math.abs(Value) == math.huge then return nil end
    return math.clamp(math.floor(Value + 0.5), 32, 96)
end
do
    local Defaults = type(ControlsConfig.Keybind) == "table" and ControlsConfig.Keybind or {}
    local State = Library._KeybindSettings
    State.DefaultIcon = Defaults.ShowIcon == true
    State.DefaultWidth = State.NormalizeWidth(Defaults.Width) or 48
    State.DefaultHighlight = Defaults.HighlightActive ~= false
    State.DefaultRightClick = Defaults.RightClickCapture ~= false
end
local CornerRadius = math.max(0, ConfigNumber(AppearanceConfig, "CornerRadius"))
local ElementCornerRadius = math.max(0, ConfigNumber(AppearanceConfig, "ElementCornerRadius"))
local StrokeThickness = math.max(0, ConfigNumber(AppearanceConfig, "StrokeThickness"))
local StrokeTransparency = math.clamp(tonumber(AppearanceConfig.StrokeTransparency) or 0.5, 0, 1)
local ButtonHoverTransparency = math.clamp(ConfigNumber(AppearanceConfig, "ButtonHoverTransparency"), 0, 1)
local GradientRotation = ConfigNumber(AppearanceConfig, "GradientRotation")

local TopBarConfig = ConfigSection("TopBar")
local TopBarHeight = math.clamp(ConfigNumber(TopBarConfig, "Height"), 20, 48)
local TopBarTitleTextSize = math.clamp(ConfigNumber(TopBarConfig, "TitleTextSize"), 8, 24)
local TopBarSubTitleTextSize = math.clamp(ConfigNumber(TopBarConfig, "SubTitleTextSize"), 6, 20)
local TopBarTitlePadding = math.max(0, ConfigNumber(TopBarConfig, "TitlePadding"))
local TopBarControlsRightPadding = math.max(0, ConfigNumber(TopBarConfig, "ControlsRightPadding"))
local TopBarControlsSpacing = math.max(0, ConfigNumber(TopBarConfig, "ControlsSpacing"))
local TopBarButtonTransparency = math.clamp(ConfigNumber(TopBarConfig, "ButtonTransparency"), 0, 1)

local TabsConfig = ConfigSection("Tabs")
local TabsPadding = math.max(0, ConfigNumber(TabsConfig, "Padding"))
local TabsSpacing = math.max(0, ConfigNumber(TabsConfig, "Spacing"))
local TabButtonHeight = math.clamp(ConfigNumber(TabsConfig, "ButtonHeight"), 16, 48)
local TabTextSize = math.clamp(ConfigNumber(TabsConfig, "TextSize"), 7, 24)
local TabIconSize = math.clamp(ConfigNumber(TabsConfig, "IconSize"), 8, 32)
local TabIconOffset = math.max(0, ConfigNumber(TabsConfig, "IconOffset"))
local TabTextOffset = math.max(0, ConfigNumber(TabsConfig, "TextOffset"))
local TabTextIconOffset = math.max(TabTextOffset, ConfigNumber(TabsConfig, "TextIconOffset"))
local TabInactiveTransparency = math.clamp(ConfigNumber(TabsConfig, "InactiveTransparency"), 0, 1)
local TabIndicatorWidth = math.clamp(ConfigNumber(TabsConfig, "IndicatorWidth"), 1, 12)
local TabIndicatorHeight = math.clamp(ConfigNumber(TabsConfig, "IndicatorHeight"), 2, 32)
local TabIndicatorIdleSize = math.clamp(ConfigNumber(TabsConfig, "IndicatorIdleSize"), 1, TabIndicatorHeight)

local ElementsConfig = ConfigSection("Elements")
local ElementHeight = math.clamp(ConfigNumber(ElementsConfig, "Height"), 18, 60)
local ElementTitleTextSize = math.clamp(ConfigNumber(ElementsConfig, "TitleTextSize"), 7, 24)
local ElementDescriptionTextSize = math.clamp(ConfigNumber(ElementsConfig, "DescriptionTextSize"), 6, 20)
local ElementHorizontalPadding = math.max(0, ConfigNumber(ElementsConfig, "HorizontalPadding"))
local ElementVerticalPadding = math.max(0, ConfigNumber(ElementsConfig, "VerticalPadding"))
local ElementSpacing = math.max(0, ConfigNumber(ElementsConfig, "Spacing"))

local ScrollConfig = ConfigSection("Scroll")
local ScrollThickness = math.clamp(ConfigNumber(ScrollConfig, "Thickness"), 0, 12)
local ScrollTransparency = math.clamp(ConfigNumber(ScrollConfig, "Transparency"), 0, 1)
local AdaptiveScrollRefresh = setmetatable({}, {__mode = "k"})

local BackgroundConfig = ConfigSection("Background")
local DefaultBackgroundImage = NormalizeAssetId(BackgroundConfig.Image) or ""
local DefaultBackgroundPreset = assert(BackgroundConfig.Default, "Config.Library.Background.Default is required.")
local DefaultBackgroundImageTransparency = math.clamp(ConfigNumber(BackgroundConfig, "ImageTransparency"), 0, 100)
local DefaultBackgroundScale = NormalizeBackgroundScale(BackgroundConfig.ScaleType)
local BackgroundPresets = type(BackgroundConfig.Presets) == "table" and BackgroundConfig.Presets or {}

local AudioConfig = ConfigSection("Audio")
local DefaultSoundEnabled = AudioConfig.Enabled == true
local DefaultSoundVolume = math.clamp(ConfigNumber(AudioConfig, "Volume"), 0, 100)
local DefaultSoundId = assert(NormalizeAssetId(AudioConfig.SoundId), "Config.Library.Audio.SoundId is invalid.")

local SoundPresets = {}
local SoundPresetOptions = {}
local SoundPresetIndexById = {}

for _, Preset in ipairs(type(AudioConfig.Presets) == "table" and AudioConfig.Presets or {}) do
    local Id = NormalizeAssetId(Preset.Id or Preset.SoundId)
    if Id and Id ~= "" then
        local Name = tostring(Preset.Name or Id)
        SoundPresets[#SoundPresets + 1] = {Name = Name, Id = Id}
        SoundPresetOptions[#SoundPresetOptions + 1] = Name
        SoundPresetIndexById[Id] = #SoundPresets
    end
end

local function EnsureSoundPreset(Id)
    if not Id or Id == "" then return nil end
    if not SoundPresetIndexById[Id] then
        SoundPresets[#SoundPresets + 1] = {Name = Id, Id = Id}
        SoundPresetOptions[#SoundPresetOptions + 1] = Id
        SoundPresetIndexById[Id] = #SoundPresets
    end
    return SoundPresetIndexById[Id]
end
EnsureSoundPreset(DefaultSoundId)

-- Keep initialization-only locals out of the long-lived module scope (Luau limit: 200).
local DropdownConfig, DefaultDropdownMaxVisibleOptions
local AnimationDefault, AnimationWindow, AnimationTopBar, AnimationTab, AnimationToggle, AnimationDropdown, AnimationDropdownPosition do
DropdownConfig = ConfigSection("Dropdown")
local DefaultDropdownSearch = DropdownConfig.Search == true
local DefaultDropdownPrefixOnly = DropdownConfig.PrefixOnly ~= false
local DefaultDropdownCloseOnSelect = DropdownConfig.CloseOnSelect == true
DefaultDropdownMaxVisibleOptions = math.clamp(math.floor(ConfigNumber(DropdownConfig, "MaxVisibleOptions")), 3, 12)

local AnimationConfig = ConfigSection("Animation")
AnimationDefault = math.max(0, ConfigNumber(AnimationConfig, "Default"))
AnimationWindow = math.max(0, ConfigNumber(AnimationConfig, "Window"))
AnimationTopBar = math.max(0, ConfigNumber(AnimationConfig, "TopBar"))
local AnimationTabOpen = math.max(0, ConfigNumber(AnimationConfig, "TabOpen"))
AnimationTab = math.max(0, ConfigNumber(AnimationConfig, "Tab"))
AnimationToggle = math.max(0, ConfigNumber(AnimationConfig, "Toggle"))
AnimationDropdown = math.max(0, ConfigNumber(AnimationConfig, "Dropdown"))
AnimationDropdownPosition = math.max(0, ConfigNumber(AnimationConfig, "DropdownPosition"))
local AnimationSlider = math.max(0, ConfigNumber(AnimationConfig, "Slider"))
local AnimationDialog = math.max(0, ConfigNumber(AnimationConfig, "Dialog"))
local AnimationDialogFade = math.max(0, ConfigNumber(AnimationConfig, "DialogFade"))

Library.Save.UISize = {DefaultWidth, DefaultHeight}
Library.Save.TabSize = DefaultTabSize
Library.Save.Keybind = DefaultKeybind
Library.Save.KeybindIcon = Library._KeybindSettings.DefaultIcon
Library.Save.KeybindWidth = Library._KeybindSettings.DefaultWidth
Library.Save.KeybindHighlight = Library._KeybindSettings.DefaultHighlight
Library.Save.KeybindRightClick = Library._KeybindSettings.DefaultRightClick
Library.Save.Transparency = DefaultTransparency
Library.Save.Draggable = Draggable
Library.Save.Resizable = Resizable
Library.Save.TabResizable = TabResizable
Library.Save.MinimizedWidth = DefaultMinimizedWidth
Library.Save.ScrollThickness = ScrollThickness
Library.Save.ScrollTransparency = ScrollTransparency
Library.Save.SectionIndicator = LibraryConfig.Section.Indicator == true
Library.Save.ShowFloatingMinimizeButton = true
Library.Save.UnlockCursorOnOpen = true
Library.Save.CameraWithRightMouseButton = true
Library.Save.UnlockCursorWhenMinimized = false
Library.Save.SavePosition = LibraryConfig.SavePosition ~= false
Library.Save.Positions = {}
Library.Save.SectionHeight = math.clamp(ConfigNumber(LibraryConfig.Section, "Height"), 16, 28)
Library.Save.SectionTextSize = math.clamp(ConfigNumber(LibraryConfig.Section, "TextSize"), 9, 16)
Library.Save.SectionThickness = math.clamp(ConfigNumber(LibraryConfig.Section, "Thickness"), 2, 8)
Library.Save.SectionIndicatorHeight = math.clamp(ConfigNumber(LibraryConfig.Section, "IndicatorHeight"), 6, 20)
Library.Save.SectionSpacing = math.clamp(ConfigNumber(LibraryConfig.Section, "Spacing"), 2, 14)
Library.Save.BackgroundImage = DefaultBackgroundImage
Library.Save.BackgroundPreset = DefaultBackgroundPreset
Library.Save.BackgroundImageTransparency = DefaultBackgroundImageTransparency
Library.Save.BackgroundScale = DefaultBackgroundScale
Library.Save.BackgroundEnabled = BackgroundConfig.Enabled ~= false
Library.Save.BackgroundImageBrightness = math.clamp(tonumber(BackgroundConfig.ImageBrightness) or 100, 0, 100)
Library.Save.BackgroundTileSize = math.clamp(math.floor((tonumber(BackgroundConfig.TileSize) or 128) + 0.5), 32, 512)
Library.Save.SoundEnabled = DefaultSoundEnabled
Library.Save.SoundVolume = DefaultSoundVolume
Library.Save.SoundId = DefaultSoundId
Library.Save.DropdownSearch = DefaultDropdownSearch
Library.Save.DropdownPrefixOnly = DefaultDropdownPrefixOnly
Library.Save.DropdownCloseOnSelect = DefaultDropdownCloseOnSelect
Library.Save.DropdownMaxVisibleOptions = DefaultDropdownMaxVisibleOptions

Library.Save.Theme = RootTheme
Library.Save.Language = assert(RootConfig.Language.Default, "Config.Language.Default is required.")
Library.Save.StartupGreetingDismissed = false

if type(Hub) == "table" and type(Hub.GetLanguage) == "function" then
    Library.Save.Language = Hub:GetLanguage()
end
end

local Settings = Library.Settings
local Flags = Library.Flags
local UIScale = ConfigNumber(LibraryConfig, "Scale")
local RequestedScale = UIScale
local OrderedParents = setmetatable({}, {__mode = "k"})

local LoadedSettingKeys = {}

local JsonFiles = {}
function JsonFiles.Read(Path)
    if type(Hub) ~= "table" or type(Hub.ReadFile) ~= "function"
        or type(Hub.FileExists) ~= "function" or not Hub:FileExists(Path) then
        return nil
    end
    local Source = Hub:ReadFile(Path)
    if type(Source) ~= "string" then return nil end
    local Success, Decoded = pcall(HttpService.JSONDecode, HttpService, Source)
    return Success and type(Decoded) == "table" and Decoded or nil
end

function JsonFiles.Write(Path, Data)
    if type(Hub) ~= "table" or type(Hub.CreateFile) ~= "function" then return false end
    local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Data)
    if not Success then return false end
    return Hub:CreateFile(Path, Encoded) == true, Encoded
end

local DropdownFavorites, SaveDropdownFavorites, SetProps, InsertTheme, Create do
DropdownFavorites = {}
local LegacyDropdownFavorites
local CreatedInstancesInBatch = 0
local InstanceBatchSize = 24
local InstanceBatchStartedAt = os.clock()
local InstanceBatchBudget = 0.005

local function NormalizeFavoriteOptions(Values)
    if type(Values) ~= "table" then return nil end
    local Result = {}
    for Key, Value in pairs(Values) do
        if type(Key) == "number" and type(Value) == "string" and Value ~= "" then
            Result[Value] = true
        elseif type(Key) == "string" and Value == true then
            Result[Key] = true
        end
    end
    return next(Result) and Result or nil
end

local function ReadDropdownFavorites(Data)
    if type(Data) ~= "table" then return end

    if type(Data.Hubs) == "table" then
        for HubName, Tabs in pairs(Data.Hubs) do
            if type(HubName) == "string" and type(Tabs) == "table" then
                for TabName, Groups in pairs(Tabs) do
                    if type(TabName) == "string" and type(Groups) == "table" then
                        for _, GroupName in ipairs({"Flags", "Names"}) do
                            local Group = Groups[GroupName]
                            if type(Group) == "table" then
                                for DropdownName, Values in pairs(Group) do
                                    if type(DropdownName) == "string" then
                                        local Favorites = NormalizeFavoriteOptions(Values)
                                        if Favorites then
                                            DropdownFavorites[HubName] = DropdownFavorites[HubName] or {}
                                            local HubFavorites = DropdownFavorites[HubName]
                                            HubFavorites[TabName] = HubFavorites[TabName] or {}
                                            HubFavorites[TabName][GroupName] = HubFavorites[TabName][GroupName] or {}
                                            HubFavorites[TabName][GroupName][DropdownName] = Favorites
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return
    end

    for Key, Values in pairs(Data) do
        if type(Key) == "string" then
            local Prefix, Kind, Name, Index = Key:match("^(.*)/(%a+):(.+)#(%d+)$")
            local HubName, TabName
            if Prefix then HubName, TabName = Prefix:match("^(.*)/([^/]+)$") end
            local Favorites = NormalizeFavoriteOptions(Values)
            if HubName and HubName ~= "" and (Kind == "flag" or Kind == "name") and Favorites then
                local GroupName = Kind == "flag" and "Flags" or "Names"
                local DropdownName = Name .. (tonumber(Index) == 1 and "" or "#" .. Index)
                DropdownFavorites[HubName] = DropdownFavorites[HubName] or {}
                local HubFavorites = DropdownFavorites[HubName]
                HubFavorites[TabName] = HubFavorites[TabName] or {}
                HubFavorites[TabName][GroupName] = HubFavorites[TabName][GroupName] or {}
                HubFavorites[TabName][GroupName][DropdownName] = Favorites
            end
        end
    end
end

local function SerializeDropdownFavorites()
    local Data = {Hubs = {}}
    for HubName, Tabs in pairs(DropdownFavorites) do
        for TabName, Groups in pairs(Tabs) do
            for _, GroupName in ipairs({"Flags", "Names"}) do
                local Group = Groups[GroupName]
                if type(Group) == "table" then
                    for DropdownName, Favorites in pairs(Group) do
                        local Names = {}
                        for Name, Enabled in pairs(Favorites) do
                            if type(Name) == "string" and Enabled == true then
                                Names[#Names + 1] = Name
                            end
                        end
                        if #Names > 0 then
                            table.sort(Names)
                            Data.Hubs[HubName] = Data.Hubs[HubName] or {}
                            local HubData = Data.Hubs[HubName]
                            HubData[TabName] = HubData[TabName] or {}
                            local TabData = HubData[TabName]
                            TabData[GroupName] = TabData[GroupName] or {}
                            TabData[GroupName][DropdownName] = Names
                        end
                    end
                end
            end
        end
    end
    return Data
end

local function FormatFavoritesJSON(Value, Depth)
    if type(Value) ~= "table" then
        return HttpService:JSONEncode(Value)
    end

    local IsArray = #Value > 0
    local Keys = {}
    if IsArray then
        for Index = 1, #Value do Keys[#Keys + 1] = Index end
    else
        for Key in pairs(Value) do Keys[#Keys + 1] = Key end
        table.sort(Keys)
    end

    if #Keys == 0 then return "{}" end
    local Items = {}
    local Indent = string.rep("  ", Depth + 1)
    for _, Key in ipairs(Keys) do
        local Item = FormatFavoritesJSON(Value[Key], Depth + 1)
        if not IsArray then
            Item = HttpService:JSONEncode(Key) .. ": " .. Item
        end
        Items[#Items + 1] = Indent .. Item
    end

    return (IsArray and "[" or "{") .. "\n"
        .. table.concat(Items, ",\n") .. "\n"
        .. string.rep("  ", Depth) .. (IsArray and "]" or "}")
end

SaveDropdownFavorites = function()
    if type(Hub) ~= "table" or type(Hub.CreateFile) ~= "function" then return false end
    local Success, Encoded = pcall(FormatFavoritesJSON, SerializeDropdownFavorites(), 0)
    return Success and Hub:CreateFile(DropdownFavoritesPath, Encoded) == true
end

local SetChildren do
	InsertTheme = function(Instance, Type)
		local Entry = {Instance = Instance, Type = Type}
		table.insert(Library.Instances, Entry)
		Instance.Destroying:Connect(function()
			local Index = table.find(Library.Instances, Entry)
			if Index then table.remove(Library.Instances, Index) end
		end)
		return Instance
	end
	
	SetChildren = function(Instance, Children)
		if Children then
			for _, Child in pairs(Children) do
				Child.Parent = Instance
			end
		end
		return Instance
	end
	
	SetProps = function(Instance, Props)
		if Props then
			for Prop, Value in pairs(Props) do
				if Prop ~= "Name" then
					Instance[Prop] = Value
				end
			end
		end
		return Instance
	end
	
	Create = function(...)
		local args = {...}
		if type(args) ~= "table" then return end
		local new = Hub:CreateInstance(args[1])
		if type(args[2]) == "table" then
			SetProps(new, args[2])
			SetChildren(new, args[3])
		elseif typeof(args[2]) == "Instance" then
			new.Parent = args[2]
			SetProps(new, args[3])
			SetChildren(new, args[4])
		end

        -- The hub manages its own language; prevent Roblox from overriding it.
        if new:IsA("GuiBase2d") then new.AutoLocalize = false end

		if new:IsA("GuiObject") and OrderedParents[new.Parent] ~= nil then
			OrderedParents[new.Parent] += 1
			new.LayoutOrder = OrderedParents[new.Parent]
		end

		-- Large hub scripts can create hundreds of controls in one uninterrupted
		-- call. Yield briefly in bounded batches so Roblox can render between them.
		CreatedInstancesInBatch += 1
		if CreatedInstancesInBatch == 1 then
			InstanceBatchStartedAt = os.clock()
		end
		if CreatedInstancesInBatch >= InstanceBatchSize
			or os.clock() - InstanceBatchStartedAt >= InstanceBatchBudget then
			CreatedInstancesInBatch = 0
			task.wait()
		end
		return new
	end
	
    local function LoadSettings()
        local Decode = JsonFiles.Read(SettingsPath)
        if not Decode then return end
        table.clear(LoadedSettingKeys)

        local function Accept(Key, Value)
            Library.Save[Key] = Value
            LoadedSettingKeys[Key] = true
        end

        -- Missing or invalid fields retain their values from Core/config.lua.
        local NumericRanges = {
            TabSize = {MinTabSize, MaxTabSize},
            Transparency = {0, 100},
            MinimizedWidth = {160, math.min(320, MaxWidth)},
            ScrollThickness = {0, 12},
            ScrollTransparency = {0, 1},
            BackgroundImageTransparency = {0, 100},
            BackgroundImageBrightness = {0, 100},
            BackgroundTileSize = {32, 512},
            SoundVolume = {0, 100},
            DropdownMaxVisibleOptions = {3, 12},
            KeybindWidth = {32, 96},
            SectionHeight = Library.SectionRanges.SectionHeight,
            SectionTextSize = Library.SectionRanges.SectionTextSize,
            SectionThickness = Library.SectionRanges.SectionThickness,
            SectionIndicatorHeight = Library.SectionRanges.SectionIndicatorHeight,
            SectionSpacing = Library.SectionRanges.SectionSpacing
        }
        for Key, Range in pairs(NumericRanges) do
            local Value = tonumber(Decode[Key])
            if Value and Value == Value and math.abs(Value) < math.huge then
                if Key == "DropdownMaxVisibleOptions" then Value = math.floor(Value) end
                if Key == "KeybindWidth" or Key == "BackgroundTileSize" then Value = math.floor(Value + 0.5) end
                Accept(Key, math.clamp(Value, Range[1], Range[2]))
            end
        end
        for _, Key in ipairs({"Draggable", "Resizable", "TabResizable", "BackgroundEnabled", "SoundEnabled", "DropdownSearch", "DropdownPrefixOnly", "DropdownCloseOnSelect", "SectionIndicator", "ShowFloatingMinimizeButton", "KeybindIcon", "KeybindHighlight", "KeybindRightClick", "UnlockCursorOnOpen", "CameraWithRightMouseButton", "UnlockCursorWhenMinimized", "SavePosition", "StartupGreetingDismissed"}) do
            if type(Decode[Key]) == "boolean" then Accept(Key, Decode[Key]) end
        end
        if type(Decode.DropdownFavorites) == "table" then
            LegacyDropdownFavorites = Decode.DropdownFavorites
        end
        if type(Decode.Positions) == "table" then
            local Positions = {}
            for Key, Value in pairs(Decode.Positions) do
                if type(Key) == "string" and (Key == "Window" or Key:match("^Minimize%d+$")) then
                    Positions[Key] = Library._PositionSettings.Normalize(Value, Key == "Window")
                end
            end
            Accept("Positions", Positions)
        end
        if type(Decode.UISize) == "table" then
            local Width, Height = GetPair(Decode.UISize)
            if Width and Height and Width == Width and Height == Height
                and math.abs(Width) < math.huge and math.abs(Height) < math.huge then
                Accept("UISize", {math.clamp(Width, MinWidth, MaxWidth), math.clamp(Height, MinHeight, MaxHeight)})
            end
        end
        if type(Decode.Theme) == "string" and type(Library.Themes[Decode.Theme]) == "table" then
            Accept("Theme", Decode.Theme)
        end
        local KeyCode = GetKeyCode(Decode.Keybind)
        if KeyCode then Accept("Keybind", KeyCode.Name) end
        for _, Key in ipairs({"BackgroundImage", "SoundId"}) do
            if Decode[Key] ~= nil then
                local Id = NormalizeAssetId(Decode[Key])
                if Id ~= nil then Accept(Key, Id) end
            end
        end
        if type(Decode.BackgroundPreset) == "string" then Accept("BackgroundPreset", Decode.BackgroundPreset) end
        if type(Decode.BackgroundScale) == "string" then
            for Name in pairs(BackgroundScaleTypes) do
                if Name:lower() == Decode.BackgroundScale:lower() then Accept("BackgroundScale", Name); break end
            end
        end
        if type(Decode.Language) == "string" and type(Hub) == "table" and type(Hub.SetLanguage) == "function" then
            local Success, Language = Hub:SetLanguage(Decode.Language)
            if Success then Accept("Language", Language) end
        end
    end

	if type(Hub) == "table" and type(Hub.CreateFolder) == "function" then
		Hub:CreateFolder(SettingsFolder)
	end

    Library.DefaultSettings = table.clone(Library.Save)

	pcall(LoadSettings)
    local SavedFavorites = JsonFiles.Read(DropdownFavoritesPath)
    if SavedFavorites then
        ReadDropdownFavorites(SavedFavorites)
    else
        ReadDropdownFavorites(LegacyDropdownFavorites)
    end
    if not SavedFavorites or SavedFavorites.Version ~= 2 then
        task.defer(SaveDropdownFavorites)
    end
    EnsureSoundPreset(Library.Save.SoundId)
	Draggable = Library.Save.Draggable ~= false
	Resizable = Library.Save.Resizable ~= false
	TabResizable = Library.Save.TabResizable ~= false
	ScrollThickness = Library.Save.ScrollThickness
	ScrollTransparency = Library.Save.ScrollTransparency
end
end

local Funcs = {} do
	function Funcs:InsertCallback(tab, func)
		if type(tab) == "table" and type(func) == "function" then
			table.insert(tab, func)
		end
		return func
	end
	
	function Funcs:FireCallback(tab, ...)
		if type(tab) ~= "table" then
			return
		end

		for _, v in ipairs(tab) do
			if type(v) == "function" then
				task.spawn(v, ...)
			end
		end
	end

    function Funcs:NotifyListeners(List, ...)
        for Object, Callback in pairs(List) do
            if type(Callback) ~= "function" or not pcall(Callback, ...) then
                List[Object] = nil
            end
        end
    end
	
	function Funcs:ToggleVisible(Obj, Bool)
		if Bool ~= nil then
			Obj.Visible = Bool
		end
	end

	function Funcs:ToggleParent(Obj, Bool, Parent)
		if Bool == nil then
			Obj.Parent = Obj.Parent and nil or Parent
		else
			Obj.Parent = Bool and Parent or nil
		end
	end
	
	function Funcs:GetConnectionFunctions(ConnectedFuncs, func)
		local Connected = { Function = func, Connected = true }
		
		function Connected:Disconnect()
			if self.Connected then
				local Index = table.find(ConnectedFuncs, self.Function)
				if Index then
					table.remove(ConnectedFuncs, Index)
				end
				self.Connected = false
			end
		end
		
		function Connected:Fire(...)
			if self.Connected then
				task.spawn(self.Function, ...)
			end
		end
		
		return Connected
	end
	
	function Funcs:GetCallback(Configs, index)
		local func = Configs[index] or Configs.Callback or function()end
		
		if type(func) == "table" then
			return ({function(Value) func[1][func[2]] = Value end})
		end
		return {func}
	end
end

local Connections, Connection = {}, Library.Connection do
	local function NewConnectionList(List)
		if type(List) ~= "table" then return end
		
		for _,CoName in ipairs(List) do
			local ConnectedFuncs, Connect = {}, {}
			Connection[CoName] = Connect
			Connections[CoName] = ConnectedFuncs
			Connect.Name = CoName
			
			function Connect:Connect(func)
				if type(func) == "function" then
					table.insert(ConnectedFuncs, func)
					return Funcs:GetConnectionFunctions(ConnectedFuncs, func)
				end
			end
			
			function Connect:Once(func)
				if type(func) == "function" then
					local Connected
					local Fired = false
					local OnceFunction

					OnceFunction = function(...)
						if Fired then
							return
						end
						Fired = true
						Connected:Disconnect()
						task.spawn(func, ...)
					end

					table.insert(ConnectedFuncs, OnceFunction)
					Connected = Funcs:GetConnectionFunctions(ConnectedFuncs, OnceFunction)
					return Connected
				end
			end
		end
	end
	
	function Connection:FireConnection(CoName, ...)
		local Name = type(CoName) == "string" and CoName or type(CoName) == "table" and CoName.Name
		local Callbacks = Name and Connections[Name]
		if not Callbacks then
			return
		end

		for _, Func in ipairs(Callbacks) do
			task.spawn(Func, ...)
		end
	end
	
	NewConnectionList({"FlagsChanged", "ThemeChanged", "LanguageChanged", "FileSaved", "ThemeChanging", "OptionAdded"})
end

local GetFlag, SetFlag, CheckFlag do
	CheckFlag = function(Name)
		return type(Name) == "string" and Flags[Name] ~= nil
	end
	
	GetFlag = function(Name)
		if type(Name) ~= "string" then return nil end
		return Flags[Name]
	end
	
	SetFlag = function(Flag, Value)
		if Flag and (Value ~= Flags[Flag] or type(Value) == "table") then
			Flags[Flag] = Value
			Connection:FireConnection("FlagsChanged", Flag, Value)
		end
	end
	
	local db
	Connection.FlagsChanged:Connect(function(Flag, Value)
		local ScriptFile = Settings.ScriptFile
		if not db and type(ScriptFile) == "string" and ScriptFile ~= "" then
			db = true
			task.wait(math.max(0, ConfigNumber(LibraryConfig, "FlagsSaveDelay")))
			db = false

			local Saved, Encoded = JsonFiles.Write(ScriptFile, Flags)
			if Saved then
				Connection:FireConnection("FileSaved", "Script-Flags", ScriptFile, Encoded)
			end
		end
	end)
end

--// Runtime

local Runtime = {}

if type(Hub) == "table" and type(Hub.GetGenv) == "function" then
    local Genv = Hub:GetGenv()
    Genv.Runtime = Genv.Runtime or {}
    Genv.Runtime.Library = Genv.Runtime.Library or {}
    Runtime = Genv.Runtime.Library
end

if typeof(Runtime.Gui) == "Instance" then
    Runtime.Gui:Destroy()
end
-- Current dialog belongs to the hub-specific Runtime.Library namespace.
Runtime.Dialog = nil
Runtime.DialogOverlay = nil

local RuntimeConnections = {}
local ResponsiveWidth, ResponsiveHeight = table.unpack(Library.Save.UISize)

local function TrackConnection(Connection)
    RuntimeConnections[#RuntimeConnections + 1] = Connection
    return Connection
end

local function UntrackConnection(Connection)
    local Index = table.find(RuntimeConnections, Connection)
    if Index then
        table.remove(RuntimeConnections, Index)
    end
end

local function GetViewportSize()
    local Camera = workspace.CurrentCamera
    return Camera and Camera.ViewportSize or Vector2.new(table.unpack(LibraryConfig.FallbackViewportSize))
end

local function GetInputMode()
    local PreferredInput = UserInputService.PreferredInput

    if PreferredInput == Enum.PreferredInput.Touch then
        return "Touch"
    elseif PreferredInput == Enum.PreferredInput.Gamepad or PreferredInput == Enum.PreferredInput.MicroGamepad then
        return "Gamepad"
    end

    return "KeyboardAndMouse"
end

local function IsCompactDisplay()
    if not ResponsiveEnabled then
        return false
    end

    local Viewport = GetViewportSize()
    return GuiService.ViewportDisplaySize == Enum.DisplaySize.Small
        or Viewport.X <= CompactBreakpoint
end

local function GetResponsivePadding()
    return IsCompactDisplay() and SmallScreenPadding or ScreenPadding
end

local function GetTopbarButtonSize()
    return GetInputMode() == "Touch" and TouchTopbarButtonSize or DesktopTopbarButtonSize
end

local function CalculateScale(Width, Height)
    return RequestedScale
end

UIScale = CalculateScale(ResponsiveWidth, ResponsiveHeight)

local ScreenScale = Create("UIScale", {
    Scale = UIScale
})

local GuiContainer = Hub:GetGuiContainer()
local ScreenGui = Create("ScreenGui", GuiContainer, {
    Archivable = false,
    ResetOnSpawn = false,
    AutoLocalize = false,
    ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, {
    ScreenScale
})

Runtime.Gui = ScreenGui
Library.Window = ScreenGui

local LibraryResources = Create("Folder", ScreenGui, {Archivable = false})
Library.Resources = LibraryResources

local UISound = Create("Sound", LibraryResources, {
    SoundId = ToAssetContentId(Library.Save.SoundId),
    Volume = (Library.Save.SoundVolume or DefaultSoundVolume) / 100
})

local function PreviewUISound()
    local SoundId = ToAssetContentId(Library.Save.SoundId)
    if SoundId == "" then
        return
    end

    UISound:Stop()
    UISound.SoundId = SoundId
    UISound.Volume = math.clamp((tonumber(Library.Save.SoundVolume) or DefaultSoundVolume) / 100, 0, 1)
    UISound.TimePosition = 0
    pcall(SoundService.PlayLocalSound, SoundService, UISound)
end

local function PlayUISound()
    if Library.Save.SoundEnabled then
        PreviewUISound()
    end
end

local CameraConnection

local function UpdateResponsiveScale()
    local NewScale = CalculateScale(ResponsiveWidth, ResponsiveHeight)
    if UIScale == NewScale then
        return
    end

    UIScale = NewScale
    ScreenScale.Scale = NewScale
end

local function BindCamera()
    if CameraConnection then
        CameraConnection:Disconnect()
        CameraConnection = nil
    end

    local Camera = workspace.CurrentCamera
    if Camera then
        CameraConnection = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateResponsiveScale)
    end

    UpdateResponsiveScale()
end

TrackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindCamera))
TrackConnection(GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(UpdateResponsiveScale))
TrackConnection(UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(UpdateResponsiveScale))
BindCamera()

ScreenGui.Destroying:Connect(function()
    UISound:Destroy()
    if Library._BackgroundSettings then
        Library._BackgroundSettings.Generation += 1
        Library._BackgroundSettings.Sync = nil
        Library._BackgroundSettings.Owner = nil
    end
    if CameraConnection then
        CameraConnection:Disconnect()
        CameraConnection = nil
    end

    for _, Connection in ipairs(RuntimeConnections) do
        if Connection.Connected then
            Connection:Disconnect()
        end
    end

    table.clear(RuntimeConnections)

    for _, Callbacks in pairs(Connections) do
        table.clear(Callbacks)
    end

    table.clear(Library.Instances)
    table.clear(Library.Options)
    table.clear(Library.Tabs)

    task.defer(function()
        if Runtime.GuiContainer == GuiContainer
            and typeof(GuiContainer) == "Instance" and GuiContainer:IsA("Folder")
            and GuiContainer.Parent
            and #GuiContainer:GetChildren() == 0 then
            Runtime.GuiContainer = nil
            GuiContainer:Destroy()
        end
    end)

    if Runtime.Gui == ScreenGui then
        Runtime.Gui = nil
    end
end)

local function FirstDefined(...)
	for Index = 1, select("#", ...) do
		local Value = select(Index, ...)
		if Value ~= nil then return Value end
	end
end

local function DisplayString(Value)
	if Value == nil then return "" end
	return tostring(Value)
end

local function GetStr(val)
    if type(val) == "function" then
        return val()
    end
    return val
end

local CreateTween do
local TweenInfoCache = {}
CreateTween = function(Configs)
    local Instance = Configs[1] or Configs.Instance
    local Prop = Configs[2] or Configs.Prop
    local NewVal = Configs[3]
    if NewVal == nil then NewVal = Configs.NewVal end
    local Time = Configs[4] or Configs.Time or AnimationDefault
    local TweenWait = Configs[5] or Configs.wait or false
    local Info = TweenInfoCache[Time]
    if not Info then
        Info = TweenInfo.new(Time, Enum.EasingStyle.Quint)
        TweenInfoCache[Time] = Info
    end

    local Tween = TweenService:Create(Instance, Info, {[Prop] = NewVal})
    Tween:Play()
    if TweenWait then
        Tween.Completed:Wait()
    end
    return Tween
end
end

local function MakeDrag(Instance, Options)
    Options = type(Options) == "table" and Options or {}

    local Handle = typeof(Options.Handle) == "Instance" and Options.Handle or Instance
    local CanStart = type(Options.CanStart) == "function" and Options.CanStart or nil
    local Threshold = math.max(0, tonumber(Options.Threshold) or DragThreshold)
    local GlobalInput = Options.GlobalInput == true
    local ShouldCancel = type(Options.ShouldCancel) == "function" and Options.ShouldCancel or nil
    local Move = type(Options.Move) == "function" and Options.Move or nil
    local MoveTo = type(Options.MoveTo) == "function" and Options.MoveTo or nil
    local PrepareMove = type(Options.PrepareMove) == "function" and Options.PrepareMove or nil
    local OnStop = type(Options.OnStop) == "function" and Options.OnStop or nil

    Handle.Active = true
    if Handle:IsA("GuiButton") then
        Handle.AutoButtonColor = false
    end

    local Dragging = false
    local DragInput
    local DragStart
    local LastPointer
    local GrabOffset
    local PassedThreshold = false
    local MovementThreshold = Threshold
    local MoveContext
    local MovementConnection
    local StateConnection

    local function IsAvailable()
        if not ScreenGui.Enabled or not Instance.Parent or not Handle.Parent then return false end
        local Current = Handle
        while Current and Current ~= ScreenGui do
            if Current:IsA("GuiObject") and not Current.Visible then return false end
            Current = Current.Parent
        end
        return Current == ScreenGui and Instance.Visible
    end

    local function GetPointer()
        if DragInput.UserInputType == Enum.UserInputType.Touch then
            local Position = DragInput.Position
            return Vector2.new(Position.X, Position.Y)
        end
        -- InputObject.Position and AbsolutePosition use CoreUISafeInsets coordinates.
        return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
    end

    local function StopDrag()
        local RememberPosition = Dragging and PassedThreshold
        if MovementConnection then
            MovementConnection:Disconnect()
            UntrackConnection(MovementConnection)
            MovementConnection = nil
        end
        if StateConnection then
            StateConnection:Disconnect()
            UntrackConnection(StateConnection)
            StateConnection = nil
        end
        Dragging = false
        DragInput = nil
        DragStart = nil
        LastPointer = nil
        GrabOffset = nil
        PassedThreshold = false
        MoveContext = nil
        -- Persist once per gesture instead of allocating and queuing a save each frame.
        if RememberPosition and OnStop then
            OnStop()
        end
    end

    local function Update()
        if not Dragging or not DragStart or not LastPointer then
            return
        end
        if not IsAvailable() or (ShouldCancel and ShouldCancel()) then
            StopDrag()
            return
        end

        local Pointer = GetPointer()
        if not PassedThreshold then
            if (Pointer - DragStart).Magnitude < MovementThreshold then return end
            PassedThreshold = true
        end

        if MoveTo and GrabOffset then
            if Pointer == LastPointer then return end
            LastPointer = Pointer
            MoveContext = MoveTo(Pointer - GrabOffset, MoveContext) or MoveContext
            return
        end

        local Delta = Pointer - LastPointer
        LastPointer = Pointer
        if Delta.Magnitude == 0 then return end
        if Move then
            MoveContext = Move(Delta, MoveContext) or MoveContext
            return
        end
        local Position = Instance.Position
        local Scale = math.max(ScreenScale.Scale, 0.001)
        Instance.Position = UDim2.new(
            Position.X.Scale, Position.X.Offset + Delta.X / Scale,
            Position.Y.Scale, Position.Y.Offset + Delta.Y / Scale
        )
    end

    local function Begin(Input)
        if Dragging or not IsAvailable() then return end
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if Input.UserInputState == Enum.UserInputState.End or Input.UserInputState == Enum.UserInputState.Cancel then return end

        if ShouldCancel and ShouldCancel() then
            return
        end

        if CanStart and not CanStart(Input) then
            return
        end

        Dragging = true
        DragInput = Input
        local Pointer = GetPointer()
        DragStart = Pointer
        LastPointer = Pointer
        GrabOffset = MoveTo and Input.UserInputType == Enum.UserInputType.MouseButton1
            and (Pointer - Instance.AbsolutePosition) or nil
        PassedThreshold = false
        MovementThreshold = Input.UserInputType == Enum.UserInputType.Touch and math.max(Threshold, 6) or Threshold
        MoveContext = PrepareMove and PrepareMove() or nil
        local function CheckInputState()
            if not Dragging then return end
            if Input.UserInputState == Enum.UserInputState.Cancel then
                StopDrag()
            elseif Input.UserInputState == Enum.UserInputState.End then
                Update()
                StopDrag()
            end
        end
        StateConnection = TrackConnection(Input:GetPropertyChangedSignal("UserInputState"):Connect(CheckInputState))
        -- Update only when the pointer actually moves. A RenderStepped poll was
        -- doing GUI work even on frames where the cursor had not changed.
        MovementConnection = TrackConnection(UserInputService.InputChanged:Connect(function(ChangedInput)
            if not Dragging then return end
            CheckInputState()
            if not Dragging then return end

            local IsMouseMove = Input.UserInputType == Enum.UserInputType.MouseButton1
                and ChangedInput.UserInputType == Enum.UserInputType.MouseMovement
            local IsTouchMove = Input.UserInputType == Enum.UserInputType.Touch and ChangedInput == Input
            if not IsMouseMove and not IsTouchMove then return end
            if ShouldCancel and ShouldCancel() then
                StopDrag()
                return
            end
            Update()
        end))
    end

    TrackConnection(Handle.InputBegan:Connect(Begin))
    if GlobalInput then
        TrackConnection(UserInputService.InputBegan:Connect(Begin))
    end

    TrackConnection(UserInputService.InputEnded:Connect(function(Input)
        if not Dragging then
            return
        end

        if Input == DragInput then
            if Input.UserInputState ~= Enum.UserInputState.Cancel then Update() end
            StopDrag()
        end
    end))

    TrackConnection(UserInputService.WindowFocusReleased:Connect(StopDrag))
    TrackConnection(ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if not ScreenGui.Enabled then StopDrag() end
    end))
    TrackConnection(Instance:GetPropertyChangedSignal("Visible"):Connect(function()
        if not Instance.Visible then StopDrag() end
    end))
    TrackConnection(Instance.Destroying:Connect(StopDrag))

    return Instance
end

local function VerifyTheme(Theme)
    return type(Theme) == "string" and type(Library.Themes[Theme]) == "table"
end

local QueueSettingsSave do
local SaveJson = JsonFiles.Write

local SettingsSaveQueued = false
local SettingsLastChange = 0
local SettingsSaveDelay = math.max(0, ConfigNumber(LibraryConfig, "SettingsSaveDelay"))
local function FlushSettingsWhenIdle()
    if not SettingsSaveQueued then return end
    local Remaining = SettingsSaveDelay - (os.clock() - SettingsLastChange)
    if Remaining > 0 then
        task.delay(math.max(Remaining, 0.05), FlushSettingsWhenIdle)
        return
    end
    SettingsSaveQueued = false
    SaveJson(SettingsPath, Library.Save)
end

QueueSettingsSave = function()
    SettingsLastChange = os.clock()
    if SettingsSaveQueued then return end
    SettingsSaveQueued = true
    task.delay(SettingsSaveDelay, FlushSettingsWhenIdle)
end

function Library:IsStartupGreetingDismissed()
    return Library.Save.StartupGreetingDismissed == true
end

function Library:SetStartupGreetingDismissed(Value)
    if type(Value) ~= "boolean" then return false end
    local Previous = Library.Save.StartupGreetingDismissed
    Library.Save.StartupGreetingDismissed = Value
    -- Persist immediately; the dialog may be the final interaction before closing.
    local Success = SaveJson(SettingsPath, Library.Save)
    if not Success then
        Library.Save.StartupGreetingDismissed = Previous
    end
    return Success
end

ScreenGui.Destroying:Connect(function()
    for _, State in pairs(Library._PositionSettings.Bindings) do State:Remember() end
    if not SettingsSaveQueued then return end
    SettingsSaveQueued = false
    SaveJson(SettingsPath, Library.Save)
end)
end

-- Positions are stored as viewport fractions, independently of the interface scale.
function Library._PositionSettings.GetBounds(Object, Padding, TopPadding, Oversized)
    local Origin, Available, Size = ScreenGui.AbsolutePosition, ScreenGui.AbsoluteSize, Object.AbsoluteSize
    local function Bounds(Start, Length, Extent, LeadingPadding, Vertical)
        if Extent >= Length then
            if Oversized then
                if Vertical then
                    local Header = math.min(Length, TopBarHeight * math.max(ScreenScale.Scale, 0.001))
                    return Start + math.min(LeadingPadding, Length - Header), Start + Length - Header
                end
                return Start + Length - Extent, Start
            end
            local Center = Start + (Length - Extent) / 2
            return Center, Center
        end
        local Margin = math.min(Padding, (Length - Extent) / 2)
        local LeadingMargin = math.min(LeadingPadding, (Length - Extent) / 2)
        return Start + LeadingMargin, Start + Length - Extent - Margin
    end
    local MinX, MaxX = Bounds(Origin.X, Available.X, Size.X, Padding)
    local MinY, MaxY = Bounds(Origin.Y, Available.Y, Size.Y, math.max(0, tonumber(TopPadding) or Padding), true)
    return MinX, MinY, MaxX, MaxY
end

function Library._PositionSettings.Bind(Object, Key, Options)
    Options = Options or {}
    local State = {Object = Object, Initialized = false, Destroyed = false, Busy = false, BoundsRevision = 0}
    local Connections = {}
    local InitialPosition = Object.Position
    local Padding = math.max(0, tonumber(Options.Padding) or 6)

    function State:Move(Target)
        if self.Destroyed or not Object.Parent then return end
        local Delta = Target - Object.AbsolutePosition
        if Delta.Magnitude < 0.01 then return end
        local Position, Scale = Object.Position, math.max(ScreenScale.Scale, 0.001)
        self.Busy = true
        Object.Position = UDim2.new(
            Position.X.Scale, Position.X.Offset + Delta.X / Scale,
            Position.Y.Scale, Position.Y.Offset + Delta.Y / Scale
        )
        self.Busy = false
    end

    function State:Clamp()
        local MinX, MinY, MaxX, MaxY = Library._PositionSettings.GetBounds(Object, Padding, Options.TopPadding, Options.Oversized)
        local Position = Object.AbsolutePosition
        self:Move(Vector2.new(math.clamp(Position.X, MinX, MaxX), math.clamp(Position.Y, MinY, MaxY)))
    end

    function State:MoveBy(Delta, Bounds)
        if self.Destroyed or not Object.Parent then return end
        if not self.Initialized then self:Initialize() end
        if type(Bounds) ~= "table" or Bounds.Revision ~= self.BoundsRevision then
            Bounds = self:GetDragBounds()
        end
        local Target = Object.AbsolutePosition + Delta
        -- Clamp before writing Position, so drag and the position observer never
        -- compete over an out-of-bounds intermediate value.
        self:Move(Vector2.new(
            math.clamp(Target.X, Bounds.MinX, Bounds.MaxX),
            math.clamp(Target.Y, Bounds.MinY, Bounds.MaxY)
        ))
        return Bounds
    end

    function State:GetDragBounds()
        if self.Destroyed or not Object.Parent then return nil end
        self:Initialize()
        local MinX, MinY, MaxX, MaxY = Library._PositionSettings.GetBounds(Object, Padding, Options.TopPadding, Options.Oversized)
        return {
            MinX = MinX,
            MinY = MinY,
            MaxX = MaxX,
            MaxY = MaxY,
            Revision = self.BoundsRevision
        }
    end

    function State:MoveGrabbedTo(Target, Bounds)
        if self.Destroyed or not Object.Parent then return end
        if not self.Initialized then self:Initialize() end
        -- Reuse per-gesture bounds; Refresh invalidates them when screen geometry changes.
        if type(Bounds) ~= "table" or Bounds.Revision ~= self.BoundsRevision then
            Bounds = self:GetDragBounds()
        end
        self:Move(Vector2.new(
            math.clamp(Target.X, Bounds.MinX, Bounds.MaxX),
            math.clamp(Target.Y, Bounds.MinY, Bounds.MaxY)
        ))
        return Bounds
    end

    function State:Remember()
        if self.Destroyed or not self.Initialized or not Library.Save.SavePosition or not Object.Parent then return end
        local Available, Origin, Position = ScreenGui.AbsoluteSize, ScreenGui.AbsolutePosition, Object.AbsolutePosition
        if Available.X <= 0 or Available.Y <= 0 then return end
        local Value = {
            X = Options.Oversized and (Position.X - Origin.X) / Available.X
                or math.clamp((Position.X - Origin.X) / Available.X, 0, 1),
            Y = math.clamp((Position.Y - Origin.Y) / Available.Y, 0, 1)
        }
        local Previous = Library.Save.Positions[Key]
        if Previous and math.abs(Previous.X - Value.X) < 0.000001
            and math.abs(Previous.Y - Value.Y) < 0.000001 then return end
        Library.Save.Positions[Key] = Value
        QueueSettingsSave()
    end

    function State:ScheduleRemember()
        if self.Pending or self.Destroyed then return end
        self.Pending = true
        task.defer(function()
            self.Pending = false
            self:Remember()
        end)
    end

    function State:Restore(Value)
        local Available, Origin = ScreenGui.AbsoluteSize, ScreenGui.AbsolutePosition
        self:Move(Vector2.new(Origin.X + Value.X * Available.X, Origin.Y + Value.Y * Available.Y))
        self:Clamp()
    end

    function State:Reset()
        if self.Destroyed or not Object.Parent then return end
        if Options.Randomize and not Library.Save.SavePosition then
            local MinX, MinY, MaxX, MaxY = Library._PositionSettings.GetBounds(Object, Padding, Options.TopPadding)
            self:Move(Vector2.new(MinX + math.random() * (MaxX - MinX), MinY + math.random() * (MaxY - MinY)))
        elseif Options.Center then
            self:Move(ScreenGui.AbsolutePosition + (ScreenGui.AbsoluteSize - Object.AbsoluteSize) / 2)
        else
            self.Busy = true
            Object.Position = InitialPosition
            self.Busy = false
        end
        self:Clamp()
        self:ScheduleRemember()
    end

    function State:Initialize()
        if self.Initialized or self.Destroyed or not Object.Parent then return end
        if ScreenGui.AbsoluteSize.X <= 0 or ScreenGui.AbsoluteSize.Y <= 0
            or Object.AbsoluteSize.X <= 0 or Object.AbsoluteSize.Y <= 0 then return end
        local Saved = Library.Save.SavePosition and Library.Save.Positions[Key]
        if Saved then self:Restore(Saved) else self:Reset() end
        self.Initialized = true
        self:ScheduleRemember()
    end

    local function Refresh()
        if State.Destroyed then return end
        State.BoundsRevision += 1
        if not State.Initialized then
            State:Initialize()
            return
        end
        local Saved = Library.Save.SavePosition and Library.Save.Positions[Key]
        if Saved then State:Restore(Saved) else State:Clamp() end
    end
    local function RefreshAfterSizeSettles()
        if State.Destroyed then return end
        State.BoundsRevision += 1
        State.SizeChangedAt = os.clock()
        if State.SizeRefreshPending then return end
        State.SizeRefreshPending = true

        local function FlushWhenSettled()
            if State.Destroyed then
                State.SizeRefreshPending = false
                return
            end
            local Remaining = 0.12 - (os.clock() - State.SizeChangedAt)
            if Remaining > 0 then
                task.delay(Remaining, FlushWhenSettled)
                return
            end
            State.SizeRefreshPending = false
            -- Window minimize/restore animates AbsoluteSize every frame. Clamping
            -- every tick writes Position repeatedly and competes with the tween.
            -- Wait for the resize to settle, then clamp once.
            if State.Initialized then State:Clamp() else State:Initialize() end
        end
        task.delay(0.12, FlushWhenSettled)
    end
    local function Connect(Signal, Callback)
        table.insert(Connections, Signal:Connect(Callback))
    end
    function State:Destroy()
        if self.Destroyed then return end
        self:Remember()
        self.Destroyed = true
        Library._PositionSettings.Bindings[Object] = nil
        for _, Item in ipairs(Connections) do Item:Disconnect() end
        table.clear(Connections)
    end

    Connect(Object:GetPropertyChangedSignal("Position"), function()
        if State.Busy or not State.Initialized then return end
        State:Clamp()
        State:ScheduleRemember()
    end)
    Connect(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), Refresh)
    Connect(ScreenGui:GetPropertyChangedSignal("AbsolutePosition"), Refresh)
    Connect(ScreenScale:GetPropertyChangedSignal("Scale"), Refresh)
    Connect(Object:GetPropertyChangedSignal("AbsoluteSize"), RefreshAfterSizeSettles)
    Connect(Object.Destroying, function() State:Destroy() end)
    Library._PositionSettings.Bindings[Object] = State
    task.defer(function() State:Initialize() end)
    return State
end

function Library:GetSavePosition()
    return Library.Save.SavePosition == true
end

function Library:SetSavePosition(Value)
    if type(Value) ~= "boolean" then return false end
    if Library.Save.SavePosition == Value then return true end
    Library.Save.SavePosition = Value
    if Value then
        for _, State in pairs(Library._PositionSettings.Bindings) do State:Remember() end
    else
        Library.Save.Positions = {}
    end
    QueueSettingsSave()
    return true
end

function Library:ResetPositions()
    Library.Save.Positions = {}
    for _, State in pairs(Library._PositionSettings.Bindings) do State:Reset() end
    QueueSettingsSave()
end

Library.Transparency = Library.Save.Transparency

local Theme = Library.Themes[Library.Save.Theme]

if type(Hub) == "table" and type(Hub.SetTheme) == "function" then
    Hub:SetTheme(Library.Save.Theme)
end

local function AddEle(Name, Func)
	Library.Elements[Name] = Func
end

local function Make(Ele, Instance, props, ...)
	local Element = Library.Elements[Ele](Instance, props, ...)
	return Element
end

local function BindHover(Object, Property, HoverValue, IdleValue)
    Object.MouseEnter:Connect(function() Object[Property] = HoverValue end)
    Object.MouseLeave:Connect(function() Object[Property] = IdleValue end)
    return Object
end

AddEle("Corner", function(parent, Radius)
	local New = Create("UICorner", parent, {
		CornerRadius = Radius or UDim.new(0, CornerRadius)
	})
	return New
end)

AddEle("Stroke", function(parent, props, ...)
	local args = {...}
	local New = InsertTheme(SetProps(Create("UIStroke", parent, {
		Color = args[1] or Theme["Color Stroke"],
		Thickness = args[2] or StrokeThickness,
		Transparency = StrokeTransparency,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	}), props), "Stroke")
	return New
end)

AddEle("Button", function(parent, props, ...)
	local args = {...}
	local New = InsertTheme(SetProps(Create("TextButton", parent, {
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme["Color Hub 2"],
		AutoButtonColor = false
	}), props), "Frame")
	
	BindHover(New, "BackgroundTransparency", ButtonHoverTransparency, 0)
	if args[1] then
		New.Activated:Connect(args[1])
	end
	return New
end)

-- Share the same theme colors across window and component backgrounds.
local function ThemeBackgroundColors()
	local Stops = Theme["Color Hub 1"].Keypoints
	local Start = Stops[1].Value
	return ColorSequence.new(Start, Start:Lerp(Stops[math.ceil(#Stops / 2)].Value, 0.75))
end

AddEle("Gradient", function(parent, props, ...)
	local args = {...}
	local New = InsertTheme(SetProps(Create("UIGradient", parent, {
		Color = ThemeBackgroundColors()
	}), props), "Gradient")
	return New
end)

local TranslateText

-- Muted theme surfaces avoid the washed-out white overlay on saturated themes.
local function ComponentColor()
	local Base = Theme["Color Hub 2"]
	local Gray = Base.R * 0.2126 + Base.G * 0.7152 + Base.B * 0.0722
	return Base:Lerp(Color3.new(Gray, Gray, Gray), 0.65):Lerp(Color3.new(1, 1, 1), 0.025)
end

local function InputSurfaceColor()
	-- A small lift from the panel surface, without the stronger control accent.
	return ComponentColor():Lerp(Color3.new(1, 1, 1), 0.035)
end

local function InputSurface(Frame)
	Frame.BackgroundColor3 = InputSurfaceColor()
	Frame.BackgroundTransparency = 0
	InsertTheme(Frame, "InputSurface")
	return Frame
end

local function ComponentSurface(Frame)
	Frame.BackgroundColor3 = ComponentColor()
	Frame.BackgroundTransparency = 0.18
	InsertTheme(Frame, "ComponentSurface")
	BindHover(Frame, "BackgroundTransparency", 0.18 * ButtonHoverTransparency, 0.18)
	return Frame
end

local function ButtonFrame(Instance, Title, Description, HolderSize, Clickable)
	local TitleL = InsertTheme(Create("TextLabel", {
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -20),
		AutomaticSize = "Y",
		Position = UDim2.new(0, 0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		TextTruncate = "AtEnd",
		TextSize = ElementTitleTextSize,
		TextXAlignment = "Left",
		Text = "",
		RichText = true
	}), "TitleText")
	
	local DescL = InsertTheme(Create("TextLabel", {
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(180, 180, 188),
		Size = UDim2.new(1, -20),
		AutomaticSize = "Y",
		Position = UDim2.new(0, ElementHorizontalPadding + 2, 0, ElementVerticalPadding * 3),
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextSize = ElementDescriptionTextSize,
		TextXAlignment = "Left",
		Text = "",
		RichText = true
	}), "DescriptionText")

	local Frame = ComponentSurface(Create(Clickable == false and "Frame" or "TextButton", Instance, {
		Size = UDim2.new(1, 0, 0, ElementHeight),
		AutomaticSize = "Y",
	}))
	if Clickable ~= false then
		Frame.Text = ""
		Frame.AutoButtonColor = false
	end
	Make("Corner", Frame, UDim.new(0, ElementCornerRadius))
	
	TitleL.LayoutOrder = 1
	DescL.LayoutOrder = 2
	local LabelHolder = Create("Frame", Frame, {
		AutomaticSize = "Y",
		BackgroundTransparency = 1,
		Size = HolderSize,
		Position = UDim2.new(0, ElementHorizontalPadding, 0),
		AnchorPoint = Vector2.new(0, 0)
	}, {
		Create("UIListLayout", {
			SortOrder = "LayoutOrder",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, ElementSpacing)
		}),
		Create("UIPadding", {
			PaddingBottom = UDim.new(0, ElementVerticalPadding),
			PaddingTop = UDim.new(0, ElementVerticalPadding)
		}),
		TitleL,
		DescL,
	})
	
	local Label = {}
	function Label:SetTitle(NewTitle)
		if NewTitle == false then NewTitle = "false" end
		if type(NewTitle) == "string" and NewTitle:gsub(" ", ""):len() > 0 then
			TitleL.Text = TranslateText and TranslateText(NewTitle) or NewTitle
		end
	end
	function Label:SetDesc(NewDesc)
		if NewDesc == false then NewDesc = "false" end
		if type(NewDesc) == "string" and NewDesc:gsub(" ", ""):len() > 0 then
			DescL.Visible = true
			DescL.Text = TranslateText and TranslateText(NewDesc) or NewDesc
			LabelHolder.Position = UDim2.new(0, ElementHorizontalPadding, 0)
			LabelHolder.AnchorPoint = Vector2.new(0, 0)
		else
			DescL.Visible = false
			DescL.Text = ""
			LabelHolder.Position = UDim2.new(0, ElementHorizontalPadding, 0.5)
			LabelHolder.AnchorPoint = Vector2.new(0, 0.5)
		end
	end
	
	Label:SetTitle(Title)
	Label:SetDesc(Description)
	function Label:SetReservedWidth(Width)
		LabelHolder.Size = UDim2.new(1, -Width, 0, 0)
	end
	return Frame, Label
end

--// Locked

local LibraryNotification = {Token = 0}

TranslateText = function(Text, Values)
	local Result = Text

	if type(Hub) == "table" and type(Hub.Translate) == "function" then
		Result = Hub:Translate(Text)
	end

	if type(Values) == "table" and type(Hub) == "table" and type(Hub.Format) == "function" then
		Result = Hub:Format(Result, Values)
	end

	return Result
end

local function RefreshTranslations()
	local Updated = {}

	local function RefreshObject(Object)
		if typeof(Object) ~= "Instance" or Updated[Object] then
			return
		end
		-- Dialog text is translated from canonical sources by its own listener.
		local DialogOverlay = Runtime.DialogOverlay
		if DialogOverlay and (Object == DialogOverlay or Object:IsDescendantOf(DialogOverlay)) then
			return
		end

		Updated[Object] = true

		if Object:IsA("TextLabel") or Object:IsA("TextButton") then
			local Current = Object.Text
			if Current ~= "" then
				local Translated = TranslateText(Current)
				if Translated ~= Current then
					Object.Text = Translated
				end
			end
		elseif Object:IsA("TextBox") then
			local Current = Object.PlaceholderText
			if Current ~= "" then
				local Translated = TranslateText(Current)
				if Translated ~= Current then
					Object.PlaceholderText = Translated
				end
			end
		end
	end

	for _, Entry in ipairs(Library.Instances) do
		local Object = Entry.Instance
		RefreshObject(Object)

		if typeof(Object) == "Instance" and Object.Parent == nil then
			for _, Descendant in ipairs(Object:GetDescendants()) do
				RefreshObject(Descendant)
			end
		end
	end

	for _, Object in ipairs(ScreenGui:GetDescendants()) do
		RefreshObject(Object)
	end
end

TrackConnection(Connection.LanguageChanged:Connect(RefreshTranslations))

local function PositionLibraryNotification()
    local State = LibraryNotification
    local Notice, Label = State.Frame, State.Label
    if not Notice or not Notice.Parent or not Notice.Visible then return end
    local Config = ConfigSection("Notification")
    local Scale = math.max(ScreenScale.Scale, 0.001)
    local View, Origin = ScreenGui.AbsoluteSize, ScreenGui.AbsolutePosition
    if View.X <= 0 or View.Y <= 0 then return end
    local Anchor = State.Anchor
    local HubPosition, HubSize
    if typeof(Anchor) == "Instance" and Anchor:IsA("GuiObject") and Anchor.Parent then
        HubPosition, HubSize = Anchor.AbsolutePosition - Origin, Anchor.AbsoluteSize
    else
        HubPosition, HubSize = Vector2.zero, View
    end
    local Margin = math.min(Config.Margin * Scale, View.X / 4, View.Y / 4)
    local Width = math.max(1, math.min(Config.MaxWidth * Scale, HubSize.X - Margin * 2, View.X - Margin * 2))
    Notice.Size = UDim2.fromOffset(Width / Scale, Notice.Size.Y.Offset)
    local Height = math.min(math.max(Config.Height * Scale, Label.TextBounds.Y + Config.TextHeightPadding * Scale), math.max(1, View.Y - Margin * 2))
    local X = math.clamp(HubPosition.X + (HubSize.X - Width) / 2, Margin, math.max(Margin, View.X - Width - Margin))
    local Below, Above = HubPosition.Y + HubSize.Y + Margin, HubPosition.Y - Height - Margin
    local Y = Below + Height <= View.Y - Margin and Below or Above >= Margin and Above
        or math.clamp(HubPosition.Y + HubSize.Y - Height - Margin, Margin, math.max(Margin, View.Y - Height - Margin))
    Notice.Position = UDim2.fromOffset(X / Scale, Y / Scale)
    Notice.Size = UDim2.fromOffset(Width / Scale, Height / Scale)
end

-- The library's compact notification is independent of the external Hub Notify API.
function Library:NotifyLibrary(Message, Values, Anchor)
    if not ScreenGui.Parent then return false end
    local Config = ConfigSection("Notification")
    local Options = type(Message) == "table" and Message or {}
    if type(Message) == "table" then
        Message = Options.Message or Options.Text
        Values = Options.Values or Values
        Anchor = Options.Anchor or Anchor
    end
    local State = LibraryNotification
    State.Source, State.Values = tostring(Message or LibraryConfig.LockedMessage), Values
    local ResolvedAnchor = Anchor or self.MainFrame
    if ResolvedAnchor ~= State.Anchor then
        for _, Link in ipairs(State.AnchorConnections or {}) do Link:Disconnect() end
        State.AnchorConnections = {}
        State.Anchor = ResolvedAnchor
        if typeof(ResolvedAnchor) == "Instance" and ResolvedAnchor:IsA("GuiObject") then
            for _, Property in ipairs({"AbsolutePosition", "AbsoluteSize"}) do
                State.AnchorConnections[#State.AnchorConnections + 1] = ResolvedAnchor:GetPropertyChangedSignal(Property):Connect(PositionLibraryNotification)
            end
        end
    end
    if not State.Frame or not State.Frame.Parent then
        State.Frame = InsertTheme(Create("Frame", LibraryResources, {
            Size = UDim2.fromOffset(Config.Width, Config.Height),
            BackgroundColor3 = Theme["Color Hub 2"], BorderSizePixel = 0,
            Visible = false, ClipsDescendants = true, ZIndex = Config.ZIndex
        }), "Frame")
        Make("Corner", State.Frame, UDim.new(0, Config.CornerRadius))
        State.Stroke = InsertTheme(Create("UIStroke", State.Frame, {
            Color = Theme["Color Theme"], Thickness = StrokeThickness,
            Transparency = Config.StrokeTransparency, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            LineJoinMode = Enum.LineJoinMode.Round
        }), "Theme")
        State.Label = InsertTheme(Create("TextLabel", State.Frame, {
            Position = UDim2.fromOffset(Config.TextPaddingX, Config.TextPaddingY),
            Size = UDim2.new(1, -Config.TextPaddingX * 2, 1, -Config.TextPaddingY * 2),
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium,
            TextSize = Config.TextSize, TextWrapped = true, RichText = false,
            TextColor3 = Theme["Color Text"], ZIndex = Config.ZIndex + 1
        }), "Text")
        State.Label:GetPropertyChangedSignal("TextBounds"):Connect(PositionLibraryNotification)
        State.Frame.Destroying:Connect(function()
            State.Token += 1
            for _, Link in ipairs(State.AnchorConnections or {}) do Link:Disconnect() end
            State.AnchorConnections = {}
            State.Anchor = nil
        end)
    end
    State.Label.Text = TranslateText(State.Source, State.Values)
    State.Frame.Visible = true
    State.Token += 1
    local Token = State.Token
    PositionLibraryNotification()
    task.defer(PositionLibraryNotification)
    local Handle = {Frame = State.Frame}
    function Handle:Close()
        if Token == State.Token then
            State.Token += 1
            if State.Frame and State.Frame.Parent then State.Frame.Visible = false end
        end
    end
    local Duration = math.max(0, tonumber(Options.Duration or Options.Time) or Config.Duration)
    if Duration > 0 then task.delay(Duration, function() Handle:Close() end) end
    return Handle
end

local function ShowToastMessage(Message, Values)
    return Library:NotifyLibrary(Message, Values)
end

TrackConnection(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(PositionLibraryNotification))
TrackConnection(ScreenScale:GetPropertyChangedSignal("Scale"):Connect(PositionLibraryNotification))
TrackConnection(Connection.LanguageChanged:Connect(function()
    local State = LibraryNotification
    if State.Label and State.Label.Parent then
        State.Label.Text = TranslateText(State.Source, State.Values)
        PositionLibraryNotification()
    end
end))

local function ApplyLocked(Element, Holder, Configs, OnChanged)
	Configs = type(Configs) == "table" and Configs or {}

	local Locked = Configs.Locked == true
	Element.Locked = Locked
	local DefaultLockedMessage = LibraryConfig.LockedMessage
	local Message = type(Configs.LockedMessage) == "string" and Configs.LockedMessage or DefaultLockedMessage

	local Overlay = Create("Frame", Holder, {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Visible = Locked,
		Active = true,
		ZIndex = 1000
	})

	Make("Corner", Overlay, UDim.new(0, 10))
	local LockRow = Create("Frame", Overlay, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 1001
	}, {Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6)
	})})
	Create("ImageLabel", LockRow, {
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Image = Library:GetIcon("lock"),
		ImageTransparency = 0.4,
		LayoutOrder = 1,
		ZIndex = 1002
	})
	local LockLabel = Create("TextLabel", LockRow, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		BackgroundTransparency = 1,
		Text = TranslateText(Configs.LockedTitle or ControlsConfig.Titles.Locked),
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		LayoutOrder = 2,
		ZIndex = 1002
	})
	local SavedInteraction = {}
	local function Block(Object)
		if Object:IsA("GuiObject") and Object ~= Overlay and not Object:IsDescendantOf(Overlay) then
			if SavedInteraction[Object] == nil then
				SavedInteraction[Object] = Object.Interactable
			end
			Object.Interactable = false
			if Object:IsA("TextBox") and Object:IsFocused() then Object:ReleaseFocus() end
		end
	end
	Holder.DescendantAdded:Connect(function(Object)
		if Locked then Block(Object) end
	end)

	local function SetLocked(Value)
		Locked = Value == true
		Element.Locked = Locked
		Overlay.Visible = Locked
		if Locked then
			Block(Holder)
			for _, Object in ipairs(Holder:GetDescendants()) do Block(Object) end
		else
			for Object, Interactable in pairs(SavedInteraction) do
				if Object.Parent then Object.Interactable = Interactable end
			end
			table.clear(SavedInteraction)
		end

		if type(OnChanged) == "function" then
			OnChanged(Locked)
		end

		return Locked
	end

	function Element:SetLocked(Value)
		return SetLocked(Value)
	end

	function Element:Lock(NewMessage)
		if type(NewMessage) == "string" then
			Message = NewMessage
			LockLabel.Text = TranslateText(NewMessage)
		end

		return SetLocked(true)
	end

	function Element:Unlock()
		return SetLocked(false)
	end

	function Element:IsLocked()
		return Locked
	end

	function Element:SetLockedMessage(NewMessage)
		if type(NewMessage) == "string" and NewMessage ~= "" then
			Message = NewMessage
		end
	end

	function Element:GetLockedMessage()
		return Message
	end

	function Element:NotifyLocked()
		ShowToastMessage(Message)
	end

	SetLocked(Locked)
	return Element
end

local LuaKeywords = {
	["and"] = true, ["break"] = true, ["continue"] = true, ["do"] = true,
	["else"] = true, ["elseif"] = true, ["end"] = true, ["export"] = true,
	["for"] = true, ["function"] = true, ["if"] = true, ["in"] = true,
	["local"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
	["return"] = true, ["then"] = true, ["type"] = true, ["until"] = true,
	["while"] = true,
}

local RobloxGlobals = {
	["game"] = true, ["workspace"] = true, ["script"] = true, ["Enum"] = true,
	["Instance"] = true, ["Color3"] = true, ["Vector2"] = true, ["Vector3"] = true,
	["CFrame"] = true, ["UDim"] = true, ["UDim2"] = true, ["Rect"] = true,
	["Region3"] = true, ["Ray"] = true, ["BrickColor"] = true, ["NumberRange"] = true,
	["NumberSequence"] = true, ["ColorSequence"] = true, ["TweenInfo"] = true,
	["task"] = true, ["math"] = true, ["string"] = true, ["table"] = true,
	["utf8"] = true, ["coroutine"] = true, ["os"] = true, ["debug"] = true,
	["bit32"] = true, ["buffer"] = true, ["shared"] = true, ["getgenv"] = true,
	["loadstring"] = true, ["typeof"] = true, ["type"] = true, ["pairs"] = true,
	["ipairs"] = true, ["next"] = true, ["select"] = true, ["pcall"] = true,
	["xpcall"] = true, ["assert"] = true, ["error"] = true, ["warn"] = true,
	["print"] = true, ["tonumber"] = true, ["tostring"] = true,
}

local function GetColor(Instance)
	if Instance:IsA("Frame") or Instance:IsA("GuiButton") then
		return "BackgroundColor3"
	elseif Instance:IsA("ImageLabel") then
		return "ImageColor3"
	elseif Instance:IsA("TextLabel") or Instance:IsA("TextBox") then
		return "TextColor3"
	elseif Instance:IsA("ScrollingFrame") then
		return "ScrollBarImageColor3"
	elseif Instance:IsA("UIStroke") then
		return "Color"
	end
	return ""
end

--// Filesystem

function Library:GetWorkspacePath(Path)
	return type(Hub) == "table" and type(Hub.GetWorkspacePath) == "function" and Hub:GetWorkspacePath(Path) or nil
end

function Library:CreateFolder(Path)
	if type(Hub) ~= "table" or type(Hub.CreateFolder) ~= "function" then
		return false, "Filesystem is unavailable."
	end

	return Hub:CreateFolder(Path)
end

function Library:CreateFile(Path, Content)
	if type(Hub) ~= "table" or type(Hub.CreateFile) ~= "function" then
		return false, "Filesystem is unavailable."
	end

	return Hub:CreateFile(Path, Content)
end

function Library:WriteFile(Path, Content)
	return self:CreateFile(Path, Content)
end

function Library:ReadFile(Path)
	if type(Hub) ~= "table" or type(Hub.ReadFile) ~= "function" then
		return nil, "Filesystem is unavailable."
	end

	return Hub:ReadFile(Path)
end

function Library:FileExists(Path)
	return type(Hub) == "table" and type(Hub.FileExists) == "function" and Hub:FileExists(Path) or false
end

function Library:FolderExists(Path)
	return type(Hub) == "table" and type(Hub.FolderExists) == "function" and Hub:FolderExists(Path) or false
end

function Library:DeleteFile(Path)
	if type(Hub) ~= "table" or type(Hub.DeleteFile) ~= "function" then
		return false, "Filesystem is unavailable."
	end

	return Hub:DeleteFile(Path)
end

function Library:GetSettingsPath()
	return self:GetWorkspacePath(SettingsPath)
end

function Library:SetIcons(Icons)
    if type(Icons) ~= "table" then
        return false
    end

    self.Icons = Icons
    table.clear(IconSearchCache)
    return true
end

function Library:GetIcons()
    return self.Icons
end

function Library:GetIcon(Index)
    if type(Index) ~= "string" or Index:find("rbxassetid://", 1, true) or #Index == 0 then
        return Index
    end

    local Key = string.lower(Index):gsub("lucide", ""):gsub("-", "")
    local Cached = IconSearchCache[Key]

    if Cached ~= nil then
        return Cached or Index
    end

    local Exact = self.Icons[Key]
    if Exact then
        IconSearchCache[Key] = Exact
        return Exact
    end

    for Name, Icon in pairs(self.Icons) do
        if Name:find(Key, 1, true) then
            IconSearchCache[Key] = Icon
            return Icon
        end
    end

    IconSearchCache[Key] = false
    return Index
end

function Library:GetTheme()
    return Library.Save.Theme
end

function Library:GetThemes()
    local Names = {}

    for Name in pairs(Library.Themes) do
        Names[#Names + 1] = Name
    end

    table.sort(Names)
    return Names
end

function Library:GetLanguage()
    if type(Hub) == "table" and type(Hub.GetLanguage) == "function" then
        return Hub:GetLanguage()
    end

    return Library.Save.Language or RootConfig.Language.Default
end

function Library:GetLanguages()
    if type(Hub) == "table" and type(Hub.GetLanguages) == "function" then
        return Hub:GetLanguages()
    end

    return table.clone(RootConfig.Language.Names)
end

function Library:SetLanguage(NewLanguage)
    if NewLanguage == Library:GetLanguage() then return true, NewLanguage end
    if type(Hub) ~= "table" or type(Hub.SetLanguage) ~= "function" then
        return false
    end

    local Success, Language = Hub:SetLanguage(NewLanguage)
    if not Success then
        return false
    end

    Library.Save.Language = Language
    QueueSettingsSave()
    Connection:FireConnection("LanguageChanged", Language)
    return true, Language
end

function Library:GetTransparency()
    if Library.Transparency ~= nil then
        return Library.Transparency
    end

    for _, Val in pairs(Library.Instances) do
        if Val.Type == "Main" then
            return Val.Instance.BackgroundTransparency * 100
        end
    end

    return nil
end

function Library:SetTheme(NewTheme)
	if not VerifyTheme(NewTheme) then return false end
	if Library.Save.Theme == NewTheme then return true end
	local PreviousTheme = Theme
	Library.Save.Theme = NewTheme
	QueueSettingsSave()
	Theme = Library.Themes[NewTheme]

	if type(Hub) == "table" and type(Hub.SetTheme) == "function" then
		Hub:SetTheme(NewTheme)
	end
	
	Connection:FireConnection("ThemeChanged", NewTheme)
	for _, Val in ipairs(Library.Instances) do
		if Val.Type == "MainGradient" or Val.Type == "Gradient" then
			Val.Instance.Color = ThemeBackgroundColors()
		elseif Val.Type == "InputSurface" then
			Val.Instance.BackgroundColor3 = InputSurfaceColor()
		elseif Val.Type == "ComponentSurface" then
			Val.Instance.BackgroundColor3 = ComponentColor()
		elseif Val.Type == "TitleText" then
			Val.Instance.TextColor3 = Color3.new(1, 1, 1)
		elseif Val.Type == "DescriptionText" then
			Val.Instance.TextColor3 = Color3.fromRGB(180, 180, 188)
		elseif Val.Type == "Frame" then
			Val.Instance.BackgroundColor3 = Theme["Color Hub 2"]
		elseif Val.Type == "Stroke" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Stroke"]
		elseif Val.Type == "Theme" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Theme"]
		elseif Val.Type == "Text" then
			local Instance = Val.Instance
			if Instance:IsA("TextButton") then
				Instance.TextColor3 = Theme["Color Text"]
			else
				Instance[GetColor(Instance)] = Theme["Color Text"]
			end
			if Instance:IsA("TextBox") and Instance.PlaceholderColor3 == PreviousTheme["Color Dark Text"] then
				Instance.PlaceholderColor3 = Theme["Color Dark Text"]
			end
		elseif Val.Type == "IconSurface" then
			Val.Instance.BackgroundColor3 = Theme["Color Hub 2"]

		elseif Val.Type == "Icon" then
			Val.Instance.ImageColor3 = Theme["Color Text"]
		elseif Val.Type == "DarkText" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Dark Text"]
		elseif Val.Type == "ScrollBar" then
			Val.Instance[GetColor(Val.Instance)] = AdaptiveScrollRefresh[Val.Instance]
				and Theme["Color Stroke"] or Theme["Color Theme"]
		end
	end
    if Library._BackgroundSettings then Library._BackgroundSettings.Apply(true) end
end

function Library:GetBackground()
    return Library.Save.BackgroundImage or DefaultBackgroundImage
end

function Library:GetBackgroundPreset()
    return Library.Save.BackgroundPreset or DefaultBackgroundPreset
end

function Library:GetBackgroundPresets()
    local Presets = {}
    for _, Preset in ipairs(BackgroundPresets) do
        if type(Preset) == "table" then
            Presets[#Presets + 1] = {
                Key = Preset.Key or Preset.Name,
                Name = Preset.Name or Preset.Key,
                Id = NormalizeAssetId(Preset.Id) or ""
            }
        end
    end
    return Presets
end

Library._BackgroundSettings = {Generation = 0}

function Library:GetBackgroundEnabled()
    return Library.Save.BackgroundEnabled ~= false
end

function Library:GetBackgroundImageBrightness()
    return Library.Save.BackgroundImageBrightness or 100
end

function Library:GetBackgroundTileSize()
    return Library.Save.BackgroundTileSize or 128
end

function Library._BackgroundSettings.Apply(SkipSync)
    local Id = Library:GetBackground()
    local Enabled = Library:GetBackgroundEnabled() and Id ~= "" and Library:GetBackgroundImageTransparency() < 100
    local Brightness = Library:GetBackgroundImageBrightness() / 100
    for _, Entry in ipairs(Library.Instances) do
        if Entry.Type == "Main" then
            local Frame = Entry.Instance
            Frame.Image = Enabled and (GuiImageCache[Id] or ToAssetContentId(Id)) or ""
            Frame.ImageTransparency = Library:GetBackgroundImageTransparency() / 100
            Frame.ImageColor3 = Color3.new(Brightness, Brightness, Brightness)
            Frame.ScaleType = BackgroundScaleTypes[Library:GetBackgroundScale()]
            Frame.TileSize = UDim2.fromOffset(Library:GetBackgroundTileSize(), Library:GetBackgroundTileSize())
            -- A disabled gradient must reveal the theme surface, never default white.
            Frame.BackgroundColor3 = Enabled and Theme["Color Hub 2"] or Color3.new(1, 1, 1)
        elseif Entry.Type == "MainGradient" then
            Entry.Instance.Enabled = not Enabled
        end
    end
    local Sync = Library._BackgroundSettings.Sync
    if Sync and not SkipSync then Sync() end
end

function Library._BackgroundSettings.Resolve()
    local State = Library._BackgroundSettings
    State.Generation += 1
    local Generation, Id = State.Generation, Library:GetBackground()
    if Id == "" or GuiImageCache[Id] then return end
    task.spawn(function()
        ResolveGuiImage(Id)
        if State.Generation == Generation and Library:GetBackground() == Id then State.Apply(true) end
    end)
end

function Library:SetBackgroundEnabled(Value)
    if type(Value) ~= "boolean" then return false end
    if Library.Save.BackgroundEnabled == Value then return true end
    Library.Save.BackgroundEnabled = Value
    QueueSettingsSave()
    Library._BackgroundSettings.Apply()
    return true
end

function Library:SetBackground(NewBackground, Preset)
    local AssetId = NormalizeAssetId(NewBackground)
    if AssetId == nil then
        return false
    end

    Library.Save.BackgroundImage = AssetId
    if type(Preset) == "string" then
        Library.Save.BackgroundPreset = Preset
    elseif AssetId == "" then
        Library.Save.BackgroundPreset = "None"
    else
        Library.Save.BackgroundPreset = "Custom"
    end
    Library.Save.BackgroundEnabled = AssetId ~= ""
    QueueSettingsSave()
    Library._BackgroundSettings.Apply()
    Library._BackgroundSettings.Resolve()

    return true
end

function Library:GetBackgroundImageTransparency()
    return Library.Save.BackgroundImageTransparency or DefaultBackgroundImageTransparency
end

function Library:SetBackgroundImageTransparency(Value)
    Value = tonumber(Value)
    if not Value or Value ~= Value or math.abs(Value) == math.huge then return false end

    Value = math.clamp(Value, 0, 100)
    Library.Save.BackgroundImageTransparency = Value
    QueueSettingsSave()

    Library._BackgroundSettings.Apply()
    return true
end

function Library:GetBackgroundScale()
    return Library.Save.BackgroundScale or DefaultBackgroundScale
end

function Library:SetBackgroundScale(Value)
    if type(Value) ~= "string" then return false end
    local Name
    for Key in pairs(BackgroundScaleTypes) do
        if Key:lower() == Value:lower() then Name = Key; break end
    end
    if not Name then return false end
    Library.Save.BackgroundScale = Name
    QueueSettingsSave()
    Library._BackgroundSettings.Apply()
    return true
end

function Library:SetBackgroundImageBrightness(Value)
    Value = tonumber(Value)
    if not Value or Value ~= Value or math.abs(Value) == math.huge then return false end
    Library.Save.BackgroundImageBrightness = math.clamp(Value, 0, 100)
    QueueSettingsSave()
    Library._BackgroundSettings.Apply()
    return true
end

function Library:SetBackgroundTileSize(Value)
    Value = tonumber(Value)
    if not Value or Value ~= Value or math.abs(Value) == math.huge then return false end
    Library.Save.BackgroundTileSize = math.clamp(math.floor(Value + 0.5), 32, 512)
    QueueSettingsSave()
    Library._BackgroundSettings.Apply()
    return true
end

function Library:ResetBackground()
    for _, Key in ipairs({"BackgroundImage", "BackgroundPreset", "BackgroundImageTransparency", "BackgroundScale", "BackgroundEnabled", "BackgroundImageBrightness", "BackgroundTileSize"}) do
        Library.Save[Key] = Library.DefaultSettings[Key]
    end
    QueueSettingsSave()
    Library._BackgroundSettings.Apply()
    Library._BackgroundSettings.Resolve()
end

function Library._BackgroundSettings.CreateControls(ConfigTab, ExtraLabels)
    local State, Controls = Library._BackgroundSettings, {}
    local Presets, Names = Library:GetBackgroundPresets(), {}
    local function AddMissing(Key)
        for _, Preset in ipairs(Presets) do if Preset.Key == Key then return end end
        Presets[#Presets + 1] = {Key = Key, Name = Key, Id = ""}
    end
    AddMissing("None")
    AddMissing("Custom")
    local function PresetName()
        for _, Preset in ipairs(Presets) do
            if Preset.Key == Library:GetBackgroundPreset() then return Preset.Name end
        end
        return Library:GetBackground() == "" and "None" or "Custom"
    end
    for _, Preset in ipairs(Presets) do Names[#Names + 1] = Preset.Name end
    local function Label(Control, Key)
        ExtraLabels[#ExtraLabels + 1] = {Control, Key}
        return Control
    end

    Label(ConfigTab:AddSection(TranslateText("Background")), "Background")
    Controls.Enabled = Label(ConfigTab:AddToggle({
        Name = TranslateText("Show background image"),
        Default = Library:GetBackgroundEnabled(),
        Callback = function(Value) Library:SetBackgroundEnabled(Value) end
    }), "Show background image")
    Controls.Preset = Label(ConfigTab:AddSelector({
        Name = TranslateText("Background preset"),
        Options = Names, Default = PresetName(), Wrap = true,
        Callback = function(Value)
            for _, Preset in ipairs(Presets) do
                if Preset.Name == Value then
                    Library:SetBackground(Preset.Key == "Custom" and Library:GetBackground() or Preset.Id, Preset.Key)
                    break
                end
            end
        end
    }), "Background preset")
    Controls.Image = Label(ConfigTab:AddTextBox({
        Name = TranslateText("Background image ID"),
        Default = Library:GetBackground(), ClearText = false, FireOnInit = false,
        PlaceholderText = TranslateText("Image ID or Roblox link"),
        Callback = function(Value)
            if not Library:SetBackground(Value) then
                Controls.Image:Set(Library:GetBackground(), true)
                Library:NotifyLibrary(TranslateText("Enter a valid image ID or Roblox image/decal link."))
            end
        end
    }), "Background image ID")
    Controls.Transparency = Label(ConfigTab:AddSlider({
        Name = TranslateText("Background image transparency"),
        Min = 0, Max = 100, Increase = 1, Default = Library:GetBackgroundImageTransparency(),
        Callback = function(Value) Library:SetBackgroundImageTransparency(Value) end
    }), "Background image transparency")
    Controls.Brightness = Label(ConfigTab:AddSlider({
        Name = TranslateText("Background image brightness"),
        Desc = TranslateText("Brightness affects only the image."),
        Min = 0, Max = 100, Increase = 1, Default = Library:GetBackgroundImageBrightness(),
        Callback = function(Value) Library:SetBackgroundImageBrightness(Value) end
    }), "Background image brightness")
    Controls.Scale = Label(ConfigTab:AddSelector({
        Name = TranslateText("Background scale"),
        Options = {"Crop", "Fit", "Stretch", "Tile"}, Default = Library:GetBackgroundScale(), Wrap = true,
        Callback = function(Value) Library:SetBackgroundScale(Value) end
    }), "Background scale")
    Controls.Tile = Label(ConfigTab:AddSlider({
        Name = TranslateText("Background tile size"),
        Desc = TranslateText("Tile size applies only to Tile mode."),
        Min = 32, Max = 512, Increase = 1, Default = Library:GetBackgroundTileSize(),
        Callback = function(Value) Library:SetBackgroundTileSize(Value) end
    }), "Background tile size")
    Label(ConfigTab:AddButton({
        Name = TranslateText("Remove background image"),
        Callback = function() Library:SetBackground("", "None") end
    }), "Remove background image")
    Label(ConfigTab:AddButton({
        Name = TranslateText("Reset background settings"),
        Callback = function() Library:ResetBackground() end
    }), "Reset background settings")

    State.Owner = ConfigTab
    State.Sync = function()
        Controls.Enabled:SetEnabled(Library:GetBackgroundEnabled(), true)
        Controls.Preset:Set(PresetName(), true)
        Controls.Image:Set(Library:GetBackground(), true)
        Controls.Transparency:SetValue(Library:GetBackgroundImageTransparency(), true)
        Controls.Brightness:SetValue(Library:GetBackgroundImageBrightness(), true)
        Controls.Scale:Set(Library:GetBackgroundScale(), true)
        Controls.Tile:SetValue(Library:GetBackgroundTileSize(), true)
        Controls.Tile:Visible(Library:GetBackgroundScale() == "Tile")
    end
    State.Sync()
end

function Library:IsSoundEnabled()
    return Library.Save.SoundEnabled == true
end

function Library:SetSoundEnabled(Value)
    if type(Value) ~= "boolean" then return false end
    if Library.Save.SoundEnabled == Value then return true end
    Library.Save.SoundEnabled = Value
    QueueSettingsSave()
    return true
end

function Library:GetSoundVolume()
    return Library.Save.SoundVolume or DefaultSoundVolume
end

function Library:SetSoundVolume(Value)
    Value = tonumber(Value)
    if not Value then return false end
    Value = math.clamp(Value, 0, 100)
    if Library.Save.SoundVolume == Value then return true end
    Library.Save.SoundVolume = Value
    UISound.Volume = Library.Save.SoundVolume / 100
    QueueSettingsSave()
    return true
end

function Library:GetSoundId()
    return Library.Save.SoundId or DefaultSoundId
end

function Library:SetSoundId(Value)
    local AssetId = NormalizeAssetId(Value)
    if not AssetId or AssetId == "" then
        return false
    end
    if tostring(Library.Save.SoundId) == tostring(AssetId) then return true end
    Library.Save.SoundId = AssetId
    EnsureSoundPreset(AssetId)
    UISound.SoundId = ToAssetContentId(AssetId)
    QueueSettingsSave()
    return true
end

function Library:PlayUISound()
    PlayUISound()
end

function Library:PreviewUISound()
    PreviewUISound()
end

function Library:ApplySectionStyle(Indicator)
    local Info = self.SectionIndicators[Indicator]
    if not Info then return end

    local Label = Info.Label
    local Frame = Indicator.Parent
    if not Frame or not Label.Parent then
        self.SectionIndicators[Indicator] = nil
        return
    end

    local Enabled = Info.Override
    if Enabled == nil then
        Enabled = self.Save.SectionIndicator
    end

    local Offset = Enabled and (8 + self.Save.SectionThickness + self.Save.SectionSpacing) or 8
    Frame.Size = UDim2.new(1, 0, 0, self.Save.SectionHeight)
    Label.Position = UDim2.fromOffset(Offset, 0)
    Label.Size = UDim2.new(1, -Offset - (Info.Collapsible and 30 or 8), 1, 0)
    Label.TextSize = self.Save.SectionTextSize
    Indicator.Size = UDim2.fromOffset(self.Save.SectionThickness, math.min(self.Save.SectionIndicatorHeight, self.Save.SectionHeight - 4))
    Indicator.Visible = Enabled
end

function Library:RefreshSections()
    for Indicator in pairs(self.SectionIndicators) do
        self:ApplySectionStyle(Indicator)
    end
end

function Library:SetSectionSetting(Key, Value)
    if Key == "SectionIndicator" then
        if type(Value) ~= "boolean" then return false end
    else
        local Range = self.SectionRanges[Key]
        if not Range then return false end
        Value = tonumber(Value)
        if not Value or Value ~= Value then return false end
        Value = math.clamp(math.floor(Value + 0.5), Range[1], Range[2])
    end

    if self.Save[Key] == Value then return true end
    self.Save[Key] = Value
    self:RefreshSections()
    QueueSettingsSave()
    return true
end

function Library:GetDropdownSearchDefault()
    return Library.Save.DropdownSearch == true
end

function Library:SetDropdownSearchDefault(Value)
    if type(Value) ~= "boolean" then return false end
    if Library.Save.DropdownSearch == Value then return true end
    Library.Save.DropdownSearch = Value
    QueueSettingsSave()

    Funcs:NotifyListeners(DropdownSearchListeners, Value)

    return true
end

function Library:GetDropdownPrefixOnly()
    return Library.Save.DropdownPrefixOnly ~= false
end

function Library:SetDropdownPrefixOnly(Value)
    if type(Value) ~= "boolean" then return false end
    if Library.Save.DropdownPrefixOnly == Value then return true end
    Library.Save.DropdownPrefixOnly = Value
    QueueSettingsSave()

    Funcs:NotifyListeners(DropdownPrefixListeners, Value)

    return true
end

function Library:GetDropdownCloseOnSelect()
    return Library.Save.DropdownCloseOnSelect == true
end

function Library:SetDropdownCloseOnSelect(Value)
    if type(Value) ~= "boolean" then return false end
    if Library.Save.DropdownCloseOnSelect == Value then return true end
    Library.Save.DropdownCloseOnSelect = Value
    QueueSettingsSave()
    return true
end

function Library:GetDropdownMaxVisibleOptions()
    return math.clamp(math.floor(tonumber(Library.Save.DropdownMaxVisibleOptions) or DefaultDropdownMaxVisibleOptions), 3, 12)
end

function Library:SetDropdownMaxVisibleOptions(Value)
    Value = tonumber(Value)
    if not Value then return false end

    Value = math.clamp(math.floor(Value + 0.5), 3, 12)
    if Library.Save.DropdownMaxVisibleOptions == Value then return true end
    Library.Save.DropdownMaxVisibleOptions = Value
    QueueSettingsSave()

    Funcs:NotifyListeners(DropdownSizeListeners)

    return true
end

function Library._KeybindSettings.SetDefault(Key, Value)
    if Library.Save[Key] == Value then return true end
    Library.Save[Key] = Value
    QueueSettingsSave()
    Funcs:NotifyListeners(Library._KeybindSettings.Listeners)
    return true
end

function Library:GetKeybindIconDefault()
    return Library.Save.KeybindIcon == true
end

function Library:SetKeybindIconDefault(Value)
    if type(Value) ~= "boolean" then return false end
    return Library._KeybindSettings.SetDefault("KeybindIcon", Value)
end

function Library:GetKeybindWidth()
    return Library._KeybindSettings.NormalizeWidth(Library.Save.KeybindWidth) or Library._KeybindSettings.DefaultWidth
end

function Library:SetKeybindWidth(Value)
    Value = Library._KeybindSettings.NormalizeWidth(Value)
    if not Value then return false end
    return Library._KeybindSettings.SetDefault("KeybindWidth", Value)
end

function Library:GetKeybindHighlight()
    return Library.Save.KeybindHighlight ~= false
end

function Library:SetKeybindHighlight(Value)
    if type(Value) ~= "boolean" then return false end
    return Library._KeybindSettings.SetDefault("KeybindHighlight", Value)
end

function Library:GetKeybindRightClick()
    return Library.Save.KeybindRightClick ~= false
end

function Library:SetKeybindRightClick(Value)
    if type(Value) ~= "boolean" then return false end
    return Library._KeybindSettings.SetDefault("KeybindRightClick", Value)
end

function Library:SetTransparency(NewTransparency)
    local Target = math.clamp(tonumber(NewTransparency) or Library.Save.Transparency or DefaultTransparency, 0, 100)
    if Library.Transparency == Target then return end
    Library.Transparency = Target
    Library.Save.Transparency = Library.Transparency
    QueueSettingsSave()

    local Transparency = Library.Transparency / 100

    for _, Val in pairs(Library.Instances) do
        if Val.Type == "Main" then
            Val.Instance.BackgroundTransparency = Transparency
        end
    end
end

function Library:SetScale(NewScale)
    local TargetHeight = tonumber(NewScale)
    if not TargetHeight then return end

    local Viewport = GetViewportSize()
    RequestedScale = TargetHeight > 10 and Viewport.Y / math.clamp(TargetHeight, 300, 2000) or math.clamp(TargetHeight, 0.1, 10)
    UIScale = RequestedScale
    ScreenScale.Scale = UIScale
end

function Library:GetScrollThickness()
    return ScrollThickness
end

function Library:SetScrollThickness(Value)
    Value = tonumber(Value)
    if not Value then return false end

    Value = math.clamp(Value, 0, 12)
    if ScrollThickness == Value then return true end
    ScrollThickness = Value
    Library.Save.ScrollThickness = ScrollThickness
    QueueSettingsSave()

    for _, Val in ipairs(Library.Instances) do
        if Val.Type == "ScrollBar" and Val.Instance:IsA("ScrollingFrame") then
            local Refresh = AdaptiveScrollRefresh[Val.Instance]
            if Refresh then
                Refresh()
            else
                Val.Instance.ScrollBarThickness = ScrollThickness
            end
        end
    end
    return true
end

function Library:GetScrollTransparency()
    return ScrollTransparency * 100
end

function Library:SetScrollTransparency(Value)
    Value = tonumber(Value)
    if not Value then return false end

    Value = math.clamp(Value / 100, 0, 1)
    if ScrollTransparency == Value then return true end
    ScrollTransparency = Value
    Library.Save.ScrollTransparency = ScrollTransparency
    QueueSettingsSave()

    for _, Val in ipairs(Library.Instances) do
        if Val.Type == "ScrollBar" and Val.Instance:IsA("ScrollingFrame") then
            Val.Instance.ScrollBarImageTransparency = ScrollTransparency
        end
    end
    return true
end

function Library:GetSizeLimits()
    return {
        Min = Vector2.new(MinWidth, MinHeight),
        Max = Vector2.new(MaxWidth, MaxHeight),
        MinTab = MinTabSize,
        MaxTab = MaxTabSize
    }
end

function Library:GetInputMode()
    return GetInputMode()
end

function Library:IsCompactDisplay()
    return IsCompactDisplay()
end

function Library:GetViewportSize()
    return GetViewportSize()
end

local MouseSettingKeys = {
    UnlockCursorOnOpen = true,
    CameraWithRightMouseButton = true,
    UnlockCursorWhenMinimized = true
}

function Library:GetMouseSetting(Key)
    if not MouseSettingKeys[Key] then return nil end
    return Library.Save[Key] ~= false
end

function Library:SetMouseSetting(Key, Value)
    if not MouseSettingKeys[Key] or type(Value) ~= "boolean" then return false end
    if Library.Save[Key] == Value then return true end
    Library.Save[Key] = Value
    if Library._MouseControl then Library._MouseControl:Refresh() end
    QueueSettingsSave()
    return true
end

-- Temporarily own the cursor; the camera keeps ownership of its underlying lock state.
Library._MouseControl = {Frames = setmetatable({}, {__mode = "k"}), Connections = {}, Generation = 0}
function Library._MouseControl.Initialize()
    local Control = Library._MouseControl
    local RunService = game:GetService("RunService")
    local Actions = game:GetService("ContextActionService")
    local BindingName = "SpecterXCursor_" .. Hub:GenerateName(12)
    local Modal = Create("TextButton", {
        Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, Active = false,
        Selectable = false, Interactable = false, Modal = false, Visible = false
    })
    Modal.Parent = ScreenGui

    function Control:IsVisible()
        if Library.Save.UnlockCursorOnOpen == false
            or (self.Minimized and Library.Save.UnlockCursorWhenMinimized == false) then return false end
        if self.Destroyed or self.Focused == false or not ScreenGui.Enabled
            or not ScreenGui:IsDescendantOf(game) then return false end
        for Frame in pairs(self.Frames) do
            local Current, Visible = Frame, true
            while Current and Current ~= ScreenGui do
                if Current:IsA("GuiObject") and not Current.Visible then Visible = false; break end
                Current = Current.Parent
            end
            if Visible and Current == ScreenGui then return true end
        end
        return false
    end

    function Control:Unlock()
        if not self.Active or self.Destroyed then return end
        if Library.Save.CameraWithRightMouseButton ~= false
            and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        if not UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = true end
    end

    function Control:Release()
        local WasActive = self.Active
        self.Active = false
        self.Generation += 1
        -- Also clean partial/stale registrations if release is called a second time.
        RunService:UnbindFromRenderStep(BindingName)
        Actions:UnbindAction(BindingName)
        Modal.Modal = false
        Modal.Visible = false
        if WasActive then
            -- A saved LockCurrentPosition/LockCenter may belong to a finished drag or an old
            -- camera mode. Reapplying it can strand the cursor. Let the camera resume its
            -- current first-person/shift-lock state on its next update instead.
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            if UserInputService.MouseIconEnabled and self.PreviousIconEnabled ~= nil then
                UserInputService.MouseIconEnabled = self.PreviousIconEnabled
            end
        end
        self.PreviousIconEnabled = nil
    end

    function Control:Refresh()
        if self.Destroyed then return end
        if not self:IsVisible() then self:Release(); return end
        if self.Active then return end
        self.PreviousIconEnabled = UserInputService.MouseIconEnabled
        self.Active = true
        self.Generation += 1
        local Generation = self.Generation
        Modal.Visible = true
        Modal.Modal = true
        Actions:BindActionAtPriority(BindingName, function()
            if self.Active and self.Generation == Generation and self:IsVisible() then
                return Enum.ContextActionResult.Sink
            end
            return Enum.ContextActionResult.Pass
        end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.CapsLock)
        RunService:BindToRenderStep(BindingName, Enum.RenderPriority.Last.Value + 1, function()
            -- Visibility events can be deferred, and an old callback may already be queued.
            if self.Generation ~= Generation or not self.Active then return end
            if not self:IsVisible() then self:Release(); return end
            self:Unlock()
        end)
        self:Unlock()
    end

    function Control:Bind(Frame)
        if self.Destroyed or self.Frames[Frame] then return end
        local Connections = {}
        self.Frames[Frame] = Connections
        local function Refresh() self:Refresh() end
        table.insert(Connections, Frame:GetPropertyChangedSignal("Visible"):Connect(Refresh))
        table.insert(Connections, Frame.AncestryChanged:Connect(Refresh))
        table.insert(Connections, Frame.Destroying:Connect(function()
            self.Frames[Frame] = nil
            for _, Connection in ipairs(Connections) do Connection:Disconnect() end
            self:Refresh()
        end))
        self:Refresh()
    end

    function Control:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        self:Release()
        for _, Connections in pairs(self.Frames) do
            for _, Connection in ipairs(Connections) do Connection:Disconnect() end
        end
        for _, Connection in ipairs(self.Connections) do Connection:Disconnect() end
        table.clear(self.Frames)
        table.clear(self.Connections)
        Modal:Destroy()
    end

    table.insert(Control.Connections, ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function() Control:Refresh() end))
    table.insert(Control.Connections, ScreenGui.AncestryChanged:Connect(function() Control:Refresh() end))
    table.insert(Control.Connections, UserInputService.WindowFocusReleased:Connect(function()
        Control.Focused = false
        Control:Refresh()
    end))
    table.insert(Control.Connections, UserInputService.WindowFocused:Connect(function()
        Control.Focused = true
        Control:Refresh()
    end))
    table.insert(Control.Connections, ScreenGui.Destroying:Connect(function() Control:Destroy() end))
end

Library._MouseControl.Initialize()

local StartupGreetingQueued = false

function Library:MakeWindow(Configs)
    Configs = type(Configs) == "table" and Configs or {}

	local WTitle = tostring(Configs[1] or Configs.Name or Configs.Title or RootConfig.Title)
	local WMiniText = tostring(Configs[2] or Configs.SubTitle or RootConfig.SubTitle)
	local Keybind = LoadedSettingKeys.Keybind and Library.Save.Keybind
		or Configs[3]
		or Configs.Keybind
		or Library.Save.Keybind
		or DefaultKeybind

	local Minimized, SaveSize, WaitClick
	local FrozenContentLayout
	local RequestedMinimizedWidth = LoadedSettingKeys.MinimizedWidth and Library.Save.MinimizedWidth
		or tonumber(Configs.MinimizedWidth)
		or Library.Save.MinimizedWidth
		or DefaultMinimizedWidth
	local TitleWidth = TextService:GetTextSize(WTitle, TopBarTitleTextSize, Enum.Font.GothamMedium, Vector2.new(1000, TopBarHeight)).X
	local MinimizedWidth = math.clamp(math.max(RequestedMinimizedWidth, TitleWidth + 115), 160, math.min(320, MaxWidth))

	Settings.ScriptFile = LibraryConfig.SaveFolder
	if Settings.ScriptFile == nil then Settings.ScriptFile = Configs[4] or Configs.SaveFolder or false end
	
    local function LoadFile()
        local File = Settings.ScriptFile
        if type(File) ~= "string" or File == "" then return end
        local Decoded = JsonFiles.Read(File)
        if not Decoded then return end
        table.clear(Flags)
        for Flag, Value in pairs(Decoded) do Flags[Flag] = Value end
    end

	LoadFile()
	
	local SavedWidth, SavedHeight = table.unpack(Library.Save.UISize)
	local UISizeX, UISizeY
	if LoadedSettingKeys.UISize then
		UISizeX, UISizeY = SavedWidth, SavedHeight
	else
		UISizeX, UISizeY = GetPair(Configs.Size, SavedWidth, SavedHeight)
	end

	UISizeX = math.clamp(UISizeX, MinWidth, MaxWidth)
	UISizeY = math.clamp(UISizeY, MinHeight, MaxHeight)

	local WindowTabSize = math.clamp(
		LoadedSettingKeys.TabSize and Library.Save.TabSize
			or tonumber(Configs.TabSize)
			or Library.Save.TabSize,
		MinTabSize,
		MaxTabSize
	)

	if IsCompactDisplay() then
		WindowTabSize = math.min(WindowTabSize, CompactTabSize)
	end

	local SaveDefaults = false

	if not LoadedSettingKeys.UISize then
		Library.Save.UISize = {UISizeX, UISizeY}
		LoadedSettingKeys.UISize = true
		SaveDefaults = true
	end

	if not LoadedSettingKeys.TabSize then
		Library.Save.TabSize = WindowTabSize
		LoadedSettingKeys.TabSize = true
		SaveDefaults = true
	end

	if not LoadedSettingKeys.MinimizedWidth then
		Library.Save.MinimizedWidth = RequestedMinimizedWidth
		LoadedSettingKeys.MinimizedWidth = true
		SaveDefaults = true
	end

	if not LoadedSettingKeys.Keybind then
		local ResolvedKeybind = GetKeyCode(Keybind)
		if ResolvedKeybind then
			Library.Save.Keybind = ResolvedKeybind.Name
		end
		LoadedSettingKeys.Keybind = true
		SaveDefaults = true
	end

	if SaveDefaults then
		QueueSettingsSave()
	end

	ResponsiveWidth, ResponsiveHeight = UISizeX, UISizeY
	UpdateResponsiveScale()

    local MainFrame = InsertTheme(Create("ImageLabel", ScreenGui, {
        Size = UDim2.fromOffset(UISizeX, UISizeY),
        Position = UDim2.new(0.5, -UISizeX/2, 0.5, -UISizeY/2),
        ClipsDescendants = true,
        BackgroundTransparency = (Library.Save.Transparency or DefaultTransparency) / 100,
        Image = ToAssetContentId(Library.Save.BackgroundImage),
        ImageTransparency = (Library.Save.BackgroundImageTransparency or DefaultBackgroundImageTransparency) / 100,
        ScaleType = BackgroundScaleTypes[Library.Save.BackgroundScale] or BackgroundScaleTypes[DefaultBackgroundScale],
    }), "Main")
    Library.MainFrame = MainFrame
    Library._MouseControl:Bind(MainFrame)
    local WindowPosition = Library._PositionSettings.Bind(MainFrame, "Window", {
        Center = true, Padding = GetResponsivePadding(), TopPadding = 0, Oversized = true
    })
	local MainGradient = InsertTheme(Create("UIGradient", MainFrame, {
		Color = ThemeBackgroundColors(),
		Rotation = GradientRotation,
		Enabled = (Library.Save.BackgroundImage or "") == ""
	}), "MainGradient")
    Library._BackgroundSettings.Apply()
    Library._BackgroundSettings.Resolve()

	Create("UISizeConstraint", MainFrame, {
		MinSize = Vector2.new(0, 0),
		MaxSize = Vector2.new(MaxWidth, MaxHeight)
	})
	
	local MainCorner = Make("Corner", MainFrame, UDim.new(0, CornerRadius))
	
	local Components = Create("Folder", MainFrame, {
	})
	
	local DropdownHolder = Create("Folder", ScreenGui, {
	})
	
	local TopBar = Create("Frame", Components, {
		Size = UDim2.new(1, 0, 0, TopBarHeight),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})
	
	local SubTitleLabel = InsertTheme(Create("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = "X",
		AutoLocalize = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 5, 0.9),
		Text = WMiniText,
		TextColor3 = Theme["Color Dark Text"],
		BackgroundTransparency = 1,
		TextXAlignment = "Left",
		TextYAlignment = "Bottom",
		TextSize = TopBarSubTitleTextSize,
		Font = Enum.Font.Gotham,
	}), "DarkText")

	local Title = InsertTheme(Create("TextLabel", TopBar, {
		Position = UDim2.new(0, TopBarTitlePadding, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		AutomaticSize = "XY",
		Text = WTitle,
		TextXAlignment = "Left",
		TextSize = TopBarTitleTextSize,
		TextColor3 = Theme["Color Text"],
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
	}, {
		SubTitleLabel
	}), "Text")
	
	local function BindAdaptiveScroll(Frame, PaddingY)
		local Layout = Frame:FindFirstChildOfClass("UIListLayout")
		if not Layout then return end

		local function Refresh()
			if not Frame.Parent then return end
			local NeedsScrolling = Layout.AbsoluteContentSize.Y + PaddingY > Frame.AbsoluteSize.Y + 1
			if Frame.ScrollingEnabled ~= NeedsScrolling then
				Frame.ScrollingEnabled = NeedsScrolling
			end
			local Thickness = NeedsScrolling and ScrollThickness or 0
			if Frame.ScrollBarThickness ~= Thickness then
				Frame.ScrollBarThickness = Thickness
			end
		end

		AdaptiveScrollRefresh[Frame] = Refresh
		Frame.ScrollBarImageColor3 = Theme["Color Stroke"]
		Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Refresh)
		Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(Refresh)
		Frame.Destroying:Connect(function()
			AdaptiveScrollRefresh[Frame] = nil
		end)
		task.defer(Refresh)
	end

	local SidebarScrollInset = 7
	local MainScroll = InsertTheme(Create("ScrollingFrame", Components, {
		Size = UDim2.new(0, WindowTabSize - SidebarScrollInset, 1, -TopBar.Size.Y.Offset - SidebarScrollInset * 2),
		ScrollBarImageColor3 = Theme["Color Theme"],
		Position = UDim2.new(0, 0, 1, -SidebarScrollInset),
		AnchorPoint = Vector2.new(0, 1),
		ScrollBarThickness = ScrollThickness,
		BackgroundTransparency = 1,
		ScrollBarImageTransparency = ScrollTransparency,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = "Y",
		ScrollingDirection = "Y",
		BorderSizePixel = 0,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, TabsPadding),
			PaddingRight = UDim.new(0, TabsPadding),
			PaddingTop = UDim.new(0, TabsPadding),
			PaddingBottom = UDim.new(0, TabsPadding)
		}), Create("UIListLayout", {
			Padding = UDim.new(0, TabsSpacing)
		})
	}), "ScrollBar")
	BindAdaptiveScroll(MainScroll, TabsPadding * 2)

	local Containers = Create("Frame", Components, {
		Size = UDim2.new(1, -WindowTabSize, 1, -TopBar.Size.Y.Offset),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})

	local function FreezeContentLayout()
		local Scale = math.max(ScreenScale.Scale, 0.001)
		local FramePosition = MainFrame.AbsolutePosition
		local Frozen = {}

		for _, Object in ipairs({MainScroll, Containers}) do
			local AbsolutePosition = (Object.AbsolutePosition - FramePosition) / Scale
			local AbsoluteSize = Object.AbsoluteSize / Scale
			Frozen[#Frozen + 1] = {
				Object = Object,
				Size = Object.Size,
				Position = Object.Position
			}
			-- Keep the expensive contents at their full layout size while the
			-- outer window animates its clip area.
			Object.Size = UDim2.fromOffset(AbsoluteSize.X, AbsoluteSize.Y)
			Object.Position = UDim2.new(
				0, AbsolutePosition.X + Object.AnchorPoint.X * AbsoluteSize.X,
				0, AbsolutePosition.Y + Object.AnchorPoint.Y * AbsoluteSize.Y
			)
		end

		return Frozen
	end

	local function RestoreContentLayout(Frozen)
		for _, Entry in ipairs(Frozen or {}) do
			if Entry.Object and Entry.Object.Parent then
				Entry.Object.Size = Entry.Size
				Entry.Object.Position = Entry.Position
			end
		end
	end

	local ControlSize1 = Create("Frame", MainFrame, {
		Size = UDim2.fromOffset(ResizeHandleSize, ResizeHandleSize),
		Position = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.8, 0.8),
		Active = Resizable,
		Interactable = Resizable,
		Visible = Resizable,
		BackgroundTransparency = 1,
		ZIndex = 50
	})

	local ControlSize2 = Create("Frame", MainFrame, {
		Size = UDim2.new(0, TabResizeHandleWidth, 1, -TopBar.Size.Y.Offset),
		Position = UDim2.new(0, WindowTabSize, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Active = TabResizable,
		Interactable = TabResizable,
		Visible = TabResizable,
		BackgroundTransparency = 1,
		ZIndex = 50
	})

	local ResizeState
	local SettingsWindowWidth
	local SettingsWindowHeight
	local SettingsTabWidth

	local function SyncSettingsSlider(Control, Value)
		if Control and type(Control.Get) == "function" and type(Control.SetValue) == "function" then
			local Rounded = math.floor(Value)
			if Control:Get() ~= Rounded then
				Control:SetValue(Rounded, true)
			end
		end
	end

	local function IsPointInside(Object, Position)
		if not ScreenGui.Enabled then return false end
		local Ancestor = Object
		while Ancestor and Ancestor ~= ScreenGui do
			if Ancestor:IsA("GuiObject") and not Ancestor.Visible then return false end
			if Ancestor ~= Object and Ancestor:IsA("GuiObject") and Ancestor.ClipsDescendants then
				local Origin, Size = Ancestor.AbsolutePosition, Ancestor.AbsoluteSize
				if Position.X < Origin.X or Position.X > Origin.X + Size.X
					or Position.Y < Origin.Y or Position.Y > Origin.Y + Size.Y then return false end
			end
			Ancestor = Ancestor.Parent
		end
		if not Ancestor then return false end

		local AbsolutePosition = Object.AbsolutePosition
		local AbsoluteSize = Object.AbsoluteSize
		return Position.X >= AbsolutePosition.X
			and Position.X <= AbsolutePosition.X + AbsoluteSize.X
			and Position.Y >= AbsolutePosition.Y
			and Position.Y <= AbsolutePosition.Y + AbsoluteSize.Y
	end

	local FloatingMinimizeButtons = setmetatable({}, {__mode = "k"})
	local FloatingMinimizeCount = 0
	local FloatingMinimizeHeld = 0
	local function IsOverMinimizeButton(Position)
		for Button in pairs(FloatingMinimizeButtons) do
			if Button.Parent and Button.Active and Button.Interactable and IsPointInside(Button, Position) then
				return true
			end
		end
		return false
	end

	local function ApplyWindowSize(Width, Height)
		Width = math.clamp(Width, MinWidth, MaxWidth)
		Height = math.clamp(Height, MinHeight, MaxHeight)
		MainFrame.Size = UDim2.fromOffset(Width, Height)
		ResponsiveWidth, ResponsiveHeight = Width, Height
		UpdateResponsiveScale()
		SyncSettingsSlider(SettingsWindowWidth, Width)
		SyncSettingsSlider(SettingsWindowHeight, Height)
	end

	local function ApplyTabSize(Width)
		Width = math.clamp(Width, MinTabSize, MaxTabSize)
		ControlSize2.Position = UDim2.new(0, Width, 1, 0)
		MainScroll.Size = UDim2.new(0, Width - SidebarScrollInset, 1, -TopBar.Size.Y.Offset - SidebarScrollInset * 2)
		Containers.Size = UDim2.new(1, -Width, 1, -TopBar.Size.Y.Offset)
		SyncSettingsSlider(SettingsTabWidth, Width)
	end

	local function FinishResize()
		local State = ResizeState
		if not State then return end
		ResizeState = nil
		if State.Monitor then
			State.Monitor:Disconnect()
			UntrackConnection(State.Monitor)
		end
		if State.Mode == "Window" then
			Library.Save.UISize = {MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset}
		else
			Library.Save.TabSize = MainScroll.Size.X.Offset + SidebarScrollInset
		end
		QueueSettingsSave()
	end

	local function CanResize(State)
		return MainFrame.Parent and MainFrame.Visible and ScreenGui.Enabled and not Minimized and not WaitClick
			and FloatingMinimizeHeld == 0 and not (Runtime.DialogOverlay and Runtime.DialogOverlay.Parent)
			and ((State.Mode == "Window" and Resizable) or (State.Mode == "Tab" and TabResizable))
	end

	local function UpdateResize(State, Position)
		local Delta = (Position - State.Start) / math.max(ScreenScale.Scale, 0.001)
		if State.Mode == "Window" then
			ApplyWindowSize(State.Width + Delta.X, State.Height + Delta.Y)
		else
			ApplyTabSize(State.TabWidth + Delta.X)
		end
	end

	local function BeginResize(Mode, Input)
		if ResizeState or not CanResize({Mode = Mode}) or IsOverMinimizeButton(Input.Position) then
			return
		end

		local InputType = Input.UserInputType
		if InputType ~= Enum.UserInputType.MouseButton1 and InputType ~= Enum.UserInputType.Touch then
			return
		end
		if Input.UserInputState == Enum.UserInputState.End or Input.UserInputState == Enum.UserInputState.Cancel then return end

		ResizeState = {
			Mode = Mode,
			Input = Input,
			Start = Input.Position,
			Width = MainFrame.Size.X.Offset,
			Height = MainFrame.Size.Y.Offset,
			TabWidth = MainScroll.Size.X.Offset + SidebarScrollInset
		}
		local State = ResizeState
		State.Monitor = TrackConnection(game:GetService("RunService").RenderStepped:Connect(function()
			if ResizeState ~= State then return end
			if not CanResize(State) or Input.UserInputState == Enum.UserInputState.Cancel then
				FinishResize()
			elseif Input.UserInputState == Enum.UserInputState.End then
				UpdateResize(State, Input.Position)
				FinishResize()
			elseif InputType == Enum.UserInputType.MouseButton1
				and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				FinishResize()
			end
		end))
	end

	TrackConnection(ControlSize1.InputBegan:Connect(function(Input)
		if Resizable then
			BeginResize("Window", Input)
		end
	end))

	TrackConnection(ControlSize2.InputBegan:Connect(function(Input)
		if TabResizable then
			BeginResize("Tab", Input)
		end
	end))

	TrackConnection(UserInputService.InputChanged:Connect(function(Input)
		local State = ResizeState
		if not State then
			return
		end
		if not CanResize(State) then
			FinishResize()
			return
		end

		if State.Input.UserInputType == Enum.UserInputType.Touch then
			if Input ~= State.Input then
				return
			end
		elseif Input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		UpdateResize(State, Input.Position)
	end))

	TrackConnection(UserInputService.InputEnded:Connect(function(Input)
		local State = ResizeState
		if not State then
			return
		end

		if Input ~= State.Input then
			return
		end

		if CanResize(State) and Input.UserInputState ~= Enum.UserInputState.Cancel then UpdateResize(State, Input.Position) end
		FinishResize()
	end))
	TrackConnection(UserInputService.WindowFocusReleased:Connect(FinishResize))
	TrackConnection(MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not MainFrame.Visible then FinishResize() end
	end))
	TrackConnection(ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not ScreenGui.Enabled then FinishResize() end
	end))
	TrackConnection(MainFrame.Destroying:Connect(FinishResize))

	local function CanDragWindow(Input)
		if not Draggable or ResizeState or WaitClick or not ScreenGui.Enabled or not MainFrame.Visible
			or (Runtime.DialogOverlay and Runtime.DialogOverlay.Parent) then
			return false
		end

		local Position = Input.Position
		if IsOverMinimizeButton(Position) or not IsPointInside(MainFrame, Position) then
			return false
		end

		if IsPointInside(ControlSize1, Position) or IsPointInside(ControlSize2, Position) then
			return false
		end

		-- Only inspect GUI objects under the pointer. Walking every descendant on
		-- each drag start gets progressively slower as tabs and controls are added.
		local Container = ScreenGui:FindFirstAncestorWhichIsA("BasePlayerGui")
		local Success, Objects = false, nil
		if Container then
			Success, Objects = pcall(Container.GetGuiObjectsAtPosition, Container, Position.X, Position.Y)
		end
		if Success then
			for _, Object in ipairs(Objects) do
				local InsideWindow = Object == MainFrame or Object:IsDescendantOf(MainFrame)
				if InsideWindow then
					if Object == MainFrame then break end
					if Object:IsA("GuiButton") or Object:IsA("TextBox") then return false end
					if Object:IsA("ScrollingFrame") then
						if Object.ScrollingEnabled then
							if Input.UserInputType == Enum.UserInputType.Touch then return false end
							local Thickness = Object.ScrollBarThickness * ScreenScale.Scale
							local Origin, Size = Object.AbsolutePosition, Object.AbsoluteSize
							local Canvas, Window = Object.AbsoluteCanvasSize, Object.AbsoluteWindowSize
							if Thickness > 0 then
								if Object.ScrollingDirection ~= Enum.ScrollingDirection.X and Canvas.Y > Window.Y then
									local Left = Object.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Left
									if (Left and Position.X <= Origin.X + Thickness)
										or (not Left and Position.X >= Origin.X + Size.X - Thickness) then return false end
								end
								if Object.ScrollingDirection ~= Enum.ScrollingDirection.Y and Canvas.X > Window.X
									and Position.Y >= Origin.Y + Size.Y - Thickness then return false end
							end
						end
					elseif Object.Active then
						return false
					end
				elseif Object.Active or Object:IsA("GuiButton") or Object:IsA("TextBox") then
					return false
				end
			end
		else
			-- Compatibility fallback for environments without a GUI hit-test API.
			for _, Object in ipairs(MainFrame:GetDescendants()) do
				if Object:IsA("GuiObject") and IsPointInside(Object, Position) then
					if Object:IsA("GuiButton") or Object:IsA("TextBox") then return false end
					if Object:IsA("ScrollingFrame") then
						if Object.ScrollingEnabled then
							if Input.UserInputType == Enum.UserInputType.Touch then return false end
							local Thickness = Object.ScrollBarThickness * ScreenScale.Scale
							local Origin, Size = Object.AbsolutePosition, Object.AbsoluteSize
							local Canvas, Window = Object.AbsoluteCanvasSize, Object.AbsoluteWindowSize
							if Thickness > 0 then
								if Object.ScrollingDirection ~= Enum.ScrollingDirection.X and Canvas.Y > Window.Y then
									local Left = Object.VerticalScrollBarPosition == Enum.VerticalScrollBarPosition.Left
									if (Left and Position.X <= Origin.X + Thickness)
										or (not Left and Position.X >= Origin.X + Size.X - Thickness) then return false end
								end
								if Object.ScrollingDirection ~= Enum.ScrollingDirection.Y and Canvas.X > Window.X
									and Position.Y >= Origin.Y + Size.Y - Thickness then return false end
							end
						end
					elseif Object.Active then
						return false
					end
				end
			end
			for _, Object in ipairs(ScreenGui:GetDescendants()) do
				if Object:IsA("GuiObject") and Object ~= MainFrame and not Object:IsDescendantOf(MainFrame)
					and (Object.Active or Object:IsA("GuiButton") or Object:IsA("TextBox"))
					and IsPointInside(Object, Position) then
					return false
				end
			end
		end

		return true
	end

	local DragInitialized = false
	local function EnsureWindowDrag()
		if DragInitialized then
			return
		end
		DragInitialized = true
		MakeDrag(MainFrame, {
			Handle = MainFrame,
			Threshold = DragThreshold,
			Move = function(Delta, Bounds) return WindowPosition:MoveBy(Delta, Bounds) end,
			MoveTo = function(Target, Bounds) return WindowPosition:MoveGrabbedTo(Target, Bounds) end,
			PrepareMove = function() return WindowPosition:GetDragBounds() end,
			OnStop = function() WindowPosition:Remember() end,
			CanStart = CanDragWindow,
			GlobalInput = true,
			ShouldCancel = function()
				return not Draggable or not ScreenGui.Enabled or not MainFrame.Visible or WaitClick or ResizeState ~= nil
					or FloatingMinimizeHeld > 0 or (Runtime.DialogOverlay and Runtime.DialogOverlay.Parent ~= nil)
			end
		})
	end

	if Draggable then
		EnsureWindowDrag()
	end

	local Window, FirstTab = {}, false
	local ActiveTab
	local FlagObjects = {}
	local FlagObjectHolders = setmetatable({}, {__mode = "k"})
	local KeybindRegistry = {}
	local CapturingKeybind
	local CapturedKeys = {}
	local WindowKeybindControl
	local TopbarButtons = {}

	-- Both keybind controls share capture ownership, validation and presentation.
	local KeybindBindings = {}
	local function ResolveBindingKey(Key)
		if type(Key) == "string" then
			Key = Key:gsub("^%s*(.-)%s*$", "%1")
		end
		local Resolved = GetKeyCode(Key)
		return Resolved ~= Enum.KeyCode.Unknown and Resolved or nil
	end

	local function IsEmptyBindingKey(Key)
		if Key == nil or Key == false or Key == Enum.KeyCode.Unknown then return true end
		return type(Key) == "string" and (Key:match("^%s*$") ~= nil or Key:match("^%s*(.-)%s*$"):lower() == "none")
	end

	local function CreateKeybindControl(Control, Button, LabelFunc, Configs, Options)
		local Binding = {CurrentKey = nil, Waiting = false, Destroyed = false}
		local Connections, AncestorConnections = {}, {}
		local DisabledKeys = type(Configs.DisabledKeys) == "table" and Configs.DisabledKeys or {}
		local PreventDuplicate = Configs.PreventDuplicate == true
		local Hovered = false
		local MouseCapturePending = false
		local RightOffset = Options.RightOffset or 10
		local Height = 18
		local KeyIcon
		local function GetBooleanOption(Key, Default)
			if type(Configs[Key]) == "boolean" then return Configs[Key] end
			return Default
		end

		local KeyButton = InsertTheme(Create("TextButton", Button, {
			Size = UDim2.fromOffset(Library:GetKeybindWidth(), Height),
			Position = UDim2.new(1, -RightOffset, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Theme["Color Stroke"],
			AutoButtonColor = false,
			Text = "",
			ClipsDescendants = true
		}), "Stroke")
		Make("Corner", KeyButton, UDim.new(0, 4))
		local Accent = InsertTheme(Create("Frame", KeyButton, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme["Color Theme"],
			BackgroundTransparency = 1
		}), "Theme")
		Make("Corner", Accent, UDim.new(0, 4))
		local KeyLabel = InsertTheme(Create("TextLabel", KeyButton, {
			Size = UDim2.new(1, -36, 1, 0),
			Position = UDim2.fromOffset(18, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Theme["Color Text"],
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "...",
			ZIndex = 2
		}), "Text")

		local function Connect(Signal, Callback)
			local NewConnection = Signal:Connect(Callback)
			table.insert(Connections, NewConnection)
			return NewConnection
		end

		local function IsCaptureVisible()
			if not ScreenGui.Enabled or Minimized or not Button:IsDescendantOf(ScreenGui) then return false end
			local Ancestor = Button
			while Ancestor and Ancestor ~= ScreenGui do
				if Ancestor:IsA("GuiObject") and not Ancestor.Visible then return false end
				Ancestor = Ancestor.Parent
			end
			return true
		end

		function Binding:Refresh()
			if self.Destroyed then return end
			local ShowIcon = Configs.KeybindIcon ~= false and Library:GetKeybindIconDefault()
			local BaseWidth = Library._KeybindSettings.NormalizeWidth(Configs.KeybindWidth) or Library:GetKeybindWidth()
			local MinWidth = BaseWidth + (ShowIcon and 14 or 0)
			local TextPadding = ShowIcon and 50 or 36
			if ShowIcon and not KeyIcon then
				KeyIcon = InsertTheme(Create("ImageLabel", KeyButton, {
					Size = UDim2.fromOffset(10, 10),
					Position = UDim2.new(0, 6, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = Library:GetIcon("keyboard"),
					ImageColor3 = Theme["Color Dark Text"],
					ZIndex = 2
				}), "DarkText")
			end
			if KeyIcon then KeyIcon.Visible = ShowIcon end
			local Text = self.Waiting and "..." or (self.CurrentKey and self.CurrentKey.Name or TranslateText("None"))
			local MaxWidth = math.max(MinWidth, math.min(Options.MaxWidth or 150, Button.AbsoluteSize.X - RightOffset - 90))
			local Width = math.clamp(TextService:GetTextSize(Text, 10, Enum.Font.GothamBold, Vector2.new(1000, Height)).X + TextPadding, MinWidth, MaxWidth)
			KeyLabel.Text = Text
			KeyLabel.Size = UDim2.new(1, -TextPadding, 1, 0)
			KeyLabel.Position = UDim2.fromOffset(ShowIcon and 32 or 18, 0)
			KeyButton.Size = UDim2.fromOffset(Width, Height)
			LabelFunc:SetReservedWidth(RightOffset + Width + 8)
			local Active = Options.IsActive() and GetBooleanOption("KeybindHighlight", Library:GetKeybindHighlight())
			local Transparency = self.Waiting and 0.82 or (Hovered and 0.94 or 1)
			if Active then
				local Color = Theme["Color Theme"]
				local Brightness = Color.R * 0.299 + Color.G * 0.587 + Color.B * 0.114
				Transparency = math.clamp(0.25 + math.max(0, Brightness - 0.45) * 0.75, 0.25, 0.6)
			end
			CreateTween({Accent, "BackgroundTransparency", Transparency, AnimationToggle})
		end

		function Binding:ContainsInput(Input)
			if Input and Input == self.CaptureInput then return true end
			if not Input or (Input.UserInputType ~= Enum.UserInputType.MouseButton1
				and Input.UserInputType ~= Enum.UserInputType.Touch) then return false end
			local Point, Position, Size = Input.Position, KeyButton.AbsolutePosition, KeyButton.AbsoluteSize
			return Point.X >= Position.X and Point.X <= Position.X + Size.X
				and Point.Y >= Position.Y and Point.Y <= Position.Y + Size.Y
		end

		function Binding:SetWaiting(Value)
			if self.Destroyed then return false end
			Value = Value == true
			if Value and (Control:IsLocked() or not IsCaptureVisible()) then return false end
			if Value and CapturingKeybind and CapturingKeybind ~= self then
				CapturingKeybind:SetWaiting(false)
			end
			self.Waiting = Value
			if Value then
				CapturingKeybind = self
			elseif CapturingKeybind == self then
				CapturingKeybind = nil
			end
			self:Refresh()
			return true
		end

		local function UnregisterKey()
			local Owners = KeybindRegistry[Binding.CurrentKey]
			if Owners then
				Owners[Binding] = nil
				if next(Owners) == nil then KeybindRegistry[Binding.CurrentKey] = nil end
			end
		end

		function Binding:SetKey(Key, Notify)
			if self.Destroyed then return false end
			local Resolved = ResolveBindingKey(Key)
			if not Resolved and not (Options.AllowNone and IsEmptyBindingKey(Key)) then return false end
			if Resolved then
				for _, DisabledKey in ipairs(DisabledKeys) do
					if ResolveBindingKey(DisabledKey) == Resolved then return false end
				end
				for Owner in pairs(KeybindRegistry[Resolved] or {}) do
					if Owner ~= self and (PreventDuplicate or Owner.PreventDuplicate) then return false end
				end
			end
			local Changed = self.CurrentKey ~= Resolved
			UnregisterKey()
			self.CurrentKey = Resolved
			if Resolved then
				KeybindRegistry[Resolved] = KeybindRegistry[Resolved] or {}
				KeybindRegistry[Resolved][self] = true
			end
			self:Refresh()
			if Changed and Notify and type(Options.OnChanged) == "function" then
				Funcs:FireCallback({Options.OnChanged}, self.CurrentKey)
			end
			return true
		end

		function Binding:Capture(Key)
			if self.Destroyed or Control:IsLocked() or not IsCaptureVisible() then
				self:SetWaiting(false)
				return
			end
			if Key == Enum.KeyCode.Escape then
				self:SetWaiting(false)
				if Options.AllowNone then self:SetKey(nil, true) end
			elseif Key == Enum.KeyCode.Backspace and Options.AllowNone then
				self:SetWaiting(false)
				self:SetKey(nil, true)
			elseif self:SetKey(Key, false) then
				self:SetWaiting(false)
				if type(Options.OnChanged) == "function" then
					Funcs:FireCallback({Options.OnChanged}, self.CurrentKey)
				end
			end
		end

		function Binding:Trigger()
			if self.Destroyed then return end
			if Control:IsLocked() then
				Control:NotifyLocked()
				return
			end
			Options.OnTriggered()
		end

		function Binding:Destroy()
			if self.Destroyed then return end
			self.Destroyed = true
			self.Waiting = false
			self.CaptureInput = nil
			if CapturingKeybind == self then CapturingKeybind = nil end
			UnregisterKey()
			KeybindBindings[self] = nil
			Library._KeybindSettings.Listeners[self] = nil
			for _, Item in ipairs(AncestorConnections) do Item:Disconnect() end
			for _, Item in ipairs(Connections) do Item:Disconnect() end
			table.clear(AncestorConnections)
			table.clear(Connections)
		end

		local function CancelHiddenCapture()
			if Binding.Waiting and not IsCaptureVisible() then Binding:SetWaiting(false) end
		end
		local function WatchAncestors()
			for _, Item in ipairs(AncestorConnections) do Item:Disconnect() end
			table.clear(AncestorConnections)
			local Ancestor = Button
			while Ancestor and Ancestor ~= ScreenGui do
				if Ancestor:IsA("GuiObject") then
					table.insert(AncestorConnections, Ancestor:GetPropertyChangedSignal("Visible"):Connect(CancelHiddenCapture))
				end
				Ancestor = Ancestor.Parent
			end
			CancelHiddenCapture()
		end

		Connect(KeyButton.Activated, function(Input)
			if Input and (Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.MouseButton2) then
				MouseCapturePending = false
				return
			end
			if not Input and MouseCapturePending then
				MouseCapturePending = false
				return
			end
			MouseCapturePending = false
			if Control:IsLocked() then
				Control:NotifyLocked()
				return
			end
			Binding:SetWaiting(not Binding.Waiting)
		end)
		Connect(KeyButton.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1
				or (Input.UserInputType == Enum.UserInputType.MouseButton2
					and GetBooleanOption("KeybindRightClick", Library:GetKeybindRightClick())) then
				if Control:IsLocked() then
					Control:NotifyLocked()
					return
				end
				MouseCapturePending = Input.UserInputType == Enum.UserInputType.MouseButton1
				Binding.CaptureInput = Input
				Binding:SetWaiting(not Binding.Waiting)
			end
		end)
		Connect(KeyButton.MouseEnter, function()
			Hovered = true
			Binding:Refresh()
		end)
		Connect(KeyButton.MouseLeave, function()
			Hovered = false
			Binding:Refresh()
		end)
		Connect(Button:GetPropertyChangedSignal("AbsoluteSize"), function() Binding:Refresh() end)
		Connect(Button.AncestryChanged, WatchAncestors)
		Connect(ScreenGui:GetPropertyChangedSignal("Enabled"), CancelHiddenCapture)
		Connect(Connection.LanguageChanged, function() Binding:Refresh() end)
		Connect(Connection.ThemeChanged, function() Binding:Refresh() end)
		Connect(Button.Destroying, function() Binding:Destroy() end)
		Binding.PreventDuplicate = PreventDuplicate
		KeybindBindings[Binding] = true
		Library._KeybindSettings.Listeners[Binding] = function() Binding:Refresh() end
		WatchAncestors()
		Binding:SetKey(Options.InitialKey, false)
		Binding:Refresh()
		return Binding
	end


	local TopbarControls = Create("Frame", TopBar, {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, -TopBarControlsRightPadding, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, TopBarControlsSpacing)
		})
	})

	local function NormalizeObjectFlag(Flag)
		if type(Flag) ~= "string" then
			return nil
		end

		Flag = Flag:gsub("^%s*(.-)%s*$", "%1")
		return Flag ~= "" and Flag or nil
	end

	local function RegisterFlagObject(Flag, Object, Holder)
		Flag = NormalizeObjectFlag(Flag)
		if not Flag or type(Object) ~= "table" then
			return Object
		end

		Holder = Holder or FlagObjectHolders[Object]
		FlagObjects[Flag] = Object
		FlagObjectHolders[Object] = Holder
		Object.Flag = Flag

		function Object:GetFlag()
			return Flag
		end

		if typeof(Holder) == "Instance" and Holder:IsA("GuiObject") then
			function Object:Order(Value)
				if Value == nil then
					return Holder.LayoutOrder
				end

				local NewOrder = tonumber(Value)
				if not NewOrder then
					return false
				end

				Holder.LayoutOrder = math.floor(NewOrder)
				return Object
			end

			Object.SetOrder = Object.Order

			function Object:GetOrder()
				return Holder.LayoutOrder
			end
		end

		local OriginalDestroy = Object.Destroy
		if type(OriginalDestroy) == "function" then
			function Object:Destroy(...)
				if FlagObjects[Flag] == self then
					FlagObjects[Flag] = nil
				end

				FlagObjectHolders[self] = nil
				return OriginalDestroy(self, ...)
			end
		end

		if typeof(Holder) == "Instance" then
			Holder.Destroying:Connect(function()
				if FlagObjects[Flag] == Object then
					FlagObjects[Flag] = nil
				end

				FlagObjectHolders[Object] = nil
			end)
		end

		return Object
	end

	function Window:GetFlag(Name)
		Name = NormalizeObjectFlag(Name)
		return Name and FlagObjects[Name] or nil
	end

	function Window:HasFlag(Name)
		return self:GetFlag(Name) ~= nil
	end

	function Window:GetFlags()
		return table.clone(FlagObjects)
	end

	function Window:AddTopbarButton(ButtonConfig)
		ButtonConfig = type(ButtonConfig) == "table" and ButtonConfig or {}

		local Icon = ButtonConfig.Icon or ButtonConfig.Image or ControlsConfig.TopBarIcon
		if type(Icon) == "string" and not Icon:find("rbxasset", 1, true) then
			Icon = Library:GetIcon(Icon) or Icon
		elseif type(Icon) == "number" then
			Icon = "rbxassetid://" .. tostring(Icon)
		end

		local BaseTransparency = math.clamp(tonumber(ButtonConfig.Transparency) or TopBarButtonTransparency, 0, 1)
		local ButtonSize = math.clamp(tonumber(ButtonConfig.Size) or GetTopbarButtonSize(), 12, 28)
		local Button = Create("ImageButton", TopbarControls, {
			Size = UDim2.fromOffset(ButtonSize, ButtonSize),
			BackgroundTransparency = 1,
			Image = tostring(Icon or ""),
			ImageColor3 = Theme["Color Text"],
			ImageTransparency = BaseTransparency,
			AutoButtonColor = false,
			LayoutOrder = tonumber(ButtonConfig.Order) or (#TopbarButtons + 1),
			Visible = ButtonConfig.Visible ~= false
		})
		InsertTheme(Button, "Icon")

		local ActiveButton = false
		TrackConnection(Button.MouseEnter:Connect(function()
			CreateTween({Button, "ImageTransparency", 0, AnimationTopBar})
		end))
		TrackConnection(Button.MouseLeave:Connect(function()
			CreateTween({Button, "ImageTransparency", ActiveButton and 0 or BaseTransparency, AnimationTopBar})
		end))

		local Callback = ButtonConfig.Callback
		if type(Callback) == "function" then
			TrackConnection(Button.Activated:Connect(function()
				task.spawn(Callback, Button)
			end))
		end

		local Controller = {Button = Button}

		function Controller:SetIcon(NewIcon)
			if type(NewIcon) == "number" then
				NewIcon = "rbxassetid://" .. tostring(NewIcon)
			elseif type(NewIcon) == "string" and not NewIcon:find("rbxasset", 1, true) then
				NewIcon = Library:GetIcon(NewIcon) or NewIcon
			end
			Button.Image = tostring(NewIcon or "")
		end

		function Controller:SetVisible(Value)
			Button.Visible = Value ~= false
		end

		function Controller:SetActive(Value)
			ActiveButton = Value == true
			Button.ImageTransparency = ActiveButton and 0 or BaseTransparency
		end

		function Controller:SetSize(Value)
			local Size = math.clamp(tonumber(Value) or GetTopbarButtonSize(), 12, 28)
			Button.Size = UDim2.fromOffset(Size, Size)
		end

		function Controller:Destroy()
			Button:Destroy()
		end

		TopbarButtons[#TopbarButtons + 1] = Controller
		return Controller
	end

	local ConfigButton = Window:AddTopbarButton({
		Icon = "settings",
		Order = 10,
		Visible = LibraryConfig.ConfigButton ~= false and Configs.ConfigButton ~= false,
		Callback = function()
			Window:ConfigBtn()
		end
	})

	local MinimizeButton = Window:AddTopbarButton({
		Icon = "minus",
		Order = 20,
		Callback = function()
			Window:MinimizeBtn()
		end
	})

	local CloseButton = Window:AddTopbarButton({
		Icon = "x",
		Order = 30,
		Callback = function()
			Window:CloseBtn()
		end
	})

	Window.Topbar = {
		Config = ConfigButton,
		Minimize = MinimizeButton,
		Close = CloseButton
	}

	TrackConnection(UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		local Size = GetTopbarButtonSize()
		for _, Controller in ipairs(TopbarButtons) do
			if Controller.SetSize then
				Controller:SetSize(Size)
			end
		end
	end))

	local CloseCallback
	local MinimizeCallback
	
	function Window:Close(Callback)
		if type(Callback) == "function" then
			CloseCallback = Callback
		end
	end

	function Window:Minimize(Callback)
		if type(Callback) == "function" then
			MinimizeCallback = Callback
		end
	end

	function Window:IsOpen()
		return MainFrame.Visible
	end
	function Window:IsMinimize()
		return Minimized
	end
	
	function Window:OnOpenChanged(Callback)
	    return MainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	        Callback(MainFrame.Visible)
	    end)
	end
	
	function Window:CloseBtn()
		Window:Dialog({
			Title = "Close",
			Text = "Are you sure you want to exit?",
			Options = {
				{Name = "Cancel", Style = "Secondary"},
				{
					Name = "Confirm",
					Style = "Primary",
					Callback = function()
						if CloseCallback then CloseCallback() end
						if type(Library._BeforeClose) == "function" then
							Library._BeforeClose()
						end
						ScreenGui:Destroy()
					end
				}
			}
		})
	end
	function Window:MinimizeBtn()
		if Runtime.DialogOverlay and Runtime.DialogOverlay.Parent then return end
		if WaitClick then return end
		FinishResize()
		WaitClick = true

		if Minimized then
			MinimizeButton:SetIcon("minus")
			CreateTween({MainFrame, "Size", SaveSize, AnimationWindow, true})
			RestoreContentLayout(FrozenContentLayout)
			FrozenContentLayout = nil
			SubTitleLabel.Visible = true
			ControlSize1.Visible = Resizable
			ControlSize2.Visible = TabResizable
			ResponsiveWidth, ResponsiveHeight = SaveSize.X.Offset, SaveSize.Y.Offset
			UpdateResponsiveScale()
			Minimized = false
		else
			MinimizeButton:SetIcon("maximize2")
			SaveSize = MainFrame.Size
			ControlSize1.Visible = false
			ControlSize2.Visible = false
			SubTitleLabel.Visible = false
			FrozenContentLayout = FreezeContentLayout()
			CreateTween({MainFrame, "Size", UDim2.fromOffset(MinimizedWidth, TopBarHeight), AnimationWindow, true})
			ResponsiveWidth, ResponsiveHeight = MinimizedWidth, TopBarHeight
			UpdateResponsiveScale()
			Minimized = true
		end

		Library._MouseControl.Minimized = Minimized
		Library._MouseControl:Refresh()
		if MinimizeCallback then
			MinimizeCallback(Minimized)
		end
		WaitClick = false
	end
	function Window:SetTitle(NewTitle)
		if type(NewTitle) ~= "string" then
			return
		end

		Title.Text = NewTitle
		local Width = TextService:GetTextSize(NewTitle, 12, Enum.Font.GothamMedium, Vector2.new(1000, 28)).X
		MinimizedWidth = math.clamp(math.max(RequestedMinimizedWidth, Width + 115), 160, math.min(320, MaxWidth))
	end

	function Window:SetSubTitle(NewSubTitle)
		if type(NewSubTitle) ~= "string" then
			return
		end

		SubTitleLabel.Text = NewSubTitle
	end

    function Window:GetTitle()
        return Title.Text
    end
    function Window:GetSubTitle()
        return SubTitleLabel.Text
    end

	function Window:GetTopbarButtons()
		return table.clone(TopbarButtons)
	end

	function Window:SetConfigButtonVisible(Value)
		ConfigButton:SetVisible(Value ~= false)
	end

	function Window:SetMinimizedWidth(Value)
		local Width = tonumber(Value)
		if not Width then
			return false
		end

		Width = math.clamp(Width, 160, math.min(320, MaxWidth))
		if RequestedMinimizedWidth == Width then return true end
		RequestedMinimizedWidth = Width
		local TextWidth = TextService:GetTextSize(Title.Text, TopBarTitleTextSize, Enum.Font.GothamMedium, Vector2.new(1000, TopBarHeight)).X
		MinimizedWidth = math.clamp(math.max(RequestedMinimizedWidth, TextWidth + 115), 160, math.min(320, MaxWidth))
		Library.Save.MinimizedWidth = RequestedMinimizedWidth
		QueueSettingsSave()

		if Minimized then
			MainFrame.Size = UDim2.fromOffset(MinimizedWidth, TopBarHeight)
			ResponsiveWidth, ResponsiveHeight = MinimizedWidth, TopBarHeight
			UpdateResponsiveScale()
		end

		return true
	end

	function Window:GetMinimizedWidth()
		return RequestedMinimizedWidth
	end

	function Window:GetSize()
		return Vector2.new(MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset)
	end

	function Window:SetSize(Width, Height)
		Width, Height = tonumber(Width), tonumber(Height)
		if not Width or not Height then
			return false
		end

		Width = math.clamp(Width, MinWidth, MaxWidth)
		Height = math.clamp(Height, MinHeight, MaxHeight)
		if MainFrame.Size.X.Offset == Width and MainFrame.Size.Y.Offset == Height then return true end
		ApplyWindowSize(Width, Height)
		Library.Save.UISize = {MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset}
		QueueSettingsSave()
		return true
	end

	function Window:GetTabSize()
		return MainScroll.Size.X.Offset + SidebarScrollInset
	end

	function Window:SetTabSize(Width)
		Width = tonumber(Width)
		if not Width then
			return false
		end

		Width = math.clamp(Width, MinTabSize, MaxTabSize)
		if MainScroll.Size.X.Offset + SidebarScrollInset == Width then return true end
		ApplyTabSize(Width)
		Library.Save.TabSize = MainScroll.Size.X.Offset + SidebarScrollInset
		QueueSettingsSave()
		return true
	end

	function Window:IsDraggable()
		return Draggable
	end

	function Window:SetDraggable(Value)
		if type(Value) ~= "boolean" then
			return false
		end
		if Draggable == Value then return true end

		Draggable = Value
		if Value then
			EnsureWindowDrag()
		end
		Library.Save.Draggable = Value
		QueueSettingsSave()
		return true
	end

	function Window:IsResizable()
		return Resizable
	end

	function Window:SetResizable(Value)
		if type(Value) ~= "boolean" then
			return false
		end
		if Resizable == Value then return true end

		Resizable = Value
		if not Value and ResizeState and ResizeState.Mode == "Window" then
			FinishResize()
		end
		ControlSize1.Active = Value
		ControlSize1.Interactable = Value
		ControlSize1.Visible = Value and not Minimized
		Library.Save.Resizable = Value
		QueueSettingsSave()
		return true
	end

	function Window:IsTabResizable()
		return TabResizable
	end

	function Window:SetTabResizable(Value)
		if type(Value) ~= "boolean" then
			return false
		end
		if TabResizable == Value then return true end

		TabResizable = Value
		if not Value and ResizeState and ResizeState.Mode == "Tab" then
			FinishResize()
		end
		ControlSize2.Active = Value
		ControlSize2.Interactable = Value
		ControlSize2.Visible = Value and not Minimized
		Library.Save.TabResizable = Value
		QueueSettingsSave()
		return true
	end

    function Window:SetVisibility(NewVisibility)
        if type(NewVisibility) ~= "boolean" then
            return
        end

        MainFrame.Visible = NewVisibility
        Library._MouseControl:Refresh()
    end

	function Window:Visible()
		Window:SetVisibility(not Window:GetVisibility())
	end

    function Window:GetVisibility()
        return MainFrame.Visible
    end

	--- 
	
	local WindowKeybindEnabled = Configs.Keybind ~= false
	local WindowKeybind = GetKeyCode(Keybind) or Enum.KeyCode.G
	local WindowKeybindCooldown = false

	function Window:EnableKeybind()
		WindowKeybindEnabled = true
	end

	function Window:DisableKeybind()
		WindowKeybindEnabled = false
	end

	function Window:IsKeybindEnabled()
		return WindowKeybindEnabled
	end

	function Window:SetKeybind(Key)
		local Resolved

		Resolved = GetKeyCode(Key)

		if not Resolved then
			return false
		end

		if WindowKeybindControl and WindowKeybindControl:GetKeybind() ~= Resolved then
			if not WindowKeybindControl:SetKeybind(Resolved) then return false end
		end
		WindowKeybind = Resolved
		Library.Save.Keybind = Resolved.Name
		QueueSettingsSave()
		return true
	end

	function Window:GetKeybind()
		return WindowKeybind
	end

	-- Route capture before shortcuts so connection order cannot activate a captured key.
	local HeldBindingKeys = {}
	TrackConnection(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if Input.UserInputType ~= Enum.UserInputType.Keyboard or Input.KeyCode == Enum.KeyCode.Unknown then return end
		local Key = Input.KeyCode
		if Runtime.DialogOverlay and Runtime.DialogOverlay.Parent then return end
		if HeldBindingKeys[Key] then return end
		HeldBindingKeys[Key] = true
		if UserInputService:GetFocusedTextBox() then
			if CapturingKeybind then CapturingKeybind:SetWaiting(false) end
			return
		end
		if CapturingKeybind then
			CapturedKeys[Key] = true
			CapturingKeybind:Capture(Key)
			return
		end
		-- Our CapsLock sink blocks the game, while hub shortcuts remain usable.
		local HubOwnsCapsLock = Key == Enum.KeyCode.CapsLock and Library._MouseControl.Active
		if (GameProcessed and not HubOwnsCapsLock) or CapturedKeys[Key] then return end

		local Matching = {}
		for Binding in pairs(KeybindBindings) do
			if Binding.CurrentKey == Key then table.insert(Matching, Binding) end
		end
		if Key == WindowKeybind and WindowKeybindEnabled and not WindowKeybindCooldown then
			WindowKeybindCooldown = true
			Window:Visible()
			task.delay(0.15, function() WindowKeybindCooldown = false end)
		end
		for _, Binding in ipairs(Matching) do
			if Binding.CurrentKey == Key then Binding:Trigger() end
		end
	end))

	TrackConnection(UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			CapturedKeys[Input.KeyCode] = nil
			HeldBindingKeys[Input.KeyCode] = nil
		end
	end))
	TrackConnection(UserInputService.TextBoxFocused:Connect(function()
		if CapturingKeybind then CapturingKeybind:SetWaiting(false) end
	end))
	TrackConnection(UserInputService.WindowFocusReleased:Connect(function()
		if CapturingKeybind then CapturingKeybind:SetWaiting(false) end
		table.clear(CapturedKeys)
		table.clear(HeldBindingKeys)
	end))
	ScreenGui.Destroying:Connect(function()
		for Binding in pairs(table.clone(KeybindBindings)) do Binding:Destroy() end
		table.clear(CapturedKeys)
		table.clear(HeldBindingKeys)
	end)

	--- 

    function Window:SetFloatingMinimizeButtonVisible(Value)
        if type(Value) ~= "boolean" then return false end
        Library.Save.ShowFloatingMinimizeButton = Value
        for Button in pairs(FloatingMinimizeButtons) do
            if Button.Parent then
                Button.Visible = Value
            else
                FloatingMinimizeButtons[Button] = nil
            end
        end
        QueueSettingsSave()
        return true
    end

	function Window:AddMinimizeButton(Configs)
		Configs = type(Configs) == "table" and Configs or {}
		local IconConfig = type(RootConfig.Icon) == "table" and RootConfig.Icon or {}
		local ButtonProps = {
			Image = RootConfig.Image,
			ImageTransparency = math.clamp((tonumber(IconConfig.Transparency) or 0) / 100, 0, 1)
		}
		if type(Configs.Button) == "table" then
			for Key, Value in pairs(Configs.Button) do
				ButtonProps[Key] = Value
			end
		end
		ButtonProps.Image = ResolveGuiImage(ButtonProps.Image)

		local Button = Create("ImageButton", ScreenGui, {
			Size = UDim2.fromOffset(35, 35),
			Position = UDim2.fromScale(0.15, 0.15),
			BackgroundTransparency = 1,
			BackgroundColor3 = Theme["Color Hub 2"],
			AutoButtonColor = false,
			Active = true,
			ZIndex = 100
		})
		InsertTheme(Button, "IconSurface")

		local CornerConfig = Configs.Corner
		if CornerConfig == nil then
			CornerConfig = {
				CornerRadius = UDim.new(0, math.max(0, tonumber(IconConfig.Corner) or 0))
			}
		end

		local Stroke, Corner
		if type(CornerConfig) == "table" then
			Corner = Make("Corner", Button)
			SetProps(Corner, CornerConfig)
		end
		if type(Configs.Stroke) == "table" then
			Stroke = Make("Stroke", Button)
			SetProps(Stroke, Configs.Stroke)
		end

		SetProps(Button, ButtonProps)
        Button.Visible = Library.Save.ShowFloatingMinimizeButton ~= false
		FloatingMinimizeButtons[Button] = true

		local PointerType, TouchInput, StartPointer, StartPosition, StartAbsolute
		local Dragged = false
		local Padding = math.max(0, tonumber(Configs.DragPadding) or 6)
		local Threshold = math.max(5, tonumber(Configs.DragThreshold) or DragThreshold)

		local function ClampToScreen(Position)
			local Origin = ScreenGui.AbsolutePosition
			local Available = ScreenGui.AbsoluteSize
			local Size = Button.AbsoluteSize
			local MinX, MinY = Origin.X + Padding, Origin.Y + Padding
			local MaxX = math.max(MinX, Origin.X + Available.X - Size.X - Padding)
			local MaxY = math.max(MinY, Origin.Y + Available.Y - Size.Y - Padding)
			return Vector2.new(math.clamp(Position.X, MinX, MaxX), math.clamp(Position.Y, MinY, MaxY))
		end

		local function SetAbsolutePosition(Target, Origin, Position)
			local Delta = Target - Origin
			local Scale = math.max(ScreenScale.Scale, 0.001)
			Button.Position = UDim2.new(
				Position.X.Scale, Position.X.Offset + Delta.X / Scale,
				Position.Y.Scale, Position.Y.Offset + Delta.Y / Scale
			)
		end

		Button.InputBegan:Connect(function(Input)
			local Kind = Input.UserInputType
			if PointerType or (Kind ~= Enum.UserInputType.MouseButton1 and Kind ~= Enum.UserInputType.Touch) then
				return
			end

			PointerType = Kind
			FloatingMinimizeHeld += 1
			TouchInput = Kind == Enum.UserInputType.Touch and Input or nil
			StartPointer = Vector2.new(Input.Position.X, Input.Position.Y)
			StartPosition = Button.Position
			StartAbsolute = Button.AbsolutePosition
			Dragged = false
		end)

		local InputChangedConnection = UserInputService.InputChanged:Connect(function(Input)
			if not PointerType then return end

			if TouchInput then
				if Input ~= TouchInput then return end
			elseif Input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local Pointer = Vector2.new(Input.Position.X, Input.Position.Y)
			local Delta = Pointer - StartPointer
			local MinMovement = PointerType == Enum.UserInputType.Touch and math.max(10, Threshold) or Threshold
			if not Dragged and Delta.Magnitude < MinMovement then return end

			Dragged = true
			SetAbsolutePosition(ClampToScreen(StartAbsolute + Delta), StartAbsolute, StartPosition)
		end)

		local InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
			if not PointerType then return end
			if TouchInput then
				if Input ~= TouchInput then return end
			elseif Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end

			local Delta = Vector2.new(Input.Position.X, Input.Position.Y) - StartPointer
			local MinMovement = PointerType == Enum.UserInputType.Touch and math.max(10, Threshold) or Threshold
			if Delta.Magnitude >= MinMovement then
				Dragged = true
				SetAbsolutePosition(ClampToScreen(StartAbsolute + Delta), StartAbsolute, StartPosition)
			end

			FloatingMinimizeHeld = math.max(0, FloatingMinimizeHeld - 1)
			PointerType, TouchInput, StartPointer, StartPosition, StartAbsolute = nil, nil, nil, nil, nil
		end)

		local FocusConnection = UserInputService.WindowFocusReleased:Connect(function()
			if PointerType then
				Dragged = true
				FloatingMinimizeHeld = math.max(0, FloatingMinimizeHeld - 1)
			end
			PointerType, TouchInput, StartPointer, StartPosition, StartAbsolute = nil, nil, nil, nil, nil
		end)

		Button.Destroying:Connect(function()
			if PointerType then
				FloatingMinimizeHeld = math.max(0, FloatingMinimizeHeld - 1)
				PointerType = nil
			end
			FloatingMinimizeButtons[Button] = nil
			InputChangedConnection:Disconnect()
			InputEndedConnection:Disconnect()
			FocusConnection:Disconnect()
		end)

		Button.Activated:Connect(function(Input)
			local Kind = Input and Input.UserInputType
			if Kind == Enum.UserInputType.Touch or Kind == Enum.UserInputType.MouseButton1 then
				if Dragged then return end
			end
			Window:Visible()
		end)

		FloatingMinimizeCount += 1
		Library._PositionSettings.Bind(Button, "Minimize" .. FloatingMinimizeCount, {Randomize = true, Padding = Padding})

		return {
			Stroke = Stroke,
			Corner = Corner,
			Button = Button
		}
	end
	function Window:Set(Val1, Val2)
		if type(Val1) == "string" and type(Val2) == "string" then
			Title.Text = Val1
			SubTitleLabel.Text = Val2
		elseif type(Val1) == "string" then
			Title.Text = Val1
		end
	end
	local ActiveDialog

	function Window:Dialog(Configs)
		if ActiveDialog and ActiveDialog.Parent then return nil end
		if Minimized then Window:MinimizeBtn() end
		Configs = type(Configs) == "table" and Configs or {}
		local PopupMode = Configs._Popup == true
		local TitleFontSize = PopupMode and 20 or 16
		local MessageFontSize = PopupMode and 16 or 14
		local Defaults = type(ControlsConfig.Dialog) == "table" and ControlsConfig.Dialog or {}
		local TitleSource = tostring(Configs[1] or Configs.Title or ControlsConfig.Titles.Dialog)
		local MessageSource = tostring(Configs[2] or Configs.Text or Configs.Description or Configs.Desc or ControlsConfig.Titles.DialogText)
		local Options = Configs[3] or Configs.Options or {}
		local MessageValues = Configs.Values or Configs.FormatValues
		local function TranslateDialog(Source)
			if type(Hub) == "table" and type(Hub.Translate) == "function" then
				return Hub:Translate(Source, Library:GetLanguage())
			end
			return TranslateText(Source)
		end
		local function RenderMessage()
			local Result = TranslateDialog(MessageSource)
			if type(MessageValues) == "table" and type(Hub) == "table" and type(Hub.Format) == "function" then
				Result = Hub:Format(Result, MessageValues)
			end
			return Result
		end
		local HorizontalPadding = math.clamp(tonumber(Configs.HorizontalPadding) or tonumber(Defaults.HorizontalPadding) or 12, 8, 30)
		local Width = math.clamp(tonumber(Configs.Width) or tonumber(Defaults.Width) or 420, 220, math.max(220, MainFrame.Size.X.Offset - 24))
		local MaxHeight = math.clamp(tonumber(Configs.MaxHeight) or tonumber(Defaults.MaxHeight) or 300, 126, math.max(126, MainFrame.Size.Y.Offset - 18))
		local MinHeight = math.min(MaxHeight, math.max(126, tonumber(Configs.MinHeight) or tonumber(Defaults.MinHeight) or 190))
		local PaddingTop = math.clamp(tonumber(Configs.PaddingTop) or tonumber(Defaults.PaddingTop) or 12, 8, 32)
		local PaddingBottom = math.clamp(tonumber(Configs.PaddingBottom) or tonumber(Defaults.PaddingBottom) or 14, 8, 32)
		local TitleGap = math.clamp(tonumber(Configs.TitleGap) or tonumber(Defaults.TitleGap) or 4, 0, 12)
		local ContentGap = math.clamp(tonumber(Configs.ContentGap) or tonumber(Defaults.ContentGap) or 26, 5, 42)
		local CornerRadius = math.clamp(tonumber(Configs.CornerRadius) or tonumber(Defaults.CornerRadius) or 11, 4, 20)
		local ButtonCornerRadius = math.clamp(tonumber(Configs.ButtonCornerRadius) or tonumber(Defaults.ButtonCornerRadius) or 8, 3, 18)
		-- Scale default action dimensions with the dialog's width. Explicit
		-- ButtonHeight/ButtonMaxWidth settings retain their literal values.
		local WidthRatio = Width / math.max(1, tonumber(Defaults.Width) or 420)
		local ButtonHeight = math.clamp(
			tonumber(Configs.ButtonHeight) or math.floor((tonumber(Defaults.ButtonHeight) or 36) * WidthRatio + 0.5),
			30, 46
		)
		local ButtonGap = math.clamp(tonumber(Configs.ButtonSpacing) or tonumber(Defaults.ButtonSpacing) or 10, 0, 20)
		local ButtonMaxWidth = math.clamp(
			tonumber(Configs.ButtonMaxWidth) or math.floor((tonumber(Defaults.ButtonMaxWidth) or 124) * WidthRatio + 0.5),
			90, 240
		)
		local SingleButtonMaxWidth = math.clamp(
			tonumber(Configs.SingleButtonMaxWidth) or math.floor((tonumber(Defaults.SingleButtonMaxWidth) or 196) * WidthRatio + 0.5),
			130, 320
		)
		if PopupMode and #Options == 0 then
			ButtonHeight = 0
			ContentGap = 0
		end
		local DefaultButtonColor = Configs.ButtonColor or Defaults.ButtonColor or "Color Stroke"
		local DefaultButtonTextColor = Configs.ButtonTextColor or Defaults.ButtonTextColor or "Color Text"
		local Alignment = tostring(Configs.ButtonAlignment or Defaults.ButtonAlignment or "Center")
		local AnimOpen = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local AnimFade = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local AnimClose = TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local AnimButton = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local function ResolveColor(Value, Fallback)
			if typeof(Value) == "Color3" then return Value end
			if type(Value) == "string" then
				if typeof(Theme[Value]) == "Color3" then return Theme[Value] end
				local Aliases = {
					Theme = "Color Theme", Accent = "Color Theme",
					Stroke = "Color Stroke", Text = "Color Text",
					Background = "Color Hub 2", Hub = "Color Hub 2"
				}
				local Key = Aliases[Value]
				if Key and typeof(Theme[Key]) == "Color3" then return Theme[Key] end
				if Value:match("^#?%x%x%x%x%x%x$") then
					local Success, Color = pcall(Color3.fromHex, Value:sub(1, 1) == "#" and Value or "#" .. Value)
					if Success then return Color end
				end
			end
			return Fallback
		end

		local PreviousMainZIndex = MainFrame.ZIndex
		local RootModal = Create("TextButton", ScreenGui, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Active = true,
			Selectable = false,
			ZIndex = 10000
		})
		MainFrame.ZIndex = 10001

		-- SpecterX translates dialog content using its own selected language.
		-- Roblox's AutoLocalize can otherwise render different text than .Text
		-- (for example Close -> Fechar while Library:GetLanguage() is US).
		local Overlay = InsertTheme(Create("TextButton", MainFrame, {
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			ZIndex = 10002,
			AutoLocalize = false,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme["Color Stroke"],
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = true
		}), "Stroke")
		ActiveDialog = Overlay
		Runtime.DialogOverlay = Overlay
		MainCorner:Clone().Parent = Overlay

		local Panel = InsertTheme(Create("Frame", Overlay, {
			Size = UDim2.fromOffset(Width, MinHeight),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme["Color Hub 2"],
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			BorderSizePixel = 0
		}), "Frame")
		Make("Corner", Panel, UDim.new(0, CornerRadius))
		Make("Stroke", Panel, {Thickness = 1, Transparency = 0.64})
		local Scale = Create("UIScale", Panel, {Scale = 0.92})
		local TitleIconOffset = PopupMode and 8 or 0
		if PopupMode and Configs.Icon ~= nil then
			local Source = Library:GetIcon(Configs.Icon)
			if type(Source) == "string" and Source:match("^rbxassetid://%d+$") then
				TitleIconOffset = 31
				local IconFrame = Create("ImageLabel", Panel, {
					Size = UDim2.fromOffset(21, 21),
					Position = UDim2.fromOffset(HorizontalPadding, PaddingTop),
					BackgroundTransparency = 1,
					Image = Source,
					ImageColor3 = Configs.IconThemed == true and Theme["Color Text"] or Color3.new(1, 1, 1)
				})
				if Configs.IconThemed == true then InsertTheme(IconFrame, "Icon") end
			end
		end
		local TitleLabel = InsertTheme(Create("TextLabel", Panel, {
			AutoLocalize = false,
			Size = UDim2.fromOffset(Width - HorizontalPadding * 2 - TitleIconOffset, PopupMode and 25 or 22),
			Position = UDim2.fromOffset(HorizontalPadding + TitleIconOffset, PaddingTop),
			BackgroundTransparency = 1,
			Text = TranslateDialog(TitleSource),
			Font = Enum.Font.GothamBold,
			TextSize = TitleFontSize,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTransparency = 1,
			TextColor3 = Theme["Color Text"]
		}), "Text")
		local TextScroll = Create("ScrollingFrame", Panel, {
			Size = UDim2.fromOffset(Width - HorizontalPadding * 2, 24),
			Position = UDim2.fromOffset(HorizontalPadding, 34),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 0,
			ScrollBarImageColor3 = Theme["Color Theme"]
		})
		local MessageLabel = InsertTheme(Create("TextLabel", TextScroll, {
			AutoLocalize = false,
			Size = UDim2.fromOffset(Width - (HorizontalPadding * 2 + 7), 25),
			BackgroundTransparency = 1,
			Text = RenderMessage(),
			TextWrapped = true,
			TextSize = MessageFontSize,
			Font = Enum.Font.GothamMedium,
			RichText = PopupMode,
			TextTransparency = 1,
			TextColor3 = Theme["Color Text"],
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top
		}), "Text")
		local ButtonInset = 12
		local ButtonsHolder = Create("Frame", Panel, {
			Size = UDim2.new(1, -ButtonInset * 2, 0, ButtonHeight),
			Position = UDim2.new(0, ButtonInset, 1, -PaddingBottom),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1
		})
		local ButtonsLayout = Create("UIListLayout", ButtonsHolder, {
			Padding = UDim.new(0, ButtonGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center
		})
		local ButtonEntries, ClosingHandlers = {}, {}
		local Dialog = {Closing = false, Pending = false}
		Runtime.Dialog = Dialog

		local function Reflow()
			if not Overlay.Parent or Dialog.Closing then return end
			local TitleHeight = math.max(PopupMode and 25 or 18, TextService:GetTextSize(TitleLabel.Text, TitleFontSize, Enum.Font.GothamBold, Vector2.new(Width - HorizontalPadding * 2 - TitleIconOffset, 2000)).Y)
			local MessageHeight = math.max(19, TextService:GetTextSize(MessageLabel.Text, MessageFontSize, Enum.Font.GothamMedium, Vector2.new(Width - (HorizontalPadding * 2 + 8), 10000)).Y + 2)
			local FixedHeight = PaddingTop + TitleHeight + TitleGap + ContentGap + ButtonHeight + PaddingBottom
			local RequestedHeight = tonumber(Configs.Height)
			local NaturalHeight = FixedHeight + MessageHeight
			local MinimumHeight = math.min(MaxHeight, math.max(MinHeight, FixedHeight + 18))
			local Height = math.clamp(RequestedHeight or NaturalHeight, MinimumHeight, MaxHeight)
			local Top = PaddingTop
			local Bottom = PaddingBottom
			local ViewHeight = math.max(18, Height - (Top + TitleHeight + TitleGap + ContentGap + ButtonHeight + Bottom))
			Panel.Size = UDim2.fromOffset(Width, Height)
			TitleLabel.Position = UDim2.fromOffset(HorizontalPadding + TitleIconOffset, Top)
			TitleLabel.Size = UDim2.fromOffset(Width - HorizontalPadding * 2 - TitleIconOffset, TitleHeight)
			TextScroll.Position = UDim2.fromOffset(HorizontalPadding, Top + TitleHeight + TitleGap)
			TextScroll.Size = UDim2.fromOffset(Width - HorizontalPadding * 2, ViewHeight)
			TextScroll.CanvasSize = UDim2.fromOffset(0, MessageHeight)
			TextScroll.ScrollingEnabled = MessageHeight > ViewHeight + 1
			TextScroll.ScrollBarThickness = MessageHeight > ViewHeight + 1 and 2 or 0
			MessageLabel.Size = UDim2.fromOffset(Width - (HorizontalPadding * 2 + 7), MessageHeight)
			ButtonsHolder.Position = UDim2.new(0, ButtonInset, 1, -Bottom)
		end

		local function ReflowButtons()
			local VisibleEntries = {}
			for _, Entry in ipairs(ButtonEntries) do
				if Entry.Visible then VisibleEntries[#VisibleEntries + 1] = Entry end
			end
			local Count = #VisibleEntries
			if Count == 0 then return end
			local AvailableWidth = math.max(1, Width - ButtonInset * 2 - ButtonGap * (Count - 1))
			for Index, Entry in ipairs(ButtonEntries) do
				Entry.Button.LayoutOrder = Index
			end
			if PopupMode then
				local Widths = {}
				local TotalWidth = 0
				for _, Entry in ipairs(VisibleEntries) do
					local TextWidth = TextService:GetTextSize(Entry.Button.Text, 13, Enum.Font.GothamBold, Vector2.new(1000, ButtonHeight)).X
					local ButtonWidth = math.clamp(math.ceil(TextWidth) + (Entry.HasIcon and 40 or (PopupMode and 30 or 26)), 68, 150)
					Widths[#Widths + 1] = ButtonWidth
					TotalWidth += ButtonWidth
				end
				local Ratio = math.min(1, AvailableWidth / math.max(1, TotalWidth))
				for Index, Entry in ipairs(VisibleEntries) do
					Entry.Button.Size = UDim2.fromOffset(math.max(1, math.floor(Widths[Index] * Ratio)), ButtonHeight)
				end
				return
			end
			-- The original dialog buttons continue filling the available width.
			local FullWidth = AvailableWidth / Count
			local Last = 0
			for _, Entry in ipairs(VisibleEntries) do
				Last += 1
				local Left = math.floor((Last - 1) * FullWidth + 0.5)
				local Right = math.floor(Last * FullWidth + 0.5)
				Entry.Button.Size = UDim2.fromOffset(math.max(1, Right - Left), ButtonHeight)
			end
		end

		local function ApplyAlignment(Value)
			Value = tostring(Value or "Center"):lower()
			Alignment = Value == "left" and "Left" or Value == "right" and "Right" or "Center"
			ButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment[Alignment]
		end

		local function NormalizeButtonStyle(Style, LegacyPrimary)
			if type(Style) ~= "string" then return LegacyPrimary and "primary" or "secondary" end
			Style = Style:lower()
			return (Style == "primary" or Style == "secondary" or Style == "tertiary" or Style == "danger") and Style or "secondary"
		end

		local function ApplyButtonStyle(Entry)
			local Palette = type(Entry.Color) == "table" and Entry.Color or {}
			local BackgroundSource = Palette.Background or Palette.BackgroundColor3 or Palette.Color or Palette.Theme or Palette[1]
			if BackgroundSource == nil and type(Entry.Color) ~= "table" then
				BackgroundSource = Entry.Color
			end
			if BackgroundSource == nil then
				if Entry.Style == "primary" then
					BackgroundSource = "Color Theme"
				elseif Entry.Style == "danger" then
					BackgroundSource = Theme["Color Danger"] or Color3.fromRGB(193, 65, 79)
				elseif Entry.Style == "tertiary" then
					BackgroundSource = "Color Hub 2"
				else
					BackgroundSource = DefaultButtonColor
				end
			end
			local Base = ResolveColor(BackgroundSource, Theme["Color Stroke"])
			local Brightness = Base.R * 0.299 + Base.G * 0.587 + Base.B * 0.114
			local Contrast = Brightness > 0.62 and Color3.fromRGB(20, 20, 24) or Color3.new(1, 1, 1)
			local TextSource = Palette.Text or Palette.TextColor or Palette.TextColor3
			if TextSource == nil and (Entry.Style == "secondary" or Entry.Style == "tertiary") and Entry.Color == nil then
				TextSource = DefaultButtonTextColor
			end
			Entry.Button.TextColor3 = ResolveColor(TextSource,
				((Entry.Style == "secondary" or Entry.Style == "tertiary") and Entry.Color == nil) and Theme["Color Text"] or Contrast)
			local HoverSource = Palette.Hover or Palette.HoverColor or Palette.HoverBackground
			local HoverColor = ResolveColor(HoverSource,
				Base:Lerp(Color3.new(1, 1, 1), Entry.Style == "secondary" and 0.07 or 0.1))
			Entry.Button.BackgroundColor3 = Entry.Hovered and HoverColor or Base
			Entry.Button.Active = Entry.Enabled
			Entry.Button.Interactable = Entry.Enabled
			Entry.Button.Selectable = Entry.Enabled
			Entry.Button.TextTransparency = Entry.Enabled and 0 or 0.5
			local Alpha = Entry.Style == "secondary" and 0.14 or 0.01
			Entry.Button.BackgroundTransparency = Entry.Enabled
				and (Entry.Style == "tertiary" and (Entry.Hovered and 0.75 or 1)
					or math.max(0, Alpha - (Entry.Hovered and 0.05 or 0))) or 0.55
		end

		local function FinishClose(Reason)
			if ActiveDialog == Overlay then ActiveDialog = nil end
			if Overlay.Parent then Overlay:Destroy() end
			if Dialog.Closed then return end
			Dialog.Closed = true
			for _, Listener in ipairs(ClosingHandlers) do
				local Success, Error = pcall(Listener.Callback, Reason, Dialog)
				if not Success then warn("[SpecterX Dialog] OnClose: " .. tostring(Error)) end
			end
			table.clear(ClosingHandlers)
			if type(Configs.OnClose) == "function" then
				local Success, Error = pcall(Configs.OnClose, Reason, Dialog)
				if not Success then warn("[SpecterX Dialog] OnClose: " .. tostring(Error)) end
			end
		end

		function Dialog:IsOpen()
			return not self.Closing and Overlay.Parent ~= nil
		end

		function Dialog:Close(Reason)
			if self.Closing or not Overlay.Parent then return false end
			self.Closing = true
			TweenService:Create(Scale, AnimClose, {Scale = 0.94}):Play()
			TweenService:Create(Panel, AnimClose, {BackgroundTransparency = 1}):Play()
			TweenService:Create(Overlay, AnimClose, {BackgroundTransparency = 1}):Play()
			TweenService:Create(TitleLabel, AnimClose, {TextTransparency = 1}):Play()
			TweenService:Create(MessageLabel, AnimClose, {TextTransparency = 1}):Play()
			for _, Entry in ipairs(ButtonEntries) do
				if Entry.Button.Parent then
					TweenService:Create(Entry.Button, AnimClose, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
				end
			end
			task.delay(0.18, function() FinishClose(Reason or "Closed") end)
			return true
		end

		function Dialog:Destroy()
			if self.Closing then return false end
			self.Closing = true
			FinishClose("Destroyed")
			return true
		end

		function Dialog:OnClose(Callback)
			if type(Callback) ~= "function" or self.Closing then return nil end
			local Entry = {Callback = Callback}
			ClosingHandlers[#ClosingHandlers + 1] = Entry
			return {
				Disconnect = function()
					local Index = table.find(ClosingHandlers, Entry)
					if Index then table.remove(ClosingHandlers, Index) end
				end
			}
		end

		function Dialog:SetTitle(Value)
			if not self:IsOpen() or Value == nil then return false end
			TitleSource = tostring(Value)
			TitleLabel.Text = TranslateDialog(TitleSource)
			Reflow()
			return true
		end
		function Dialog:SetText(Value)
			if not self:IsOpen() or Value == nil then return false end
			MessageSource = tostring(Value)
			MessageLabel.Text = RenderMessage()
			Reflow()
			return true
		end
		Dialog.SetDesc = Dialog.SetText
		function Dialog:GetTitle() return TitleLabel.Text end
		function Dialog:GetText() return MessageLabel.Text end
		function Dialog:SetAlignment(Value)
			if not self:IsOpen() then return false end
			ApplyAlignment(Value)
			return true
		end

		local function FindButton(Identifier)
			if type(Identifier) == "number" then return ButtonEntries[Identifier] end
			for _, Entry in ipairs(ButtonEntries) do
				if Identifier == Entry.Handle or Identifier == Entry.Button or Identifier == Entry.Name or Identifier == Entry.Button.Text then
					return Entry
				end
			end
			return nil
		end

		function Dialog:RemoveButton(Identifier)
			local Entry = FindButton(Identifier)
			if not Entry then return false end
			local Index = table.find(ButtonEntries, Entry)
			if Index then table.remove(ButtonEntries, Index) end
			Entry.Button:Destroy()
			ReflowButtons()
			return true
		end
		function Dialog:ClearButtons()
			for Index = #ButtonEntries, 1, -1 do self:RemoveButton(Index) end
		end

		function Dialog:Button(Option)
			if not self:IsOpen() then return nil end
			Option = type(Option) == "table" and Option or {Option}
			local LabelSource = tostring(Option[1] or Option.Name or Option.Title or Option.Label or "")
			local Callback = Option[2] or Option.Callback
			local Button = Create("TextButton", ButtonsHolder, {
				AutoLocalize = false,
				Size = UDim2.fromOffset(80, ButtonHeight),
				BackgroundColor3 = Theme["Color Stroke"],
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = TranslateDialog(LabelSource),
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				TextColor3 = Theme["Color Text"],
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
				AutoButtonColor = false,
				LayoutOrder = #ButtonEntries + 1
			})
			Make("Corner", Button, UDim.new(0, ButtonCornerRadius))
			local HasButtonIcon = false
			if PopupMode and Option.Icon then
				local Source = Library:GetIcon(Option.Icon)
				if type(Source) == "string" and Source:match("^rbxassetid://%d+$") then
					HasButtonIcon = true
					Button.TextXAlignment = Enum.TextXAlignment.Right
					Create("UIPadding", Button, {PaddingRight = UDim.new(0, 10)})
					InsertTheme(Create("ImageLabel", Button, {
						Size = UDim2.fromOffset(14, 14),
						Position = UDim2.new(0, 8, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = Source,
						ImageColor3 = Theme["Color Text"]
					}), "Icon")
				end
			end
			local ButtonScale = Create("UIScale", Button, {Scale = 1})
			local Entry = {
				Button = Button, Name = LabelSource, Color = Option.Color,
				HasIcon = HasButtonIcon, Primary = Option.Primary == true,
				Style = NormalizeButtonStyle(Option.Style, Option.Primary == true),
				Enabled = Option.Enabled ~= false and Option.Disabled ~= true,
				Visible = Option.Visible ~= false, Hovered = false, Callback = Callback,
				CloseOnClick = Option.Close ~= false
			}
			local Handle = {}
			Entry.Handle = Handle
			ButtonEntries[#ButtonEntries + 1] = Entry
			Button.Visible = Entry.Visible

			function Handle:SetColor(Color)
				if not Button.Parent then return false end
				Entry.Color = Color
				ApplyButtonStyle(Entry)
				return true
			end
			function Handle:SetStyle(Style)
				if not Button.Parent or type(Style) ~= "string" then return false end
				Entry.Style = NormalizeButtonStyle(Style, false)
				ApplyButtonStyle(Entry)
				return true
			end
			function Handle:SetText(Value)
				if not Button.Parent or Value == nil then return false end
				Entry.Name = tostring(Value)
				Button.Text = TranslateDialog(Entry.Name)
				ReflowButtons()
				return true
			end
			Handle.SetTitle = Handle.SetText
			function Handle:GetText() return Button.Text end
			function Handle:SetEnabled(Value)
				if not Button.Parent then return false end
				Entry.Enabled = Value == true
				ApplyButtonStyle(Entry)
				return true
			end
			function Handle:SetVisible(Value)
				if not Button.Parent then return false end
				Entry.Visible = Value == true
				Button.Visible = Entry.Visible
				ReflowButtons()
				return true
			end
			function Handle:Destroy() return Dialog:RemoveButton(self) end

			Button.MouseEnter:Connect(function()
				if Dialog.Closing or Dialog.Pending or not Entry.Enabled then return end
				Entry.Hovered = true
				ApplyButtonStyle(Entry)
				TweenService:Create(ButtonScale, AnimButton, {Scale = 1.025}):Play()
			end)
			Button.MouseLeave:Connect(function()
				Entry.Hovered = false
				if not Dialog.Closing then ApplyButtonStyle(Entry) end
				TweenService:Create(ButtonScale, AnimButton, {Scale = 1}):Play()
			end)
			Button.MouseButton1Down:Connect(function()
				if not Dialog.Closing and not Dialog.Pending and Entry.Enabled then
					TweenService:Create(ButtonScale, AnimButton, {Scale = 0.96}):Play()
				end
			end)
			Button.MouseButton1Up:Connect(function()
				if not Dialog.Closing and not Dialog.Pending and Entry.Enabled then
					TweenService:Create(ButtonScale, AnimButton, {Scale = 1}):Play()
				end
			end)
			Button.Activated:Connect(function()
				if Dialog.Closing or Dialog.Pending or not Entry.Enabled then return end
				Dialog.Pending = true
				local Selected = Entry
				TweenService:Create(ButtonScale, AnimButton, {Scale = 0.96}):Play()
				task.delay(0.09, function()
					local function FireCallback()
						if type(Selected.Callback) == "function" then
							local Success, Error = pcall(Selected.Callback)
							if not Success then warn("[SpecterX Dialog] Button callback: " .. tostring(Error)) end
						end
						if not Dialog.Closing then Dialog.Pending = false end
					end
					if Selected.CloseOnClick then
						Dialog:Close(Selected.Name)
						task.delay(0.19, FireCallback)
					else
						FireCallback()
					end
				end)
			end)
			ApplyButtonStyle(Entry)
			ReflowButtons()
			-- Animate newly added buttons in, rather than applying their final
			-- transparency before the fade begins.
			Button.TextTransparency = 1
			Button.BackgroundTransparency = 1
			TweenService:Create(Button, AnimFade, {
				TextTransparency = Entry.Enabled and 0 or 0.5,
				BackgroundTransparency = Entry.Enabled and (Entry.Style == "tertiary" and 1 or (Entry.Style == "secondary" and 0.14 or 0.01)) or 0.55
			}):Play()
			return Handle
		end
		Dialog.AddButton = Dialog.Button

		function Dialog:SetOptions(NewOptions)
			if not self:IsOpen() or type(NewOptions) ~= "table" then return false end
			self:ClearButtons()
			for _, Option in ipairs(NewOptions) do self:Button(Option) end
			return true
		end
		function Dialog:GetButtons()
			local Result = {}
			for _, Entry in ipairs(ButtonEntries) do Result[#Result + 1] = Entry.Handle end
			return Result
		end
		function Dialog:SetButtonColor(Identifier, Color)
			local Entry = FindButton(Identifier)
			return Entry and Entry.Handle:SetColor(Color) or false
		end
		function Dialog:SetButtonStyle(Identifier, Style)
			local Entry = FindButton(Identifier)
			return Entry and Entry.Handle:SetStyle(Style) or false
		end
		function Dialog:SetButtonText(Identifier, Text)
			local Entry = FindButton(Identifier)
			return Entry and Entry.Handle:SetText(Text) or false
		end
		function Dialog:SetButtonEnabled(Identifier, Value)
			local Entry = FindButton(Identifier)
			return Entry and Entry.Handle:SetEnabled(Value) or false
		end
		function Dialog:SetButtonDefaultColor(Value)
			if not self:IsOpen() then return false end
			DefaultButtonColor = Value or "Color Stroke"
			for _, Entry in ipairs(ButtonEntries) do ApplyButtonStyle(Entry) end
			return true
		end

		ApplyAlignment(Alignment)
		local SelectedObject = GuiService.SelectedObject
		if SelectedObject and SelectedObject:IsDescendantOf(ScreenGui) then GuiService.SelectedObject = nil end
		for _, Option in ipairs(Options) do Dialog:Button(Option) end
		Reflow()
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			for _, Entry in ipairs(ButtonEntries) do
				if Entry.Enabled and Entry.Visible then
					GuiService.SelectedObject = Entry.Button
					break
				end
			end
		end

		local ThemeConnection = Connection.ThemeChanged:Connect(function()
			if not Overlay.Parent then return end
			TextScroll.ScrollBarImageColor3 = Theme["Color Theme"]
			for _, Entry in ipairs(ButtonEntries) do ApplyButtonStyle(Entry) end
		end)
		local function RefreshDialogTranslations()
			if not Overlay.Parent or Dialog.Closing then return end
			-- Always re-render from the original source texts, never from an
			-- already localized button label or dialog title.
			TitleLabel.Text = TranslateDialog(TitleSource)
			MessageLabel.Text = RenderMessage()
			for _, Entry in ipairs(ButtonEntries) do
				if Entry.Button.Parent then
					Entry.Button.Text = TranslateDialog(Entry.Name)
				end
			end
			Reflow()
			ReflowButtons()
		end
		local LanguageConnection = Connection.LanguageChanged:Connect(RefreshDialogTranslations)
		local HubLanguageConnection
		if type(Hub) == "table" and type(Hub.OnLanguageChanged) == "function" then
			HubLanguageConnection = Hub:OnLanguageChanged(RefreshDialogTranslations)
		end
		function Dialog:RefreshTranslations()
			if not self:IsOpen() then return false end
			RefreshDialogTranslations()
			return true
		end
		Overlay.Destroying:Connect(function()
			if RootModal.Parent then RootModal:Destroy() end
			if MainFrame.Parent then MainFrame.ZIndex = PreviousMainZIndex end
			ThemeConnection:Disconnect()
			LanguageConnection:Disconnect()
			if HubLanguageConnection then HubLanguageConnection:Disconnect() end
			if ActiveDialog == Overlay then ActiveDialog = nil end
			if Runtime.DialogOverlay == Overlay then Runtime.DialogOverlay = nil end
			if Runtime.Dialog == Dialog then Runtime.Dialog = nil end
		end)
		TweenService:Create(Scale, AnimOpen, {Scale = 1}):Play()
		TweenService:Create(Panel, AnimFade, {BackgroundTransparency = 0}):Play()
		TweenService:Create(Overlay, AnimFade, {BackgroundTransparency = 0.4}):Play()
		TweenService:Create(TitleLabel, AnimFade, {TextTransparency = 0}):Play()
		TweenService:Create(MessageLabel, AnimFade, {TextTransparency = 0.14}):Play()
		if type(Configs.OnOpen) == "function" then
			task.defer(function()
				if Dialog:IsOpen() then
					local Success, Error = pcall(Configs.OnOpen, Dialog)
					if not Success then warn("[SpecterX Dialog] OnOpen: " .. tostring(Error)) end
				end
			end)
		end
		return Dialog
	end
	function Window:AddPopup(Configs)
		Configs = type(Configs) == "table" and Configs or {Content = Configs}
		local PopupConfigs = table.clone(Configs)
		PopupConfigs._Popup = true
		PopupConfigs.Title = tostring(Configs.Title or Configs[1] or "Popup")
		PopupConfigs.Text = tostring(Configs.Content or Configs.Text or Configs.Description or Configs.Desc or Configs[2] or "")
		PopupConfigs.Width = Configs.Width or 368
		PopupConfigs.MinHeight = Configs.MinHeight or 132
		PopupConfigs.HorizontalPadding = Configs.HorizontalPadding or 14
		PopupConfigs.PaddingTop = Configs.PaddingTop or 12
		PopupConfigs.PaddingBottom = Configs.PaddingBottom or 12
		PopupConfigs.ButtonHeight = Configs.ButtonHeight or 32
		PopupConfigs.ButtonSpacing = Configs.ButtonSpacing or 8
		PopupConfigs.TitleGap = Configs.TitleGap or 6
		PopupConfigs.ContentGap = Configs.ContentGap or 10
		PopupConfigs.ButtonAlignment = Configs.ButtonAlignment or "Right"
		PopupConfigs.Options = {}
		local Buttons = Configs.Buttons or Configs.Options or {}
		for _, Button in ipairs(type(Buttons) == "table" and Buttons or {}) do
			local Option = type(Button) == "table" and table.clone(Button) or {Title = Button}
			Option.Style = Option.Variant or Option.Style or "Primary"
			table.insert(PopupConfigs.Options, Option)
		end
		local Popup = Window:Dialog(PopupConfigs)
		if Popup then
			Popup.SetContent = Popup.SetText
			if type(Configs.Duration) == "number" and Configs.Duration > 0 then
				task.delay(Configs.Duration, function()
					if Popup:IsOpen() then Popup:Close("Timeout") end
				end)
			end
		end
		return Popup
	end

	function Window:SelectTab(TabSelect)
		if type(TabSelect) == "number" then
			TabSelect = Library.Tabs[TabSelect] and Library.Tabs[TabSelect].func
		end
		if type(TabSelect) ~= "table" or TabSelect._Destroyed then
			return false
		end
		for _, Entry in ipairs(Library.Tabs) do
			if Entry.func == TabSelect then
				return TabSelect:Enable()
			end
		end
		return false
	end


	local ContainerList = {}
	local ConfigTab
	local FavoriteTabCounts = {}
	ScreenGui.Destroying:Connect(function()
		for _, Container in ipairs(ContainerList) do Container:Destroy() end
		table.clear(ContainerList)
	end)
	local SidebarOrder = 0

	local function ResolveSidebarIcon(Value)
		local Id = NormalizeAssetId(Value)
		if not Id and type(Value) == "string" then
			Id = NormalizeAssetId(Library:GetIcon(Value))
		end
		return Id and Id ~= "" and ("rbxassetid://" .. Id) or nil
	end

	function Window:AddSection(Configs)
		Configs = type(Configs) == "table" and Configs or {Title = Configs}
		local TitleSource = tostring(Configs[1] or Configs.Title or Configs.Name or "Section")
		local Expanded = Configs.Opened == true or (Configs.Opened == nil and Configs.Expanded == true)
		local Section = {
			_Window = Window,
			_Tabs = {},
			_Order = 0,
			_Expanded = Expanded,
			_Destroyed = false
		}

		local SectionHeaderHeight = math.max(TabButtonHeight, TabTextSize + 8)
		SidebarOrder += 1
		local Holder = Create("Frame", MainScroll, {
			LayoutOrder = SidebarOrder,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0
		})
		Create("UIListLayout", Holder, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4)
		})
		local Header = Create("TextButton", Holder, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, SectionHeaderHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false
		})
		local SectionLeftPadding = TabIconOffset
		local SectionIconSize = math.max(13, TabIconSize)
		local SectionIconGap = 6
		local SectionIconOffset = SectionIconSize + SectionIconGap
		local Source = ResolveSidebarIcon(Configs.Icon)
		if Source then
				local Image = Create("ImageLabel", Header, {
					Size = UDim2.fromOffset(SectionIconSize, SectionIconSize),
					Position = UDim2.new(0, SectionLeftPadding, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = Source,
					ImageColor3 = Configs.IconThemed == true and Theme["Color Text"] or Color3.new(1, 1, 1),
					ImageTransparency = 0.22
				})
			if Configs.IconThemed == true then InsertTheme(Image, "Icon") end
		end
		local SectionTextOffset = Source and (SectionLeftPadding + SectionIconOffset) or 4
		local Label = InsertTheme(Create("TextLabel", Header, {
			Position = UDim2.fromOffset(SectionTextOffset, 0),
			Size = UDim2.new(1, -(SectionTextOffset + 24), 1, 0),
			BackgroundTransparency = 1,
			AutoLocalize = false,
			Text = TranslateText(TitleSource),
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamMedium,
			TextSize = Library.Save.SectionTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd
		}), "TitleText")
		local Icon = Library:GetIcon("chevron-down")
		local Arrow
		if type(Icon) == "string" and Icon:find("^rbxassetid://") then
			Arrow = InsertTheme(Create("ImageLabel", Header, {
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.new(1, -10, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Icon,
				Visible = false,
				ImageColor3 = Theme["Color Dark Text"],
				Rotation = Expanded and 0 or -90
			}), "DarkText")
		else
			Arrow = InsertTheme(Create("TextLabel", Header, {
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.new(1, -10, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "⌄",
				Visible = false,
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 18,
				Rotation = Expanded and 0 or -90
			}), "DarkText")
		end
		local Content = Create("Frame", Holder, {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = Expanded
		})
		Create("UIListLayout", Content, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, TabsSpacing)
		})
		Section._Container = Content
		Section._Arrow = Arrow

		function Section:SetExpanded(Value)
			if self._Destroyed or #self._Tabs == 0 then return false end
			Value = Value == true
			if self._Expanded ~= Value then
				self._Expanded = Value
				Content.Visible = Value
				CreateTween({Arrow, "Rotation", Value and 0 or -90, AnimationTab})
			end
			return self._Expanded
		end
		function Section:Expand() return self:SetExpanded(true) end
		function Section:Collapse() return self:SetExpanded(false) end
		Section.Open = Section.Expand
		Section.Close = Section.Collapse
		function Section:Toggle() return self:SetExpanded(not self._Expanded) end
		function Section:IsExpanded() return self._Expanded end
		function Section:SetTitle(Value)
			if self._Destroyed or Value == nil then return false end
			TitleSource = tostring(Value)
			Label.Text = TranslateText(TitleSource)
			return true
		end
		function Section:SetVisible(Value)
			if self._Destroyed then return false end
			Holder.Visible = Value == true
			return true
		end
		function Section:MakeTab(TabConfigs, IconName)
			if self._Destroyed then return nil end
			local Options = type(TabConfigs) == "table" and table.clone(TabConfigs)
				or {Title = TabConfigs, Icon = IconName}
			Options.Section = self
			local Tab = Window:MakeTab(Options)
			Arrow.Visible = #self._Tabs > 0
			return Tab
		end
		function Section:Destroy()
			if self._Destroyed then return end
			self._Destroyed = true
			while #self._Tabs > 0 do
				self._Tabs[1]:Destroy()
			end
			Holder:Destroy()
		end

		local LanguageConnection = Connection.LanguageChanged:Connect(function()
			if Section._Destroyed then return end
			Label.Text = TranslateText(TitleSource)
		end)
		Holder.Destroying:Connect(function()
			Section._Destroyed = true
			LanguageConnection:Disconnect()
		end)
		Header.Activated:Connect(function() Section:Toggle() end)
		return Section
	end
	Window.AddTabSection = Window.AddSection

	function Window:MakeTab(paste, Configs)
		if type(paste) == "table" then Configs = paste end
		Configs = type(Configs) == "table" and Configs or {}
		local Section = Configs.Section
		if type(Section) ~= "table" or Section._Window ~= Window or Section._Destroyed then Section = nil end
		local Hidden = Configs.Hidden == true
		local TName = TranslateText(tostring(Configs[1] or Configs.Title or ControlsConfig.Titles.Tab))
		local BaseTabKey = tostring(Configs[1] or Configs.Title or ControlsConfig.Titles.Tab)
		FavoriteTabCounts[BaseTabKey] = (FavoriteTabCounts[BaseTabKey] or 0) + 1
		local TabIndex = FavoriteTabCounts[BaseTabKey]
		local FavoriteTabKey = BaseTabKey .. (TabIndex == 1 and "" or "#" .. TabIndex)
		local TIcon = not Hidden and ResolveSidebarIcon(Configs[2] or Configs.Icon) or nil
		local TabSelect, LabelTitle, LabelIcon, Selected

		if not Hidden then

			if Section then Section._Order += 1 else SidebarOrder += 1 end
			TabSelect = Make("Button", Section and Section._Container or MainScroll, {
				Size = UDim2.new(1, 0, 0, TabButtonHeight),
				LayoutOrder = Section and Section._Order or SidebarOrder
			})
			Make("Corner", TabSelect, UDim.new(0, 5))

			local TextOffset = TIcon and math.max(TabTextIconOffset, TabIconOffset + TabIconSize + 7)
				or (TabIconOffset + math.max(4, math.floor(TabIconSize * 0.2)))
			LabelTitle = InsertTheme(Create("TextLabel", TabSelect, {
				Size = UDim2.new(1, -TextOffset - 5, 1, 0),
				Position = UDim2.fromOffset(TextOffset, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Text = TName,
				TextColor3 = Theme["Color Text"],
				TextSize = TabTextSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = (FirstTab and TabInactiveTransparency) or 0,
				TextTruncate = "AtEnd"
			}), "Text")

			if TIcon then
				LabelIcon = InsertTheme(Create("ImageLabel", TabSelect, {
					Position = UDim2.new(0, TabIconOffset, 0.5, 0),
					Size = UDim2.fromOffset(TabIconSize, TabIconSize),
					AnchorPoint = Vector2.new(0, 0.5),
					Image = TIcon,
					BackgroundTransparency = 1,
					ImageTransparency = (FirstTab and TabInactiveTransparency) or 0
				}), "Text")
			end

			Selected = InsertTheme(Create("Frame", TabSelect, {
				Size = UDim2.fromOffset(TabIndicatorWidth, FirstTab and TabIndicatorIdleSize or TabIndicatorHeight),
				Position = UDim2.new(0, 1, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme["Color Theme"],
				BackgroundTransparency = FirstTab and 1 or 0,
				BorderSizePixel = 0
			}), "Theme")
			Make("Corner", Selected, UDim.new(0.5, 0))
		else
			TIcon = false
		end
		
		local Container = InsertTheme(Create("ScrollingFrame", Containers, {
			Visible = false,
			Size = UDim2.new(1, -14, 1, -24),
			Position = UDim2.new(0, 0, 1, -16),
			AnchorPoint = Vector2.new(0, 1),
			ScrollBarThickness = ScrollThickness,
			BackgroundTransparency = 1,
			ScrollBarImageTransparency = ScrollTransparency,
			ScrollBarImageColor3 = Theme["Color Theme"],
			AutomaticCanvasSize = "Y",
			ScrollingDirection = "Y",
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
		}, {
			Create("UIPadding", {
				PaddingLeft = UDim.new(0, TabsPadding),
				PaddingRight = UDim.new(0, TabsPadding),
				PaddingTop = UDim.new(0, TabsPadding),
				PaddingBottom = UDim.new(0, TabsPadding)
			}), Create("UIListLayout", {
				Padding = UDim.new(0, TabsSpacing)
			})
		}), "ScrollBar")
		
		BindAdaptiveScroll(Container, TabsPadding * 2)
		OrderedParents[Container] = 0
		table.insert(ContainerList, Container)
		
		local InitiallySelected = not ActiveTab and not Hidden and not Configs.Locked
		Container.Visible = InitiallySelected
		
		local Tab = {}
		if Section then
			table.insert(Section._Tabs, Tab)
			if Section._Arrow and Section._Arrow.Parent then Section._Arrow.Visible = true end
		end
		local FavoriteDropdownCounts = {}
		if Hidden then
			local Locked = Configs.Locked == true
			local LockedMessage = type(Configs.LockedMessage) == "string" and Configs.LockedMessage or LibraryConfig.LockedMessage

			function Tab:SetLocked(Value)
				Locked = Value == true
				Tab.Locked = Locked
				return Locked
			end
			function Tab:Lock(NewMessage)
				if type(NewMessage) == "string" then LockedMessage = NewMessage end
				return Tab:SetLocked(true)
			end
			function Tab:Unlock()
				return Tab:SetLocked(false)
			end
			function Tab:IsLocked()
				return Locked
			end
			function Tab:SetLockedMessage(NewMessage)
				if type(NewMessage) == "string" and NewMessage ~= "" then LockedMessage = NewMessage end
			end
			function Tab:GetLockedMessage()
				return LockedMessage
			end
			function Tab:NotifyLocked()
				ShowToastMessage(LockedMessage)
			end
			Tab.Locked = Locked
		else
			ApplyLocked(Tab, TabSelect, Configs)
		end

		local TabVisible = true
		local TabElements = {}
		local ElementParent = Container
		local CurrentContentSection
		local function Tabs()
			if Tab._Destroyed or not TabVisible then return false end
			if Tab:IsLocked() then
				Tab:NotifyLocked()
				return false
			end
			if Section then Section:Expand() end
			if ActiveTab == Tab and Container.Visible then return true end

			if ActiveTab and ActiveTab ~= Tab then
				ActiveTab:Disable()
			end
			ActiveTab = Tab
			Container.Visible = true
			if ConfigButton then ConfigButton:SetActive(Tab == ConfigTab) end
			if TabSelect then
				CreateTween({LabelTitle, "TextTransparency", 0, AnimationTab})
				if LabelIcon then CreateTween({LabelIcon, "ImageTransparency", 0, AnimationTab}) end
				CreateTween({Selected, "Size", UDim2.fromOffset(TabIndicatorWidth, TabIndicatorHeight), AnimationTab})
				CreateTween({Selected, "BackgroundTransparency", 0, AnimationTab})
			end
			return true
		end
		if TabSelect then TabSelect.Activated:Connect(Tabs) end
		
		if InitiallySelected then
			ActiveTab = Tab
		end

		FirstTab = FirstTab or (not Hidden and not Configs.Locked)
		table.insert(Library.Tabs, {TabInfo = {Name = TName, Icon = TIcon}, func = Tab, Cont = Container})
		Tab.Cont = Container
		
		function Tab:Disable()
			if Tab._Destroyed or not Container.Visible then return end
			Container.Visible = false
			if TabSelect then
				CreateTween({LabelTitle, "TextTransparency", TabInactiveTransparency, AnimationTab})
				if LabelIcon then CreateTween({LabelIcon, "ImageTransparency", TabInactiveTransparency, AnimationTab}) end
				CreateTween({Selected, "Size", UDim2.fromOffset(TabIndicatorWidth, TabIndicatorIdleSize), AnimationTab})
				CreateTween({Selected, "BackgroundTransparency", 1, AnimationTab})
			end
		end
		function Tab:Enable()
			return Tabs()
		end
		function Tab:Visible(Bool)
			if Tab._Destroyed then return end
			if Bool == nil then Bool = not TabVisible end
			TabVisible = Bool == true
			if TabSelect then TabSelect.Visible = TabVisible end
			if not TabVisible then
				if ActiveTab == Tab then
					Tab:Disable()
					ActiveTab = nil
					if ConfigButton then ConfigButton:SetActive(false) end
					for _, Entry in ipairs(Library.Tabs) do
						if Entry.func ~= Tab and Entry.func:Enable() then break end
					end
				end
			elseif ActiveTab == Tab then
				Container.Visible = true
			end
		end
		function Tab:Destroy()
			if Tab._Destroyed then return end
			Tab._Destroyed = true
			while next(TabElements) do
				local Element = next(TabElements)
				Element:Destroy()
			end
			local TabIndex
			for Index, TabData in ipairs(Library.Tabs) do
				if TabData.func == Tab then
					TabIndex = Index
					break
				end
			end

			if TabIndex then
				table.remove(Library.Tabs, TabIndex)
			end

			local ContainerIndex = table.find(ContainerList, Container)
			if ContainerIndex then
				table.remove(ContainerList, ContainerIndex)
			end

			local WasActive = ActiveTab == Tab
			if WasActive then ActiveTab = nil end
			if ConfigTab == Tab then ConfigTab = nil end
			if #Library.Tabs == 0 then FirstTab = false end

			if Section then
				local SectionIndex = table.find(Section._Tabs, Tab)
				if SectionIndex then table.remove(Section._Tabs, SectionIndex) end
				if Section._Arrow and Section._Arrow.Parent then Section._Arrow.Visible = #Section._Tabs > 0 end
			end
			if TabSelect then TabSelect:Destroy() end
			Container:Destroy()
			if WasActive then
				if ConfigButton then ConfigButton:SetActive(false) end
				for _, Entry in ipairs(Library.Tabs) do
					if not Entry.func._Destroyed and not Entry.func:IsLocked() and Entry.func:Enable() then break end
				end
			end
		end
		function Tab:SetTitle(Value)
			TName = TranslateText(DisplayString(Value))
			if LabelTitle then LabelTitle.Text = TName end
		end
		function Tab:GetTitle()
			return LabelTitle and LabelTitle.Text or TName
		end
		
		function Tab:AddSection(Configs, UseIndicator)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local Collapsible = Configs.Collapsible == true or (Configs.Collapsible ~= false
				and (type(Configs.Opened) == "boolean" or type(Configs.Expanded) == "boolean"))
			if not Collapsible then
				CurrentContentSection, ElementParent = nil, Container
				local SectionFlag = Configs.Flag
				local SectionName = TranslateText(DisplayString(Configs[1] or Configs.Name or Configs.Title or Configs.Section or ControlsConfig.Titles.Section))
				local Override
				if type(UseIndicator) == "boolean" then
					Override = UseIndicator
				elseif type(Configs.Indicator) == "boolean" then
					Override = Configs.Indicator
				end

				local SectionFrame = Create("Frame", Container, {
					Size = UDim2.new(1, 0, 0, Library.Save.SectionHeight),
					BackgroundTransparency = 1,
					BorderSizePixel = 0
				})

				local SectionLabel = InsertTheme(Create("TextLabel", SectionFrame, {
					Font = Enum.Font.GothamBold,
					Text = SectionName,
					TextColor3 = Theme["Color Text"],
					BackgroundTransparency = 1,
					TextTruncate = "AtEnd",
					TextSize = Library.Save.SectionTextSize,
					TextXAlignment = "Left",
					TextYAlignment = "Center"
				}), "Text")

				local Indicator = InsertTheme(Create("Frame", SectionFrame, {
					Size = UDim2.fromOffset(Library.Save.SectionThickness, Library.Save.SectionIndicatorHeight),
					Position = UDim2.new(0, 8, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Theme["Color Theme"],
					BorderSizePixel = 0
				}), "Theme")
				Make("Corner", Indicator, UDim.new(1, 0))
				Library.SectionIndicators[Indicator] = {Label = SectionLabel, Override = Override}
				Library:ApplySectionStyle(Indicator)

				local Section = {}
				local SectionOption = {type = "Section", Name = SectionName, func = Section}
				table.insert(Library.Options, SectionOption)
				function Section:Visible(Bool)
					if Bool == nil then SectionFrame.Visible = not SectionFrame.Visible return end
					SectionFrame.Visible = Bool
				end
				function Section:Destroy()
					local Index = table.find(Library.Options, SectionOption)
					if Index then table.remove(Library.Options, Index) end
					Library.SectionIndicators[Indicator] = nil
					SectionFrame:Destroy()
				end
				function Section:Set(New)
					if New ~= nil then
						SectionLabel.Text = TranslateText(DisplayString(GetStr(New)))
					end
				end
				Section.SetTitle = Section.Set
				function Section:GetTitle()
					return SectionLabel.Text
				end
				return RegisterFlagObject(SectionFlag, Section, SectionFrame)
			end
			local SectionFlag = Configs.Flag
			local SectionName = TranslateText(DisplayString(Configs[1] or Configs.Name or Configs.Title or Configs.Section or ControlsConfig.Titles.Section))
			local Override
			if type(UseIndicator) == "boolean" then
				Override = UseIndicator
			elseif type(Configs.Indicator) == "boolean" then
				Override = Configs.Indicator
			end

			local Expanded = Configs.Opened == true or (Configs.Opened == nil and Configs.Expanded == true)
			if not Collapsible then Expanded = true end
			local Holder = Create("Frame", Container, {
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1, BorderSizePixel = 0
			})
			Create("UIListLayout", Holder, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, TabsSpacing)})
			local SectionFrame = Create("TextButton", Holder, {
				LayoutOrder = 1, Text = "", AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, Library.Save.SectionHeight),
				BackgroundTransparency = 1, BorderSizePixel = 0
			})
			local Content = Create("Frame", Holder, {
				LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, Visible = Expanded,
				BackgroundTransparency = 1, BorderSizePixel = 0
			})
			Create("UIListLayout", Content, {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, TabsSpacing)})
			OrderedParents[Content] = 0

			local SectionLabel = InsertTheme(Create("TextLabel", SectionFrame, {
				Font = Enum.Font.GothamBold,
				Text = SectionName,
				TextColor3 = Theme["Color Text"],
				BackgroundTransparency = 1,
				TextTruncate = "AtEnd",
				TextSize = Library.Save.SectionTextSize,
				TextXAlignment = "Left",
				TextYAlignment = "Center"
			}), "Text")

			local Indicator = InsertTheme(Create("Frame", SectionFrame, {
				Size = UDim2.fromOffset(Library.Save.SectionThickness, Library.Save.SectionIndicatorHeight),
				Position = UDim2.new(0, 8, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme["Color Theme"],
				BorderSizePixel = 0
			}), "Theme")
			Make("Corner", Indicator, UDim.new(1, 0))
			Library.SectionIndicators[Indicator] = {Label = SectionLabel, Override = Override, Collapsible = Collapsible}
			Library:ApplySectionStyle(Indicator)

			local ArrowIcon = ResolveSidebarIcon("chevron-down")
			local Arrow
			if ArrowIcon then
				Arrow = InsertTheme(Create("ImageLabel", SectionFrame, {
					Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
					Image = ArrowIcon, ImageColor3 = Theme["Color Text"],
					Rotation = Expanded and 0 or -90, Visible = Collapsible
				}), "Text")
			else
				-- ASCII fallback remains readable even when the icon pack is unavailable.
				Arrow = InsertTheme(Create("TextLabel", SectionFrame, {
					Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
					Text = "v", Font = Enum.Font.GothamMedium, TextSize = 14,
					TextColor3 = Theme["Color Text"],
					Rotation = Expanded and 0 or -90, Visible = Collapsible
				}), "Text")
			end
			local Section = {_Elements = {}, _Container = Content, _Destroyed = false}
			local SectionOption = {type = "Section", Name = SectionName, func = Section}
			table.insert(Library.Options, SectionOption)
			function Section:SetExpanded(Value)
				if self._Destroyed or not Collapsible then return false end
				Expanded = Value == true
				Content.Visible = Expanded
				if not Expanded then
					for Element in pairs(self._Elements) do
						if Element._OnSectionHidden then Element._OnSectionHidden() end
					end
				end
				CreateTween({Arrow, "Rotation", Expanded and 0 or -90, AnimationTab})
				return Expanded
			end
			function Section:Expand() return self:SetExpanded(true) end
			function Section:Collapse() return self:SetExpanded(false) end
			function Section:Toggle() return self:SetExpanded(not Expanded) end
			function Section:IsExpanded() return Expanded end
			Section.Open = Section.Expand
			Section.Close = Section.Collapse
			function Section:Visible(Bool)
				if self._Destroyed then return end
				Holder.Visible = Bool == nil and not Holder.Visible or Bool == true
				if not Holder.Visible then
					for Element in pairs(self._Elements) do
						if Element._OnSectionHidden then Element._OnSectionHidden() end
					end
				end
			end
			function Section:Destroy()
				if self._Destroyed then return end
				self._Destroyed = true
				if CurrentContentSection == self then
					CurrentContentSection, ElementParent = nil, Container
				end
				while next(self._Elements) do
					local Element = next(self._Elements)
					self._Elements[Element] = nil
					Element:Destroy()
				end
				local Index = table.find(Library.Options, SectionOption)
				if Index then table.remove(Library.Options, Index) end
				Library.SectionIndicators[Indicator] = nil
				Holder:Destroy()
			end
			function Section:Set(New)
				if not self._Destroyed and New ~= nil then
					SectionLabel.Text = TranslateText(DisplayString(GetStr(New)))
				end
			end
			Section.SetTitle = Section.Set
			function Section:GetTitle() return SectionLabel.Text end
			setmetatable(Section, {__index = function(_, Key)
				if type(Key) ~= "string" or not Key:match("^Add") or Key == "AddSection" or type(Tab[Key]) ~= "function" then return nil end
				return function(Self, ...)
					if Self._Destroyed or Tab._Destroyed then return nil end
					local PreviousParent, PreviousSection = ElementParent, CurrentContentSection
					ElementParent, CurrentContentSection = Content, Self
					local Results = table.pack(pcall(Tab[Key], Tab, ...))
					ElementParent, CurrentContentSection = PreviousParent, PreviousSection
					if not Results[1] then error(Results[2], 0) end
					return table.unpack(Results, 2, Results.n)
				end
			end})
			SectionFrame.Activated:Connect(function() Section:Toggle() end)
			CurrentContentSection, ElementParent = Section, Content
			return RegisterFlagObject(SectionFlag, Section, Holder)
		end

		function Tab:AddDivider(Configs)
			Configs = type(Configs) == "table" and Configs or {}
			local Height = math.clamp(tonumber(Configs.Height) or 14, 4, 60)
			local Thickness = math.clamp(tonumber(Configs.Thickness) or 1, 1, 12)
			local Inset = math.clamp(tonumber(Configs.Inset) or 8, 0, 60)
			local Transparency = math.clamp(tonumber(Configs.Transparency) or 0.25, 0, 1)
			Height = math.max(Height, Thickness + 4)

			local Holder = Create("Frame", ElementParent, {
				Size = UDim2.new(1, 0, 0, Height),
				BackgroundTransparency = 1,
				BorderSizePixel = 0
			})
			local Line = InsertTheme(Create("Frame", Holder, {
				Size = UDim2.new(1, -Inset * 2, 0, Thickness),
				Position = UDim2.new(0, Inset, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme["Color Stroke"],
				BackgroundTransparency = Transparency,
				BorderSizePixel = 0
			}), "Stroke")
			local ThemeEntry = Library.Instances[#Library.Instances]
			local Divider = {}

			function Divider:SetColor(Value)
				local Key, Kind
				if Value == nil or Value == "Stroke" or Value == "Color Stroke" then
					Key, Kind = "Color Stroke", "Stroke"
				elseif Value == "Theme" or Value == "Color Theme" then
					Key, Kind = "Color Theme", "Theme"
				elseif Value == "Text" or Value == "Color Text" then
					Key, Kind = "Color Text", "Text"
				elseif Value == "DarkText" or Value == "Color Dark Text" then
					Key, Kind = "Color Dark Text", "DarkText"
				elseif typeof(Value) ~= "Color3" then
					return false
				end
				ThemeEntry.Type = Kind or "Custom"
				Line.BackgroundColor3 = Key and Theme[Key] or Value
				return true
			end

			function Divider:SetThickness(Value)
				Value = tonumber(Value)
				if not Value or Value ~= Value then return false end
				Thickness = math.clamp(Value, 1, 12)
				Height = math.max(Height, Thickness + 4)
				Holder.Size = UDim2.new(1, 0, 0, Height)
				Line.Size = UDim2.new(1, -Inset * 2, 0, Thickness)
				return true
			end

			function Divider:SetHeight(Value)
				Value = tonumber(Value)
				if not Value or Value ~= Value then return false end
				Height = math.clamp(Value, Thickness + 4, 60)
				Holder.Size = UDim2.new(1, 0, 0, Height)
				return true
			end

			function Divider:SetInset(Value)
				Value = tonumber(Value)
				if not Value or Value ~= Value then return false end
				Inset = math.clamp(Value, 0, 60)
				Line.Position = UDim2.new(0, Inset, 0.5, 0)
				Line.Size = UDim2.new(1, -Inset * 2, 0, Thickness)
				return true
			end

			function Divider:SetTransparency(Value)
				Value = tonumber(Value)
				if not Value or Value ~= Value then return false end
				Line.BackgroundTransparency = math.clamp(Value, 0, 1)
				return true
			end

			function Divider:Visible(...) Funcs:ToggleVisible(Holder, ...) end
			function Divider:Destroy() Holder:Destroy() end

			Divider:SetColor(Configs.Color)
			return RegisterFlagObject(Configs.Flag, Divider, Holder)
		end

		function Tab:AddParagraph(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local PName = Configs[1] or Configs.Title or TranslateText(ControlsConfig.Titles.Paragraph)
			local PDesc = FirstDefined(Configs[2], Configs.Text, Configs.Desc, Configs.Description, "")
			
			local Frame, LabelFunc = ButtonFrame(ElementParent, PName, PDesc, UDim2.new(1, -20), false)
			
			local Paragraph = {}
			function Paragraph:Visible(...) Funcs:ToggleVisible(Frame, ...) end
			function Paragraph:Destroy() Frame:Destroy() end
			function Paragraph:SetTitle(Val)
				LabelFunc:SetTitle(GetStr(Val))
			end
			function Paragraph:SetDesc(Val)
				LabelFunc:SetDesc(GetStr(Val))
			end
			function Paragraph:Set(Val1, Val2)
				if Val1 and Val2 then
					LabelFunc:SetTitle(GetStr(Val1))
					LabelFunc:SetDesc(GetStr(Val2))
				elseif Val1 then
					LabelFunc:SetDesc(GetStr(Val1))
				end
			end
			return RegisterFlagObject(Configs.Flag, Paragraph, Frame)
		end
		function Tab:AddButton(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local BName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.Button)
			local BDescription = Configs.Desc or Configs.Description or ""
			local Callback = Funcs:GetCallback(Configs, 2)
			
			local FButton, LabelFunc = ButtonFrame(ElementParent, BName, BDescription, UDim2.new(1, -20))
			
			local ButtonIcon = Create("ImageLabel", FButton, {
				Size = UDim2.new(0, 14, 0, 14),
				Position = UDim2.new(1, -10, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://10709791437"
			})
			
			local function FireButton()
				PlayUISound()
				Funcs:FireCallback(Callback)
			end

			FButton.Activated:Connect(FireButton)
			
			local Button = {}
			function Button:Visible(...) Funcs:ToggleVisible(FButton, ...) end
			function Button:Destroy() FButton:Destroy() end
			function Button:SetTitle(Value) LabelFunc:SetTitle(DisplayString(Value)) end
			function Button:SetDesc(Value) LabelFunc:SetDesc(DisplayString(Value)) end
			function Button:Callback(...) Funcs:InsertCallback(Callback, ...) end
			function Button:Click()
				if self.IsLocked and self:IsLocked() then
					self:NotifyLocked()
					return false
				end

				FireButton()
				return true
			end
			function Button:Set(Val1, Val2)
				if type(Val1) == "string" and type(Val2) == "string" then
					LabelFunc:SetTitle(Val1)
					LabelFunc:SetDesc(Val2)
				elseif type(Val1) == "string" then
					LabelFunc:SetTitle(Val1)
				elseif type(Val1) == "function" then
					Callback = {Val1}
				end
			end

			ApplyLocked(Button, FButton, Configs)
			return RegisterFlagObject(Configs.Flag, Button, FButton)
		end
		function Tab:AddToggle(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local TName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.Toggle)
			local TDesc = Configs.Desc or Configs.Description or ""
			local Callback = Funcs:GetCallback(Configs, 3)
			local Flag = Configs[4] or Configs.Flag or false
			local Default = FirstDefined(Configs[2], Configs.Default, false)
			if CheckFlag(Flag) then Default = GetFlag(Flag) end
			Default = Default == true
			
			local HasKeybind = Configs.Keybind ~= nil and Configs.Keybind ~= false and UserInputService.KeyboardEnabled
			local Destroyed = false
			local Binding
			local ToggleControl = {}
			local DragInput, DragMoveConnection, DragEndConnection
			local DragStartX, DragStartY, DragStartCenter
			local Dragged, Scrolled = false, false
			local SuppressActivation, ActivationToken = false, 0
			local PositionTween, TransparencyTween
			local FinishDrag
			local Button, LabelFunc = ButtonFrame(ElementParent, TName, TDesc, UDim2.new(1, -38))
			
			local ToggleHolder = InsertTheme(Create("Frame", Button, {
				Size = UDim2.new(0, 35, 0, 18),
				Position = UDim2.new(1, -10, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme["Color Stroke"]
			}), "Stroke")Make("Corner", ToggleHolder, UDim.new(0.5, 0))
			
			local Slider = Create("Frame", ToggleHolder, {
				BackgroundTransparency = 1,
				Size = UDim2.new(0.8, 0, 0.8, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5)
			})
			
			local Toggle = InsertTheme(Create("TextButton", Slider, {
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.new(0, 6, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme["Color Theme"],
				Text = "",
				AutoButtonColor = false,
				Selectable = false,
				Active = true
			}), "Theme")Make("Corner", Toggle, UDim.new(0.5, 0))
			local KnobHalfWidth = Toggle.Size.X.Offset / 2
			
			local function SetToggleVisual(Value, Instant)
				if PositionTween then
					PositionTween:Cancel()
					PositionTween = nil
				end
				if TransparencyTween then
					TransparencyTween:Cancel()
					TransparencyTween = nil
				end

				local Target = UDim2.new(Value and 1 or 0, Value and -KnobHalfWidth or KnobHalfWidth, 0.5, 0)
				local Transparency = Value and 0 or 0.8
				if Instant then
					Toggle.Position = Target
					Toggle.BackgroundTransparency = Transparency
				else
					PositionTween = CreateTween({Toggle, "Position", Target, AnimationToggle})
					TransparencyTween = CreateTween({Toggle, "BackgroundTransparency", Transparency, AnimationToggle})
				end
			end

			local function SetToggle(Value, Force, Silent)
				if Destroyed or type(Value) ~= "boolean" then return false end
				if Default == Value and not Force then return true end
				if DragInput and FinishDrag then FinishDrag(false) end

				Default = Value
				SetFlag(Flag, Default)
				SetToggleVisual(Default, Force)
				if Binding then Binding:Refresh() end
				if not Silent then Funcs:FireCallback(Callback, Default) end
				return true
			end

			FinishDrag = function(Restore)
				if not DragInput then return end
				DragInput = nil
				if DragMoveConnection then
					DragMoveConnection:Disconnect()
					DragMoveConnection = nil
				end
				if DragEndConnection then
					DragEndConnection:Disconnect()
					DragEndConnection = nil
				end
				if Restore and not Destroyed then
					SetToggleVisual(Default, false)
				end

				local Token = ActivationToken
				task.delay(0.1, function()
					if ActivationToken == Token then
						SuppressActivation = false
					end
				end)
			end

			Toggle.InputBegan:Connect(function(Input)
				local InputType = Input.UserInputType
				if Destroyed or DragInput or ToggleControl.Locked or not Button.Interactable
					or (Binding and Binding.Waiting)
					or (InputType ~= Enum.UserInputType.MouseButton1 and InputType ~= Enum.UserInputType.Touch) then
					return
				end

				if PositionTween then
					PositionTween:Cancel()
					PositionTween = nil
				end
				if TransparencyTween then
					TransparencyTween:Cancel()
					TransparencyTween = nil
				end

				DragInput = Input
				DragStartX, DragStartY = Input.Position.X, Input.Position.Y
				DragStartCenter = Toggle.AbsolutePosition.X + Toggle.AbsoluteSize.X / 2 - Slider.AbsolutePosition.X
				Dragged, Scrolled = false, false
				SuppressActivation = true
				ActivationToken += 1

				DragMoveConnection = UserInputService.InputChanged:Connect(function(Changed)
					if DragInput ~= Input or Scrolled then return end
					if InputType == Enum.UserInputType.Touch then
						if Changed ~= Input then return end
					elseif Changed.UserInputType ~= Enum.UserInputType.MouseMovement then
						return
					end

					local DeltaX = Changed.Position.X - DragStartX
					local DeltaY = Changed.Position.Y - DragStartY
					if not Dragged then
						if math.abs(DeltaY) > 10 and math.abs(DeltaY) > math.abs(DeltaX) then
							Scrolled = true
							return
						end
						if math.abs(DeltaX) <= 3 then return end
						Dragged = true
					end

					local HalfWidth = Toggle.AbsoluteSize.X / 2
					local Travel = Slider.AbsoluteSize.X - HalfWidth * 2
					if Travel <= 0 then return end
					local Center = math.clamp(DragStartCenter + DeltaX, HalfWidth, HalfWidth + Travel)
					Toggle.Position = UDim2.new(Center / Slider.AbsoluteSize.X, 0, 0.5, 0)
					Toggle.BackgroundTransparency = 0.8 * (1 - (Center - HalfWidth) / Travel)
				end)

				DragEndConnection = UserInputService.InputEnded:Connect(function(Ended)
					if DragInput ~= Input then return end
					if InputType == Enum.UserInputType.Touch then
						if Ended ~= Input then return end
					elseif Ended.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					local WasDragged, WasScrolled = Dragged, Scrolled
					local NextValue = Toggle.AbsolutePosition.X + Toggle.AbsoluteSize.X / 2 >= Slider.AbsolutePosition.X + Slider.AbsoluteSize.X / 2
					FinishDrag(false)

					if Destroyed or ToggleControl.Locked or not Button.Interactable or WasScrolled then
						if not Destroyed then SetToggleVisual(Default, false) end
					elseif WasDragged then
						if NextValue == Default then
							SetToggleVisual(Default, false)
						elseif SetToggle(NextValue) then
							PlayUISound()
						end
					elseif SetToggle(not Default) then
						PlayUISound()
					end
				end)
			end)

			Button.Activated:Connect(function(Input)
				if Destroyed or SuppressActivation or DragInput or not Button.Interactable then return end
				if Binding and (Binding.Waiting or Binding:ContainsInput(Input)) then return end
				if SetToggle(not Default) then PlayUISound() end
			end)

			function ToggleControl:Visible(...) Funcs:ToggleVisible(Button, ...) end
			function ToggleControl:Destroy()
				if Destroyed then return end
				if FinishDrag then FinishDrag(false) end
				if Binding then Binding:Destroy() end
				Destroyed = true
				Button:Destroy()
			end
			function ToggleControl:Callback(...)
				local Added = Funcs:InsertCallback(Callback, ...)
				if type(Added) == "function" then Added(Default) end
			end
			function ToggleControl:SetEnabled(Value, Silent)
				if Destroyed or type(Value) ~= "boolean" then return false end
				SetToggle(Value, false, Silent == true)
				return Default
			end
			function ToggleControl:SetKeybind(Key)
				if not Binding then return false end
				return Binding:SetKey(Key, true)
			end
			function ToggleControl:GetKeybind()
				return Binding and Binding.CurrentKey or nil
			end
			function ToggleControl:GetEnabled()
				return Default
			end
			ToggleControl.Get = ToggleControl.GetEnabled
			ToggleControl.IsEnabled = ToggleControl.GetEnabled
			function ToggleControl:Toggle()
				return self:SetEnabled(not Default)
			end
			function ToggleControl:Set(Val1, Val2)
				if type(Val1) == "string" and type(Val2) == "string" then
					LabelFunc:SetTitle(Val1)
					LabelFunc:SetDesc(Val2)
				elseif type(Val1) == "string" then
					LabelFunc:SetTitle(Val1)
				elseif type(Val1) == "boolean" then
					SetToggle(Val1)
				elseif type(Val1) == "function" then
					Callback = {Val1}
				end
			end
			function ToggleControl:SetTitle(Value)
				LabelFunc:SetTitle(DisplayString(Value))
			end
			function ToggleControl:SetDesc(Value)
				LabelFunc:SetDesc(DisplayString(Value))
			end

			ApplyLocked(ToggleControl, Button, Configs, function(IsLocked)
				if IsLocked then
					if FinishDrag then FinishDrag(true) end
					if Binding then Binding:SetWaiting(false) end
				end
			end)
			if HasKeybind then
				Binding = CreateKeybindControl(ToggleControl, Button, LabelFunc, Configs, {
					RightOffset = 51,
					MaxWidth = 120,
					AllowNone = true,
					InitialKey = Configs.Keybind,
					IsActive = function() return Default == true end,
					OnChanged = Configs.OnKeybindChanged,
					OnTriggered = function()
						if SetToggle(not Default) then PlayUISound() end
					end
				})
			end
			Button.Destroying:Connect(function()
				if FinishDrag then FinishDrag(false) end
				Destroyed = true
				if Binding then Binding:Destroy() end
			end)
			local Registered = RegisterFlagObject(Flag, ToggleControl, Button)
			SetToggle(Default == true, true)
			return Registered
		end
		function Tab:AddDropdown(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local DName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.Dropdown)
			local DDesc = Configs.Desc or Configs.Description or ""
			local DOptions = Configs[2] or Configs.Options or {}
			DOptions = type(DOptions) == "table" and DOptions or {}
			local OpDefault = Configs[3] or Configs.Default or ControlsConfig.Dropdown.Placeholder
			local DMultiSelect = Configs.MultiSelect or false
			local DMultiConfig = type(Configs.MultiConfig) == "table" and Configs.MultiConfig or {}
			local DAllowNone = Configs.AllowNone ~= false
			local UsesGlobalSearch = type(Configs.Search) ~= "boolean"
			local DSearch = UsesGlobalSearch and Library.Save.DropdownSearch == true or Configs.Search == true
			local UsesGlobalPrefixOnly = not (Configs.SearchConfig and type(Configs.SearchConfig.PrefixOnly) == "boolean")
			local UsesGlobalCloseOnSelect = type(Configs.CloseOnSelect) ~= "boolean"
			local UsesGlobalMaxVisibleOptions = tonumber(Configs.MaxVisibleOptions) == nil
			local DPrefixOnly = UsesGlobalPrefixOnly and Library.Save.DropdownPrefixOnly ~= false
				or Configs.SearchConfig and Configs.SearchConfig.PrefixOnly == true
			local DCloseOnSelect = UsesGlobalCloseOnSelect and Library.Save.DropdownCloseOnSelect == true or Configs.CloseOnSelect == true
			local DMaxVisibleOptions = math.clamp(
				math.floor(tonumber(Configs.MaxVisibleOptions) or Library.Save.DropdownMaxVisibleOptions or DefaultDropdownMaxVisibleOptions),
				3,
				12
			)
			local OptionRenderer = Configs.OptionRenderer
			local OnSearch = Configs.OnSearch
			local Callback = Funcs:GetCallback(Configs, 4)
			local Flag = Configs[5] or Configs.Flag or false
			local FavoriteEnabled = Configs.Favorite == true
			local FavoriteGroup, FavoriteIdentity, FavoriteEntries
			if FavoriteEnabled then
				local HasFlag = type(Flag) == "string" and Flag ~= ""
				local GroupName = HasFlag and "Flags" or "Names"
				local BaseIdentity = HasFlag and Flag
					or tostring(Configs.FavoriteKey or Configs[1] or Configs.Name or Configs.Title or DName)
				local CountKey = GroupName .. "/" .. BaseIdentity
				local Number = (FavoriteDropdownCounts[CountKey] or 0) + 1
				FavoriteDropdownCounts[CountKey] = Number
				FavoriteIdentity = BaseIdentity .. (Number == 1 and "" or "#" .. Number)
				DropdownFavorites[WTitle] = DropdownFavorites[WTitle] or {}
				local HubFavorites = DropdownFavorites[WTitle]
				HubFavorites[FavoriteTabKey] = HubFavorites[FavoriteTabKey] or {}
				local TabFavorites = HubFavorites[FavoriteTabKey]
				TabFavorites[GroupName] = TabFavorites[GroupName] or {}
				FavoriteGroup = TabFavorites[GroupName]
				local Saved = FavoriteGroup[FavoriteIdentity]
				FavoriteEntries = type(Saved) == "table" and table.clone(Saved) or {}
			end
			local DropdownConnections = {}

			local function TrackDropdownConnection(ConnectionObject)
				DropdownConnections[#DropdownConnections + 1] = ConnectionObject
				return ConnectionObject
			end

			local CustomNoResultText = Configs.SearchConfig and Configs.SearchConfig.NoResultText
			local SearchConfig = {
				Enabled = DSearch,
				Placeholder = TranslateText("Search"),
				TextSize = Configs.SearchConfig and Configs.SearchConfig.TextSize or DropdownConfig.SearchConfig.TextSize,
				MinTextSize = Configs.SearchConfig and Configs.SearchConfig.MinTextSize or DropdownConfig.SearchConfig.MinTextSize,
				SearchFrameHeight = Configs.SearchConfig and Configs.SearchConfig.SearchFrameHeight or DropdownConfig.SearchConfig.SearchFrameHeight,
				SearchFrameOffset = Configs.SearchConfig and Configs.SearchConfig.SearchFrameOffset or DropdownConfig.SearchConfig.SearchFrameOffset,
				IconSize = Configs.SearchConfig and Configs.SearchConfig.IconSize or DropdownConfig.SearchConfig.IconSize,
				IconPosition = Configs.SearchConfig and Configs.SearchConfig.IconPosition or DropdownConfig.SearchConfig.IconPosition,
				InputOffset = Configs.SearchConfig and Configs.SearchConfig.InputOffset or DropdownConfig.SearchConfig.InputOffset,
				NoResultText = TranslateText(CustomNoResultText or "No options found"),
				NoResultTextSize = Configs.SearchConfig and Configs.SearchConfig.NoResultTextSize or DropdownConfig.SearchConfig.NoResultTextSize,
				PrefixOnly = DPrefixOnly == true
			}

			local Button, LabelFunc = ButtonFrame(ElementParent, DName, DDesc, UDim2.new(1, -180))

			local SelectedFrame = InsertTheme(Create("Frame", Button, {
				Size = UDim2.new(0, 150, 0, 18),
				Position = UDim2.new(1, -10, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme["Color Stroke"]
			}), "Stroke")

			Make("Corner", SelectedFrame, UDim.new(0, 4))

			local ActiveLabel = InsertTheme(Create("TextLabel", SelectedFrame, {
				Size = UDim2.new(0.85, 0, 0.85, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
				TextColor3 = Theme["Color Text"],
				Text = "..."
			}), "Text")

			local Arrow = InsertTheme(Create("ImageLabel", SelectedFrame, {
				Size = UDim2.new(0, 15, 0, 15),
				Position = UDim2.new(0, -5, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				Image = "rbxassetid://10709791523",
				ImageColor3 = Theme["Color Dark Text"],
				BackgroundTransparency = 1
			}), "DarkText")

			local NoClickFrame = Create("TextButton", DropdownHolder, {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Visible = false,
				Text = ""
			})

			local DropFrame = Create("Frame", NoClickFrame, {
				Size = UDim2.new(SelectedFrame.Size.X, 0, 0),
				BackgroundTransparency = 0.1,
				BackgroundColor3 = ControlColors.White,
				AnchorPoint = Vector2.new(0, 1),
				ClipsDescendants = true,
				Active = true
			})

			Make("Corner", DropFrame)
			Make("Stroke", DropFrame)
			Make("Gradient", DropFrame, {Rotation = 60})

			local SearchFrame
			local SearchIcon
			local SearchInputFrame
			local SearchInput
			local SearchPlaceholderLabel
			local SearchMessage
			local SearchResizePending = false

			do
				SearchFrame = InsertTheme(Create("Frame", DropFrame, {
					Size = UDim2.new(1, -16, 0, SearchConfig.SearchFrameHeight),
					Position = UDim2.new(0, 8, 0, SearchConfig.SearchFrameOffset),
					BackgroundColor3 = Theme["Color Hub 2"],
					Visible = SearchConfig.Enabled
				}), "Frame")

				Make("Corner", SearchFrame, UDim.new(0, 4))

				SearchIcon = InsertTheme(Create("ImageLabel", SearchFrame, {
					Size = UDim2.fromOffset(SearchConfig.IconSize, SearchConfig.IconSize),
					Position = UDim2.new(0, SearchConfig.IconPosition, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://10734943674",
					ImageColor3 = Theme["Color Dark Text"]
				}), "DarkText")

				SearchInputFrame = Create("Frame", SearchFrame, {
					Size = UDim2.new(1, -27, 1, 0),
					Position = UDim2.new(0, SearchConfig.InputOffset, 0, 0),
					BackgroundTransparency = 1,
					ClipsDescendants = true
				})

				-- Render the placeholder ourselves: Roblox or other scripts can replace
				-- a TextBox's native placeholder even when AutoLocalize is disabled.
				SearchPlaceholderLabel = InsertTheme(Create("TextLabel", SearchInputFrame, {
					AutoLocalize = false,
					Size = UDim2.new(1, -2, 1, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Text = SearchConfig.Placeholder,
					TextColor3 = Theme["Color Dark Text"],
					TextSize = SearchConfig.TextSize,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextWrapped = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Active = false, Interactable = false, Selectable = false
				}), "DarkText")

				SearchInput = InsertTheme(Create("TextBox", SearchInputFrame, {
                    AutoLocalize = false,
					Size = UDim2.new(1, -2, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					Font = Enum.Font.GothamBold,
					Text = "",
					PlaceholderText = "",
					PlaceholderColor3 = Theme["Color Dark Text"],
					TextColor3 = Theme["Color Text"],
					TextSize = SearchConfig.TextSize,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextWrapped = false,
					ClipsDescendants = false
				}), "Text")

				SearchMessage = InsertTheme(Create("TextLabel", DropFrame, {
					Size = UDim2.new(1, -16, 0, 20),
					Position = UDim2.new(0, 8, 0, 32),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Text = SearchConfig.NoResultText,
					TextColor3 = Theme["Color Dark Text"],
					TextSize = SearchConfig.NoResultTextSize,
					TextXAlignment = "Center",
					TextYAlignment = "Center",
					Visible = false,
					ZIndex = 5
				}), "DarkText")

				TrackConnection(TrackDropdownConnection(Connection.LanguageChanged:Connect(function()
					if SearchPlaceholderLabel and SearchPlaceholderLabel.Parent then
						SearchPlaceholderLabel.Text = TranslateText("Search")
					end
					if SearchMessage and SearchMessage.Parent then
						SearchMessage.Text = TranslateText(CustomNoResultText or "No options found")
					end
				end)))
			end

			local function UpdateSearchTextSize()
				if not SearchConfig.Enabled or not SearchInput then
					return
				end

				if SearchResizePending then
					return
				end

				SearchResizePending = true

				task.defer(function()
					SearchResizePending = false

					if not SearchInput or not SearchInput.Parent then
						return
					end

					local Text = SearchInput.Text
					local NewTextSize = SearchConfig.TextSize

					if Text ~= "" then
						local AvailableWidth = SearchInput.AbsoluteSize.X - 2

						if AvailableWidth > 0 then
							for Size = SearchConfig.TextSize, SearchConfig.MinTextSize, -0.25 do
								local Bounds = TextService:GetTextSize(
									Text,
									Size,
									SearchInput.Font,
									Vector2.new(math.huge, math.huge)
								)

								if Bounds.X <= AvailableWidth then
									NewTextSize = Size
									break
								end

								NewTextSize = SearchConfig.MinTextSize
							end
						end
					end

					if SearchInput.TextSize ~= NewTextSize then
						SearchInput.TextSize = NewTextSize
					end
				end)
			end

			if SearchInput then
				local function UpdateSearchPlaceholder()
					if SearchPlaceholderLabel and SearchPlaceholderLabel.Parent then
						SearchPlaceholderLabel.Visible = SearchInput.Text == "" and not SearchInput:IsFocused()
					end
				end
				TrackDropdownConnection(SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
					UpdateSearchTextSize()
					UpdateSearchPlaceholder()
				end))
				TrackDropdownConnection(SearchInput.Focused:Connect(UpdateSearchPlaceholder))
				TrackDropdownConnection(SearchInput.FocusLost:Connect(UpdateSearchPlaceholder))
				TrackDropdownConnection(SearchInput:GetPropertyChangedSignal("PlaceholderText"):Connect(function()
					if SearchInput.PlaceholderText ~= "" then SearchInput.PlaceholderText = "" end
				end))
				SearchInput:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateSearchTextSize)
			end

			local ScrollFrame = InsertTheme(Create("ScrollingFrame", DropFrame, {
				Size = SearchConfig.Enabled and UDim2.new(1, 0, 1, -30) or UDim2.new(1, 0, 1, 0),
				Position = SearchConfig.Enabled and UDim2.new(0, 0, 0, 30) or UDim2.new(0, 0, 0, 0),
				ScrollBarImageColor3 = Theme["Color Theme"],
				ScrollBarThickness = ScrollThickness,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				ScrollingDirection = "Y",
				AutomaticCanvasSize = "Y",
				Active = true
			}, {
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
					PaddingTop = UDim.new(0, 5),
					PaddingBottom = UDim.new(0, 5)
				}),
				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4)
				})
			}), "ScrollBar")

			local ScrollSize, WaitClick = 5

			local function Disable()
				if not NoClickFrame.Visible or WaitClick then return end
				WaitClick = true

				CreateTween({Arrow, "Rotation", 0, AnimationDropdown})
				CreateTween({DropFrame, "Size", UDim2.new(0, 152, 0, 0), AnimationDropdown, true})
				CreateTween({Arrow, "ImageColor3", ControlColors.White, AnimationDropdown})

				Arrow.Image = "rbxassetid://10709791523"
				NoClickFrame.Visible = false

				if SearchInput then
					SearchInput:ReleaseFocus()
				end

				WaitClick = false
			end

			local function HideInstantly()
				if not NoClickFrame.Visible then return end
				NoClickFrame.Visible = false
				DropFrame.Size = UDim2.fromOffset(152, 0)
				Arrow.Image = "rbxassetid://10709791523"
				Arrow.Rotation = 0
				Arrow.ImageColor3 = ControlColors.White
				if SearchInput then SearchInput:ReleaseFocus() end
			end


			local function GetFrameSize()
				return UDim2.fromOffset(152, ScrollSize)
			end

			local function CalculateSize()
				local Count = 0

				for _, Frame in pairs(ScrollFrame:GetChildren()) do
					if Frame:IsA(FavoriteEnabled and "Frame" or "TextButton") then
						Count = Count + 1
					end
				end

				local MaxVisibleOptions = UsesGlobalMaxVisibleOptions
					and Library:GetDropdownMaxVisibleOptions()
					or DMaxVisibleOptions

				ScrollSize = (math.clamp(Count, 0, MaxVisibleOptions) * 25) + 10

				if SearchConfig.Enabled then
					ScrollSize = ScrollSize + 30
				end

				if NoClickFrame.Visible then
					CreateTween({DropFrame, "Size", GetFrameSize(), AnimationDropdown, true})
				end
			end

			local CalculatePos
			local function Minimize()
				if WaitClick then
					return
				end

				WaitClick = true

				if NoClickFrame.Visible then
					Arrow.Image = "rbxassetid://10709791523"
					CreateTween({Arrow, "ImageColor3", ControlColors.White, AnimationDropdown})
					CreateTween({DropFrame, "Size", UDim2.new(0, 152, 0, 0), AnimationDropdown, true})
					NoClickFrame.Visible = false
				else
					if FavoriteEnabled then ScrollFrame.CanvasPosition = Vector2.new(0, 0) end
					CalculatePos()
					NoClickFrame.Visible = true
					Arrow.Image = "rbxassetid://10709790948"
					CreateTween({Arrow, "ImageColor3", Theme["Color Theme"], AnimationDropdown})
					CreateTween({DropFrame, "Size", GetFrameSize(), AnimationDropdown, true})

					if SearchInput then
						UpdateSearchTextSize()
					end
				end

				WaitClick = false
			end

			CalculatePos = function()
				local FramePos = SelectedFrame.AbsolutePosition
				local ScreenSize = ScreenGui.AbsoluteSize

				local ClampX = math.clamp(
					FramePos.X / UIScale,
					0,
					ScreenSize.X / UIScale - DropFrame.Size.X.Offset
				)

				local ClampY = math.clamp(
					FramePos.Y / UIScale,
					0,
					ScreenSize.Y / UIScale
				)

				local NewPos = UDim2.fromOffset(ClampX, ClampY)
				local AnchorPoint = FramePos.Y > ScreenSize.Y / 1.4 and 1 or ScrollSize > 80 and 0.5 or 0

				DropFrame.AnchorPoint = Vector2.new(0, AnchorPoint)
				if DropFrame.Position ~= NewPos then
					if NoClickFrame.Visible then
						CreateTween({DropFrame, "Position", NewPos, AnimationDropdownPosition})
					else
						DropFrame.Position = NewPos
					end
				end
			end

            TrackDropdownConnection(Container:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                if not NoClickFrame.Visible then return end
                local Top = Container.AbsolutePosition.Y
                local Bottom = Top + Container.AbsoluteSize.Y
                local AnchorTop = SelectedFrame.AbsolutePosition.Y
                local AnchorBottom = AnchorTop + SelectedFrame.AbsoluteSize.Y
                if AnchorBottom <= Top or AnchorTop >= Bottom then
                    HideInstantly()
                else
                    CalculatePos()
                end
            end))

			local AddNewOptions, GetOptions, AddOption, RemoveOption, Selected, SetSearchEnabled, SetPrefixOnly

			do
				local Default = type(OpDefault) ~= "table" and {OpDefault} or OpDefault

				local MultiSelect = DMultiSelect
				local MultiMax = tonumber(DMultiConfig.Max) or math.huge
				local MultiMin = tonumber(DMultiConfig.Min) or ControlsConfig.Dropdown.MultiMin

				MultiMax = math.max(0, MultiMax)
				MultiMin = math.max(0, MultiMin)

				if MultiMax ~= math.huge and MultiMin > MultiMax then
					MultiMin = MultiMax
				end

				local Options = {}
				local SearchNameCache = setmetatable({}, {__mode = "k"})
				local NextOptionOrder = 0

				local FavoriteTweenInfo = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
				local FavoriteGold = Color3.fromRGB(255, 197, 74)
				local FavoriteGoldHover = Color3.fromRGB(255, 225, 145)
				local FavoriteColorTweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local function UpdateFavoriteVisual(Entry, AnimateColor)
					if not FavoriteEnabled then return end
					Entry.Holder.LayoutOrder = Entry.Favorite and Entry.SortIndex - 100000000 or Entry.SortIndex
					if Entry.StarIcon then
						local Color = Entry.Favorite and (Entry.StarHovered and FavoriteGoldHover or FavoriteGold) or Theme["Color Dark Text"]
						local Transparency = Entry.Favorite and 0 or (Entry.StarHovered and 0.18 or 0.5)
						if Entry.ColorTween then Entry.ColorTween:Cancel() end
						if AnimateColor then
							Entry.ColorTween = TweenService:Create(Entry.StarIcon, FavoriteColorTweenInfo, {
								ImageColor3 = Color,
								ImageTransparency = Transparency
							})
							Entry.ColorTween:Play()
						else
							Entry.StarIcon.ImageColor3 = Color
							Entry.StarIcon.ImageTransparency = Transparency
						end
					end
				end

				local function AnimateFavoriteOrder(ChangedEntry)
					local Visible = {}
					local PreviousPositions = {}
					for _, Entry in pairs(Options) do
						if Entry.Holder.Visible then
							Visible[#Visible + 1] = Entry
						end
					end
					table.sort(Visible, function(A, B)
						return A.Holder.LayoutOrder < B.Holder.LayoutOrder
					end)
					for Index, Entry in ipairs(Visible) do
						PreviousPositions[Entry] = Index
					end
					for _, Entry in pairs(Options) do
						if Entry == ChangedEntry then
							UpdateFavoriteVisual(Entry, true)
						else
							Entry.Holder.LayoutOrder = Entry.Favorite and Entry.SortIndex - 100000000 or Entry.SortIndex
						end
					end
					table.sort(Visible, function(A, B)
						return A.Holder.LayoutOrder < B.Holder.LayoutOrder
					end)
					for Index, Entry in ipairs(Visible) do
						if Entry.MoveTween then Entry.MoveTween:Cancel() end
						local Row = Entry.nodes[1]
						local OldY = (PreviousPositions[Entry] - 1) * 25
						local NewY = (Index - 1) * 25
						local ViewTop = ScrollFrame.CanvasPosition.Y
						local ViewBottom = ViewTop + ScrollFrame.AbsoluteSize.Y
						local InView = (OldY + 21 >= ViewTop and OldY <= ViewBottom)
							or (NewY + 21 >= ViewTop and NewY <= ViewBottom)
						local Offset = Row.Position.Y.Offset + OldY - NewY
						if InView and Offset ~= 0 then
							Row.Position = UDim2.fromOffset(0, Offset)
							local Tween = TweenService:Create(Row, FavoriteTweenInfo, {Position = UDim2.fromOffset(0, 0)})
							Entry.MoveTween = Tween
							Tween.Completed:Once(function()
								if Entry.MoveTween == Tween then Entry.MoveTween = nil end
							end)
							Tween:Play()
						else
							Row.Position = UDim2.fromOffset(0, 0)
							Entry.MoveTween = nil
						end
					end
				end

				if MultiSelect then
					Selected = {}

					local Saved = CheckFlag(Flag) and GetFlag(Flag) or nil

					if type(Saved) == "table" then
						for Index, Value in pairs(Saved) do
							if type(Index) == "string" and Value then
								Selected[Index] = true
							end
						end
					end
				else
					if CheckFlag(Flag) then
						Selected = GetFlag(Flag)
					else
						Selected = Default[1]
					end
				end

				local function GetOptionName(Value, Index)
					if type(Value) == "table" then
						return tostring(
							FirstDefined(Value.Name, Value.DisplayName, Value.Label, Index)
						)
					end

					return tostring(type(Index) == "string" and Index or Value)
				end

				local function GetSelectedCount()
					local Count = 0

					for _, Value in pairs(Selected) do
						if Value then
							Count = Count + 1
						end
					end

					return Count
				end

				local function CallbackSelected()
					SetFlag(Flag, Selected)
					Funcs:FireCallback(Callback, Selected)
				end

				local function GetSelectedText(Value)
					local Text

					if type(Value) == "table" then
						Text = tostring(
							FirstDefined(Value.Name, Value.DisplayName, Value.Label, "")
						)
					else
						Text = tostring(Value)
					end

					return TranslateText(Text)
				end

				local function UpdateLabel()
					if MultiSelect then
						local List = {}

						for Name, Value in pairs(Selected) do
							if Value then
								table.insert(List, TranslateText(Name))
							end
						end

						if #List > 0 then
							ActiveLabel.Text = table.concat(List, ", ")
						else
							ActiveLabel.Text = TranslateText(tostring(FirstDefined(Default[1], "...")))
						end
					else
						if Selected ~= nil then
							ActiveLabel.Text = GetSelectedText(Selected)
						else
							ActiveLabel.Text = TranslateText(tostring(FirstDefined(Default[1], "...")))
						end
					end
				end

				local function UpdateSelected()
					for _, Entry in pairs(Options) do
						local Nodes = Entry.nodes
						local IsActive = MultiSelect and Entry.Stats == true or (not MultiSelect and Entry.Value == Selected)
						if Entry.VisualActive ~= IsActive then
							local IndicatorTransparency = IsActive and 0 or 1
							local IndicatorSize = IsActive and UDim2.fromOffset(4, 14) or UDim2.fromOffset(4, 4)
							local TextTransparency = IsActive and 0 or 0.4
							if Entry.VisualActive == nil then
								Nodes[2].BackgroundTransparency = IndicatorTransparency
								Nodes[2].Size = IndicatorSize
								Nodes[3].TextTransparency = TextTransparency
							else
								CreateTween({Nodes[2], "BackgroundTransparency", IndicatorTransparency, AnimationTab})
								CreateTween({Nodes[2], "Size", IndicatorSize, AnimationTab})
								CreateTween({Nodes[3], "TextTransparency", TextTransparency, AnimationTab})
							end
							Entry.VisualActive = IsActive
						end
					end
					UpdateLabel()
				end

				local function UpdateSearch()
					if not SearchConfig.Enabled or not SearchInput then
						return
					end

					local SearchText = SearchInput.Text:lower():gsub("^%s*(.-)%s*$", "%1")
					local Found = false

					for _, Value in pairs(Options) do
						local OptionButton = Value.Holder or Value.nodes[1]
						local OptionName = SearchNameCache[Value] or TranslateText(Value.Name):lower()

						if type(OnSearch) == "function" then
							local Success, Result = pcall(OnSearch, SearchText, Value.Value)

							if Success and Result ~= nil then
								OptionName = tostring(Result)
							end
						end

						OptionName = OptionName:lower()

						local Match

						if SearchConfig.PrefixOnly then
							Match = SearchText == "" or OptionName:sub(1, #SearchText) == SearchText
						else
							Match = SearchText == "" or OptionName:find(SearchText, 1, true) ~= nil
						end

						OptionButton.Visible = Match

						if Match then
							Found = true
						end
					end

					SearchMessage.Visible = SearchText ~= "" and not Found
					ScrollFrame.CanvasPosition = Vector2.new(0, 0)

					UpdateSearchTextSize()
				end

				SetSearchEnabled = function(Value)
					Value = Value == true

					if SearchConfig.Enabled == Value then
						return
					end

					SearchConfig.Enabled = Value
					SearchFrame.Visible = Value
					ScrollFrame.Size = Value and UDim2.new(1, 0, 1, -30) or UDim2.new(1, 0, 1, 0)
					ScrollFrame.Position = Value and UDim2.new(0, 0, 0, 30) or UDim2.new(0, 0, 0, 0)

					if Value then
						UpdateSearch()
						UpdateSearchTextSize()
					else
						SearchInput:ReleaseFocus()
						SearchInput.Text = ""
						SearchMessage.Visible = false

						for _, Option in pairs(Options) do
							if Option.nodes and Option.nodes[1] then
								(Option.Holder or Option.nodes[1]).Visible = true
							end
						end
					end

					ScrollFrame.CanvasPosition = Vector2.new(0, 0)
					CalculateSize()
					CalculatePos()
				end

				SetPrefixOnly = function(Value)
					SearchConfig.PrefixOnly = Value == true
					if SearchConfig.Enabled then
						UpdateSearch()
					end
				end

				local function Select(Option)
					if not Option then
						return
					end

					if MultiSelect then
						local CurrentCount = GetSelectedCount()

						if Option.Stats then
							if CurrentCount <= MultiMin then
								return
							end

							Option.Stats = false
							Selected[Option.Name] = nil
						else
							if CurrentCount >= MultiMax then
								return
							end

							Option.Stats = true
							Selected[Option.Name] = true
						end

						CallbackSelected()
					else
						if Selected == Option.Value then
							if not DAllowNone then
								return
							end

							Selected = nil
						else
							Selected = Option.Value
						end

						CallbackSelected()
					end

					PlayUISound()
					UpdateSelected()

					local CloseOnSelect = UsesGlobalCloseOnSelect
						and Library:GetDropdownCloseOnSelect()
						or DCloseOnSelect

					if CloseOnSelect and not MultiSelect then
						Disable()
					end
				end

				AddOption = function(Index, Value, SkipSearch)
					local Name = GetOptionName(Value, Index)

					if Options[Name] then
						return
					end

					NextOptionOrder += 1
					Options[Name] = {
						index = Index,
						Value = Value,
						Name = Name,
						Stats = false,
						SortIndex = NextOptionOrder,
						Favorite = FavoriteEnabled and FavoriteEntries[Name] == true or false
					}
					SearchNameCache[Options[Name]] = TranslateText(Name):lower()

					if MultiSelect then
						local Stats = Selected[Name] == true
						Selected[Name] = Stats
						Options[Name].Stats = Stats
					end

					local Holder = FavoriteEnabled and Create("Frame", ScrollFrame, {
						Size = UDim2.new(1, 0, 0, 21),
						BackgroundTransparency = 1
					}) or ScrollFrame
					local OptionButton = Make("Button", Holder, FavoriteEnabled and {
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.fromOffset(0, 0),
						AnchorPoint = Vector2.new(0, 0)
					} or {
						Size = UDim2.new(1, 0, 0, 21),
						Position = UDim2.new(0, 0, 0.5),
						AnchorPoint = Vector2.new(0, 0.5)
					})

					Make("Corner", OptionButton, UDim.new(0, 4))

					local IsSelected = InsertTheme(Create("Frame", OptionButton, {
						Position = UDim2.new(0, 1, 0.5),
						Size = UDim2.new(0, 4, 0, 4),
						BackgroundColor3 = Theme["Color Theme"],
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 0.5)
					}), "Theme")

					Make("Corner", IsSelected, UDim.new(0.5, 0))

					local OptioneName = InsertTheme(Create("TextLabel", OptionButton, {
						Size = UDim2.new(1, FavoriteEnabled and -36 or 0, 1, 0),
						TextTruncate = FavoriteEnabled and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
						Position = UDim2.new(0, 10),
						Text = TranslateText(Name),
						TextColor3 = Theme["Color Text"],
						Font = Enum.Font.GothamBold,
						TextXAlignment = "Left",
						BackgroundTransparency = 1,
						TextTransparency = 0.4
					}), "Text")

					local Entry = Options[Name]
					Entry.Holder = FavoriteEnabled and Holder or nil
					Entry.nodes = {
						OptionButton,
						IsSelected,
						OptioneName
					}

					if FavoriteEnabled then
						local StarButton = Create("ImageButton", OptionButton, {
							Size = UDim2.fromOffset(26, 21),
							Position = UDim2.new(1, 0, 0.5, 0),
							AnchorPoint = Vector2.new(1, 0.5),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							ImageTransparency = 1,
							AutoButtonColor = false,
							ZIndex = OptionButton.ZIndex + 1
						})
						local StarIcon = Create("ImageLabel", StarButton, {
							Size = UDim2.fromOffset(12, 12),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = Library:GetIcon("star"),
							ScaleType = Enum.ScaleType.Fit,
							ZIndex = StarButton.ZIndex + 1
						})
						Entry.StarButton = StarButton
						Entry.StarIcon = StarIcon
						Entry.StarScale = Create("UIScale", StarIcon, {Scale = 1})
						Entry.StarHovered = false

						local function TweenStarScale(Scale, Duration, EasingStyle)
							if Entry.StarTween then Entry.StarTween:Cancel() end
							Entry.StarTween = TweenService:Create(
								Entry.StarScale,
								TweenInfo.new(Duration, EasingStyle, Enum.EasingDirection.Out),
								{Scale = Scale}
							)
							Entry.StarTween:Play()
						end

						TrackDropdownConnection(StarButton.MouseEnter:Connect(function()
							Entry.StarHovered = true
							TweenStarScale(1.18, 0.16, Enum.EasingStyle.Quad)
							UpdateFavoriteVisual(Entry, true)
						end))
						TrackDropdownConnection(StarButton.MouseLeave:Connect(function()
							Entry.StarHovered = false
							TweenStarScale(1, 0.16, Enum.EasingStyle.Quad)
							UpdateFavoriteVisual(Entry, true)
						end))

						UpdateFavoriteVisual(Entry)
						StarButton.Activated:Connect(function()
							if Options[Name] ~= Entry then return end
							Entry.Favorite = not Entry.Favorite
							FavoriteEntries[Name] = Entry.Favorite or nil
							FavoriteGroup[FavoriteIdentity] =
								next(FavoriteEntries) and FavoriteEntries or nil
							AnimateFavoriteOrder(Entry)
							SaveDropdownFavorites()
							if Entry.StarTween then Entry.StarTween:Cancel() end
							Entry.StarScale.Scale = 0.88
							TweenStarScale(Entry.StarHovered and 1.18 or 1, 0.2, Enum.EasingStyle.Back)
							PlayUISound()
						end)
					end

					if type(OptionRenderer) == "function" then
						OptionRenderer(Value, OptionButton, OptioneName, IsSelected)
					end

					OptionButton.Activated:Connect(function()
						Select(Options[Name])
					end)

					if SearchConfig.Enabled and not SkipSearch then
						UpdateSearch()
					end
				end

				RemoveOption = function(Index, Value)
					local Name = GetOptionName(Value, Index)

					if Options[Name] then
						if MultiSelect then
							Selected[Name] = nil
						elseif Selected == Options[Name].Value then
							Selected = nil
						end

						if Options[Name].MoveTween then Options[Name].MoveTween:Cancel() end
						if Options[Name].StarTween then Options[Name].StarTween:Cancel() end
						if Options[Name].ColorTween then Options[Name].ColorTween:Cancel() end
						(Options[Name].Holder or Options[Name].nodes[1]):Destroy()
						table.clear(Options[Name])
						Options[Name] = nil
					end

					UpdateSelected()

					if SearchConfig.Enabled then
						UpdateSearch()
					end
				end

				GetOptions = function()
					return Options
				end

				AddNewOptions = function(List, Clear)
					if type(List) ~= "table" then return end
					local Desired = {}
					local Changed = false
					for Index, Value in pairs(List) do
						Desired[GetOptionName(Value, Index)] = Value
					end
					if Clear then
						local RemoveList = {}
						for Name, Entry in pairs(Options) do
							if Desired[Name] == nil or Desired[Name] ~= Entry.Value then
								RemoveList[#RemoveList + 1] = {Name, Entry.Value}
							end
						end
						for _, Entry in ipairs(RemoveList) do
							RemoveOption(Entry[1], Entry[2])
							Changed = true
						end
					end
					for Index, Value in pairs(List) do
						local Name = GetOptionName(Value, Index)
						if not Options[Name] then
							AddOption(Index, Value, true)
							Changed = true
						end
					end
					if not Changed then return end
					CallbackSelected()
					UpdateSelected()
					if SearchConfig.Enabled then UpdateSearch() end
					CalculateSize()
				end

				for Index, Value in pairs(DOptions) do
					AddOption(Index, Value)
				end

				CallbackSelected()
				UpdateSelected()

				TrackDropdownConnection(SearchInput:GetPropertyChangedSignal("Text"):Connect(UpdateSearch))

				local Dropdown = {}

				if FavoriteEnabled then
					TrackDropdownConnection(Connection.ThemeChanged:Connect(function()
						for _, Entry in pairs(Options) do
							UpdateFavoriteVisual(Entry)
						end
					end))
				end

				TrackDropdownConnection(Connection.LanguageChanged:Connect(function()
					for _, Option in pairs(Options) do
						if Option.nodes and Option.nodes[3] and Option.nodes[3].Parent then
							local TranslatedName = TranslateText(Option.Name)
							SearchNameCache[Option] = TranslatedName:lower()
							if Option.nodes[3].Text ~= TranslatedName then
								Option.nodes[3].Text = TranslatedName
							end
						end
					end

					UpdateSelected()
					if SearchConfig.Enabled then
						UpdateSearch()
					end
				end))

				if UsesGlobalSearch then
					DropdownSearchListeners[Dropdown] = SetSearchEnabled
				end
				if UsesGlobalPrefixOnly then
					DropdownPrefixListeners[Dropdown] = SetPrefixOnly
				end
				if UsesGlobalMaxVisibleOptions then
					DropdownSizeListeners[Dropdown] = function()
						CalculateSize()
						CalculatePos()
					end
				end

				function Dropdown:Visible(Value)
					if Value == nil then Value = not Button.Visible end
					Funcs:ToggleVisible(Button, Value)
					if not Value then HideInstantly() end
				end

				function Dropdown:Destroy()
					if FavoriteEnabled then
						for _, Entry in pairs(Options) do
							if Entry.MoveTween then Entry.MoveTween:Cancel() end
							if Entry.StarTween then Entry.StarTween:Cancel() end
							if Entry.ColorTween then Entry.ColorTween:Cancel() end
						end
					end
					DropdownSearchListeners[self] = nil
					DropdownPrefixListeners[self] = nil
					DropdownSizeListeners[self] = nil

					for _, ConnectionObject in ipairs(DropdownConnections) do
						if ConnectionObject.Connected then
							ConnectionObject:Disconnect()
						end
						UntrackConnection(ConnectionObject)
					end
					table.clear(DropdownConnections)

					NoClickFrame:Destroy()
					Button:Destroy()
				end

				function Dropdown:Callback(...)
					local Added = Funcs:InsertCallback(Callback, ...)
					if type(Added) == "function" then
						Added(Selected)
					end
				end

				function Dropdown:Add(...)
					local NewOptions = {...}

					if #NewOptions == 1 and type(NewOptions[1]) == "table" then
						local Value = NewOptions[1]

						if Value.Player then
							AddOption(Value.Name, Value)
						else
							for Index, Name in pairs(Value) do
								AddOption(Index, Name)
							end
						end
					else
						for _, Name in pairs(NewOptions) do
							AddOption(Name, Name)
						end
					end

					CalculateSize()
					UpdateSelected()

					if SearchConfig.Enabled then
						UpdateSearch()
					end
				end

				function Dropdown:Remove(Option)
					for Index, Value in pairs(GetOptions()) do
						if (type(Option) == "number" and Index == Option)
							or Value.Name == Option
							or Value.Value == Option then
							RemoveOption(Index, Value.Value)
							break
						end
					end
				end

				function Dropdown:Select(Option)
					for _, Value in pairs(GetOptions()) do
						if Value.Name == Option or Value.Value == Option then
							Select(Value)
							break
						end
					end
				end

				function Dropdown:Get()
					return Selected
				end

				function Dropdown:SetTitle(Value)
					LabelFunc:SetTitle(DisplayString(Value))
				end

				function Dropdown:SetDesc(Value)
					LabelFunc:SetDesc(DisplayString(Value))
				end

				function Dropdown:Set(Val1, Clear)
					if type(Val1) == "table" then
						AddNewOptions(Val1, not Clear)
					elseif type(Val1) == "function" then
						Callback = {Val1}
					end
				end

				Button.Activated:Connect(Minimize)
				NoClickFrame.MouseButton1Down:Connect(Disable)
				NoClickFrame.MouseButton1Click:Connect(Disable)
				TrackDropdownConnection(MainFrame:GetPropertyChangedSignal("Visible"):Connect(Disable))
				TrackDropdownConnection(Container:GetPropertyChangedSignal("Visible"):Connect(function()
					if not Container.Visible then HideInstantly() end
				end))
				SelectedFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
					if NoClickFrame.Visible then CalculatePos() end
				end)
				Button.Activated:Connect(CalculateSize)
				local SizeUpdateQueued = false
				local function QueueSizeUpdate()
					if SizeUpdateQueued then return end
					SizeUpdateQueued = true
					task.defer(function()
						SizeUpdateQueued = false
						if ScrollFrame.Parent then CalculateSize() end
					end)
				end
				ScrollFrame.ChildAdded:Connect(QueueSizeUpdate)
				ScrollFrame.ChildRemoved:Connect(QueueSizeUpdate)

				CalculateSize()

				ApplyLocked(Dropdown, Button, Configs, function(IsLocked)
					if IsLocked then
						Disable()
					end
				end)

				Dropdown._OnSectionHidden = HideInstantly
				return RegisterFlagObject(Flag, Dropdown, Button)
			end
		end
		function Tab:AddPlayers(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local PName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.Players)
			local PDesc = Configs.Desc or Configs.Description or ""
			local Display = Configs.Display or false
			local LocalPlayerEnabled = Configs.LocalPlayer ~= false
			local Whitelist = Configs.Whitelist or {}
			local MultiSelect = Configs.MultiSelect or false
			local MultiLine = Configs.MultiLine or false
			local MultiOptions = Configs.MultiOptions or {}
			local Search = Configs.Search
			local Flag = Configs[5] or Configs.Flag or false
			local Callback = Funcs:GetCallback(Configs, 4)

			local PlayerOptions = {}
			local PlayerSearchNames = setmetatable({}, {__mode = "k"})
			local PlayerConnections = {}
			local SelectedPlayers = {}
			local PlayerDropdown

			local function IsWhitelisted(Player)
				if #Whitelist == 0 then
					return false
				end

				for _, Value in pairs(Whitelist) do
					if typeof(Value) == "Instance" and Value:IsA("Player") then
						if Value == Player then
							return true
						end
					elseif type(Value) == "number" then
						if Player.UserId == Value then
							return true
						end
					elseif type(Value) == "string" then
						if Player.Name == Value or Player.DisplayName == Value then
							return true
						end
					elseif type(Value) == "table" then
						if Value.Player == Player
							or Value.UserId == Player.UserId
							or Value.Name == Player.Name
							or Value.DisplayName == Player.DisplayName then
							return true
						end
					end
				end

				return false
			end

			local function GetPlayerText(Player)
				return Display and Player.DisplayName or Player.Name
			end

			local function CreatePlayerData(Player)
				return {
					Player = Player,
					Name = GetPlayerText(Player),
					DisplayName = Player.DisplayName,
					UserName = Player.Name,
					UserId = Player.UserId,
					Thumbnail = ""
				}
			end

			local function GetSearchName(SearchText, Data)
				if type(Data) ~= "table" or not Data.Player then
					return Data and Data.Name or ""
				end

				local Player = Data.Player

				SearchText = tostring(SearchText or "")
				SearchText = SearchText:lower():gsub("^%s*(.-)%s*$", "%1")

				if SearchText == "" then
					return GetPlayerText(Player)
				end

				local Name = Player.Name
				local DisplayName = Player.DisplayName
				local SearchNames = PlayerSearchNames[Data]
				if not SearchNames or SearchNames.Name ~= Name or SearchNames.DisplayName ~= DisplayName then
					SearchNames = {
						Name = Name,
						DisplayName = DisplayName,
						NameLower = Name:lower(),
						DisplayLower = DisplayName:lower()
					}
					PlayerSearchNames[Data] = SearchNames
				end

				local NameMatch = SearchNames.NameLower:sub(1, #SearchText) == SearchText
				local DisplayMatch = SearchNames.DisplayLower:sub(1, #SearchText) == SearchText

				if NameMatch then
					return Name
				end

				if DisplayMatch then
					return DisplayName
				end

				return GetPlayerText(Player)
			end

			local function CreatePlayerDataIfValid(Player)
				if not Player or not Player.Parent then
					return
				end

				if not LocalPlayerEnabled and Player == Players.LocalPlayer then
					return
				end

				if IsWhitelisted(Player) then
					return
				end

				if PlayerOptions[Player] then
					return
				end

				local PlayerData = CreatePlayerData(Player)
				PlayerOptions[Player] = PlayerData

				return PlayerData
			end

			local function CreatePlayerOption(Player)
				local PlayerData = CreatePlayerDataIfValid(Player)

				if PlayerData and PlayerDropdown then
					PlayerDropdown:Add(PlayerData)
				end
			end

			local function RemovePlayerOption(Player)
				local Data = PlayerOptions[Player]

				if not Data then
					return
				end

				if PlayerDropdown then
					PlayerDropdown:Remove(Data.Name)
				end

				PlayerOptions[Player] = nil
				SelectedPlayers[Player] = nil
			end

			local ThumbnailNodes = setmetatable({}, {__mode = "k"})

			PlayerDropdown = Tab:AddDropdown({
				Name = PName,
				Desc = PDesc,
				Options = {},
				MultiSelect = MultiSelect,
				MultiLine = MultiLine,
				MultiOptions = MultiOptions,
				Search = Search,
				Flag = Flag,
				Locked = Configs.Locked,
				LockedMessage = Configs.LockedMessage,
				SearchConfig = Configs.SearchConfig,

				OptionRenderer = function(Value, OptionButton, NameLabel)
					if type(Value) ~= "table" or not Value.Player then
						return
					end

					local OldThumbnail = ThumbnailNodes[OptionButton]

					if OldThumbnail then
						OldThumbnail:Destroy()
					end

					local Thumbnail = Create("ImageLabel", OptionButton, {
						Size = UDim2.fromOffset(17, 17),
						Position = UDim2.new(0, 8, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = Value.Thumbnail or "",
						ImageTransparency = Value.Thumbnail and 0 or 1
					})
					ThumbnailNodes[OptionButton] = Thumbnail

					Make("Corner", Thumbnail, UDim.new(1, 0))

					NameLabel.Position = UDim2.new(0, 30, 0, 0)
					NameLabel.Size = UDim2.new(1, -30, 1, 0)

					if Value.Thumbnail and Value.Thumbnail ~= "" then return end
					task.spawn(function()
						local Success, Content = pcall(function()
							return Players:GetUserThumbnailAsync(
								Value.UserId,
								Enum.ThumbnailType.HeadShot,
								Enum.ThumbnailSize.Size100x100
							)
						end)

						if Success and Content and Thumbnail.Parent then
							Value.Thumbnail = Content
							Thumbnail.Image = Content
							Thumbnail.ImageTransparency = 0
						end
					end)
				end,

				OnSearch = function(SearchText, Value)
					return GetSearchName(SearchText, Value)
				end,

				Callback = function(Value)
					if MultiSelect then
						table.clear(SelectedPlayers)

						if type(Value) == "table" then
							for Name, Selected in pairs(Value) do
								if Selected then
									for Player, Data in pairs(PlayerOptions) do
										if Data.Name == Name
											or Data.UserName == Name
											or Data.DisplayName == Name then
											SelectedPlayers[Player] = true
											break
										end
									end
								end
							end
						end

						local Result = {}

						for Player in pairs(SelectedPlayers) do
							table.insert(Result, Player)
						end

						Funcs:FireCallback(Callback, Result)
					else
						local SelectedPlayer

						if typeof(Value) == "Instance" and Value:IsA("Player") then
							SelectedPlayer = Value
						elseif type(Value) == "table" and Value.Player then
							SelectedPlayer = Value.Player
						end

						Funcs:FireCallback(Callback, SelectedPlayer)
					end
				end
			})

			local InitialPlayers = {}

			for _, Player in ipairs(Players:GetPlayers()) do
				local PlayerData = CreatePlayerDataIfValid(Player)

				if PlayerData then
					table.insert(InitialPlayers, PlayerData)
				end
			end

			if #InitialPlayers > 0 then
				PlayerDropdown:Set(InitialPlayers, true)
			end

			PlayerConnections.PlayerAdded = TrackConnection(Players.PlayerAdded:Connect(function(Player)
				CreatePlayerOption(Player)
			end))

			PlayerConnections.PlayerRemoving = TrackConnection(Players.PlayerRemoving:Connect(function(Player)
				RemovePlayerOption(Player)
			end))

			local PlayersElement = {}

			function PlayersElement:Get()
				if MultiSelect then
					local Result = {}

					for Player in pairs(SelectedPlayers) do
						table.insert(Result, Player)
					end

					return Result
				end

				local Selected = PlayerDropdown:Get()

				if typeof(Selected) == "Instance" and Selected:IsA("Player") then
					return Selected
				end

				if type(Selected) == "table" and Selected.Player then
					return Selected.Player
				end

				for Player, Data in pairs(PlayerOptions) do
					if Data.Name == Selected
						or Data.UserName == Selected
						or Data.DisplayName == Selected then
						return Player
					end
				end

				return nil
			end

			function PlayersElement:Select(Player)
				if typeof(Player) ~= "Instance" or not Player:IsA("Player") then
					return
				end

				local Data = PlayerOptions[Player]

				if Data then
					PlayerDropdown:Select(Data.Name)
				end
			end

			function PlayersElement:Add(Player)
				if typeof(Player) == "Instance" and Player:IsA("Player") then
					CreatePlayerOption(Player)
				end
			end

			function PlayersElement:Remove(Player)
				if typeof(Player) == "Instance" and Player:IsA("Player") then
					RemovePlayerOption(Player)
				end
			end

			function PlayersElement:Callback(Func)
				Funcs:InsertCallback(Callback, Func)
			end
			function PlayersElement:SetTitle(Value)
				if PlayerDropdown then PlayerDropdown:SetTitle(DisplayString(Value)) end
			end
			function PlayersElement:SetDesc(Value)
				if PlayerDropdown then PlayerDropdown:SetDesc(DisplayString(Value)) end
			end

			function PlayersElement:Visible(...)
				PlayerDropdown:Visible(...)
			end

			function PlayersElement:SetLocked(...)
				return PlayerDropdown:SetLocked(...)
			end

			function PlayersElement:Lock(...)
				return PlayerDropdown:Lock(...)
			end

			function PlayersElement:Unlock(...)
				return PlayerDropdown:Unlock(...)
			end

			function PlayersElement:IsLocked()
				return PlayerDropdown:IsLocked()
			end

			function PlayersElement:SetLockedMessage(...)
				return PlayerDropdown:SetLockedMessage(...)
			end

			function PlayersElement:GetLockedMessage()
				return PlayerDropdown:GetLockedMessage()
			end

			function PlayersElement:Destroy()
				for _, Connection in pairs(PlayerConnections) do
					if Connection then
						Connection:Disconnect()
						UntrackConnection(Connection)
					end
				end

				table.clear(PlayerConnections)
				table.clear(PlayerOptions)
				table.clear(SelectedPlayers)

				if PlayerDropdown then
					PlayerDropdown:Destroy()
					PlayerDropdown = nil
				end
			end

			return RegisterFlagObject(Flag, PlayersElement, FlagObjectHolders[PlayerDropdown])
		end
		function Tab:AddSelector(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local SName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.Selector)
			local SDesc = Configs.Desc or Configs.Description or ""
			local Options = Configs[2] or Configs.Options
			local SOptions = type(Options) == "table" and table.clone(Options) or {}
			local SDefault = FirstDefined(Configs[3], Configs.Default, 1)
			local Callback = Funcs:GetCallback(Configs, 4)
			local Flag = Configs[5] or Configs.Flag or false
			local Wrap = Configs.Wrap == true or Configs.Loop == true
			
			local HoverCorner = 3

			local Button, LabelFunc = ButtonFrame(ElementParent, SName, SDesc, UDim2.new(1, -180), false)

			local SelectedFrame = InsertTheme(Create("Frame", Button, {
				Size = UDim2.new(0, 150, 0, 22),
				Position = UDim2.new(1, -10, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme["Color Stroke"]
			}), "Stroke")

			Make("Corner", SelectedFrame, UDim.new(0, 5))

			local LeftButton = Create("TextButton", SelectedFrame, {
				Size = UDim2.fromOffset(24, 22),
				Position = UDim2.new(0, 1, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = ""
			})

			local LeftHover = InsertTheme(Create("Frame", LeftButton, {
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme["Color Theme"],
				BackgroundTransparency = 1
			}), "Theme")

			Make("Corner", LeftHover, UDim.new(0, HoverCorner))

			local LeftArrow = InsertTheme(Create("ImageLabel", LeftButton, {
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://10709791281",
				ImageColor3 = Theme["Color Text"]
			}), "Theme")

			local RightButton = Create("TextButton", SelectedFrame, {
				Size = UDim2.fromOffset(24, 22),
				Position = UDim2.new(1, -1, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = ""
			})

			local RightHover = InsertTheme(Create("Frame", RightButton, {
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Theme["Color Theme"],
				BackgroundTransparency = 1
			}), "Theme")

			Make("Corner", RightHover, UDim.new(0, HoverCorner))

			local RightArrow = InsertTheme(Create("ImageLabel", RightButton, {
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "rbxassetid://10709791437",
				ImageColor3 = Theme["Color Text"]
			}), "Theme")

			local ActiveLabel = InsertTheme(Create("TextLabel", SelectedFrame, {
				Size = UDim2.new(1, -58, 1, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = Theme["Color Text"],
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				Text = "..."
			}), "Text")

			local Selector = {}
			local Destroyed = false
			local Index = 0
			local CanPrevious, CanNext = false, false

			local function OptionText(Option)
				if type(Option) == "table" then
					return tostring(FirstDefined(Option.Name, Option.DisplayName, Option.Label, Option.Value, Option))
				end
				return tostring(Option)
			end

			local function FindOption(Value)
				for i, Option in ipairs(SOptions) do
					if Option == Value or (type(Value) == "string" and (tostring(Option) == Value or OptionText(Option) == Value)) then
						return i
					end
					if type(Option) == "table" and type(Value) == "table" then
						local OptionKey = FirstDefined(Option.Value, Option.Name, Option.DisplayName, Option.Label)
						local ValueKey = FirstDefined(Value.Value, Value.Name, Value.DisplayName, Value.Label)
						if OptionKey ~= nil and OptionKey == ValueKey then
							return i
						end
					end
				end
				return nil
			end

			local function ValidIndex(Value)
				if type(Value) ~= "number" or Value ~= Value or Value == math.huge or Value == -math.huge then
					return nil
				end
				return math.floor(Value)
			end

			local SavedValue = GetFlag(Flag)
			if SavedValue ~= nil then
				Index = FindOption(SavedValue) or 0
				if Index == 0 then
					local SavedIndex = ValidIndex(SavedValue)
					if SavedIndex and SavedIndex >= 1 and SavedIndex <= #SOptions then
						Index = SavedIndex
					end
				end
			end

			if Index == 0 and #SOptions > 0 then
				local DefaultIndex = ValidIndex(SDefault)
				Index = DefaultIndex and math.clamp(DefaultIndex, 1, #SOptions) or FindOption(SDefault) or 1
			end

			local function Update()
				if Destroyed then
					return
				end

				local Count = #SOptions
				if Index > 0 and Index <= Count then
					ActiveLabel.Text = string.format("%s (%d/%d)", TranslateText(OptionText(SOptions[Index])), Index, Count)
				else
					ActiveLabel.Text = "... (0/0)"
				end

				CanPrevious = Count > 1 and (Wrap or Index > 1)
				CanNext = Count > 1 and (Wrap or Index < Count)
				LeftArrow.ImageTransparency = CanPrevious and 0 or 0.6
				RightArrow.ImageTransparency = CanNext and 0 or 0.6
				LeftButton.Selectable = CanPrevious
				RightButton.Selectable = CanNext
				if not CanPrevious then LeftHover.BackgroundTransparency = 1 end
				if not CanNext then RightHover.BackgroundTransparency = 1 end
			end

			local function NotifyChange(OldIndex, OldValue, Silent, IncludeIndex)
				Update()
				local Value = SOptions[Index]
				if OldValue ~= Value or (IncludeIndex and OldIndex ~= Index) then
					SetFlag(Flag, Value)
					if not Silent then
						Funcs:FireCallback(Callback, Value)
					end
				end
			end

			local function Select(NewIndex, Silent)
				NewIndex = ValidIndex(NewIndex)
				if Destroyed or not NewIndex or NewIndex < 1 or NewIndex > #SOptions or NewIndex == Index then
					return false
				end

				local OldIndex, OldValue = Index, SOptions[Index]
				Index = NewIndex
				NotifyChange(OldIndex, OldValue, Silent, true)
				return true
			end

			local function Move(Step)
				if Destroyed or #SOptions < 2 then
					return false
				end

				local NextIndex = Index + Step
				if Wrap then
					NextIndex = (NextIndex - 1) % #SOptions + 1
				end
				return Select(NextIndex)
			end

			LeftButton.MouseEnter:Connect(function()
				if CanPrevious and not Selector.Locked then
					LeftHover.BackgroundTransparency = 0.55
				end
			end)
			LeftButton.MouseLeave:Connect(function()
				LeftHover.BackgroundTransparency = 1
			end)
			RightButton.MouseEnter:Connect(function()
				if CanNext and not Selector.Locked then
					RightHover.BackgroundTransparency = 0.55
				end
			end)
			RightButton.MouseLeave:Connect(function()
				RightHover.BackgroundTransparency = 1
			end)

			LeftButton.Activated:Connect(function()
				if not Selector.Locked and Move(-1) then
					PlayUISound()
				end
			end)
			RightButton.Activated:Connect(function()
				if not Selector.Locked and Move(1) then
					PlayUISound()
				end
			end)

			Update()
			if Index > 0 then
				SetFlag(Flag, SOptions[Index])
			end

			local SelectorLanguageConnection = Connection.LanguageChanged:Connect(Update)
			local function Cleanup()
				if Destroyed then return end
				Destroyed = true
				if SelectorLanguageConnection and SelectorLanguageConnection.Connected then
					SelectorLanguageConnection:Disconnect()
				end
			end
			Button.Destroying:Connect(Cleanup)

			function Selector:Set(Value, Silent)
				if type(Value) == "number" then
					return Select(Value, Silent)
				end
				return Select(FindOption(Value), Silent)
			end

			function Selector:SelectValue(Value, Silent)
				for i, Option in ipairs(SOptions) do
					if Option == Value then
						return Select(i, Silent)
					end
				end
				return false
			end

			function Selector:Get()
				return SOptions[Index]
			end

			function Selector:GetIndex()
				return Index
			end

			function Selector:GetOptions()
				return table.clone(SOptions)
			end

			function Selector:SetOptions(Options, Silent)
				if Destroyed or type(Options) ~= "table" then
					return false
				end

				local OldIndex, OldValue = Index, SOptions[Index]
				SOptions = table.clone(Options)
				if #SOptions == 0 then
					Index = 0
				else
					local RestoredIndex = OldIndex == 0 and CheckFlag(Flag) and FindOption(GetFlag(Flag))
					Index = (OldIndex > 0 and FindOption(OldValue)) or RestoredIndex or math.clamp(math.max(OldIndex, 1), 1, #SOptions)
				end
				NotifyChange(OldIndex, OldValue, Silent)
				return true
			end

			function Selector:Add(Option, Silent)
				if Destroyed or Option == nil then
					return false
				end

				table.insert(SOptions, Option)
				if Index == 0 then
					Index = 1
					NotifyChange(0, nil, Silent)
				else
					Update()
				end
				return true
			end

			function Selector:Remove(Value, Silent)
				if Destroyed then return false end
				local OptionIndex = type(Value) == "number" and ValidIndex(Value) or FindOption(Value)
				if not OptionIndex or OptionIndex < 1 or OptionIndex > #SOptions then
					return false
				end

				local OldIndex, OldValue = Index, SOptions[Index]
				table.remove(SOptions, OptionIndex)
				if #SOptions == 0 then
					Index = 0
				elseif OptionIndex < Index then
					Index = Index - 1
				elseif Index > #SOptions then
					Index = #SOptions
				end
				NotifyChange(OldIndex, OldValue, Silent)
				return true
			end

			function Selector:Next()
				return Move(1)
			end

			function Selector:Previous()
				return Move(-1)
			end

			function Selector:SetTitle(Value)
				LabelFunc:SetTitle(DisplayString(Value))
			end

			function Selector:SetDesc(Value)
				LabelFunc:SetDesc(DisplayString(Value))
			end

			function Selector:Callback(Func)
				Funcs:InsertCallback(Callback, Func)
			end

			function Selector:Visible(...)
				if not Destroyed then Funcs:ToggleVisible(Button, ...) end
			end

			function Selector:Destroy()
				if Destroyed then return end
				Cleanup()
				Button:Destroy()
			end

			ApplyLocked(Selector, Button, Configs)
			return RegisterFlagObject(Flag, Selector, Button)
		end

		function Tab:AddProgressBar(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local Range = type(Configs.Value) == "table" and Configs.Value or {}

			local function Finite(Input)
				local Number = tonumber(Input)
				if not Number or Number ~= Number or math.abs(Number) == math.huge then return nil end
				return Number
			end

			local Min = Finite(Range.Min) or Finite(Configs.Min) or 0
			local Max = Finite(Range.Max) or Finite(Configs.Max) or 100
			if Min > Max then Min, Max = Max, Min end

			local Default = (type(Configs.Value) == "number" and Finite(Configs.Value))
				or Finite(Range.Default) or Finite(Configs.Default) or Min
			local Flag = NormalizeObjectFlag(Configs.Flag)
			local SavedValue = CheckFlag(Flag) and Finite(GetFlag(Flag)) or nil
			local Value = math.clamp(SavedValue or Default, Min, Max)
			local Indeterminate = Configs.Indeterminate == true
			local IndeterminateText = tostring(Configs.IndeterminateText or "")
			local ShowValue = Configs.ShowValue
			if ShowValue == nil then ShowValue = not Indeterminate or IndeterminateText ~= "" end
			ShowValue = ShowValue == true

			local Callback = Funcs:GetCallback(Configs, 3)
			local CompleteCallbacks = {}
			local ResetCallbacks = {}
			local MilestoneCallbacks = {}
			if type(Configs.OnComplete) == "function" then table.insert(CompleteCallbacks, Configs.OnComplete) end
			if type(Configs.OnReset) == "function" then table.insert(ResetCallbacks, Configs.OnReset) end
			if type(Configs.OnMilestone) == "function" then table.insert(MilestoneCallbacks, Configs.OnMilestone) end

			local Milestones = {}
			if type(Configs.Milestones) == "table" then
				for _, Entry in ipairs(Configs.Milestones) do
					local Threshold = Finite(Entry)
					if Threshold and Threshold >= 0 and Threshold <= 100 and not table.find(Milestones, Threshold) then
						table.insert(Milestones, Threshold)
					end
				end
				table.sort(Milestones)
			end

			local Width = math.max(Finite(Configs.Width) or 160, 0)
			local ValueWidth = math.max(Finite(Configs.ValueWidth) or 44, 0)
			local ControlGap = math.max(Finite(Configs.ControlGap) or 16, 0)
			local ControlWidth = Width + (ShowValue and ValueWidth + 8 or 0)
			local Title = Configs[1] or Configs.Name or Configs.Title or "ProgressBar"
			local Desc = Configs.Desc or Configs.Description or ""

			local Frame, LabelFunc = ButtonFrame(
				ElementParent, Title, Desc,
				UDim2.new(1, -(ControlWidth + ControlGap + ElementHorizontalPadding)), false
			)
			local Holder = Create("Frame", Frame, {
				Size = UDim2.fromOffset(ControlWidth, 24),
				Position = UDim2.new(1, -ElementHorizontalPadding, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0
			})
			local Track = InsertTheme(Create("Frame", Holder, {
				Size = UDim2.fromOffset(Width, 6),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme["Color Stroke"],
				BorderSizePixel = 0,
				ClipsDescendants = true
			}), "Stroke")
			Make("Corner", Track, UDim.new(1, 0))

			local Fill = InsertTheme(Create("Frame", Track, {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme["Color Theme"],
				BorderSizePixel = 0
			}), "Theme")
			Make("Corner", Fill, UDim.new(1, 0))

			local ValueLabel = InsertTheme(Create("TextLabel", Holder, {
				Size = UDim2.fromOffset(ValueWidth, 20),
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				TextColor3 = Theme["Color Text"],
				TextTransparency = 0.15,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = "",
				Visible = ShowValue
			}), "Text")

			local ProgressBar = {
				__type = "ProgressBar",
				Value = {Min = Min, Max = Max, Default = Value},
				Indeterminate = Indeterminate,
				IndeterminateText = IndeterminateText,
				ShowValue = ShowValue,
				DisplayMode = Configs.DisplayMode or "Percent",
				Format = Configs.Format,
				Animate = Configs.Animate ~= false,
				AnimationDuration = math.max(Finite(Configs.AnimationDuration) or 0.15, 0),
				Speed = math.max(Finite(Configs.Speed) or 1, 0.01),
				Paused = false,
				Locked = Configs.Locked == true,
				UIElements = {Container = Holder, Bar = Track, Fill = Fill, Value = ValueLabel}
			}
			local Destroyed = false
			local ValueTween
			local LoopTween
			local VisibilityConnection
			local FrameVisibilityConnection
			local FlagConnection

			local function GetRatio(Number)
				if Max == Min then return Number >= Max and 1 or 0 end
				return math.clamp((Number - Min) / (Max - Min), 0, 1)
			end

			local function FormatNumber(Number)
				if Number % 1 == 0 then return tostring(Number) end
				return tostring(tonumber(string.format("%.2f", Number)))
			end

			local function FormatValue(Number, Percentage)
				if Indeterminate then return ProgressBar.IndeterminateText end
				if type(ProgressBar.Format) == "function" then
					local Success, Result = pcall(ProgressBar.Format, Number, Percentage, Min, Max)
					if Success and Result ~= nil then return tostring(Result) end
				end
				if ProgressBar.DisplayMode == "Value" then
					return FormatNumber(Number)
				elseif ProgressBar.DisplayMode == "Fraction" then
					return FormatNumber(Number) .. "/" .. FormatNumber(Max)
				end
				return tostring(math.floor(Percentage + 0.5)) .. "%"
			end

			local function StopValueTween()
				if ValueTween then
					ValueTween:Cancel()
					ValueTween:Destroy()
					ValueTween = nil
				end
			end

			local function StopLoop()
				if LoopTween then
					LoopTween:Cancel()
					LoopTween:Destroy()
					LoopTween = nil
				end
			end

			local function SyncLoop()
				if Destroyed or not Indeterminate then return end
				if not LoopTween then
					Fill.Size = UDim2.fromScale(0.35, 1)
					Fill.Position = UDim2.fromScale(-0.35, 0)
					LoopTween = TweenService:Create(Fill,
						TweenInfo.new(1 / ProgressBar.Speed, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
						{Position = UDim2.fromScale(1, 0)})
				end
				if ProgressBar.Paused or ProgressBar.Locked or not Frame.Visible or not Container.Visible then
					LoopTween:Pause()
				else
					LoopTween:Play()
				end
			end

			local function Refresh(Instant)
				if Destroyed then return end
				local Fraction = GetRatio(Value)
				ValueLabel.Text = FormatValue(Value, Fraction * 100)
				if Indeterminate then return end

				StopValueTween()
				local Target = UDim2.fromScale(Fraction, 1)
				if not Instant and ProgressBar.Animate and ProgressBar.AnimationDuration > 0 then
					ValueTween = TweenService:Create(Fill,
						TweenInfo.new(ProgressBar.AnimationDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
						{Size = Target})
					ValueTween:Play()
				else
					Fill.Size = Target
				end
			end

			local function SetValue(NewValue, Silent, Instant)
				if Destroyed then return Value end
				local Number = Finite(NewValue)
				if not Number then return Value end
				Number = math.clamp(Number, Min, Max)
				if Number == Value then return Value end

				local Previous = Value
				local PreviousPercentage = GetRatio(Previous) * 100
				Value = Number
				ProgressBar.Value.Default = Value
				Refresh(Instant)
				SetFlag(Flag, Value)

				if not Silent then
					local Percentage = GetRatio(Value) * 100
					Funcs:FireCallback(Callback, Value, Percentage)
					for _, Threshold in ipairs(Milestones) do
						if PreviousPercentage < Threshold and Percentage >= Threshold then
							Funcs:FireCallback(MilestoneCallbacks, Threshold, Value)
						end
					end
					if Previous < Max and Value >= Max then
						Funcs:FireCallback(CompleteCallbacks, Value)
					end
					if Previous > Min and Value <= Min then
						Funcs:FireCallback(ResetCallbacks, Value)
					end
				end
				return Value
			end

			function ProgressBar:Set(NewValue, Silent)
				return SetValue(NewValue, Silent == true)
			end
			ProgressBar.SetValue = ProgressBar.Set

			function ProgressBar:Get()
				return Value
			end
			function ProgressBar:GetPercentage()
				return GetRatio(Value) * 100
			end
			function ProgressBar:IsComplete()
				return Value >= Max
			end
			function ProgressBar:IsIndeterminate()
				return Indeterminate
			end
			function ProgressBar:SetPercentage(Percentage, Silent)
				local Number = Finite(Percentage)
				if not Number then return Value end
				return SetValue(Min + (Max - Min) * math.clamp(Number / 100, 0, 1), Silent == true)
			end
			function ProgressBar:Increment(Amount, Silent)
				local Number = Finite(Amount)
				if not Number then return Value end
				return SetValue(Value + Number, Silent == true)
			end
			ProgressBar.Add = ProgressBar.Increment

			function ProgressBar:Reset(Silent)
				return SetValue(Min, Silent == true)
			end
			function ProgressBar:Complete(Silent)
				if Indeterminate then self:SetIndeterminate(false) end
				return SetValue(Max, Silent == true)
			end
			function ProgressBar:SetRange(NewMin, NewMax)
				NewMin, NewMax = Finite(NewMin), Finite(NewMax)
				if not NewMin or not NewMax then return Min, Max end
				if NewMin > NewMax then NewMin, NewMax = NewMax, NewMin end
				if Min == NewMin and Max == NewMax then return Min, Max end
				Min, Max = NewMin, NewMax
				ProgressBar.Value.Min, ProgressBar.Value.Max = Min, Max
				local Clamped = math.clamp(Value, Min, Max)
				if Clamped ~= Value then
					SetValue(Clamped)
				else
					Refresh(true)
				end
				return Min, Max
			end
			function ProgressBar:SetMin(NewMin)
				NewMin = Finite(NewMin)
				if not NewMin then return Min end
				self:SetRange(NewMin, math.max(NewMin, Max))
				return Min
			end
			function ProgressBar:SetMax(NewMax)
				NewMax = Finite(NewMax)
				if not NewMax then return Max end
				self:SetRange(math.min(Min, NewMax), NewMax)
				return Max
			end

			function ProgressBar:SetIndeterminate(Enabled)
				if Destroyed or type(Enabled) ~= "boolean" or Indeterminate == Enabled then return Indeterminate end
				Indeterminate = Enabled
				self.Indeterminate = Enabled
				StopValueTween()
				if Indeterminate then
					SyncLoop()
				else
					StopLoop()
					Fill.Position = UDim2.fromScale(0, 0)
				end
				Refresh(true)
				return Indeterminate
			end
			function ProgressBar:SetIndeterminateText(Text)
				self.IndeterminateText = tostring(Text or "")
				Refresh(true)
			end
			function ProgressBar:SetSpeed(NewSpeed)
				local Number = Finite(NewSpeed)
				if not Number or Number <= 0 then return self.Speed end
				self.Speed = Number
				if Indeterminate then
					StopLoop()
					SyncLoop()
				end
				return self.Speed
			end
			function ProgressBar:Pause()
				self.Paused = true
				if LoopTween then LoopTween:Pause() end
			end
			function ProgressBar:Resume()
				self.Paused = false
				SyncLoop()
			end
			function ProgressBar:SetDisplayMode(Mode)
				if type(Mode) ~= "string" then return end
				self.DisplayMode = Mode
				Refresh(true)
			end
			function ProgressBar:SetFormat(Formatter)
				if Formatter ~= nil and type(Formatter) ~= "function" then return end
				self.Format = Formatter
				Refresh(true)
			end
			function ProgressBar:SetAnimation(Enabled, Duration)
				if type(Enabled) == "boolean" then self.Animate = Enabled end
				local Number = Finite(Duration)
				if Number and Number >= 0 then self.AnimationDuration = Number end
				if not self.Animate then Refresh(true) end
			end
			function ProgressBar:SetTitle(NewTitle)
				LabelFunc:SetTitle(DisplayString(NewTitle))
			end
			function ProgressBar:SetDesc(NewDesc)
				LabelFunc:SetDesc(DisplayString(NewDesc))
			end
			function ProgressBar:Callback(Func)
				Funcs:InsertCallback(Callback, Func)
			end
			function ProgressBar:OnComplete(Func)
				Funcs:InsertCallback(CompleteCallbacks, Func)
			end
			function ProgressBar:OnReset(Func)
				Funcs:InsertCallback(ResetCallbacks, Func)
			end
			function ProgressBar:OnMilestone(Func)
				Funcs:InsertCallback(MilestoneCallbacks, Func)
			end
			function ProgressBar:Visible(...)
				if not Destroyed then Funcs:ToggleVisible(Frame, ...) end
			end
			function ProgressBar:Destroy()
				if not Destroyed then Frame:Destroy() end
			end

			VisibilityConnection = Container:GetPropertyChangedSignal("Visible"):Connect(SyncLoop)
			FrameVisibilityConnection = Frame:GetPropertyChangedSignal("Visible"):Connect(SyncLoop)
			if Flag then
				FlagConnection = Connection.FlagsChanged:Connect(function(Name, NewValue)
					if Destroyed or Name ~= Flag or GetFlag(Flag) ~= NewValue then return end
					local Number = Finite(NewValue)
					if Number then SetValue(Number, true) end
				end)
			end

			Frame.Destroying:Connect(function()
				Destroyed = true
				StopValueTween()
				StopLoop()
				VisibilityConnection:Disconnect()
				FrameVisibilityConnection:Disconnect()
				if FlagConnection then FlagConnection:Disconnect() end
			end)

			Refresh(true)
			if Indeterminate then SyncLoop() end
			SetFlag(Flag, Value)
			if Configs.FireOnInit == true then
				Funcs:FireCallback(Callback, Value, GetRatio(Value) * 100)
				if Value >= Max then Funcs:FireCallback(CompleteCallbacks, Value) end
			end
			ApplyLocked(ProgressBar, Frame, Configs, SyncLoop)
			return RegisterFlagObject(Flag, ProgressBar, Frame)
		end
		function Tab:AddSlider(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local SName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.Slider)
			local SDesc = Configs.Desc or Configs.Description or ""
			local function Finite(Input, Fallback)
				local Number = tonumber(Input)
				return Number and Number == Number and math.abs(Number) < math.huge and Number or Fallback
			end
			local Min = Finite(Configs[2] or Configs.MinValue or Configs.Min, ControlsConfig.Slider.Min)
			local Max = Finite(Configs[3] or Configs.MaxValue or Configs.Max, ControlsConfig.Slider.Max)
			if Min > Max then Min, Max = Max, Min end
			local Step = math.abs(Finite(Configs[4] or Configs.Increase, ControlsConfig.Slider.Step))
			if Step <= 0 then Step = 1 end
			local Callback = Funcs:GetCallback(Configs, 6)
			local LiveUpdate = FirstDefined(Configs.LiveUpdate, Configs.UpdateOnDrag, Configs.UpdateWhileDragging, true) ~= false
			local Editable = Configs.Editable == true
			local Flag = Configs[7] or Configs.Flag or false
			local Default = Configs[5] or Configs.Default or ControlsConfig.Slider.Default
			if CheckFlag(Flag) then Default = GetFlag(Flag) end

			local Button, LabelFunc = ButtonFrame(ElementParent, SName, SDesc, UDim2.new(0.58, -28, 0, 0), false)
			local SliderHolder = Create("Frame", Button, {
				Name = "SliderHolder", Size = UDim2.new(0.42, 0, 1, 0),
				Position = UDim2.new(1, -12, 0, 0), AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1, BorderSizePixel = 0
			})
			-- The editor owns its entire surface. Its padding can never start a drag.
			local ValueBackground = InsertTheme(Create(Editable and "TextButton" or "Frame", SliderHolder, {
				Name = "ValueBackground", Size = UDim2.fromOffset(36, 22),
				Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme["Color Stroke"], BackgroundTransparency = 1,
				BorderSizePixel = 0, ClipsDescendants = true
			}), "Stroke")
			Make("Corner", ValueBackground, UDim.new(0, 6))
			if Editable then ValueBackground.Text = "" ValueBackground.AutoButtonColor = false end
			local LabelVal = InsertTheme(Create(Editable and "TextBox" or "TextLabel", ValueBackground, {
				Name = "SliderValue", Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0),
				BackgroundTransparency = 1, Text = "", TextColor3 = Theme["Color Text"],
				Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = false, ClipsDescendants = true, BorderSizePixel = 0
			}), "Text")
			if Editable then
				LabelVal.ClearTextOnFocus = true
				LabelVal.MultiLine = false
				LabelVal.TextEditable = true
			end
			local DragTarget = Create("TextButton", SliderHolder, {
				Name = "SliderHitbox", Size = UDim2.new(1, -44, 1, 0),
				BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0
			})
			local SliderBar = InsertTheme(Create("Frame", DragTarget, {
				Name = "SliderBar", Size = UDim2.new(1, -10, 0, 4), Position = UDim2.new(0, 5, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme["Color Stroke"], BorderSizePixel = 0
			}), "Stroke")
			Make("Corner", SliderBar)
			local Indicator = InsertTheme(Create("Frame", SliderBar, {
				Name = "SliderFill", BackgroundColor3 = Theme["Color Theme"],
				Size = UDim2.fromScale(0, 1), BorderSizePixel = 0
			}), "Theme")
			Make("Corner", Indicator)
			local SliderIcon = Create("Frame", SliderBar, {
				Name = "SliderThumb", Size = UDim2.fromOffset(7, 14), BackgroundColor3 = ControlColors.Light,
				Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 0.12, BorderSizePixel = 0
			})
			Make("Corner", SliderIcon)

			local Value
			local Destroyed, Editing, WritingValue, Dragging = false, false, false, false
			local Hovering, ValueHovering = false, false
			local ActiveInput, DragStartValue, WasScrolling
			local MoveConnection, EndConnection, FocusConnection, EditInputConnection
			local Connections, Tweens = {}, {}
			local MotionInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local StyleInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local function Connect(Signal, Handler)
				local Connection = Signal:Connect(Handler)
				table.insert(Connections, Connection)
				return Connection
			end
			local function StopTween(Key)
				if Tweens[Key] then Tweens[Key]:Cancel() Tweens[Key] = nil end
			end
			local function Animate(Key, Object, Info, Properties)
				StopTween(Key)
				if Destroyed then return end
				local Tween = TweenService:Create(Object, Info, Properties)
				Tweens[Key] = Tween
				Tween:Play()
			end
			local function CanInteract()
				if Destroyed or not Button.Interactable or not Button.Visible or not Container.Visible or not Containers.Visible or not MainFrame.Visible then return false end
				local Parent = Button.Parent
				while Parent and Parent ~= Container do
					if Parent:IsA("GuiObject") and not Parent.Visible then return false end
					Parent = Parent.Parent
				end
				return true
			end
			local function RefreshInteraction()
				if Destroyed then return end
				local Enabled = CanInteract()
				local Active = Enabled and (Hovering or Dragging)
				Animate("ThumbStyle", SliderIcon, StyleInfo, {
					Size = Dragging and UDim2.fromOffset(8, 16) or UDim2.fromOffset(7, 14),
					BackgroundTransparency = Active and 0 or 0.12
				})
				if Editable then
					Animate("EditorStyle", ValueBackground, StyleInfo, {
						BackgroundTransparency = Enabled and (Editing and 0.35 or ValueHovering and 0.65 or 1) or 1
					})
				end
			end
			local function RefreshValue(Immediate)
				if Destroyed or Value == nil then return end
				if not Editing then
					WritingValue = true
					LabelVal.Text = string.format("%.15g", Value)
					WritingValue = false
				end
				local Fraction = Max == Min and 0 or math.clamp((Value - Min) / (Max - Min), 0, 1)
				if Immediate or Dragging then
					StopTween("Position") StopTween("Fill")
					SliderIcon.Position = UDim2.fromScale(Fraction, 0.5)
					Indicator.Size = UDim2.fromScale(Fraction, 1)
				else
					Animate("Position", SliderIcon, MotionInfo, {Position = UDim2.fromScale(Fraction, 0.5)})
					Animate("Fill", Indicator, MotionInfo, {Size = UDim2.fromScale(Fraction, 1)})
				end
			end
			-- Measure committed values only; typing must never resize the track.
			local ValueWidth = 36
			for _, Probe in ipairs({Min, Max, math.clamp(Min + Step, Min, Max), math.clamp(Max - Step, Min, Max)}) do
				ValueWidth = math.max(ValueWidth, math.ceil(TextService:GetTextSize(string.format("%.15g", Probe), 11, Enum.Font.GothamBold, Vector2.new(1000, 22)).X) + 12)
			end
			ValueWidth = math.min(ValueWidth, 80)
			ValueBackground.Size = UDim2.fromOffset(ValueWidth, 22)
			DragTarget.Size = UDim2.new(1, -(ValueWidth + 8), 1, 0)
			local function RefreshLayout()
				if Destroyed then return end
				local Width = Button.AbsoluteSize.X / math.max(UIScale, 0.01)
				if Width <= 0 then return end
				local ControlWidth = math.min(math.clamp(Width * 0.42, ValueWidth + 38, 220), math.max(ValueWidth, Width - 48))
				SliderHolder.Size = UDim2.new(0, ControlWidth, 1, 0)
				DragTarget.Visible = ControlWidth >= ValueWidth + 28
				LabelFunc:SetReservedWidth(ControlWidth + 24 + ElementHorizontalPadding)
			end
			local function SetValue(Input, Silent, Force)
				if Destroyed then return false end
				local Number = Finite(Input)
				if not Number then return false end
				Number = math.clamp(Number, Min, Max)
				if Number ~= Max then Number = math.clamp(Min + math.floor((Number - Min) / Step + 0.5) * Step, Min, Max) end
				Number = math.clamp(tonumber(string.format("%.15g", Number)), Min, Max)
				local Changed = Value ~= Number
				Value = Number
				RefreshValue(Force)
				if Changed or Force then
					SetFlag(Flag, Number)
					if not Silent then Funcs:FireCallback(Callback, Number) end
				end
				return true
			end
			local function EndEdit(Commit)
				if not Editing then return end
				Editing = false
				if EditInputConnection then EditInputConnection:Disconnect() EditInputConnection = nil end
				local Draft = LabelVal.Text
				if LabelVal:IsFocused() then LabelVal:ReleaseFocus() end
				if Commit and CanInteract() and Draft ~= "" then
					local Number = tonumber(Draft)
					if Number then SetValue(math.clamp(Number, Min, Max)) end
				end
				RefreshValue()
				RefreshInteraction()
			end
			local function FinishDrag(Commit)
				if not Dragging then return end
				Dragging = false
				ActiveInput = nil
				if MoveConnection then MoveConnection:Disconnect() MoveConnection = nil end
				if EndConnection then EndConnection:Disconnect() EndConnection = nil end
				if FocusConnection then FocusConnection:Disconnect() FocusConnection = nil end
				Container.ScrollingEnabled = WasScrolling
				local Changed = Value ~= DragStartValue
				DragStartValue = nil
				RefreshInteraction()
				if Commit and Changed and not LiveUpdate and not Destroyed then Funcs:FireCallback(Callback, Value) end
			end
			local function UpdateFromPosition(ScreenX)
				local Width = SliderBar.AbsoluteSize.X
				if Width <= 0 then return end
				local Fraction = math.clamp((ScreenX - SliderBar.AbsolutePosition.X) / Width, 0, 1)
				SetValue(Fraction == 1 and Max or Min + (Max - Min) * Fraction, not LiveUpdate)
			end
			local function BeginDrag(Input)
				if Dragging or not CanInteract() or not DragTarget.Visible then return end
				local InputType = Input.UserInputType
				if InputType ~= Enum.UserInputType.MouseButton1 and InputType ~= Enum.UserInputType.Touch then return end
				EndEdit(true)
				if not CanInteract() or not DragTarget.Visible then return end
				Dragging = true
				ActiveInput, DragStartValue, WasScrolling = Input, Value, Container.ScrollingEnabled
				Container.ScrollingEnabled = false
				RefreshInteraction()
				UpdateFromPosition(Input.Position.X)
				if Destroyed or not Dragging then return end
				MoveConnection = UserInputService.InputChanged:Connect(function(Changed)
					if not Dragging then return end
					if InputType == Enum.UserInputType.Touch then
						if Changed ~= ActiveInput then return end
					elseif Changed.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					UpdateFromPosition(Changed.Position.X)
				end)
				EndConnection = UserInputService.InputEnded:Connect(function(Ended)
					if InputType == Enum.UserInputType.Touch then
						if Ended ~= ActiveInput then return end
					elseif Ended.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					UpdateFromPosition(Ended.Position.X)
					FinishDrag(true)
				end)
				FocusConnection = UserInputService.WindowFocusReleased:Connect(function() FinishDrag(false) end)
			end
			if Editable then
				Connect(ValueBackground.Activated, function()
					if CanInteract() and not Editing then LabelVal:CaptureFocus() end
				end)
				Connect(LabelVal.Focused, function()
					if Destroyed then return end
					if not CanInteract() then LabelVal:ReleaseFocus() RefreshValue(true) return end
					FinishDrag(true)
					if Destroyed then return end
					if not CanInteract() then LabelVal:ReleaseFocus() RefreshValue(true) return end
					Editing = true
					WritingValue = true
					LabelVal.Text = ""
					WritingValue = false
					RefreshInteraction()
					EditInputConnection = UserInputService.InputBegan:Connect(function(Input)
						if Destroyed or not Editing then return end
						if Input.KeyCode == Enum.KeyCode.Return or Input.KeyCode == Enum.KeyCode.KeypadEnter then
							EndEdit(true)
						elseif Input.KeyCode == Enum.KeyCode.Escape then EndEdit(false)
						elseif Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
							local Point, Position, Size = Input.Position, ValueBackground.AbsolutePosition, ValueBackground.AbsoluteSize
							if Point.X < Position.X or Point.X > Position.X + Size.X or Point.Y < Position.Y or Point.Y > Position.Y + Size.Y then EndEdit(true) end
						end
					end)
				end)
				Connect(LabelVal.FocusLost, function() EndEdit(true) end)
				Connect(LabelVal:GetPropertyChangedSignal("Text"), function()
					if Destroyed or WritingValue or not Editing then return end
					local Text, Cursor = LabelVal.Text, LabelVal.CursorPosition
					local Clean = Text:gsub("[^0-9]", ""):sub(1, 64)
					if Clean == Text then return end
					local BeforeCursor = Text:sub(1, math.max(0, Cursor - 1)):gsub("[^0-9]", "")
					WritingValue = true
					LabelVal.Text = Clean
					if Cursor > 0 then LabelVal.CursorPosition = math.min(#BeforeCursor, #Clean) + 1 end
					WritingValue = false
				end)
				Connect(ValueBackground.MouseEnter, function() ValueHovering = true RefreshInteraction() end)
				Connect(ValueBackground.MouseLeave, function() ValueHovering = false RefreshInteraction() end)
			end
			Connect(DragTarget.MouseEnter, function() Hovering = true RefreshInteraction() end)
			Connect(DragTarget.MouseLeave, function() Hovering = false RefreshInteraction() end)
			Connect(DragTarget.InputBegan, BeginDrag)
			local function StopInteraction()
				FinishDrag(false)
				EndEdit(false)
				Hovering, ValueHovering = false, false
				RefreshInteraction()
			end
			Connect(Button:GetPropertyChangedSignal("Visible"), function() if not Button.Visible then StopInteraction() end end)
			Connect(Container:GetPropertyChangedSignal("Visible"), function() if not Container.Visible then StopInteraction() end end)
			Connect(Containers:GetPropertyChangedSignal("Visible"), function() if not Containers.Visible then StopInteraction() end end)
			Connect(MainFrame:GetPropertyChangedSignal("Visible"), function() if not MainFrame.Visible then StopInteraction() end end)
			local Ancestor = Button.Parent
			while Ancestor and Ancestor ~= Container do
				if Ancestor:IsA("GuiObject") then
					local Surface = Ancestor
					Connect(Surface:GetPropertyChangedSignal("Visible"), function() if not Surface.Visible then StopInteraction() end end)
				end
				Ancestor = Ancestor.Parent
			end
			Connect(Button:GetPropertyChangedSignal("AbsoluteSize"), RefreshLayout)
			Connect(ScreenScale:GetPropertyChangedSignal("Scale"), RefreshLayout)
			local function Cleanup()
				if Destroyed then return end
				StopInteraction()
				Destroyed = true
				for Key in pairs(Tweens) do StopTween(Key) end
				for _, Connection in ipairs(Connections) do Connection:Disconnect() end
			end
			Connect(Button.Destroying, Cleanup)
			local Slider = {_OnSectionHidden = StopInteraction}
			function Slider:Set(Val1, Val2)
				if type(Val1) == "string" then
					LabelFunc:SetTitle(Val1)
					if type(Val2) == "string" then LabelFunc:SetDesc(Val2) end
				elseif type(Val1) == "function" then Callback = {Val1}
				elseif type(Val1) == "number" then SetValue(Val1) end
			end
			function Slider:SetTitle(Title) LabelFunc:SetTitle(DisplayString(Title)) end
			function Slider:SetDesc(Desc) LabelFunc:SetDesc(DisplayString(Desc)) end
			function Slider:Get() return Value end
			function Slider:SetValue(NewValue, Silent) return SetValue(NewValue, Silent == true) end
			function Slider:Callback(...)
				local Added = Funcs:InsertCallback(Callback, ...)
				if type(Added) == "function" then Added(Value) end
			end
			function Slider:Visible(...) Funcs:ToggleVisible(Button, ...) end
			function Slider:Destroy() Cleanup() Button:Destroy() end
			RefreshLayout()
			if not SetValue(Default, false, true) then SetValue(Min, false, true) end
			if Destroyed then return Slider end
			ApplyLocked(Slider, Button, Configs, function(IsLocked)
				if IsLocked then StopInteraction() end
				if Editable then LabelVal.TextEditable = not IsLocked end
			end)
			return RegisterFlagObject(Flag, Slider, Button)
		end
		function Tab:AddTextBox(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local TName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.TextBox)
			local TDesc = Configs.Desc or Configs.Description or ""
			local TDefault = FirstDefined(Configs[2], Configs.Default, ControlsConfig.TextBox.Default)
			local Flag = Configs.Flag
			if CheckFlag(Flag) then TDefault = GetFlag(Flag) end
			local TPlaceholderText = TranslateText(tostring(Configs[5] or Configs.PlaceholderText or ControlsConfig.TextBox.Placeholder))
			local TClearText = FirstDefined(Configs[3], Configs.ClearText, ControlsConfig.TextBox.ClearText)
			local Callback = Funcs:GetCallback(Configs, 4)
			local Mod = Configs.Mod

			if type(TDefault) ~= "string" then TDefault = DisplayString(TDefault) end

			local Button, LabelFunc = ButtonFrame(ElementParent, TName, TDesc, UDim2.new(1, -38), false)

			local SelectedFrame = InsertTheme(Create("Frame", Button, {
				Size = UDim2.new(0, 150, 0, 18),
				Position = UDim2.new(1, -10, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme["Color Stroke"]
			}), "Stroke")

			Make("Corner", SelectedFrame, UDim.new(0, 4))

			local TextBoxInput = InsertTheme(Create("TextBox", SelectedFrame, {
				Size = UDim2.new(0.85, 0, 0.85, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
				TextColor3 = Theme["Color Text"],
				ClearTextOnFocus = TClearText,
				PlaceholderText = TPlaceholderText,
				Text = ""
			}), "Text")

			local Pencil = Create("ImageLabel", SelectedFrame, {
				Size = UDim2.new(0, 12, 0, 12),
				Position = UDim2.new(0, -5, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				Image = "rbxassetid://15637081879",
				BackgroundTransparency = 1
			})

			local TextBox = {}
			TextBox.OnChanging = false

			local function ApplyMod(Text)
				if type(Mod) == "function" then
					local Result = Mod(Text)

					if type(Result) == "string" then
						return Result
					end

					return Text
				end

				if type(Mod) ~= "table" then
					return Text
				end

				local Space = Mod.Space ~= false
				local Number = Mod.Number ~= false
				local Letter = Mod.Letter ~= false
				local Symbol = Mod.Symbol == true
				local Result = {}

				for i = 1, #Text do
					local Character = Text:sub(i, i)

					if Character:match("%a") then
						if Letter then
							Result[#Result + 1] = Character
						end
					elseif Character:match("%d") then
						if Number then
							Result[#Result + 1] = Character
						end
					elseif Character == " " then
						if Space then
							Result[#Result + 1] = Character
						end
					else
						if Symbol then
							Result[#Result + 1] = Character
						end
					end
				end

				return table.concat(Result)
			end

			local Changing = false
			local LastSubmitted = ""

			local function Input(Silent)
				if not Button.Interactable then return end
				local Text = ApplyMod(TextBoxInput.Text)
				if type(TextBox.OnChanging) == "function" then
					local Changed = TextBox.OnChanging(Text)
					if type(Changed) == "string" then Text = Changed end
				end
				if TextBoxInput.Text ~= Text then TextBoxInput.Text = Text end
				if LastSubmitted == Text then return end
				LastSubmitted = Text
				SetFlag(Flag, Text)
				if not Silent then Funcs:FireCallback(Callback, Text) end
			end

			TextBoxInput:GetPropertyChangedSignal("Text"):Connect(function()
				if Changing then
					return
				end

				if Mod == nil then
					return
				end

				local Text = TextBoxInput.Text
				local NewText = ApplyMod(Text)

				if Text ~= NewText then
					Changing = true
					TextBoxInput.Text = NewText
					Changing = false
				end
			end)

			TextBoxInput.FocusLost:Connect(function() Input() end)
			TextBoxInput.Text = ApplyMod(TDefault)
			Input(Configs.FireOnInit == false)

			TextBoxInput.FocusLost:Connect(function()
				CreateTween({
					Pencil,
					"ImageColor3",
					ControlColors.White,
					0.2
				})
			end)

			TextBoxInput.Focused:Connect(function()
				CreateTween({
					Pencil,
					"ImageColor3",
					Theme["Color Theme"],
					0.2
				})
			end)

			function TextBox:Get()
				return TextBoxInput.Text
			end

			function TextBox:GetPlaceholder()
				return TextBoxInput.PlaceholderText
			end

			function TextBox:Set(Text, Silent)
				if type(Text) ~= "string" then
					return
				end

				TextBoxInput.Text = Text
				Input(Silent == true)
			end

			function TextBox:SetPlaceholder(Text)
				if type(Text) ~= "string" then
					return
				end

				TextBoxInput.PlaceholderText = TranslateText(Text)
			end

			function TextBox:SetTitle(Value)
				LabelFunc:SetTitle(DisplayString(Value))
			end

			function TextBox:SetDesc(Value)
				LabelFunc:SetDesc(DisplayString(Value))
			end

			function TextBox:Callback(Func)
				Funcs:InsertCallback(Callback, Func)
			end

			function TextBox:Mod(NewMod)
				Mod = NewMod
			end

			function TextBox:Visible(...)
				Funcs:ToggleVisible(Button, ...)
			end

			function TextBox:Destroy()
				Button:Destroy()
			end

			ApplyLocked(TextBox, Button, Configs)
			return RegisterFlagObject(Flag, TextBox, Button)
		end

		function Tab:AddTextArea(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local Title = Configs[1] or Configs.Name or Configs.Title or "TextArea"
			local Description = Configs.Desc or Configs.Description or ""
			local Flag = NormalizeObjectFlag(Configs.Flag)
			local Default = FirstDefined(Configs[2], Configs.Default, ControlsConfig.TextBox.Default, "")
			if CheckFlag(Flag) then Default = GetFlag(Flag) end
			if type(Default) ~= "string" then Default = DisplayString(Default) end
			local Placeholder = Configs[5] or Configs.PlaceholderText or ControlsConfig.TextBox.Placeholder or ""
			local ClearOnFocus = FirstDefined(Configs[3], Configs.ClearText, false) == true
			local Callback = Funcs:GetCallback(Configs, 4)
			local Mod = Configs.Mod
			local ReadOnly = Configs.ReadOnly == true or Configs.TextEditable == false
			local Height = math.clamp(tonumber(Configs.Height) or 96, 64, 360)
			local MinHeight = math.clamp(tonumber(Configs.MinHeight) or 64, 48, Height)
			local AutoResize = Configs.AutoResize ~= false
			local TextSize = math.clamp(tonumber(Configs.TextSize) or 12, 10, 28)
			local function NormalizeMaxLength(Value)
				if Value == nil or Value == false then return nil end
				local Number = tonumber(Value)
				if not Number or Number ~= Number or Number < 0 or Number == math.huge then return nil end
				return math.floor(Number)
			end
			local MaxLength = NormalizeMaxLength(Configs.MaxLength)
			local EditorPadding = 20
			local CounterPadding = 16
			local Destroyed = false
			local Connections = {}

			local function Track(Signal, Handler)
				local Connection = Signal:Connect(Handler)
				Connections[#Connections + 1] = Connection
				return Connection
			end

			local Frame = ComponentSurface(Create("Frame", ElementParent, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme["Color Hub 2"],
				BorderSizePixel = 0
			}))
			Make("Corner", Frame, UDim.new(0, ElementCornerRadius))
			local Content = Create("Frame", Frame, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0
			})
			Create("UIPadding", Content, {
				PaddingLeft = UDim.new(0, ElementHorizontalPadding),
				PaddingRight = UDim.new(0, ElementHorizontalPadding),
				PaddingTop = UDim.new(0, ElementVerticalPadding),
				PaddingBottom = UDim.new(0, ElementVerticalPadding)
			})
			Create("UIListLayout", Content, {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, math.max(ElementSpacing, 11))
			})

			local Header = Create("Frame", Content, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1
			})
			Create("UIListLayout", Header, {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ElementSpacing)
			})

			local TitleLabel = InsertTheme(Create("TextLabel", Header, {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = ElementTitleTextSize,
				TextColor3 = Theme["Color Text"],
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = TranslateText(DisplayString(Title))
			}), "Text")

			local DescLabel = InsertTheme(Create("TextLabel", Header, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = ElementDescriptionTextSize,
				TextColor3 = Color3.fromRGB(180, 180, 188),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = "",
				Visible = false
			}), "DescriptionText")

			local Editor = InputSurface(Create("Frame", Content, {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, Height),
				BorderSizePixel = 0,
				ClipsDescendants = true
			}))
			Make("Corner", Editor, UDim.new(0, 5))

			local Scroll = InsertTheme(Create("ScrollingFrame", Editor, {
				Size = UDim2.new(1, -24, 1, -(EditorPadding + (MaxLength and CounterPadding or 0))),
				Position = UDim2.fromOffset(12, 10),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.None,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollingEnabled = false,
				Active = true,
				ScrollBarThickness = 0,
				ScrollBarImageColor3 = Theme["Color Theme"],
				ScrollBarImageTransparency = 0.48
			}), "ScrollBar")

			local Input = InsertTheme(Create("TextBox", Scroll, {
				Size = UDim2.new(1, -3, 0, Height - EditorPadding),
				AutomaticSize = Enum.AutomaticSize.None,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				MultiLine = true,
				TextWrapped = true,
				TextScaled = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Font = Enum.Font.Gotham,
				TextSize = TextSize,
				TextColor3 = Theme["Color Text"],
				PlaceholderColor3 = Theme["Color Dark Text"],
				PlaceholderText = TranslateText(DisplayString(Placeholder)),
				ClearTextOnFocus = ClearOnFocus,
				TextEditable = not ReadOnly,
				Text = ""
			}), "Text")

			local Counter = Create("TextLabel", Editor, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -4),
				Size = UDim2.new(1, -24, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				TextColor3 = Theme["Color Dark Text"],
				Text = "",
				Visible = MaxLength ~= nil
			})

			local LineHeight = TextService:GetTextSize("Mg", TextSize, Input.Font, Vector2.new(1000, 1000)).Y

			local TextArea = {OnChanging = false}
			local Changing = false
			local LastSubmitted
			local Hovering = false
			local SavedTabScroll
			-- Touch devices retain native scrolling even when a keyboard is present.
			local ManualWheel = UserInputService.MouseEnabled and not UserInputService.TouchEnabled
			local Overflow = false
			local LastContentHeight = 0
			local CaretScheduled = false

			local function EffectiveScale()
				return math.max(0.01, ScreenScale.Scale)
			end

			local function CountCharacters(Text)
				return utf8.len(Text) or #Text
			end

			local function EnforceMaxLength(Text)
				if MaxLength == nil or CountCharacters(Text) <= MaxLength then return Text end
				local Offset = utf8.offset(Text, MaxLength + 1)
				return Text:sub(1, (Offset or MaxLength + 1) - 1)
			end

			local function UpdateCounter()
				Counter.Visible = MaxLength ~= nil
				if MaxLength == nil then return end
				local Count = CountCharacters(Input.Text)
				Counter.Text = string.format("%d/%d", Count, MaxLength)
				Counter.TextColor3 = Count >= MaxLength and Theme["Color Theme"] or Theme["Color Dark Text"]
			end

			local function MeasureText(Text)
				local Width = Input.AbsoluteSize.X / EffectiveScale()
				if Width < 1 then return end
				return TextService:GetTextSize(Text, TextSize, Input.Font, Vector2.new(math.floor(Width), 100000)).Y
			end

			local function MaxScroll()
				return math.max(0, Scroll.AbsoluteCanvasSize.Y - Scroll.AbsoluteWindowSize.Y)
			end

			local function ClampScroll(Value)
				return Vector2.new(0, math.clamp(Value, 0, MaxScroll()))
			end

			local function UpdateScrollOwnership()
				local Capture = not Destroyed and Hovering and Overflow and Frame.Visible and Container.Visible
				if Capture and SavedTabScroll == nil then
					SavedTabScroll = Container.ScrollingEnabled
					Container.ScrollingEnabled = false
				elseif not Capture and SavedTabScroll ~= nil then
					Container.ScrollingEnabled = SavedTabScroll
					SavedTabScroll = nil
				end
			end

			local function UpdateCanvas()
				if Destroyed then return end
				UpdateCounter()
				local Padding = EditorPadding + (MaxLength and CounterPadding or 0)
				if Scroll.Size.Y.Offset ~= -Padding then
					Scroll.Size = UDim2.new(1, -24, 1, -Padding)
				end
				local Text = Input.Text
				local Measured = Text == "" and " " or Text
				if Measured:sub(-1) == "\n" then Measured ..= " " end
				local RealHeight = MeasureText(Measured)
				if not RealHeight then return end
				local Lines = select(2, Text:gsub("\n", "")) + 1
				local ContentHeight = math.max(math.ceil(RealHeight), Lines * LineHeight) + 6
				local TargetHeight = AutoResize and math.clamp(ContentHeight + Padding, MinHeight, Height) or Height
				if Editor.Size.Y.Offset ~= TargetHeight then
					Editor.Size = UDim2.new(1, 0, 0, TargetHeight)
				end
				local ViewHeight = TargetHeight - Padding
				LastContentHeight = ContentHeight
				Overflow = ContentHeight > ViewHeight + 2
				local CanvasHeight = math.max(ViewHeight, ContentHeight)
				if Input.Size.Y.Offset ~= CanvasHeight then
					Input.Size = UDim2.new(1, -3, 0, CanvasHeight)
				end
				Scroll.CanvasSize = UDim2.fromOffset(0, CanvasHeight)
				Scroll.ScrollBarThickness = Overflow and 2 or 0
				Scroll.ScrollingEnabled = Overflow and not (ManualWheel and Input:IsFocused())
				if not Overflow then
					Scroll.CanvasPosition = Vector2.zero
				else
					Scroll.CanvasPosition = ClampScroll(Scroll.CanvasPosition.Y)
				end
				UpdateScrollOwnership()
			end

			local function KeepCaretVisible()
				if Destroyed or not Overflow or not Input:IsFocused() then return end
				local Cursor = Input.CursorPosition
				if Cursor < 1 then return end
				local Prefix = Input.Text:sub(1, Cursor - 1)
				if Prefix == "" or Prefix:sub(-1) == "\n" then Prefix ..= " " end
				local RealHeight = MeasureText(Prefix)
				if not RealHeight then return end
				local Scale = EffectiveScale()
				local CaretBottom = math.min(LastContentHeight * Scale, RealHeight * Scale)
				local Top = Scroll.CanvasPosition.Y
				local ViewHeight = math.max(1, Scroll.AbsoluteWindowSize.Y)
				local Margin = 6 * Scale
				if CaretBottom > Top + ViewHeight - Margin then
					Scroll.CanvasPosition = ClampScroll(CaretBottom - ViewHeight + Margin)
				elseif CaretBottom < Top + TextSize * Scale then
					Scroll.CanvasPosition = ClampScroll(CaretBottom - (TextSize + 4) * Scale)
				end
			end

			local function ScheduleCaretFollow()
				if Destroyed or CaretScheduled then return end
				CaretScheduled = true
				task.defer(function()
					CaretScheduled = false
					if not Destroyed then KeepCaretVisible() end
				end)
			end

			local function Refresh()
				UpdateCanvas()
				ScheduleCaretFollow()
			end

			local function SetDescription(Value)
				local Text = DisplayString(Value)
				DescLabel.Text = TranslateText(Text)
				DescLabel.Visible = Text:match("%S") ~= nil
			end

			local function ApplyMod(Text)
				if type(Mod) == "function" then
					local Result = Mod(Text)
					return type(Result) == "string" and Result or Text
				end
				if type(Mod) ~= "table" then return Text end

				local Space = Mod.Space ~= false
				local Number = Mod.Number ~= false
				local Letter = Mod.Letter ~= false
				local Symbol = Mod.Symbol == true
				local Result = table.create(#Text)
				for Index = 1, #Text do
					local Character = Text:sub(Index, Index)
					local Allowed
					if Character == "\n" or Character == "\r" then
						Allowed = true
					elseif Character == " " or Character == "\t" then
						Allowed = Space
					elseif Character:match("%a") then
						Allowed = Letter
					elseif Character:match("%d") then
						Allowed = Number
					else
						Allowed = Symbol
					end
					if Allowed then Result[#Result + 1] = Character end
				end
				return table.concat(Result)
			end

			local function SetInput(Text)
				Text = EnforceMaxLength(Text)
				if Input.Text == Text then return Text end
				local Cursor = Input.CursorPosition
				local Selection = Input.SelectionStart
				Changing = true
				Input.Text = Text
				local CursorLimit = CountCharacters(Text) + 1
				if Cursor > 0 then Input.CursorPosition = math.min(Cursor, CursorLimit) end
				if Selection > 0 then Input.SelectionStart = math.min(Selection, CursorLimit) end
				Changing = false
				Refresh()
				return Text
			end

			local function Submit(Silent)
				if Destroyed then return end
				local Text = ApplyMod(Input.Text)
				if type(TextArea.OnChanging) == "function" and not Silent then
					local Changed = TextArea.OnChanging(Text)
					if type(Changed) == "string" then Text = Changed end
				end
				Text = SetInput(Text)
				if LastSubmitted == Text then return end
				LastSubmitted = Text
				SetFlag(Flag, Text)
				if not Silent then Funcs:FireCallback(Callback, Text) end
			end

			Track(Input:GetPropertyChangedSignal("Text"), function()
				if Destroyed or Changing then return end
				local NewText = Input.Text
				if Mod ~= nil then NewText = ApplyMod(NewText) end
				NewText = EnforceMaxLength(NewText)
				if NewText ~= Input.Text then SetInput(NewText) end
				Refresh()
			end)
			Track(Input:GetPropertyChangedSignal("CursorPosition"), ScheduleCaretFollow)
			Track(Scroll:GetPropertyChangedSignal("AbsoluteSize"), Refresh)
			Track(Scroll:GetPropertyChangedSignal("AbsoluteWindowSize"), Refresh)
			Track(Scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
				if not Overflow then return end
				Scroll.CanvasPosition = ClampScroll(Scroll.CanvasPosition.Y)
				ScheduleCaretFollow()
			end)
			Track(ScreenScale:GetPropertyChangedSignal("Scale"), Refresh)
			Track(Container:GetPropertyChangedSignal("Visible"), function()
				UpdateScrollOwnership()
				if Container.Visible then Refresh() end
			end)
			Track(Frame:GetPropertyChangedSignal("Visible"), UpdateScrollOwnership)

			Track(Editor.MouseEnter, function()
				Hovering = true
				UpdateScrollOwnership()
			end)
			Track(Editor.MouseLeave, function()
				Hovering = false
				UpdateScrollOwnership()
			end)

			Track(UserInputService.InputChanged, function(InputObject)
				if Destroyed or not ManualWheel or not Hovering or not Overflow
					or InputObject.UserInputType ~= Enum.UserInputType.MouseWheel
					or not Input:IsFocused() then return end
				local Movement = InputObject.Position.Z
				if Movement == 0 then return end
				Scroll.CanvasPosition = ClampScroll(
					Scroll.CanvasPosition.Y - Movement * math.max(TextSize * 3, 30) * EffectiveScale()
				)
			end)

			Track(Input.Focused, function()
				if Destroyed then return end
				Refresh()
			end)
			Track(Input.FocusLost, function()
				if Destroyed then return end
				Scroll.ScrollingEnabled = Overflow
				if not TextArea.Locked then Submit(false) end
			end)

			SetDescription(Description)
			SetInput(ApplyMod(Default))
			UpdateCanvas()
			Submit(false)

			function TextArea:Get()
				return Input.Text
			end
			function TextArea:GetPlaceholder()
				return Input.PlaceholderText
			end
			function TextArea:Set(Text)
				if type(Text) ~= "string" or Destroyed then return end
				SetInput(ApplyMod(Text))
				Submit(false)
			end
			function TextArea:Clear()
				self:Set("")
			end
			function TextArea:SetPlaceholder(Text)
				if type(Text) == "string" and not Destroyed then
					Input.PlaceholderText = TranslateText(Text)
				end
			end
			function TextArea:SetTitle(Value)
				if not Destroyed then TitleLabel.Text = TranslateText(DisplayString(Value)) end
			end
			function TextArea:SetDesc(Value)
				if not Destroyed then SetDescription(Value) end
			end
			function TextArea:SetHeight(Value)
				local NewHeight = tonumber(Value)
				if not NewHeight or NewHeight ~= NewHeight or math.abs(NewHeight) == math.huge or Destroyed then return end
				Height = math.clamp(NewHeight, 64, 360)
				MinHeight = math.min(MinHeight, Height)
				Refresh()
			end
			function TextArea:GetHeight()
				return Editor.Size.Y.Offset
			end
			function TextArea:GetTextLength()
				return CountCharacters(Input.Text)
			end
			function TextArea:GetMaxLength()
				return MaxLength
			end
			function TextArea:SetMaxLength(Value)
				if Destroyed then return end
				if Value ~= nil and Value ~= false and NormalizeMaxLength(Value) == nil then return end
				local NewLength = NormalizeMaxLength(Value)
				if MaxLength == NewLength then return end
				MaxLength = NewLength
				local OldText = Input.Text
				SetInput(OldText)
				Refresh()
				if Input.Text ~= OldText and not Input:IsFocused() then Submit(false) end
			end
			function TextArea:SetAutoResize(Enabled)
				if Destroyed or type(Enabled) ~= "boolean" then return end
				AutoResize = Enabled
				Refresh()
			end
			function TextArea:Focus()
				if not Destroyed and not self.Locked and Input.TextEditable then Input:CaptureFocus() end
			end
			function TextArea:Callback(Func)
				Funcs:InsertCallback(Callback, Func)
			end
			function TextArea:Mod(NewMod)
				Mod = NewMod
				SetInput(ApplyMod(Input.Text))
			end
			function TextArea:Visible(...)
				if not Destroyed then
					Funcs:ToggleVisible(Frame, ...)
					UpdateScrollOwnership()
					if Frame.Visible then Refresh() end
				end
			end
			function TextArea:Destroy()
				if not Destroyed then Frame:Destroy() end
			end

			if Flag then
				Track(Connection.FlagsChanged, function(Name, Value)
					if Destroyed or Name ~= Flag or type(Value) ~= "string" or GetFlag(Flag) ~= Value then return end
					if Input:IsFocused() or Input.Text == Value then return end
					local Limited = SetInput(Value)
					LastSubmitted = Limited
					if Limited ~= Value then SetFlag(Flag, Limited) end
				end)
			end
			Track(Connection.ThemeChanged, function()
				if Destroyed then return end
				Input.PlaceholderColor3 = Theme["Color Dark Text"]
				UpdateCounter()
			end)
			Track(Frame.Destroying, function()
				Hovering = false
				UpdateScrollOwnership()
				Destroyed = true
				for _, Connection in ipairs(Connections) do
					Connection:Disconnect()
				end
				table.clear(Connections)
			end)

			ApplyLocked(TextArea, Frame, Configs, function(Locked)
				Input.TextEditable = not Locked and not ReadOnly
			end)
			return RegisterFlagObject(Flag, TextArea, Frame)
		end
		function Tab:AddKeybind(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			if not UserInputService.KeyboardEnabled then return end
			local KName = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.Keybind)
			local KDesc = Configs.Desc or Configs.Description or ""
			local DefaultValue = Configs.Default
			local KDefault = Configs.Value or Configs.Key or Configs.Keybind or Configs[2]
			if KDefault == nil and (type(DefaultValue) == "string" or typeof(DefaultValue) == "EnumItem") then
				KDefault = DefaultValue
			end
			KDefault = KDefault or Enum.KeyCode.LeftShift
			local Toggle = Configs.Toggle ~= false
			local Enabled = Toggle and (Configs.Enabled == true or Configs.State == true or DefaultValue == true) or false
			local Callback = Funcs:GetCallback(Configs, 3)
			local Keybind = {}
			local Binding
			local Button, LabelFunc = ButtonFrame(ElementParent, KName, KDesc, UDim2.new(1, -38), false)

			local function SetState(State, Fire)
				if not Binding or Binding.Destroyed or not Toggle or type(State) ~= "boolean" then return false end
				Enabled = State
				Binding:Refresh()
				if Fire then Funcs:FireCallback(Callback, Enabled) end
				return true
			end

			ApplyLocked(Keybind, Button, Configs, function(IsLocked)
				if IsLocked and Binding then Binding:SetWaiting(false) end
			end)
			Binding = CreateKeybindControl(Keybind, Button, LabelFunc, Configs, {
				InitialKey = ResolveBindingKey(KDefault) or Enum.KeyCode.LeftShift,
				IsActive = function() return Toggle and Enabled end,
				OnChanged = Configs.OnChanged,
				OnTriggered = function()
					if Toggle then SetState(not Enabled, true) else Funcs:FireCallback(Callback, true) end
				end
			})
			if not Binding.CurrentKey and not Binding:SetKey(Enum.KeyCode.LeftShift, false) then
				for _, Key in ipairs(Enum.KeyCode:GetEnumItems()) do
					if Binding:SetKey(Key, false) then break end
				end
			end

			function Keybind:Set(Value)
				if Binding.Destroyed then return end
				if Toggle and type(Value) == "boolean" then
					SetState(Value, true)
				elseif type(Value) == "string" then
					LabelFunc:SetTitle(Value)
				end
			end
			function Keybind:Get()
				if Toggle then return Enabled end
				return nil
			end
			function Keybind:SetKeybind(Key)
				return Binding:SetKey(Key, false)
			end
			function Keybind:GetKeybind() return Binding.CurrentKey end
			function Keybind:SetTitle(Value) LabelFunc:SetTitle(DisplayString(Value)) end
			function Keybind:SetDesc(Value) LabelFunc:SetDesc(DisplayString(Value)) end
			function Keybind:Callback(Func) Funcs:InsertCallback(Callback, Func) end
			function Keybind:Visible(...) Funcs:ToggleVisible(Button, ...) end
			function Keybind:Destroy()
				if Binding.Destroyed then return end
				Binding:Destroy()
				Button:Destroy()
			end
			return RegisterFlagObject(Configs.Flag, Keybind, Button)
		end
		function Tab:AddColorPicker(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local ColorPicker = {}
			local ColorConnections = {}

			local function TrackColorConnection(ConnectionObject)
				ColorConnections[#ColorConnections + 1] = ConnectionObject
				return ConnectionObject
			end

			local Name = Configs[1] or Configs.Name or Configs.Title or TranslateText(ControlsConfig.Titles.ColorPicker)
			local Description = Configs.Desc or Configs.Description or ""
			local Callback = Funcs:GetCallback(Configs, 3)
			local LiveUpdate = FirstDefined(Configs.LiveUpdate, Configs.UpdateOnDrag, Configs.UpdateWhileDragging, true) ~= false
			local Flag = Configs[4] or Configs.Flag or false
			local MaxRecent = math.clamp(math.floor(tonumber(Configs.MaxRecent) or ControlsConfig.ColorPicker.MaxRecent), 0, 32)
			local SmoothTime = math.clamp(tonumber(Configs.SmoothTime) or ColorPickerSmoothTime, 0, 0.2)

			local DisplayMode = Configs.DisplayMode or Configs.Display or ControlsConfig.ColorPicker.Display
			local DisplayString = tostring(DisplayMode):lower():gsub("%s+", "")

			local ShowHex = DisplayString:find("hex", 1, true) ~= nil
			local ShowRGB = DisplayString:find("rgb", 1, true) ~= nil

			if not ShowHex and not ShowRGB then
				ShowHex = true
			end

			local function ParseHex(Value)
				if typeof(Value) ~= "string" then
					return nil
				end

				local Hex = Value:gsub("^#", ""):gsub("%s+", ""):upper()

				if #Hex == 3 then
					Hex = Hex:sub(1, 1):rep(2)
						.. Hex:sub(2, 2):rep(2)
						.. Hex:sub(3, 3):rep(2)
				end

				if #Hex ~= 6 or not Hex:match("^[%x]+$") then
					return nil
				end

				local R = tonumber(Hex:sub(1, 2), 16)
				local G = tonumber(Hex:sub(3, 4), 16)
				local B = tonumber(Hex:sub(5, 6), 16)

				if not R or not G or not B then
					return nil
				end

				return Color3.fromRGB(R, G, B)
			end

			local function ColorToHex(Color)
				return string.format(
					"#%02X%02X%02X",
					math.floor(Color.R * 255 + 0.5),
					math.floor(Color.G * 255 + 0.5),
					math.floor(Color.B * 255 + 0.5)
				)
			end

			local function ColorToRGB(Color)
				return string.format(
					"%d,%d,%d",
					math.floor(Color.R * 255 + 0.5),
					math.floor(Color.G * 255 + 0.5),
					math.floor(Color.B * 255 + 0.5)
				)
			end

			local function ParseRGB(Value)
				if typeof(Value) ~= "string" then
					return nil
				end

				local R, G, B = Value:match("^(%d+),(%d+),(%d+)$")
				R, G, B = tonumber(R), tonumber(G), tonumber(B)

				if not R or not G or not B then
					return nil
				end

				if R > 255 or G > 255 or B > 255 then
					return nil
				end

				return Color3.fromRGB(R, G, B)
			end

			local function ParseBrickColor(Value)
				if typeof(Value) == "BrickColor" then
					return Value.Color, Value.Name
				end

				if typeof(Value) ~= "string" then
					return nil
				end

				local Success, BrickColorValue = pcall(BrickColor.new, Value)

				if not Success or not BrickColorValue then
					return nil
				end

				if BrickColorValue.Name:lower() ~= Value:lower() then
					return nil
				end

				return BrickColorValue.Color, BrickColorValue.Name
			end

			local function ParseColor(Value)
				if typeof(Value) == "Color3" then
					return Value, "Color3"
				end

				if typeof(Value) == "BrickColor" then
					return Value.Color, "BrickColor"
				end

				if typeof(Value) == "string" then
					local HexColor = ParseHex(Value)

					if HexColor then
						return HexColor, "Color3"
					end

					local BrickColorValue, BrickColorName = ParseBrickColor(Value)

					if BrickColorValue then
						return BrickColorValue, "BrickColorName"
					end
				end

				return nil, nil
			end

			local Default = Configs[2] or Configs.Default or ControlsConfig.ColorPicker.Default
			local CurrentColor, DefaultFormat = ParseColor(Default)

			if not CurrentColor then
				CurrentColor = assert(ParseColor(ControlsConfig.ColorPicker.Default), "Config.Library.Controls.ColorPicker.Default is invalid.")
			end

			if Flag and CheckFlag(Flag) then
				local SavedColor = GetFlag(Flag)

				if typeof(SavedColor) == "string" then
					local ParsedSavedColor = ParseHex(SavedColor)

					if ParsedSavedColor then
						CurrentColor = ParsedSavedColor
					end
				end
			end

			local ReturnFormat =
				Configs.ReturnFormat
				or Configs.Format
				or Configs.OutputFormat
				or (Configs[2] == nil and Configs.Default == nil and ControlsConfig.ColorPicker.ReturnFormat)
				or DefaultFormat
				or ControlsConfig.ColorPicker.ReturnFormat

			local ReturnFormatString = tostring(ReturnFormat):lower():gsub("%s+", "")
			local OutputFormat = "Color3"

			if ReturnFormatString:find("brickcolorname", 1, true)
				or ReturnFormatString == "name"
				or ReturnFormatString:find("nomedabrickcolor", 1, true)
				or ReturnFormatString:find("nomedacor", 1, true) then
				OutputFormat = "BrickColorName"
			elseif ReturnFormatString:find("brickcolor", 1, true) then
				OutputFormat = "BrickColor"
			end

			local function GetOutput(Color)
				local Hex = ColorToHex(Color)

				if OutputFormat == "BrickColor" then
					local Success, BrickColorValue = pcall(BrickColor.new, Color)

					if Success and BrickColorValue then
						return BrickColorValue, Hex
					end
				elseif OutputFormat == "BrickColorName" then
					local Success, BrickColorValue = pcall(BrickColor.new, Color)

					if Success and BrickColorValue then
						return BrickColorValue.Name, Hex
					end
				end

				return Color, Hex
			end

			local Presets = Configs.Presets or ControlsConfig.ColorPicker.Presets

			local RecentColors = {}

			local function HasColor(Color)
				local Hex = ColorToHex(Color)

				for _, RecentColor in ipairs(RecentColors) do
					if ColorToHex(RecentColor) == Hex then
						return true
					end
				end

				return false
			end

			for Index, Color in ipairs(Presets) do
				if Index > MaxRecent then
					break
				end

				local ParsedColor = ParseColor(Color)

				if ParsedColor and not HasColor(ParsedColor) then
					table.insert(RecentColors, ParsedColor)
				end
			end

			local OptionWidth = UDim2.new(1, -130)

			local Option, Label = ButtonFrame(
				ElementParent,
				Name,
				Description,
				OptionWidth,
				false
			)

			local Controls = Create("Frame", Option, {
				Size = UDim2.new(0, 0, 0, 23),
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.new(1, -10, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1
			}, {
				Create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8)
				})
			})

			local HexInput
			local RGBInput
			local HexFrame
			local RGBFrame

			if ShowHex then
				HexFrame = Create("Frame", Controls, {
					Size = UDim2.new(0, 96, 1, 0),
					LayoutOrder = 1,
					ClipsDescendants = true
				})

				InputSurface(HexFrame)
				Make("Corner", HexFrame, UDim.new(0, 5))

				HexInput = Create("TextBox", HexFrame, {
					Size = UDim2.new(1, -10, 1, 0),
					Position = UDim2.new(0, 5, 0, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextColor3 = Theme["Color Text"],
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ClipsDescendants = true,
					Text = ColorToHex(CurrentColor)
				})

				InsertTheme(HexInput, "Text")
			end

			if ShowRGB then
				RGBFrame = Create("Frame", Controls, {
					Size = UDim2.new(0, 104, 1, 0),
					LayoutOrder = 2,
					ClipsDescendants = true
				})

				InputSurface(RGBFrame)
				Make("Corner", RGBFrame, UDim.new(0, 5))

				RGBInput = Create("TextBox", RGBFrame, {
					Size = UDim2.new(1, -10, 1, 0),
					Position = UDim2.new(0, 5, 0, 0),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					TextSize = 10,
					TextColor3 = Theme["Color Text"],
					TextXAlignment = Enum.TextXAlignment.Left,
					ClearTextOnFocus = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ClipsDescendants = true,
					Text = ColorToRGB(CurrentColor)
				})

				InsertTheme(RGBInput, "Text")
			end

			local function PreviewFormat(Color)
				return ShowHex and ColorToHex(Color) or ColorToRGB(Color)
			end

			local PreviewButton = InsertTheme(Create("TextButton", Controls, {
				Size = UDim2.fromOffset(104, 23),
				BackgroundColor3 = Theme["Color Stroke"],
				BackgroundTransparency = 0,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = 3
			}), "Stroke")
			Make("Corner", PreviewButton, UDim.new(0, 4))

			local ColorPreview = Create("Frame", PreviewButton, {
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(0, 4, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = CurrentColor,
				BorderSizePixel = 0
			})
			Make("Corner", ColorPreview, UDim.new(0, 4))

			local PreviewValue = InsertTheme(Create("TextLabel", PreviewButton, {
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.new(1, -44, 1, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Theme["Color Text"],
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextSize = 10,
				Text = PreviewFormat(CurrentColor)
			}), "Text")

			local Arrow = InsertTheme(Create("ImageLabel", PreviewButton, {
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.new(1, -5, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Image = Library:GetIcon("chevrondown"),
				ImageColor3 = Theme["Color Dark Text"]
			}), "DarkText")

			local PopupOverlay = Create("Frame", MainFrame, {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = false,
				Active = true,
				ZIndex = 200
			})
			local PopupBackdrop = InsertTheme(Create("TextButton", PopupOverlay, {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme["Color Hub 2"],
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				Active = true,
				ZIndex = 1
			}), "Frame")
			MainCorner:Clone().Parent = PopupBackdrop
			local PickerFrame = Create("Frame", PopupOverlay, {
				Size = UDim2.new(0.82, 0, 0, 314),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				BorderSizePixel = 0,
				Active = true,
				ZIndex = 2
			})
			Make("Corner", PickerFrame, UDim.new(0, 10))
			InsertTheme(Create("UIGradient", PickerFrame, {
				Color = ThemeBackgroundColors(),
				Rotation = GradientRotation
			}), "Gradient")
			Create("UISizeConstraint", PickerFrame, {
				MinSize = Vector2.new(240, 305),
				MaxSize = Vector2.new(360, 314)
			})
			local PickerScale = Create("UIScale", PickerFrame, {Scale = 1})
			local PanelTitle = InsertTheme(Create("TextLabel", PickerFrame, {
				Position = UDim2.fromOffset(16, 9),
				Size = UDim2.new(1, -79, 0, 21),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 14,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = TranslateText(Name)
			}), "TitleText")
			local PanelSubtitle = InsertTheme(Create("TextLabel", PickerFrame, {
				Position = UDim2.fromOffset(16, 29),
				Size = UDim2.new(1, -79, 0, 15),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextColor3 = Color3.fromRGB(180, 180, 188),
				TextSize = 10,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = Description ~= "" and TranslateText(Description) or "HSV · HEX · RGB"
			}), "DescriptionText")
			local CloseButton = InsertTheme(Create("TextButton", PickerFrame, {
				Position = UDim2.new(1, -10, 0, 8),
				AnchorPoint = Vector2.new(1, 0),
				Size = UDim2.fromOffset(36, 36),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Theme["Color Text"],
				TextTransparency = 0.05,
				TextSize = 26,
				Text = "×"
			}), "Text")

			local PickerContent = Create("Frame", PickerFrame, {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1
			}, {
				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 5)
				}),
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, 15),
					PaddingRight = UDim.new(0, 15),
					PaddingTop = UDim.new(0, 54),
					PaddingBottom = UDim.new(0, 11)
				})
			})

			local SummaryRow = InsertTheme(Create("Frame", PickerContent, {
				Size = UDim2.new(1, 0, 0, 42),
				BackgroundColor3 = Theme["Color Hub 2"],
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				LayoutOrder = 0
			}), "Frame")
			Make("Corner", SummaryRow, UDim.new(0, 8))
			local SummaryPreview = Create("Frame", SummaryRow, {
				Size = UDim2.fromOffset(32, 32),
				Position = UDim2.new(0, 5, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = CurrentColor,
				BorderSizePixel = 0
			})
			Make("Corner", SummaryPreview, UDim.new(0, 6))
			local SummaryValue = InsertTheme(Create("TextLabel", SummaryRow, {
				Position = UDim2.fromOffset(47, 6),
				Size = UDim2.new(1, -55, 0, 18),
				BackgroundTransparency = 1,
				TextColor3 = Theme["Color Text"],
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = ColorToHex(CurrentColor)
			}), "Text")
			local SummaryRGB = InsertTheme(Create("TextLabel", SummaryRow, {
				Position = UDim2.fromOffset(47, 23),
				Size = UDim2.new(1, -55, 0, 13),
				BackgroundTransparency = 1,
				TextColor3 = Theme["Color Dark Text"],
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = ColorToRGB(CurrentColor)
			}), "DarkText")

			Create("Frame", PickerContent, {
				Size = UDim2.new(1, 0, 0, 7),
				BackgroundTransparency = 1,
				LayoutOrder = 10
			})
			local InputRow = Create("Frame", PickerContent, {
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				LayoutOrder = 11
			}, {
				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8)
				})
			})
			for _, Entry in ipairs({
				{Frame = HexFrame, Input = HexInput, Title = "HEX"},
				{Frame = RGBFrame, Input = RGBInput, Title = "RGB"}
			}) do
				if Entry.Frame then
					local Frame = Entry.Frame
					local Input = Entry.Input
					Frame.Parent = InputRow
					Frame.Size = UDim2.new(ShowHex and ShowRGB and 0.5 or 1, ShowHex and ShowRGB and -4 or 0, 1, 0)
					Input.Position = UDim2.fromOffset(8, 0)
					Input.Size = UDim2.new(1, -48, 1, 0)
					InsertTheme(Create("TextLabel", Frame, {
						Position = UDim2.new(1, -6, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						Size = UDim2.fromOffset(30, 15),
						BackgroundTransparency = 1,
						TextColor3 = Theme["Color Dark Text"],
						Font = Enum.Font.GothamMedium,
						TextSize = 9,
						TextXAlignment = Enum.TextXAlignment.Right,
						Text = Entry.Title
					}), "DarkText")
				end
			end

			local RecentLabel = Create("TextLabel", PickerContent, {
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = TranslateText("Recent"),
				LayoutOrder = 8
			})

			InsertTheme(RecentLabel, "DarkText")

			local RecentHolder = Create("ScrollingFrame", PickerContent, {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				ScrollingDirection = Enum.ScrollingDirection.X,
				ScrollBarThickness = 0,
				ScrollingEnabled = true,
				ClipsDescendants = true,
				LayoutOrder = 9
			}, {
				Create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 7)
				})
			})

			local HueLabel = Create("TextLabel", PickerContent, {
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = TranslateText("Hue"),
				LayoutOrder = 2
			})

			InsertTheme(HueLabel, "DarkText")

			local HueBar = Create("TextButton", PickerContent, {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = 3
			})

			local HueBackground = Create("Frame", HueBar, {
				Size = UDim2.new(1, 0, 0, 10),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BorderSizePixel = 0,
				BackgroundColor3 = ControlColors.White
			}, {
				Create("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
						ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
						ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
						ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
						ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
						ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
					})
				})
			})

			Make("Corner", HueBackground, UDim.new(0.5, 0))

			local HueIndicator = Create("Frame", HueBackground, {
				Size = UDim2.new(0, 10, 0, 19),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				BackgroundColor3 = ControlColors.Handle,
				BackgroundTransparency = 0.1,
				ZIndex = 2
			})
			Make("Corner", HueIndicator)

			local SaturationLabel = Create("TextLabel", PickerContent, {
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = TranslateText("Saturation"),
				LayoutOrder = 4
			})

			InsertTheme(SaturationLabel, "DarkText")

			local SaturationBar = Create("TextButton", PickerContent, {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = 5
			})

			local SaturationBackground = Create("Frame", SaturationBar, {
				Size = UDim2.new(1, 0, 0, 10),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1)
			})

			Make("Corner", SaturationBackground, UDim.new(0.5, 0))

			local SaturationGradient = Create("UIGradient", SaturationBackground)

			local SaturationIndicator = Create("Frame", SaturationBackground, {
				Size = UDim2.new(0, 10, 0, 19),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = ControlColors.Handle,
				BackgroundTransparency = 0.1,
				ZIndex = 2
			})

			Make("Corner", SaturationIndicator)

			local BrightnessLabel = Create("TextLabel", PickerContent, {
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = TranslateText("Brightness"),
				LayoutOrder = 6
			})

			InsertTheme(BrightnessLabel, "DarkText")

			TrackConnection(TrackColorConnection(Connection.LanguageChanged:Connect(function()
				if RecentLabel.Parent then
					RecentLabel.Text = TranslateText("Recent")
					HueLabel.Text = TranslateText("Hue")
					SaturationLabel.Text = TranslateText("Saturation")
					BrightnessLabel.Text = TranslateText("Brightness")
					PanelTitle.Text = TranslateText(Name)
					PanelSubtitle.Text = Description ~= "" and TranslateText(Description) or "HSV · HEX · RGB"
				end
			end)))

			local BrightnessBar = Create("TextButton", PickerContent, {
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = 7
			})

			local BrightnessBackground = Create("Frame", BrightnessBar, {
				Size = UDim2.new(1, 0, 0, 10),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(0, 0, 0)
			})

			Make("Corner", BrightnessBackground, UDim.new(0.5, 0))

			local BrightnessGradient = Create("UIGradient", BrightnessBackground)

			local BrightnessIndicator = Create("Frame", BrightnessBackground, {
				Size = UDim2.new(0, 10, 0, 19),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = ControlColors.Handle,
				BackgroundTransparency = 0.1,
				ZIndex = 2
			})

			Make("Corner", BrightnessIndicator)

			local function CreateSliderValueLabel(Parent)
				return InsertTheme(Create("TextLabel", Parent, {
					Position = UDim2.new(1, 0, 0, 0),
					AnchorPoint = Vector2.new(1, 0),
					Size = UDim2.fromOffset(50, 12),
					BackgroundTransparency = 1,
					TextColor3 = Theme["Color Dark Text"],
					Font = Enum.Font.GothamMedium,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = ""
				}), "DarkText")
			end
			local HueValue = CreateSliderValueLabel(HueLabel)
			local SaturationValue = CreateSliderValueLabel(SaturationLabel)
			local BrightnessValue = CreateSliderValueLabel(BrightnessLabel)

			local Expanded = false
			local CurrentColorValue = CurrentColor
			local Hue, Saturation, Brightness = CurrentColor:ToHSV()

			local function RefreshColorDisplay(Color)
				ColorPreview.BackgroundColor3 = Color
				PreviewValue.Text = PreviewFormat(Color)
				SummaryPreview.BackgroundColor3 = Color
				SummaryValue.Text = ColorToHex(Color)
				SummaryRGB.Text = ColorToRGB(Color)
				HueValue.Text = string.format("%d°", math.floor(Hue * 360 + 0.5))
				SaturationValue.Text = string.format("%d%%", math.floor(Saturation * 100 + 0.5))
				BrightnessValue.Text = string.format("%d%%", math.floor(Brightness * 100 + 0.5))
			end

			local function CreateRecentButton(Parent, Color)
				local Button = Create("TextButton", Parent, {
					Size = UDim2.fromOffset(22, 22),
					BackgroundColor3 = Color,
					AutoButtonColor = false,
					Text = ""
				})
				Make("Corner", Button, UDim.new(0, 6))
				Button.BackgroundTransparency = 0
				return Button
			end

			local SetColor

			local function RefreshRecent()
				for _, Child in ipairs(RecentHolder:GetChildren()) do
					if Child:IsA("TextButton") then
						Child:Destroy()
					end
				end

				for _, Color in ipairs(RecentColors) do
					local RecentColor = Color

					CreateRecentButton(RecentHolder, RecentColor).Activated:Connect(function()
						SetColor(RecentColor, true, true)
					end)
				end
			end

			local function AddRecent(Color)
				local Hex = ColorToHex(Color)

				for Index = #RecentColors, 1, -1 do
					if ColorToHex(RecentColors[Index]) == Hex then
						table.remove(RecentColors, Index)
					end
				end

				table.insert(RecentColors, 1, Color)

				while #RecentColors > MaxRecent do
					table.remove(RecentColors)
				end

				RefreshRecent()
			end

			local IndicatorTargets = setmetatable({}, {__mode = "k"})
			local IndicatorUpdateConnection

			local function StopIndicatorAnimation()
				if IndicatorUpdateConnection then
					IndicatorUpdateConnection:Disconnect()
					IndicatorUpdateConnection = nil
				end
				table.clear(IndicatorTargets)
			end

			local function UpdateIndicator(Indicator, Background, Value, Smooth)
				if Background.AbsoluteSize.X <= 0 then return end
				local Target = UDim2.fromScale(math.clamp(Value, 0, 1), 0.5)

				if not Smooth or SmoothTime <= 0 then
					IndicatorTargets[Indicator] = nil
					Indicator.Position = Target
					return
				end

				IndicatorTargets[Indicator] = Target
				if IndicatorUpdateConnection then return end
				IndicatorUpdateConnection = game:GetService("RunService").RenderStepped:Connect(function(Delta)
					local Pending = false
					local Alpha = 1 - math.exp(-math.min(Delta, 0.05) / SmoothTime)
					for ActiveIndicator, Position in pairs(IndicatorTargets) do
						local Current = ActiveIndicator.Position
						if math.abs(Current.X.Scale - Position.X.Scale) < 0.001 then
							ActiveIndicator.Position = Position
							IndicatorTargets[ActiveIndicator] = nil
						else
							ActiveIndicator.Position = Current:Lerp(Position, Alpha)
							Pending = true
						end
					end
					if not Pending then StopIndicatorAnimation() end
				end)
			end

			local function UpdateIndicators(Animate)
				UpdateIndicator(HueIndicator, HueBackground, Hue, Animate == true)
				UpdateIndicator(SaturationIndicator, SaturationBackground, Saturation, Animate == true)
				UpdateIndicator(BrightnessIndicator, BrightnessBackground, Brightness, Animate == true)
			end

			local function UpdateGradients(Component)
				if Component == "Brightness" then return end
				if Component ~= "Saturation" then
					SaturationGradient.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(Hue, 1, 1))
					})
				end
				BrightnessGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(Hue, Saturation, 1))
				})
			end

			SetColor = function(Color, FireCallback, AddToRecent)
				CurrentColorValue = Color

				Hue, Saturation, Brightness = Color:ToHSV()

				RefreshColorDisplay(Color)

				if HexInput and not HexInput:IsFocused() then
					HexInput.Text = ColorToHex(Color)
				end

				if RGBInput and not RGBInput:IsFocused() then
					RGBInput.Text = ColorToRGB(Color)
				end

				UpdateGradients()
				UpdateIndicators(true)

				if Flag then
					SetFlag(Flag, ColorToHex(Color))
				end

				if AddToRecent then
					AddRecent(Color)
				end

				if FireCallback and Callback then
					local Value, Hex = GetOutput(Color)

					Funcs:FireCallback(
						Callback,
						Value,
						Hex
					)
				end
			end

			local function ApplyHSV(FireCallback, AddToRecent, ChangedComponent)
				local Color = Color3.fromHSV(
					Hue,
					Saturation,
					Brightness
				)

				CurrentColorValue = Color
				RefreshColorDisplay(Color)

				if HexInput and not HexInput:IsFocused() then
					HexInput.Text = ColorToHex(Color)
				end

				if RGBInput and not RGBInput:IsFocused() then
					RGBInput.Text = ColorToRGB(Color)
				end

				UpdateGradients(ChangedComponent)
				UpdateIndicators()

				if Flag then
					SetFlag(Flag, ColorToHex(Color))
				end

				if AddToRecent then
					AddRecent(Color)
				end

				if FireCallback and Callback then
					local Value, Hex = GetOutput(Color)

					Funcs:FireCallback(
						Callback,
						Value,
						Hex
					)
				end
			end

			local FinishColorDrag
			local PickerScaleTween
			local PickerBackdropTween
			local PickerArrowTween
			local PopupTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local PopupAnimationToken = 0

			local function StopPickerTweens()
				PopupAnimationToken += 1
				if PickerScaleTween then
					PickerScaleTween:Cancel()
					PickerScaleTween = nil
				end
				if PickerBackdropTween then
					PickerBackdropTween:Cancel()
					PickerBackdropTween = nil
				end
				if PickerArrowTween then
					PickerArrowTween:Cancel()
					PickerArrowTween = nil
				end
			end

			local function SetExpanded(Value)
				local ShouldExpand = Value == nil and not Expanded or Value == true
				if ShouldExpand == Expanded then return end
				if ShouldExpand and (not Container.Visible or not Option.Visible or not Option.Interactable or ColorPicker.Locked) then
					return
				end
				Expanded = ShouldExpand
				if not Expanded and FinishColorDrag then FinishColorDrag(false) end
				StopPickerTweens()
				local Token = PopupAnimationToken

				if Expanded and not PopupOverlay.Visible then
					PopupOverlay.Visible = true
					PickerScale.Scale = 0.96
					PopupBackdrop.BackgroundTransparency = 1
				end

				PickerScaleTween = TweenService:Create(PickerScale, PopupTweenInfo, {
					Scale = Expanded and 1 or 0.96
				})
				PickerBackdropTween = TweenService:Create(PopupBackdrop, PopupTweenInfo, {
					BackgroundTransparency = Expanded and 0.48 or 1
				})
				PickerArrowTween = TweenService:Create(Arrow, PopupTweenInfo, {
					Rotation = Expanded and 180 or 0
				})
				if not Expanded then
					PickerScaleTween.Completed:Once(function(State)
						if Token == PopupAnimationToken and State == Enum.PlaybackState.Completed
							and not Expanded and PopupOverlay.Parent then
							PopupOverlay.Visible = false
						end
					end)
				end

				PickerScaleTween:Play()
				PickerBackdropTween:Play()
				PickerArrowTween:Play()
				if Expanded then task.defer(UpdateIndicators) end
			end

			PreviewButton.Activated:Connect(function()
				SetExpanded()
			end)
			CloseButton.Activated:Connect(function()
				SetExpanded(false)
			end)
			PopupBackdrop.Activated:Connect(function()
				SetExpanded(false)
			end)

			local function GetSliderValue(Input, Background)
				local Width = Background.AbsoluteSize.X
				if Width <= 0 then return nil end
				return math.clamp((Input.Position.X - Background.AbsolutePosition.X) / Width, 0, 1)
			end

			local HueDragging = false
			local SaturationDragging = false
			local BrightnessDragging = false
			local DragInput
			local MoveConnection
			local EndConnection
			local FocusConnection
			local PreviousScrolling

			local function UpdateHue(Input)
				local NewHue = GetSliderValue(Input, HueBackground)
				if NewHue == nil or NewHue == Hue then return end
				Hue = NewHue
				ApplyHSV(LiveUpdate, false, "Hue")
			end

			local function UpdateSaturation(Input)
				local NewSaturation = GetSliderValue(Input, SaturationBackground)
				if NewSaturation == nil or NewSaturation == Saturation then return end
				Saturation = NewSaturation
				ApplyHSV(LiveUpdate, false, "Saturation")
			end

			local function UpdateBrightness(Input)
				local NewBrightness = GetSliderValue(Input, BrightnessBackground)
				if NewBrightness == nil or NewBrightness == Brightness then return end
				Brightness = NewBrightness
				ApplyHSV(LiveUpdate, false, "Brightness")
			end

			FinishColorDrag = function(Commit)
				local ActiveIndicator = HueDragging and HueIndicator
					or SaturationDragging and SaturationIndicator
					or BrightnessDragging and BrightnessIndicator
				if not ActiveIndicator then return end
				HueDragging, SaturationDragging, BrightnessDragging = false, false, false
				DragInput = nil
				if MoveConnection then MoveConnection:Disconnect() MoveConnection = nil end
				if EndConnection then EndConnection:Disconnect() EndConnection = nil end
				if FocusConnection then FocusConnection:Disconnect() FocusConnection = nil end
				Container.ScrollingEnabled = PreviousScrolling
				ActiveIndicator.Size = UDim2.fromOffset(10, 19)
				if Commit then ApplyHSV(not LiveUpdate, true, "Brightness") end
			end

			local function StartDrag(Indicator, CallbackFunction, Input)
				if MoveConnection then return end
				DragInput = Input.UserInputType == Enum.UserInputType.Touch and Input or nil
				PreviousScrolling = Container.ScrollingEnabled
				Container.ScrollingEnabled = false
				Indicator.Size = UDim2.fromOffset(12, 21)
				CallbackFunction(Input)
				MoveConnection = UserInputService.InputChanged:Connect(function(Changed)
					if DragInput then
						if Changed ~= DragInput then return end
					elseif Changed.UserInputType ~= Enum.UserInputType.MouseMovement then
						return
					end
					if HueDragging then
						UpdateHue(Changed)
					elseif SaturationDragging then
						UpdateSaturation(Changed)
					elseif BrightnessDragging then
						UpdateBrightness(Changed)
					end
				end)
				EndConnection = UserInputService.InputEnded:Connect(function(Ended)
					if DragInput then
						if Ended ~= DragInput then return end
					elseif Ended.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end
					CallbackFunction(Ended)
					FinishColorDrag(true)
				end)
				FocusConnection = UserInputService.WindowFocusReleased:Connect(function()
					FinishColorDrag(true)
				end)
			end

			local function CanStartSlider(Input)
				local Kind = Input.UserInputType
				return Expanded and PickerFrame.Visible and Option.Interactable and not MoveConnection
					and (Kind == Enum.UserInputType.MouseButton1 or Kind == Enum.UserInputType.Touch)
			end

			local function BeginHue(Input)
				if not CanStartSlider(Input) then return end
				HueDragging = true
				StartDrag(HueIndicator, UpdateHue, Input)
			end
			local function BeginSaturation(Input)
				if not CanStartSlider(Input) then return end
				SaturationDragging = true
				StartDrag(SaturationIndicator, UpdateSaturation, Input)
			end
			local function BeginBrightness(Input)
				if not CanStartSlider(Input) then return end
				BrightnessDragging = true
				StartDrag(BrightnessIndicator, UpdateBrightness, Input)
			end

			for _, Surface in ipairs({HueBar, HueBackground, HueIndicator}) do
				Surface.InputBegan:Connect(BeginHue)
			end
			for _, Surface in ipairs({SaturationBar, SaturationBackground, SaturationIndicator}) do
				Surface.InputBegan:Connect(BeginSaturation)
			end
			for _, Surface in ipairs({BrightnessBar, BrightnessBackground, BrightnessIndicator}) do
				Surface.InputBegan:Connect(BeginBrightness)
			end

			TrackColorConnection(Container:GetPropertyChangedSignal("Visible"):Connect(function()
				if not Container.Visible then SetExpanded(false) end
			end))

			HueBackground:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateIndicators)
			SaturationBackground:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateIndicators)
			BrightnessBackground:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateIndicators)

			if HexInput then
				HexInput:GetPropertyChangedSignal("Text"):Connect(function()
					local Text = HexInput.Text:gsub("[^%x]", ""):upper()

					if #Text > 6 then
						Text = Text:sub(1, 6)
					end

					local NewText = "#" .. Text

					if HexInput.Text ~= NewText then
						HexInput.Text = NewText
					end

					if HexInput.CursorPosition <= 1 then
						HexInput.CursorPosition = math.max(#HexInput.Text + 1, 2)
					end
				end)

				HexInput.Focused:Connect(function()
					if HexInput.Text:sub(1, 1) ~= "#" then
						HexInput.Text = "#" .. HexInput.Text:gsub("[^%x]", ""):sub(1, 6)
					end

					task.defer(function()
						if HexInput:IsFocused() then
							HexInput.CursorPosition = math.max(#HexInput.Text + 1, 2)
						end
					end)
				end)

				HexInput.FocusLost:Connect(function()
					local Color = ParseHex(HexInput.Text)

					if Color then
						SetColor(Color, true, true)
					else
						HexInput.Text = ColorToHex(CurrentColorValue)
					end
				end)
			end

			if RGBInput then
				RGBInput:GetPropertyChangedSignal("Text"):Connect(function()
					local Text = RGBInput.Text:gsub("[^%d,]", "")
					local Parts = {}

					for Part in Text:gmatch("%d+") do
						if #Parts < 3 then
							table.insert(Parts, Part:sub(1, 3))
						end
					end

					local Clean = table.concat(Parts, ",")

					if RGBInput.Text ~= Clean then
						RGBInput.Text = Clean
					end
				end)

				RGBInput.FocusLost:Connect(function()
					local Color = ParseRGB(RGBInput.Text)

					if Color then
						SetColor(Color, true, true)
					else
						RGBInput.Text = ColorToRGB(CurrentColorValue)
					end
				end)
			end

			function ColorPicker:Set(Value, DescriptionValue)
				if type(Value) == "string" and type(DescriptionValue) == "string" then
					Name, Description = Value, DescriptionValue
					Label:SetTitle(Name)
					Label:SetDesc(Description)
					PanelTitle.Text = TranslateText(Name)
					PanelSubtitle.Text = Description ~= "" and TranslateText(Description) or "HSV · HEX · RGB"
					return
				end

				if type(Value) == "string" then
					local HexColor = ParseHex(Value)

					if HexColor then
						SetColor(HexColor, true, false)
						return
					end

					local BrickColorValue = ParseBrickColor(Value)

					if BrickColorValue then
						SetColor(BrickColorValue, true, false)
						return
					end

					Name = Value
					Label:SetTitle(Name)
					PanelTitle.Text = TranslateText(Name)
					return
				end

				if typeof(Value) == "Color3" then
					SetColor(Value, true, false)
					return
				end

				if typeof(Value) == "BrickColor" then
					SetColor(Value.Color, true, false)
					return
				end

				if type(Value) == "function" then
					Callback = {Value}
				end
			end

			function ColorPicker:Get()
				return GetOutput(CurrentColorValue)
			end

			function ColorPicker:Callback(...)
				local Added = Funcs:InsertCallback(Callback, ...)
				if type(Added) == "function" then
					local Value, Hex = GetOutput(CurrentColorValue)
					Added(Value, Hex)
				end
			end

			function ColorPicker:Visible(Value)
				if Value == nil then Value = not Option.Visible end
				Funcs:ToggleVisible(Option, Value)
				if Value == false then
					FinishColorDrag(false)
					Expanded = false
					StopPickerTweens()
					Arrow.Rotation = 0
					PopupOverlay.Visible = false
				end
			end

			function ColorPicker:Expand(Value)
				SetExpanded(Value)
			end

			local ColorOption

			function ColorPicker:Destroy()
				FinishColorDrag(false)
				StopPickerTweens()
				if ColorOption then
					local Index = table.find(Library.Options, ColorOption)
					if Index then
						table.remove(Library.Options, Index)
					end
					ColorOption = nil
				end

				for _, ConnectionObject in ipairs(ColorConnections) do
					if ConnectionObject.Connected then
						ConnectionObject:Disconnect()
					end
					UntrackConnection(ConnectionObject)
				end
				table.clear(ColorConnections)

				StopIndicatorAnimation()

				Option:Destroy()
				if PopupOverlay.Parent then PopupOverlay:Destroy() end
			end

			SetColor(CurrentColorValue, false, false)
			RefreshRecent()

			task.defer(UpdateIndicators)

			if Flag then
				ColorOption = {
					type = "ColorPicker",
					Name = Name,
					Flag = Flag,
					Default = ColorToHex(CurrentColorValue),
					func = ColorPicker
				}
				table.insert(Library.Options, ColorOption)
			end

			ApplyLocked(ColorPicker, Option, Configs, function(IsLocked)
				if IsLocked then
					FinishColorDrag(false)
					SetExpanded(false)
				end
			end)

			Option.Destroying:Connect(function()
				FinishColorDrag(false)
				StopPickerTweens()
				if PopupOverlay.Parent then PopupOverlay:Destroy() end
			end)

			ColorPicker._OnSectionHidden = function() SetExpanded(false) end
			return RegisterFlagObject(Flag, ColorPicker, Option)
		end
		function Tab:AddCode(Configs)
			Configs = type(Configs) == "table" and Configs or {}
			local CodeConfig = LibraryConfig.Code
			local function ReadOption(Name)
				if Configs[Name] ~= nil then return Configs[Name] end
				return CodeConfig[Name]
			end
			local function BooleanOption(Name, Alternate)
				if Configs[Name] ~= nil or Alternate and Configs[Alternate] ~= nil then
					return Configs[Name] == true or Alternate and Configs[Alternate] == true or false
				end
				return CodeConfig[Name] == true
			end

			local TitleSource = tostring(Configs.Title or Configs.Name or CodeConfig.Title)
			local TitleText = TranslateText(TitleSource)
			local function NormalizeCode(Value)
				return (tostring(Value or ""):gsub("\r\n", "\n"):gsub("\r", "\n"))
			end
			local function ClampCursor(Position, Text)
				Position = math.clamp(Position, 1, #Text + 1)
				local Byte = Text:byte(Position)
				while Byte and Byte >= 128 and Byte < 192 do
					Position -= 1
					Byte = Text:byte(Position)
				end
				return Position
			end
			local function NumberOption(Value, Default, Minimum, Maximum)
				local Number = tonumber(Value)
				if not Number or Number ~= Number then Number = Default end
				return math.clamp(Number, Minimum, Maximum)
			end
			local InitialCode = NormalizeCode(Configs.Code or Configs.Source or Configs.Text or CodeConfig.Source)
			local ObservedCode, RenderedCode = InitialCode, nil
			local Language = tostring(ReadOption("Language"))
			local SavedCode = InitialCode
			local EditAllowed = BooleanOption("Edit", "Editable")
			local CanExecute = BooleanOption("Execute")
			local CanCopy = ReadOption("Copy") ~= false

			local ErrorEnabled = BooleanOption("Error", "ShowErrors")
			local Option = {
				BlockOnError = ReadOption("BlockOnError") ~= false,
				SmoothCaret = ReadOption("SmoothCaret") ~= false,
				CaretWidth = NumberOption(Configs.CaretWidth, CodeConfig.CaretWidth, 1, 6),
				CaretNudge = NumberOption(Configs.CaretOffset, CodeConfig.CaretOffset, -4, 4)
			}
			local IndentUnit
			do
				local function DetectIndent(Source)
				local Custom = Configs.IndentUnit or Configs.Indent
				if type(Custom) == "string" and Custom ~= "" and not Custom:find("[^ \t]") then return Custom end
				local Size = tonumber(Configs.TabSize)
				if Size then return string.rep(" ", math.floor(math.clamp(Size, 1, 8))) end
				if Source:find("\n\t") then return "\t" end
				local Spaces = Source:match("\n( +)%S")
				if Spaces then
					local Count = #Spaces
					return string.rep(" ", Count % 4 == 0 and 4 or Count % 2 == 0 and 2 or math.min(Count, 8))
				end
					return CodeConfig.IndentUnit
			end

				IndentUnit = DetectIndent(InitialCode)
			end
			local OnChange = type(Configs.OnChange) == "function" and Configs.OnChange or nil
			local OnSave = type(Configs.OnSave) == "function" and Configs.OnSave or nil
			local FontSize = math.floor(NumberOption(Configs.FontSize, CodeConfig.FontSize, 9, 32))
			local LineSpacing = NumberOption(Configs.LineSpacing, CodeConfig.LineSpacing, 1, 3)
			local LineHeight
			do
				local Bounds = Vector2.new(10000, 10000)
				local TwoLineHeight = TextService:GetTextSize("M\nM", FontSize, Enum.Font.Code, Bounds).Y
				local TenLineHeight = TextService:GetTextSize(string.rep("M\n", 9) .. "M", FontSize, Enum.Font.Code, Bounds).Y
				local NaturalAdvance = (TenLineHeight - TwoLineHeight) / 8
				LineHeight = (NaturalAdvance > 0 and NaturalAdvance or TextService:GetTextSize("Ag", FontSize, Enum.Font.Code, Bounds).Y) * LineSpacing
			end
			local HeaderHeight, Padding, BottomPadding = CodeConfig.HeaderHeight, CodeConfig.Padding, CodeConfig.BottomPadding
			local MaxVisibleLines = math.floor(NumberOption(Configs.MaxVisibleLines, CodeConfig.MaxVisibleLines, 1, 60))
			local GutterWidth = CodeConfig.GutterWidth
			local GutterFontSize = math.max(10, FontSize - 2)
			local ExecuteSpinDuration = NumberOption(ReadOption("ExecuteSpinDuration"), CodeConfig.ExecuteSpinDuration, 0.2, 3)
			local Editable, Focused, Destroyed, RefreshQueued, Executing = false, false, false, false, false
			local Lines, StyledLines, LineOffsets, LineCount, MaxLineWidth = {}, {}, {}, 1, 0
			local HighlightCache, Cached = {}, 0
			local WidthCache, WidthCached = {}, 0
			local LineLabels, NumberLabels, SelectionFrames, Buttons = {}, {}, {}, {}
			local Measurements, MeasurementCount = {}, 0
			local MeasurementTexts = setmetatable({}, {__mode = "k"})
			local QueueRefresh, QueueGeometry, QueueDiagnostics
			local RenderVersion, DrawnVersion, DrawnFirst, DrawnLast = 0, -1, 0, 0
			local DrawnActiveRow
			local CopyToken, ExecutionToken = 0, 0
			local CopyTweens = {}
			local AutoClosers = {}
			local PairOpen = {['"'] = '"', ["'"] = "'", ["`"] = "`", ["("] = ")", ["["] = "]", ["{"] = "}"}
			local PairClose = {["("] = ")", ["["] = "]", ["{"] = "}"}
			local ClosingCharacters = {["\""] = true, ["'"] = true, ["`"] = true, [")"] = true, ["]"] = true, ["}"] = true}
			local SpinTween, BodyTween, FlashTween
			local ShakeToken = 0
			local ExternalConnections = {}
			local ActionPointer, PastePending, Saving = false, false, false
			local FlushText, TextQueued, TextWasEditing
			local BlinkToken, CaretFadeTween, CaretMoveTween = 0, nil, nil
			local Diagnostics, RuntimeDiagnostic, Shown, DiagByLine, DiagToken = {}, nil, {}, {}, 0
			local UndoStack, RedoStack, LastHistoryTime = {}, {}, 0
			local ErrorColor = CodeConfig.ErrorColor.Dark
			local Palette = {}
			local Code = {}

			local function IsLuaLanguage()
				local Name = Language:lower()
				return Name == "lua" or Name == "luau"
			end

			local function UpdatePalette()
				local Background = Theme["Color Hub 2"]
				local Light = (Background and Background.R * 0.2126 + Background.G * 0.7152 + Background.B * 0.0722 > CodeConfig.PaletteLightThreshold) or false
				local Mode = Light and "Light" or "Dark"
				Palette = CodeConfig.Palette[Mode]
				ErrorColor = CodeConfig.ErrorColor[Mode]
			end
			UpdatePalette()

			local function BodyColor(IsEditable)
				return Theme["Color Hub 2"]:Lerp(Color3.new(0, 0, 0), IsEditable and 0.37 or 0.28)
			end

			local Holder = ComponentSurface(Create("Frame", ElementParent, {
				Name = "CodeElement",
				ZIndex = 10,
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundColor3 = Theme["Color Hub 2"],
				BorderSizePixel = 0,
				ClipsDescendants = false
			}))
			Make("Corner", Holder, UDim.new(0, ElementCornerRadius))

			local Header = Create("Frame", Holder, {
				Name = "Header",
				ZIndex = 10,
				Size = UDim2.new(1, 0, 0, HeaderHeight),
				BackgroundTransparency = 1
			})

			InsertTheme(Create("ImageLabel", Header, {
				Name = "FileIcon",
				Position = UDim2.fromOffset(9, 8),
				Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1,
				Image = Library:GetIcon("code2"),
				ImageColor3 = Theme["Color Dark Text"]
			}), "DarkText")

			local FileName = InsertTheme(Create("TextLabel", Header, {
				Name = "Filename",
				Position = UDim2.fromOffset(30, 0),
				Size = UDim2.new(1, -140, 1, 0),
				BackgroundTransparency = 1,
				Text = TitleText,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextColor3 = Theme["Color Text"],
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd
			}), "Text")

			local ErrorBadge = Create("Frame", Header, {
				Name = "ErrorBadge",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -60, 0.5, 0),
				Size = UDim2.fromOffset(7, 7),
				BackgroundColor3 = ErrorColor,
				BorderSizePixel = 0,
				Visible = false
			})
			Make("Corner", ErrorBadge, UDim.new(1, 0))

			local Actions = Create("Frame", Header, {
				Name = "Actions",
				Position = UDim2.new(1, -7, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1
			}, {
				Create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 2)
				})
			})

			local function Action(Name, IconName, Order)
				local Button = Create("ImageButton", Actions, {
					Name = Name,
					LayoutOrder = Order,
					Size = UDim2.fromOffset(24, 24),
					BackgroundColor3 = Theme["Color Theme"],
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Image = ""
				})
				Make("Corner", Button, UDim.new(0, 6))
				local Icon = InsertTheme(Create("ImageLabel", Button, {
					Name = "Icon",
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = Library:GetIcon(IconName),
					ImageColor3 = Theme["Color Dark Text"]
				}), "DarkText")
				local Scale = Create("UIScale", Button, {Scale = 1})
				local IconScale = Create("UIScale", Icon, {Name = "IconScale", Scale = 1})
				local Entry = {
					ActionName = Name,
					Button = Button,
					Icon = Icon,
					Scale = Scale,
					IconScale = IconScale,
					Selected = false,
					Hover = false,
					Press = false
				}
				Buttons[#Buttons + 1] = Entry
				function Entry.Update(Instant)
					if Destroyed then return end
					local TargetAlpha = Entry.Hover and 0.8 or 1
					local TargetScale = Entry.Press and 0.92 or 1
					if Entry.TintTween then Entry.TintTween:Cancel() end
					if Entry.ScaleTween then Entry.ScaleTween:Cancel() end
					if Instant then
						Button.BackgroundTransparency = TargetAlpha
						Scale.Scale = TargetScale
					else
						Entry.TintTween = TweenService:Create(Button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = TargetAlpha})
						Entry.ScaleTween = TweenService:Create(Scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = TargetScale})
						Entry.TintTween:Play()
						Entry.ScaleTween:Play()
					end
					Icon.ImageColor3 = Entry.Selected and Theme["Color Theme"] or Entry.Hover and Theme["Color Text"] or Theme["Color Dark Text"]
					Button.BackgroundColor3 = Theme["Color Theme"]
				end
				Button.MouseEnter:Connect(function() Entry.Hover = true; Entry.Update() end)
				Button.MouseLeave:Connect(function() Entry.Hover = false; Entry.Press = false; Entry.Update() end)
				Button.InputBegan:Connect(function(InputObject)
					if InputObject.UserInputType == Enum.UserInputType.MouseButton1 or InputObject.UserInputType == Enum.UserInputType.Touch then ActionPointer = true end
				end)
				Button.MouseButton1Down:Connect(function() ActionPointer = true; Entry.Press = true; Entry.Update() end)
				Button.MouseButton1Up:Connect(function() Entry.Press = false; Entry.Update() end)
				return Entry
			end

			local ExecuteButton = Action("Execute", "rotate-ccw", 1)
			local EditButton = Action("Edit", "pencil", 2)
			local CopyButton = Action("Copy", "copy", 3)
			local ResetButton = Action("Reset", "undo2", 4)
			ExecuteButton.Button.Visible = CanExecute
			EditButton.Button.Visible = EditAllowed
			CopyButton.Button.Visible = CanCopy
			if ResetButton then ResetButton.Button.Visible = false end
			local function UpdateActions()
				local Count = (CanExecute and 1 or 0) + (EditAllowed and 1 or 0) + (CanCopy and 1 or 0)
				if ResetButton and ResetButton.Button.Visible then Count += 1 end
				local Width = Count * 24 + math.max(0, Count - 1) * 2
				ErrorBadge.Position = UDim2.new(1, -(7 + Width + 6), 0.5, 0)
				FileName.Size = UDim2.new(1, -(38 + Width + (ErrorBadge.Visible and 14 or 0)), 1, 0)
			end

			local Body = Create("Frame", Holder, {
				Name = "Editor",
				Position = UDim2.fromOffset(5, HeaderHeight),
				Size = UDim2.new(1, -10, 1, -HeaderHeight - BottomPadding),
				BackgroundColor3 = BodyColor(false),
				BorderSizePixel = 0,
				ClipsDescendants = true
			})
			Make("Corner", Body, UDim.new(0, 6))

			local Gutter = Create("Frame", Body, {
				Name = "Gutter",
				Size = UDim2.new(0, GutterWidth, 1, 0),
				BackgroundTransparency = 1,
				ClipsDescendants = true
			})
			local NumbersLayer = Create("Frame", Gutter, {
				Name = "LineNumbers",
				Position = UDim2.fromOffset(0, Padding),
				Size = UDim2.new(1, 0, 0, LineHeight),
				BackgroundTransparency = 1,
				BorderSizePixel = 0
			})

			local Scroll = Create("ScrollingFrame", Body, {
				Name = "CodeScroll",
				Position = UDim2.fromOffset(GutterWidth, 0),
				Size = UDim2.new(1, -GutterWidth - 2, 1, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				ScrollBarImageColor3 = Theme["Color Theme"],
				ScrollBarImageTransparency = 0.65,
				ScrollingEnabled = false,
				ScrollingDirection = Enum.ScrollingDirection.XY,
				ElasticBehavior = Enum.ElasticBehavior.Never,
				AutomaticCanvasSize = Enum.AutomaticSize.None,
				CanvasSize = UDim2.new(),
				ClipsDescendants = true
			})

			local TextPosition = UDim2.fromOffset(2, Padding)
			local SelectionLayer = Create("Frame", Scroll, {
				Name = "SelectionLayer",
				Position = TextPosition,
				Size = UDim2.fromOffset(64, LineHeight),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 2
			})
			local HighlightLayer = Create("Frame", Scroll, {
				Name = "HighlightLayer",
				Position = TextPosition,
				Size = UDim2.fromOffset(64, LineHeight),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 3
			})
			local Input = Create("TextBox", Scroll, {
				Name = "CodeInput",
				Position = TextPosition,
				Size = UDim2.fromOffset(64, LineHeight),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.Code,
				TextSize = FontSize,
				LineHeight = LineSpacing,
				TextColor3 = Theme["Color Text"],
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = false,
				TextScaled = false,
				AutoLocalize = false,
				TextEditable = false,
				MultiLine = true,
				ClearTextOnFocus = false,
				RichText = false,
				TextTransparency = 1,
				Text = InitialCode,
				ZIndex = 4
			})
			local Caret = Create("Frame", Scroll, {
				Name = "Caret",
				Position = TextPosition,
				Size = UDim2.fromOffset(Option.CaretWidth, FontSize * CodeConfig.CaretHeightRatio),
				BackgroundColor3 = Theme["Color Theme"],
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 6
			})
			Make("Corner", Caret, UDim.new(0, CodeConfig.CaretCornerRadius))
			local MeasurementLayer = Create("Frame", Body, {
				Name = "MeasurementLayer",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true
			})
			local function EscapeRich(Text)
				return (Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
			end
			local function MakeMeasurement(Name, Text)
				local Expected = EscapeRich(Text)
				local Label = Create("TextLabel", MeasurementLayer, {
					Name = Name,
					Size = UDim2.fromOffset(1000000, 100000),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					FontFace = Input.FontFace,
					TextSize = Input.TextSize,
					LineHeight = Input.LineHeight,
					TextXAlignment = Input.TextXAlignment,
					TextYAlignment = Input.TextYAlignment,
					TextWrapped = false,
					TextScaled = false,
					AutoLocalize = false,
					RichText = true,
					MaxVisibleGraphemes = 0,
					TextTransparency = 1,
					Text = Expected
				})
				MeasurementTexts[Label] = Expected
				Label:GetPropertyChangedSignal("Text"):Connect(function()
					local Original = MeasurementTexts[Label]
					if not Destroyed and Original and Label.Text ~= Original then Label.Text = Original end
				end)
				Label:GetPropertyChangedSignal("TextBounds"):Connect(function()
					if not Destroyed and QueueGeometry then QueueGeometry() end
				end)
				return Label
			end
			local MeasureProbe = MakeMeasurement("MeasureProbe", "M")
			local MeasureContent = MakeMeasurement("MeasureContent", "M")
			local MeasureTwo = MakeMeasurement("MeasureTwo", "M\nM")
			local MeasureTen = MakeMeasurement("MeasureTen", string.rep("M\n", 9) .. "M")
			local function EffectiveScale()
				local Scale = Header.AbsoluteSize.Y / HeaderHeight
				return Scale > 0 and Scale or 1
			end

			local function ViewSize()
				return Scroll.AbsoluteWindowSize / EffectiveScale()
			end

			local function ShakeCodeComponent()
				if Destroyed then return end
				ShakeToken += 1
				local Token = ShakeToken
				local Sequence = {-7, 6, -5, 4, -3, 2, -1, 0}
				for Index, Offset in ipairs(Sequence) do
					task.delay((Index - 1) * 0.03, function()
						if Destroyed or Token ~= ShakeToken then return end
						Header.Position = UDim2.fromOffset(Offset, 0)
						Body.Position = UDim2.fromOffset(5 + Offset, HeaderHeight)
					end)
				end
				if FlashTween then FlashTween:Cancel() end
				Body.BackgroundColor3 = BodyColor(Editable):Lerp(ErrorColor, 0.22)
				FlashTween = TweenService:Create(Body, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = BodyColor(Editable)})
				FlashTween:Play()
			end

			local function MeasureCaretWidth(Text)
				if Text == "" then return 0 end
				local Entry = Measurements[Text]
				if not Entry then
					if MeasurementCount >= 400 then
						for _, Previous in pairs(Measurements) do Previous.Label:Destroy() end
						table.clear(Measurements)
						MeasurementCount = 0
					end
					Entry = {Label = MakeMeasurement("MeasurePrefix", Text .. "M"), Ready = false}
					Measurements[Text] = Entry
					MeasurementCount += 1
					task.defer(function()
						if Destroyed or Measurements[Text] ~= Entry then return end
						Entry.Ready = true
						QueueGeometry()
					end)
				end
				local Width, ProbeWidth = Entry.Label.TextBounds.X, MeasureProbe.TextBounds.X
				if not Entry.Ready or Width <= 0 or ProbeWidth <= 0 then return nil end
				return math.max(0, Width - ProbeWidth) / EffectiveScale()
			end

			local MeasureWidth
			do
				local WidthProbe = "M"
				local WidthBounds = Vector2.new(1000000, 100000)
				local ProbeWidth = TextService:GetTextSize(WidthProbe, FontSize, Enum.Font.Code, WidthBounds).X
				MeasureWidth = function(Text)
					if Text == "" then return 0 end
					local Hit = WidthCache[Text]
					if Hit ~= nil then return Hit end
					local Width = math.max(0, TextService:GetTextSize(Text .. WidthProbe, FontSize, Enum.Font.Code, WidthBounds).X - ProbeWidth)
					if WidthCached >= 400 then
						table.clear(WidthCache)
						WidthCached = 0
					end
					WidthCache[Text] = Width
					WidthCached += 1
					return Width
				end
			end

			local function SyncGutter()
				if Destroyed then return end
				local Y = (Input.AbsolutePosition.Y - Gutter.AbsolutePosition.Y) / EffectiveScale()
				NumbersLayer.Position = UDim2.fromOffset(0, Y)
			end

			local function ClampCanvas(Position)
				local Maximum = Scroll.AbsoluteCanvasSize - Scroll.AbsoluteWindowSize
				return Vector2.new(
					math.clamp(Position.X, 0, math.max(0, Maximum.X)),
					math.clamp(Position.Y, 0, math.max(0, Maximum.Y))
				)
			end

			local function UpdateCanvas()
				if Destroyed then return end
				local View = ViewSize()
				if View.X < 1 or View.Y < 1 then return end
				local ProbeWidth = MeasureProbe.TextBounds.X
				local ContentWidth = MeasureContent.TextBounds.X
				local RenderedWidth = ContentWidth >= ProbeWidth and ProbeWidth > 0
					and (ContentWidth - ProbeWidth) / EffectiveScale() or MaxLineWidth
				local ContentX = math.max(0, RenderedWidth) + 12
				local ContentY = LineCount * LineHeight + Padding * 2
				local OverflowX = ContentX > View.X + 1
				local OverflowY = ContentY > View.Y + 1
				local Width = math.max(math.ceil(View.X), math.ceil(ContentX))
				local Height = math.max(math.ceil(View.Y), math.ceil(ContentY))
				Scroll.ScrollingEnabled = OverflowX or OverflowY
				Scroll.ScrollBarThickness = (OverflowX or OverflowY) and 2 or 0
				Scroll.ScrollingDirection = OverflowX and OverflowY and Enum.ScrollingDirection.XY
					or OverflowX and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
				Scroll.CanvasSize = UDim2.fromOffset(Width, Height)
				Input.Size = UDim2.fromOffset(math.max(Width - 2, View.X - 2), math.max(Height - Padding, View.Y - Padding))
				HighlightLayer.Size = Input.Size
				SelectionLayer.Size = Input.Size
				NumbersLayer.Size = UDim2.new(1, 0, 0, math.max(LineCount * LineHeight, View.Y))
				if not OverflowX and not OverflowY then
					Scroll.CanvasPosition = Vector2.zero
				else
					Scroll.CanvasPosition = ClampCanvas(Scroll.CanvasPosition)
				end
				SyncGutter()
			end

			local Types = {
				any = true, unknown = true, never = true, number = true, string = true,
				boolean = true, thread = true, buffer = true, vector = true,
				userdata = true, self = false
			}
			local ExtraGlobals = {
				require = true, unpack = true, rawget = true, rawset = true, rawequal = true,
				rawlen = true, setmetatable = true, getmetatable = true, collectgarbage = true,
				gcinfo = true, getfenv = true, setfenv = true, newproxy = true,
				_G = true, _VERSION = true, tick = true, time = true, elapsedTime = true,
				wait = true, spawn = true, delay = true, DateTime = true, Axes = true,
				Faces = true, Vector2int16 = true, Vector3int16 = true, PhysicalProperties = true,
				RaycastParams = true, OverlapParams = true, Random = true, Region3int16 = true,
				ColorSequenceKeypoint = true, NumberSequenceKeypoint = true, Font = true,
				vector = true, settings = true, UserSettings = true, version = true
			}
			local Operators = {
				["..."] = true, ["..="] = true, ["//="] = true,
				["=="] = true, ["~="] = true, ["<="] = true, [">="] = true,
				["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true,
				["%="] = true, ["^="] = true, ["//"] = true, [".."] = true,
				["::"] = true, ["->"] = true, ["<<"] = true, [">>"] = true,
				["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true,
				["%"] = true, ["^"] = true, ["#"] = true, ["="] = true,
				["<"] = true, [">"] = true, ["~"] = true, ["&"] = true,
				["|"] = true, ["?"] = true
			}

			local function HighlightCode(Source, State)
				local Colors = Palette
				local Output, Stack, Index, Length, Previous = {}, {}, 1, #Source, nil
				local ExpectTypeName, ExpectFunction, FinalContext = false, false, nil
				if type(State) == "string" then
					for Mode in State:gmatch("[^|]+") do
						if Mode == "b" or Mode:match("^i%d+$") or Mode:match("^[sc]=*$") or Mode:match("^q[\"']z?$") then
							Stack[#Stack + 1] = Mode
						end
					end
				end
				local function Add(Text, Kind)
					if Text == "" then return end
					local Last = Output[#Output]
					if Last and Last[3] == Kind and (Kind == "String" or Kind == "Comment" or Kind == "Plain") then
						Last[1] ..= Text
					else
						Output[#Output + 1] = {Text, Colors[Kind], Kind}
					end
				end
				local function EscapeEnd(Start)
					local Next = Source:sub(Start + 1, Start + 1)
					if Next == "u" and Source:sub(Start + 2, Start + 2) == "{" then
						local Finish = Source:find("}", Start + 3, true)
						if Finish then return Finish + 1 end
					elseif Next == "x" then
						local Digits = Source:sub(Start + 2, Start + 3):match("^%x%x")
						if Digits then return Start + 4 end
					elseif Next:match("%d") then
						return Start + 1 + #Source:sub(Start + 1, Start + 3):match("^%d+")
					end
					return math.min(Length + 1, Start + 2)
				end
				local function NumberEnd(Start)
					local Finish, Pattern = Start, "[%d_]"
					local Prefix = Source:sub(Start, Start + 1):lower()
					if Prefix == "0x" then
						Finish, Pattern = Start + 2, "[%x_]"
					elseif Prefix == "0b" then
						Finish, Pattern = Start + 2, "[01_]"
					end
					local DigitStart = Finish
					while Finish <= Length and Source:sub(Finish, Finish):match(Pattern) do Finish += 1 end
					if Finish > Start and DigitStart > Start and not Source:sub(DigitStart, Finish - 1):match("%x") then return Start + 1 end
					if Prefix ~= "0b" and Source:sub(Finish, Finish) == "." and Source:sub(Finish + 1, Finish + 1) ~= "." then
						Finish += 1
						while Finish <= Length and Source:sub(Finish, Finish):match(Pattern) do Finish += 1 end
					end
					local Exponent = Source:sub(Finish, Finish):lower()
					if Prefix ~= "0b" and Exponent == (Prefix == "0x" and "p" or "e") then
						local End = Finish + 1
						if Source:sub(End, End) == "+" or Source:sub(End, End) == "-" then End += 1 end
						local Digits = End
						while End <= Length and Source:sub(End, End):match("[%d_]") do End += 1 end
						if Source:sub(Digits, End - 1):match("%d") then Finish = End end
					end
					return math.max(Start + 1, Finish)
				end
				while Index <= Length do
					local Mode = Stack[#Stack]
					local Char = Source:sub(Index, Index)
					if Mode and (Mode:sub(1, 1) == "s" or Mode:sub(1, 1) == "c") then
						local Close = "]" .. Mode:sub(2) .. "]"
						local Finish = Source:find(Close, Index, true)
						local Last = Finish and Finish + #Close - 1 or Length
						Add(Source:sub(Index, Last), Mode:sub(1, 1) == "s" and "String" or "Comment")
						Index = Last + 1
						if Finish then table.remove(Stack) end
					elseif Mode == "b" then
						if Char == "`" then
							Add(Char, "String")
							Index += 1
							table.remove(Stack)
						elseif Char == "{" then
							Add(Char, "Operator")
							Index += 1
							Stack[#Stack + 1] = "i0"
							Previous = nil
						elseif Char == "\\" then
							local Finish = EscapeEnd(Index)
							Add(Source:sub(Index, Finish - 1), "Escape")
							Index = Finish
						else
							local Finish = Source:find("[\\`{]", Index) or Length + 1
							Add(Source:sub(Index, Finish - 1), "String")
							Index = Finish
						end
					elseif Mode and Mode:sub(1, 1) == "q" then
						local Quote = Mode:sub(2, 2)
						if Char == Quote then
							Add(Char, "String")
							Index += 1
							table.remove(Stack)
							Previous = "String"
						elseif Char == "\\" then
							local Finish = EscapeEnd(Index)
							Add(Source:sub(Index, Finish - 1), "Escape")
							if Source:sub(Index + 1, Index + 1) == "z" then
								local Whitespace = Source:sub(Finish):match("^%s*")
								Add(Whitespace, "String")
								Finish += #Whitespace
								Stack[#Stack] = "q" .. Quote .. "z"
							elseif Finish <= Length then
								Stack[#Stack] = "q" .. Quote
							end
							if Index == Length then Stack[#Stack] = "q" .. Quote .. "z" end
							Index = Finish
						else
							local Finish = Index
							while Finish <= Length do
								local Current = Source:sub(Finish, Finish)
								if Current == Quote or Current == "\\" then break end
								Finish += 1
							end
							Add(Source:sub(Index, Finish - 1), "String")
							if Source:sub(Index, Finish - 1):find("%S") then Stack[#Stack] = "q" .. Quote end
							Index = Finish
						end
					else
						local Rest = Source:sub(Index)
						local IsComment = Rest:sub(1, 2) == "--"
						local Equals = (IsComment and Rest:sub(3) or Rest):match("^%[(=*)%[")
						if Equals then
							local Prefix = #Equals + 2 + (IsComment and 2 or 0)
							Add(Rest:sub(1, Prefix), IsComment and "Comment" or "String")
							Stack[#Stack + 1] = (IsComment and "c" or "s") .. Equals
							Index += Prefix
						elseif IsComment then
							Add(Rest, "Comment")
							FinalContext = "c"
							Index = Length + 1
						elseif Char == "`" then
							Add(Char, "String")
							Stack[#Stack + 1] = "b"
							Index += 1
						elseif Char == '"' or Char == "'" then
							Add(Char, "String")
							Stack[#Stack + 1] = "q" .. Char
							Index += 1
						elseif Char:match("%s") then
							local Text = Rest:match("^%s+")
							Add(Text, "Plain")
							Index += #Text
						elseif Char:match("%d") or Char == "." and Source:sub(Index + 1, Index + 1):match("%d") then
							local Finish = NumberEnd(Index)
							Add(Source:sub(Index, Finish - 1), "Number")
							Index, Previous = Finish, "Number"
						elseif Char == "@" and Rest:match("^@[%a_]") then
							local Text = Rest:match("^@[%a_][%w_]*")
							Add(Text, "Attribute")
							Index += #Text
						else
							local Identifier = Rest:match("^[%a_][%w_]*")
							if Identifier then
								local After = Rest:sub(#Identifier + 1):match("^%s*(.*)")
								local Call = After:sub(1, 1) == "(" or After:sub(1, 1) == '"' or After:sub(1, 1) == "'" or After:match("^%[(=*)%[") ~= nil
								local Kind = "Plain"
								local Member = Previous == "." or Previous == ":"
								if Identifier == "nil" or Identifier == "true" or Identifier == "false" then
									Kind = "Literal"
								elseif ExpectTypeName then
									Kind, ExpectTypeName = "Type", false
								elseif Identifier == "type" then
									if not Member and After:match("^[%a_][%w_]*%s*[=<]") then
										Kind, ExpectTypeName = "Keyword", true
									else
										Kind = Member and (Call and "Function" or "Property") or "Global"
									end
								elseif Identifier == "export" then
									Kind = not Member and After:match("^type%f[^%w_]") and "Keyword" or (Member and "Property" or "Plain")
								elseif Identifier == "const" or Identifier == "continue" then
									Kind = not Member and not Call and After:sub(1, 1) ~= "=" and "Keyword" or (Call and "Function" or "Plain")
								elseif not Member and LuaKeywords[Identifier] then
									Kind = "Keyword"
								elseif ExpectFunction or Call then
									Kind = "Function"
								elseif Previous == "::" or Previous == ":" or Types[Identifier] and Previous ~= "." and not After:match("^%s*[.=:]") then
									Kind = "Type"
								elseif Previous == "." then
									Kind = "Property"
								elseif RobloxGlobals[Identifier] or ExtraGlobals[Identifier] then
									Kind = "Global"
								elseif After:sub(1, 1) == "=" or After:sub(1, 1) == ":" then
									Kind = "Plain"
								end
								Add(Identifier, Kind)
								if Identifier == "function" and Kind == "Keyword" then ExpectFunction = true end
								Previous, Index = Identifier, Index + #Identifier
							else
								local Token = Operators[Rest:sub(1, 3)] and Rest:sub(1, 3) or Operators[Rest:sub(1, 2)] and Rest:sub(1, 2) or Char
								local Kind = Operators[Token] and "Operator" or Token:match("^[%(%){%}%[%],:;%.]$") and "Punctuation" or "Plain"
								if Mode and Mode:sub(1, 1) == "i" then
									local Depth = tonumber(Mode:sub(2)) or 0
									if Token == "{" then
										Stack[#Stack] = "i" .. (Depth + 1)
									elseif Token == "}" then
										if Depth == 0 then
											Kind = "Operator"
											table.remove(Stack)
										else
											Stack[#Stack] = "i" .. (Depth - 1)
										end
									end
								end
								Add(Token, Kind)
								if Token == "(" or Token == "=" or Token == ";" then ExpectFunction = false end
								Previous, Index = Token, Index + #Token
							end
						end
					end
				end
				local Last = Stack[#Stack]
				FinalContext = FinalContext or Last
				if Last and Last:sub(1, 1) == "q" and Last:sub(3, 3) ~= "z" then table.remove(Stack) end
				return Output, #Stack > 0 and table.concat(Stack, "|") or nil, FinalContext
			end
			local function CodeContext(Source, Position)
				local Prefix = Source:sub(1, math.clamp(Position - 1, 0, #Source))
				local State, Context
				for Line in (Prefix .. "\n"):gmatch("(.-)\n") do
					local Tokens
					Tokens, State, Context = HighlightCode(Line, State)
				end
				if Context then
					local Mode = Context:sub(1, 1)
					if Mode == "q" then
						local Slashes = Prefix:match("(\\*)$") or ""
						return "string", Context:sub(2, 2), #Slashes % 2 == 1
					end
					if Mode == "b" then
						local Slashes = Prefix:match("(\\*)$") or ""
						return "string", "`", #Slashes % 2 == 1
					end
					if Mode == "s" then return "longstring" end
					if Mode == "c" then return "comment" end
				end
				return "code"
			end

			local function BuildRichLine(Tokens)
				local Parts = table.create(#Tokens)
				for Index, Segment in ipairs(Tokens) do
					local Value = EscapeRich(Segment[1])
					local Color = Segment[2]
					if Color then
						Value = string.format('<font color="#%02X%02X%02X">%s</font>',
							math.floor(Color.R * 255 + 0.5),
							math.floor(Color.G * 255 + 0.5),
							math.floor(Color.B * 255 + 0.5), Value)
					end
					Parts[Index] = Value
				end
				return table.concat(Parts)
			end

			local function CursorRow()
				if RenderedCode ~= Input.Text or Input.CursorPosition < 1 then return nil end
				local Position = math.clamp(Input.CursorPosition, 1, #Input.Text + 1)
				local Low, High, Row = 1, LineCount, 1
				while Low <= High do
					local Middle = math.floor((Low + High) / 2)
					if LineOffsets[Middle] <= Position then
						Row, Low = Middle, Middle + 1
					else
						High = Middle - 1
					end
				end
				return Row, Position
			end
			local function DrawVisibleLines()
				if Destroyed then return end
				local View = ViewSize()
				local HiddenY = (Scroll.AbsolutePosition.Y - Input.AbsolutePosition.Y) / EffectiveScale()
				local First = math.clamp(math.floor(HiddenY / LineHeight) + 1, 1, LineCount)
				local Last = math.min(LineCount, First + math.ceil(math.max(View.Y, LineHeight) / LineHeight) + 1)
				local ActiveRow = CodeConfig.GutterActiveLine and Editable and Focused and CursorRow() or nil
				if DrawnVersion == RenderVersion and DrawnFirst == First and DrawnLast == Last and DrawnActiveRow == ActiveRow then return end
				DrawnVersion, DrawnFirst, DrawnLast = RenderVersion, First, Last
				DrawnActiveRow = ActiveRow
				local Used = 0
				for Index = First, Last do
					Used += 1
					local Y = (Index - 1) * LineHeight
					local Number = NumberLabels[Used]
					if not Number then
						Number = Create("TextLabel", NumbersLayer, {
							Name = "Number",
							BackgroundTransparency = 1,
							Font = Enum.Font.Code,
							FontFace = Input.FontFace,
							TextSize = GutterFontSize,
							TextTransparency = CodeConfig.GutterNumberTransparency,
							TextXAlignment = Enum.TextXAlignment.Right,
							TextYAlignment = Enum.TextYAlignment.Center,
							TextWrapped = false,
							TextScaled = false,
							AutoLocalize = false,
							RichText = false
						})
						NumberLabels[Used] = Number
					end
					local HasError = DiagByLine[Index] ~= nil
					local IsActive = Index == ActiveRow
					Number.TextColor3 = HasError and ErrorColor or IsActive and Theme["Color Theme"] or Theme["Color Dark Text"]
					Number.TextTransparency = HasError and CodeConfig.GutterErrorNumberTransparency
						or IsActive and CodeConfig.GutterActiveNumberTransparency or CodeConfig.GutterNumberTransparency
					Number.Position = UDim2.fromOffset(CodeConfig.GutterPaddingLeft, Y)
					Number.Size = UDim2.fromOffset(math.max(1, GutterWidth - CodeConfig.GutterPaddingLeft - CodeConfig.GutterPaddingRight), LineHeight)
					Number.Text = tostring(Index)
					Number.Visible = true
					local Label = LineLabels[Used]
					if not Label then
						Label = Create("TextLabel", HighlightLayer, {
							Name = "SyntaxLine",
							BackgroundTransparency = 1,
							Font = Enum.Font.Code,
							FontFace = Input.FontFace,
							TextSize = FontSize,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							TextWrapped = false,
							RichText = true,
							TextScaled = false,
							AutoLocalize = false,
							ZIndex = 3
						})
						LineLabels[Used] = Label
					end
					Label.TextColor3 = Theme["Color Text"]
					Label.Position = UDim2.fromOffset(0, Y)
					Label.Size = UDim2.new(1, 0, 0, LineHeight)
					Label.Text = StyledLines[Index] or ""
					Label.Visible = true
				end
				for Index = Used + 1, #LineLabels do
					LineLabels[Index].Visible = false
				end
				for Index = Used + 1, #NumberLabels do
					NumberLabels[Index].Visible = false
				end
			end

			local function UpdateEditingAppearance()
				if Destroyed then return end
				Input.TextTransparency = 1
				HighlightLayer.Visible = true
			end
			local function CursorLocation()
				local Row, Position = CursorRow()
				if not Row then return nil end
				local X = MeasureCaretWidth(Lines[Row]:sub(1, Position - LineOffsets[Row]))
				if X == nil then return nil end
				if #Lines[Row] > 0 and Position - LineOffsets[Row] == #Lines[Row] then X += CodeConfig.CaretEndGap end
				return X, (Row - 1) * LineHeight, Row
			end
			local function EnsureCursorVisible()
				if Destroyed or not Editable or not Focused then return end
				local X, Y = CursorLocation()
				if X == nil then return end
				local Scale = EffectiveScale()
				local CaretX = Input.AbsolutePosition.X + X * Scale
				local CaretY = Input.AbsolutePosition.Y + Y * Scale
				local Left, Top = Scroll.AbsolutePosition.X, Scroll.AbsolutePosition.Y
				local Right = Left + Scroll.AbsoluteWindowSize.X
				local Bottom = Top + Scroll.AbsoluteWindowSize.Y
				local DeltaX, DeltaY = 0, 0
				if CaretX + 6 * Scale > Right then DeltaX = CaretX + 6 * Scale - Right end
				if CaretX < Left then DeltaX = CaretX - Left end
				if CaretY + LineHeight * Scale > Bottom then DeltaY = CaretY + LineHeight * Scale - Bottom end
				if CaretY < Top then DeltaY = CaretY - Top end
				if Scroll.ScrollingEnabled and (DeltaX ~= 0 or DeltaY ~= 0) then
					Scroll.CanvasPosition = ClampCanvas(Scroll.CanvasPosition + Vector2.new(DeltaX, DeltaY))
				end
			end

			local function StopBlink()
				BlinkToken += 1
				if CaretFadeTween then
					CaretFadeTween:Cancel()
					CaretFadeTween = nil
				end
			end
			local function StartBlink()
				StopBlink()
				local Token = BlinkToken
				Caret.BackgroundTransparency = 0
				task.spawn(function()
					local Fade = TweenInfo.new(CodeConfig.CaretBlinkFadeDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					while not Destroyed and Token == BlinkToken do
						task.wait(CodeConfig.CaretBlinkOnDuration)
						if Destroyed or Token ~= BlinkToken then return end
						CaretFadeTween = TweenService:Create(Caret, Fade, {BackgroundTransparency = 1})
						CaretFadeTween:Play()
						task.wait(CodeConfig.CaretBlinkFadeDuration + CodeConfig.CaretBlinkOffDuration)
						if Destroyed or Token ~= BlinkToken then return end
						CaretFadeTween = TweenService:Create(Caret, Fade, {BackgroundTransparency = 0})
						CaretFadeTween:Play()
						task.wait(CodeConfig.CaretBlinkFadeDuration)
					end
				end)
			end
			local LastCaret = {}
			local function UpdateCaret()
				if Destroyed then return end
				DrawVisibleLines()
				local WasVisible = Caret.Visible
				local Selecting = Input.SelectionStart > 0 and Input.SelectionStart ~= Input.CursorPosition
				local X, Y, Row
				if Editable and Focused and not Selecting then X, Y, Row = CursorLocation() end
				Caret.Visible = X ~= nil
				if X == nil then
					StopBlink()
					if CaretMoveTween then
						CaretMoveTween:Cancel()
						CaretMoveTween = nil
					end
					LastCaret.X, LastCaret.Y = nil, nil
					return
				end
				local Scale = EffectiveScale()
				local function Snap(Value) return math.floor(Value * Scale + 0.5) / Scale end
				local Width = math.max(1, math.floor(Option.CaretWidth * Scale + 0.5)) / Scale
				local Height = Snap(math.clamp(FontSize + 1, 6, math.max(6, LineHeight - 1)))
				local XPos = Snap(2.5 + Option.CaretNudge + X)
				local YPos = Snap(Padding + Y + (LineHeight - Height) * 0.5)
				local Target = UDim2.fromOffset(XPos, YPos)
				Caret.Size = UDim2.fromOffset(Width, Height)
				local Moved = X ~= LastCaret.X or Y ~= LastCaret.Y or Scale ~= LastCaret.Scale
				if not WasVisible or Scale ~= LastCaret.Scale or Row ~= LastCaret.Row or not Option.SmoothCaret then
					if CaretMoveTween then CaretMoveTween:Cancel() end
					CaretMoveTween = nil
					Caret.Position = Target
				elseif Moved then
					if CaretMoveTween then CaretMoveTween:Cancel() end
					CaretMoveTween = TweenService:Create(Caret, TweenInfo.new(CodeConfig.CaretMoveDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = Target})
					CaretMoveTween:Play()
				end
				if not WasVisible or Moved then StartBlink() end
				LastCaret.X, LastCaret.Y, LastCaret.Scale = X, Y, Scale
				LastCaret.Row = Row
			end
			local function UpdateSelection()
				if Destroyed then return end
				local Cursor, Anchor = Input.CursorPosition, Input.SelectionStart
				local Used = 0
				if Editable and Focused and RenderedCode == Input.Text and Cursor > 0 and Anchor > 0 and Cursor ~= Anchor then
					local Low, High = math.min(Cursor, Anchor), math.max(Cursor, Anchor)
					for Index = DrawnFirst, DrawnLast do
						local Line, Offset = Lines[Index], LineOffsets[Index]
						if Line and Offset then
							if Offset >= High then break end
							local Left = math.clamp(Low - Offset, 0, #Line)
							local Right = math.clamp(High - Offset, 0, #Line)
							local Newline = Index < LineCount and Low <= Offset + #Line and High > Offset + #Line
							if Right > Left or Newline then
								local X1 = MeasureCaretWidth(Line:sub(1, Left))
								local X2 = MeasureCaretWidth(Line:sub(1, Right))
								if X1 ~= nil and X2 ~= nil then
									Used += 1
									local Frame = SelectionFrames[Used]
									if not Frame then
										Frame = Create("Frame", SelectionLayer, {
											Name = "Selection",
											BorderSizePixel = 0,
											BackgroundColor3 = Theme["Color Theme"],
											BackgroundTransparency = 0.72,
											ZIndex = 2
										})
										SelectionFrames[Used] = Frame
									end
									if Newline then X2 += math.max(4, MeasureProbe.TextBounds.X / EffectiveScale()) end
									Frame.Position = UDim2.fromOffset(X1, (Index - 1) * LineHeight)
									Frame.Size = UDim2.fromOffset(math.max(1, X2 - X1), LineHeight)
									Frame.Visible = true
								end
							end
						end
					end
				end
				for Index = Used + 1, #SelectionFrames do SelectionFrames[Index].Visible = false end
			end
			local GeometryQueued = false
			QueueGeometry = function()
				if Destroyed or GeometryQueued then return end
				GeometryQueued = true
				task.defer(function()
					GeometryQueued = false
					if Destroyed then return end
					local Advance = (MeasureTen.TextBounds.Y - MeasureTwo.TextBounds.Y) / (8 * EffectiveScale())
					if Advance > 0 and math.abs(Advance - LineHeight) > 0.01 then
						LineHeight = Advance
						QueueRefresh()
					end
					UpdateCanvas()
					UpdateCaret()
					UpdateSelection()
					EnsureCursorVisible()
				end)
			end

			local function UpdateModified()
				if ResetButton then
					local Show = EditAllowed and Editable and Input.Text ~= InitialCode
					ResetButton.Button.Visible = Show
					if not Show and (ResetButton.Hover or ResetButton.Press) then
						ResetButton.Hover, ResetButton.Press = false, false
						ResetButton.Update(true)
					end
				end
				UpdateActions()
			end

			local ErrorTip, ErrorTipText, ErrorTipToken, ErrorTipPoint = nil, nil, 0, nil

			local function SplitLines(Source)
				local Result = {}
				for Line in (Source .. "\n"):gmatch("(.-)\n") do Result[#Result + 1] = Line end
				return Result
			end
			local function ParseErrorLine(Message)
				local First = tostring(Message or ""):match("^[^\r\n]*") or ""
				local Line, Column, Text = First:match(":(%d+):(%d+):%s*(.*)")
				if Line then return tonumber(Line), Text, tonumber(Column) end
				Line, Text = First:match(":(%d+):%s*(.*)")
				if Line then return tonumber(Line), Text end
				return nil, First
			end
			local function MakeLineDiagnostic(SourceLines, Line, Message, Kind, Column)
				Line = math.clamp(math.floor(tonumber(Line) or #SourceLines), 1, math.max(1, #SourceLines))
				local Text = SourceLines[Line] or ""
				local Start = Text:find("%S") or 1
				local Finish = math.max(Start, #(Text:match("^(.-)%s*$")))
				if Column then
					Start = math.clamp(math.floor(Column), 1, #Text + 1)
					Finish = Start
					Column = Start
				else
					local Near = tostring(Message):match("[Nn]ear%s+['\"]([^'\"]+)['\"]")
					if Near then
						local Position = Text:find(Near, 1, true)
						if Position and not Text:find(Near, Position + 1, true) then
							Start, Finish, Column = Position, Position + #Near - 1, Position
						end
					end
				end
				return {Line = Line, Column = Column, Start = Start, End = Finish, Message = Message, Kind = Kind}
			end
			local function CompilerDiagnostics(Source, SourceLines)
				local Loader = loadstring
				if type(Loader) ~= "function" and type(getgenv) == "function" then
					local Okay, Environment = pcall(getgenv)
					Loader = Okay and type(Environment) == "table" and Environment.loadstring or nil
				end
				if type(Loader) ~= "function" then return nil end
				local Found, Masked, WorkingLines = {}, {}, nil
				local Candidate = Source
				local Limit = math.floor(NumberOption(ReadOption("MaxDiagnostics"), CodeConfig.MaxDiagnostics or 12, 1, 30))
				for _ = 1, Limit do
					local Okay, Compiled, Message = pcall(Loader, Candidate, "=AddCode")
					if not Okay then
						if #Found == 0 then return nil end
						break
					end
					if Compiled then break end
					local Line, Text, Column = ParseErrorLine(Message)
					if not Line or Line < 1 or Line > #SourceLines then
						if #Found == 0 then
							Found[1] = MakeLineDiagnostic(SourceLines, Line or #SourceLines, Text ~= "" and Text or "Syntax error", "compiler", Column)
						end
						break
					end
					if Masked[Line] then break end
					local OriginalLine = SourceLines[Line]
					Text = Text ~= "" and Text or "Syntax error"
					local Identifier = OriginalLine:match("^%s*([%a_][%w_]*)%s*$")
					local Lower = Text:lower()
					if Identifier and (Lower:find("incomplete statement", 1, true)
						or Lower:find("expected assignment", 1, true)) then
						Text ..= " (near '" .. Identifier .. "')"
					end
					Found[#Found + 1] = MakeLineDiagnostic(SourceLines, Line, Text, "compiler", Column)
					Masked[Line] = true
					if not OriginalLine:find("%S") then break end
					if not WorkingLines then WorkingLines = table.clone(SourceLines) end
					WorkingLines[Line] = ""
					Candidate = table.concat(WorkingLines, "\n")
				end
				table.sort(Found, function(A, B)
					if A.Line ~= B.Line then return A.Line < B.Line end
					return A.Start < B.Start
				end)
				return Found
			end
			local function LexicalDiagnostics(SourceLines)
				local Found, Stack, State, OpenLine = {}, {}, nil, nil
				local function Report(Line, Start, Finish, Message)
					if #Found < 6 then
						Found[#Found + 1] = {
							Line = Line, Column = Start, Start = Start, End = Finish,
							Message = Message, Kind = "lexical"
						}
					end
				end
				for LineNumber, Line in ipairs(SourceLines) do
					local Tokens, NextState, Context = HighlightCode(Line, State)
					if NextState and not State then OpenLine = LineNumber elseif not NextState then OpenLine = nil end
					State = NextState
					local Column, StringStart = 1, nil
					for _, Token in ipairs(Tokens) do
						local Text, Kind = Token[1], Token[3]
						if Kind == "Punctuation" or Kind == "Operator" then
							for Offset = 1, #Text do
								local Symbol = Text:sub(Offset, Offset)
								local At = Column + Offset - 1
								if PairClose[Symbol] then
									Stack[#Stack + 1] = {Symbol, LineNumber, At}
								elseif Symbol == ")" or Symbol == "]" or Symbol == "}" then
									local Top = Stack[#Stack]
									if Top and PairClose[Top[1]] == Symbol then
										table.remove(Stack)
									elseif Top then
										Report(LineNumber, At, At,
											"Unexpected '" .. Symbol .. "'; expected '" .. PairClose[Top[1]]
											.. "' to close '" .. Top[1] .. "' from line " .. Top[2] .. ", column " .. Top[3])
									else
										Report(LineNumber, At, At, "Unexpected closing '" .. Symbol .. "' without an opening delimiter")
									end
								end
							end
						elseif Kind == "String" and Text:find("^[\"']") then
							StringStart = Column
						end
						Column += #Text
					end
					if Context and Context:sub(1, 1) == "q" and Context:sub(3, 3) ~= "z" then
						Report(LineNumber, StringStart or 1, math.max(#Line, 1),
							"Unterminated string; missing closing " .. Context:sub(2, 2))
					end
				end
				if State then
					local Kind = (State:match("[^|]+$") or ""):sub(1, 1)
					local Message = Kind == "c" and "Unterminated block comment"
						or Kind == "s" and "Unterminated long string"
						or Kind == "b" and "Unterminated template string"
						or "Unterminated string or interpolation"
					if #Found < 6 then
						Found[#Found + 1] = MakeLineDiagnostic(SourceLines, OpenLine or #SourceLines, Message, "lexical")
					end
				end
				for _, Entry in ipairs(Stack) do
					Report(Entry[2], Entry[3], Entry[3],
						"Unclosed '" .. Entry[1] .. "'; missing '" .. PairClose[Entry[1]] .. "'")
				end
				table.sort(Found, function(A, B)
					if A.Line ~= B.Line then return A.Line < B.Line end
					return A.Start < B.Start
				end)
				return Found
			end
			local function CollectDiagnostics(Source)
				if not IsLuaLanguage() then return {} end
				local SourceLines = SplitLines(Source)
				return CompilerDiagnostics(Source, SourceLines) or LexicalDiagnostics(SourceLines)
			end
			local function ExportDiagnostics(Source)
				local Result = {}
				for _, Diagnostic in ipairs(Source) do
					Result[#Result + 1] = {Line = Diagnostic.Line, Column = Diagnostic.Column, Message = Diagnostic.Message, Kind = Diagnostic.Kind}
				end
				return Result
			end


			local function HideErrorTip()
				ErrorTipToken += 1
				if ErrorTip then ErrorTip.Visible = false end
			end
			local function PositionErrorTip()
				if not ErrorTip or not ErrorTip.Visible or not ErrorTipPoint then return end
				local Scale = EffectiveScale()
				local ViewOrigin, View = ScreenGui.AbsolutePosition, ScreenGui.AbsoluteSize
				local Size = ErrorTip.AbsoluteSize
				local Margin = 4 * Scale
				local X = ErrorTipPoint.X + 12 * Scale
				local Y = ErrorTipPoint.Y + 18 * Scale
				local MinX, MinY = ViewOrigin.X + Margin, ViewOrigin.Y + Margin
				local MaxX = math.max(MinX, ViewOrigin.X + View.X - Size.X - Margin)
				local MaxY = math.max(MinY, ViewOrigin.Y + View.Y - Size.Y - Margin)
				X = math.clamp(X, MinX, MaxX)
				if Y + Size.Y > ViewOrigin.Y + View.Y - Margin then
					Y = ErrorTipPoint.Y - Size.Y - 8 * Scale
				end
				Y = math.clamp(Y, MinY, MaxY)
				local HeaderOrigin = Header.AbsolutePosition
				ErrorTip.Position = UDim2.fromOffset((X - HeaderOrigin.X) / Scale, (Y - HeaderOrigin.Y) / Scale)
			end
			local function ShowErrorTip(Diagnostic, Point, Duration)
				if Destroyed or not Diagnostic or not Holder.Visible then return end
				if not ErrorTip then
					ErrorTip = InsertTheme(Create("Frame", Header, {
						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UDim2.fromOffset(0, 0),
						BackgroundColor3 = Theme["Color Hub 2"],
						BorderSizePixel = 0,
						Visible = false,
						ZIndex = 3000
					}), "Frame")
					Make("Corner", ErrorTip, UDim.new(0, 6))
					InsertTheme(Create("UIStroke", ErrorTip, {
						Color = Theme["Color Theme"],
						Thickness = StrokeThickness,
						Transparency = CodeConfig.ErrorTip.StrokeTransparency,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						LineJoinMode = Enum.LineJoinMode.Round
					}), "Theme")
					Create("UIPadding", ErrorTip, {
						PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
						PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)
					})
					ErrorTipText = InsertTheme(Create("TextLabel", ErrorTip, {
						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UDim2.fromOffset(0, 0),
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamMedium,
						TextSize = 10,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						RichText = false,
						TextColor3 = Theme["Color Text"],
						ZIndex = 3001
					}), "Text")
					Create("UISizeConstraint", ErrorTipText, {MaxSize = Vector2.new(280, 400)})
					ErrorTip:GetPropertyChangedSignal("AbsoluteSize"):Connect(PositionErrorTip)
				end
				local Values = {Line = tostring(Diagnostic.Line), Column = tostring(Diagnostic.Column or ""), Error = tostring(Diagnostic.Message)}
				ErrorTipText.Text = TranslateText(Diagnostic.Column and "Line {Line}, column {Column}: {Error}" or "Line {Line}: {Error}", Values)
				ErrorTipPoint = Point
				ErrorTip.Visible = true
				PositionErrorTip()
				ErrorTipToken += 1
				local Token = ErrorTipToken
				if Duration then
					task.delay(Duration, function()
						if not Destroyed and ErrorTip and Token == ErrorTipToken then HideErrorTip() end
					end)
				end
			end
			local function DiagnosticAtText(Point)
				if #Shown == 0 or RenderedCode ~= Input.Text then return nil end
				local Scale = EffectiveScale()
				local X = (Point.X - Input.AbsolutePosition.X) / Scale
				local Y = (Point.Y - Input.AbsolutePosition.Y) / Scale
				local Row = math.floor(Y / LineHeight) + 1
				local Line = Lines[Row]
				if not Line or Y < 0 or Y >= LineCount * LineHeight then return nil end
				for _, Diagnostic in ipairs(Shown) do
					if Diagnostic.Line == Row then
						local StartX = MeasureWidth(Line:sub(1, Diagnostic.Start - 1))
						local EndX = math.max(StartX + 6, MeasureWidth(Line:sub(1, Diagnostic.End)))
						if X >= StartX - 3 and X <= EndX + 3 then return Diagnostic end
					end
				end
				return nil
			end

			local function RebuildShown()
				table.clear(Shown)
				table.clear(DiagByLine)
				if ErrorEnabled then
					for _, Diagnostic in ipairs(Diagnostics) do Shown[#Shown + 1] = Diagnostic end
					if RuntimeDiagnostic then Shown[#Shown + 1] = RuntimeDiagnostic end
				end
				for _, Diagnostic in ipairs(Shown) do
					if not DiagByLine[Diagnostic.Line] then DiagByLine[Diagnostic.Line] = Diagnostic end
				end
				ErrorBadge.Visible = #Shown > 0
				ErrorBadge.BackgroundColor3 = ErrorColor
				UpdateActions()
				HideErrorTip()
			end
			local function RedrawErrors()
				DrawnVersion = -1
				DrawVisibleLines()
			end
			local function RunDiagnostics()
				if Destroyed or not ErrorEnabled then return end
				local Source = Input.Text
				local Found = CollectDiagnostics(Source)
				if Destroyed or Source ~= Input.Text then return end
				Diagnostics = Found
				RebuildShown()
				RedrawErrors()
			end
			QueueDiagnostics = function(Delay)
				if Destroyed then return end
				DiagToken += 1
				if not ErrorEnabled then return end
				local Token = DiagToken
				task.delay(Delay or 0.35, function()
					if Destroyed or Token ~= DiagToken then return end
					RunDiagnostics()
				end)
			end
			local function InvalidateDiagnostics()
				if RuntimeDiagnostic then
					RuntimeDiagnostic = nil
					RebuildShown()
					RedrawErrors()
				end
				QueueDiagnostics()
			end
			local function SetRuntimeError(Message)
				if not ErrorEnabled then return end
				local Line, Text, Column = ParseErrorLine(Message)
				if not Line or Line < 1 then return end
				local SourceLines = SplitLines(Input.Text)
				if Line > #SourceLines then return end
				RuntimeDiagnostic = MakeLineDiagnostic(SourceLines, Line, Text, "runtime", Column)
				RebuildShown()
				RedrawErrors()
			end

			local function Refresh()
				if Destroyed then return end
				table.clear(Lines)
				table.clear(StyledLines)
				table.clear(LineOffsets)

				RenderedCode = Input.Text
				local Highlight = IsLuaLanguage()
				local State
				local Offset = 1
				local MeasureLines = {}
				MaxLineWidth = 0
				for Line in (Input.Text .. "\n"):gmatch("(.-)\n") do
					local Index = #Lines + 1
					Lines[Index] = Line
					MeasureLines[Index] = Line .. "M"
					LineOffsets[Index] = Offset
					Offset += #Line + 1
					MaxLineWidth = math.max(MaxLineWidth, MeasureWidth(Line))

					local Key = tostring(State or "") .. "\0" .. Line
					local CachedLine = HighlightCache[Key]
					if not CachedLine then
						local Rich, NextState = EscapeRich(Line), nil
						if Highlight and type(HighlightCode) == "function" then
							local Success, Tokens, TokenState = pcall(HighlightCode, Line, State)
							if Success and type(Tokens) == "table" then
								local RawParts, Valid = {}, true
								for _, Segment in ipairs(Tokens) do
									if type(Segment) ~= "table" or type(Segment[1]) ~= "string" then
										Valid = false
										break
									end
									RawParts[#RawParts + 1] = Segment[1]
								end
								if Valid and table.concat(RawParts) == Line then
									local Built, Result = pcall(BuildRichLine, Tokens)
									if Built then Rich = Result end
								end
								NextState = TokenState
							end
						end
						CachedLine = {Rich, NextState}
						HighlightCache[Key] = CachedLine
						Cached += 1
					end
					StyledLines[Index], State = CachedLine[1], CachedLine[2]
				end
				if Cached >= 600 then
					table.clear(HighlightCache)
					Cached = 0
				end

				local MeasuredSource = EscapeRich(table.concat(MeasureLines, "\n"))
				MeasurementTexts[MeasureContent] = MeasuredSource
				MeasureContent.Text = MeasuredSource
				LineCount = #Lines
				RenderVersion += 1
				GutterWidth = math.ceil(math.max(CodeConfig.GutterWidth, TextService:GetTextSize(string.rep("9", #tostring(LineCount)), GutterFontSize, Enum.Font.Code, Vector2.new(10000, 10000)).X + CodeConfig.GutterPaddingLeft + CodeConfig.GutterPaddingRight))
				Gutter.Size = UDim2.new(0, GutterWidth, 1, 0)
				Scroll.Position = UDim2.fromOffset(GutterWidth, 0)
				Scroll.Size = UDim2.new(1, -GutterWidth - 2, 1, 0)
				local NewHeight = math.ceil(HeaderHeight + BottomPadding + Padding * 2 + math.min(LineCount, MaxVisibleLines) * LineHeight)
				Holder.Size = UDim2.new(1, 0, 0, NewHeight)
				UpdateCanvas()
				DrawVisibleLines()
				UpdateCaret()
				UpdateSelection()
				EnsureCursorVisible()
			end

			QueueRefresh = function()
				if RefreshQueued or Destroyed then return end
				RefreshQueued = true
				task.defer(function()
					RefreshQueued = false
					if not Destroyed then Refresh() end
				end)
			end

			local function ControlDown()
				return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			end
			local function ShiftDown()
				return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			end
			local function MatchingCloser(Source, Position, Character)
				local Stack, State = {}, nil
				for Line in (Source:sub(1, Position - 1) .. "\n"):gmatch("(.-)\n") do
					local Tokens
					Tokens, State = HighlightCode(Line, State)
					for _, Token in ipairs(Tokens) do
						if Token[3] == "Punctuation" or Token[3] == "Operator" then
							for Symbol in Token[1]:gmatch(".") do
								if PairClose[Symbol] then
									Stack[#Stack + 1] = PairClose[Symbol]
								elseif Symbol == ")" or Symbol == "]" or Symbol == "}" then
									if Stack[#Stack] ~= Symbol then return false end
									table.remove(Stack)
								end
							end
						end
					end
				end
				return Stack[#Stack] == Character
			end
			local function ExpectedCloser(Source, Position)
				local Character = Source:sub(Position, Position)
				if Character == "[" then
					local Equals = Source:sub(1, Position - 1):match("%[(=*)$")
					if Equals then return "]" .. Equals .. "]" end
				end
				return PairOpen[Character]
			end
			local function MoveAutoClosers(Previous, Text)
				if Previous == Text then return end
				local First = 1
				while First <= math.min(#Previous, #Text) and Previous:byte(First) == Text:byte(First) do First += 1 end
				local OldLast, NewLast = #Previous, #Text
				while OldLast >= First and NewLast >= First and Previous:byte(OldLast) == Text:byte(NewLast) do
					OldLast -= 1
					NewLast -= 1
				end
				local Delta = #Text - #Previous
				local NextClosers = {}
				for Position, Character in pairs(AutoClosers) do
					local NextPosition = Position < First and Position or Position > OldLast and Position + Delta
					if NextPosition and Text:sub(NextPosition, NextPosition) == Character then NextClosers[NextPosition] = Character end
				end
				AutoClosers = NextClosers
			end

			local function SmartNewline(Source, Position)
				local OpenWords = {["then"] = true, ["do"] = true, ["else"] = true, ["repeat"] = true}
				local LineStart = 1
				for Index = Position - 1, 1, -1 do
					if Source:byte(Index) == 10 then
						LineStart = Index + 1
						break
					end
				end
				local Before = Source:sub(LineStart, Position - 1)
				local After = Source:match("^[^\n]*", Position) or ""
				local Indent = Before:match("^[ \t]*") or ""
				local Opens, Last = false, nil
				if CodeContext(Source, Position) == "code" then
					local Tokens = HighlightCode(Before, nil)
					local LastKind, HasFunction, HasEnd
					for _, Token in ipairs(Tokens) do
						local Kind = Token[3]
						if Kind ~= "Plain" and Kind ~= "Comment" then
							Last, LastKind = Token[1], Kind
							if Kind == "Keyword" then
								if Token[1] == "function" then HasFunction = true elseif Token[1] == "end" then HasEnd = true end
							end
						end
					end
					if Last then
						if OpenWords[Last] and LastKind == "Keyword" then
							Opens = true
						elseif PairClose[Last] and LastKind == "Punctuation" then
							Opens = true
						elseif Last == ")" and HasFunction and not HasEnd then
							Opens = true
						end
					end
				end
				local Skip = #(After:match("^[ \t]*") or "")
				local Next = After:match("^[ \t]*(.?)") or ""
				local Head, Tail = Source:sub(1, Position - 1), Source:sub(Position + Skip)
				if Opens and PairClose[Last] and PairClose[Last] == Next then
					return Head .. "\n" .. Indent .. IndentUnit .. "\n" .. Indent .. Tail, 1 + #Indent + #IndentUnit
				end
				local Insert = "\n" .. Indent .. (Opens and IndentUnit or "")
				return Head .. Insert .. Tail, #Insert
			end

			local function PushHistory(Text, Force)
				local Now = os.clock()
				if Force or #UndoStack == 0 or Now - LastHistoryTime > 0.7 then
					if UndoStack[#UndoStack] ~= Text then
						UndoStack[#UndoStack + 1] = Text
						if #UndoStack > 100 then table.remove(UndoStack, 1) end
					end
				end
				LastHistoryTime = Now
				table.clear(RedoStack)
			end
			local function ApplyText(Target)
				local Current = Input.Text
				local Limit = math.min(#Current, #Target)
				local Prefix = 0
				while Prefix < Limit and Current:byte(Prefix + 1) == Target:byte(Prefix + 1) do Prefix += 1 end
				local Suffix = 0
				while Suffix < Limit - Prefix and Current:byte(#Current - Suffix) == Target:byte(#Target - Suffix) do Suffix += 1 end
				ObservedCode = Target
				table.clear(AutoClosers)
				Input.Text = Target
				Input.SelectionStart = -1
				Input.CursorPosition = ClampCursor(#Target - Suffix + 1, Target)
				LastHistoryTime = 0
				UpdateModified()
				Refresh()
				InvalidateDiagnostics()
				if OnChange then task.spawn(OnChange, Target) end
			end
			local function StepHistory(From, To)
				if Destroyed or not Editable then return false end
				FlushText()
				local Target = table.remove(From)
				if Target == nil then return false end
				To[#To + 1] = Input.Text
				ApplyText(Target)
				return true
			end

			FlushText = function()
				if Destroyed then return end
				TextQueued = false
				local Raw = Input.Text
				local Text = NormalizeCode(Raw)
				local Cursor, Selection = Input.CursorPosition, Input.SelectionStart
				if Raw ~= Text then
					if Cursor > 0 then Cursor = #NormalizeCode(Raw:sub(1, Cursor - 1)) + 1 end
					if Selection > 0 then Selection = #NormalizeCode(Raw:sub(1, Selection - 1)) + 1 end
				end
				local Previous = ObservedCode
				local QuoteEdit = false
				local NewCloserPosition, NewCloser
				if Editable and (Focused or TextWasEditing) and not PastePending and not (ControlDown() and UserInputService:IsKeyDown(Enum.KeyCode.V)) then
					if #Text == #Previous + 1 then
						local Position = Cursor - 1
						local function IsInsertion(Index)
							local Character = Text:sub(Index, Index)
							return Index >= 1 and Index <= #Previous + 1 and (PairOpen[Character] ~= nil or ClosingCharacters[Character] or AutoClosers[Index] == Character or Character == "\n" or Character == "\t")
								and Previous:sub(1, Index - 1) .. Character .. Previous:sub(Index) == Text
						end
						if not IsInsertion(Position) then
							Position = 1
							while Position <= #Previous and Previous:sub(Position, Position) == Text:sub(Position, Position) do Position += 1 end
						end
						if IsInsertion(Position) then
							local Character = Text:sub(Position, Position)
							if Character == "\n" then
								local Rebuilt, Offset = SmartNewline(Previous, Position)
								Text, Cursor, Selection, QuoteEdit = Rebuilt, Position + Offset, -1, true
							elseif Character == "\t" then
								if IndentUnit ~= "\t" then
									Text = Previous:sub(1, Position - 1) .. IndentUnit .. Previous:sub(Position)
									Cursor, Selection, QuoteEdit = Position + #IndentUnit, -1, true
								end
							else
								local Mode, Delimiter, Escaped = CodeContext(Previous, Position)
								local ExistingCloser = Previous:sub(Position, Position) == Character
								local SkipQuote = Mode == "string" and Delimiter == Character and not Escaped
								local SkipBracket = Mode == "code" and ClosingCharacters[Character]
									and MatchingCloser(Previous, Position, Character)
								local SkipLongString = Mode == "longstring" and AutoClosers[Position] == Character
								if ExistingCloser and (SkipQuote or SkipBracket or SkipLongString) then
									Text, Cursor, Selection, QuoteEdit = Previous, Position + 1, -1, true
									AutoClosers[Position] = nil
								elseif PairOpen[Character] and (Mode == "code" or Mode == "string" and Delimiter == "`" and Character == "{" and not Escaped) then
									local TrackedClosing = ExpectedCloser(Text, Position)
									local Closing = TrackedClosing
									if Character == "[" and TrackedClosing ~= "]" and Previous:sub(Position, Position) == "]" then
										Closing = TrackedClosing:sub(1, -2)
									end
									Text = Text:sub(1, Position) .. Closing .. Text:sub(Position + 1)
									Cursor, Selection, QuoteEdit = Position + 1, -1, true
									NewCloserPosition, NewCloser = Position + 1, TrackedClosing
								end
							end
						end
					elseif #Text == #Previous - 1 then
						local Position = Cursor
						local function IsDeletion(Index)
							return Index >= 1 and Index <= #Previous
								and Previous:sub(1, Index - 1) .. Previous:sub(Index + 1) == Text
						end
						if not IsDeletion(Position) then
							Position = 1
							while Position <= #Text and Previous:byte(Position) == Text:byte(Position) do Position += 1 end
						end
						if IsDeletion(Position) then
							local Closing = ExpectedCloser(Previous, Position)
							if Closing and Previous:sub(Position + 1, Position + #Closing) == Closing then
								Text = Previous:sub(1, Position - 1) .. Previous:sub(Position + #Closing + 1)
								Cursor, Selection, QuoteEdit = Position, -1, true
							elseif Position > 1 then
								Closing = ExpectedCloser(Previous, Position - 1)
								if Closing and Previous:sub(Position, Position + #Closing - 1) == Closing then
									Text = Previous:sub(1, Position - 2) .. Previous:sub(Position + #Closing)
									Cursor, Selection, QuoteEdit = Position - 1, -1, true
								end
							end
						end
					end
				end
				PastePending, TextWasEditing = false, false
				local Changed = ObservedCode ~= Text
				MoveAutoClosers(Previous, Text)
				if NewCloserPosition then
					for Offset = 1, #NewCloser do AutoClosers[NewCloserPosition + Offset - 1] = NewCloser:sub(Offset, Offset) end
				end
				ObservedCode = Text
				if Input.Text ~= Text then Input.Text = Text end
				if Raw ~= Text or QuoteEdit then
					if Cursor > 0 then Input.CursorPosition = ClampCursor(Cursor, Text) end
					Input.SelectionStart = Selection > 0 and ClampCursor(Selection, Text) or -1
				end
				if Changed then
					PushHistory(Previous)
					InvalidateDiagnostics()
				end
				UpdateModified()
				QueueRefresh()
				if Changed and OnChange then task.spawn(OnChange, Text) end
			end
			Input:GetPropertyChangedSignal("Text"):Connect(function()
				if Destroyed then return end
				TextWasEditing = TextWasEditing or Editable and Focused
				if TextQueued then return end
				TextQueued = true
				task.defer(function() if TextQueued and not Destroyed then FlushText() end end)
			end)
			Input:GetPropertyChangedSignal("CursorPosition"):Connect(function()
				if not Destroyed and Editable then QueueGeometry() end
			end)
			Input:GetPropertyChangedSignal("SelectionStart"):Connect(QueueGeometry)
			Input.Focused:Connect(function()
				if Destroyed then return end
				if not Editable then Input:ReleaseFocus(); return end
				Focused = true
				QueueGeometry()
			end)
			Input.FocusLost:Connect(function(_, Cause)
				TextWasEditing = TextWasEditing or Editable and Focused and Input.Text ~= ObservedCode
				Focused = false
				UpdateCaret()
				UpdateSelection()
				local KeepEditing = false
				if Cause and (Cause.UserInputType == Enum.UserInputType.MouseButton1 or Cause.UserInputType == Enum.UserInputType.Touch) then
					local Point, Position, Size = Cause.Position, Holder.AbsolutePosition, Holder.AbsoluteSize
					KeepEditing = Point.X >= Position.X and Point.Y >= Position.Y and Point.X < Position.X + Size.X and Point.Y < Position.Y + Size.Y
				end
				task.defer(function()
					if not Destroyed and Editable and not Input:IsFocused() and not ActionPointer and not KeepEditing then Code:EditClose() end
				end)
			end)
			local function UpdateViewport()
				if Destroyed then return end
				SyncGutter()
				DrawVisibleLines()
				UpdateCaret()
				UpdateSelection()
			end
			Scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(UpdateViewport)
			Input:GetPropertyChangedSignal("AbsolutePosition"):Connect(UpdateViewport)
			local function ResizeViewport()
				if Destroyed then return end
				UpdateCanvas()
				UpdateViewport()
				EnsureCursorVisible()
			end
			Scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(ResizeViewport)
			Scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(ResizeViewport)
			Input:GetPropertyChangedSignal("TextBounds"):Connect(function()
				if Destroyed then return end
				UpdateCanvas()
				QueueGeometry()
			end)

			function Code:SetCode(Value)
				if Destroyed then return nil end
				local NewCode = NormalizeCode(Value)
				local Cursor = Input.CursorPosition
				SavedCode, ObservedCode = NewCode, NewCode
				table.clear(AutoClosers)
				table.clear(UndoStack)
				table.clear(RedoStack)
				if Input.Text ~= NewCode then Input.Text = NewCode end
				Input.SelectionStart = -1
				if Cursor > 0 then Input.CursorPosition = ClampCursor(Cursor, NewCode) end
				UpdateModified()
				Refresh()
				InvalidateDiagnostics()
				return NewCode
			end
			Code.Set = Code.SetCode
			function Code:GetCode() return Input.Text end
			function Code:SetTitle(Value)
				if Destroyed then return nil end
				TitleSource = DisplayString(Value)
				TitleText = TranslateText(TitleSource)
				FileName.Text = TitleText
			end
			function Code:SetLanguage(Value)
				if Destroyed then return nil end
				Language = tostring(Value or CodeConfig.Language)
				table.clear(HighlightCache)
				Cached = 0
				Refresh()
				InvalidateDiagnostics()
				return Language
			end
			function Code:GetLanguage() return Language end
			function Code:SetEditable(Value)
				if Destroyed then return false end
				if Value == true and (not EditAllowed or (self.IsLocked and self:IsLocked())) then return false end
				if Value ~= true and Editable then FlushText() end
				if Editable == (Value == true) then return Editable end
				Editable = Value == true
				Input.TextEditable = Editable
				UpdateEditingAppearance()
				if EditButton then
					EditButton.Selected = Editable
					EditButton.Icon.Image = Library:GetIcon("pencil")
					EditButton.Update()
				end
				UpdateModified()
				if Editable then
					Input:CaptureFocus()
				else
					Focused = false
					if Input:IsFocused() then Input:ReleaseFocus() end
				end
				if BodyTween then BodyTween:Cancel() end
				BodyTween = TweenService:Create(Body, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = BodyColor(Editable)
				})
				BodyTween:Play()
				QueueGeometry()
				return Editable
			end
			function Code:IsEditable() return Editable end
			function Code:CanEdit() return EditAllowed end
			function Code:SetEdit(Value)
				if Destroyed then return false end
				EditAllowed = Value == true
				EditButton.Button.Visible = EditAllowed
				if not EditAllowed then self:EditClose() end
				UpdateModified()
				return EditAllowed
			end
			Code.SetEditEnabled = Code.SetEdit
			function Code:EditOpen() return self:SetEditable(true) end
			function Code:EditClose()
				if Destroyed then return false end
				FlushText()
				return self:SetEditable(false)
			end
			function Code:GetSavedCode() return SavedCode end
			function Code:GetOriginalCode() return InitialCode end
			function Code:IsModified() return Input.Text ~= InitialCode end
			function Code:Save()
				if Destroyed then return false, "Destroyed" end
				if self.IsLocked and self:IsLocked() then self:NotifyLocked(); return false, "Locked" end
				if not EditAllowed then return false, "Editing is disabled." end
				if Saving then return false, "Saving is already in progress." end
				FlushText()
				local Source = Input.Text
				Saving = true
				local Called, Result, Error = true, nil, nil
				if OnSave then Called, Result, Error = pcall(OnSave, Source, self) end
				Saving = false
				if Destroyed then return false, "Destroyed" end
				if not Called or Result == false then
					local Reason = tostring(not Called and Result or Error or "Save rejected.")
					ShowToastMessage("Code save failed: {Error}", {Error = Reason})
					ShakeCodeComponent()
					if Editable and not Input:IsFocused() then Input:CaptureFocus() end
					return false, Reason
				end
				SavedCode = Source
				UpdateModified()
				if Input.Text == Source then self:EditClose() end
				return true, Source
			end
			function Code:Reset()
				if Destroyed then return false, "Destroyed" end
				if not EditAllowed then return false, "Editing is disabled." end
				if self.IsLocked and self:IsLocked() then self:NotifyLocked(); return false, "Locked" end
				FlushText()
				local Cursor = Input.CursorPosition
				local Changed = Input.Text ~= InitialCode
				if Changed then PushHistory(Input.Text, true) end
				ObservedCode = InitialCode
				table.clear(AutoClosers)
				Input.Text = InitialCode
				Input.SelectionStart = -1
				if Cursor > 0 then Input.CursorPosition = ClampCursor(Cursor, InitialCode) end
				UpdateModified()
				Refresh()
				InvalidateDiagnostics()
				if Changed and OnChange then task.spawn(OnChange, InitialCode) end
				return true
			end
			function Code:Undo() return StepHistory(UndoStack, RedoStack) end
			function Code:Redo() return StepHistory(RedoStack, UndoStack) end
			function Code:Shake() ShakeCodeComponent() end
			function Code:SetError(Value)
				if Destroyed then return false end
				ErrorEnabled = Value == true
				Diagnostics, RuntimeDiagnostic = {}, nil
				RebuildShown()
				RedrawErrors()
				if ErrorEnabled then QueueDiagnostics(0.05) end
				return ErrorEnabled
			end
			Code.SetShowErrors = Code.SetError
			function Code:IsErrorEnabled() return ErrorEnabled end
			function Code:HasError() return #Shown > 0 end
			function Code:GetErrors()
				return ExportDiagnostics(Shown)
			end
			function Code:Check()
				if Destroyed then return {} end
				FlushText()
				if ErrorEnabled then
					RunDiagnostics()
					return self:GetErrors()
				end
				return ExportDiagnostics(CollectDiagnostics(Input.Text))
			end
			function Code:SetExecuteEnabled(Value)
				if Destroyed then return false end
				CanExecute = Value == true
				ExecuteButton.Button.Visible = CanExecute
				UpdateActions()
				return CanExecute
			end
			function Code:CanExecute() return CanExecute end
			Code.SetExecute = Code.SetExecuteEnabled
			function Code:SetCopyEnabled(Value)
				if Destroyed then return false end
				CanCopy = Value == true
				if CopyButton then CopyButton.Button.Visible = CanCopy end
				UpdateActions()
				return CanCopy
			end
			function Code:CanCopy() return CanCopy end
			Code.SetCopy = Code.SetCopyEnabled
			local function AnimateCopy(Duration, Rotation, Scale, Transparency)
				for _, Animation in ipairs(CopyTweens) do Animation:Cancel() end
				table.clear(CopyTweens)
				CopyTweens[1] = TweenService:Create(CopyButton.Icon,
					TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Rotation = Rotation, ImageTransparency = Transparency})
				CopyTweens[2] = TweenService:Create(CopyButton.IconScale,
					TweenInfo.new(Duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{Scale = Scale})
				for _, Animation in ipairs(CopyTweens) do Animation:Play() end
			end
			function Code:Copy()
				if Destroyed then return false, "Destroyed" end
				if self.IsLocked and self:IsLocked() then self:NotifyLocked(); return false, "Locked" end
				if not CanCopy then return false, "Copy is disabled." end
				if type(Hub) ~= "table" or type(Hub.SetClipboard) ~= "function" then return false, "Clipboard API is unavailable." end
				FlushText()
				local Called, Success, Error = pcall(Hub.SetClipboard, Hub, Input.Text)
				if not Called then ShowToastMessage("Code copy failed: {Error}", {Error = tostring(Success)}); return false, Success end
				if not Success then ShowToastMessage("Code copy failed: {Error}", {Error = tostring(Error or "Clipboard unavailable.")}) end
				if Success and CopyButton then
					CopyToken += 1
					local Token = CopyToken
					for _, Animation in ipairs(CopyTweens) do Animation:Cancel() end
					CopyButton.Icon.Image = Library:GetIcon("copy")
					CopyButton.Icon.Rotation, CopyButton.Icon.ImageTransparency = 0, 0
					CopyButton.IconScale.Scale = 1
					AnimateCopy(0.12, -25, 0.7, 1)
					task.delay(0.12, function()
						if Destroyed or Token ~= CopyToken then return end
						CopyButton.Icon.Image = Library:GetIcon("check")
						CopyButton.Icon.Rotation = 18
						AnimateCopy(0.2, 0, 1.15, 0)
					end)
					task.delay(0.34, function()
						if not Destroyed and Token == CopyToken then AnimateCopy(0.12, 0, 1, 0) end
					end)
					task.delay(0.8, function()
						if not Destroyed and Token == CopyToken then AnimateCopy(0.12, 25, 0.7, 1) end
					end)
					task.delay(0.92, function()
						if Destroyed or Token ~= CopyToken then return end
						CopyButton.Icon.Image = Library:GetIcon("copy")
						CopyButton.Icon.Rotation = -18
						AnimateCopy(0.18, 0, 1, 0)
					end)
				end
				return Success, Error
			end
			function Code:Execute()
				if Destroyed then return false, "Destroyed" end
				if self.IsLocked and self:IsLocked() then self:NotifyLocked(); return false, "Locked" end
				if not CanExecute then return false, "Code execution is disabled." end
				if Executing then return false, "Code execution is already running." end
				if type(Hub) ~= "table" or type(Hub.Execute) ~= "function" then return false, "Code execution API is unavailable." end
				FlushText()

				if ErrorEnabled and Option.BlockOnError then
					local Found = CollectDiagnostics(Input.Text)
					local First = Found[1]
					if First and First.Kind == "compiler" then
						Diagnostics, RuntimeDiagnostic = Found, nil
						RebuildShown()
						RedrawErrors()
						ShakeCodeComponent()
						return false, First.Message
					end
				end
				Executing = true
				ExecutionToken += 1
				local Token, Started = ExecutionToken, os.clock()
				if SpinTween then SpinTween:Cancel() end
				ExecuteButton.Icon.Rotation = 0
				SpinTween = TweenService:Create(ExecuteButton.Icon,
					TweenInfo.new(ExecuteSpinDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
					{Rotation = -360})
				SpinTween:Play()
				local Called, Success, Result = pcall(Hub.Execute, Hub, Input.Text, TitleText)
				if not Called then Success, Result = false, Success end
				Executing = false
				if not Destroyed then
					local function FinishAnimation()
						if Destroyed or Token ~= ExecutionToken then return end
						if SpinTween then SpinTween:Cancel(); SpinTween = nil end
						ExecuteButton.Icon.Rotation = 0
					end
					local Remaining = ExecuteSpinDuration - (os.clock() - Started)
					if Remaining > 0 then task.delay(Remaining, FinishAnimation) else FinishAnimation() end
					if not Success then
						local ErrorText = tostring(Result)
						SetRuntimeError(ErrorText)
						if #ErrorText > 120 then ErrorText = ErrorText:sub(1, 117) .. "..." end
						ShowToastMessage("Code execution failed: {Error}", {Error = ErrorText})
						ShakeCodeComponent()
					end
				end
				return Success, Result
			end
			function Code:IsExecuting() return Executing end
			function Code:Visible(Value)
				if not Destroyed then
					Funcs:ToggleVisible(Holder, Value)
					if not Holder.Visible then
						self:EditClose()
						HideErrorTip()
					end
				end
			end
			function Code:Destroy()
				if Destroyed then return end
				Destroyed = true
				Holder:Destroy()
			end

			ExecuteButton.Button.Activated:Connect(function()
				if Destroyed or Executing then return end
				task.spawn(function() Code:Execute() end)
			end)

			if EditButton then
				EditButton.Button.Activated:Connect(function()
					if Destroyed then return end
					if Editable then Code:Save() else Code:EditOpen() end
				end)
			end
			if CopyButton then CopyButton.Button.Activated:Connect(function() Code:Copy() end) end
			if ResetButton then
				ResetButton.Button.Activated:Connect(function()
					local Success = Code:Reset()
					if Success and Editable and not Destroyed then
						Input:CaptureFocus()
						Input.CursorPosition = #Input.Text + 1
					end
				end)
			end
			local function Inside(Object, Point)
				local Position, Size = Object.AbsolutePosition, Object.AbsoluteSize
				return Point.X >= Position.X and Point.Y >= Position.Y and Point.X < Position.X + Size.X and Point.Y < Position.Y + Size.Y
			end
			local function IsPointer(InputObject)
				return InputObject.UserInputType == Enum.UserInputType.MouseButton1 or InputObject.UserInputType == Enum.UserInputType.Touch
			end

			Input.InputChanged:Connect(function(InputObject)
				if Destroyed or InputObject.UserInputType ~= Enum.UserInputType.MouseMovement then return end
				local Diagnostic = DiagnosticAtText(InputObject.Position)
				if Diagnostic then ShowErrorTip(Diagnostic, InputObject.Position) else HideErrorTip() end
			end)
			Input.InputBegan:Connect(function(InputObject)
				if Destroyed or not IsPointer(InputObject) then return end
				local Diagnostic = DiagnosticAtText(InputObject.Position)
				if Diagnostic then ShowErrorTip(Diagnostic, InputObject.Position, CodeConfig.ErrorTip.Duration) end
			end)
			Input.MouseLeave:Connect(HideErrorTip)
			ExternalConnections[#ExternalConnections + 1] = Container:GetPropertyChangedSignal("Visible"):Connect(function()
				if not Container.Visible then HideErrorTip() end
			end)
			ExternalConnections[#ExternalConnections + 1] = Holder:GetPropertyChangedSignal("Visible"):Connect(function()
				if not Holder.Visible then HideErrorTip() end
			end)

			ExternalConnections[#ExternalConnections + 1] = UserInputService.InputBegan:Connect(function(InputObject)
				if Destroyed then return end
				if IsPointer(InputObject) then
					if Editable and not Inside(Holder, InputObject.Position) then
						task.defer(function() if not Destroyed and Editable and not ActionPointer then Code:EditClose() end end)
					end
				elseif Editable and UserInputService:GetFocusedTextBox() == Input then
					local KeyCode = InputObject.KeyCode
					if ControlDown() and KeyCode == Enum.KeyCode.V
						or KeyCode == Enum.KeyCode.Insert and ShiftDown() then
						PastePending = true
					elseif ControlDown() and KeyCode == Enum.KeyCode.S then
						Code:Save()
					elseif ControlDown() and KeyCode == Enum.KeyCode.Z then
						if ShiftDown() then Code:Redo() else Code:Undo() end
					elseif ControlDown() and KeyCode == Enum.KeyCode.Y then
						Code:Redo()
					end
				end
			end)
			ExternalConnections[#ExternalConnections + 1] = UserInputService.InputEnded:Connect(function(InputObject)
				if Destroyed then return end
				if InputObject.KeyCode == Enum.KeyCode.V or InputObject.KeyCode == Enum.KeyCode.Insert then
					task.defer(function() if not Destroyed and not TextQueued then PastePending = false end end)
				end
				if IsPointer(InputObject) then
					task.defer(function()
						if Destroyed then return end
						local RestoreFocus = ActionPointer and Editable
						ActionPointer = false
						if RestoreFocus and not Input:IsFocused() then Input:CaptureFocus() end
					end)
				end
			end)
			ExternalConnections[#ExternalConnections + 1] = UserInputService.WindowFocusReleased:Connect(function()
				ActionPointer = false
				if not Destroyed and Editable then Code:EditClose() end
			end)

			local LanguageConnection = Connection.LanguageChanged:Connect(function()
				task.defer(function()
					if Destroyed then return end
					TitleText = TranslateText(TitleSource)
					FileName.Text = TitleText
					HideErrorTip()
					DrawnVersion = -1
					DrawVisibleLines()
				end)
			end)
			local ThemeConnection = Connection.ThemeChanged:Connect(function()
				if Destroyed then return end
				UpdatePalette()
				Body.BackgroundColor3 = BodyColor(Editable)
				Scroll.ScrollBarImageColor3 = Theme["Color Theme"]
				for _, Entry in ipairs(Buttons) do Entry.Update(true) end
				for _, Frame in ipairs(SelectionFrames) do Frame.BackgroundColor3 = Theme["Color Theme"] end
				Input.TextColor3 = Theme["Color Text"]
				Caret.BackgroundColor3 = Theme["Color Theme"]
				ErrorBadge.BackgroundColor3 = ErrorColor
				table.clear(HighlightCache)
				Cached = 0
				table.clear(WidthCache)
				WidthCached = 0
				Refresh()
			end)
			Holder.Destroying:Connect(function()
				Destroyed = true
				if ErrorTip then ErrorTip:Destroy(); ErrorTip = nil end
				ThemeConnection:Disconnect()
				LanguageConnection:Disconnect()
				for _, Link in ipairs(ExternalConnections) do Link:Disconnect() end
				table.clear(ExternalConnections)
				BlinkToken += 1
				DiagToken += 1
				ErrorTipToken += 1
				if CaretFadeTween then CaretFadeTween:Cancel() end
				if CaretMoveTween then CaretMoveTween:Cancel() end
				if FlashTween then FlashTween:Cancel() end
				CopyToken += 1
				ExecutionToken += 1
				ShakeToken += 1
				table.clear(AutoClosers)
				for _, Animation in ipairs(CopyTweens) do Animation:Cancel() end
				table.clear(CopyTweens)
				if SpinTween then SpinTween:Cancel() end
				if BodyTween then BodyTween:Cancel() end
				for _, Entry in ipairs(Buttons) do
					if Entry.TintTween then Entry.TintTween:Cancel() end
					if Entry.ScaleTween then Entry.ScaleTween:Cancel() end
				end
				table.clear(HighlightCache)
				table.clear(WidthCache)
				table.clear(LineLabels)
				table.clear(NumberLabels)
				table.clear(SelectionFrames)
				table.clear(Measurements)
				table.clear(MeasurementTexts)
				table.clear(Lines)
				table.clear(StyledLines)
				table.clear(LineOffsets)
				table.clear(UndoStack)
				table.clear(RedoStack)
				table.clear(Shown)
				table.clear(DiagByLine)
			end)
			ApplyLocked(Code, Holder, Configs, function(Locked)
				if Locked then HideErrorTip() end
				if Locked and Editable then Code:SetEditable(false) end
			end)
			function Code:NotifyLocked()
				local Message = self.GetLockedMessage and self:GetLockedMessage() or Configs.LockedMessage or LibraryConfig.LockedMessage
				ShowToastMessage(Message)
			end
			Refresh()
			UpdateEditingAppearance()
			UpdateActions()
			for _, Entry in ipairs(Buttons) do Entry.Update(true) end
			QueueGeometry()
			QueueDiagnostics(0.1)
			return RegisterFlagObject(Configs.Flag, Code, Holder)
		end
		function Tab:AddDiscordInvite(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local Title = TranslateText(tostring(Configs[1] or Configs.Name or Configs.Title or ControlsConfig.Titles.Discord))
			local Desc = TranslateText(tostring(Configs.Desc or Configs.Description or ""))
			local Logo = ResolveGuiImage(Configs[2] or Configs.Logo or RootConfig.Image)
			local Invite = Configs[3] or Configs.Invite or ""
			
			local InviteHolder = Create("Frame", ElementParent, {
				Size = UDim2.new(1, 0, 0, 80),
				BackgroundTransparency = 1
			})
			
			local InviteLabel = Create("TextLabel", InviteHolder, {
				Size = UDim2.new(1, 0, 0, 15),
				Position = UDim2.new(0, 5),
				TextColor3 = ControlColors.Link,
				Font = Enum.Font.GothamBold,
				TextXAlignment = "Left",
				BackgroundTransparency = 1,
				TextSize = 10,
				Text = Invite
			})
			
			local FrameHolder = InsertTheme(Create("Frame", InviteHolder, {
				Size = UDim2.new(1, 0, 0, 65),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1),
				BackgroundColor3 = Theme["Color Hub 2"]
			}), "Frame")Make("Corner", FrameHolder)
			
			local ImageLabel = Create("ImageLabel", FrameHolder, {
				Size = UDim2.new(0, 30, 0, 30),
				Position = UDim2.new(0, 7, 0, 7),
				Image = Logo,
				BackgroundTransparency = 1
			})Make("Corner", ImageLabel, UDim.new(0, 4))Make("Stroke", ImageLabel)
			
			local LTitle = InsertTheme(Create("TextLabel", FrameHolder, {
				Size = UDim2.new(1, -52, 0, 15),
				Position = UDim2.new(0, 42, 0, 5),
				Font = Enum.Font.GothamBold,
				TextColor3 = Theme["Color Text"],
				TextXAlignment = "Left",
				BackgroundTransparency = 1,
				TextSize = 10,
				Text = Title
			}), "Text")
			
			local LDesc = InsertTheme(Create("TextLabel", FrameHolder, {
				Size = UDim2.new(1, -52, 0, 0),
				Position = UDim2.new(0, 44, 0, 22),
				TextWrapped = "Y",
				AutomaticSize = "Y",
				Font = Enum.Font.Gotham,
				TextColor3 = Theme["Color Dark Text"],
				TextXAlignment = "Left",
				BackgroundTransparency = 1,
				TextSize = 8,
				Text = Desc
			}), "DarkText")
			
			local JoinButton = Create("TextButton", FrameHolder, {
				Size = UDim2.new(1, -14, 0, 16),
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -7),
				Text = TranslateText("Join"),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = ControlColors.JoinText,
				BackgroundColor3 = ControlColors.Join
			})Make("Corner", JoinButton, UDim.new(0, 5))
			
			local ClickDelay
			JoinButton.Activated:Connect(function()
				if ClickDelay then return end

				local Success = type(Hub) == "table" and type(Hub.SetClipboard) == "function" and Hub:SetClipboard(Invite)
				if not Success then
					ShowToastMessage("Clipboard API is unavailable.")
					return
				end
				
				ClickDelay = true
				SetProps(JoinButton, {
					Text = TranslateText("Copied to Clipboard"),
					BackgroundColor3 = ControlColors.JoinDisabled,
					TextColor3 = ControlColors.JoinDisabledText
				})
				task.delay(5, function()
					if not JoinButton.Parent then return end
					SetProps(JoinButton, {
						Text = TranslateText("Join"),
						BackgroundColor3 = ControlColors.Join,
						TextColor3 = ControlColors.JoinText
					})
					ClickDelay = false
				end)
			end)
			
			local DiscordInvite = {}
			function DiscordInvite:Destroy() InviteHolder:Destroy() end
			function DiscordInvite:Visible(...) Funcs:ToggleVisible(InviteHolder, ...) end
			function DiscordInvite:SetTitle(Value)
				LTitle.Text = TranslateText(DisplayString(Value))
			end
			function DiscordInvite:SetDesc(Value)
				LDesc.Text = TranslateText(DisplayString(Value))
			end

			ApplyLocked(DiscordInvite, InviteHolder, Configs)
			return RegisterFlagObject(Configs.Flag, DiscordInvite, InviteHolder)
		end
		for _, MethodName in ipairs({
			"AddSection", "AddDivider", "AddParagraph", "AddButton", "AddToggle", "AddDropdown",
			"AddPlayers", "AddSelector", "AddProgressBar", "AddSlider", "AddTextBox", "AddTextArea", "AddKeybind",
			"AddColorPicker", "AddCode", "AddDiscordInvite"
		}) do
			local CreateElement = Tab[MethodName]
			Tab[MethodName] = function(Self, ...)
				if Self._Destroyed then return nil end
				local Owner = MethodName ~= "AddSection" and CurrentContentSection or nil
				local Element = CreateElement(Self, ...)
				if type(Element) == "table" and type(Element.Destroy) == "function" then
					local OriginalDestroy = Element.Destroy
					local Destroyed = false
					TabElements[Element] = true
					if Owner then Owner._Elements[Element] = true end
					Element.Destroy = function(Object, ...)
						if Destroyed then return end
						Destroyed = true
						TabElements[Object] = nil
						if Owner then Owner._Elements[Object] = nil end
						return OriginalDestroy(Object, ...)
					end
				end
				return Element
			end
		end
		return Tab
	end

	local function GetLanguageOptions()
		local Languages = Library:GetLanguages()
		local Options = {}
		local CodeByName = {}

		for Code, Name in pairs(Languages) do
			local Display = tostring(Name)
			Options[#Options + 1] = Display
			CodeByName[Display] = Code
		end

		table.sort(Options)
		return Options, CodeByName
	end

	function Window:GetConfigTab()
		return ConfigTab
	end

	function Window:ConfigBtn()
		if ConfigTab and not ConfigTab._Destroyed then
			if ActiveTab ~= ConfigTab then
				Window:SelectTab(ConfigTab)
			end
			return ConfigTab
		end
		if not ConfigTab then
			ConfigTab = Window:MakeTab({
				Title = TranslateText("Settings"),
				Icon = "settings",
				Hidden = true
			})

			local InterfaceSection = ConfigTab:AddSection(TranslateText("Interface"))

			local ThemeDropdown = ConfigTab:AddDropdown({
				Title = TranslateText("Theme"),
				Options = Library:GetThemes(),
				Default = Library:GetTheme(),
				AllowNone = false,
				Callback = function(Value)
					if type(Value) == "string" then
						Library:SetTheme(Value)
					end
				end
			})

			local LanguageOptions, CodeByName = GetLanguageOptions()
			local Languages = Library:GetLanguages()
			local CurrentLanguage = Library:GetLanguage()
			local CurrentLanguageName = tostring(Languages[CurrentLanguage] or CurrentLanguage)

			local LanguageDropdown = ConfigTab:AddDropdown({
				Title = TranslateText("Language"),
				Options = LanguageOptions,
				Default = CurrentLanguageName,
				AllowNone = false,
				Callback = function(Value)
					local Code = CodeByName[tostring(Value)]
					if Code then
						Library:SetLanguage(Code)
					end
				end
			})


			local ExtraLabels = {}
			WindowKeybindControl = ConfigTab:AddKeybind({
				Name = TranslateText("Hub keybind"),
				Value = Window:GetKeybind(),
				Toggle = false,
				OnChanged = function(Key)
					Window:SetKeybind(Key)
				end
			})
			if WindowKeybindControl then
				ExtraLabels[#ExtraLabels + 1] = {WindowKeybindControl, "Hub keybind"}
			end

			local WindowSection = ConfigTab:AddSection(TranslateText("Window"))
			ExtraLabels[#ExtraLabels + 1] = {WindowSection, "Window"}

			local CurrentSize = Window:GetSize()
			SettingsWindowWidth = ConfigTab:AddSlider({
				Name = TranslateText("Window width"),
				Min = MinWidth, Max = MaxWidth, Increase = 1,
				Default = CurrentSize.X,
				Callback = function(Value)
					local Size = Window:GetSize()
					Window:SetSize(Value, Size.Y)
				end
			})
			ExtraLabels[#ExtraLabels + 1] = {SettingsWindowWidth, "Window width"}

			SettingsWindowHeight = ConfigTab:AddSlider({
				Name = TranslateText("Window height"),
				Min = MinHeight, Max = MaxHeight, Increase = 1,
				Default = CurrentSize.Y,
				Callback = function(Value)
					local Size = Window:GetSize()
					Window:SetSize(Size.X, Value)
				end
			})
			ExtraLabels[#ExtraLabels + 1] = {SettingsWindowHeight, "Window height"}

			SettingsTabWidth = ConfigTab:AddSlider({
				Name = TranslateText("Tab width"),
				Min = MinTabSize, Max = MaxTabSize, Increase = 1,
				Default = Window:GetTabSize(),
				Callback = function(Value) Window:SetTabSize(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {SettingsTabWidth, "Tab width"}

			local MinimizedWidthControl = ConfigTab:AddSlider({
				Name = TranslateText("Minimized width"),
				Min = 160, Max = math.min(320, MaxWidth), Increase = 1,
				Default = Window:GetMinimizedWidth(),
				Callback = function(Value) Window:SetMinimizedWidth(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {MinimizedWidthControl, "Minimized width"}

			local HubTransparency = ConfigTab:AddSlider({
				Name = TranslateText("Transparency"),
				Min = 0, Max = 100, Increase = 1,
				Default = Library:GetTransparency(),
				Callback = function(Value) Library:SetTransparency(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {HubTransparency, "Transparency"}

			local DraggableControl = ConfigTab:AddToggle({
				Name = TranslateText("Draggable window"),
				Default = Window:IsDraggable(),
				Callback = function(Value) Window:SetDraggable(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {DraggableControl, "Draggable window"}

			local ResizableControl = ConfigTab:AddToggle({
				Name = TranslateText("Resizable window"),
				Default = Window:IsResizable(),
				Callback = function(Value) Window:SetResizable(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {ResizableControl, "Resizable window"}

			local TabResizableControl = ConfigTab:AddToggle({
				Name = TranslateText("Resizable tabs"),
				Default = Window:IsTabResizable(),
				Callback = function(Value) Window:SetTabResizable(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {TabResizableControl, "Resizable tabs"}

			Library._BackgroundSettings.CreateControls(ConfigTab, ExtraLabels)

			local KeybindSection = ConfigTab:AddSection(TranslateText("Keybinds"))
			ExtraLabels[#ExtraLabels + 1] = {KeybindSection, "Keybinds"}
			local KeybindIconControl = ConfigTab:AddToggle({
				Name = TranslateText("Show keybind icons"),
				Default = Library:GetKeybindIconDefault(),
				Callback = function(Value) Library:SetKeybindIconDefault(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {KeybindIconControl, "Show keybind icons"}
			local KeybindWidthControl = ConfigTab:AddSlider({
				Name = TranslateText("Keybind button width"),
				Min = 32, Max = 96, Increase = 1,
				Default = Library:GetKeybindWidth(),
				Callback = function(Value) Library:SetKeybindWidth(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {KeybindWidthControl, "Keybind button width"}
			local KeybindHighlightControl = ConfigTab:AddToggle({
				Name = TranslateText("Highlight active keybinds"),
				Default = Library:GetKeybindHighlight(),
				Callback = function(Value) Library:SetKeybindHighlight(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {KeybindHighlightControl, "Highlight active keybinds"}
			local KeybindRightClickControl = ConfigTab:AddToggle({
				Name = TranslateText("Capture keybind on right click"),
				Default = Library:GetKeybindRightClick(),
				Callback = function(Value) Library:SetKeybindRightClick(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {KeybindRightClickControl, "Capture keybind on right click"}

			local SectionSettings = ConfigTab:AddSection(TranslateText("Sections"))
			ExtraLabels[#ExtraLabels + 1] = {SectionSettings, "Sections"}

			local SectionIndicatorToggle = ConfigTab:AddToggle({
				Name = TranslateText("Apply indicators to sections"),
				Default = Library.Save.SectionIndicator,
				Callback = function(Value) Library:SetSectionSetting("SectionIndicator", Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {SectionIndicatorToggle, "Apply indicators to sections"}

			for _, Option in ipairs({
				{"Section height", "SectionHeight"},
				{"Section text size", "SectionTextSize"},
				{"Indicator thickness", "SectionThickness"},
				{"Indicator height", "SectionIndicatorHeight"},
				{"Indicator spacing", "SectionSpacing"}
			}) do
				local Name, Key = Option[1], Option[2]
				local Range = Library.SectionRanges[Key]
				local Control = ConfigTab:AddSlider({
					Name = TranslateText(Name),
					Min = Range[1], Max = Range[2], Increase = 1,
					Default = Library.Save[Key],
					Callback = function(Value) Library:SetSectionSetting(Key, Value) end
				})
				ExtraLabels[#ExtraLabels + 1] = {Control, Name}
			end

			local ScrollingSection = ConfigTab:AddSection(TranslateText("Scrolling"))
			ExtraLabels[#ExtraLabels + 1] = {ScrollingSection, "Scrolling"}

			local ScrollThicknessControl = ConfigTab:AddSlider({
				Name = TranslateText("Scrollbar thickness"),
				Min = 0, Max = 12, Increase = 0.5,
				Default = Library:GetScrollThickness(),
				Callback = function(Value) Library:SetScrollThickness(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {ScrollThicknessControl, "Scrollbar thickness"}

			local ScrollTransparencyControl = ConfigTab:AddSlider({
				Name = TranslateText("Scrollbar transparency"),
				Min = 0, Max = 100, Increase = 1,
				Default = Library:GetScrollTransparency(),
				Callback = function(Value) Library:SetScrollTransparency(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {ScrollTransparencyControl, "Scrollbar transparency"}

			local AudioSection = ConfigTab:AddSection(TranslateText("Audio"))
			ExtraLabels[#ExtraLabels + 1] = {AudioSection, "Audio"}

			local SoundEnabledControl = ConfigTab:AddToggle({
				Name = TranslateText("UI sounds"),
				Default = Library:IsSoundEnabled(),
				Callback = function(Value) Library:SetSoundEnabled(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {SoundEnabledControl, "UI sounds"}

			local SoundPresetIndex = EnsureSoundPreset(tostring(Library:GetSoundId()))

			local SoundPresetControl = ConfigTab:AddSelector({
				Name = TranslateText("UI sound"),
				Options = SoundPresetOptions,
				Default = SoundPresetIndex or 0,
                AllowNone = SoundPresetIndex == nil,
				Callback = function(Value)
					for _, Preset in ipairs(SoundPresets) do
						if Preset.Name == Value then
							if tostring(Library:GetSoundId()) ~= tostring(Preset.Id) then
								Library:SetSoundId(Preset.Id)
								Library:PreviewUISound()
							end
							break
						end
					end
				end
			})
			ExtraLabels[#ExtraLabels + 1] = {SoundPresetControl, "UI sound"}

			local SoundVolumeControl = ConfigTab:AddSlider({
				Name = TranslateText("UI sound volume"),
				Min = 0, Max = 100, Increase = 1,
				Default = Library:GetSoundVolume(),
				Callback = function(Value) Library:SetSoundVolume(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {SoundVolumeControl, "UI sound volume"}

			local DropdownSection = ConfigTab:AddSection(TranslateText("Dropdowns"))
			ExtraLabels[#ExtraLabels + 1] = {DropdownSection, "Dropdowns"}

			local DropdownSearchControl = ConfigTab:AddToggle({
				Name = TranslateText("Search in all dropdowns"),
				Default = Library:GetDropdownSearchDefault(),
				Callback = function(Value) Library:SetDropdownSearchDefault(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {DropdownSearchControl, "Search in all dropdowns"}

			local DropdownPrefixControl = ConfigTab:AddToggle({
				Name = TranslateText("Search from beginning only"),
				Default = Library:GetDropdownPrefixOnly(),
				Callback = function(Value) Library:SetDropdownPrefixOnly(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {DropdownPrefixControl, "Search from beginning only"}

			local DropdownCloseControl = ConfigTab:AddToggle({
				Name = TranslateText("Close dropdown after selection"),
				Default = Library:GetDropdownCloseOnSelect(),
				Callback = function(Value) Library:SetDropdownCloseOnSelect(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {DropdownCloseControl, "Close dropdown after selection"}

			local DropdownVisibleOptionsControl = ConfigTab:AddSlider({
				Name = TranslateText("Visible dropdown options"),
				Min = 3, Max = 12, Increase = 1,
				Default = Library:GetDropdownMaxVisibleOptions(),
				Callback = function(Value) Library:SetDropdownMaxVisibleOptions(Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {DropdownVisibleOptionsControl, "Visible dropdown options"}

			local CursorSection = ConfigTab:AddSection(TranslateText("Cursor and camera"))
			ExtraLabels[#ExtraLabels + 1] = {CursorSection, "Cursor and camera"}

			local UnlockCursorToggle = ConfigTab:AddToggle({
				Name = TranslateText("Unlock cursor when hub opens"),
				Default = Library:GetMouseSetting("UnlockCursorOnOpen"),
				Callback = function(Value) Library:SetMouseSetting("UnlockCursorOnOpen", Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {UnlockCursorToggle, "Unlock cursor when hub opens"}

			local CameraRightClickToggle = ConfigTab:AddToggle({
				Name = TranslateText("Rotate camera with right mouse button"),
				Default = Library:GetMouseSetting("CameraWithRightMouseButton"),
				Callback = function(Value) Library:SetMouseSetting("CameraWithRightMouseButton", Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {CameraRightClickToggle, "Rotate camera with right mouse button"}

			local MinimizedCursorToggle = ConfigTab:AddToggle({
				Name = TranslateText("Keep cursor unlocked while minimized"),
				Default = Library:GetMouseSetting("UnlockCursorWhenMinimized"),
				Callback = function(Value) Library:SetMouseSetting("UnlockCursorWhenMinimized", Value) end
			})
			ExtraLabels[#ExtraLabels + 1] = {MinimizedCursorToggle, "Keep cursor unlocked while minimized"}

			local MiscSection = ConfigTab:AddSection(TranslateText("Miscellaneous"))
            ExtraLabels[#ExtraLabels + 1] = {MiscSection, "Miscellaneous"}

            local FloatingButtonToggle = ConfigTab:AddToggle({
                Name = TranslateText("Show floating hub button"),
                Default = Library.Save.ShowFloatingMinimizeButton,
                Callback = function(Value) Window:SetFloatingMinimizeButtonVisible(Value) end
            })
            ExtraLabels[#ExtraLabels + 1] = {FloatingButtonToggle, "Show floating hub button"}

            local SavePositionToggle = ConfigTab:AddToggle({
                Name = TranslateText("Save position"),
                Default = Library:GetSavePosition(),
                Callback = function(Value) Library:SetSavePosition(Value) end
            })
            ExtraLabels[#ExtraLabels + 1] = {SavePositionToggle, "Save position"}

            local ResetSettingsButton = ConfigTab:AddButton({
                Name = TranslateText("Reset settings"),
                Callback = function()
                    Window:Dialog({
                        Title = TranslateText("Reset settings"),
                        Text = TranslateText("Restore interface defaults now? Your language will be kept."),
                        Options = {
                            {Name = TranslateText("Cancel")},
                            {
                                Name = TranslateText("Restore defaults"),
                                Callback = function()
                                    local Defaults = Library.DefaultSettings
                                    Window:SetSize(Defaults.UISize[1], Defaults.UISize[2])
                                    Window:SetTabSize(Defaults.TabSize)
                                    Window:SetMinimizedWidth(Defaults.MinimizedWidth)
                                    Window:SetKeybind(Defaults.Keybind)
                                    Library:SetKeybindIconDefault(Defaults.KeybindIcon)
                                    Library:SetKeybindWidth(Defaults.KeybindWidth)
                                    Library:SetKeybindHighlight(Defaults.KeybindHighlight)
                                    Library:SetKeybindRightClick(Defaults.KeybindRightClick)
                                    DraggableControl:SetEnabled(Defaults.Draggable)
                                    ResizableControl:SetEnabled(Defaults.Resizable)
                                    TabResizableControl:SetEnabled(Defaults.TabResizable)
                                    FloatingButtonToggle:SetEnabled(Defaults.ShowFloatingMinimizeButton)
                                    Library:SetSavePosition(Defaults.SavePosition)
                                    SavePositionToggle:SetEnabled(Defaults.SavePosition)
                                    Library:ResetPositions()

                                    Library:SetTransparency(Defaults.Transparency)
                                    Library:SetScrollThickness(Defaults.ScrollThickness)
                                    Library:SetScrollTransparency(Defaults.ScrollTransparency)
                                    Library:ResetBackground()
                                    Library:SetSoundEnabled(Defaults.SoundEnabled)
                                    Library:SetSoundId(Defaults.SoundId)
                                    Library:SetSoundVolume(Defaults.SoundVolume)
                                    Library:SetDropdownSearchDefault(Defaults.DropdownSearch)
                                    Library:SetDropdownPrefixOnly(Defaults.DropdownPrefixOnly)
                                    Library:SetDropdownCloseOnSelect(Defaults.DropdownCloseOnSelect)
                                    Library:SetDropdownMaxVisibleOptions(Defaults.DropdownMaxVisibleOptions)
                                    Library:SetMouseSetting("UnlockCursorOnOpen", Defaults.UnlockCursorOnOpen)
                                    Library:SetMouseSetting("CameraWithRightMouseButton", Defaults.CameraWithRightMouseButton)
                                    Library:SetMouseSetting("UnlockCursorWhenMinimized", Defaults.UnlockCursorWhenMinimized)
                                    for Key in pairs(Library.SectionRanges) do
                                        Library:SetSectionSetting(Key, Defaults[Key])
                                    end
                                    Library:SetSectionSetting("SectionIndicator", Defaults.SectionIndicator)
                                    Library:SetTheme(Defaults.Theme)

                                    SettingsWindowWidth:SetValue(Defaults.UISize[1], true)
                                    SettingsWindowHeight:SetValue(Defaults.UISize[2], true)
                                    SettingsTabWidth:SetValue(Defaults.TabSize, true)
                                    MinimizedWidthControl:SetValue(Defaults.MinimizedWidth, true)
                                    HubTransparency:SetValue(Defaults.Transparency, true)
                                    KeybindIconControl:SetEnabled(Defaults.KeybindIcon)
                                    KeybindWidthControl:SetValue(Defaults.KeybindWidth, true)
                                    KeybindHighlightControl:SetEnabled(Defaults.KeybindHighlight)
                                    KeybindRightClickControl:SetEnabled(Defaults.KeybindRightClick)
                                    ScrollThicknessControl:SetValue(Defaults.ScrollThickness, true)
                                    ScrollTransparencyControl:SetValue(Defaults.ScrollTransparency * 100, true)
                                    SoundEnabledControl:SetEnabled(Defaults.SoundEnabled)
                                    SoundVolumeControl:SetValue(Defaults.SoundVolume, true)
                                    SoundPresetControl:Set(EnsureSoundPreset(tostring(Defaults.SoundId)), true)
                                    DropdownSearchControl:SetEnabled(Defaults.DropdownSearch)
                                    DropdownPrefixControl:SetEnabled(Defaults.DropdownPrefixOnly)
                                    DropdownCloseControl:SetEnabled(Defaults.DropdownCloseOnSelect)
                                    DropdownVisibleOptionsControl:SetValue(Defaults.DropdownMaxVisibleOptions, true)
                                    UnlockCursorToggle:SetEnabled(Defaults.UnlockCursorOnOpen)
                                    CameraRightClickToggle:SetEnabled(Defaults.CameraWithRightMouseButton)
                                    MinimizedCursorToggle:SetEnabled(Defaults.UnlockCursorWhenMinimized)
                                    SectionIndicatorToggle:SetEnabled(Defaults.SectionIndicator)
                                    for _, Entry in ipairs(ExtraLabels) do
                                        local Key = ({
                                            ["Section height"] = "SectionHeight",
                                            ["Section text size"] = "SectionTextSize",
                                            ["Indicator thickness"] = "SectionThickness",
                                            ["Indicator height"] = "SectionIndicatorHeight",
                                            ["Indicator spacing"] = "SectionSpacing"
                                        })[Entry[2]]
                                        if Key then Entry[1]:SetValue(Defaults[Key], true) end
                                    end
                                    ThemeDropdown:Select(Defaults.Theme)
                                    QueueSettingsSave()
                                    Library:NotifyLibrary(TranslateText("Interface settings restored."))
                                end
                            }
                        }
                    })
                end
            })
            ExtraLabels[#ExtraLabels + 1] = {ResetSettingsButton, "Reset settings"}

			local ConfigLanguageConnection = Connection.LanguageChanged:Connect(function()
				if not ConfigTab or ConfigTab._Destroyed then return end
				ConfigTab:SetTitle(TranslateText("Settings"))
				InterfaceSection:Set(TranslateText("Interface"))
				LanguageDropdown:SetTitle(TranslateText("Language"))
				ThemeDropdown:SetTitle(TranslateText("Theme"))
				for _, Entry in ipairs(ExtraLabels) do
					local Control, Key = Entry[1], Entry[2]
					if type(Control.SetTitle) == "function" then
						Control:SetTitle(TranslateText(Key))
					else
						Control:Set(TranslateText(Key))
					end
				end
			end)
			local ConfigDestroy = ConfigTab.Destroy
			function ConfigTab:Destroy(...)
				ConfigLanguageConnection:Disconnect()
				if Library._BackgroundSettings.Owner == self then
					Library._BackgroundSettings.Sync = nil
					Library._BackgroundSettings.Owner = nil
				end
				return ConfigDestroy(self, ...)
			end
		end

		Window:SelectTab(ConfigTab)
		return ConfigTab
	end

	local Greeting = RootConfig.StartupGreeting
	if type(Greeting) == "table" and Greeting.Enabled ~= false
		and not StartupGreetingQueued and not Library:IsStartupGreetingDismissed() then
		StartupGreetingQueued = true
		task.defer(function()
			if not ScreenGui.Parent or not MainFrame.Parent then return end
			local Name = Player and (Player.DisplayName ~= "" and Player.DisplayName or Player.Name) or "Player"
			local Template = type(Greeting.Description) == "string" and Greeting.Description
				or "Good to see you, {Player}! {Title} is ready. Make yourself at home and enjoy!"
			Window:Dialog({
				Title = tostring(RootConfig.Title or WTitle),
				Text = Template,
				Values = {
					Player = Name,
					Title = tostring(RootConfig.Title or WTitle)
				},
				Options = {
					{
						Name = "Don't show again",
						Style = "Secondary",
						Color = {
							Background = (type(ControlsConfig.Dialog) == "table" and ControlsConfig.Dialog.ButtonColor) or "Color Stroke",
							Text = (type(ControlsConfig.Dialog) == "table" and ControlsConfig.Dialog.ButtonTextColor) or "Color Text"
						},
						Callback = function()
							if not Library:SetStartupGreetingDismissed(true) then
								warn("[SpecterX] Could not save startup greeting preference.")
							end
						end
					}
				}
			})
		end)
	end

	return Window
end

return Library
