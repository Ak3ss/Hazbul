local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()

local RANKS = {
    [4126624226] = "Dev",
}

local playerId = game.Players.LocalPlayer.UserId
local rank = RANKS[playerId] or "Free"
local subtitleText = (rank == "Dev") and "Dev User" or "Free User"

local Window = Luna:CreateWindow({
	Name = "Hazbul",
	Subtitle = subtitleText,
	LogoID = nil,
	LoadingEnabled = true,
	LoadingTitle = "Hazbul Project",
	LoadingSubtitle = "by Akute ;D",
	ConfigSettings = {
		RootFolder = nil,
		ConfigFolder = "Hazbul"
	},
	KeySystem = false,
	KeySettings = {
		Title = "Luna Example Key",
		Subtitle = "Key System",
		Note = "key is 1234!",
		SaveInRoot = false,
		SaveKey = true,
		Key = {"1234"},
		SecondAction = {
			Enabled = true,
			Type = "Link",
			Parameter = ""
		}
	}
})

Window:CreateHomeTab({
	SupportedExecutors = {
		"Synapse X","Krnl","ProtoSmasher","Fluxus","Script-Ware","EasyExploits",
		"Electron","JJSploit","Calamari","SirHurt","Sentinel","WEAREDEVS",
		"Comet","Cellery","Wave","CODex","Delta","Real","Solara","Xeno"
	},
	DiscordInvite = "driprplt",
	Icon = 1
})

local Tab = Window:CreateTab({
	Name = "Automation",
	Icon = "view_in_ar",
	ImageSource = "Material",
	ShowTitle = true
})

local SellTab = Window:CreateTab({
	Name = "Sell Settings",
	Icon = "money",
	ImageSource = "Material",
	ShowTitle = true
})

local MiscTab = Window:CreateTab({
	Name = "Misc",
	Icon = "tune",
	ImageSource = "Material",
	ShowTitle = true
})

local ConfigTab = Window:CreateTab({
	Name = "Config Tab",
	Icon = "settings",
	ImageSource = "Material",
	ShowTitle = true
})

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local LP                = Players.LocalPlayer

local CONFIG = {
	AutoOpen      = false,
	CaseAmount    = 1,
	OpeningSpeed  = 1,
	SelectedCase  = nil,
	DoSell        = true,
	SellThreshold = 20000,
	SellUnknown   = false,
	SellSpeed     = 0.5,
	HideOpening   = true,
	DisableBloom  = true,
	AntiAFK       = false,
	ShowNotifs    = true,
}

local function parsePrice(str)
	local s = str:gsub("[%$,]", "")
	local num, suffix = s:match("([%d%.]+)%s*([KkMm]?)")
	if not num then return 0 end
	local n = tonumber(num) or 0
	if suffix == "K" or suffix == "k" then n = n * 1000
	elseif suffix == "M" or suffix == "m" then n = n * 1_000_000 end
	return n
end

local function getItemPrice(item, scrolling)
	if not scrolling then return nil end
	for _, f in ipairs(scrolling:GetChildren()) do
		if f.Name:sub(1, #item.Name) == item.Name then
			local tmpl = f:FindFirstChild("Template")
			local p = tmpl and tmpl:FindFirstChild("Price")
			if p and p:IsA("TextLabel") then
				return parsePrice(p.Text)
			end
		end
	end
	return nil
end

local function formatNumber(n)
	if n >= 1_000_000 then
		return string.format("%.2fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.2fK", n / 1_000)
	end
	return tostring(n)
end

local loopRunning = false
local loopThread  = nil
local lastSellTime = 0

local function startAutoLoop()
	if loopRunning then return end
	loopRunning = true

	loopThread = task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local Event   = remotes:WaitForChild("MainEvent")

		while loopRunning do
			if not CONFIG.AutoOpen then
				break
			end

			local gui     = LP:FindFirstChild("PlayerGui")
			local mainGui = gui and gui:FindFirstChild("MainGui")

			if CONFIG.HideOpening then
				local opening = mainGui and mainGui:FindFirstChild("Opening")
				if opening then opening.Visible = false end
			end

			if CONFIG.DisableBloom then
				local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
				if bloom then bloom.Enabled = false end
			end

			if CONFIG.DoSell then
				local now = tick()
				if (now - lastSellTime) >= CONFIG.SellSpeed then
					lastSellTime = now

					local toSell = {}
					local inv = LP:FindFirstChild("Inventory")

					local scrolling
					if mainGui then
						local itemFrame = mainGui:FindFirstChild("ItemFrame")
						local holder    = itemFrame and itemFrame:FindFirstChild("Holder")
						scrolling       = holder and holder:FindFirstChild("ScrollingFrame")
					end

					if inv then
						for _, item in ipairs(inv:GetChildren()) do
							if item:IsA("NumberValue") then
								local price = getItemPrice(item, scrolling)
								if price == nil then
									if CONFIG.SellUnknown then
										table.insert(toSell, item)
									end
								else
									if price > 0 and price < CONFIG.SellThreshold then
										table.insert(toSell, item)
									end
								end
							end
						end
					end

					if #toSell > 0 then
						pcall(function()
							Event:FireServer("SellItem", toSell)
						end)
					end
				end
			end

			if CONFIG.SelectedCase and CONFIG.SelectedCase ~= "No cases found" then
				pcall(function()
					Event:FireServer("OpenCase", CONFIG.SelectedCase, CONFIG.CaseAmount)
				end)
			end

			task.wait(CONFIG.OpeningSpeed)
		end

		loopRunning = false
		loopThread  = nil
	end)
end

local function stopAutoLoop()
	loopRunning = false
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
end

local antiAfkConn = nil
local function setAntiAfk(enabled)
	if enabled then
		if antiAfkConn then return end
		antiAfkConn = LP.Idled:Connect(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	else
		if antiAfkConn then
			antiAfkConn:Disconnect()
			antiAfkConn = nil
		end
	end
end

local caseNames = {}
pcall(function()
	local casesFolder = ReplicatedStorage:WaitForChild("Cases", 10)
	if casesFolder then
		for _, caseObj in ipairs(casesFolder:GetChildren()) do
			table.insert(caseNames, caseObj.Name)
		end
	end
end)

if #caseNames == 0 then
	table.insert(caseNames, "No cases found")
end
table.sort(caseNames)
CONFIG.SelectedCase = caseNames[1]

Tab:CreateSection("Case Opening")

local Toggle = Tab:CreateToggle({
	Name = "Auto Open Case",
	Description = "Starts/stops the sell + open case loop",
	CurrentValue = false,
	Callback = function(Value)
		CONFIG.AutoOpen = Value
		if Value then
			startAutoLoop()
		else
			stopAutoLoop()
		end
	end
}, "AutoOpenToggle")

Tab:CreateSlider({
	Name = "Cases Amount",
	Range = {1, 50},
	Increment = 1,
	CurrentValue = 1,
	Callback = function(Value)
		CONFIG.CaseAmount = Value
	end
}, "CasesAmountSlider")

Tab:CreateSlider({
	Name = "Opening Speed (s)",
	Range = {0.05, 2},
	Increment = 0.05,
	CurrentValue = 1,
	Callback = function(Value)
		CONFIG.OpeningSpeed = Value
	end
}, "OpeningSpeedSlider")

local Dropdown = Tab:CreateDropdown({
	Name = "Select Case",
	Description = "Choose which case to auto-open",
	Options = caseNames,
	CurrentOption = {CONFIG.SelectedCase},
	MultipleOptions = false,
	SpecialType = nil,
	Callback = function(Options)
		local picked
		if type(Options) == "table" then
			picked = Options[1] or Options.Option or Options.Value
		elseif type(Options) == "string" then
			picked = Options
		end
		if picked then
			CONFIG.SelectedCase = picked
		else
			warn("[Hazbul] Dropdown returned unexpected value:", Options)
		end
	end
}, "CaseDropdown")

SellTab:CreateSection("Sell Options")

SellTab:CreateToggle({
	Name = "Auto Sell",
	Description = "Automatically sells items below the threshold",
	CurrentValue = true,
	Callback = function(Value)
		CONFIG.DoSell = Value
	end
}, "AutoSellToggle")

SellTab:CreateToggle({
	Name = "Sell Unknown Price",
	Description = "Sell items whose price could not be read",
	CurrentValue = false,
	Callback = function(Value)
		CONFIG.SellUnknown = Value
	end
}, "SellUnknownToggle")

SellTab:CreateSlider({
	Name = "Sell Under Value",
	Description = "Items priced under this will be sold",
	Range = {0, 1000000},
	Increment = 100,
	CurrentValue = 20000,
	Callback = function(Value)
		CONFIG.SellThreshold = Value
	end
}, "SellValueSlider")

SellTab:CreateSlider({
	Name = "Sell Interval (s)",
	Description = "How often the seller runs (0 = every loop)",
	Range = {0, 5},
	Increment = 0.1,
	CurrentValue = 0.5,
	Callback = function(Value)
		CONFIG.SellSpeed = Value
	end
}, "SellSpeedSlider")

SellTab:CreateSection("Presets")

SellTab:CreateButton({
	Name = "Low Threshold (5K)",
	Description = "Only sell very cheap items",
	Callback = function()
		CONFIG.SellThreshold = 5000
	end
}, "PresetLow")

SellTab:CreateButton({
	Name = "Medium Threshold (20K)",
	Description = "Balanced",
	Callback = function()
		CONFIG.SellThreshold = 20000
	end
}, "PresetMid")

SellTab:CreateButton({
	Name = "High Threshold (100K)",
	Description = "Sell almost everything",
	Callback = function()
		CONFIG.SellThreshold = 100000
	end
}, "PresetHigh")

SellTab:CreateButton({
	Name = "Sell Everything Now",
	Description = "Instantly triggers a sell pass",
	Callback = function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local Event = remotes and remotes:FindFirstChild("MainEvent")
		if not Event then
			warn("[Hazbul] MainEvent not found")
			return
		end

		local toSell = {}
		local inv = LP:FindFirstChild("Inventory")
		if inv then
			for _, item in ipairs(inv:GetChildren()) do
				if item:IsA("NumberValue") then
					table.insert(toSell, item)
				end
			end
		end

		if #toSell > 0 then
			Event:FireServer("SellItem", toSell)
		end
	end
}, "SellAllNow")

MiscTab:CreateSection("Visual")

MiscTab:CreateToggle({
	Name = "Hide Opening Animation",
	Description = "Hides the case opening GUI",
	CurrentValue = true,
	Callback = function(Value)
		CONFIG.HideOpening = Value
	end
}, "HideOpeningToggle")

MiscTab:CreateToggle({
	Name = "Disable Bloom",
	Description = "Removes BloomEffect for less lag",
	CurrentValue = true,
	Callback = function(Value)
		CONFIG.DisableBloom = Value
		if not Value then
			local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
			if bloom then bloom.Enabled = true end
		end
	end
}, "DisableBloomToggle")

MiscTab:CreateSection("Utility")

MiscTab:CreateToggle({
	Name = "Anti-AFK",
	Description = "Prevents Roblox from kicking you for idling",
	CurrentValue = false,
	Callback = function(Value)
		CONFIG.AntiAFK = Value
		setAntiAfk(Value)
	end
}, "AntiAfkToggle")

ConfigTab:BuildConfigSection()
