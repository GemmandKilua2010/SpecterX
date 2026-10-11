---@diagnostic disable: undefined-global

--// Services

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

--// Context

local Hub, RootConfig = ...
local Player = Players.LocalPlayer
local LibraryConfig = type(RootConfig) == "table" and RootConfig.Library or nil
LibraryConfig = type(LibraryConfig) == "table" and LibraryConfig or {}

local SharedThemes = type(RootConfig) == "table" and RootConfig.Themes or nil
SharedThemes = type(SharedThemes) == "table" and SharedThemes or {}

if not next(SharedThemes) then
    SharedThemes = {
        MetalRed = {
            ["Color Hub 1"] = ColorSequence.new(Color3.fromRGB(20, 20, 20)),
            ["Color Hub 2"] = Color3.fromRGB(20, 20, 20),
            ["Color Stroke"] = Color3.fromRGB(100, 0, 0),
            ["Color Theme"] = Color3.fromRGB(200, 30, 30),
            ["Color Text"] = Color3.fromRGB(220, 220, 220),
            ["Color Dark Text"] = Color3.fromRGB(170, 170, 170)
        }
    }
end

local Library = {
	Themes = SharedThemes,
	Info = {
		Version = "1.1.0"
	},
	Save = {
		UISize = {534, 281},
		TabSize = 160,
		Theme = "MetalRed",
		Keybind = "G",
		Transparency = 3,
		Language = "US",
		Draggable = true,
		Resizable = true,
		TabResizable = true,
		MinimizedWidth = 220,
		ScrollThickness = 1.5,
		ScrollTransparency = 0.2,
		BackgroundImage = "",
		BackgroundPreset = "None",
		BackgroundImageTransparency = 35,
		BackgroundScale = "Crop",
		SoundEnabled = false,
		SoundVolume = 35,
		SoundId = "179235828",
		DropdownSearch = false,
		DropdownPrefixOnly = true,
		DropdownCloseOnSelect = false,
		DropdownMaxVisibleOptions = 10
	},
	Settings = {},
	Connection = {},
	Instances = {},
	Elements = {},
	Options = {},
	Flags = {},
	Tabs = {},
	Icons = {}
}

--// Cache

local IconSearchCache = {}
local DropdownSearchListeners = setmetatable({}, {__mode = "k"})
local DropdownPrefixListeners = setmetatable({}, {__mode = "k"})
local DropdownSizeListeners = setmetatable({}, {__mode = "k"})

--// Config

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
    return "Crop"
end

local DefaultWidth, DefaultHeight = GetPair(LibraryConfig.Size, 534, 281)
local MinWidth, MinHeight = GetPair(LibraryConfig.MinSize, 500, 280)
local MaxWidth, MaxHeight = GetPair(LibraryConfig.MaxSize, 580, 350)

MinWidth = math.max(320, MinWidth)
MinHeight = math.max(200, MinHeight)
MaxWidth = math.max(MinWidth, MaxWidth)
MaxHeight = math.max(MinHeight, MaxHeight)

DefaultWidth = math.clamp(DefaultWidth, MinWidth, MaxWidth)
DefaultHeight = math.clamp(DefaultHeight, MinHeight, MaxHeight)

local MinTabSize = math.max(100, tonumber(LibraryConfig.MinTabSize) or 140)
local MaxTabSize = math.max(MinTabSize, tonumber(LibraryConfig.MaxTabSize) or 220)
local DefaultTabSize = math.clamp(tonumber(LibraryConfig.TabSize) or 160, MinTabSize, MaxTabSize)
local ScreenPadding = math.max(0, tonumber(LibraryConfig.ScreenPadding) or 16)
local SettingsFolder = type(LibraryConfig.SettingsFolder) == "string" and LibraryConfig.SettingsFolder or "Library"
local SettingsFile = type(LibraryConfig.SettingsFile) == "string" and LibraryConfig.SettingsFile or "settings.json"
local SettingsPath = SettingsFolder .. "/" .. SettingsFile
local DefaultKeybind = (GetKeyCode(LibraryConfig.Keybind) or Enum.KeyCode.G).Name
local DefaultTransparency = math.clamp(tonumber(LibraryConfig.Transparency) or 3, 0, 100)
local DefaultMinimizedWidth = math.clamp(tonumber(LibraryConfig.MinimizedWidth) or 220, 160, 320)
local ColorPickerSmoothTime = math.clamp(tonumber(LibraryConfig.ColorPickerSmoothTime) or 0.06, 0, 0.2)
local ResponsiveConfig = type(LibraryConfig.Responsive) == "table" and LibraryConfig.Responsive or {}
local ResponsiveEnabled = ResponsiveConfig.Enabled ~= false
local CompactBreakpoint = math.max(320, tonumber(ResponsiveConfig.CompactBreakpoint) or 640)
local CompactTabSize = math.clamp(tonumber(ResponsiveConfig.CompactTabSize) or 128, 100, MaxTabSize)
local ResponsiveMinScale = math.clamp(tonumber(ResponsiveConfig.MinScale) or 0.5, 0.35, 1)
local ResponsiveMaxScale = math.clamp(tonumber(ResponsiveConfig.MaxScale) or 1, ResponsiveMinScale, 1.5)
local SmallScreenPadding = math.max(0, tonumber(ResponsiveConfig.SmallScreenPadding) or 8)
local TouchTopbarButtonSize = math.clamp(tonumber(ResponsiveConfig.TouchTopbarButtonSize) or 18, 14, 28)
local DesktopTopbarButtonSize = math.clamp(tonumber(ResponsiveConfig.DesktopTopbarButtonSize) or 14, 12, 24)
local Draggable = LibraryConfig.Draggable ~= false
local Resizable = LibraryConfig.Resizable ~= false
local TabResizable = LibraryConfig.TabResizable ~= false
local DragThreshold = math.max(0, tonumber(LibraryConfig.DragThreshold) or 3)
local ResizeHandleSize = math.clamp(tonumber(LibraryConfig.ResizeHandleSize) or 35, 12, 48)
local TabResizeHandleWidth = math.clamp(tonumber(LibraryConfig.TabResizeHandleWidth) or 20, 6, 30)

local AppearanceConfig = type(LibraryConfig.Appearance) == "table" and LibraryConfig.Appearance or {}
local CornerRadius = math.max(0, tonumber(AppearanceConfig.CornerRadius) or 10)
local ElementCornerRadius = math.max(0, tonumber(AppearanceConfig.ElementCornerRadius) or 6)
local StrokeThickness = math.max(0, tonumber(AppearanceConfig.StrokeThickness) or 1)
local ButtonHoverTransparency = math.clamp(tonumber(AppearanceConfig.ButtonHoverTransparency) or 0.4, 0, 1)
local GradientRotation = tonumber(AppearanceConfig.GradientRotation) or 45

local TopBarConfig = type(LibraryConfig.TopBar) == "table" and LibraryConfig.TopBar or {}
local TopBarHeight = math.clamp(tonumber(TopBarConfig.Height) or 28, 20, 48)
local TopBarTitleTextSize = math.clamp(tonumber(TopBarConfig.TitleTextSize) or 12, 8, 24)
local TopBarSubTitleTextSize = math.clamp(tonumber(TopBarConfig.SubTitleTextSize) or 8, 6, 20)
local TopBarTitlePadding = math.max(0, tonumber(TopBarConfig.TitlePadding) or 15)
local TopBarControlsRightPadding = math.max(0, tonumber(TopBarConfig.ControlsRightPadding) or 9)
local TopBarControlsSpacing = math.max(0, tonumber(TopBarConfig.ControlsSpacing) or 10)
local TopBarButtonTransparency = math.clamp(tonumber(TopBarConfig.ButtonTransparency) or 0.15, 0, 1)

local TabsConfig = type(LibraryConfig.Tabs) == "table" and LibraryConfig.Tabs or {}
local TabsPadding = math.max(0, tonumber(TabsConfig.Padding) or 10)
local TabsSpacing = math.max(0, tonumber(TabsConfig.Spacing) or 5)
local TabButtonHeight = math.clamp(tonumber(TabsConfig.ButtonHeight) or 24, 16, 48)
local TabTextSize = math.clamp(tonumber(TabsConfig.TextSize) or 10, 7, 24)
local TabIconSize = math.clamp(tonumber(TabsConfig.IconSize) or 13, 8, 32)
local TabIconOffset = math.max(0, tonumber(TabsConfig.IconOffset) or 8)
local TabTextOffset = math.max(0, tonumber(TabsConfig.TextOffset) or 15)
local TabTextIconOffset = math.max(TabTextOffset, tonumber(TabsConfig.TextIconOffset) or 25)
local TabInactiveTransparency = math.clamp(tonumber(TabsConfig.InactiveTransparency) or 0.3, 0, 1)
local TabIndicatorWidth = math.clamp(tonumber(TabsConfig.IndicatorWidth) or 4, 1, 12)
local TabIndicatorHeight = math.clamp(tonumber(TabsConfig.IndicatorHeight) or 13, 2, 32)
local TabIndicatorIdleSize = math.clamp(tonumber(TabsConfig.IndicatorIdleSize) or 4, 1, TabIndicatorHeight)

local ElementsConfig = type(LibraryConfig.Elements) == "table" and LibraryConfig.Elements or {}
local ElementHeight = math.clamp(tonumber(ElementsConfig.Height) or 25, 18, 60)
local ElementTitleTextSize = math.clamp(tonumber(ElementsConfig.TitleTextSize) or 10, 7, 24)
local ElementDescriptionTextSize = math.clamp(tonumber(ElementsConfig.DescriptionTextSize) or 8, 6, 20)
local ElementHorizontalPadding = math.max(0, tonumber(ElementsConfig.HorizontalPadding) or 10)
local ElementVerticalPadding = math.max(0, tonumber(ElementsConfig.VerticalPadding) or 5)
local ElementSpacing = math.max(0, tonumber(ElementsConfig.Spacing) or 2)

local ScrollConfig = type(LibraryConfig.Scroll) == "table" and LibraryConfig.Scroll or {}
local ScrollThickness = math.clamp(tonumber(ScrollConfig.Thickness) or 1.5, 0, 12)
local ScrollTransparency = math.clamp(tonumber(ScrollConfig.Transparency) or 0.2, 0, 1)

local BackgroundConfig = type(LibraryConfig.Background) == "table" and LibraryConfig.Background or {}
local DefaultBackgroundImage = NormalizeAssetId(BackgroundConfig.Image) or ""
local DefaultBackgroundPreset = type(BackgroundConfig.Default) == "string" and BackgroundConfig.Default or "None"
local DefaultBackgroundImageTransparency = math.clamp(tonumber(BackgroundConfig.ImageTransparency) or 35, 0, 100)
local DefaultBackgroundScale = NormalizeBackgroundScale(BackgroundConfig.ScaleType)
local BackgroundPresets = type(BackgroundConfig.Presets) == "table" and BackgroundConfig.Presets or {}

local AudioConfig = type(LibraryConfig.Audio) == "table" and LibraryConfig.Audio or {}
local DefaultSoundEnabled = AudioConfig.Enabled == true
local DefaultSoundVolume = math.clamp(tonumber(AudioConfig.Volume) or 35, 0, 100)
local DefaultSoundId = NormalizeAssetId(AudioConfig.SoundId) or "179235828"
if DefaultSoundId == "" then DefaultSoundId = "179235828" end

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

if #SoundPresets == 0 then
    SoundPresets[1] = {Name = "Classic Click", Id = "179235828"}
    SoundPresetOptions[1] = "Classic Click"
    SoundPresetIndexById["179235828"] = 1
end

if not SoundPresetIndexById[DefaultSoundId] then
    DefaultSoundId = SoundPresets[1].Id
end

local DropdownConfig = type(LibraryConfig.Dropdown) == "table" and LibraryConfig.Dropdown or {}
local DefaultDropdownSearch = DropdownConfig.Search == true
local DefaultDropdownPrefixOnly = DropdownConfig.PrefixOnly ~= false
local DefaultDropdownCloseOnSelect = DropdownConfig.CloseOnSelect == true
local DefaultDropdownMaxVisibleOptions = math.clamp(math.floor(tonumber(DropdownConfig.MaxVisibleOptions) or 10), 3, 12)

local AnimationConfig = type(LibraryConfig.Animation) == "table" and LibraryConfig.Animation or {}
local AnimationDefault = math.max(0, tonumber(AnimationConfig.Default) or 0.5)
local AnimationWindow = math.max(0, tonumber(AnimationConfig.Window) or 0.22)
local AnimationTopBar = math.max(0, tonumber(AnimationConfig.TopBar) or 0.12)
local AnimationTabOpen = math.max(0, tonumber(AnimationConfig.TabOpen) or 0.3)
local AnimationTab = math.max(0, tonumber(AnimationConfig.Tab) or 0.35)
local AnimationToggle = math.max(0, tonumber(AnimationConfig.Toggle) or 0.25)
local AnimationDropdown = math.max(0, tonumber(AnimationConfig.Dropdown) or 0.2)
local AnimationDropdownPosition = math.max(0, tonumber(AnimationConfig.DropdownPosition) or 0.1)
local AnimationSlider = math.max(0, tonumber(AnimationConfig.Slider) or 0.3)
local AnimationDialog = math.max(0, tonumber(AnimationConfig.Dialog) or 0.2)
local AnimationDialogFade = math.max(0, tonumber(AnimationConfig.DialogFade) or 0.15)

Library.Save.UISize = {DefaultWidth, DefaultHeight}
Library.Save.TabSize = DefaultTabSize
Library.Save.Keybind = DefaultKeybind
Library.Save.Transparency = DefaultTransparency
Library.Save.Draggable = Draggable
Library.Save.Resizable = Resizable
Library.Save.TabResizable = TabResizable
Library.Save.MinimizedWidth = DefaultMinimizedWidth
Library.Save.ScrollThickness = ScrollThickness
Library.Save.ScrollTransparency = ScrollTransparency
Library.Save.BackgroundImage = DefaultBackgroundImage
Library.Save.BackgroundPreset = DefaultBackgroundPreset
Library.Save.BackgroundImageTransparency = DefaultBackgroundImageTransparency
Library.Save.BackgroundScale = DefaultBackgroundScale
Library.Save.SoundEnabled = DefaultSoundEnabled
Library.Save.SoundVolume = DefaultSoundVolume
Library.Save.SoundId = DefaultSoundId
Library.Save.DropdownSearch = DefaultDropdownSearch
Library.Save.DropdownPrefixOnly = DefaultDropdownPrefixOnly
Library.Save.DropdownCloseOnSelect = DefaultDropdownCloseOnSelect
Library.Save.DropdownMaxVisibleOptions = DefaultDropdownMaxVisibleOptions

local RootTheme = type(RootConfig) == "table" and RootConfig.Theme or nil
if type(RootTheme) == "string" and Library.Themes[RootTheme] then
    Library.Save.Theme = RootTheme
end

if type(Hub) == "table" and type(Hub.GetLanguage) == "function" then
    Library.Save.Language = Hub:GetLanguage()
end

local Settings = Library.Settings
local Flags = Library.Flags
local UIScale = 1.9636363983154297
local RequestedScale = tonumber(LibraryConfig.Scale) or 1.9636363983154297
local OrderedParents = setmetatable({}, {__mode = "k"})

local GenerateName
local LoadedSettingKeys = {}

local SetProps, SetChildren, InsertTheme, Create do
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
		local new = Instance.new(args[1])
		if new:IsA("UIListLayout") then
			new.SortOrder = Enum.SortOrder.LayoutOrder
		end
		local Children = {}
		
		if type(args[2]) == "table" then
			SetProps(new, args[2])
			SetChildren(new, args[3])
			Children = args[3] or {}
		elseif typeof(args[2]) == "Instance" then
			new.Parent = args[2]
			SetProps(new, args[3])
			SetChildren(new, args[4])
			Children = args[4] or {}
		end

		if new:IsA("GuiObject") and OrderedParents[new.Parent] ~= nil then
			OrderedParents[new.Parent] += 1
			new.LayoutOrder = OrderedParents[new.Parent]
		end
		new.Name = GenerateName and GenerateName(12) or new.Name
		return new
	end
	
	local function Save()
		if type(Hub) ~= "table" or type(Hub.FileExists) ~= "function" or not Hub:FileExists(SettingsPath) then
			return
		end

		local Source = Hub:ReadFile(SettingsPath)
		if type(Source) ~= "string" then
			return
		end

		local Success, Decode = pcall(HttpService.JSONDecode, HttpService, Source)
		if not Success or type(Decode) ~= "table" then
			return
		end

		table.clear(LoadedSettingKeys)
		for Key in pairs(Decode) do
			LoadedSettingKeys[Key] = true
		end

		local Width, Height = GetPair(Decode.UISize, DefaultWidth, DefaultHeight)
		Library.Save.UISize = {
			math.clamp(Width, MinWidth, MaxWidth),
			math.clamp(Height, MinHeight, MaxHeight)
		}

		Library.Save.TabSize = math.clamp(tonumber(Decode.TabSize) or DefaultTabSize, MinTabSize, MaxTabSize)

		if type(Decode.Theme) == "string" and Library.Themes[Decode.Theme] then
			Library.Save.Theme = Decode.Theme
		end

		local SavedKeybind = GetKeyCode(Decode.Keybind)
		if SavedKeybind then
			Library.Save.Keybind = SavedKeybind.Name
		end

		Library.Save.Transparency = math.clamp(tonumber(Decode.Transparency) or DefaultTransparency, 0, 100)

		if type(Decode.Draggable) == "boolean" then
			Library.Save.Draggable = Decode.Draggable
		end
		if type(Decode.Resizable) == "boolean" then
			Library.Save.Resizable = Decode.Resizable
		end
		if type(Decode.TabResizable) == "boolean" then
			Library.Save.TabResizable = Decode.TabResizable
		end
		Library.Save.MinimizedWidth = math.clamp(tonumber(Decode.MinimizedWidth) or DefaultMinimizedWidth, 160, math.min(320, MaxWidth))
		Library.Save.ScrollThickness = math.clamp(tonumber(Decode.ScrollThickness) or ScrollThickness, 0, 12)
		Library.Save.ScrollTransparency = math.clamp(tonumber(Decode.ScrollTransparency) or ScrollTransparency, 0, 1)

		local SavedBackground = NormalizeAssetId(Decode.BackgroundImage)
		if SavedBackground ~= nil then
			Library.Save.BackgroundImage = SavedBackground
		end
		if type(Decode.BackgroundPreset) == "string" then
			Library.Save.BackgroundPreset = Decode.BackgroundPreset
		end
		Library.Save.BackgroundImageTransparency = math.clamp(tonumber(Decode.BackgroundImageTransparency) or DefaultBackgroundImageTransparency, 0, 100)
		Library.Save.BackgroundScale = NormalizeBackgroundScale(Decode.BackgroundScale or DefaultBackgroundScale)

		if type(Decode.SoundEnabled) == "boolean" then
			Library.Save.SoundEnabled = Decode.SoundEnabled
		end
		Library.Save.SoundVolume = math.clamp(tonumber(Decode.SoundVolume) or DefaultSoundVolume, 0, 100)
		local SavedSoundId = NormalizeAssetId(Decode.SoundId)
		if SavedSoundId and SoundPresetIndexById[SavedSoundId] then
			Library.Save.SoundId = SavedSoundId
		end

		if type(Decode.DropdownSearch) == "boolean" then
			Library.Save.DropdownSearch = Decode.DropdownSearch
		end
		if type(Decode.DropdownPrefixOnly) == "boolean" then
			Library.Save.DropdownPrefixOnly = Decode.DropdownPrefixOnly
		end
		if type(Decode.DropdownCloseOnSelect) == "boolean" then
			Library.Save.DropdownCloseOnSelect = Decode.DropdownCloseOnSelect
		end
		Library.Save.DropdownMaxVisibleOptions = math.clamp(
			math.floor(tonumber(Decode.DropdownMaxVisibleOptions) or DefaultDropdownMaxVisibleOptions),
			3,
			12
		)

		if type(Decode.Language) == "string" and type(Hub) == "table" and type(Hub.SetLanguage) == "function" then
			local Success, Language = Hub:SetLanguage(Decode.Language)
			if Success then
				Library.Save.Language = Language
			end
		end
	end

	if type(Hub) == "table" and type(Hub.CreateFolder) == "function" then
		Hub:CreateFolder(SettingsFolder)
	end

	pcall(Save)
	Draggable = Library.Save.Draggable ~= false
	Resizable = Library.Save.Resizable ~= false
	TabResizable = Library.Save.TabResizable ~= false
	ScrollThickness = Library.Save.ScrollThickness
	ScrollTransparency = Library.Save.ScrollTransparency

	if type(Hub) == "table" and type(Hub.CreateFile) == "function" then
		local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Library.Save)
		if Success then
			Hub:CreateFile(SettingsPath, Encoded)
		end
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
		return type(Name) == "string" and Flags[Name]
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
			task.wait(0.1)
			db = false

			local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Flags)
			if Success and type(Hub) == "table" and type(Hub.CreateFile) == "function" then
				local Saved = Hub:CreateFile(ScriptFile, Encoded)
				if Saved then
					Connection:FireConnection("FileSaved", "Script-Flags", ScriptFile, Encoded)
				end
			end
		end
	end)
end

--// Runtime

local FallbackRNG = Random.new()
local FallbackCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
local FallbackCharacterCount = #FallbackCharacters

GenerateName = function(Length)
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
    return Camera and Camera.ViewportSize or Vector2.new(1280, 720)
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

local function ResolveGuiParent()
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

local function GetGuiContainer()
    local Existing = Runtime.GuiContainer
    if typeof(Existing) == "Instance" and Existing:IsA("Folder") and Existing.Parent then
        local TargetParent = ResolveGuiParent()
        if Existing.Parent ~= TargetParent then
            pcall(function()
                Existing.Parent = TargetParent
            end)
        end
        return Existing
    end

    local TargetParent = ResolveGuiParent()
    local Success, Result = pcall(Create, "Folder", TargetParent, {Archivable = false})

    if (not Success or typeof(Result) ~= "Instance") and TargetParent ~= CoreGui then
        Success, Result = pcall(Create, "Folder", CoreGui, {Archivable = false})
    end

    if Success and typeof(Result) == "Instance" then
        Runtime.GuiContainer = Result
        return Result
    end

    return CoreGui
end

local GuiContainer = GetGuiContainer()
local ScreenGui = Create("ScreenGui", GuiContainer, {
    Archivable = false,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, {
    ScreenScale
})

Runtime.Gui = ScreenGui
Library.Window = ScreenGui

local UISound = Create("Sound", ScreenGui, {
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
    UIScale = CalculateScale(ResponsiveWidth, ResponsiveHeight)
    ScreenScale.Scale = UIScale
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
            and GuiContainer ~= CoreGui
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

local function GetStr(val)
    if type(val) == "function" then
        return val()
    end
    return val
end

local TweenInfoCache = {}
local function CreateTween(Configs)
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

local function MakeDrag(Instance, Options)
    Options = type(Options) == "table" and Options or {}

    local Handle = typeof(Options.Handle) == "Instance" and Options.Handle or Instance
    local CanStart = type(Options.CanStart) == "function" and Options.CanStart or nil
    local Threshold = math.max(0, tonumber(Options.Threshold) or DragThreshold)
    local GlobalInput = Options.GlobalInput == true

    Handle.Active = true
    if Handle:IsA("GuiButton") then
        Handle.AutoButtonColor = false
    end

    local Dragging = false
    local DragInput
    local DragStart
    local StartPos

    local function StopDrag()
        Dragging = false
        DragInput = nil
        DragStart = nil
        StartPos = nil
    end

    local function Update(Input)
        if not Dragging or not DragStart or not StartPos then
            return
        end

        local Delta = Input.Position - DragStart
        if math.abs(Delta.X) < Threshold and math.abs(Delta.Y) < Threshold then
            return
        end

        Instance.Position = UDim2.new(
            StartPos.X.Scale,
            StartPos.X.Offset + Delta.X / UIScale,
            StartPos.Y.Scale,
            StartPos.Y.Offset + Delta.Y / UIScale
        )
    end

    local function Begin(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if CanStart and not CanStart(Input) then
            return
        end

        Dragging = true
        DragStart = Input.Position
        StartPos = Instance.Position
        DragInput = Input.UserInputType == Enum.UserInputType.Touch and Input or nil
    end

    if GlobalInput then
        TrackConnection(UserInputService.InputBegan:Connect(Begin))
    else
        TrackConnection(Handle.InputBegan:Connect(Begin))
    end

    TrackConnection(UserInputService.InputChanged:Connect(function(Input)
        if not Dragging then
            return
        end

        if DragInput then
            if Input == DragInput then
                Update(Input)
            end
        elseif Input.UserInputType == Enum.UserInputType.MouseMovement then
            Update(Input)
        end
    end))

    TrackConnection(UserInputService.InputEnded:Connect(function(Input)
        if not Dragging then
            return
        end

        if (DragInput and Input == DragInput)
            or (not DragInput and Input.UserInputType == Enum.UserInputType.MouseButton1) then
            StopDrag()
        end
    end))

    return Instance
end

local function VerifyTheme(Theme)
	for name,_ in pairs(Library.Themes) do
		if name == Theme then
			return true
		end
	end
end

local function SaveJson(FileName, SaveData)
	if type(Hub) ~= "table" or type(Hub.CreateFile) ~= "function" then
		return false
	end

	local Success, Json = pcall(HttpService.JSONEncode, HttpService, SaveData)
	if not Success then
		return false
	end

	local Saved = Hub:CreateFile(FileName, Json)
	return Saved == true
end

local SettingsSaveQueued = false
local SettingsLastChange = 0
local SettingsSaveDelay = 0.5
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

local function QueueSettingsSave()
    SettingsLastChange = os.clock()
    if SettingsSaveQueued then return end
    SettingsSaveQueued = true
    task.delay(SettingsSaveDelay, FlushSettingsWhenIdle)
end

ScreenGui.Destroying:Connect(function()
    if not SettingsSaveQueued then return end
    SettingsSaveQueued = false
    SaveJson(SettingsPath, Library.Save)
end)

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

AddEle("Corner", function(parent, Radius)
	local New = SetProps(Create("UICorner", parent, {
		CornerRadius = Radius or UDim.new(0, CornerRadius)
	}), props)
	return New
end)

AddEle("Stroke", function(parent, props, ...)
	local args = {...}
	local New = InsertTheme(SetProps(Create("UIStroke", parent, {
		Color = args[1] or Theme["Color Stroke"],
		Thickness = args[2] or StrokeThickness,
		ApplyStrokeMode = "Border"
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
	
	New.MouseEnter:Connect(function()
		New.BackgroundTransparency = ButtonHoverTransparency
	end)
	New.MouseLeave:Connect(function()
		New.BackgroundTransparency = 0
	end)
	if args[1] then
		New.Activated:Connect(args[1])
	end
	return New
end)

AddEle("Gradient", function(parent, props, ...)
	local args = {...}
	local New = InsertTheme(SetProps(Create("UIGradient", parent, {
		Color = Theme["Color Hub 1"]
	}), props), "Gradient")
	return New
end)

local TranslateText

local function ButtonFrame(Instance, Title, Description, HolderSize, Clickable)
	local TitleL = InsertTheme(Create("TextLabel", {
		Font = Enum.Font.GothamMedium,
		TextColor3 = Theme["Color Text"],
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
	}), "Text")
	
	local DescL = InsertTheme(Create("TextLabel", {
		Font = Enum.Font.Gotham,
		TextColor3 = Theme["Color Dark Text"],
		Size = UDim2.new(1, -20),
		AutomaticSize = "Y",
		Position = UDim2.new(0, ElementHorizontalPadding + 2, 0, ElementVerticalPadding * 3),
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextSize = ElementDescriptionTextSize,
		TextXAlignment = "Left",
		Text = "",
		RichText = true
	}), "DarkText")

	local Frame
	if Clickable == false then
		Frame = InsertTheme(Create("Frame", Instance, {
			Size = UDim2.new(1, 0, 0, ElementHeight),
			AutomaticSize = "Y",
			BackgroundColor3 = Theme["Color Hub 2"]
		}), "Frame")
		Frame.MouseEnter:Connect(function()
			Frame.BackgroundTransparency = ButtonHoverTransparency
		end)
		Frame.MouseLeave:Connect(function()
			Frame.BackgroundTransparency = 0
		end)
	else
		Frame = Make("Button", Instance, {
			Size = UDim2.new(1, 0, 0, ElementHeight),
			AutomaticSize = "Y",
		})
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
		if type(NewTitle) == "string" and NewTitle:gsub(" ", ""):len() > 0 then
			TitleL.Text = TranslateText and TranslateText(NewTitle) or NewTitle
		end
	end
	function Label:SetDesc(NewDesc)
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
	return Frame, Label
end

--// Locked

local LockedToast
local LockedToastLabel
local LockedToastToken = 0

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

local function ShowToastMessage(Message, Values)
	LockedToastToken += 1
	local Token = LockedToastToken

	if not LockedToast or not LockedToast.Parent then
		LockedToast = InsertTheme(Create("Frame", ScreenGui, {
			Size = UDim2.fromOffset(300, 32),
			Position = UDim2.new(0.5, 0, 1, -25),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Theme["Color Hub 2"],
			Visible = false,
			ZIndex = 2000
		}), "Frame")

		Make("Corner", LockedToast, UDim.new(0, 6))
		Make("Stroke", LockedToast, {
			Transparency = 0.15
		})

		LockedToastLabel = InsertTheme(Create("TextLabel", LockedToast, {
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			BackgroundTransparency = 1,
			TextColor3 = Theme["Color Text"],
			TextSize = 10,
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			ZIndex = 2001
		}), "Text")
	end

	LockedToastLabel.Text = TranslateText(tostring(Message or "This element is unavailable."), Values)
	LockedToast.Visible = true

	task.delay(2, function()
		if Token == LockedToastToken and LockedToast and LockedToast.Parent then
			LockedToast.Visible = false
		end
	end)
end

local function ApplyLocked(Element, Holder, Configs, OnChanged)
	Configs = type(Configs) == "table" and Configs or {}

	local Locked = Configs.Locked == true
	Element.Locked = Locked
	local DefaultLockedMessage = type(LibraryConfig.LockedMessage) == "string" and LibraryConfig.LockedMessage or "This element is unavailable."
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
		Text = TranslateText(Configs.LockedTitle or "Locked"),
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

local function TokenizeCode(Source, State)
	local Colors = {
		Keyword = Color3.fromRGB(198, 120, 221),
		Global = Color3.fromRGB(97, 175, 239),
		String = Color3.fromRGB(152, 195, 121),
		Number = Color3.fromRGB(209, 154, 102),
		Comment = Color3.fromRGB(92, 99, 112),
		Boolean = Color3.fromRGB(209, 154, 102),
		Function = Theme["Color Theme"]
	}
	local Output, Index, Length = {}, 1, #Source
	local function Add(Text, Color)
		Output[#Output + 1] = {Text, Color}
	end
	while Index <= Length do
		local Rest = Source:sub(Index)
		if State then
			local Kind, Equals = State:match("^(%a+):(.*)$")
			local Close = "]" .. Equals .. "]"
			local Finish = Source:find(Close, Index, true)
			local Last = Finish and Finish + #Close - 1 or Length
			Add(Source:sub(Index, Last), Colors[Kind])
			Index = Last + 1
			if Finish then State = nil end
		else
			local Comment = Rest:sub(1, 2) == "--"
			local Equals = (Comment and Rest:sub(3) or Rest):match("^%[(=*)%[")
			if Equals then
				local Prefix = (Comment and 2 or 0) + #Equals + 2
				State = (Comment and "Comment:" or "String:") .. Equals
				Add(Rest:sub(1, Prefix), Comment and Colors.Comment or Colors.String)
				Index += Prefix
			elseif Comment then
				Add(Rest, Colors.Comment)
				break
			else
				local Char = Rest:sub(1, 1)
				local Token, Color
				if Char == '"' or Char == "'" or Char == "`" then
					local Finish = Index + 1
					while Finish <= Length do
						local Current = Source:sub(Finish, Finish)
						if Current == "\\" then
							Finish += 2
						elseif Current == Char then
							Finish += 1
							break
						else
							Finish += 1
						end
					end
					Token, Color = Source:sub(Index, Finish - 1), Colors.String
				else
					Token = Rest:match("^[%a_][%w_]*")
					if Token then
						Color = LuaKeywords[Token] and Colors.Keyword or RobloxGlobals[Token] and Colors.Global
						if Token == "true" or Token == "false" or Token == "nil" then Color = Colors.Boolean end
						if not Color and Rest:sub(#Token + 1):match("^%s*%(") then Color = Colors.Function end
					else
						Token = Rest:match("^0[xX][%da-fA-F_]+") or Rest:match("^0[bB][01_]+")
							or Rest:match("^%d[%d_]*%.?[%d_]*[eE][+-]?[%d_]+")
							or Rest:match("^%d[%d_]*%.?[%d_]*") or Rest:match("^%.%d[%d_]*")
						Color = Token and Colors.Number
					end
				end
				Token = Token or Char
				Add(Token, Color)
				Index += #Token
			end
		end
	end
	return Output, State
end

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

    return Library.Save.Language or "US"
end

function Library:GetLanguages()
    if type(Hub) == "table" and type(Hub.GetLanguages) == "function" then
        return Hub:GetLanguages()
    end

    return {US = "English", BR = "Português", ES = "Español"}
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
	Library.Save.Theme = NewTheme
	QueueSettingsSave()
	Theme = Library.Themes[NewTheme]

	if type(Hub) == "table" and type(Hub.SetTheme) == "function" then
		Hub:SetTheme(NewTheme)
	end
	
	Connection:FireConnection("ThemeChanged", NewTheme)
	for _, Val in ipairs(Library.Instances) do
		if Val.Type == "Gradient" or Val.Type == "MainGradient" then
			Val.Instance.Color = Theme["Color Hub 1"]
		elseif Val.Type == "Frame" then
			Val.Instance.BackgroundColor3 = Theme["Color Hub 2"]
		elseif Val.Type == "Stroke" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Stroke"]
		elseif Val.Type == "Theme" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Theme"]
		elseif Val.Type == "Text" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Text"]
		elseif Val.Type == "IconSurface" then
			Val.Instance.BackgroundColor3 = Theme["Color Hub 2"]

		elseif Val.Type == "Icon" then
			Val.Instance.ImageColor3 = Theme["Color Text"]
		elseif Val.Type == "DarkText" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Dark Text"]
		elseif Val.Type == "ScrollBar" then
			Val.Instance[GetColor(Val.Instance)] = Theme["Color Theme"]
		end
	end
end

function Library:GetBackground()
    return Library.Save.BackgroundImage or ""
end

function Library:GetBackgroundPreset()
    return Library.Save.BackgroundPreset or "None"
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
    QueueSettingsSave()

    local Enabled = AssetId ~= ""
    local Image = ToAssetContentId(AssetId)

    for _, Val in ipairs(Library.Instances) do
        if Val.Type == "Main" then
            Val.Instance.Image = Image
        elseif Val.Type == "MainGradient" then
            Val.Instance.Enabled = not Enabled
        end
    end

    return true
end

function Library:GetBackgroundImageTransparency()
    return Library.Save.BackgroundImageTransparency or DefaultBackgroundImageTransparency
end

function Library:SetBackgroundImageTransparency(Value)
    Value = tonumber(Value)
    if not Value then return false end

    Value = math.clamp(Value, 0, 100)
    Library.Save.BackgroundImageTransparency = Value
    QueueSettingsSave()

    for _, Val in ipairs(Library.Instances) do
        if Val.Type == "Main" then
            Val.Instance.ImageTransparency = Value / 100
        end
    end
    return true
end

function Library:GetBackgroundScale()
    return Library.Save.BackgroundScale or DefaultBackgroundScale
end

function Library:SetBackgroundScale(Value)
    local Name = NormalizeBackgroundScale(Value)
    Library.Save.BackgroundScale = Name
    QueueSettingsSave()

    for _, Val in ipairs(Library.Instances) do
        if Val.Type == "Main" then
            Val.Instance.ScaleType = BackgroundScaleTypes[Name]
        end
    end
    return true
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

function Library:GetDropdownSearchDefault()
    return Library.Save.DropdownSearch == true
end

function Library:SetDropdownSearchDefault(Value)
    if type(Value) ~= "boolean" then return false end
    if Library.Save.DropdownSearch == Value then return true end
    Library.Save.DropdownSearch = Value
    QueueSettingsSave()

    for Dropdown, SetSearchEnabled in pairs(DropdownSearchListeners) do
        if type(SetSearchEnabled) == "function" then
            local Success = pcall(SetSearchEnabled, Value)
            if not Success then
                DropdownSearchListeners[Dropdown] = nil
            end
        end
    end

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

    for Dropdown, SetPrefixOnly in pairs(DropdownPrefixListeners) do
        if type(SetPrefixOnly) == "function" then
            local Success = pcall(SetPrefixOnly, Value)
            if not Success then
                DropdownPrefixListeners[Dropdown] = nil
            end
        end
    end

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
    return math.clamp(math.floor(tonumber(Library.Save.DropdownMaxVisibleOptions) or 10), 3, 12)
end

function Library:SetDropdownMaxVisibleOptions(Value)
    Value = tonumber(Value)
    if not Value then return false end

    Value = math.clamp(math.floor(Value + 0.5), 3, 12)
    if Library.Save.DropdownMaxVisibleOptions == Value then return true end
    Library.Save.DropdownMaxVisibleOptions = Value
    QueueSettingsSave()

    for Dropdown, UpdateSize in pairs(DropdownSizeListeners) do
        if type(UpdateSize) == "function" then
            local Success = pcall(UpdateSize)
            if not Success then
                DropdownSizeListeners[Dropdown] = nil
            end
        end
    end

    return true
end

function Library:SetTransparency(NewTransparency)
    local Target = math.clamp(tonumber(NewTransparency) or Library.Save.Transparency or 3, 0, 100)
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
            Val.Instance.ScrollBarThickness = ScrollThickness
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

function Library:MakeWindow(Configs)
    Configs = type(Configs) == "table" and Configs or {}

	local WTitle = tostring(Configs[1] or Configs.Name or Configs.Title or "Library")
	local WMiniText = tostring(Configs[2] or Configs.SubTitle or "By Unknown")
	local Keybind = LoadedSettingKeys.Keybind and Library.Save.Keybind
		or Configs[3]
		or Configs.Keybind
		or Library.Save.Keybind
		or Enum.KeyCode.G

	local Minimized, SaveSize, WaitClick
	local RequestedMinimizedWidth = LoadedSettingKeys.MinimizedWidth and Library.Save.MinimizedWidth
		or tonumber(Configs.MinimizedWidth)
		or Library.Save.MinimizedWidth
		or DefaultMinimizedWidth
	local TitleWidth = TextService:GetTextSize(WTitle, TopBarTitleTextSize, Enum.Font.GothamMedium, Vector2.new(1000, TopBarHeight)).X
	local MinimizedWidth = math.clamp(math.max(RequestedMinimizedWidth, TitleWidth + 115), 160, math.min(320, MaxWidth))

	Settings.ScriptFile = Configs[4] or Configs.SaveFolder or false
	
	local function LoadFile()
		local File = Settings.ScriptFile
		if type(File) ~= "string" or File == "" or not Library:FileExists(File) then
			return
		end

		local Source = Library:ReadFile(File)
		if type(Source) ~= "string" then
			return
		end

		local DecodeSuccess, Decoded = pcall(HttpService.JSONDecode, HttpService, Source)
		if not DecodeSuccess or type(Decoded) ~= "table" then
			return
		end

		table.clear(Flags)
		for Flag, Value in pairs(Decoded) do
			Flags[Flag] = Value
		end
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
        BackgroundTransparency = (Library.Save.Transparency or 3) / 100,
        Image = ToAssetContentId(Library.Save.BackgroundImage),
        ImageTransparency = (Library.Save.BackgroundImageTransparency or DefaultBackgroundImageTransparency) / 100,
        ScaleType = BackgroundScaleTypes[Library.Save.BackgroundScale] or Enum.ScaleType.Crop,
    }), "Main")
	local MainGradient = InsertTheme(Create("UIGradient", MainFrame, {
		Color = Theme["Color Hub 1"],
		Rotation = GradientRotation,
		Enabled = (Library.Save.BackgroundImage or "") == ""
	}), "MainGradient")

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
	
	local MainScroll = InsertTheme(Create("ScrollingFrame", Components, {
		Size = UDim2.new(0, WindowTabSize, 1, -TopBar.Size.Y.Offset),
		ScrollBarImageColor3 = Theme["Color Theme"],
		Position = UDim2.new(0, 0, 1, 0),
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
	
	local Containers = Create("Frame", Components, {
		Size = UDim2.new(1, -MainScroll.Size.X.Offset, 1, -TopBar.Size.Y.Offset),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})

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
		if not Object.Visible then
			return false
		end

		local AbsolutePosition = Object.AbsolutePosition
		local AbsoluteSize = Object.AbsoluteSize
		return Position.X >= AbsolutePosition.X
			and Position.X <= AbsolutePosition.X + AbsoluteSize.X
			and Position.Y >= AbsolutePosition.Y
			and Position.Y <= AbsolutePosition.Y + AbsoluteSize.Y
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
		MainScroll.Size = UDim2.new(0, Width, 1, -TopBar.Size.Y.Offset)
		Containers.Size = UDim2.new(1, -Width, 1, -TopBar.Size.Y.Offset)
		SyncSettingsSlider(SettingsTabWidth, Width)
	end

	local function BeginResize(Mode, Input)
		if Minimized then
			return
		end

		local InputType = Input.UserInputType
		if InputType ~= Enum.UserInputType.MouseButton1 and InputType ~= Enum.UserInputType.Touch then
			return
		end

		ResizeState = {
			Mode = Mode,
			Input = InputType == Enum.UserInputType.Touch and Input or nil,
			Start = Input.Position,
			Width = MainFrame.Size.X.Offset,
			Height = MainFrame.Size.Y.Offset,
			TabWidth = MainScroll.Size.X.Offset
		}
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

		if State.Input then
			if Input ~= State.Input then
				return
			end
		elseif Input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		local Delta = (Input.Position - State.Start) / UIScale
		if State.Mode == "Window" then
			ApplyWindowSize(State.Width + Delta.X, State.Height + Delta.Y)
		else
			ApplyTabSize(State.TabWidth + Delta.X)
		end
	end))

	TrackConnection(UserInputService.InputEnded:Connect(function(Input)
		local State = ResizeState
		if not State then
			return
		end

		if not ((State.Input and Input == State.Input)
			or (not State.Input and Input.UserInputType == Enum.UserInputType.MouseButton1)) then
			return
		end

		ResizeState = nil
		if State.Mode == "Window" then
			Library.Save.UISize = {MainFrame.Size.X.Offset, MainFrame.Size.Y.Offset}
		else
			Library.Save.TabSize = MainScroll.Size.X.Offset
		end
		QueueSettingsSave()
	end))

	local function CanDragWindow(Input)
		if not Draggable or ResizeState or not MainFrame.Visible then
			return false
		end

		local Position = Input.Position
		if not IsPointInside(MainFrame, Position) then
			return false
		end

		if IsPointInside(ControlSize1, Position) or IsPointInside(ControlSize2, Position) then
			return false
		end

		local TouchInput = Input.UserInputType == Enum.UserInputType.Touch
		local Success, Objects = pcall(CoreGui.GetGuiObjectsAtPosition, CoreGui, Position.X, Position.Y)
		if Success then
			for _, Object in ipairs(Objects) do
				if Object ~= MainFrame and Object:IsDescendantOf(MainFrame) then
					if Object:IsA("GuiButton") or Object:IsA("TextBox") or (TouchInput and Object:IsA("ScrollingFrame")) then
						return false
					end
				end
			end
		else
			for _, Object in ipairs(MainFrame:GetDescendants()) do
				if (Object:IsA("GuiButton") or Object:IsA("TextBox") or (TouchInput and Object:IsA("ScrollingFrame")))
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
			CanStart = CanDragWindow,
			GlobalInput = true
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
	local CancelKeybindCapture
	local WindowKeybindControl
	local TopbarButtons = {}

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

		local Icon = ButtonConfig.Icon or ButtonConfig.Image or "circle"
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
			Title = TranslateText("Close"),
			Text = TranslateText("Are you sure you want to exit?"),
			Options = {
				{TranslateText("Confirm"), function()
					if CloseCallback then
						CloseCallback()
					end
					if type(Library._BeforeClose) == "function" then
						Library._BeforeClose()
					end
					ScreenGui:Destroy()
				end},
				{TranslateText("Cancel")}
			}
		})
	end
	function Window:MinimizeBtn()
		if WaitClick then return end
		WaitClick = true

		if Minimized then
			MinimizeButton:SetIcon("minus")
			CreateTween({MainFrame, "Size", SaveSize, AnimationWindow, true})
			MainScroll.Visible = true
			Containers.Visible = true
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
			MainScroll.Visible = false
			Containers.Visible = false
			SubTitleLabel.Visible = false
			CreateTween({MainFrame, "Size", UDim2.fromOffset(MinimizedWidth, TopBarHeight), AnimationWindow, true})
			ResponsiveWidth, ResponsiveHeight = MinimizedWidth, TopBarHeight
			UpdateResponsiveScale()
			Minimized = true
		end

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
		return MainScroll.Size.X.Offset
	end

	function Window:SetTabSize(Width)
		Width = tonumber(Width)
		if not Width then
			return false
		end

		Width = math.clamp(Width, MinTabSize, MaxTabSize)
		if MainScroll.Size.X.Offset == Width then return true end
		ApplyTabSize(Width)
		Library.Save.TabSize = MainScroll.Size.X.Offset
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
			ResizeState = nil
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
			ResizeState = nil
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

		WindowKeybind = Resolved
		if WindowKeybindControl and WindowKeybindControl:GetKeybind() ~= Resolved then
			WindowKeybindControl:SetKeybind(Resolved)
		end
		Library.Save.Keybind = Resolved.Name
		QueueSettingsSave()
		return true
	end

	function Window:GetKeybind()
		return WindowKeybind
	end

	TrackConnection(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed then return end
		if WindowKeybindCooldown or CapturingKeybind or CapturedKeys[Input.KeyCode] then return end
		if Input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if Input.KeyCode ~= WindowKeybind then return end
		if not WindowKeybindEnabled then return end

		WindowKeybindCooldown = true
		Window:Visible()

		task.delay(0.15, function()
			WindowKeybindCooldown = false
		end)
	end))

	TrackConnection(UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			CapturedKeys[Input.KeyCode] = nil
		end
	end))

	--- 

	function Window:AddMinimizeButton(Configs)
		local Button = MakeDrag(Create("ImageButton", ScreenGui, {
			Size = UDim2.fromOffset(35, 35),
			Position = UDim2.fromScale(0.15, 0.15),
			BackgroundTransparency = 1,
			BackgroundColor3 = Theme["Color Hub 2"],
			AutoButtonColor = false
		}))
		InsertTheme(Button, "IconSurface")
		
		local Stroke, Corner
		if Configs.Corner then
			Corner = Make("Corner", Button)
			SetProps(Corner, Configs.Corner)
		end
		if Configs.Stroke then
			Stroke = Make("Stroke", Button)
			SetProps(Stroke, Configs.Stroke)
		end
		
		SetProps(Button, Configs.Button)
		Button.Activated:Connect(function()
		    Window:Visible()
		end)
		
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
		if ActiveDialog and ActiveDialog.Parent then return end
		if Minimized then
			Window:MinimizeBtn()
		end
		
		local DTitle = TranslateText(tostring(Configs[1] or Configs.Title or "Dialog"))
		local DText = TranslateText(tostring(Configs[2] or Configs.Text or "This is a Dialog"))
		local DOptions = Configs[3] or Configs.Options or {}
		
		local Frame = Create("Frame", {
			Active = true,
			Size = UDim2.fromOffset(250 * 1.08, 150 * 1.08),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5)
		}, {
			InsertTheme(Create("TextLabel", {
				Font = Enum.Font.GothamBold,
				Size = UDim2.new(1, 0, 0, 20),
				Text = DTitle,
				TextXAlignment = "Left",
				TextColor3 = Theme["Color Text"],
				TextSize = 15,
				Position = UDim2.fromOffset(15, 5),
				BackgroundTransparency = 1
			}), "Text"),
			InsertTheme(Create("TextLabel", {
				Font = Enum.Font.GothamMedium,
				Size = UDim2.new(1, -25),
				AutomaticSize = "Y",
				Text = DText,
				TextXAlignment = "Left",
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 12,
				Position = UDim2.fromOffset(15, 25),
				BackgroundTransparency = 1,
				TextWrapped = true
			}), "DarkText")
		})Make("Gradient", Frame, {Rotation = 270})Make("Corner", Frame)
		
		local ButtonsHolder = Create("Frame", Frame, {
			Size = UDim2.fromScale(1, 0.35),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Theme["Color Hub 2"],
			BackgroundTransparency = 1
		}, {
			Create("UIListLayout", {
				Padding = UDim.new(0, 10),
				VerticalAlignment = "Center",
				FillDirection = "Horizontal",
				HorizontalAlignment = "Center"
			})
		})
		
		local Screen = InsertTheme(Create("Frame", MainFrame, {
			BackgroundTransparency = 0.6,
			Active = true,
			BackgroundColor3 = Theme["Color Stroke"],
			Size = UDim2.new(1, 0, 1, 0),
		}), "Stroke")
		ActiveDialog = Screen
		
		local DialogCorner = MainCorner:Clone()
		DialogCorner.Name = GenerateName(12)
		DialogCorner.Parent = Screen
		Frame.Parent = Screen
		CreateTween({Frame, "Size", UDim2.fromOffset(250, 150), AnimationDialog})
		CreateTween({Frame, "Transparency", 0, AnimationDialogFade})
		CreateTween({Screen, "Transparency", 0.3, AnimationDialogFade})
		
		local ButtonCount, Dialog = 1, {}
		function Dialog:Button(Configs)
			local Name = TranslateText(tostring(Configs[1] or Configs.Name or Configs.Title or ""))
			local Callback = Configs[2] or Configs.Callback or function()end
			
			ButtonCount = ButtonCount + 1
			local Button = Make("Button", ButtonsHolder)
			Make("Corner", Button)
			SetProps(Button, {
				Text = Name,
				Font = Enum.Font.GothamBold,
				TextColor3 = Theme["Color Text"],
				TextSize = 12
			})
			
			for _,Button in pairs(ButtonsHolder:GetChildren()) do
				if Button:IsA("TextButton") then
					Button.Size = UDim2.new(1 / ButtonCount, -(((ButtonCount - 1) * 20) / ButtonCount), 0, 32)
				end
			end
			Button.Activated:Connect(Dialog.Close)
			Button.Activated:Connect(Callback)
		end
		function Dialog:Close()
			CreateTween({Frame, "Size", UDim2.fromOffset(250 * 1.08, 150 * 1.08), AnimationDialog})
			CreateTween({Screen, "Transparency", 1, AnimationDialogFade})
			CreateTween({Frame, "Transparency", 1, AnimationDialogFade, true})
			if ActiveDialog == Screen then
				ActiveDialog = nil
			end
			Screen:Destroy()
		end
		for _, Button in pairs(DOptions) do
			Dialog:Button(Button)
		end
		return Dialog
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
	ScreenGui.Destroying:Connect(function()
		for _, Container in ipairs(ContainerList) do Container:Destroy() end
		table.clear(ContainerList)
	end)
	function Window:MakeTab(paste, Configs)
		if type(paste) == "table" then Configs = paste end
		Configs = type(Configs) == "table" and Configs or {}
		local Hidden = Configs.Hidden == true
		local TName = TranslateText(tostring(Configs[1] or Configs.Title or "Tab!"))
		local TIcon = Configs[2] or Configs.Icon or ""
		local TabSelect, LabelTitle, LabelIcon, Selected

		if not Hidden then
			TIcon = Library:GetIcon(TIcon)
			if not TIcon:find("rbxassetid://") or TIcon:gsub("rbxassetid://", ""):len() < 6 then
				TIcon = false
			end

			TabSelect = Make("Button", MainScroll, {
				Size = UDim2.new(1, 0, 0, TabButtonHeight),
				LayoutOrder = #Library.Tabs + 1
			})
			Make("Corner", TabSelect, UDim.new(0, 5))

			LabelTitle = InsertTheme(Create("TextLabel", TabSelect, {
				Size = UDim2.new(1, TIcon and -TabTextIconOffset or -TabTextOffset, 1),
				Position = UDim2.fromOffset(TIcon and TabTextIconOffset or TabTextOffset),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Text = TName,
				TextColor3 = Theme["Color Text"],
				TextSize = TabTextSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = (FirstTab and TabInactiveTransparency) or 0,
				TextTruncate = "AtEnd"
			}), "Text")

			LabelIcon = InsertTheme(Create("ImageLabel", TabSelect, {
				Position = UDim2.new(0, TabIconOffset, 0.5),
				Size = UDim2.new(0, TabIconSize, 0, TabIconSize),
				AnchorPoint = Vector2.new(0, 0.5),
				Image = TIcon or "",
				BackgroundTransparency = 1,
				ImageTransparency = (FirstTab and TabInactiveTransparency) or 0
			}), "Text")

			Selected = InsertTheme(Create("Frame", TabSelect, {
				Size = FirstTab and UDim2.new(0, TabIndicatorWidth, 0, TabIndicatorIdleSize) or UDim2.new(0, TabIndicatorWidth, 0, TabIndicatorHeight),
				Position = UDim2.new(0, 1, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme["Color Theme"],
				BackgroundTransparency = FirstTab and 1 or 0
			}), "Theme")
			Make("Corner", Selected, UDim.new(0.5, 0))
		else
			TIcon = false
		end
		
		local Container = InsertTheme(Create("ScrollingFrame", Containers, {
			Visible = false,
			Size = UDim2.new(1, -6, 1, -8),
			Position = UDim2.new(0, 0, 1, -4),
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
		
		OrderedParents[Container] = 0
		table.insert(ContainerList, Container)
		
		local InitiallySelected = not ActiveTab and not Hidden and not Configs.Locked
		Container.Visible = InitiallySelected
		
		local Tab = {}
		if Hidden then
			local Locked = Configs.Locked == true
			local LockedMessage = type(Configs.LockedMessage) == "string" and Configs.LockedMessage or (LibraryConfig.LockedMessage or "This element is unavailable.")

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
		local function Tabs()
			if Tab._Destroyed or not TabVisible then return false end
			if Tab:IsLocked() then
				Tab:NotifyLocked()
				return false
			end
			if ActiveTab == Tab and Container.Visible then return true end

			if ActiveTab and ActiveTab ~= Tab then
				ActiveTab:Disable()
			end
			ActiveTab = Tab
			Container.Visible = true
			if ConfigButton then ConfigButton:SetActive(Tab == ConfigTab) end
			if TabSelect then
				CreateTween({LabelTitle, "TextTransparency", 0, AnimationTab})
				CreateTween({LabelIcon, "ImageTransparency", 0, AnimationTab})
				CreateTween({Selected, "Size", UDim2.new(0, TabIndicatorWidth, 0, TabIndicatorHeight), AnimationTab})
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
				CreateTween({LabelIcon, "ImageTransparency", TabInactiveTransparency, AnimationTab})
				CreateTween({Selected, "Size", UDim2.new(0, TabIndicatorWidth, 0, TabIndicatorIdleSize), AnimationTab})
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
			TName = TranslateText(tostring(Value or ""))
			if LabelTitle then LabelTitle.Text = TName end
		end
		function Tab:GetTitle()
			return LabelTitle and LabelTitle.Text or TName
		end
		
		function Tab:AddSection(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local SectionFlag = type(Configs) == "table" and Configs.Flag or nil
			local SectionName = type(Configs) == "string" and Configs or Configs[1] or Configs.Name or Configs.Title or Configs.Section
			SectionName = TranslateText(tostring(SectionName or ""))
			
			local SectionFrame = InsertTheme(Create("Frame", Container, {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundColor3 = Theme["Color Hub 2"],
				BackgroundTransparency = 0.48,
				BorderSizePixel = 0
			}), "Frame")
			Make("Corner", SectionFrame, UDim.new(0, ElementCornerRadius))
			
			local SectionLabel = InsertTheme(Create("TextLabel", SectionFrame, {
				Font = Enum.Font.GothamBold,
				Text = SectionName,
				TextColor3 = Theme["Color Text"],
				Size = UDim2.new(1, -25, 1, 0),
				Position = UDim2.new(0, 8),
				BackgroundTransparency = 1,
				TextTruncate = "AtEnd",
				TextSize = 12,
				TextXAlignment = "Left"
			}), "Text")
			
			local Section = {}
			local SectionOption = {type = "Section", Name = SectionName, func = Section}
			table.insert(Library.Options, SectionOption)
			function Section:Visible(Bool)
				if Bool == nil then SectionFrame.Visible = not SectionFrame.Visible return end
				SectionFrame.Visible = Bool
			end
			function Section:Destroy()
				local Index = table.find(Library.Options, SectionOption)
				if Index then
					table.remove(Library.Options, Index)
				end
				SectionFrame:Destroy()
			end
			function Section:Set(New)
				if New ~= nil then
					SectionLabel.Text = TranslateText(tostring(GetStr(New) or ""))
				end
			end
			Section.SetTitle = Section.Set
			function Section:GetTitle()
				return SectionLabel.Text
			end
			return RegisterFlagObject(SectionFlag, Section, SectionFrame)
		end
		function Tab:AddParagraph(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local PName = Configs[1] or Configs.Title or TranslateText("Paragraph")
			local PDesc = Configs[2] or Configs.Text or Configs.Desc or Configs.Description or ""
			
			local Frame, LabelFunc = ButtonFrame(Container, PName, PDesc, UDim2.new(1, -20), false)
			
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
			local BName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Button!")
			local BDescription = Configs.Desc or Configs.Description or ""
			local Callback = Funcs:GetCallback(Configs, 2)
			
			local FButton, LabelFunc = ButtonFrame(Container, BName, BDescription, UDim2.new(1, -20))
			
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
			function Button:SetTitle(Value) LabelFunc:SetTitle(tostring(Value or "")) end
			function Button:SetDesc(Value) LabelFunc:SetDesc(tostring(Value or "")) end
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
			local TName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Toggle")
			local TDesc = Configs.Desc or Configs.Description or ""
			local Callback = Funcs:GetCallback(Configs, 3)
			local Flag = Configs[4] or Configs.Flag or false
			local Default = Configs[2] or Configs.Default or false
			if CheckFlag(Flag) then Default = GetFlag(Flag) end
			
			local Button, LabelFunc = ButtonFrame(Container, TName, TDesc, UDim2.new(1, -38))
			
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
			
			local Toggle = InsertTheme(Create("Frame", Slider, {
				Size = UDim2.new(0, 12, 0, 12),
				Position = UDim2.new(0, 0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Theme["Color Theme"]
			}), "Theme")Make("Corner", Toggle, UDim.new(0.5, 0))
			
			local function SetToggle(Value, Force)
				if type(Value) ~= "boolean" then return false end
				if Default == Value and not Force then return true end
				Default = Value
				SetFlag(Flag, Default)
				if Default then
					Toggle.AnchorPoint = Vector2.new(1, 0.5)
					CreateTween({Toggle, "Position", UDim2.new(1, 0, 0.5), AnimationToggle})
					CreateTween({Toggle, "BackgroundTransparency", 0, AnimationToggle})
				else
					Toggle.AnchorPoint = Vector2.new(0, 0.5)
					CreateTween({Toggle, "Position", UDim2.new(0, 0, 0.5), AnimationToggle})
					CreateTween({Toggle, "BackgroundTransparency", 0.8, AnimationToggle})
				end
				Funcs:FireCallback(Callback, Default)
				return true
			end
			SetToggle(Default == true, true)

			Button.Activated:Connect(function()
				if not Button.Interactable then return end
				if SetToggle(not Default) then PlayUISound() end
			end)

			local ToggleControl = {}
			function ToggleControl:Visible(...) Funcs:ToggleVisible(Button, ...) end
			function ToggleControl:Destroy() Button:Destroy() end
			function ToggleControl:Callback(...)
				local Added = Funcs:InsertCallback(Callback, ...)
				if type(Added) == "function" then Added(Default) end
			end
			function ToggleControl:SetEnabled(Value)
				if type(Value) ~= "boolean" then return false end
				SetToggle(Value)
				return Default
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
				LabelFunc:SetTitle(tostring(Value or ""))
			end
			function ToggleControl:SetDesc(Value)
				LabelFunc:SetDesc(tostring(Value or ""))
			end

			ApplyLocked(ToggleControl, Button, Configs)
			return RegisterFlagObject(Flag, ToggleControl, Button)
		end
		function Tab:AddDropdown(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local DName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Dropdown")
			local DDesc = Configs.Desc or Configs.Description or ""
			local DOptions = Configs[2] or Configs.Options or {}
			DOptions = type(DOptions) == "table" and DOptions or {}
			local OpDefault = Configs[3] or Configs.Default or "..."
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
			local DropdownConnections = {}

			local function TrackDropdownConnection(ConnectionObject)
				DropdownConnections[#DropdownConnections + 1] = ConnectionObject
				return ConnectionObject
			end

			local CustomSearchPlaceholder = Configs.SearchConfig and Configs.SearchConfig.Placeholder
			local CustomNoResultText = Configs.SearchConfig and Configs.SearchConfig.NoResultText
			local SearchConfig = {
				Enabled = DSearch,
				Placeholder = CustomSearchPlaceholder or TranslateText("Search..."),
				TextSize = Configs.SearchConfig and Configs.SearchConfig.TextSize or 11,
				MinTextSize = Configs.SearchConfig and Configs.SearchConfig.MinTextSize or 8,
				SearchFrameHeight = Configs.SearchConfig and Configs.SearchConfig.SearchFrameHeight or 21,
				SearchFrameOffset = Configs.SearchConfig and Configs.SearchConfig.SearchFrameOffset or 5,
				IconSize = Configs.SearchConfig and Configs.SearchConfig.IconSize or 12,
				IconPosition = Configs.SearchConfig and Configs.SearchConfig.IconPosition or 6,
				InputOffset = Configs.SearchConfig and Configs.SearchConfig.InputOffset or 23,
				NoResultText = CustomNoResultText or TranslateText("No options found"),
				NoResultTextSize = Configs.SearchConfig and Configs.SearchConfig.NoResultTextSize or 9,
				PrefixOnly = DPrefixOnly == true
			}

			local Button, LabelFunc = ButtonFrame(Container, DName, DDesc, UDim2.new(1, -180))

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

			local Arrow = Create("ImageLabel", SelectedFrame, {
				Size = UDim2.new(0, 15, 0, 15),
				Position = UDim2.new(0, -5, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				Image = "rbxassetid://10709791523",
				BackgroundTransparency = 1
			})

			local NoClickFrame = Create("TextButton", DropdownHolder, {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Visible = false,
				Text = ""
			})

			local DropFrame = Create("Frame", NoClickFrame, {
				Size = UDim2.new(SelectedFrame.Size.X, 0, 0),
				BackgroundTransparency = 0.1,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
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
			local SearchMessage
			local SearchResizePending = false

			do
				SearchFrame = InsertTheme(Create("Frame", DropFrame, {
					Size = UDim2.new(1, -16, 0, SearchConfig.SearchFrameHeight),
					Position = UDim2.new(0, 8, 0, SearchConfig.SearchFrameOffset),
					BackgroundColor3 = Theme["Color Hub 2"],
					Visible = SearchConfig.Enabled
				}), "Stroke")

				Make("Corner", SearchFrame, UDim.new(0, 4))

				SearchIcon = Create("ImageLabel", SearchFrame, {
					Size = UDim2.fromOffset(SearchConfig.IconSize, SearchConfig.IconSize),
					Position = UDim2.new(0, SearchConfig.IconPosition, 0.5),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://10734943674",
					ImageColor3 = Theme["Color Dark Text"]
				})

				SearchInputFrame = Create("Frame", SearchFrame, {
					Size = UDim2.new(1, -27, 1, 0),
					Position = UDim2.new(0, SearchConfig.InputOffset, 0, 0),
					BackgroundTransparency = 1,
					ClipsDescendants = true
				})

				SearchInput = InsertTheme(Create("TextBox", SearchInputFrame, {
					Size = UDim2.new(1, -2, 1, 0),
					Position = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					Font = Enum.Font.GothamBold,
					Text = "",
					PlaceholderText = SearchConfig.Placeholder,
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
				}), "Text")

				TrackConnection(TrackDropdownConnection(Connection.LanguageChanged:Connect(function()
					if SearchInput and SearchInput.Parent and not CustomSearchPlaceholder then
						SearchInput.PlaceholderText = TranslateText("Search...")
					end
					if SearchMessage and SearchMessage.Parent and not CustomNoResultText then
						SearchMessage.Text = TranslateText("No options found")
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
				SearchInput:GetPropertyChangedSignal("Text"):Connect(UpdateSearchTextSize)
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
					Padding = UDim.new(0, 4)
				})
			}), "ScrollBar")

			local ScrollSize, WaitClick = 5

			local function Disable()
				if not NoClickFrame.Visible or WaitClick then return end
				WaitClick = true

				CreateTween({Arrow, "Rotation", 0, AnimationDropdown})
				CreateTween({DropFrame, "Size", UDim2.new(0, 152, 0, 0), AnimationDropdown, true})
				CreateTween({Arrow, "ImageColor3", Color3.fromRGB(255, 255, 255), AnimationDropdown})

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
				Arrow.ImageColor3 = Color3.fromRGB(255, 255, 255)
				if SearchInput then SearchInput:ReleaseFocus() end
			end

			local function GetFrameSize()
				return UDim2.fromOffset(152, ScrollSize)
			end

			local function CalculateSize()
				local Count = 0

				for _, Frame in pairs(ScrollFrame:GetChildren()) do
					if Frame:IsA("TextButton") then
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
					CreateTween({Arrow, "ImageColor3", Color3.fromRGB(255, 255, 255), AnimationDropdown})
					CreateTween({DropFrame, "Size", UDim2.new(0, 152, 0, 0), AnimationDropdown, true})
					NoClickFrame.Visible = false
				else
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

			local AddNewOptions, GetOptions, AddOption, RemoveOption, Selected, SetSearchEnabled, SetPrefixOnly

			do
				local Default = type(OpDefault) ~= "table" and {OpDefault} or OpDefault

				local MultiSelect = DMultiSelect
				local MultiMax = tonumber(DMultiConfig.Max) or math.huge
				local MultiMin = tonumber(DMultiConfig.Min) or 0

				MultiMax = math.max(0, MultiMax)
				MultiMin = math.max(0, MultiMin)

				if MultiMax ~= math.huge and MultiMin > MultiMax then
					MultiMin = MultiMax
				end

				local Options = {}

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
					Selected = CheckFlag(Flag) and GetFlag(Flag) or Default[1]
				end

				local function GetOptionName(Value, Index)
					if type(Value) == "table" then
						return tostring(
							Value.Name
							or Value.DisplayName
							or Value.Label
							or Index
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
							Value.Name
							or Value.DisplayName
							or Value.Label
							or ""
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
							ActiveLabel.Text = TranslateText(tostring(Default[1] or "..."))
						end
					else
						if Selected ~= nil then
							ActiveLabel.Text = GetSelectedText(Selected)
						else
							ActiveLabel.Text = TranslateText(tostring(Default[1] or "..."))
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
						local OptionButton = Value.nodes[1]
						local OptionName = TranslateText(Value.Name)

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
								Option.nodes[1].Visible = true
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

					Options[Name] = {
						index = Index,
						Value = Value,
						Name = Name,
						Stats = false
					}

					if MultiSelect then
						local Stats = Selected[Name] == true
						Selected[Name] = Stats
						Options[Name].Stats = Stats
					end

					local OptionButton = Make("Button", ScrollFrame, {
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
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.new(0, 10),
						Text = TranslateText(Name),
						TextColor3 = Theme["Color Text"],
						Font = Enum.Font.GothamBold,
						TextXAlignment = "Left",
						BackgroundTransparency = 1,
						TextTransparency = 0.4
					}), "Text")

					Options[Name].nodes = {
						OptionButton,
						IsSelected,
						OptioneName
					}

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

						Options[Name].nodes[1]:Destroy()
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

				TrackDropdownConnection(Connection.LanguageChanged:Connect(function()
					for _, Option in pairs(Options) do
						if Option.nodes and Option.nodes[3] and Option.nodes[3].Parent then
							Option.nodes[3].Text = TranslateText(Option.Name)
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
					LabelFunc:SetTitle(tostring(Value or ""))
				end

				function Dropdown:SetDesc(Value)
					LabelFunc:SetDesc(tostring(Value or ""))
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

				return RegisterFlagObject(Flag, Dropdown, Button)
			end
		end
		function Tab:AddPlayers(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local PName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Players")
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

				local NameLower = Name:lower()
				local DisplayLower = DisplayName:lower()

				local NameMatch = NameLower:sub(1, #SearchText) == SearchText
				local DisplayMatch = DisplayLower:sub(1, #SearchText) == SearchText

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
				if PlayerDropdown then PlayerDropdown:SetTitle(tostring(Value or "")) end
			end
			function PlayersElement:SetDesc(Value)
				if PlayerDropdown then PlayerDropdown:SetDesc(tostring(Value or "")) end
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
			local SName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Selector")
			local SDesc = Configs.Desc or Configs.Description or ""
			local Options = Configs[2] or Configs.Options
			local SOptions = type(Options) == "table" and table.clone(Options) or {}
			local SDefault = Configs[3] or Configs.Default or 1
			local Callback = Funcs:GetCallback(Configs, 4)
			local Flag = Configs[5] or Configs.Flag or false
			local Wrap = Configs.Wrap == true or Configs.Loop == true
			
			local HoverCorner = 3

			local Button, LabelFunc = ButtonFrame(Container, SName, SDesc, UDim2.new(1, -180), false)

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
					return tostring(Option.Name or Option.DisplayName or Option.Label or Option.Value or Option)
				end
				return tostring(Option)
			end

			local function FindOption(Value)
				for i, Option in ipairs(SOptions) do
					if Option == Value or (type(Value) == "string" and (tostring(Option) == Value or OptionText(Option) == Value)) then
						return i
					end
					if type(Option) == "table" and type(Value) == "table" then
						local OptionKey = Option.Value or Option.Name or Option.DisplayName or Option.Label
						local ValueKey = Value.Value or Value.Name or Value.DisplayName or Value.Label
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

			local SavedValue = CheckFlag(Flag) and GetFlag(Flag) or nil
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
				LabelFunc:SetTitle(tostring(Value or ""))
			end

			function Selector:SetDesc(Value)
				LabelFunc:SetDesc(tostring(Value or ""))
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
		function Tab:AddSlider(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local SName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Slider!")
			local SDesc = Configs.Desc or Configs.Description or ""
			local Min = tonumber(Configs[2] or Configs.MinValue or Configs.Min) or 10
			local Max = tonumber(Configs[3] or Configs.MaxValue or Configs.Max) or 100
			if Min > Max then Min, Max = Max, Min end
			local Step = math.abs(tonumber(Configs[4] or Configs.Increase) or 1)
			if Step <= 0 or Step ~= Step then Step = 1 end
			local Callback = Funcs:GetCallback(Configs, 6)
			local Flag = Configs[7] or Configs.Flag or false
			local Default = Configs[5] or Configs.Default or 25
			if CheckFlag(Flag) then Default = GetFlag(Flag) end

			local Button, LabelFunc = ButtonFrame(Container, SName, SDesc, UDim2.new(1, -180), false)
			local SliderHolder = Create("TextButton", Button, {
				Size = UDim2.new(0.45, 0, 1),
				Position = UDim2.new(1),
				AnchorPoint = Vector2.new(1, 0),
				AutoButtonColor = false,
				Text = "",
				BackgroundTransparency = 1
			})
			local SliderBar = InsertTheme(Create("Frame", SliderHolder, {
				BackgroundColor3 = Theme["Color Stroke"],
				Size = UDim2.new(1, -20, 0, 6),
				Position = UDim2.new(0.5, 0, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5)
			}), "Stroke")Make("Corner", SliderBar)
			local Indicator = InsertTheme(Create("Frame", SliderBar, {
				BackgroundColor3 = Theme["Color Theme"],
				Size = UDim2.fromScale(0, 1),
				BorderSizePixel = 0
			}), "Theme")Make("Corner", Indicator)
			local SliderIcon = Create("Frame", SliderBar, {
				Size = UDim2.new(0, 6, 0, 12),
				BackgroundColor3 = Color3.fromRGB(220, 220, 220),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 0.2
			})Make("Corner", SliderIcon)
			local LabelVal = InsertTheme(Create("TextLabel", SliderHolder, {
				Size = UDim2.new(0, 14, 0, 14),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(0, 0, 0.5),
				BackgroundTransparency = 1,
				TextColor3 = Theme["Color Text"],
				Font = Enum.Font.FredokaOne,
				TextSize = 12
			}), "Text")

			local Value
			local Dragging = false
			local DragInput
			local MoveConnection
			local EndConnection
			local WasScrolling
			local Destroyed = false
			local function SetValue(ValueInput, Silent, Force)
				local Number = tonumber(ValueInput)
				if not Number or Number ~= Number then return false end
				Number = math.clamp(Number, Min, Max)
				Number = math.min(Max, Min + math.floor((Number - Min) / Step + 0.5) * Step)
				Number = tonumber(string.format("%.6f", Number))
				if not Force and Value == Number then return true end
				Value = Number
				local Fraction = Max == Min and 0 or math.clamp((Number - Min) / (Max - Min), 0, 1)
				SliderIcon.Position = UDim2.fromScale(Fraction, 0.5)
				Indicator.Size = UDim2.fromScale(Fraction, 1)
				LabelVal.Text = tostring(Number)
				SetFlag(Flag, Number)
				if not Silent then Funcs:FireCallback(Callback, Number) end
				return true
			end
			local function UpdateFromPosition(ScreenX)
				local Width = SliderBar.AbsoluteSize.X
				if Width <= 0 then return end
				local Fraction = math.clamp((ScreenX - SliderBar.AbsolutePosition.X) / Width, 0, 1)
				SetValue(Min + (Max - Min) * Fraction, false)
			end
			local function FinishDrag()
				if not Dragging then return end
				Dragging = false
				DragInput = nil
				if MoveConnection then MoveConnection:Disconnect() MoveConnection = nil end
				if EndConnection then EndConnection:Disconnect() EndConnection = nil end
				Container.ScrollingEnabled = WasScrolling
				SliderIcon.BackgroundTransparency = 0.2
			end

			local TabVisibilityConnection = Container:GetPropertyChangedSignal("Visible"):Connect(function()
				if not Container.Visible then FinishDrag() end
			end)
			SliderHolder.InputBegan:Connect(function(Input)
				if Destroyed or not Button.Interactable or Dragging then return end
				if Input.UserInputType ~= Enum.UserInputType.MouseButton1
					and Input.UserInputType ~= Enum.UserInputType.Touch then return end
				Dragging = true
				DragInput = Input.UserInputType == Enum.UserInputType.Touch and Input or nil
				WasScrolling = Container.ScrollingEnabled
				Container.ScrollingEnabled = false
				SliderIcon.BackgroundTransparency = 0
				UpdateFromPosition(Input.Position.X)
				MoveConnection = UserInputService.InputChanged:Connect(function(Changed)
					if DragInput then
						if Changed == DragInput then UpdateFromPosition(Changed.Position.X) end
					elseif Changed.UserInputType == Enum.UserInputType.MouseMovement then
						UpdateFromPosition(Changed.Position.X)
					end
				end)
			EndConnection = UserInputService.InputEnded:Connect(function(Ended)
					if DragInput then
						if Ended == DragInput then FinishDrag() end
					elseif Ended.UserInputType == Enum.UserInputType.MouseButton1 then
						FinishDrag()
					end
				end)
			end)

			local Slider = {}
			function Slider:Set(Val1, Val2)
				if type(Val1) == "string" then
					LabelFunc:SetTitle(Val1)
					if type(Val2) == "string" then LabelFunc:SetDesc(Val2) end
				elseif type(Val1) == "function" then
					Callback = {Val1}
				elseif type(Val1) == "number" then
					SetValue(Val1)
				end
			end
			function Slider:SetTitle(Title)
				LabelFunc:SetTitle(tostring(Title or ""))
			end
			function Slider:SetDesc(Desc)
				LabelFunc:SetDesc(tostring(Desc or ""))
			end
			function Slider:Get() return Value end
			function Slider:SetValue(NewValue, Silent)
				return SetValue(NewValue, Silent == true)
			end
			function Slider:Callback(...)
				local Added = Funcs:InsertCallback(Callback, ...)
				if type(Added) == "function" then Added(Value) end
			end
			function Slider:Visible(...) Funcs:ToggleVisible(Button, ...) end
			function Slider:Destroy()
				if Destroyed then return end
				FinishDrag()
				Destroyed = true
				TabVisibilityConnection:Disconnect()
				Button:Destroy()
			end

			SetValue(Default, false, true)
			ApplyLocked(Slider, Button, Configs, function(IsLocked)
				if IsLocked then FinishDrag() end
			end)
			return RegisterFlagObject(Flag, Slider, Button)
		end
		function Tab:AddTextBox(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local TName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Text Box")
			local TDesc = Configs.Desc or Configs.Description or ""
			local TDefault = Configs[2] or Configs.Default or ""
			local Flag = Configs.Flag
			if CheckFlag(Flag) then TDefault = GetFlag(Flag) end
			local TPlaceholderText = TranslateText(tostring(Configs[5] or Configs.PlaceholderText or "Input"))
			local TClearText = Configs[3] or Configs.ClearText or false
			local Callback = Funcs:GetCallback(Configs, 4)
			local Mod = Configs.Mod

			if type(TDefault) ~= "string" then TDefault = tostring(TDefault or "") end

			local Button, LabelFunc = ButtonFrame(Container, TName, TDesc, UDim2.new(1, -38), false)

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

			local function Input()
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
				Funcs:FireCallback(Callback, Text)
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

			TextBoxInput.FocusLost:Connect(Input)
			TextBoxInput.Text = ApplyMod(TDefault)
			Input()

			TextBoxInput.FocusLost:Connect(function()
				CreateTween({
					Pencil,
					"ImageColor3",
					Color3.fromRGB(255, 255, 255),
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

			function TextBox:Set(Text)
				if type(Text) ~= "string" then
					return
				end

				TextBoxInput.Text = Text
				Input()
			end

			function TextBox:SetPlaceholder(Text)
				if type(Text) ~= "string" then
					return
				end

				TextBoxInput.PlaceholderText = TranslateText(Text)
			end

			function TextBox:SetTitle(Value)
				LabelFunc:SetTitle(tostring(Value or ""))
			end

			function TextBox:SetDesc(Value)
				LabelFunc:SetDesc(tostring(Value or ""))
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
		function Tab:AddKeybind(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			if not UserInputService.KeyboardEnabled then return end

			local KName = Configs[1] or Configs.Name or Configs.Title or TranslateText("Keybind")
			local KDesc = Configs.Desc or Configs.Description or ""
			local DefaultValue = Configs.Default
			local KDefault = Configs.Value or Configs.Key or Configs.Keybind or Configs[2]

			if KDefault == nil and (type(DefaultValue) == "string" or typeof(DefaultValue) == "EnumItem") then
				KDefault = DefaultValue
			end

			KDefault = KDefault or Enum.KeyCode.LeftShift

			local Default = Configs.Enabled == true or Configs.State == true or DefaultValue == true
			local Toggle = Configs.Toggle ~= false
			local PreventDuplicate = Configs.PreventDuplicate == true
			local DisabledKeys = Configs.DisabledKeys or {}
			local Callback = Funcs:GetCallback(Configs, 3)

			local Keybind = {}
			local CurrentKey
			local Enabled = Toggle and Default or false
			local Waiting = false
			local Destroyed = false

			local function ResolveKey(Key)
				if typeof(Key) == "EnumItem" and Key.EnumType == Enum.KeyCode then
					return Key
				end

				if type(Key) == "string" then
					Key = Key:gsub("^%s*(.-)%s*$", "%1")

					for _, EnumKey in ipairs(Enum.KeyCode:GetEnumItems()) do
						if EnumKey.Name:lower() == Key:lower() then
							return EnumKey
						end
					end
				end

				return nil
			end

			local function IsDisabled(Key)
				for _, DisabledKey in ipairs(DisabledKeys) do
					if ResolveKey(DisabledKey) == Key then
						return true
					end
				end

				return false
			end

			local function IsDuplicate(Key)
				if not PreventDuplicate then
					return false
				end

				local Registered = KeybindRegistry[Key]
				return Registered and Registered ~= Keybind
			end

			local function RegisterKey(Key)
				if not Key or Key == Enum.KeyCode.Unknown or IsDisabled(Key) or IsDuplicate(Key) then
					return false
				end

				if CurrentKey and KeybindRegistry[CurrentKey] == Keybind then
					KeybindRegistry[CurrentKey] = nil
				end

				CurrentKey = Key

				if PreventDuplicate then
					KeybindRegistry[CurrentKey] = Keybind
				end

				return true
			end

			local Button, LabelFunc = ButtonFrame(
				Container,
				KName,
				KDesc,
				UDim2.new(1, -38),
				false
			)

			local SelectedFrame = InsertTheme(Create("Frame", Button, {
				Size = UDim2.fromOffset(30, 18),
				Position = UDim2.new(1, -10, 0.5),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Theme["Color Stroke"]
			}), "Stroke")

			Make("Corner", SelectedFrame, UDim.new(0, 4))

			local KeyButton = InsertTheme(Create("TextButton", SelectedFrame, {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = Theme["Color Text"],
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = "..."
			}), "Text")

			local SizeConstraint = Create("UISizeConstraint", SelectedFrame, {
				MinSize = Vector2.new(25, 18)
			})

			local function GetDisplayText()
				if Waiting then
					return "..."
				end

				return CurrentKey and CurrentKey.Name or "None"
			end

			local function UpdateSize()
				if Destroyed then
					return
				end

				local Text = GetDisplayText()
				local MaxWidth = math.max(25, Button.AbsoluteSize.X - 100)

				local TextWidth = TextService:GetTextSize(
					Text,
					10,
					Enum.Font.GothamBold,
					Vector2.new(1000, 18)
				).X + 16

				KeyButton.Text = Text
				SizeConstraint.MaxSize = Vector2.new(MaxWidth, 18)

				SelectedFrame.Size = UDim2.fromOffset(
					math.clamp(TextWidth, 25, MaxWidth),
					18
				)
			end

			local function UpdateState()
				if not Toggle then
					return
				end

				CreateTween({
					SelectedFrame,
					"BackgroundColor3",
					Enabled and Theme["Color Theme"] or Theme["Color Stroke"],
					0.2
				})
			end

			local function SetWaiting(Value)
				if Value and CapturingKeybind ~= Keybind and CancelKeybindCapture then
					CancelKeybindCapture()
				end

				Waiting = Value

				if Value then
					CapturingKeybind = Keybind

					CancelKeybindCapture = function()
						if not Destroyed and Waiting then
							SetWaiting(false)
						end
					end
				elseif CapturingKeybind == Keybind then
					CapturingKeybind = nil
					CancelKeybindCapture = nil
				end

				UpdateSize()
			end

			local function SetState(State, Fire)
				if not Toggle or type(State) ~= "boolean" then
					return
				end

				Enabled = State
				UpdateState()

				if Fire then
					Funcs:FireCallback(Callback, Enabled)
				end
			end

			local function SetKey(Key)
				Key = ResolveKey(Key)

				if not RegisterKey(Key) then
					return false
				end

				UpdateSize()
				return true
			end

			local InitialKey = ResolveKey(KDefault) or Enum.KeyCode.LeftShift

			if not RegisterKey(InitialKey) and not RegisterKey(Enum.KeyCode.LeftShift) then
				for _, Key in ipairs(Enum.KeyCode:GetEnumItems()) do
					if Key ~= Enum.KeyCode.Unknown and RegisterKey(Key) then
						break
					end
				end
			end

			UpdateState()
			UpdateSize()

			ApplyLocked(Keybind, Button, Configs, function(IsLocked)
				if IsLocked and Waiting then
					SetWaiting(false)
				end
			end)

			local MouseConnection = KeyButton.InputBegan:Connect(function(Input)
				if Input.UserInputType ~= Enum.UserInputType.MouseButton1
					and Input.UserInputType ~= Enum.UserInputType.MouseButton2 then
					return
				end

				if Keybind:IsLocked() then
					Keybind:NotifyLocked()
					return
				end

				SetWaiting(true)
			end)

			local InputConnection = TrackConnection(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
				if Input.UserInputType ~= Enum.UserInputType.Keyboard then
					return
				end

				if Keybind:IsLocked() then
					if Waiting or Input.KeyCode == CurrentKey then
						Keybind:NotifyLocked()
					end

					return
				end

				if Waiting then
					if Input.KeyCode ~= Enum.KeyCode.Unknown and SetKey(Input.KeyCode) then
						CapturedKeys[Input.KeyCode] = true

						SetWaiting(false)

						if type(Configs.OnChanged) == "function" then
							Configs.OnChanged(CurrentKey)
						end
					end

					return
				end

				if GameProcessed then
					return
				end

				if Input.KeyCode ~= CurrentKey then
					return
				end

				if Toggle then
					SetState(not Enabled, true)
				else
					Funcs:FireCallback(Callback, true)
				end
			end))

			local SizeConnection = Button:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateSize)

			local function CancelHiddenCapture()
				if not Waiting then
					return
				end

				if not Button.Visible
					or not Container.Visible
					or not MainFrame.Visible
					or Minimized
					or not Container:IsDescendantOf(ScreenGui) then
					SetWaiting(false)
				end
			end

			local AncestryConnection = Container.AncestryChanged:Connect(CancelHiddenCapture)
			local TabVisibilityConnection = Container:GetPropertyChangedSignal("Visible"):Connect(CancelHiddenCapture)

			local VisibilityConnection = MainFrame:GetPropertyChangedSignal("Visible"):Connect(
				CancelHiddenCapture
			)

			local ContentConnection = Containers:GetPropertyChangedSignal("Visible"):Connect(function()
				if Waiting and not Containers.Visible then
					SetWaiting(false)
				end
			end)

			local ButtonVisibilityConnection = Button:GetPropertyChangedSignal("Visible"):Connect(
				CancelHiddenCapture
			)

			local function Cleanup()
				if Destroyed then
					return
				end

				Destroyed = true

				if CapturingKeybind == Keybind then
					CapturingKeybind = nil
					CancelKeybindCapture = nil
				end

				Waiting = false

				if CurrentKey and KeybindRegistry[CurrentKey] == Keybind then
					KeybindRegistry[CurrentKey] = nil
				end

				MouseConnection:Disconnect()
				InputConnection:Disconnect()
				SizeConnection:Disconnect()
				AncestryConnection:Disconnect()
				TabVisibilityConnection:Disconnect()
				VisibilityConnection:Disconnect()
				ContentConnection:Disconnect()
				ButtonVisibilityConnection:Disconnect()

				UntrackConnection(InputConnection)
			end

			local DestroyingConnection

			DestroyingConnection = Button.Destroying:Connect(function()
				Cleanup()

				if DestroyingConnection then
					DestroyingConnection:Disconnect()
					DestroyingConnection = nil
				end
			end)

			task.defer(UpdateSize)

			function Keybind:Set(Value)
				if Toggle and type(Value) == "boolean" then
					SetState(Value, true)
				elseif type(Value) == "string" then
					LabelFunc:SetTitle(Value)
				end
			end

			function Keybind:Get()
				if not Toggle then
					return nil
				end

				return Enabled
			end

			function Keybind:SetKeybind(Key)
				return SetKey(Key)
			end

			function Keybind:SetTitle(Value)
				LabelFunc:SetTitle(tostring(Value or ""))
			end

			function Keybind:SetDesc(Value)
				LabelFunc:SetDesc(tostring(Value or ""))
			end

			function Keybind:GetKeybind()
				return CurrentKey
			end

			function Keybind:Callback(Func)
				Funcs:InsertCallback(Callback, Func)
			end

			function Keybind:Visible(...)
				Funcs:ToggleVisible(Button, ...)
			end

			function Keybind:Destroy()
				if Destroyed then
					return
				end

				Cleanup()

				if Button.Parent then
					Button:Destroy()
				end
			end

			if PreventDuplicate and CurrentKey then
				KeybindRegistry[CurrentKey] = Keybind
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

			local Name = Configs[1] or Configs.Name or Configs.Title or TranslateText("Custom color")
			local Description = Configs.Desc or Configs.Description or ""
			local Callback = Funcs:GetCallback(Configs, 3)
			local Flag = Configs[4] or Configs.Flag or false
			local MaxRecent = math.clamp(math.floor(tonumber(Configs.MaxRecent) or 8), 0, 32)
			local SmoothTime = math.clamp(tonumber(Configs.SmoothTime) or ColorPickerSmoothTime, 0, 0.2)

			local DisplayMode = Configs.DisplayMode or Configs.Display or "Hex"
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

			local Default = Configs[2] or Configs.Default or "#137D81"
			local CurrentColor, DefaultFormat = ParseColor(Default)

			if not CurrentColor then
				CurrentColor = Color3.fromRGB(19, 125, 129)
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
				or DefaultFormat
				or "Color3"

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

			local Presets = Configs.Presets or {
				Color3.fromRGB(108, 99, 255),
				Color3.fromRGB(33, 150, 243),
				Color3.fromRGB(67, 181, 129),
				Color3.fromRGB(255, 193, 7),
				Color3.fromRGB(255, 107, 107),
				Color3.fromRGB(233, 30, 140),
				Color3.fromRGB(156, 106, 222),
				Color3.fromRGB(255, 255, 255)
			}

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

			local OptionWidth = ShowHex and ShowRGB
				and UDim2.new(1, -300)
				or UDim2.new(1, -230)

			local Option, Label = ButtonFrame(
				Container,
				Name,
				Description,
				OptionWidth,
				false
			)

			local Controls = Create("Frame", Option, {
				Size = UDim2.new(0, 0, 0, 20),
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

			if ShowHex then
				local HexFrame = Create("Frame", Controls, {
					Size = UDim2.new(0, 96, 1, 0),
					BackgroundColor3 = Theme["Color Stroke"],
					LayoutOrder = 1,
					ClipsDescendants = true
				})

				InsertTheme(HexFrame, "Stroke")
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
				local RGBFrame = Create("Frame", Controls, {
					Size = UDim2.new(0, 104, 1, 0),
					BackgroundColor3 = Theme["Color Stroke"],
					LayoutOrder = 2,
					ClipsDescendants = true
				})

				InsertTheme(RGBFrame, "Stroke")
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

			local PreviewButton = Create("TextButton", Controls, {
				Size = UDim2.new(0, 50, 1, 0),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = 3
			})

			local ColorPreview = Create("Frame", PreviewButton, {
				Size = UDim2.new(0, 20, 0, 20),
				Position = UDim2.new(0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = CurrentColor,
				BorderSizePixel = 0
			})

			Make("Corner", ColorPreview, UDim.new(0, 5))

			local Arrow = Create("ImageLabel", PreviewButton, {
				Size = UDim2.new(0, 16, 0, 16),
				Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Image = Library:GetIcon("chevrondown"),
				ImageColor3 = Theme["Color Text"]
			})

			InsertTheme(Arrow, "Text")

			local PickerFrame = Create("Frame", Container, {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundColor3 = Theme["Color Hub 2"],
				ClipsDescendants = true,
				Visible = false
			})

			InsertTheme(PickerFrame, "Hub 2")
			Make("Corner", PickerFrame, UDim.new(0, 6))

			local PickerContent = Create("Frame", PickerFrame, {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1
			}, {
				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10)
				}),
				Create("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12)
				})
			})

			local RecentLabel = Create("TextLabel", PickerContent, {
				Size = UDim2.new(1, 0, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Theme["Color Dark Text"],
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = TranslateText("Recent"),
				LayoutOrder = 0
			})

			InsertTheme(RecentLabel, "DarkText")

			local RecentHolder = Create("Frame", PickerContent, {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				LayoutOrder = 1
			}, {
				Create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8)
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
				Size = UDim2.new(1, 0, 1, 0),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255)
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
				Size = UDim2.new(0, 7, 0, 22),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				BackgroundColor3 = Color3.fromRGB(230, 230, 230),
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
				Size = UDim2.new(1, 0, 1, 0),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1)
			})

			Make("Corner", SaturationBackground, UDim.new(0.5, 0))

			local SaturationGradient = Create("UIGradient", SaturationBackground)

			local SaturationIndicator = Create("Frame", SaturationBackground, {
				Size = UDim2.new(0, 7, 0, 22),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(230, 230, 230),
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
				Size = UDim2.new(1, 0, 1, 0),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(0, 0, 0)
			})

			Make("Corner", BrightnessBackground, UDim.new(0.5, 0))

			local BrightnessGradient = Create("UIGradient", BrightnessBackground)

			local BrightnessIndicator = Create("Frame", BrightnessBackground, {
				Size = UDim2.new(0, 7, 0, 22),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(230, 230, 230),
				BackgroundTransparency = 0.1,
				ZIndex = 2
			})

			Make("Corner", BrightnessIndicator)

			local Expanded = false
			local CurrentColorValue = CurrentColor
			local Hue, Saturation, Brightness = CurrentColor:ToHSV()

			if Saturation == 0 then
				Saturation = 1
			end

			local function CreateRecentButton(Parent, Color)
				local Button = Create("TextButton", Parent, {
					Size = UDim2.new(0, 22, 0, 22),
					BackgroundColor3 = Color,
					AutoButtonColor = false,
					Text = ""
				})

				Make("Corner", Button, UDim.new(0, 5))

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

			local IndicatorLastUpdate = setmetatable({}, {__mode = "k"})

			local function UpdateIndicator(Indicator, Background, Value, Smooth)
				local Width = Background.AbsoluteSize.X
				local Half = Indicator.AbsoluteSize.X / 2

				if Width <= 0 then
					return
				end

				local Scale = math.clamp(
					(Value * (Width - Half * 2) + Half) / Width,
					0,
					1
				)

				local Target = UDim2.new(Scale, 0, 0.5, 0)

				if Smooth and SmoothTime > 0 then
					local Now = os.clock()
					local Last = IndicatorLastUpdate[Indicator] or (Now - 1 / 60)
					local Delta = math.clamp(Now - Last, 1 / 240, 0.05)
					local Alpha = 1 - math.exp(-Delta / SmoothTime)
					IndicatorLastUpdate[Indicator] = Now
					Indicator.Position = Indicator.Position:Lerp(Target, Alpha)
				else
					IndicatorLastUpdate[Indicator] = nil
					Indicator.Position = Target
				end
			end

			local function UpdateIndicators(SmoothIndicator)
				UpdateIndicator(HueIndicator, HueBackground, Hue, SmoothIndicator == HueIndicator)
				UpdateIndicator(SaturationIndicator, SaturationBackground, Saturation, SmoothIndicator == SaturationIndicator)
				UpdateIndicator(BrightnessIndicator, BrightnessBackground, Brightness, SmoothIndicator == BrightnessIndicator)
			end

			local function UpdateGradients()
				local HueColor = Color3.fromHSV(Hue, 1, 1)

				SaturationGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, HueColor)
				})

				BrightnessGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(Hue, Saturation, 1))
				})
			end

			SetColor = function(Color, FireCallback, AddToRecent)
				CurrentColorValue = Color

				Hue, Saturation, Brightness = Color:ToHSV()

				if Saturation == 0 then
					Saturation = 1
				end

				ColorPreview.BackgroundColor3 = Color

				if HexInput and not HexInput:IsFocused() then
					HexInput.Text = ColorToHex(Color)
				end

				if RGBInput and not RGBInput:IsFocused() then
					RGBInput.Text = ColorToRGB(Color)
				end

				UpdateGradients()
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

			local function ApplyHSV(FireCallback, AddToRecent, SmoothIndicator)
				local Color = Color3.fromHSV(
					Hue,
					Saturation,
					Brightness
				)

				CurrentColorValue = Color
				ColorPreview.BackgroundColor3 = Color

				if HexInput and not HexInput:IsFocused() then
					HexInput.Text = ColorToHex(Color)
				end

				if RGBInput and not RGBInput:IsFocused() then
					RGBInput.Text = ColorToRGB(Color)
				end

				UpdateGradients()
				UpdateIndicators(SmoothIndicator)

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

			local function SetExpanded(Value)
				Expanded = Value == nil and not Expanded or Value

				if Expanded then
					PickerFrame.Visible = true
					PickerFrame.Size = UDim2.new(1, 0, 0, 0)

					CreateTween({
						Arrow,
						"Rotation",
						180,
						0.25
					})

					CreateTween({
						PickerFrame,
						"Size",
						UDim2.new(1, 0, 0, 225),
						0.25
					})
				else
					CreateTween({
						Arrow,
						"Rotation",
						0,
						0.25
					})

					local Tween = CreateTween({
						PickerFrame,
						"Size",
						UDim2.new(1, 0, 0, 0),
						0.35
					})

					Tween.Completed:Once(function()
						if not Expanded and PickerFrame.Parent then
							PickerFrame.Size = UDim2.new(1, 0, 0, 0)
							PickerFrame.Visible = false
						end
					end)
				end

				task.defer(UpdateIndicators)
			end

			PreviewButton.Activated:Connect(function()
				SetExpanded()
			end)

			local function GetSliderValue(Input, Background, Indicator)
				local Width = Background.AbsoluteSize.X
				local X = Input.Position.X - Background.AbsolutePosition.X
				local Half = Indicator.AbsoluteSize.X / 2

				local Range = math.max(Width - Half * 2, 1)

				return math.clamp((X - Half) / Range, 0, 1)
			end

			local HueDragging = false
			local SaturationDragging = false
			local BrightnessDragging = false
			local DragInput
			local MoveConnection
			local EndConnection
			local PreviousScrolling

			local function UpdateHue(Input)
				Hue = GetSliderValue(Input, HueBackground, HueIndicator)
				ApplyHSV(false, false, HueIndicator)
			end

			local function UpdateSaturation(Input)
				Saturation = GetSliderValue(Input, SaturationBackground, SaturationIndicator)
				ApplyHSV(false, false, SaturationIndicator)
			end

			local function UpdateBrightness(Input)
				Brightness = GetSliderValue(Input, BrightnessBackground, BrightnessIndicator)
				ApplyHSV(false, false, BrightnessIndicator)
			end

			local function FinishColorDrag(Commit)
				local Changed = HueDragging or SaturationDragging or BrightnessDragging
				if not Changed then return end
				HueDragging, SaturationDragging, BrightnessDragging = false, false, false
				DragInput = nil
				if MoveConnection then MoveConnection:Disconnect() MoveConnection = nil end
				if EndConnection then EndConnection:Disconnect() EndConnection = nil end
				Container.ScrollingEnabled = PreviousScrolling
				CreateTween({HueIndicator, "Size", UDim2.new(0, 7, 0, 22), 0.15})
				CreateTween({SaturationIndicator, "Size", UDim2.new(0, 7, 0, 22), 0.15})
				CreateTween({BrightnessIndicator, "Size", UDim2.new(0, 7, 0, 22), 0.15})
				if Commit then ApplyHSV(true, true) end
			end

			local function StartDrag(Indicator, CallbackFunction, Input)
				if MoveConnection then return end
				DragInput = Input.UserInputType == Enum.UserInputType.Touch and Input or nil
				PreviousScrolling = Container.ScrollingEnabled
				Container.ScrollingEnabled = false
				CreateTween({Indicator, "Size", UDim2.new(0, 9, 0, 24), 0.15})
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
						if Ended == DragInput then FinishColorDrag(true) end
					elseif Ended.UserInputType == Enum.UserInputType.MouseButton1 then
						FinishColorDrag(true)
					end
				end)
			end

			HueBar.InputBegan:Connect(function(Input)
				if not Option.Interactable or MoveConnection then return end
				if Input.UserInputType == Enum.UserInputType.MouseButton1
					or Input.UserInputType == Enum.UserInputType.Touch then
					HueDragging = true
					StartDrag(HueIndicator, UpdateHue, Input)
				end
			end)

			SaturationBar.InputBegan:Connect(function(Input)
				if not Option.Interactable or MoveConnection then return end
				if Input.UserInputType == Enum.UserInputType.MouseButton1
					or Input.UserInputType == Enum.UserInputType.Touch then
					SaturationDragging = true
					StartDrag(SaturationIndicator, UpdateSaturation, Input)
				end
			end)

			BrightnessBar.InputBegan:Connect(function(Input)
				if not Option.Interactable or MoveConnection then return end
				if Input.UserInputType == Enum.UserInputType.MouseButton1
					or Input.UserInputType == Enum.UserInputType.Touch then
					BrightnessDragging = true
					StartDrag(BrightnessIndicator, UpdateBrightness, Input)
				end
			end)

			TrackColorConnection(Container:GetPropertyChangedSignal("Visible"):Connect(function()
				if not Container.Visible then FinishColorDrag(false) end
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
					Label:SetTitle(Value)
					Label:SetDesc(DescriptionValue)
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

					Label:SetTitle(Value)
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
					PickerFrame.Visible = false
					PickerFrame.Size = UDim2.new(1, 0, 0, 0)
				end

				Funcs:ToggleVisible(PickerFrame, Value and Expanded)
			end

			function ColorPicker:Expand(Value)
				SetExpanded(Value)
			end

			local ColorOption

			function ColorPicker:Destroy()
				FinishColorDrag(false)
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

				table.clear(IndicatorLastUpdate)

				Option:Destroy()
				PickerFrame:Destroy()
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

			return RegisterFlagObject(Flag, ColorPicker, Option)
		end
		function Tab:AddCode(Configs)
			Configs = type(Configs) == "table" and Configs or {}
			local LibraryCreate = Create
			local function Create(Class, Parent, Properties, Children)
				local Props = type(Parent) == "table" and Parent or Properties
				local Instance = LibraryCreate(Class, Parent, Properties, Children)
				if type(Props) == "table" and Props.Name then Instance.Name = "AddCode_" .. tostring(Props.Name) end
				return Instance
			end

			local TitleSource = tostring(Configs.Title or Configs.Name or "Code")
			local TitleText = TranslateText(TitleSource)
			local function NormalizeCode(Value)
				return tostring(Value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
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
			local InitialCode = NormalizeCode(Configs.Code or Configs.Source or Configs.Text)
			local ObservedCode, RenderedCode = InitialCode, nil
			local Language = tostring(Configs.Language or "Lua")
			local SavedCode = InitialCode
			local EditAllowed = Configs.Edit == true or Configs.Editable == true
			local CanExecute = Configs.Execute == true
			local CanCopy = Configs.Copy ~= false
			local ShowErrors = Configs.ShowErrors ~= false
			local OnChange = type(Configs.OnChange) == "function" and Configs.OnChange or nil
			local OnSave = type(Configs.OnSave) == "function" and Configs.OnSave or nil
			local FontSize = math.floor(NumberOption(Configs.FontSize, 13, 9, 32))
			local LineSpacing = NumberOption(Configs.LineSpacing, 1.16, 1, 3)
			local Bounds = Vector2.new(10000, 10000)
			local TwoLineHeight = TextService:GetTextSize("M\nM", FontSize, Enum.Font.Code, Bounds).Y
			local TenLineHeight = TextService:GetTextSize(string.rep("M\n", 9) .. "M", FontSize, Enum.Font.Code, Bounds).Y
			local NaturalAdvance = (TenLineHeight - TwoLineHeight) / 8
			local LineHeight = (NaturalAdvance > 0 and NaturalAdvance or TextService:GetTextSize("Ag", FontSize, Enum.Font.Code, Bounds).Y) * LineSpacing
			local CellWidth = TextService:GetTextSize(string.rep("M", 64), FontSize, Enum.Font.Code, Bounds).X / 64
			local HeaderHeight, Padding, BottomPadding = 30, 5, 6
			local MaxVisibleLines = math.floor(NumberOption(Configs.MaxVisibleLines, 8, 1, 60))
			local GutterWidth = 25
			local Editable, Focused, Destroyed, RefreshQueued, Executing = false, false, false, false, false
			local Lines, StyledLines, LineOffsets, LineCount, MaxLineWidth = {}, {}, {}, 1, 0
			local HighlightCache, Cached = {}, 0
			local WidthCache, WidthCached = {}, 0
			local LineLabels, NumberLabels, SelectionFrames, Buttons = {}, {}, {}, {}
			local Measurements, MeasurementCount = {}, 0
			local MeasurementTexts = setmetatable({}, {__mode = "k"})
			local QueueRefresh, QueueGeometry, QueueDiagnostics, DrawErrors
			local RenderVersion, DrawnVersion, DrawnFirst, DrawnLast = 0, -1, 0, 0
			local CopyToken, ExecutionToken = 0, 0
			local CopyTweens = {}
			local AutoClosers = {}
			local PairOpen = {['"'] = '"', ["'"] = "'", ["`"] = "`", ["("] = ")", ["["] = "]", ["{"] = "}"}
			local PairClose = {["("] = ")", ["["] = "]", ["{"] = "}"}
			local ClosingCharacters = {["\""] = true, ["'"] = true, ["`"] = true, [")"] = true, ["]"] = true, ["}"] = true}
			local SpinTween, BodyTween
			local ShakeToken = 0
			local ExternalConnections = {}
			local ActionPointer, PastePending, Saving = false, false, false
			local FlushText, TextQueued, TextWasEditing
			local Code = {}

			local Holder = InsertTheme(Create("Frame", Container, {
				Name = "CodeElement",
				Size = UDim2.new(1, 0, 0, 60),
				BackgroundColor3 = Theme["Color Hub 2"],
				BorderSizePixel = 0,
				ClipsDescendants = true
			}), "Frame")
			Make("Corner", Holder, UDim.new(0, ElementCornerRadius))

			local Header = Create("Frame", Holder, {
				Name = "Header",
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
					Button = Button,
					Icon = Icon,
					Scale = Scale,
					IconScale = IconScale,
					Selected = false,
					Hover = false,
					Press = false,
					GlowTween = nil
				}
				Buttons[#Buttons + 1] = Entry
				function Entry.StopGlow()
					if Entry.GlowTween then
						Entry.GlowTween:Cancel()
						Entry.GlowTween = nil
					end
				end
				function Entry.StartGlow()
					if Destroyed then return end
					local BaseColor = Theme["Color Theme"]
					local GlowColor = BaseColor:Lerp(Theme["Color Text"], 0.45)
					Entry.StopGlow()
					Icon.ImageColor3 = BaseColor
					Entry.GlowTween = TweenService:Create(Icon,
						TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ImageColor3 = GlowColor})
					Entry.GlowTween:Play()
				end
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
					if Entry.Selected then
						if Entry.Button.Name == "Edit" then
							Entry.StartGlow()
						else
							Entry.StopGlow()
							Icon.ImageColor3 = Theme["Color Theme"]
						end
					else
						Entry.StopGlow()
						Icon.ImageColor3 = Entry.Hover and Theme["Color Text"] or Theme["Color Dark Text"]
					end
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
				FileName.Size = UDim2.new(1, -(38 + Count * 24 + math.max(0, Count - 1) * 2), 1, 0)
			end

			local Body = Create("Frame", Holder, {
				Name = "Editor",
				Position = UDim2.fromOffset(5, HeaderHeight),
				Size = UDim2.new(1, -10, 1, -HeaderHeight - BottomPadding),
				BackgroundColor3 = Theme["Color Hub 2"]:Lerp(Color3.new(0, 0, 0), 0.28),
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
			local CaretGlow = Create("Frame", Scroll, {
				Name = "CaretGlow",
				Position = TextPosition,
				Size = UDim2.fromOffset(4, FontSize + 1),
				BackgroundColor3 = Theme["Color Theme"],
				BackgroundTransparency = 0.86,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 5
			})
			Make("Corner", CaretGlow, UDim.new(1, 0))
			local Caret = Create("Frame", Scroll, {
				Name = "Caret",
				Position = TextPosition,
				Size = UDim2.fromOffset(1.4, FontSize - 1),
				BackgroundColor3 = Theme["Color Theme"],
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 6
			})
			Make("Corner", Caret, UDim.new(1, 0))
			local BlinkInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			local Blink = TweenService:Create(Caret, BlinkInfo, {BackgroundTransparency = 0.85})
			local GlowBlink = TweenService:Create(CaretGlow, BlinkInfo, {BackgroundTransparency = 1})
			local MeasurementLayer = Create("Frame", Body, {
				Name = "MeasurementLayer",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true
			})
			local function EscapeRich(Text)
				return Text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
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
			local Toast, ToastText, ToastToken = nil, nil, 0
			local ToastSource, ToastValues
			local function PositionMessage()
				if Destroyed or not Toast or not Toast.Visible then return end
				local Scale = EffectiveScale()
				local View = ScreenGui.AbsoluteSize
				local Origin = ScreenGui.AbsolutePosition
				local HubPosition, HubSize = MainFrame.AbsolutePosition - Origin, MainFrame.AbsoluteSize
				if View.X <= 0 or View.Y <= 0 then return end
				local Margin = math.min(8 * Scale, View.X / 4, View.Y / 4)
				local Width = math.max(1, math.min(420 * Scale, HubSize.X - Margin * 2, View.X - Margin * 2))
				Toast.Size = UDim2.fromOffset(Width / Scale, Toast.Size.Y.Offset)
				local TextHeight = ToastText.TextBounds.Y
				local Height = math.min(math.max(32 * Scale, TextHeight + 16 * Scale), math.max(1, View.Y - Margin * 2))
				local X = math.clamp(HubPosition.X + (HubSize.X - Width) / 2, Margin, math.max(Margin, View.X - Width - Margin))
				local Below, Above = HubPosition.Y + HubSize.Y + Margin, HubPosition.Y - Height - Margin
				local Y = Below + Height <= View.Y - Margin and Below or Above >= Margin and Above
					or math.clamp(HubPosition.Y + HubSize.Y - Height - Margin, Margin, math.max(Margin, View.Y - Height - Margin))
				Toast.Position = UDim2.fromOffset(X / Scale, Y / Scale)
				Toast.Size = UDim2.fromOffset(Width / Scale, Height / Scale)
			end
			local function ShowCodeMessage(Message, Values)
				if Destroyed then return end
				ToastSource, ToastValues = tostring(Message), Values
				if not Toast then
					Toast = InsertTheme(Create("Frame", ScreenGui, {
						Name = "CodeToast", Size = UDim2.fromOffset(300, 32),
						BackgroundColor3 = Theme["Color Hub 2"], BorderSizePixel = 0,
						Visible = false, ClipsDescendants = true, ZIndex = 2000
					}), "Frame")
					Make("Corner", Toast, UDim.new(0, 7))
					Make("Stroke", Toast, {Color = Theme["Color Theme"], Transparency = 0.4})
					ToastText = InsertTheme(Create("TextLabel", Toast, {
						Name = "MessageText", Position = UDim2.fromOffset(10, 7),
						Size = UDim2.new(1, -20, 1, -14), BackgroundTransparency = 1,
						Font = Enum.Font.GothamMedium, TextSize = 10, TextWrapped = true,
						RichText = false, TextColor3 = Theme["Color Text"], ZIndex = 2001
					}), "Text")
					ToastText:GetPropertyChangedSignal("TextBounds"):Connect(PositionMessage)
				end
				ToastText.Text = TranslateText(ToastSource, ToastValues)
				ToastToken += 1
				local Token = ToastToken
				Toast.Visible = true
				PositionMessage()
				task.defer(PositionMessage)
				task.delay(3, function()
					if not Destroyed and Token == ToastToken then Toast.Visible = false end
				end)
			end
			local function ShakeCodeComponent()
				if Destroyed then return end
				ShakeToken += 1
				local Token = ShakeToken
				local HeaderBase = UDim2.fromOffset(0, 0)
				local BodyBase = UDim2.fromOffset(5, HeaderHeight)
				local Sequence = {-6, 5, -4, 3, -2, 0}
				for Index, Offset in ipairs(Sequence) do
					task.delay((Index - 1) * 0.032, function()
						if Destroyed or Token ~= ShakeToken then return end
						Header.Position = UDim2.new(HeaderBase.X.Scale, HeaderBase.X.Offset + Offset, HeaderBase.Y.Scale, HeaderBase.Y.Offset)
						Body.Position = UDim2.new(BodyBase.X.Scale, BodyBase.X.Offset + Offset, BodyBase.Y.Scale, BodyBase.Y.Offset)
					end)
				end
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

			local WidthProbe = "M"
			local WidthBounds = Vector2.new(1000000, 100000)
			local ProbeWidth = TextService:GetTextSize(WidthProbe, FontSize, Enum.Font.Code, WidthBounds).X
			local function MeasureWidth(Text)
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

			local function HighlightCode(Source, State)
				local Background = Theme["Color Hub 2"]
				local Light = Background and Background.R * 0.2126 + Background.G * 0.7152 + Background.B * 0.0722 > 0.55
				local function Color(DarkR, DarkG, DarkB, LightR, LightG, LightB)
					return Light and Color3.fromRGB(LightR, LightG, LightB) or Color3.fromRGB(DarkR, DarkG, DarkB)
				end
				local Colors = {
					Keyword = Color(198, 120, 221, 133, 55, 164),
					Global = Color(86, 182, 194, 0, 109, 125),
					Function = Color(97, 175, 239, 37, 100, 166),
					Property = Color(171, 201, 229, 42, 85, 125),
					Type = Color(229, 192, 123, 139, 86, 16),
					String = Color(152, 195, 121, 66, 121, 48),
					Escape = Color(209, 154, 102, 156, 80, 29),
					Number = Color(209, 154, 102, 156, 80, 29),
					Literal = Color(209, 154, 102, 156, 80, 29),
					Comment = Color(127, 143, 159, 92, 108, 120),
					Operator = Color(198, 120, 221, 133, 55, 164),
					Punctuation = Color(171, 178, 191, 65, 75, 90),
					Attribute = Color(229, 192, 123, 139, 86, 16)
				}
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

			local function DrawVisibleLines()
				if Destroyed then return end
				local View = ViewSize()
				local HiddenY = (Scroll.AbsolutePosition.Y - Input.AbsolutePosition.Y) / EffectiveScale()
				local First = math.clamp(math.floor(HiddenY / LineHeight) + 1, 1, LineCount)
				local Last = math.min(LineCount, First + math.ceil(math.max(View.Y, LineHeight) / LineHeight) + 1)
				if DrawnVersion == RenderVersion and DrawnFirst == First and DrawnLast == Last then return end
				DrawnVersion, DrawnFirst, DrawnLast = RenderVersion, First, Last
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
							TextSize = FontSize,
							TextTransparency = 0.45,
							TextXAlignment = Enum.TextXAlignment.Right,
							TextYAlignment = Enum.TextYAlignment.Top,
							TextWrapped = false,
							RichText = false
						})
						NumberLabels[Used] = Number
					end
					Number.TextColor3 = Theme["Color Dark Text"]
					Number.Position = UDim2.fromOffset(0, Y)
					Number.Size = UDim2.fromOffset(GutterWidth - 5, LineHeight)
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
				local X = MeasureCaretWidth(Lines[Row]:sub(1, Position - LineOffsets[Row]))
				if X == nil then return nil end
				return X, (Row - 1) * LineHeight
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
			local LastCaretX, LastCaretY, LastCaretScale
			local function UpdateCaret()
				if Destroyed then return end
				local WasVisible = Caret.Visible
				local Selecting = Input.SelectionStart > 0 and Input.SelectionStart ~= Input.CursorPosition
				local X, Y
				if Editable and Focused and not Selecting then X, Y = CursorLocation() end
				Caret.Visible = X ~= nil
				CaretGlow.Visible = X ~= nil
				if X == nil then Blink:Cancel(); GlowBlink:Cancel(); return end
				local Scale = EffectiveScale()
				local Width = math.max(1, 1.35 / Scale)
				local Target = math.min(LineHeight, FontSize * 1.22)
				local Height = math.max(5 / Scale, Target * 0.78)
				local XPos = 2.85 + X
				local YPos = Padding + Y + (LineHeight - Height) * 0.5
				local GlowPadding = 1 / Scale
				Caret.Size = UDim2.fromOffset(Width, Height)
				Caret.Position = UDim2.fromOffset(XPos, YPos)
				CaretGlow.Size = UDim2.fromOffset(Width + GlowPadding * 2, Height + GlowPadding * 2)
				CaretGlow.Position = UDim2.fromOffset(XPos - GlowPadding, YPos - GlowPadding)
				if not WasVisible or X ~= LastCaretX or Y ~= LastCaretY or Scale ~= LastCaretScale then
					Blink:Cancel()
					GlowBlink:Cancel()
					Caret.BackgroundTransparency = 0
					CaretGlow.BackgroundTransparency = 0.86
					Blink:Play()
					GlowBlink:Play()
				end
				LastCaretX, LastCaretY, LastCaretScale = X, Y, Scale
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
					local Show = EditAllowed and Input.Text ~= InitialCode
					ResetButton.Button.Visible = Show
					if not Show and (ResetButton.Hover or ResetButton.Press) then
						ResetButton.Hover, ResetButton.Press = false, false
						ResetButton.Update(true)
					end
				end
				UpdateActions()
			end

			local function Refresh()
				if Destroyed then return end
				table.clear(Lines)
				table.clear(StyledLines)
				table.clear(LineOffsets)

				RenderedCode = Input.Text
				local Highlight = Language:lower() == "lua" or Language:lower() == "luau"
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
				GutterWidth = math.max(25, #tostring(LineCount) * math.ceil(CellWidth) + 9)
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
							return Index >= 1 and Index <= #Previous + 1 and (PairOpen[Character] ~= nil or ClosingCharacters[Character] or AutoClosers[Index] == Character)
								and Previous:sub(1, Index - 1) .. Character .. Previous:sub(Index) == Text
						end
						if not IsInsertion(Position) then
							Position = 1
							while Position <= #Previous and Previous:sub(Position, Position) == Text:sub(Position, Position) do Position += 1 end
						end
						if IsInsertion(Position) then
							local Character = Text:sub(Position, Position)
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
								local Closing = PairOpen[Character]
								local TrackedClosing = Closing
								local Equals = Character == "[" and Previous:sub(1, Position - 1):match("%[(=*)$")
								if Equals then
									TrackedClosing = "]" .. Equals .. "]"
									Closing = Previous:sub(Position, Position) == "]" and "]" .. Equals or TrackedClosing
								end
								Text = Text:sub(1, Position) .. Closing .. Text:sub(Position + 1)
								Cursor, Selection, QuoteEdit = Position + 1, -1, true
								NewCloserPosition, NewCloser = Position + 1, TrackedClosing
							end
						end
					elseif #Text == #Previous - 1 then
						local Position = 1
						while Position <= #Text and Previous:sub(Position, Position) == Text:sub(Position, Position) do Position += 1 end
						local Deleted = Previous:sub(Position, Position)
						local Closing = PairOpen[Deleted]
						if Closing and Previous:sub(Position + 1, Position + #Closing) == Closing then
							local Tracked = true
							for Offset = 1, #Closing do
								if AutoClosers[Position + Offset] ~= Closing:sub(Offset, Offset) then
									Tracked = false
									break
								end
							end
							if Tracked then
								Text = Previous:sub(1, Position - 1) .. Previous:sub(Position + #Closing + 1)
								Cursor, Selection, QuoteEdit = Position, -1, true
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
				if Input.Text ~= NewCode then Input.Text = NewCode end
				Input.SelectionStart = -1
				if Cursor > 0 then Input.CursorPosition = ClampCursor(Cursor, NewCode) end
				UpdateModified()
				Refresh()
				return NewCode
			end
			Code.Set = Code.SetCode
			function Code:GetCode() return Input.Text end
			function Code:SetTitle(Value)
				if Destroyed then return nil end
				TitleSource = tostring(Value or "")
				TitleText = TranslateText(TitleSource)
				FileName.Text = TitleText
			end
			function Code:SetLanguage(Value)
				if Destroyed then return nil end
				Language = tostring(Value or "Lua")
				table.clear(HighlightCache)
				Cached = 0
				Refresh()
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
					BackgroundColor3 = Theme["Color Hub 2"]:Lerp(Color3.new(0, 0, 0), Editable and 0.37 or 0.28)
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
					ShowCodeMessage("Code save failed: {Error}", {Error = Reason})
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
				ObservedCode = InitialCode
				table.clear(AutoClosers)
				Input.Text = InitialCode
				Input.SelectionStart = -1
				if Cursor > 0 then Input.CursorPosition = ClampCursor(Cursor, InitialCode) end
				UpdateModified()
				Refresh()
				if Changed and OnChange then task.spawn(OnChange, InitialCode) end
				return true
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
				if not Called then ShowCodeMessage("Code copy failed: {Error}", {Error = tostring(Success)}); return false, Success end
				if not Success then ShowCodeMessage("Code copy failed: {Error}", {Error = tostring(Error or "Clipboard unavailable.")}) end
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
				Executing = true
				ExecutionToken += 1
				local Token, Started = ExecutionToken, os.clock()
				if SpinTween then SpinTween:Cancel() end
				ExecuteButton.Icon.Rotation = 0
				SpinTween = TweenService:Create(ExecuteButton.Icon,
					TweenInfo.new(0.65, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
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
					local Remaining = 0.65- (os.clock() - Started)
					if Remaining > 0 then task.delay(Remaining, FinishAnimation) else FinishAnimation() end
					if not Success then
						local ErrorText = tostring(Result)
						if #ErrorText > 120 then ErrorText = ErrorText:sub(1, 117) .. "..." end
						ShowCodeMessage("Code execution failed: {Error}", {Error = ErrorText})
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
						if Toast then Toast.Visible = false end
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
			ExternalConnections[#ExternalConnections + 1] = UserInputService.InputBegan:Connect(function(InputObject)
				if Destroyed then return end
				if IsPointer(InputObject) then
					if Editable and not Inside(Holder, InputObject.Position) then
						task.defer(function() if not Destroyed and Editable and not ActionPointer then Code:EditClose() end end)
					end
				elseif Editable and UserInputService:GetFocusedTextBox() == Input then
					if ControlDown() and InputObject.KeyCode == Enum.KeyCode.V
						or InputObject.KeyCode == Enum.KeyCode.Insert and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
						PastePending = true
					elseif ControlDown() and InputObject.KeyCode == Enum.KeyCode.S then
						Code:Save()
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
			for _, Object in ipairs({MainFrame, ScreenGui, Header}) do
				for _, Property in ipairs({"AbsolutePosition", "AbsoluteSize"}) do
					ExternalConnections[#ExternalConnections + 1] = Object:GetPropertyChangedSignal(Property):Connect(PositionMessage)
				end
			end

			local LanguageConnection = Connection.LanguageChanged:Connect(function()
				task.defer(function()
					if Destroyed then return end
					TitleText = TranslateText(TitleSource)
					FileName.Text = TitleText
					if Toast and ToastSource then
						ToastText.Text = TranslateText(ToastSource, ToastValues)
						PositionMessage()
					end
					DrawnVersion = -1
					DrawVisibleLines()
				end)
			end)
			local ThemeConnection = Connection.ThemeChanged:Connect(function()
				if Destroyed then return end
				Body.BackgroundColor3 = Theme["Color Hub 2"]:Lerp(Color3.new(0, 0, 0), Editable and 0.37 or 0.28)
				Scroll.ScrollBarImageColor3 = Theme["Color Theme"]
				for _, Entry in ipairs(Buttons) do Entry.Update(true) end
				for _, Frame in ipairs(SelectionFrames) do Frame.BackgroundColor3 = Theme["Color Theme"] end
				Input.TextColor3 = Theme["Color Text"]
				Caret.BackgroundColor3 = Theme["Color Theme"]
				CaretGlow.BackgroundColor3 = Theme["Color Theme"]
				table.clear(HighlightCache)
				Cached = 0
				table.clear(WidthCache)
				WidthCached = 0
				Refresh()
			end)
			Holder.Destroying:Connect(function()
				Destroyed = true
				ThemeConnection:Disconnect()
				LanguageConnection:Disconnect()
				for _, Link in ipairs(ExternalConnections) do Link:Disconnect() end
				table.clear(ExternalConnections)
				if Toast then Toast:Destroy() end
				Blink:Cancel()
				GlowBlink:Cancel()
				CopyToken += 1
				ExecutionToken += 1
				table.clear(AutoClosers)
				for _, Animation in ipairs(CopyTweens) do Animation:Cancel() end
				table.clear(CopyTweens)
				if SpinTween then SpinTween:Cancel() end
				if BodyTween then BodyTween:Cancel() end
				for _, Entry in ipairs(Buttons) do
					if Entry.TintTween then Entry.TintTween:Cancel() end
					if Entry.ScaleTween then Entry.ScaleTween:Cancel() end
					if Entry.GlowTween then Entry.GlowTween:Cancel() end
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
			end)
			ApplyLocked(Code, Holder, Configs, function(Locked)
				if Locked and Editable then Code:SetEditable(false) end
			end)
			function Code:NotifyLocked()
				local Message = self.GetLockedMessage and self:GetLockedMessage() or Configs.LockedMessage or "This element is unavailable."
				ShowCodeMessage(Message)
			end
			Refresh()
			UpdateEditingAppearance()
			UpdateActions()
			for _, Entry in ipairs(Buttons) do Entry.Update(true) end
			QueueGeometry()
			return RegisterFlagObject(Configs.Flag, Code, Holder)
		end
		function Tab:AddDiscordInvite(Configs)
			Configs = type(Configs) == "table" and Configs or type(Configs) == "string" and {Configs} or {}
			local Title = TranslateText(tostring(Configs[1] or Configs.Name or Configs.Title or "Discord"))
			local Desc = TranslateText(tostring(Configs.Desc or Configs.Description or ""))
			local Logo = Configs[2] or Configs.Logo or ""
			local Invite = Configs[3] or Configs.Invite or ""
			
			local InviteHolder = Create("Frame", Container, {
				Size = UDim2.new(1, 0, 0, 80),
				BackgroundTransparency = 1
			})
			
			local InviteLabel = Create("TextLabel", InviteHolder, {
				Size = UDim2.new(1, 0, 0, 15),
				Position = UDim2.new(0, 5),
				TextColor3 = Color3.fromRGB(40, 150, 255),
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
				TextColor3 = Color3.fromRGB(220, 220, 220),
				BackgroundColor3 = Color3.fromRGB(50, 150, 50)
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
					BackgroundColor3 = Color3.fromRGB(100, 100, 100),
					TextColor3 = Color3.fromRGB(150, 150, 150)
				})
				task.delay(5, function()
					if not JoinButton.Parent then return end
					SetProps(JoinButton, {
						Text = TranslateText("Join"),
						BackgroundColor3 = Color3.fromRGB(50, 150, 50),
						TextColor3 = Color3.fromRGB(220, 220, 220)
					})
					ClickDelay = false
				end)
			end)
			
			local DiscordInvite = {}
			function DiscordInvite:Destroy() InviteHolder:Destroy() end
			function DiscordInvite:Visible(...) Funcs:ToggleVisible(InviteHolder, ...) end
			function DiscordInvite:SetTitle(Value)
				LTitle.Text = TranslateText(tostring(Value or ""))
			end
			function DiscordInvite:SetDesc(Value)
				LDesc.Text = TranslateText(tostring(Value or ""))
			end

			ApplyLocked(DiscordInvite, InviteHolder, Configs)
			return RegisterFlagObject(Configs.Flag, DiscordInvite, InviteHolder)
		end
		for _, MethodName in ipairs({
			"AddSection", "AddParagraph", "AddButton", "AddToggle", "AddDropdown",
			"AddPlayers", "AddSelector", "AddSlider", "AddTextBox", "AddKeybind",
			"AddColorPicker", "AddCode", "AddDiscordInvite"
		}) do
			local CreateElement = Tab[MethodName]
			Tab[MethodName] = function(Self, ...)
				if Self._Destroyed then return nil end
				local Element = CreateElement(Self, ...)
				if type(Element) == "table" and type(Element.Destroy) == "function" then
					local OriginalDestroy = Element.Destroy
					local Destroyed = false
					TabElements[Element] = true
					Element.Destroy = function(Object, ...)
						if Destroyed then return end
						Destroyed = true
						TabElements[Object] = nil
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

			local SoundPresetIndex = SoundPresetIndexById[tostring(Library:GetSoundId())] or 1
			if not SoundPresetIndexById[tostring(Library:GetSoundId())] then
				Library:SetSoundId(SoundPresets[SoundPresetIndex].Id)
			end

			local SoundPresetControl = ConfigTab:AddSelector({
				Name = TranslateText("UI sound"),
				Options = SoundPresetOptions,
				Default = SoundPresetIndex,
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
				return ConfigDestroy(self, ...)
			end
		end

		Window:SelectTab(ConfigTab)
		return ConfigTab
	end

	return Window
end

return Library
