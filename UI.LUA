local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Library = {}

Library.Name = "Rose"
Library.Font = Enum.Font.Code
Library.Accent = Color3.fromRGB(0, 170, 255) -- cyan-blue
Library.flags = Library.flags or {}
Library.notifications = Library.notifications or {}
Library._accentBinds = Library._accentBinds or {}
Library._controlsByFlag = Library._controlsByFlag or {}

function Library:_registerFlagControl(flag, control)
	if type(flag) ~= "string" or flag == "" then
		return
	end
	if type(control) ~= "table" or type(control.Set) ~= "function" then
		return
	end
	self._controlsByFlag[flag] = self._controlsByFlag[flag] or {}
	table.insert(self._controlsByFlag[flag], control)
end

function Library:ApplyFlag(flag, value)
	if type(flag) ~= "string" or flag == "" then
		return
	end
	self.flags[flag] = value
	local list = self._controlsByFlag[flag]
	if type(list) == "table" then
		for _, control in ipairs(list) do
			if control and control.Set then
				pcall(control.Set, value)
			end
		end
	end
end

function Library:ApplyFlags(flagTable)
	if type(flagTable) ~= "table" then
		return
	end
	for flag, value in pairs(flagTable) do
		self:ApplyFlag(flag, value)
	end
end

function Library:_encodeValue(v)
	local t = typeof(v)
	if t == "Color3" then
		return { __t = "Color3", r = v.R, g = v.G, b = v.B }
	end
	if t == "EnumItem" then
		return { __t = "EnumItem", enum = tostring(v.EnumType), name = v.Name }
	end
	if type(v) == "table" then
		local out = {}
		for k, val in pairs(v) do
			if type(k) == "string" then
				out[k] = self:_encodeValue(val)
			end
		end
		return out
	end
	if type(v) == "string" or type(v) == "number" or type(v) == "boolean" or v == nil then
		return v
	end
	return nil
end

function Library:_decodeValue(v)
	if type(v) ~= "table" then
		return v
	end
	if v.__t == "Color3" then
		return Color3.new(tonumber(v.r) or 0, tonumber(v.g) or 0, tonumber(v.b) or 0)
	end
	if v.__t == "EnumItem" and type(v.enum) == "string" and type(v.name) == "string" then
		if v.enum == "Enum.KeyCode" and Enum.KeyCode[v.name] then
			return Enum.KeyCode[v.name]
		end
	end
	local out = {}
	for k, val in pairs(v) do
		out[k] = self:_decodeValue(val)
	end
	return out
end

function Library:_bindAccent(inst, prop)
	if not inst or not prop then
		return
	end
	table.insert(self._accentBinds, { inst = inst, prop = prop })
	pcall(function()
		inst[prop] = self.Accent
	end)
end

function Library:SetAccent(color)
	if typeof(color) ~= "Color3" then
		return
	end
	self.Accent = color
	for i = #self._accentBinds, 1, -1 do
		local b = self._accentBinds[i]
		if not b or not b.inst or not b.inst.Parent then
			table.remove(self._accentBinds, i)
		else
			pcall(function()
				b.inst[b.prop] = color
			end)
		end
	end
end

if getgenv then
	local env = getgenv()
	env.Rose = Library
	env.RoseLibrary = Library
end

local function protectGui(gui)
	if syn and syn.protect_gui then
		syn.protect_gui(gui)
		gui.Parent = CoreGui
	elseif getgenv and getgenv().gethui then
		gui.Parent = getgenv().gethui()
	else
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function isPhone()
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local vp = camera.ViewportSize
	return vp.X <= 650
end

local function viewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

local function addCorner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 6)
	c.Parent = inst
	return c
end

local function addStroke(inst, color)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function hsvToColor(h, s, v)
	return Color3.fromHSV(h, s, v)
end

local function safeToHSV(c)
	if Color3.toHSV then
		return Color3.toHSV(c)
	end
	if typeof(c) == "Color3" and c.ToHSV then
		return c:ToHSV()
	end
	return 0, 0, 0
end

local function colorToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function Library:CreateWindow(options)
	options = options or {}
	local titleText = options.Title or Library.Name
	local displayName = options.name or options.Name or titleText
	local suffix = options.suffix or options.Suffix
	local gameInfo = options.gameInfo or options.GameInfo
	local requestedSize = options.Size or options.size

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "Rose_UI_V1"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.IgnoreGuiInset = true
	protectGui(ScreenGui)

	-- Dropdown overlay layer (keeps dropdown menus out of section layouts)
	local DropdownOverlay = Instance.new("TextButton")
	DropdownOverlay.Name = "DropdownOverlay"
	DropdownOverlay.Parent = ScreenGui
	DropdownOverlay.BackgroundTransparency = 1
	DropdownOverlay.BorderSizePixel = 0
	DropdownOverlay.Size = UDim2.new(1, 0, 1, 0)
	DropdownOverlay.Position = UDim2.new(0, 0, 0, 0)
	DropdownOverlay.Text = ""
	DropdownOverlay.AutoButtonColor = false
	DropdownOverlay.Visible = false
	DropdownOverlay.ZIndex = 900

	local DropdownLayer = Instance.new("Frame")
	DropdownLayer.Name = "DropdownLayer"
	DropdownLayer.Parent = ScreenGui
	DropdownLayer.BackgroundTransparency = 1
	DropdownLayer.BorderSizePixel = 0
	DropdownLayer.Size = UDim2.new(1, 0, 1, 0)
	DropdownLayer.Position = UDim2.new(0, 0, 0, 0)
	DropdownLayer.ZIndex = 950

	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Parent = ScreenGui
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainFrame.BorderSizePixel = 0
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.Visible = true

	local baseSize = requestedSize or UDim2.new(0, 550, 0, 600)
	local vp = viewportSize()
	if isPhone() then
		local targetW = math.max(320, math.min(420, math.floor(vp.X - 32)))
		local targetH = math.max(320, math.min(460, math.floor(vp.Y - 96)))
		MainFrame.Size = UDim2.new(0, targetW, 0, targetH)
	else
		-- Keep desktop/tablet consistent, but clamp to viewport so it never goes off-screen.
		if baseSize.X.Offset > 0 and baseSize.Y.Offset > 0 then
			local targetW = math.min(baseSize.X.Offset, math.floor(vp.X - 64))
			local targetH = math.min(baseSize.Y.Offset, math.floor(vp.Y - 80))
			MainFrame.Size = UDim2.new(0, targetW, 0, targetH)
		else
			MainFrame.Size = baseSize
		end
	end

	addCorner(MainFrame, UDim.new(0, 8))
	addStroke(MainFrame, Color3.fromRGB(50, 50, 50))

	-- Optional background image layer
	local BgImage = Instance.new("ImageLabel")
	BgImage.Name = "BackgroundImage"
	BgImage.Parent = MainFrame
	BgImage.BackgroundTransparency = 1
	BgImage.BorderSizePixel = 0
	BgImage.Size = UDim2.new(1, 0, 1, 0)
	BgImage.Position = UDim2.new(0, 0, 0, 0)
	BgImage.ZIndex = 0
	BgImage.Visible = false
	BgImage.ScaleType = Enum.ScaleType.Crop
	BgImage.ImageTransparency = 0.88
	BgImage.BackgroundTransparency = 1
	BgImage.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

	local BgGradient = Instance.new("UIGradient")
	BgGradient.Name = "BgGradient"
	BgGradient.Parent = BgImage
	BgGradient.Enabled = false
	BgGradient.Rotation = 90

	local BgEffects = Instance.new("Frame")
	BgEffects.Name = "BgEffects"
	BgEffects.Parent = BgImage
	BgEffects.BackgroundTransparency = 1
	BgEffects.BorderSizePixel = 0
	BgEffects.Size = UDim2.new(1, 0, 1, 0)
	BgEffects.Position = UDim2.new(0, 0, 0, 0)
	BgEffects.ClipsDescendants = true
	BgEffects.ZIndex = 1

	local Watermark = Instance.new("TextLabel")
	Watermark.Name = "Watermark"
	Watermark.Parent = MainFrame
	Watermark.BackgroundTransparency = 1
	Watermark.AnchorPoint = Vector2.new(1, 1)
	Watermark.Position = UDim2.new(1, -10, 1, -10)
	Watermark.Size = UDim2.new(0, 140, 0, 18)
	Watermark.Font = Library.Font
	Watermark.Text = tostring(displayName)
	Watermark.TextColor3 = Color3.fromRGB(90, 90, 90)
	Watermark.TextSize = 14
	Watermark.TextTransparency = 0.35
	Watermark.TextXAlignment = Enum.TextXAlignment.Right
	Watermark.ZIndex = 2

	local TopBar = Instance.new("Frame")
	TopBar.Name = "TopBar"
	TopBar.Parent = MainFrame
	TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	TopBar.BackgroundTransparency = 1
	TopBar.BorderSizePixel = 0
	TopBar.Size = UDim2.new(1, 0, 0, 42)
	TopBar.ZIndex = 2
	addStroke(TopBar, Color3.fromRGB(35, 35, 35))

	local TopShade = Instance.new("Frame")
	TopShade.Name = "TopShade"
	TopShade.Parent = TopBar
	TopShade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	TopShade.BackgroundTransparency = 0.35
	TopShade.BorderSizePixel = 0
	TopShade.Size = UDim2.new(1, 0, 1, 0)
	TopShade.Position = UDim2.new(0, 0, 0, 0)
	TopShade.ZIndex = 2

	local TitleLabel = Instance.new("TextLabel")
	TitleLabel.Name = "Title"
	TitleLabel.Parent = TopBar
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Position = UDim2.new(0, 14, 0, 0)
	TitleLabel.Size = UDim2.new(0, 200, 1, 0)
	TitleLabel.Font = Library.Font
	local titleLeft = tostring(titleText)
	if suffix and tostring(suffix) ~= "" then
		titleLeft = titleLeft .. " " .. tostring(suffix)
	end
	TitleLabel.Text = titleLeft
	TitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	TitleLabel.TextSize = 15
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	TitleLabel.RichText = false
	TitleLabel.ZIndex = 3

	local TitlePad = Instance.new("UIPadding")
	TitlePad.Parent = TitleLabel
	TitlePad.PaddingRight = UDim.new(0, 0)

	local TabContainer = Instance.new("Frame")
	TabContainer.Name = "TabContainer"
	TabContainer.Parent = TopBar
	TabContainer.BackgroundTransparency = 1
	TabContainer.Position = UDim2.new(0, 160, 0, 0)
	TabContainer.Size = UDim2.new(1, -170, 1, 0)
	TabContainer.ZIndex = 3

	local TabLayout = Instance.new("UIListLayout")
	TabLayout.Parent = TabContainer
	TabLayout.FillDirection = Enum.FillDirection.Horizontal
	TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	TabLayout.Padding = UDim.new(0, 12)
	TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local titleOffsetY = 0
	local function updateTabPosition()
		local pad = 14
		-- Size title off TextBounds so it works even if AutomaticSize is flaky.
		local maxTitleW = math.max(120, math.floor(MainFrame.AbsoluteSize.X * 0.55))
		local titleW = math.clamp(math.ceil(TitleLabel.TextBounds.X + 4), 60, maxTitleW)
		TitleLabel.Size = UDim2.new(0, titleW, 1, 0)
		local x = TitleLabel.Position.X.Offset + titleW + pad
		TabContainer.Position = UDim2.new(0, x, 0, titleOffsetY)
		TabContainer.Size = UDim2.new(1, -(x + 14), 1, 0)
	end
	TitleLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateTabPosition)
	TitleLabel:GetPropertyChangedSignal("Text"):Connect(updateTabPosition)
	MainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTabPosition)
	task.defer(updateTabPosition)

	local ContentScroll = Instance.new("ScrollingFrame")
	ContentScroll.Name = "ContentScroll"
	ContentScroll.Parent = MainFrame
	ContentScroll.BackgroundTransparency = 1
	ContentScroll.Position = UDim2.new(0, 0, 0, 46)
	ContentScroll.Size = UDim2.new(1, 0, 1, -52)
	ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	ContentScroll.ScrollBarThickness = 2
	Library:_bindAccent(ContentScroll, "ScrollBarImageColor3")
	ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	-- Snow layer renders above content (so flakes are visible)
	local SnowLayer = Instance.new("Frame")
	SnowLayer.Name = "SnowLayer"
	SnowLayer.Parent = MainFrame
	SnowLayer.BackgroundTransparency = 1
	SnowLayer.BorderSizePixel = 0
	SnowLayer.Position = UDim2.new(0, 0, 0, 46)
	SnowLayer.Size = UDim2.new(1, 0, 1, -52)
	SnowLayer.ClipsDescendants = true
	SnowLayer.ZIndex = 2

	local ContentHolder = Instance.new("Frame")
	ContentHolder.Name = "ContentHolder"
	ContentHolder.Parent = ContentScroll
	ContentHolder.BackgroundTransparency = 1
	ContentHolder.Size = UDim2.new(1, 0, 1, 0)

	local holderPadding = Instance.new("UIPadding")
	holderPadding.Parent = ContentHolder
	holderPadding.PaddingTop = UDim.new(0, 10)
	holderPadding.PaddingBottom = UDim.new(0, 10)
	holderPadding.PaddingLeft = UDim.new(0, 12)
	holderPadding.PaddingRight = UDim.new(0, 12)

	local OpenCloseButton = Instance.new("TextButton")
	OpenCloseButton.Name = "OpenClose"
	OpenCloseButton.Parent = ScreenGui
	OpenCloseButton.AnchorPoint = Vector2.new(1, 0)
	OpenCloseButton.Position = UDim2.new(1, -14, 0, 14)
	OpenCloseButton.Size = UDim2.new(0, 44, 0, 44)
	OpenCloseButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	OpenCloseButton.BorderSizePixel = 0
	OpenCloseButton.Text = "×"
	OpenCloseButton.TextColor3 = Color3.fromRGB(230, 230, 230)
	OpenCloseButton.Font = Library.Font
	OpenCloseButton.TextSize = 20
	OpenCloseButton.AutoButtonColor = true
	OpenCloseButton.ZIndex = 50
	addCorner(OpenCloseButton, UDim.new(0, 10))
	addStroke(OpenCloseButton, Color3.fromRGB(45, 45, 45))

	-- Notifications holder
	local NotifHolder = Instance.new("Frame")
	NotifHolder.Name = "Notifications"
	NotifHolder.Parent = ScreenGui
	NotifHolder.BackgroundTransparency = 1
	NotifHolder.AnchorPoint = Vector2.new(1, 0)
	NotifHolder.Position = UDim2.new(1, -14, 0, 66)
	NotifHolder.Size = UDim2.new(0, 280, 1, -80)
	NotifHolder.ZIndex = 60

	local NotifLayout = Instance.new("UIListLayout")
	NotifLayout.Parent = NotifHolder
	NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
	NotifLayout.Padding = UDim.new(0, 8)
	NotifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local function setOpen(isOpen)
		MainFrame.Visible = isOpen
		OpenCloseButton.Text = isOpen and "×" or "≡"
	end

	OpenCloseButton.MouseButton1Click:Connect(function()
		setOpen(not MainFrame.Visible)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightControl then
			setOpen(not MainFrame.Visible)
		end
	end)

	-- Dragging: mouse + touch, only when window is open
	local dragging = false
	local dragStart = nil
	local startPos = nil

	local function beginDrag(input)
		if not MainFrame.Visible then
			return
		end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
	end

	local function updateDrag(input)
		if not dragging or not dragStart or not startPos then
			return
		end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end

	local function endDrag(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = false
			dragStart = nil
			startPos = nil
		end
	end

	TopBar.InputBegan:Connect(beginDrag)
	UserInputService.InputChanged:Connect(updateDrag)
	UserInputService.InputEnded:Connect(endDrag)

	local function newColumnContainer(parent)
		local ColumnContainer = Instance.new("Frame")
		ColumnContainer.Parent = parent
		ColumnContainer.BackgroundTransparency = 1
		ColumnContainer.Size = UDim2.new(1, 0, 1, 0)

		local LeftCol = Instance.new("Frame")
		LeftCol.Parent = ColumnContainer
		LeftCol.BackgroundTransparency = 1
		LeftCol.Position = UDim2.new(0, 0, 0, 0)
		LeftCol.Size = UDim2.new(0.5, -9, 1, 0)

		local RightCol = Instance.new("Frame")
		RightCol.Parent = ColumnContainer
		RightCol.BackgroundTransparency = 1
		RightCol.Position = UDim2.new(0.5, 9, 0, 0)
		RightCol.Size = UDim2.new(0.5, -9, 1, 0)

		local function SetupLayout(p)
			local l = Instance.new("UIListLayout")
			l.Parent = p
			l.SortOrder = Enum.SortOrder.LayoutOrder
			l.Padding = UDim.new(0, 12)
		end
		SetupLayout(LeftCol)
		SetupLayout(RightCol)

		return ColumnContainer, LeftCol, RightCol
	end

	local Window = {}
	Window._screenGui = ScreenGui
	Window._main = MainFrame
	Window._tabs = {}
	Window._activeTab = nil
	Window._notifHolder = NotifHolder
	Window._bgImage = BgImage
	Window._bgGradient = BgGradient
	Window._bgEffects = BgEffects
	Window._topShade = TopShade
	Window._snowLayer = SnowLayer
	Window._dropdownOverlay = DropdownOverlay
	Window._dropdownLayer = DropdownLayer
	Window._openDropdown = nil
	Window._watermark = Watermark
	Window._titleLabel = TitleLabel
	Window._tabContainer = TabContainer

	function Window:_closeOpenDropdown()
		local open = self._openDropdown
		if open and open.Close then
			pcall(open.Close)
		end
		self._openDropdown = nil
		if self._dropdownOverlay then
			self._dropdownOverlay.Visible = false
		end
	end

	if DropdownOverlay then
		DropdownOverlay.MouseButton1Click:Connect(function()
			Window:_closeOpenDropdown()
		end)
	end

	function Window:SetBackgroundImage(image)
		if not self._bgImage then
			return
		end
		local img = tostring(image or "")
		if img == "" or img == "0" or img:lower() == "none" then
			self._bgImage.Visible = false
			self._bgImage.Image = ""
			self._bgImage.BackgroundTransparency = 1
			if self._bgGradient then
				self._bgGradient.Enabled = false
			end
			return
		end
		if not img:find("rbxassetid://") then
			if tonumber(img) then
				img = "rbxassetid://" .. img
			end
		end
		if self._bgGradient then
			self._bgGradient.Enabled = false
		end
		self._bgImage.BackgroundTransparency = 1
		self._bgImage.Image = img
		self._bgImage.Visible = true
	end

	function Window:SetBackgroundPreset(preset)
		if not self._bgImage or not self._bgGradient then
			return
		end
		local name = tostring(preset or "None")
		if name == "None" then
			self._bgGradient.Enabled = false
			if self._bgImage.Image == "" then
				self._bgImage.Visible = false
			end
			return
		end

		self._bgImage.Visible = true
		self._bgImage.Image = ""
		self._bgImage.BackgroundTransparency = 0
		self._bgGradient.Enabled = true
		self._bgGradient.Rotation = 90

		if name == "Rose" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(15, 10, 14)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 90, 200)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(60, 20, 80)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(10, 10, 14)),
			})
		elseif name == "Midnight" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(40, 60, 120)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(6, 8, 14)),
			})
		elseif name == "Sunset" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(18, 10, 8)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 140, 50)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(220, 60, 120)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 8, 14)),
			})
		elseif name == "Forest" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(8, 14, 10)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(70, 160, 90)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(8, 12, 10)),
			})
		elseif name == "Ocean" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(6, 10, 14)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(30, 190, 255)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(6, 8, 14)),
			})
		elseif name == "Galaxy" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(6, 6, 12)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 60, 255)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(30, 10, 80)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(6, 6, 12)),
			})
		elseif name == "Ice" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(6, 10, 14)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(180, 240, 255)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(6, 10, 14)),
			})
		elseif name == "Lava" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(14, 6, 6)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 80, 20)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(180, 20, 20)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(14, 6, 6)),
			})
		elseif name == "Mono" then
			self._bgImage.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(55, 55, 55)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(10, 10, 10)),
			})
		else
			self._bgImage.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
			self._bgGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.0, Color3.fromRGB(35, 35, 35)),
				ColorSequenceKeypoint.new(1.0, Color3.fromRGB(10, 10, 10)),
			})
		end
	end

	-- Snow effect (simple circle flakes, no external image ids)
	local snowEnabled = false
	local snowIntensity = 160
	local snowSpeed = 5
	local snowToken = 0
	local snowFlakes = {}

	local function clearSnow()
		for _, flake in ipairs(snowFlakes) do
			if flake and flake.Parent then
				flake:Destroy()
			end
		end
		snowFlakes = {}
	end

	local function spawnFlake(parent)
		local f = Instance.new("Frame")
		f.Name = "SnowFlake"
		f.Parent = parent
		f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		f.BackgroundTransparency = 0.25
		f.BorderSizePixel = 0
		f.ZIndex = 1
		addCorner(f, UDim.new(1, 0))
		return f
	end

	local function animateFlake(token, flake)
		while snowEnabled and token == snowToken and flake and flake.Parent do
			local w = math.random(2, 4)
			flake.Size = UDim2.new(0, w, 0, w)
			flake.BackgroundTransparency = 0.25 + (math.random() * 0.35)
			local startX = math.random(0, math.max(0, MainFrame.AbsoluteSize.X - 6))
			flake.Position = UDim2.new(0, startX, 0, -10)
			local drift = math.random(-40, 40)
			local endX = math.clamp(startX + drift, 0, math.max(0, MainFrame.AbsoluteSize.X - 6))
			local duration = (math.random(35, 70) / 10) / math.max(0.2, snowSpeed)
			local tween = TweenService:Create(flake, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, endX, 1, 10),
			})
			tween:Play()
			task.wait(duration)
		end
	end

	function Window:SetSnowEnabled(on)
		snowEnabled = (on == true)
		snowToken += 1
		if not self._snowLayer then
			return
		end
		if not snowEnabled then
			clearSnow()
			return
		end
		local token = snowToken
		clearSnow()
		for i = 1, math.clamp(tonumber(snowIntensity) or 160, 0, 160) do
			local flake = spawnFlake(self._snowLayer)
			table.insert(snowFlakes, flake)
			task.spawn(animateFlake, token, flake)
		end
	end

	function Window:SetSnowIntensity(amount)
		snowIntensity = math.clamp(tonumber(amount) or 160, 0, 160)
		if snowEnabled then
			self:SetSnowEnabled(true)
		end
	end

	function Window:SetSnowSpeed(speed)
		snowSpeed = math.clamp(tonumber(speed) or 1, 0.2, 5)
	end

	function Window:SetBackgroundTransparency(alpha)
		if self._bgImage then
			self._bgImage.ImageTransparency = math.clamp(tonumber(alpha) or 0.88, 0, 1)
		end
	end

	function Window:SetTitleOffset(offset)
		titleOffsetY = math.floor(tonumber(offset) or 0)
		TitleLabel.Position = UDim2.new(0, 14, 0, titleOffsetY)
		updateTabPosition()
	end

	local function setActiveTab(tab)
		Window._activeTab = tab
		for _, t in pairs(Window._tabs) do
			local isActive = (t == tab)
			t.Button.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(130, 130, 130)
			t.Underline.Visible = isActive
			t.Container.Visible = isActive
		end
	end

	function Window:CreateTab(name, layoutOrder)
		Window._tabOrderCounter = (Window._tabOrderCounter or 0) + 1
		local TabBtn = Instance.new("TextButton")
		TabBtn.Name = name
		TabBtn.Parent = TabContainer
		TabBtn.BackgroundTransparency = 1
		TabBtn.BorderSizePixel = 0
		TabBtn.Font = Library.Font
		TabBtn.Text = name
		TabBtn.TextColor3 = Color3.fromRGB(130, 130, 130)
		TabBtn.TextSize = 14
		TabBtn.TextYAlignment = Enum.TextYAlignment.Center
		TabBtn.AutomaticSize = Enum.AutomaticSize.X
		TabBtn.Size = UDim2.new(0, 0, 1, 0)
		TabBtn.ClipsDescendants = false
		TabBtn.LayoutOrder = tonumber(layoutOrder) or Window._tabOrderCounter

		local underlinePad = Instance.new("UIPadding")
		underlinePad.Parent = TabBtn
		underlinePad.PaddingBottom = UDim.new(0, 6)

		local Underline = Instance.new("Frame")
		Underline.Name = "Underline"
		Underline.Parent = TabBtn
		Library:_bindAccent(Underline, "BackgroundColor3")
		Underline.BorderSizePixel = 0
		Underline.AnchorPoint = Vector2.new(0, 1)
		Underline.Position = UDim2.new(0, 0, 1, 2)
		Underline.Size = UDim2.new(1, 0, 0, 2)
		Underline.Visible = false
		Underline.ZIndex = 5

		local TabContent = Instance.new("Frame")
		TabContent.Name = name .. "_Content"
		TabContent.Parent = ContentHolder
		TabContent.BackgroundTransparency = 1
		TabContent.Size = UDim2.new(1, 0, 1, 0)
		TabContent.Visible = false

		local _, LeftCol, RightCol = newColumnContainer(TabContent)

		local Tab = {}
		Tab._left = LeftCol
		Tab._right = RightCol
		Tab._container = TabContent
		Tab._columnIndex = 0

		function Tab:column(opts)
			Tab._columnIndex += 1
			local side = (Tab._columnIndex == 1) and "Left" or "Right"
			local Column = {}
			Column._side = side
			function Column:section(sopts)
				sopts = sopts or {}
				local sectionName = sopts.name or sopts.Name or sopts.title or "Section"
				return Tab:CreateSection(sectionName, side)
			end
			return Column
		end

		function Tab:CreateSection(sectionName, side)
			local parent = (side == "Right" and RightCol) or LeftCol

			local SectionBox = Instance.new("Frame")
			SectionBox.Name = sectionName
			SectionBox.Parent = parent
			SectionBox.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
			SectionBox.BorderSizePixel = 0
			SectionBox.AutomaticSize = Enum.AutomaticSize.Y
			SectionBox.Size = UDim2.new(1, 0, 0, 0)
			addCorner(SectionBox, UDim.new(0, 6))
			addStroke(SectionBox, Color3.fromRGB(45, 45, 45))

			local SectionLabel = Instance.new("TextLabel")
			SectionLabel.Parent = SectionBox
			SectionLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			SectionLabel.Position = UDim2.new(0, 10, 0, -8)
			SectionLabel.Size = UDim2.new(0, 0, 0, 16)
			SectionLabel.Font = Library.Font
			SectionLabel.Text = " " .. sectionName .. " "
			SectionLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
			SectionLabel.TextSize = 13
			SectionLabel.AutomaticSize = Enum.AutomaticSize.X
			addCorner(SectionLabel, UDim.new(0, 4))

			local Container = Instance.new("Frame")
			Container.Parent = SectionBox
			Container.BackgroundTransparency = 1
			Container.AutomaticSize = Enum.AutomaticSize.Y
			Container.Size = UDim2.new(1, 0, 0, 0)

			local Padding = Instance.new("UIPadding")
			Padding.Parent = Container
			Padding.PaddingTop = UDim.new(0, 10)
			Padding.PaddingBottom = UDim.new(0, 8)
			Padding.PaddingLeft = UDim.new(0, 8)
			Padding.PaddingRight = UDim.new(0, 8)

			local UIList = Instance.new("UIListLayout")
			UIList.Parent = Container
			UIList.SortOrder = Enum.SortOrder.LayoutOrder
			UIList.Padding = UDim.new(0, 6)

			local Section = {}
			Section.Container = Container

			function Section:AddToggle(opts)
				opts = opts or {}
				local text = opts.Text or "Toggle"
				local default = opts.Default == true
				local flag = opts.Flag or opts.flag
				local callback = opts.Callback or function() end

				local TFrame = Instance.new("Frame")
				TFrame.Parent = Container
				TFrame.BackgroundTransparency = 1
				TFrame.Size = UDim2.new(1, 0, 0, 20)

				local Box = Instance.new("TextButton")
				Box.Parent = TFrame
				Box.Size = UDim2.new(0, 16, 0, 16)
				Box.Position = UDim2.new(0, 0, 0.5, -8)
				Box.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				Box.BorderSizePixel = 0
				Box.Text = ""
				addCorner(Box, UDim.new(0, 4))
				addStroke(Box, Color3.fromRGB(60, 60, 60))

				local Fill = Instance.new("Frame")
				Fill.Parent = Box
				Library:_bindAccent(Fill, "BackgroundColor3")
				Fill.BorderSizePixel = 0
				Fill.Size = default and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 1, 0)
				Fill.Position = UDim2.new(0, 0, 0, 0)
				addCorner(Fill, UDim.new(0, 4))

				local Label = Instance.new("TextButton")
				Label.Parent = TFrame
				Label.BackgroundTransparency = 1
				Label.Position = UDim2.new(0, 24, 0, 0)
				Label.Size = UDim2.new(1, -24, 1, 0)
				Label.Font = Library.Font
				Label.Text = text
				Label.TextColor3 = Color3.fromRGB(150, 150, 150)
				Label.TextSize = 13
				Label.TextXAlignment = Enum.TextXAlignment.Left
				Label.BorderSizePixel = 0
				Label.AutoButtonColor = false

				local state = default

				local function setState(v)
					state = v
					TweenService:Create(Fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = state and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 1, 0),
					}):Play()
					if flag then
						Library.flags[flag] = state
					end
					pcall(callback, state)
				end

				local function toggle()
					setState(not state)
				end

				Box.MouseButton1Click:Connect(toggle)
				Label.MouseButton1Click:Connect(toggle)
				if flag then
					Library.flags[flag] = state
				end

				local control = {
					Set = setState,
					Get = function() return state end,
				}
				if flag then
					Library:_registerFlagControl(flag, control)
				end
				return control
			end

			function Section:AddButton(opts)
				opts = opts or {}
				local text = opts.Text or opts.name or opts.Name or "Button"
				local callback = opts.Callback or opts.callback or function() end

				local Btn = Instance.new("TextButton")
				Btn.Parent = Container
				Btn.Size = UDim2.new(1, 0, 0, 24)
				Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
				Btn.BorderSizePixel = 0
				Btn.Font = Library.Font
				Btn.Text = text
				Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
				Btn.TextSize = 12
				Btn.AutoButtonColor = true
				addCorner(Btn, UDim.new(0, 6))
				addStroke(Btn, Color3.fromRGB(55, 55, 55))

				Btn.MouseButton1Click:Connect(function()
					pcall(callback)
				end)

				return Btn
			end

			function Section:AddDropdown(opts)
				opts = opts or {}
				local text = opts.Text or opts.name or opts.Name or "Dropdown"
				local items = opts.Items or opts.items or {}
				local default = opts.Default or opts.default or items[1]
				local flag = opts.Flag or opts.flag
				local callback = opts.Callback or opts.callback or function() end

				local DFrame = Instance.new("Frame")
				DFrame.Parent = Container
				DFrame.BackgroundTransparency = 1
				DFrame.Size = UDim2.new(1, 0, 0, 30)

				local Btn = Instance.new("TextButton")
				Btn.Parent = DFrame
				Btn.Size = UDim2.new(1, 0, 0, 24)
				Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
				Btn.BorderSizePixel = 0
				Btn.Font = Library.Font
				Btn.TextColor3 = Color3.fromRGB(200, 200, 200)
				Btn.TextSize = 12
				Btn.TextXAlignment = Enum.TextXAlignment.Left
				Btn.AutoButtonColor = true
				addCorner(Btn, UDim.new(0, 6))
				addStroke(Btn, Color3.fromRGB(55, 55, 55))

				local pad = Instance.new("UIPadding")
				pad.Parent = Btn
				pad.PaddingLeft = UDim.new(0, 8)
				pad.PaddingRight = UDim.new(0, 28)

				-- Add arrow icon
				local Arrow = Instance.new("TextLabel")
				Arrow.Parent = Btn
				Arrow.BackgroundTransparency = 1
				Arrow.AnchorPoint = Vector2.new(1, 0.5)
				Arrow.Position = UDim2.new(1, -3, 0.5, 0)
				Arrow.Size = UDim2.new(0, 16, 0, 16)
				Arrow.Font = Library.Font
				Arrow.Text = "▼"
				Arrow.TextColor3 = Color3.fromRGB(150, 150, 150)
				Arrow.TextSize = 10
				Arrow.ZIndex = 2

				local ListContainer = Instance.new("ScrollingFrame")
				ListContainer.Parent = DropdownLayer
				ListContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
				ListContainer.BorderSizePixel = 0
				ListContainer.Visible = false
				ListContainer.Size = UDim2.fromOffset(0, 0)
				ListContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
				ListContainer.ScrollBarThickness = 4
				ListContainer.Active = true
				ListContainer.ScrollingDirection = Enum.ScrollingDirection.Y
				Library:_bindAccent(ListContainer, "ScrollBarImageColor3")
				ListContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
				ListContainer.ZIndex = 1001
				addCorner(ListContainer, UDim.new(0, 6))
				addStroke(ListContainer, Color3.fromRGB(45, 45, 45))

				local List = Instance.new("Frame")
				List.Parent = ListContainer
				List.BackgroundTransparency = 1
				List.Size = UDim2.new(1, 0, 1, 0)
				List.AutomaticSize = Enum.AutomaticSize.Y
				List.ZIndex = 1000

				local lpad = Instance.new("UIPadding")
				lpad.Parent = List
				lpad.PaddingTop = UDim.new(0, 8)
				lpad.PaddingBottom = UDim.new(0, 8)
				lpad.PaddingLeft = UDim.new(0, 8)
				lpad.PaddingRight = UDim.new(0, 8)

				local ll = Instance.new("UIListLayout")
				ll.Parent = List
				ll.SortOrder = Enum.SortOrder.LayoutOrder
				ll.Padding = UDim.new(0, 6)

				local current = default
				local open = false
				local menuHeight = math.min(150, #items * 30 + 16)

				local function clampMenuPosition(x, y, w, h)
					local vp2 = viewportSize()
					x = math.clamp(x, 8, math.max(8, vp2.X - w - 8))
					if y + h > vp2.Y - 8 then
						y = (Btn.AbsolutePosition.Y - h - 6)
					end
					y = math.clamp(y, 8, math.max(8, vp2.Y - h - 8))
					return x, y
				end

				local function closeMenu()
					open = false
					ListContainer.Visible = false
					Arrow.Text = "▼"
					if DropdownOverlay then
						DropdownOverlay.Visible = false
					end
					if Window._openDropdown and Window._openDropdown.ListContainer == ListContainer then
						Window._openDropdown = nil
					end
				end

				local function openMenu()
					Window:_closeOpenDropdown()
					open = true
					Arrow.Text = "▲"
					if DropdownOverlay then
						DropdownOverlay.Visible = true
					end
					local w = Btn.AbsoluteSize.X
					local h = menuHeight
					local x = Btn.AbsolutePosition.X
					local y = Btn.AbsolutePosition.Y + Btn.AbsoluteSize.Y + 6
					x, y = clampMenuPosition(x, y, w, h)
					ListContainer.Size = UDim2.fromOffset(w, h)
					ListContainer.Position = UDim2.fromOffset(x, y)
					ListContainer.Visible = true
					Window._openDropdown = { ListContainer = ListContainer, Close = closeMenu }
				end
				local function setValue(v)
					current = v
					Btn.Text = text .. ": " .. tostring(current)
					if flag then
						Library.flags[flag] = current
					end
					pcall(callback, current)
				end

				local function refreshItems(newItems)
					for _, child in ipairs(List:GetChildren()) do
						if child:IsA("TextButton") then
							child:Destroy()
						end
					end

					items = newItems or items

					for _, it in ipairs(items) do
						local ItemBtn = Instance.new("TextButton")
						ItemBtn.Parent = List
						ItemBtn.Size = UDim2.new(1, 0, 0, 24)
						ItemBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
						ItemBtn.BorderSizePixel = 0
						ItemBtn.Font = Library.Font
						ItemBtn.Text = tostring(it)
						ItemBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
						ItemBtn.TextSize = 13
						ItemBtn.AutoButtonColor = true
						ItemBtn.ZIndex = 1001
						addCorner(ItemBtn, UDim.new(0, 6))
						addStroke(ItemBtn, Color3.fromRGB(55, 55, 55))

						ItemBtn.MouseButton1Click:Connect(function()
							setValue(it)
							closeMenu()
						end)
					end

					menuHeight = math.min(150, #items * 30 + 16)
					if open then
						local w = Btn.AbsoluteSize.X
						local x = Btn.AbsolutePosition.X
						local y = Btn.AbsolutePosition.Y + Btn.AbsoluteSize.Y + 6
						x, y = clampMenuPosition(x, y, w, menuHeight)
						ListContainer.Size = UDim2.fromOffset(w, menuHeight)
						ListContainer.Position = UDim2.fromOffset(x, y)
					end
					if #items > 0 and not current then
						setValue(items[1])
					end
				end

				refreshItems()

				Btn.MouseButton1Click:Connect(function()
					if open then
						closeMenu()
					else
						openMenu()
					end
				end)

				setValue(current)
				if flag then
					Library.flags[flag] = current
				end

				local control = {
					Set = setValue,
					Get = function() return current end,
					Refresh = refreshItems,
				}
				if flag then
					Library:_registerFlagControl(flag, control)
				end
				return control
			end

			function Section:AddTextBox(opts)
				opts = opts or {}
				local text = opts.Text or opts.name or opts.Name or "Text"
				local placeholder = opts.Placeholder or opts.placeholder or "Type here..."
				local default = opts.Default or opts.default or ""
				local flag = opts.Flag or opts.flag
				local callback = opts.Callback or opts.callback or function() end

				local TFrame = Instance.new("Frame")
				TFrame.Parent = Container
				TFrame.BackgroundTransparency = 1
				TFrame.Size = UDim2.new(1, 0, 0, 46)

				local Label = Instance.new("TextLabel")
				Label.Parent = TFrame
				Label.BackgroundTransparency = 1
				Label.Size = UDim2.new(1, 0, 0, 16)
				Label.Font = Library.Font
				Label.Text = text
				Label.TextColor3 = Color3.fromRGB(150, 150, 150)
				Label.TextSize = 12
				Label.TextXAlignment = Enum.TextXAlignment.Left

				local Box = Instance.new("TextBox")
				Box.Parent = TFrame
				Box.Position = UDim2.new(0, 0, 0, 22)
				Box.Size = UDim2.new(1, 0, 0, 24)
				Box.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
				Box.BorderSizePixel = 0
				Box.Font = Library.Font
				Box.Text = tostring(default)
				Box.PlaceholderText = placeholder
				Box.TextColor3 = Color3.fromRGB(220, 220, 220)
				Box.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
				Box.TextSize = 13
				Box.ClearTextOnFocus = false
				Box.TextXAlignment = Enum.TextXAlignment.Left
				addCorner(Box, UDim.new(0, 6))
				addStroke(Box, Color3.fromRGB(55, 55, 55))

				local pad = Instance.new("UIPadding")
				pad.Parent = Box
				pad.PaddingLeft = UDim.new(0, 10)
				pad.PaddingRight = UDim.new(0, 10)

				local function fire()
					if flag then
						Library.flags[flag] = Box.Text
					end
					pcall(callback, Box.Text)
				end
				Box.FocusLost:Connect(function(enterPressed)
					fire()
				end)
				if flag then
					Library.flags[flag] = Box.Text
				end

				local control = {
					Set = function(v)
						Box.Text = tostring(v)
						fire()
					end,
					Get = function() return Box.Text end,
					Box = Box,
				}
				if flag then
					Library:_registerFlagControl(flag, control)
				end
				return control
			end

			function Section:AddSlider(opts)
				opts = opts or {}
				local text = opts.Text or "Slider"
				local min = tonumber(opts.Min) or 0
				local max = tonumber(opts.Max) or 100
				local default = tonumber(opts.Default) or min
				local interval = tonumber(opts.Interval or opts.interval)
				local suffix = opts.Suffix or ""
				local flag = opts.Flag or opts.flag
				local callback = opts.Callback or function() end

				default = math.clamp(default, min, max)

				local SFrame = Instance.new("Frame")
				SFrame.Parent = Container
				SFrame.BackgroundTransparency = 1
				SFrame.Size = UDim2.new(1, 0, 0, 42)

				local Top = Instance.new("TextLabel")
				Top.Parent = SFrame
				Top.BackgroundTransparency = 1
				Top.Size = UDim2.new(1, 0, 0, 16)
				Top.Font = Library.Font
				Top.TextXAlignment = Enum.TextXAlignment.Left
				Top.TextColor3 = Color3.fromRGB(150, 150, 150)
				Top.TextSize = 12
				Top.Text = text

				local ValueLabel = Instance.new("TextLabel")
				ValueLabel.Parent = SFrame
				ValueLabel.BackgroundTransparency = 1
				ValueLabel.Size = UDim2.new(1, 0, 0, 16)
				ValueLabel.Font = Library.Font
				ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
				ValueLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
				ValueLabel.TextSize = 12

				local Bar = Instance.new("Frame")
				Bar.Parent = SFrame
				Bar.Position = UDim2.new(0, 0, 0, 22)
				Bar.Size = UDim2.new(1, 0, 0, 12)
				Bar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				Bar.BorderSizePixel = 0
				addCorner(Bar, UDim.new(0, 4))
				addStroke(Bar, Color3.fromRGB(55, 55, 55))

				local Fill = Instance.new("Frame")
				Fill.Parent = Bar
				Library:_bindAccent(Fill, "BackgroundColor3")
				Fill.BorderSizePixel = 0
				Fill.Size = UDim2.new(0, 0, 1, 0)
				addCorner(Fill, UDim.new(0, 4))

				local hitbox = Instance.new("TextButton")
				hitbox.Parent = Bar
				hitbox.BackgroundTransparency = 1
				hitbox.Size = UDim2.new(1, 0, 1, 0)
				hitbox.Text = ""
				hitbox.ZIndex = 5

				local value = default
				local draggingSlider = false

				local function snap(v)
					if interval and interval > 0 then
						local steps = math.floor(((v - min) / interval) + 0.5)
						return min + (steps * interval)
					end
					return v
				end

				local function setValue(v)
					value = math.clamp(snap(v), min, max)
					local pct = (value - min) / (max - min)
					Fill.Size = UDim2.new(pct, 0, 1, 0)
					ValueLabel.Text = tostring(math.floor(value + 0.5)) .. suffix
					if flag then
						Library.flags[flag] = value
					end
					pcall(callback, value)
				end

				local function updateFromX(x)
					local rel = clamp01((x - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X)
					local v = min + (max - min) * rel
					setValue(v)
				end

				hitbox.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						draggingSlider = true
						updateFromX(input.Position.X)
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if not draggingSlider then
						return
					end
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						updateFromX(input.Position.X)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						draggingSlider = false
					end
				end)

				setValue(default)
				if flag then
					Library.flags[flag] = value
				end

				local control = {
					Set = setValue,
					Get = function() return value end,
				}
				if flag then
					Library:_registerFlagControl(flag, control)
				end
				return control
			end

			function Section:AddColorPicker(opts)
				opts = opts or {}
				local text = opts.Text or "Color"
				local default = opts.Default or Library.Accent
				local flag = opts.Flag or opts.flag
				local callback = opts.Callback or function() end

				local h, s, v = safeToHSV(default)

				local PFrame = Instance.new("Frame")
				PFrame.Parent = Container
				PFrame.BackgroundTransparency = 1
				PFrame.Size = UDim2.new(1, 0, 0, 20)

				-- match toggle layout: color box on left, label on right
				local Preview = Instance.new("TextButton")
				Preview.Parent = PFrame
				Preview.Size = UDim2.new(0, 16, 0, 16)
				Preview.Position = UDim2.new(0, 0, 0.5, -8)
				Preview.BackgroundColor3 = default
				Preview.BorderSizePixel = 0
				Preview.Text = ""
				addCorner(Preview, UDim.new(0, 4))
				addStroke(Preview, Color3.fromRGB(60, 60, 60))

				local Label = Instance.new("TextButton")
				Label.Parent = PFrame
				Label.BackgroundTransparency = 1
				Label.Position = UDim2.new(0, 24, 0, 0)
				Label.Size = UDim2.new(1, -24, 1, 0)
				Label.Font = Library.Font
				Label.Text = text
				Label.TextColor3 = Color3.fromRGB(150, 150, 150)
				Label.TextSize = 12
				Label.TextXAlignment = Enum.TextXAlignment.Left
				Label.BorderSizePixel = 0
				Label.AutoButtonColor = false

				local Picker = Instance.new("Frame")
				Picker.Parent = Container
				Picker.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
				Picker.BorderSizePixel = 0
				Picker.Visible = false
				Picker.Size = UDim2.new(1, 0, 0, 120)
				addCorner(Picker, UDim.new(0, 6))
				addStroke(Picker, Color3.fromRGB(45, 45, 45))

				local pad = Instance.new("UIPadding")
				pad.Parent = Picker
				pad.PaddingTop = UDim.new(0, 6)
				pad.PaddingBottom = UDim.new(0, 6)
				pad.PaddingLeft = UDim.new(0, 6)
				pad.PaddingRight = UDim.new(0, 6)

				local SV = Instance.new("ImageButton")
				SV.Parent = Picker
				SV.BackgroundColor3 = Color3.new(1, 1, 1)
				SV.BorderSizePixel = 0
				SV.Size = UDim2.new(1, -18, 1, -26)
				SV.Image = "rbxassetid://4155801252"
				SV.ImageColor3 = Color3.fromHSV(h, 1, 1)
				SV.AutoButtonColor = false
				addCorner(SV, UDim.new(0, 4))
				addStroke(SV, Color3.fromRGB(55, 55, 55))

				local SVPicker = Instance.new("Frame")
				SVPicker.Parent = SV
				SVPicker.Size = UDim2.new(0, 10, 0, 10)
				SVPicker.AnchorPoint = Vector2.new(0.5, 0.5)
				SVPicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				SVPicker.BorderSizePixel = 0
				addCorner(SVPicker, UDim.new(0, 10))
				addStroke(SVPicker, Color3.fromRGB(0, 0, 0))

				local Hue = Instance.new("ImageButton")
				Hue.Parent = Picker
				Hue.AnchorPoint = Vector2.new(1, 0)
				Hue.Position = UDim2.new(1, 0, 0, 0)
				Hue.Size = UDim2.new(0, 12, 1, -26)
				Hue.BackgroundColor3 = Color3.new(1, 1, 1)
				Hue.BorderSizePixel = 0
				Hue.Image = ""
				Hue.AutoButtonColor = false
				addCorner(Hue, UDim.new(0, 4))
				addStroke(Hue, Color3.fromRGB(55, 55, 55))

				local HueGrad = Instance.new("UIGradient")
				HueGrad.Parent = Hue
				HueGrad.Rotation = 90
				HueGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
				})

				local HuePicker = Instance.new("Frame")
				HuePicker.Parent = Hue
				HuePicker.Size = UDim2.new(1, 0, 0, 3)
				HuePicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				HuePicker.BorderSizePixel = 0
				addCorner(HuePicker, UDim.new(0, 4))

				local HexLabel = Instance.new("TextLabel")
				HexLabel.Parent = Picker
				HexLabel.BackgroundTransparency = 1
				HexLabel.Position = UDim2.new(0, 0, 1, -18)
				HexLabel.Size = UDim2.new(1, 0, 0, 12)
				HexLabel.Font = Library.Font
				HexLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
				HexLabel.TextSize = 10
				HexLabel.TextXAlignment = Enum.TextXAlignment.Left

				local function setPickerPositions()
					SVPicker.Position = UDim2.new(s, 0, 1 - v, 0)
					HuePicker.Position = UDim2.new(0, 0, h, 0)
				end

				local function applyColor()
					local c = hsvToColor(h, s, v)
					Preview.BackgroundColor3 = c
					SV.ImageColor3 = Color3.fromHSV(h, 1, 1)
					HexLabel.Text = colorToHex(c)
					if flag then
						Library.flags[flag] = c
					end
					pcall(callback, c)
				end

				local pickingSV = false
				local pickingHue = false

				local function updateSVFromPos(pos)
					local relX = clamp01((pos.X - SV.AbsolutePosition.X) / SV.AbsoluteSize.X)
					local relY = clamp01((pos.Y - SV.AbsolutePosition.Y) / SV.AbsoluteSize.Y)
					s = relX
					v = 1 - relY
					setPickerPositions()
					applyColor()
				end

				local function updateHueFromPos(pos)
					local relY = clamp01((pos.Y - Hue.AbsolutePosition.Y) / Hue.AbsoluteSize.Y)
					h = relY
					setPickerPositions()
					applyColor()
				end

				SV.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						pickingSV = true
						updateSVFromPos(input.Position)
					end
				end)
				Hue.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						pickingHue = true
						updateHueFromPos(input.Position)
					end
				end)

				UserInputService.InputChanged:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
						return
					end
					if pickingSV then
						updateSVFromPos(input.Position)
					elseif pickingHue then
						updateHueFromPos(input.Position)
					end
				end)

				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						pickingSV = false
						pickingHue = false
					end
				end)

				local function togglePicker()
					Picker.Visible = not Picker.Visible
				end
				Label.MouseButton1Click:Connect(togglePicker)
				Preview.MouseButton1Click:Connect(togglePicker)

				setPickerPositions()
				applyColor()
				if flag then
					Library.flags[flag] = hsvToColor(h, s, v)
				end

				local control = {
					Set = function(color)
						local nh, ns, nv = safeToHSV(color)
						h, s, v = nh, ns, nv
						setPickerPositions()
						applyColor()
					end,
					Get = function() return hsvToColor(h, s, v) end,
				}
				if flag then
					Library:_registerFlagControl(flag, control)
				end
				return control
			end

			-- v2-style names + flags
			function Section:AddLabel(opts)
				opts = opts or {}
				local text = opts.Text or opts.name or opts.Name or "Label"
				local align = opts.Align or opts.align or "Left"

				local Label = Instance.new("TextLabel")
				Label.Parent = Container
				Label.BackgroundTransparency = 1
				Label.Size = UDim2.new(1, 0, 0, 18)
				Label.Font = Library.Font
				Label.Text = text
				Label.TextColor3 = Color3.fromRGB(180, 180, 180)
				Label.TextSize = 13
				Label.TextWrapped = true
				Label.AutomaticSize = Enum.AutomaticSize.Y
				if align == "Center" then
					Label.TextXAlignment = Enum.TextXAlignment.Center
				elseif align == "Right" then
					Label.TextXAlignment = Enum.TextXAlignment.Right
				else
					Label.TextXAlignment = Enum.TextXAlignment.Left
				end

				return {
					Set = function(v) Label.Text = tostring(v) end,
					Get = function() return Label.Text end,
					Label = Label,
				}
			end

			function Section:AddKeybind(opts)
				opts = opts or {}
				local text = opts.Text or opts.name or opts.Name or "Keybind"
				local default = opts.Default or opts.default or Enum.KeyCode.E
				local callback = opts.Callback or opts.callback or function() end

				local KFrame = Instance.new("Frame")
				KFrame.Parent = Container
				KFrame.BackgroundTransparency = 1
				KFrame.Size = UDim2.new(1, 0, 0, 26)

				local Label = Instance.new("TextLabel")
				Label.Parent = KFrame
				Label.BackgroundTransparency = 1
				Label.Position = UDim2.new(0, 0, 0, 0)
				Label.Size = UDim2.new(1, -80, 1, 0)
				Label.Font = Library.Font
				Label.Text = text
				Label.TextColor3 = Color3.fromRGB(150, 150, 150)
				Label.TextSize = 13
				Label.TextXAlignment = Enum.TextXAlignment.Left

				local KeyBtn = Instance.new("TextButton")
				KeyBtn.Parent = KFrame
				KeyBtn.AnchorPoint = Vector2.new(1, 0)
				KeyBtn.Position = UDim2.new(1, 0, 0, 0)
				KeyBtn.Size = UDim2.new(0, 70, 0, 22)
				KeyBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
				KeyBtn.BorderSizePixel = 0
				KeyBtn.Font = Library.Font
				KeyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
				KeyBtn.TextSize = 12
				KeyBtn.AutoButtonColor = true
				addCorner(KeyBtn, UDim.new(0, 4))
				addStroke(KeyBtn, Color3.fromRGB(55, 55, 55))

				local currentKey = default
				local binding = false

				local function updateText()
					if binding then
						KeyBtn.Text = "..."
					else
						local keyName = currentKey.Name:gsub("^%l", string.upper)
						KeyBtn.Text = keyName
					end
				end

				KeyBtn.MouseButton1Click:Connect(function()
					binding = true
					updateText()
				end)

				UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if binding then
						if input.UserInputType == Enum.UserInputType.Keyboard then
							currentKey = input.KeyCode
							binding = false
							updateText()
						end
					elseif not gameProcessed and input.KeyCode == currentKey then
						pcall(callback)
					end
				end)

				updateText()

				return {
					Set = function(k)
						currentKey = k
						updateText()
					end,
					Get = function() return currentKey end,
				}
			end

			function Section:AddDivider(opts)
				opts = opts or {}
				local text = opts.Text or opts.text or ""
				local align = opts.Align or opts.align or "Center"

				local DFrame = Instance.new("Frame")
				DFrame.Parent = Container
				DFrame.BackgroundTransparency = 1
				DFrame.Size = UDim2.new(1, 0, 0, 20)

				local Line = Instance.new("Frame")
				Line.Parent = DFrame
				Line.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				Line.BorderSizePixel = 0
				Line.Position = UDim2.new(0, 0, 0.5, -1)
				Line.Size = UDim2.new(1, 0, 0, 1)

				if text ~= "" then
					local Label = Instance.new("TextLabel")
					Label.Parent = DFrame
					Label.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
					Label.BorderSizePixel = 0
					Label.Font = Library.Font
					Label.Text = " " .. text .. " "
					Label.TextColor3 = Color3.fromRGB(140, 140, 140)
					Label.TextSize = 12
					Label.AutomaticSize = Enum.AutomaticSize.X
					Label.Size = UDim2.new(0, 0, 0, 16)
					Label.Position = UDim2.new(0.5, 0, 0.5, -8)
					Label.AnchorPoint = Vector2.new(0.5, 0.5)
					if align == "Left" then
						Label.Position = UDim2.new(0, 0, 0.5, -8)
						Label.AnchorPoint = Vector2.new(0, 0.5)
					elseif align == "Right" then
						Label.Position = UDim2.new(1, 0, 0.5, -8)
						Label.AnchorPoint = Vector2.new(1, 0.5)
					end
				end

				return DFrame
			end

			function Section:toggle(opts)
				opts = opts or {}
				local flag = opts.flag
				local control = self:AddToggle({
					Text = opts.name or opts.Text or "Toggle",
					Default = opts.default == true or opts.Default == true,
					Callback = function(v)
						if flag then
							Library.flags[flag] = v
						end
						local cb = opts.callback or opts.Callback
						if cb then
							cb(v)
						end
					end,
				})
				if flag then
					Library.flags[flag] = control.Get()
				end
				return control
			end

			function Section:slider(opts)
				opts = opts or {}
				local flag = opts.flag
				local control = self:AddSlider({
					Text = opts.name or opts.Text or "Slider",
					Min = opts.min or opts.Min,
					Max = opts.max or opts.Max,
					Default = opts.default or opts.Default,
					Interval = opts.interval or opts.Interval,
					Suffix = opts.suffix or opts.Suffix or "",
					Callback = function(v)
						if flag then
							Library.flags[flag] = v
						end
						local cb = opts.callback or opts.Callback
						if cb then
							cb(v)
						end
					end,
				})
				if flag then
					Library.flags[flag] = control.Get()
				end
				return control
			end

			function Section:dropdown(opts)
				opts = opts or {}
				local flag = opts.flag
				local control = self:AddDropdown({
					Text = opts.name or opts.Text or "Dropdown",
					Items = opts.items or opts.Items or {},
					Default = opts.default or opts.Default,
					Callback = function(v)
						if flag then
							Library.flags[flag] = v
						end
						local cb = opts.callback or opts.Callback
						if cb then
							cb(v)
						end
					end,
				})
				if flag then
					Library.flags[flag] = control.Get()
				end
				return control
			end

			function Section:colorpicker(opts)
				opts = opts or {}
				local flag = opts.flag
				local alpha = tonumber(opts.alpha) or 0
				local cb = opts.callback or opts.Callback
				local control = self:AddColorPicker({
					Text = opts.name or opts.Text or "Color",
					Default = opts.color or opts.Default or Library.Accent,
					Callback = function(c)
						if flag then
							Library.flags[flag] = c
						end
						if cb then
							cb(c, alpha)
						end
					end,
				})
				if flag then
					Library.flags[flag] = control.Get()
				end
				return control
			end

			function Section:button(opts)
				opts = opts or {}
				return self:AddButton({
					Text = opts.name or opts.Text or "Button",
					Callback = opts.callback or opts.Callback,
				})
			end

			function Section:textbox(opts)
				opts = opts or {}
				local flag = opts.flag
				local control = self:AddTextBox({
					Text = opts.name or opts.Text or "Text",
					Placeholder = opts.placeholder or opts.Placeholder,
					Default = opts.default or opts.Default,
					Callback = function(v)
						if flag then
							Library.flags[flag] = v
						end
						local cb = opts.callback or opts.Callback
						if cb then
							cb(v)
						end
					end,
				})
				if flag then
					Library.flags[flag] = control.Get()
				end
				return control
			end

			function Section:label(opts)
				opts = opts or {}
				return self:AddLabel({
					Text = opts.name or opts.Text or "Label",
					Align = opts.align or opts.Align,
				})
			end

			function Section:keybind(opts)
				opts = opts or {}
				local flag = opts.flag
				local control = self:AddKeybind({
					Text = opts.name or opts.Text or "Keybind",
					Default = opts.default or opts.Default,
					Callback = function()
						local cb = opts.callback or opts.Callback
						if cb then
							cb()
						end
					end,
				})
				if flag then
					Library.flags[flag] = control.Get()
				end
				return control
			end

			function Section:divider(opts)
				opts = opts or {}
				return self:AddDivider({
					Text = opts.text or opts.Text or "",
					Align = opts.align or opts.Align,
				})
			end

			return Section
		end

		local tabObj = {
			Button = TabBtn,
			Underline = Underline,
			Container = TabContent,
			Tab = Tab,
		}
		table.insert(Window._tabs, tabObj)

		TabBtn.MouseButton1Click:Connect(function()
			setActiveTab(tabObj)
		end)

		if not Window._activeTab then
			setActiveTab(tabObj)
		end

		return Tab
	end

	-- Backward-compatible helpers (v1 scripts):
	-- - Window:Section(name, side)
	-- - Window:Tab(name)
	local compatDefaultTab = nil
	function Window:Tab(name)
		return self:CreateTab(name)
	end
	function Window:Section(name, side)
		if not compatDefaultTab then
			compatDefaultTab = self:CreateTab("General")
		end
		return compatDefaultTab:CreateSection(name, side)
	end

	function Window:SetOpen(isOpen)
		setOpen(isOpen)
	end

	-- Built-in Default/Settings tab (optional)
	function Window:EnableDefaultSettings(opts)
		opts = opts or {}
		local show = (opts.Enabled ~= false)
		if not show then
			return
		end
		if self._defaultSettingsEnabled then
			return
		end
		self._defaultSettingsEnabled = true

		local hadActive = (self._activeTab ~= nil)
		local settingsTabName = opts.TabName or "Settings"
		local settingsTab = self:CreateTab(settingsTabName, 1000000)

		-- If Settings is created first, don't force it active.
		if not hadActive then
			local tabObj = self._tabs[#self._tabs]
			if tabObj then
				tabObj.Container.Visible = false
				tabObj.Underline.Visible = false
				tabObj.Button.TextColor3 = Color3.fromRGB(130, 130, 130)
				self._activeTab = nil
			end
		end
		local uiSection = settingsTab:column():section({ name = "UI Settings" })

		uiSection:AddKeybind({
			Text = "Show/Hide UI",
			Default = Enum.KeyCode.RightControl,
			Callback = function()
				self:SetOpen(not self._main.Visible)
			end,
		})

		-- Accent
		local accentControl = uiSection:AddColorPicker({
			Text = "Custom UI Color",
			Default = Library.Accent,
			flag = "ui_accent",
			Callback = function(color)
				Library:SetAccent(color)
			end,
		})
		Library:_registerFlagControl("ui_accent", accentControl)

		-- Unload
		uiSection:AddButton({
			Text = "Unload",
			Callback = function()
				pcall(function()
					if Library.notifications and Library.notifications.create_notification then
						Library.notifications:create_notification({ Name = "Unloading", Info = "Destroying UI...", lifetime = 2 })
					end
				end)
				task.delay(0.1, function()
					pcall(function()
						self:Destroy()
					end)
				end)
			end,
		})

		-- Config System (library-managed)
		local configFolder = opts.ConfigFolder or "RoseConfigs"
		local function ensureFolder()
			if isfolder and makefolder and not isfolder(configFolder) then
				makefolder(configFolder)
			end
		end
		local function getConfigPath(name)
			return configFolder .. "/" .. tostring(name) .. ".json"
		end
		local function listConfigs()
			local out = {}
			if isfolder and listfiles and isfolder(configFolder) then
				for _, file in ipairs(listfiles(configFolder)) do
					local n = tostring(file):gsub(configFolder .. "/", ""):gsub("%.json$", "")
					if n ~= "" then
						table.insert(out, n)
					end
				end
			end
			if #out == 0 then
				table.insert(out, "No configs")
			end
			return out
		end
		local function notify(n, i)
			if Library.notifications and Library.notifications.create_notification then
				Library.notifications:create_notification({ Name = n, Info = i, lifetime = 3 })
			end
		end

		uiSection:AddDivider({ Text = "Config System", Align = "Center" })
		local configName = uiSection:AddTextBox({ Text = "Config Name", Placeholder = "Enter config name...", Default = "default" })
		local cfgItems = listConfigs()
		local cfgDropdown = uiSection:AddDropdown({ Text = "Config List", Items = cfgItems, Default = cfgItems[1] })

		uiSection:AddButton({
			Text = "Save Config",
			Callback = function()
				if not (writefile and HttpService) then
					notify("Error", "File API not available")
					return
				end
				ensureFolder()
				local name = configName.Get and configName.Get() or "default"
				if not name or tostring(name) == "" then
					notify("Error", "Missing config name")
					return
				end
				local data = HttpService:JSONEncode(Library:_encodeValue(Library.flags))
				writefile(getConfigPath(name), data)
				notify("Config Saved", "Saved '" .. tostring(name) .. "'")
				local items = listConfigs()
				if cfgDropdown.Refresh then
					cfgDropdown.Refresh(items)
				end
			end,
		})

		uiSection:AddButton({
			Text = "Load Config",
			Callback = function()
				if not (readfile and isfile and HttpService) then
					notify("Error", "File API not available")
					return
				end
				local name = cfgDropdown.Get and cfgDropdown.Get() or ""
				if not name or name == "No configs" then
					return
				end
				local path = getConfigPath(name)
				if not isfile(path) then
					notify("Error", "Config not found")
					return
				end
				local decoded = Library:_decodeValue(HttpService:JSONDecode(readfile(path)))
				Library:ApplyFlags(decoded)
				notify("Config Loaded", "Loaded '" .. tostring(name) .. "'")
			end,
		})

		uiSection:AddButton({
			Text = "Delete Config",
			Callback = function()
				if not (delfile and isfile) then
					notify("Error", "File API not available")
					return
				end
				local name = cfgDropdown.Get and cfgDropdown.Get() or ""
				if not name or name == "No configs" then
					return
				end
				local path = getConfigPath(name)
				if isfile(path) then
					delfile(path)
					notify("Config Deleted", "Deleted '" .. tostring(name) .. "'")
				end
				local items = listConfigs()
				if cfgDropdown.Refresh then
					cfgDropdown.Refresh(items)
				end
			end,
		})

		uiSection:AddButton({
			Text = "Refresh Configs",
			Callback = function()
				local items = listConfigs()
				if cfgDropdown.Refresh then
					cfgDropdown.Refresh(items)
				end
				notify("Refreshed", "Config list updated")
			end,
		})

		-- Socials/Key moved to right side (see below)

		-- Background controls
		local bgSection = settingsTab:column():section({ name = "Background" })
		bgSection:AddDivider({ Text = "Presets", Align = "Center" })
		local presetControl = bgSection:AddDropdown({
			Text = "Preset",
			Items = { "None", "Rose", "Midnight", "Sunset", "Forest", "Ocean", "Galaxy", "Ice", "Lava", "Mono" },
			Default = "None",
			flag = "bg_preset",
			Callback = function(v)
				self:SetBackgroundPreset(v)
			end,
		})
		Library:_registerFlagControl("bg_preset", presetControl)

		local imgControl = bgSection:AddTextBox({
			Text = "Image ID",
			Placeholder = "rbxassetid://123 or 123",
			Default = "",
			flag = "bg_image",
			Callback = function(v)
				self:SetBackgroundImage(v)
			end,
		})
		Library:_registerFlagControl("bg_image", imgControl)

		local styleControl = bgSection:AddDropdown({
			Text = "Background Style",
			Items = { "None", "Dim", "Dark" },
			Default = "Dark",
			flag = "bg_style",
			Callback = function(v)
				if v == "Dim" then
					self._main.BackgroundTransparency = 0.2
					self:SetBackgroundTransparency(0.88)
				elseif v == "Dark" then
					self._main.BackgroundTransparency = 0
					self._main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					self:SetBackgroundTransparency(0.82)
				else
					self._main.BackgroundTransparency = 0
					self._main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
					self:SetBackgroundTransparency(0.92)
				end
			end,
		})
		Library:_registerFlagControl("bg_style", styleControl)
		-- Apply style default immediately
		self._main.BackgroundTransparency = 0
		self._main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

		local titleOffsetControl = bgSection:AddSlider({
			Text = "Title Offset",
			Min = 0,
			Max = 10,
			Default = 0,
			Interval = 1,
			flag = "title_offset",
			Callback = function(v)
				self:SetTitleOffset(v)
			end,
		})
		Library:_registerFlagControl("title_offset", titleOffsetControl)

		-- Snow intentionally removed from Settings UI

		-- Right-side: Socials Info + Key Info (display only)
		local socialsSection = settingsTab:column():section({ name = "Socials Info" })
		socialsSection:AddDivider({ Text = "Links", Align = "Center" })
		local socials = opts.Socials
		if socials == nil then
			socials = {
				{ Name = "Discord", Url = "https://discord.gg/" },
				{ Name = "Website", Url = "https://" },
			}
		end
		for _, s in ipairs(socials) do
			socialsSection:AddButton({
				Text = tostring(s.Name or "Link"),
				Callback = function()
					local url = tostring(s.Url or "")
					if url == "" then
						notify("Error", "Missing URL")
						return
					end
					if setclipboard then
						setclipboard(url)
						notify("Copied", tostring(s.Name or "Link") .. " copied")
					else
						notify("Error", "Clipboard API not available")
					end
				end,
			})
		end

		socialsSection:AddDivider({ Text = "KEY INFO", Align = "Center" })
		local durationLabel = socialsSection:AddLabel({ Text = "Key Duration: Unknown", Align = "Left" })
		local scriptId = opts.LuarmorScriptId or opts.luarmorScriptId or opts.ScriptId or opts.script_id

		local function getGenv()
			local ok, genv = pcall(function()
				return getgenv and getgenv() or _G
			end)
			if ok and type(genv) == "table" then
				return genv
			end
			return _G
		end
		local function getLuaArmorApi()
			local genv = getGenv()
			if type(genv.__rose_luarmor_api) == "table" then
				return genv.__rose_luarmor_api
			end
			local api = loadstring(game:HttpGet("https://sdkapi-public.luarmor.net/library.lua"))()
			genv.__rose_luarmor_api = api
			return api
		end
		local function formatRemaining(seconds)
			seconds = math.floor(tonumber(seconds) or 0)
			if seconds <= 0 then
				return "0s"
			end
			local daysTotal = math.floor(seconds / 86400)
			if daysTotal > 365 then
				return "Lifetime"
			end
			local years = math.floor(seconds / (86400 * 365))
			seconds = seconds - years * 86400 * 365
			local months = math.floor(seconds / (86400 * 30))
			seconds = seconds - months * 86400 * 30
			local days = math.floor(seconds / 86400)
			seconds = seconds - days * 86400
			local hours = math.floor(seconds / 3600)
			seconds = seconds - hours * 3600
			local mins = math.floor(seconds / 60)
			seconds = seconds - mins * 60
			local parts = {}
			if years > 0 then table.insert(parts, tostring(years) .. "y") end
			if months > 0 then table.insert(parts, tostring(months) .. "mo") end
			if days > 0 then table.insert(parts, tostring(days) .. "d") end
			if hours > 0 then table.insert(parts, tostring(hours) .. "h") end
			if mins > 0 then table.insert(parts, tostring(mins) .. "m") end
			if #parts == 0 then table.insert(parts, tostring(seconds) .. "s") end
			return table.concat(parts, " ")
		end

		-- Try to fetch key duration automatically if script_key is already set.
		pcall(function()
			local genv = getGenv()
			local script_key = tostring(genv.script_key or "")
			if script_key == "" or not scriptId or tostring(scriptId) == "" then
				return
			end
			local api = getLuaArmorApi()
			api.script_id = tostring(scriptId)
			local status = api.check_key(script_key)
			if type(status) ~= "table" then
				return
			end
			if tostring(status.code or "") == "KEY_VALID" and type(status.data) == "table" and type(status.data.auth_expire) == "number" then
				local remaining = math.max(0, status.data.auth_expire - os.time())
				if durationLabel and durationLabel.Set then
					durationLabel.Set("Key Duration: " .. formatRemaining(remaining))
				end
			end
		end)

		socialsSection:AddButton({
			Text = "Copy Key",
			Callback = function()
				local genv = getGenv()
				local script_key = tostring(genv.script_key or "")
				if script_key == "" then
					notify("Error", "No script_key set")
					return
				end
				if setclipboard then
					setclipboard(script_key)
					notify("Copied", "Key copied")
				else
					notify("Error", "Clipboard API not available")
				end
			end,
		})
	end

	function Window:Destroy()
		if ScreenGui then
			ScreenGui:Destroy()
		end
	end

	-- v2-style API wrappers
	function Window:tab(opts)
		opts = opts or {}
		return self:CreateTab(opts.name or opts.Name or "Tab")
	end

	-- Default snow enable (can be overridden by callers via options)
	if options and options.SnowSpeed ~= nil then
		Window:SetSnowSpeed(options.SnowSpeed)
	else
		Window:SetSnowSpeed(5)
	end
	if options and options.SnowIntensity ~= nil then
		Window:SetSnowIntensity(options.SnowIntensity)
	else
		Window:SetSnowIntensity(160)
	end
	if options and options.SnowEnabled == false then
		Window:SetSnowEnabled(false)
	else
		Window:SetSnowEnabled(true)
	end

	return Window
end

-- Backward-compatible constructor name (v1 scripts): Library:Create()
function Library:Create(options)
	return self:CreateWindow(options)
end

-- v2-style constructor: library:window({ ... })
function Library:window(opts)
	return self:CreateWindow(opts)
end

-- Basic notifications API (v2-style)
function Library.notifications:create_notification(opts)
	opts = opts or {}
	local title = opts.name or opts.Name or Library.Name
	local info = opts.info or opts.Info or ""
	local lifetime = tonumber(opts.lifetime) or 3

	local holder = nil
	if Library and Library._lastWindow and Library._lastWindow._notifHolder then
		holder = Library._lastWindow._notifHolder
	end
	if not holder then
		return
	end

	local Card = Instance.new("Frame")
	Card.Parent = holder
	Card.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	Card.BorderSizePixel = 0
	Card.Size = UDim2.new(1, 0, 0, 60)
	Card.ZIndex = 61
	Card.BackgroundTransparency = 0.05
	addCorner(Card, UDim.new(0, 10))
	local cardStroke = addStroke(Card, Library.Accent)
	Library:_bindAccent(cardStroke, "Color")

	local Accent = Instance.new("Frame")
	Accent.Parent = Card
	Library:_bindAccent(Accent, "BackgroundColor3")
	Accent.BorderSizePixel = 0
	Accent.Size = UDim2.new(0, 3, 1, 0)
	Accent.Position = UDim2.new(0, 0, 0, 0)
	Accent.ZIndex = 62
	local acorner = Instance.new("UICorner")
	acorner.CornerRadius = UDim.new(0, 10)
	acorner.Parent = Accent

	local T = Instance.new("TextLabel")
	T.Parent = Card
	T.BackgroundTransparency = 1
	T.Position = UDim2.new(0, 16, 0, 8)
	T.Size = UDim2.new(1, -26, 0, 18)
	T.Font = Library.Font
	T.Text = tostring(title)
	T.TextColor3 = Color3.fromRGB(240, 240, 240)
	T.TextSize = 14
	T.TextXAlignment = Enum.TextXAlignment.Left
	T.TextTruncate = Enum.TextTruncate.AtEnd
	T.ZIndex = 62

	local I = Instance.new("TextLabel")
	I.Parent = Card
	I.BackgroundTransparency = 1
	I.Position = UDim2.new(0, 16, 0, 28)
	I.Size = UDim2.new(1, -26, 0, 24)
	I.Font = Library.Font
	I.Text = tostring(info)
	I.TextColor3 = Color3.fromRGB(180, 180, 180)
	I.TextSize = 12
	I.TextXAlignment = Enum.TextXAlignment.Left
	I.TextWrapped = true
	I.TextYAlignment = Enum.TextYAlignment.Top
	I.ZIndex = 62

	-- Fade in animation
	Card.BackgroundTransparency = 1
	T.TextTransparency = 1
	I.TextTransparency = 1
	Accent.BackgroundTransparency = 1

	TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.05 }):Play()
	TweenService:Create(T, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(I, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	TweenService:Create(Accent, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 }):Play()

	task.delay(lifetime, function()
		if Card and Card.Parent then
			TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(T, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
			TweenService:Create(I, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
			TweenService:Create(Accent, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
			task.delay(0.35, function()
				if Card and Card.Parent then
					Card:Destroy()
				end
			end)
		end
	end)
end

-- Track the most recent window for notifications
local _oldCreateWindow = Library.CreateWindow
function Library:CreateWindow(options)
	local w = _oldCreateWindow(self, options)
	Library._lastWindow = w
	return w
end

return Library
