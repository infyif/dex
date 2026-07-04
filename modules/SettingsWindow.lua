--[[
	Save Instance App Module
	
	Revival of the old dex's Save Instance
]] 

-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, SettingsWindow, Notebook, AIChat -- Major Apps
local API,RMD,env,service,plr,create,createSimple -- Main Locals

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
	SettingsWindow = Apps.SettingsWindow
	Notebook = Apps.Notebook
	AIChat = Apps.AIChat
end

local function main()
	local SettingsWindow = {}
	local window, ListFrame
	local fileName = "Place_"..game.PlaceId.."_"..game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name.."_{TIMESTAMP}"
	local Saving = false
	
	local function AddCheckbox(title, default)
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)
		
		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)
		
		-- Checkbox
		local checkbox = Lib.Checkbox.new()
		
		checkbox.Gui.Parent = frame.Gui
		checkbox.Gui.Size = UDim2.new(0,15,0,15)
		
		-- Label
		local label = Lib.Label.new()
		
		label.Gui.Parent = frame.Gui
		label.Gui.Size = UDim2.new(1, 0,1, -15)
		label.Gui.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd
		
		checkbox:SetState(default or false)
		
		return checkbox
	end
	
	local function AddTextbox(title, default, sizeX)
		default = default and tostring(default) or ""
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)

		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)

		-- Textbox
		local textbox = Instance.new("TextBox") -- replaced cuz why Moon make every inputs only work on mouse/pc users >:( 
		textbox.BackgroundColor3 = Settings.Theme.TextBox
		textbox.BorderColor3 = Settings.Theme.Outline3
		textbox.ClearTextOnFocus = false
		textbox.TextColor3 = Settings.Theme.Text
		textbox.Font = Enum.Font.SourceSans
		textbox.TextSize = 14
		textbox.ZIndex = 2

		textbox.Parent = frame.Gui
		if sizeX and type(sizeX) == "number" then
			textbox.Size = UDim2.new(0,sizeX,0,15)
		else
			textbox.Size = UDim2.new(0,45,0,15)
		end
		
		frame.Gui.AutomaticSize = Enum.AutomaticSize.X
		textbox.AutomaticSize = Enum.AutomaticSize.X

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		label.Size = UDim2.new(1, 0,1, -15)
		label.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd

		textbox.Text = default

		return textbox
	end
	
	local function AddDropdown(title, options, default, allowEmpty, sizeX)
		if allowEmpty == nil then allowEmpty = true end
		
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)

		local listlayout = Instance.new("UIListLayout")
		listlayout.Parent = frame.Gui
		listlayout.FillDirection = Enum.FillDirection.Horizontal
		listlayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listlayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listlayout.Padding = UDim.new(0, 10)

		-- Textbox
		local dropdown = Lib.DropDown.new()
		dropdown.CanBeEmpty = allowEmpty
		dropdown.Size = UDim2.new(0,sizeX or 75,0,15)
		dropdown:SetOptions(options)
		if default then dropdown:SetSelected(default) end
		dropdown.Gui.Parent = frame.Gui

		frame.Gui.AutomaticSize = Enum.AutomaticSize.X

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		label.Size = UDim2.new(1, 0,1, -15)
		label.Text = title
		label.TextTruncate = Enum.TextTruncate.AtEnd
		
		return dropdown
	end
	
	local function AddSeperator(title)

		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,20)
		
		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		--label.AnchorPoint = Vector2.new(0,1)
		--label.Position = UDim2.new(0,0,0,0)
		label.Size = UDim2.new(1, 0,1, 0)
		label.Text = title
		label.TextSize = 16
		label.TextTruncate = Enum.TextTruncate.AtEnd

		return label
	end
	
	local function AddText(text)
		local frame = Lib.Frame.new()
		frame.Gui.Parent = ListFrame
		frame.Gui.Transparency = 1
		frame.Gui.Size = UDim2.new(1,0,0,15)

		-- Label
		local label = Lib.Label.new()

		label.Parent = frame.Gui
		--label.AnchorPoint = Vector2.new(0,1)
		--label.Position = UDim2.new(0,0,0,0)
		label.Size = UDim2.new(1, 0,1, 0)
		label.TextColor3 = Color3.fromRGB(185,185,185)
		label.Text = text
		label.TextSize = 14
		label.TextTruncate = Enum.TextTruncate.AtEnd

		return label
	end
	
	SettingsWindow.ReloadPrompt = function()		
		local win = ScriptViewer.ReloadPromptWindow
		if not win then
			win = Lib.Window.new()
			win.Alignable = false
			win.Resizable = false
			win:SetTitle("Apply Current Settings")
			win:SetSize(300,115)

			local reloadButton = Lib.Button.new()
			local nameLabel = Lib.Label.new()
			nameLabel.Text = "By applying current settings requires reload.\nAny unsaved progress will be lost.\nAre you sure?"
			nameLabel.Position = UDim2.new(0,30,0,20)
			nameLabel.Size = UDim2.new(0,40,0,20)
			win:Add(nameLabel)

			local cancelButton = Lib.Button.new()
			cancelButton.AnchorPoint = Vector2.new(1,1)
			cancelButton.Text = "Apply Later"
			cancelButton.Position = UDim2.new(1,-5,1,-5)
			cancelButton.Size = UDim2.new(0.5,-10,0,20)
			cancelButton.OnClick:Connect(function()
				win:Close()
			end)
			win:Add(cancelButton)

			reloadButton.Text = "Apply Now"
			reloadButton.AnchorPoint = Vector2.new(0,1)
			reloadButton.Position = UDim2.new(0,5,1,-5)
			reloadButton.Size = UDim2.new(0.5,-5,0,20)
			reloadButton.OnClick:Connect(function()
				Main.Reinit()
			end)

			win:Add(reloadButton,"reloadButton")

			SettingsWindow.ReloadPromptWindow = win
		end
		win:Show()
	end
	
	SettingsWindow.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Settings")
		window:Resize(250,375)
		SettingsWindow.Window = window
		
		-- ListFrame
		
		ListFrame = Instance.new("ScrollingFrame")
		ListFrame.Parent = window.GuiElems.Content
		ListFrame.Size = UDim2.new(1, 0,1, -20)
		ListFrame.Position = UDim2.new(0, 0, 0, 0)
		ListFrame.Transparency = 1
		ListFrame.CanvasSize = UDim2.new(0,0,0,0)
		ListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ListFrame.ScrollBarThickness = 16
		ListFrame.BottomImage = ""
		ListFrame.TopImage = ""
		ListFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
		ListFrame.ScrollBarImageTransparency = 0
		ListFrame.ZIndex = 2
		ListFrame.BorderSizePixel = 0
		
		local scrollbar = Lib.ScrollBar.new()
		scrollbar.Gui.Parent = window.GuiElems.Content
		scrollbar.Gui.Size = UDim2.new(1, 0,1, -40)
		scrollbar.Gui.Up.ZIndex = 3
		scrollbar.Gui.Down.ZIndex = 3
		
		ListFrame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
			if ListFrame.AbsoluteCanvasSize ~= ListFrame.AbsoluteWindowSize then
				scrollbar.Gui.Visible = true
			else
				scrollbar.Gui.Visible = false
			end
		end)
		
		local ListLayout = Instance.new("UIListLayout")
		ListLayout.Parent = ListFrame
		ListLayout.Padding = UDim.new(0, 5)
		
		local Padding = Instance.new("UIPadding")
		Padding.Parent = ListFrame
		Padding.PaddingBottom = UDim.new(0, 5)
		Padding.PaddingLeft = UDim.new(0, 10)
		Padding.PaddingRight = UDim.new(0, 10)
		Padding.PaddingTop = UDim.new(0, 5)
		
		-- Options
		
		AddSeperator("UI")
		
		local titleonmiddle = AddCheckbox("Window Title On Middle", Settings.Window.TitleOnMiddle)
		titleonmiddle.OnInput:Connect(function()
			Settings.Window.TitleOnMiddle = titleonmiddle.Toggled
		end)
		
		local bgTransparency = AddTextbox("Background Transparency", tostring(Settings.Window.Transparency), 15)
		bgTransparency.FocusLost:Connect(function()
			Settings.Window.Transparency = tonumber(bgTransparency.Text)
		end)
		
		local classIcon = AddDropdown("Class Icons", {"Old", "NewDark", "Vanilla3"}, Settings.ClassIcon, false, 100)
		classIcon.OnSelect:Connect(function()
			Settings.ClassIcon = classIcon.Selected
		end)
		
		AddSeperator("Explorer")
		
		local clickRename = AddCheckbox("Click to Rename", Settings.Explorer.ClickToRename)
		clickRename.OnInput:Connect(function()
			Settings.Explorer.ClickToRename = clickRename.Toggled
		end)
		
		local partSelectionBox = AddCheckbox("Part Selection Box", Settings.Explorer.PartSelectionBox)
		partSelectionBox.OnInput:Connect(function()
			Settings.Explorer.PartSelectionBox = partSelectionBox.Toggled
		end)
		
		local copypathUseChildren = AddCheckbox("Use GetChildren to Copy Path", Settings.Explorer.CopyPathUseGetChildren)
		copypathUseChildren.OnInput:Connect(function()
			Settings.Explorer.CopyPathUseGetChildren = copypathUseChildren.Toggled
		end)
		
		AddSeperator("Properties")

		local showDeprecated = AddCheckbox("Show Deprecated", Settings.Properties.ShowDeprecated)
		showDeprecated.OnInput:Connect(function()
			Settings.Properties.ShowDeprecated = showDeprecated.Toggled
		end)
		
		local showHidden = AddCheckbox("Show Hidden", Settings.Properties.ShowHidden)
		showHidden.OnInput:Connect(function()
			Settings.Properties.ShowHidden = showHidden.Toggled
		end)
		
		local showAttributes = AddCheckbox("Show Attributes", Settings.Properties.ShowAttributes)
		showAttributes.OnInput:Connect(function()
			Settings.Properties.ShowAttributes = showAttributes.Toggled
		end)
		local clearOnFocus = AddCheckbox("Clear On Focus", Settings.Properties.ClearOnFocus)
		clearOnFocus.OnInput:Connect(function()
			Settings.Properties.ClearOnFocus = clearOnFocus.Toggled
		end)
		
		AddSeperator("Script Viewer")
		
		local showMoreInfo = AddCheckbox("Show Decompiled Script Info", Settings.ScriptViewer.ShowMoreInfo)
		showMoreInfo.OnInput:Connect(function()
			Settings.ScriptViewer.ShowMoreInfo = showMoreInfo.Toggled
		end)
		
        AddSeperator("Decompiler")
		AddText("If executor does not support decompile, it will use the fallback option.")
		AddText("'getbytecode' is mandatory to use fallback decompilers.")

		local decompilerOption = {"Lua Expert", "DecompilerLol", "Shiny", "x2125", "Konstant", "Oracle"}
		local decompiler = AddDropdown("Decompiler Fallback", decompilerOption, Settings.Decompiler.DecompilerFallback, false, 125)

		local ShinyPort = AddTextbox("Shiny Decompiler Port", tostring(Settings.Decompiler.ShinyDecompilerPort), 50)
		ShinyPort.Parent.Visible = Settings.Decompiler.DecompilerFallback == "Shiny"

		local OracleKey = AddTextbox("Oracle API Key", Settings.Decompiler.OracleAPIKey or "", 150)
		OracleKey.Parent.Visible = Settings.Decompiler.DecompilerFallback == "Oracle"

		local OracleVersion = AddDropdown("Oracle Version", {"1", "2"}, tostring(Settings.Decompiler.OracleVersion or 2), false, 60)
		OracleVersion.Gui.Parent.Visible = Settings.Decompiler.DecompilerFallback == "Oracle"

		decompiler.OnSelect:Connect(function()
			Settings.Decompiler.DecompilerFallback = decompiler.Selected
			ShinyPort.Parent.Visible = decompiler.Selected == "Shiny"
			OracleKey.Parent.Visible = decompiler.Selected == "Oracle"
			OracleVersion.Gui.Parent.Visible = decompiler.Selected == "Oracle"
		end)

		ShinyPort.FocusLost:Connect(function()
			local portinput = tonumber(ShinyPort.Text)
			if not portinput then
				ShinyPort.Text = Settings.Decompiler.ShinyDecompilerPort
			else
				if portinput > 0 and portinput <= 65535 then
					Settings.Decompiler.ShinyDecompilerPort = portinput
				else
					ShinyPort.Text = Settings.Decompiler.ShinyDecompilerPort
				end
			end
		end)

		OracleKey.FocusLost:Connect(function()
			Settings.Decompiler.OracleAPIKey = OracleKey.Text
		end)

		OracleVersion.OnSelect:Connect(function()
			Settings.Decompiler.OracleVersion = tonumber(OracleVersion.Selected)
		end)

		local preferFallback = AddCheckbox("Prefer Fallback Decompiler", Settings.Decompiler.PreferDecompilerFallback)
		preferFallback.OnInput:Connect(function()
			Settings.Decompiler.PreferDecompilerFallback = preferFallback.Toggled
		end)

		local stripHeader = AddCheckbox("Strip Decompiler Header", Settings.Decompiler.StripHeader)
		stripHeader.OnInput:Connect(function()
			Settings.Decompiler.StripHeader = stripHeader.Toggled
		end)
		
        AddSeperator("AIChat")
		AddText("Configure AI Chat with Claude, OpenAI, Gemini or Pollinations.")

		local aiModels = {}
		pcall(function()
			local res = game:HttpGet("https://raw.githubusercontent.com/infyif/dex/main/AI/models")
			aiModels = loadstring(res)()
		end)

		if not next(aiModels) then
			aiModels = {
				["Claude"] = {"claude-sonnet-4-6"},
				["OpenAI"] = {"gpt-4o"},
				["Gemini"] = {"gemini-2.5-flash"},
				["Pollinations"] = {"openai"},
			}
		end

		local apiKeyInput = AddTextbox("API Key", Settings.AIChat.APIKey, 150)
		apiKeyInput.Parent.Visible = Settings.AIChat.Provider ~= "Pollinations"
		apiKeyInput.FocusLost:Connect(function()
			Settings.AIChat.APIKey = apiKeyInput.Text
		end)

		local providerDropdown = AddDropdown("Provider", {"Claude", "OpenAI", "Gemini", "Pollinations"}, Settings.AIChat.Provider, false, 100)

		local currentModels = aiModels[Settings.AIChat.Provider] or {}
		local modelDropdown = AddDropdown("Model", currentModels, Settings.AIChat.Model, false, 150)
		modelDropdown.OnSelect:Connect(function()
			Settings.AIChat.Model = modelDropdown.Selected
		end)

		providerDropdown.OnSelect:Connect(function()
			Settings.AIChat.Provider = providerDropdown.Selected
			apiKeyInput.Parent.Visible = providerDropdown.Selected ~= "Pollinations"
			local models = aiModels[providerDropdown.Selected] or {}
			modelDropdown:SetOptions(models)
			if #models > 0 then
				modelDropdown:SetSelected(models[1])
				Settings.AIChat.Model = models[1]
			end
		end)

		local maxTokensInput = AddTextbox("Max Tokens", tostring(Settings.AIChat.MaxTokens), 50)
		maxTokensInput.FocusLost:Connect(function()
			local val = tonumber(maxTokensInput.Text)
			if val and val > 0 and val <= 32000 then
				Settings.AIChat.MaxTokens = val
			else
				maxTokensInput.Text = tostring(Settings.AIChat.MaxTokens)
			end
		end)

		local tempInput = AddTextbox("Temperature", tostring(Settings.AIChat.Temperature), 50)
		tempInput.FocusLost:Connect(function()
			local val = tonumber(tempInput.Text)
			if val and val >= 0 and val <= 1 then
				Settings.AIChat.Temperature = val
			else
				tempInput.Text = tostring(Settings.AIChat.Temperature)
			end
		end)
		
		-- Save buttons below
		local BackgroundreloadButton = Lib.Frame.new()
		BackgroundreloadButton.Gui.Parent = window.GuiElems.Content
		BackgroundreloadButton.Size = UDim2.new(0.5,-5,0,20)
		BackgroundreloadButton.Position = UDim2.new(0,0,1,-20)
		
		local LabelreloadButton = Lib.Label.new()
		LabelreloadButton.Gui.Parent = window.GuiElems.Content
		LabelreloadButton.Size = UDim2.new(0.5,-5,0,20)
		LabelreloadButton.Position = UDim2.new(0,0,1,-20)
		LabelreloadButton.Gui.Text = "Restart"
		LabelreloadButton.Gui.TextXAlignment = Enum.TextXAlignment.Center
		
		local reloadButton = Instance.new("TextButton")
		reloadButton.Parent = BackgroundreloadButton.Gui
		reloadButton.Size = UDim2.new(1,0, 1,0)
		reloadButton.Position = UDim2.new(0,0, 0,0)
		reloadButton.Transparency = 1
		
		reloadButton.MouseButton1Click:Connect(function()
			window:SetTitle("Settings - Saving")
			
			Main.SaveCurrentSettings()
			
			window:SetTitle("Settings - Saved")
			SettingsWindow.ReloadPrompt()
			task.wait(3)
			
			window:SetTitle("Settings")
		end)

		local BackgroundCloseButton = Lib.Frame.new()
		BackgroundCloseButton.Gui.Parent = window.GuiElems.Content
		BackgroundCloseButton.Size = UDim2.new(0.5,-5,0,20)
		BackgroundCloseButton.Position = UDim2.new(0.5,5,1,-20)

		local LabelCloseButton = Lib.Label.new()
		LabelCloseButton.Gui.Parent = window.GuiElems.Content
		LabelCloseButton.Size = UDim2.new(0.5,-5,0,20)
		LabelCloseButton.Position = UDim2.new(0.5,5,1,-20)
		LabelCloseButton.Gui.Text = "Close"
		LabelCloseButton.Gui.TextXAlignment = Enum.TextXAlignment.Center

		local closeButton = Instance.new("TextButton")
		closeButton.Parent = BackgroundCloseButton.Gui
		closeButton.Size = UDim2.new(1,0,1,0)
		closeButton.BackgroundTransparency = 1

		closeButton.MouseButton1Click:Connect(function()
    		Main.Uninit()
		end)
	end

	return SettingsWindow
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end