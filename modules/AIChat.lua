local Main,Lib,Apps,Settings
local Explorer, Properties, ScriptViewer, Notebook, AIChat
local API,RMD,env,service,plr,create,createSimple

local function initDeps(data)
	Main = data.Main Lib = data.Lib Apps = data.Apps Settings = data.Settings
	API = data.API RMD = data.RMD env = data.env service = data.service
	plr = data.plr create = data.create createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer Notebook = Apps.Notebook AIChat = Apps.AIChat
end

local function main()
	local AIChat = {}
	local window, messageList, inputBox
	local conversationHistory = {}
	local isProcessing = false
	local HttpService = game:GetService("HttpService")

	local SCAN_CONTAINERS = {
		"ReplicatedStorage", "StarterPlayer", "StarterGui",
		"ReplicatedFirst", "Players"
	}
	local SKIP_SERVICES = { CoreGui = true, CorePackages = true }
	local SKIP_ANIMATE = true
	local function shouldSkip(obj)
		if SKIP_SERVICES[obj.Name] then return true end
		if SKIP_ANIMATE and obj.Name == "Animate" and obj.Parent and obj.Parent:IsA("Player") then return true end
		return false
	end
	local function getSource(obj)
		if not env.isViableDecompileScript or not env.isViableDecompileScript(obj) then return nil end
		local ok, src = pcall(env.decompile or function() end, obj)
		if ok and type(src) == "string" and #src > 0 then return src end
		return nil
	end
	local function searchInContainer(container, query, scriptTypes, maxResults)
		local results = {}
		local lowerQuery = query:lower()
		local function recur(obj)
			if #results >= maxResults then return end
			if shouldSkip(obj) then return end
			local isTarget = false
			for _, t in pairs(scriptTypes) do
				if obj:IsA(t) then isTarget = true break end
			end
			if isTarget then
				local src = getSource(obj)
				if src and src:lower():find(lowerQuery, 1, true) then
					results[#results+1] = {
						path = Explorer.GetInstancePath(obj),
						class = obj.ClassName,
						snippet = src:sub(1, 300)
					}
				end
			end
			for _, child in pairs(obj:GetChildren()) do
				if #results >= maxResults then return end
				recur(child)
			end
		end
		recur(container)
		return results
	end
	local function searchAll(query, scriptTypes, maxResults)
		maxResults = maxResults or 20
		local all = {}
		for _, svcName in pairs(SCAN_CONTAINERS) do
			local ok, svc = pcall(function() return game:GetService(svcName) end)
			if ok and svc then
				local res = searchInContainer(svc, query, scriptTypes, maxResults - #all)
				for _, r in pairs(res) do all[#all+1] = r end
			end
			if #all >= maxResults then break end
		end
		if #all < maxResults then
			local res = searchInContainer(workspace, query, scriptTypes, maxResults - #all)
			for _, r in pairs(res) do all[#all+1] = r end
		end
		return all
	end

	local function executeTool(toolName, args)
		if toolName == "SEARCH_SCRIPTS" then
			local query = args[1] or ""
			local tipStr = (args[2] or "local"):lower()
			local types = {}
			if tipStr == "local" then types = {"LocalScript"}
			elseif tipStr == "module" then types = {"ModuleScript"}
			elseif tipStr == "server" then types = {"Script"}
			else types = {"LocalScript","ModuleScript","Script"} end

			local results = searchAll(query, types, 15)
			if #results == 0 then
				return "No scripts found: `" .. query .. "`"
			end
			local lines = {"Found " .. #results .. " scripts:"}
			for _, r in pairs(results) do
				lines[#lines+1] = "\n[" .. r.class .. "] " .. r.path
				lines[#lines+1] = "Snippet:\n" .. r.snippet:sub(1,200) .. "\n---"
			end
			return table.concat(lines, "\n")

		elseif toolName == "GET_SOURCE" then
			local pathStr = args[1] or ""
			local parts = pathStr:split(".")
			local obj = game
			local ok = true
			for _, part in pairs(parts) do
				if part == "game" then
				elseif part:sub(1,11) == "GetService(" then
					local svcName = part:match('GetService%("(.+)"%)')
					if svcName then
						local s, r = pcall(function() return game:GetService(svcName) end)
						if s then obj = r else ok = false break end
					end
				else
					local child = obj:FindFirstChild(part)
					if child then obj = child else ok = false break end
				end
			end
			if not ok or obj == game then return "Path not found: " .. pathStr end
			local src = getSource(obj)
			if not src then return "Source could not be retrieved (not decompilable or not a script)" end
			return "```lua\n" .. src:sub(1, 1500) .. (src:len() > 1500 and "\n-- [truncated]" or "") .. "\n```"

		elseif toolName == "LIST_CHILDREN" then

			local svcName = args[1] or "ReplicatedStorage"
			local ok, svc = pcall(function() return game:GetService(svcName) end)
			if not ok then return "Service not found: " .. svcName end
			local children = svc:GetChildren()
			if #children == 0 then return svcName .. " is empty." end
			local lines = {svcName .. " contains the following objects (" .. #children .. "):"}
			for _, c in pairs(children) do
				lines[#lines+1] = "  [" .. c.ClassName .. "] " .. c.Name
			end
			return table.concat(lines, "\n")
		end

		return "Unknown tool: " .. toolName
	end

	local function processToolCalls(text)
		local toolResults = {}
		for call in text:gmatch("%[TOOL:([^%]]+)%]") do
			local parts = call:split("|")
			local toolName = table.remove(parts, 1)
			local result = executeTool(toolName, parts)
			toolResults[#toolResults+1] = "**[" .. toolName .. " result]**\n" .. result
		end
		local cleanText = text:gsub("%[TOOL:[^%]]+%]", ""):match("^%s*(.-)%s*$")
		return cleanText, toolResults
	end

local SYSTEM_PROMPT = [[You are an AI assistant embedded in Dex, a Roblox developer tool.
You can search scripts in the game using these tools. Write tool calls at the end of your message exactly like this:
[TOOL:SEARCH_SCRIPTS|search_text|type]   (type: local, module, server, all)
[TOOL:GET_SOURCE|full.path.here]
[TOOL:LIST_CHILDREN|ServiceName]
Explain what you are doing before the tool call. Respond in the same language as the user.]]

local function callAPI(messages)
	local provider = Settings.AIChat.Provider or "Gemini"
	local apiKey = Settings.AIChat.APIKey
	local maxTok = Settings.AIChat.MaxTokens or 8192
	local temp = Settings.AIChat.Temperature or 0.7
	local request = env.request
	if not request then return nil, "request() missing" end

	if provider ~= "Pollinations" and (not apiKey or apiKey == "") then
		return nil, "API Key not set."
	end

	local url, headers, body

	if provider == "Claude" then
		url = "https://api.anthropic.com/v1/messages"
		headers = {
			["content-type"] = "application/json",
			["x-api-key"] = apiKey,
			["anthropic-version"] = "2023-06-01",
		}
		body = HttpService:JSONEncode({
			model = Settings.AIChat.Model or "claude-sonnet-4-5",
			max_tokens = maxTok,
			system = SYSTEM_PROMPT,
			messages = messages,
		})

	elseif provider == "OpenAI" then
		url = "https://api.openai.com/v1/chat/completions"
		headers = {
			["content-type"] = "application/json",
			["Authorization"] = "Bearer " .. apiKey,
		}
		local msgs = {{role = "system", content = SYSTEM_PROMPT}}
		for _, m in pairs(messages) do msgs[#msgs+1] = m end
		body = HttpService:JSONEncode({
			model = Settings.AIChat.Model or "gpt-4o-mini",
			max_tokens = maxTok,
			temperature = temp,
			messages = msgs,
		})

	elseif provider == "Pollinations" then
		url = "https://text.pollinations.ai/openai"
		headers = {
			["content-type"] = "application/json",
		}
		local msgs = {{role = "system", content = SYSTEM_PROMPT}}
		for _, m in pairs(messages) do msgs[#msgs+1] = m end
		body = HttpService:JSONEncode({
			model = Settings.AIChat.Model or "openai",
			max_tokens = maxTok,
			temperature = temp,
			messages = msgs,
		})

	else
		local model = Settings.AIChat.Model or "gemini-2.5-flash"
		url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. apiKey
		headers = {
			["content-type"] = "application/json",
		}

		local contents = {}
		for i, m in pairs(messages) do
			local role = m.role == "assistant" and "model" or "user"
			local text = m.content
			if i == 1 and m.role == "user" then
				text = SYSTEM_PROMPT .. "\n\n---\n\n" .. text
			end
			if #contents > 0 and contents[#contents].role == role then
				contents[#contents].parts[1].text ..= "\n" .. text
			else
				contents[#contents+1] = {role = role, parts = {{text = text}}}
			end
		end

		body = HttpService:JSONEncode({
			contents = contents,
			generationConfig = {maxOutputTokens = maxTok, temperature = temp},
		})
	end

	local ok, resp = pcall(request, {Url = url, Method = "POST", Headers = headers, Body = body})
	if not ok then return nil, "Request failed: " .. tostring(resp) end
	if resp.StatusCode ~= 200 then return nil, "API error " .. resp.StatusCode .. ": " .. resp.Body:sub(1, 300) end

	local decoded = HttpService:JSONDecode(resp.Body)
	local text

	if provider == "Claude" then
		text = decoded.content and decoded.content[1] and decoded.content[1].text
	elseif provider == "OpenAI" or provider == "Pollinations" then
		text = decoded.choices and decoded.choices[1] and decoded.choices[1].message and decoded.choices[1].message.content
	else
		text = decoded.candidates and decoded.candidates[1] and decoded.candidates[1].content and decoded.candidates[1].content.parts and decoded.candidates[1].content.parts[1] and decoded.candidates[1].content.parts[1].text
	end

	return text or "Empty response", nil
end

	local function scrollToBottom()
		task.defer(function()
			messageList.CanvasPosition = Vector2.new(0, messageList.AbsoluteCanvasSize.Y)
		end)
	end

	local function addMessage(role, text)
		local isUser = role == "user"
		local bg = Instance.new("Frame")
		bg.BackgroundColor3 = isUser and Color3.fromRGB(40,60,90) or Color3.fromRGB(45,45,45)
		bg.BorderSizePixel = 0
		bg.Size = UDim2.new(1,0,0,10)
		bg.AutomaticSize = Enum.AutomaticSize.Y
		bg.Parent = messageList

		local corner = Instance.new("UICorner", bg)
		corner.CornerRadius = UDim.new(0,6)
		local pad = Instance.new("UIPadding", bg)
		pad.PaddingLeft = UDim.new(0,8) pad.PaddingRight = UDim.new(0,8)
		pad.PaddingTop = UDim.new(0,6) pad.PaddingBottom = UDim.new(0,6)

		local prefix = isUser and "You: " or "AI: "
		local lbl = Instance.new("TextLabel", bg)
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1,0,0,0)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.Font = Enum.Font.SourceSans
		lbl.TextSize = 13
		lbl.TextColor3 = Color3.new(1,1,1)
		lbl.TextWrapped = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.Text = prefix .. text

		scrollToBottom()
		return lbl
	end

	local function addStatus(text)
		local lbl = Instance.new("TextLabel", messageList)
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1,0,0,20)
		lbl.Font = Enum.Font.SourceSans
		lbl.TextSize = 12
		lbl.TextColor3 = Color3.fromRGB(150,150,150)
		lbl.TextWrapped = true
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.Text = text
		scrollToBottom()
		return lbl
	end

local abortFlag = false

local function sendMessage(userText)
    if isProcessing then
        abortFlag = true
        return
    end
    if userText == "" then return end
    isProcessing = true
    abortFlag = false

    addMessage("user", userText)
    conversationHistory[#conversationHistory+1] = {role="user", content=userText}

    local statusLbl = addStatus("AI is thinking...")

    local aiText, err = callAPI(conversationHistory)

    if abortFlag then
        statusLbl:Destroy()
        isProcessing = false
        abortFlag = false
        return
    end

    if err then
        statusLbl:Destroy()
        addMessage("assistant", "Error: " .. err)
        isProcessing = false
        return
    end

    local cleanText, toolResults = processToolCalls(aiText)

    if #toolResults > 0 then
        statusLbl.Text = "Scanning scripts..."
        local toolContext = table.concat(toolResults, "\n\n")
        conversationHistory[#conversationHistory+1] = {role="assistant", content=aiText}
        conversationHistory[#conversationHistory+1] = {role="user", content="[Tool results]\n" .. toolContext .. "\n\nAnswer based on these results."}

        local finalText, err2 = callAPI(conversationHistory)
        statusLbl:Destroy()
        if abortFlag then
            isProcessing = false
            abortFlag = false
            return
        end
        if err2 then
            addMessage("assistant", "Error: " .. err2)
        else
            local finalClean = finalText:gsub("%[TOOL:[^%]]+%]",""):match("^%s*(.-)%s*$")
            conversationHistory[#conversationHistory+1] = {role="assistant", content=finalClean}
            addMessage("assistant", finalClean)
        end
    else
        statusLbl:Destroy()
        if cleanText and #cleanText > 0 then
            conversationHistory[#conversationHistory+1] = {role="assistant", content=cleanText}
            addMessage("assistant", cleanText)
        end
    end

    isProcessing = false
end

	AIChat.Init = function()
		window = Lib.Window.new()
		window:SetTitle("AI Chat")
		window:Resize(520, 450)
		AIChat.Window = window

		local content = window.GuiElems.Content

		local listFrame = Instance.new("ScrollingFrame", content)
		listFrame.Name = "MessageList"
		listFrame.Size = UDim2.new(1,0,1,-38)
		listFrame.Position = UDim2.new(0,0,0,0)
		listFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
		listFrame.BorderSizePixel = 0
		listFrame.CanvasSize = UDim2.new(0,0,0,0)
		listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		listFrame.ScrollBarThickness = 8
		listFrame.ScrollBarImageColor3 = Color3.fromRGB(80,80,80)

		local layout = Instance.new("UIListLayout", listFrame)
		layout.Padding = UDim.new(0,6)
		local lpad = Instance.new("UIPadding", listFrame)
		lpad.PaddingLeft = UDim.new(0,6) lpad.PaddingRight = UDim.new(0,6)
		lpad.PaddingTop = UDim.new(0,6) lpad.PaddingBottom = UDim.new(0,6)

		messageList = listFrame

		local inputBar = Instance.new("Frame", content)
		inputBar.Size = UDim2.new(1,0,0,36)
		inputBar.Position = UDim2.new(0,0,1,-36)
		inputBar.BackgroundColor3 = Color3.fromRGB(40,40,40)
		inputBar.BorderSizePixel = 0

		inputBox = Instance.new("TextBox", inputBar)
		inputBox.Size = UDim2.new(1,-100,1,-8)
		inputBox.Position = UDim2.new(0,4,0,4)
		inputBox.BackgroundColor3 = Color3.fromRGB(55,55,55)
		inputBox.BorderSizePixel = 0
		inputBox.Text = ""
		inputBox.TextColor3 = Color3.new(1,1,1)
		inputBox.PlaceholderText = "Ask a question..."
		inputBox.PlaceholderColor3 = Color3.fromRGB(120,120,120)
		inputBox.Font = Enum.Font.SourceSans
		inputBox.TextSize = 13
		inputBox.TextXAlignment = Enum.TextXAlignment.Left
		inputBox.ClearTextOnFocus = false
		local ipad = Instance.new("UIPadding", inputBox)
		ipad.PaddingLeft = UDim.new(0,6)
		local icorner = Instance.new("UICorner", inputBox)
		icorner.CornerRadius = UDim.new(0,4)

		local sendBtn = Instance.new("TextButton", inputBar)
		sendBtn.Size = UDim2.new(0,54,1,-8)
		sendBtn.Position = UDim2.new(1,-58,0,4)
		sendBtn.BackgroundColor3 = Color3.fromRGB(0,120,200)
		sendBtn.BorderSizePixel = 0
		sendBtn.Font = Enum.Font.SourceSansBold
		sendBtn.TextSize = 13
		sendBtn.TextColor3 = Color3.new(1,1,1)
		sendBtn.Text = "Send"
		local sbcorner = Instance.new("UICorner", sendBtn)
		sbcorner.CornerRadius = UDim.new(0,4)

		local attachBtn = Instance.new("TextButton", inputBar)
		attachBtn.Size = UDim2.new(0,30,1,-8)
		attachBtn.Position = UDim2.new(0,inputBox.Position.X.Offset + inputBox.Size.X.Offset + 2, 0, 4)
		attachBtn.BackgroundColor3 = Color3.fromRGB(55,55,55)
		attachBtn.BorderSizePixel = 0
		attachBtn.Font = Enum.Font.SourceSansBold
		attachBtn.TextSize = 14
		attachBtn.TextColor3 = Color3.new(1,1,1)
		attachBtn.Text = "📎"
		local acorner = Instance.new("UICorner", attachBtn)
		acorner.CornerRadius = UDim.new(0,4)

local function doSend()
    local txt = inputBox.Text:match("^%s*(.-)%s*$")
    if isProcessing then
        abortFlag = true
        sendBtn.Text = "Send"
        return
    end
    inputBox.Text = ""
    sendBtn.Text = "■"
    task.spawn(function()
        sendMessage(txt)
        sendBtn.Text = "Send"
    end)
end

		sendBtn.MouseButton1Click:Connect(doSend)
		inputBox.FocusLost:Connect(function(enter)
			if enter then doSend() end
		end)

		attachBtn.MouseButton1Click:Connect(function()
    if not Explorer or not Explorer.Selection then
        addMessage("assistant", "Explorer not available.")
        return
    end
    local node = Explorer.Selection.List[1]
    if not node then
        addMessage("assistant", "No instance selected in Explorer.")
        return
    end
    local obj = node.Obj
    if not obj:IsA("LuaSourceContainer") then
        addMessage("assistant", "Selected instance is not a script.")
        return
    end
    local src = getSource(obj)
    if not src or src == "" then
        addMessage("assistant", "Could not decompile: " .. obj.Name)
        return
    end
    local fname = obj.Name .. ".lua"
    local sizeTxt = src and (#src < 1024 and #src.."B" or string.format("%.1f",#src/1024).."KB") or "?"
    addMessage("user", "📄 " .. fname .. " · " .. sizeTxt)
    conversationHistory[#conversationHistory+1] = {
        role="user",
        content="[Attached script: " .. fname .. "]\n```lua\n" .. src:sub(1,6000) .. (src:len()>6000 and "\n-- [truncated]" or "") .. "\n```"
    }
    if ScriptViewer and ScriptViewer.Window then
        task.defer(function()
            ScriptViewer.Window:SetTitle(fname)
            ScriptViewer.Window:Show()
        end)
    end
end)
window.OnActivate:Connect(function()
    isProcessing = false
    abortFlag = false
end)
		addMessage("assistant", "Hello! I can help you analyze the Roblox game structure.\n\nExample questions:\n• 'Where was this remote event \"<event_name>\" used?'\n• 'What's in ReplicatedStorage?'\n• 'Show me the source of game.Players.LocalPlayer.PlayerScripts.Main'")
	end

	return AIChat
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
