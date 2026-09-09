AutoRoll = {}
AutoRoll.Version = "1.0"
AutoRoll.Roll = {
	Pass = 0,
	Need = 1,
	Greed = 2,
	Disenchant = 3,
}
AutoRoll_Options = AutoRoll_Options or {}
AutoRoll_Autoroll = AutoRoll_Autoroll or {}
AutoRoll_Destroy  = AutoRoll_Destroy  or {}

local _listCache = nil
local function InvalidateListCache() _listCache = nil end
AutoRoll.Queue = {}
AutoRollOptionsFrame = nil

local function SL_Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00AutoRoll:|r " .. tostring(msg))
end

function AutoRoll.EnsureOptions()
	local o = AutoRoll_Options
	if o.Enabled == nil then o.Enabled = true end
	if o.HideDefaultFrames == nil then o.HideDefaultFrames = true end
	if o.AutoLoot == nil then o.AutoLoot = true end
	if o.AutoConfirm == nil then o.AutoConfirm = true end
	if o.ShowMinimapButton == nil then o.ShowMinimapButton = true end
	if o.MinimapButtonPosition == nil then o.MinimapButtonPosition = 281 end
	if o.MinimapButtonRadius == nil then o.MinimapButtonRadius = 80 end
	if o.AutoGreedGreens == nil then o.AutoGreedGreens = false end
	if o.AutoGreedGreensMinLevel == nil then o.AutoGreedGreensMinLevel = 60 end
	if o.AutoGreedRoll == nil then o.AutoGreedRoll = "disenchant" end
	if o.AutoGreedQualities == nil then o.AutoGreedQualities = "green" end
	if o.AutoDestroy == nil then o.AutoDestroy = false end
end

local function CreateOptionsFrame()
	if AutoRollOptionsFrame then return end

	local f = CreateFrame("Frame", "AutoRollOptionsFrame", UIParent)
	f:SetWidth(575)
	f:SetHeight(480)
	f:SetPoint("CENTER")
	f:Hide()

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -16)
	title:SetText("AutoRoll")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -5, -5)

	local tabAutoRoll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	tabAutoRoll:SetWidth(90)
	tabAutoRoll:SetHeight(22)
	tabAutoRoll:SetText("AutoRoll")
	tabAutoRoll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -35)

	local tabDestroy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	tabDestroy:SetWidth(100)
	tabDestroy:SetHeight(22)
	tabDestroy:SetText("AutoDestroy")
	tabDestroy:SetPoint("LEFT", tabAutoRoll, "RIGHT", 4, 0)

	-- ── AutoRoll panel ───────────────────────────────────────────────────────
	local panelRoll = CreateFrame("Frame", nil, f)
	panelRoll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -60)
	panelRoll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	panelRoll:Show()

	local enableCheck = CreateFrame("CheckButton", "AutoRollOptionsFrame_Enable", panelRoll, "UICheckButtonTemplate")
	enableCheck:SetPoint("TOPLEFT", 10, -5)
	enableCheck:SetChecked(AutoRoll_Options.Enabled)
	enableCheck:SetScript("OnClick", function(self)
		AutoRoll_Options.Enabled = self:GetChecked() and true or false
	end)
	local enableLabel = panelRoll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	enableLabel:SetPoint("LEFT", enableCheck, "RIGHT", 1, 1)
	enableLabel:SetText("Enable AutoRoll")

	local autoGreedCheck = CreateFrame("CheckButton", "AutoRollOptionsFrame_AutoGreedGreens", panelRoll, "UICheckButtonTemplate")
	autoGreedCheck:SetPoint("TOPLEFT", 10, -26)
	autoGreedCheck:SetChecked(AutoRoll_Options.AutoGreedGreens)
	autoGreedCheck:SetScript("OnClick", function(self)
		AutoRoll_Options.AutoGreedGreens = self:GetChecked() and true or false
	end)
	local autoGreedLabel1 = panelRoll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autoGreedLabel1:SetPoint("LEFT", autoGreedCheck, "RIGHT", 1, 1)
	autoGreedLabel1:SetText("Auto-")

	local rollBtn = CreateFrame("Button", "AutoRollOptionsFrame_AutoGreedRollBtn", panelRoll, "UIPanelButtonTemplate")
	rollBtn:SetHeight(20)
	rollBtn:SetPoint("LEFT", autoGreedLabel1, "RIGHT", 2, -1)
	local function UpdateRollBtnText()
		local t = AutoRoll_Options.AutoGreedRoll
		rollBtn:SetText(t == "greed" and "Greed" or t == "pass" and "Pass" or "Disenchant")
		rollBtn:SetWidth(rollBtn:GetFontString():GetStringWidth() + 18)
	end
	UpdateRollBtnText()
	rollBtn:SetScript("OnClick", function(self)
		if not self.menu then
			self.menu = CreateFrame("Frame", "AutoRollRollDropMenu", UIParent, "UIDropDownMenuTemplate")
		end
		local menuTable = {}
		for _, o in ipairs({ {"Greed","greed"}, {"Disenchant","disenchant"}, {"Pass","pass"} }) do
			local v = o[2]
			table.insert(menuTable, {
				text = o[1], checked = (AutoRoll_Options.AutoGreedRoll == v),
				func = function() AutoRoll_Options.AutoGreedRoll = v; UpdateRollBtnText() end,
			})
		end
		EasyMenu(menuTable, self.menu, self, 0, 20, "MENU")
	end)

	local autoGreedLabel2 = panelRoll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autoGreedLabel2:SetPoint("LEFT", rollBtn, "RIGHT", 4, 1)
	autoGreedLabel2:SetText("all")

	local qualBtn = CreateFrame("Button", "AutoRollOptionsFrame_AutoGreedQualBtn", panelRoll, "UIPanelButtonTemplate")
	qualBtn:SetHeight(20)
	qualBtn:SetPoint("LEFT", autoGreedLabel2, "RIGHT", 2, -1)
	local function UpdateQualBtnText()
		qualBtn:SetText(AutoRoll_Options.AutoGreedQualities == "greenblue" and "green & blue" or "green")
		qualBtn:SetWidth(qualBtn:GetFontString():GetStringWidth() + 18)
	end
	UpdateQualBtnText()
	qualBtn:SetScript("OnClick", function(self)
		if not self.menu then
			self.menu = CreateFrame("Frame", "AutoRollQualDropMenu", UIParent, "UIDropDownMenuTemplate")
		end
		EasyMenu({
			{ text="Green only",   checked=(AutoRoll_Options.AutoGreedQualities=="green"),
			  func=function() AutoRoll_Options.AutoGreedQualities="green";     UpdateQualBtnText() end },
			{ text="Green & Blue", checked=(AutoRoll_Options.AutoGreedQualities=="greenblue"),
			  func=function() AutoRoll_Options.AutoGreedQualities="greenblue"; UpdateQualBtnText() end },
		}, self.menu, self, 0, 20, "MENU")
	end)

	local autoGreedLabel3 = panelRoll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autoGreedLabel3:SetPoint("LEFT", qualBtn, "RIGHT", 4, 1)
	autoGreedLabel3:SetText("items when player level is")

	local levelBox = CreateFrame("EditBox", "AutoRollOptionsFrame_AutoGreedLevel", panelRoll, "InputBoxTemplate")
	levelBox:SetWidth(20)
	levelBox:SetHeight(18)
	levelBox:SetPoint("LEFT", autoGreedLabel3, "RIGHT", 8, -1)
	levelBox:SetAutoFocus(false)
	levelBox:SetNumeric(true)
	levelBox:SetMaxLetters(2)
	levelBox:SetText(tostring(AutoRoll_Options.AutoGreedGreensMinLevel))
	levelBox:SetScript("OnEnterPressed", function(self)
		local val = math.max(1, math.min(99, tonumber(self:GetText()) or 60))
		AutoRoll_Options.AutoGreedGreensMinLevel = val
		self:SetText(tostring(val))
		self:ClearFocus()
	end)
	levelBox:SetScript("OnEditFocusLost", function(self)
		local val = math.max(1, math.min(99, tonumber(self:GetText()) or 60))
		AutoRoll_Options.AutoGreedGreensMinLevel = val
		self:SetText(tostring(val))
	end)

	local levelLabel2 = panelRoll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	levelLabel2:SetPoint("LEFT", levelBox, "RIGHT", 4, 0)
	levelLabel2:SetText("or above")

	local rowTip = CreateFrame("Frame", nil, panelRoll)
	rowTip:SetPoint("LEFT", autoGreedCheck, "LEFT", 0, 0)
	rowTip:SetPoint("RIGHT", levelLabel2, "RIGHT", 0, 0)
	rowTip:SetHeight(22)
	rowTip:SetFrameLevel(f:GetFrameLevel() + 1)
	rowTip:EnableMouse(true)
	rowTip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("Saved item rules take priority over this setting.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	rowTip:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local header = panelRoll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOPLEFT", 16, -68)
	header:SetText("Saved auto-roll items")

	local searchBox = CreateFrame("EditBox", "AutoRollOptionsFrame_Search", panelRoll, "InputBoxTemplate")
	searchBox:SetWidth(200)
	searchBox:SetHeight(20)
	searchBox:SetPoint("LEFT", header, "RIGHT", 12, 0)
	searchBox:SetAutoFocus(false)
	searchBox:SetMaxLetters(64)
	local searchHint = panelRoll:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	searchHint:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
	searchHint:SetText("Search...")
	searchBox:SetScript("OnTextChanged", function(self)
		local txt = self:GetText()
		if txt == "" then searchHint:Show() else searchHint:Hide() end
		AutoRoll.searchFilter = txt ~= "" and txt:lower() or nil
		AutoRoll.RenderAutorollList()
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
		AutoRoll.searchFilter = nil
		AutoRoll.RenderAutorollList()
	end)
	AutoRollOptionsFrame_Search = searchBox

	local ROW_COUNT  = 16
	local ROW_HEIGHT = 20

	local scrollFrame = CreateFrame("ScrollFrame", "AutoRollOptionsFrame_AutorollScroll", panelRoll, "FauxScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 12, -88)
	scrollFrame:SetWidth(527)
	scrollFrame:SetHeight(ROW_COUNT * ROW_HEIGHT)
	AutoRollOptionsFrame_AutorollScroll = scrollFrame

	local content = CreateFrame("Frame", "AutoRollOptionsFrame_AutorollScrollContent", panelRoll)
	content:SetWidth(520)
	content:SetHeight(ROW_COUNT * ROW_HEIGHT)
	content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
	content.rows = {}
	AutoRollOptionsFrame_AutorollScrollContent = content

	for i = 1, ROW_COUNT do
		local row = CreateFrame("Frame", nil, content)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
		row:SetPoint("RIGHT", content, "RIGHT", -10, 0)
		row:Hide()

		local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		remove:SetHeight(18)
		remove:SetText("Remove")
		remove:SetWidth(remove:GetTextWidth() + 6)
		remove:SetPoint("LEFT", row, "LEFT", 4, 0)
		remove:SetScript("OnClick", function(self)
			AutoRoll.AutorollListRemove(self:GetParent().itemName)
		end)
		local removeText = remove:GetFontString()
		if removeText then
			removeText:SetFont(removeText:GetFont(), 11)
			removeText:SetPoint("CENTER", remove, "CENTER", 0, -1)
		end

		local dropdown = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		dropdown:SetHeight(18)
		dropdown:SetText("Disenchant")
		dropdown:SetWidth(dropdown:GetTextWidth() + 8)
		dropdown:SetPoint("LEFT", remove, "RIGHT", 4, 0)
		local ddText = dropdown:GetFontString()
		if ddText then
			ddText:SetFont(ddText:GetFont(), 11)
			ddText:SetPoint("CENTER", dropdown, "CENTER", 0, -1)
		end
		dropdown:SetScript("OnClick", function(self)
			if not self.menu then
				self.menu = CreateFrame("Frame", "AutoRollDropdownMenu"..i, UIParent, "UIDropDownMenuTemplate")
			end
			local itemName    = self:GetParent().itemName
			local currentRoll = AutoRoll_Autoroll[itemName] and AutoRoll_Autoroll[itemName].roll
			EasyMenu({
				{ text="Need",       checked=(currentRoll==AutoRoll.Roll.Need),
				  func=function() AutoRoll.SetAutorollRoll(itemName, AutoRoll.Roll.Need) end },
				{ text="Greed",      checked=(currentRoll==AutoRoll.Roll.Greed),
				  func=function() AutoRoll.SetAutorollRoll(itemName, AutoRoll.Roll.Greed) end },
				{ text="Disenchant", checked=(currentRoll==AutoRoll.Roll.Disenchant),
				  func=function() AutoRoll.SetAutorollRoll(itemName, AutoRoll.Roll.Disenchant) end },
				{ text="Pass",       checked=(currentRoll==AutoRoll.Roll.Pass),
				  func=function() AutoRoll.SetAutorollRoll(itemName, AutoRoll.Roll.Pass) end },
			}, self.menu, self, 76, 0, "MENU")
		end)

		local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		text:SetPoint("LEFT", dropdown, "RIGHT", 4, 0)
		text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		text:SetJustifyH("LEFT")
		text:SetNonSpaceWrap(false)
		text:SetWordWrap(false)
		row.text     = text
		row.remove   = remove
		row.dropdown = dropdown
		content.rows[i] = row
	end

	scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, AutoRoll.RenderAutorollList)
	end)

	-- ── AutoDestroy panel ────────────────────────────────────────────────────
	local panelDestroy = CreateFrame("Frame", nil, f)
	panelDestroy:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -60)
	panelDestroy:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	panelDestroy:Hide()

	local destroyEnableCheck = CreateFrame("CheckButton", "AutoRollOptionsFrame_DestroyEnable", panelDestroy, "UICheckButtonTemplate")
	destroyEnableCheck:SetPoint("TOPLEFT", 10, -5)
	destroyEnableCheck:SetChecked(AutoRoll_Options.AutoDestroy)
	destroyEnableCheck:SetScript("OnClick", function(self)
		AutoRoll_Options.AutoDestroy = self:GetChecked() and true or false
	end)
	local destroyEnableLabel = panelDestroy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	destroyEnableLabel:SetPoint("LEFT", destroyEnableCheck, "RIGHT", 1, 1)
	destroyEnableLabel:SetText("Enable AutoDestroy")

	local destroyNote = panelDestroy:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	destroyNote:SetPoint("TOPLEFT", 10, -30)
	destroyNote:SetText("Items in this list will be automatically looted and destroyed.")

	local destroyInputBox = CreateFrame("EditBox", "AutoRollOptionsFrame_DestroyInput", panelDestroy, "InputBoxTemplate")
	destroyInputBox:SetWidth(320)
	destroyInputBox:SetHeight(20)
	destroyInputBox:SetPoint("TOPLEFT", 14, -50)
	destroyInputBox:SetAutoFocus(false)
	destroyInputBox:SetMaxLetters(128)
	local destroyInputHint = panelDestroy:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	destroyInputHint:SetPoint("LEFT", destroyInputBox, "LEFT", 6, 0)
	destroyInputHint:SetText("Item name...")
	destroyInputBox:SetScript("OnTextChanged", function(self)
		if self:GetText() == "" then destroyInputHint:Show() else destroyInputHint:Hide() end
	end)

	local destroyAddBtn = CreateFrame("Button", nil, panelDestroy, "UIPanelButtonTemplate")
	destroyAddBtn:SetHeight(20)
	destroyAddBtn:SetWidth(60)
	destroyAddBtn:SetText("Add")
	destroyAddBtn:SetPoint("LEFT", destroyInputBox, "RIGHT", 6, 0)
	destroyAddBtn:SetScript("OnClick", function()
		local name = destroyInputBox:GetText()
		name = name and name:match("^%s*(.-)%s*$")
		if name and name ~= "" and not AutoRoll_Destroy[name] then
			AutoRoll_Destroy[name] = true
			AutoRoll.RenderDestroyList()
			destroyInputBox:SetText("")
			destroyInputHint:Show()
		end
	end)
	destroyInputBox:SetScript("OnEnterPressed", function(self)
		local name = self:GetText()
		name = name and name:match("^%s*(.-)%s*$")
		if name and name ~= "" and not AutoRoll_Destroy[name] then
			AutoRoll_Destroy[name] = true
			AutoRoll.RenderDestroyList()
			self:SetText("")
			destroyInputHint:Show()
		end
		self:ClearFocus()
	end)

	local destroyHeader = panelDestroy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	destroyHeader:SetPoint("TOPLEFT", 16, -76)
	destroyHeader:SetText("Items to destroy")

	local DROW_COUNT = 16
	local destroyScroll = CreateFrame("ScrollFrame", "AutoRollOptionsFrame_DestroyScroll", panelDestroy, "FauxScrollFrameTemplate")
	destroyScroll:SetPoint("TOPLEFT", 12, -96)
	destroyScroll:SetWidth(527)
	destroyScroll:SetHeight(DROW_COUNT * ROW_HEIGHT)
	AutoRollOptionsFrame_DestroyScroll = destroyScroll

	local destroyContent = CreateFrame("Frame", "AutoRollOptionsFrame_DestroyScrollContent", panelDestroy)
	destroyContent:SetWidth(520)
	destroyContent:SetHeight(DROW_COUNT * ROW_HEIGHT)
	destroyContent:SetPoint("TOPLEFT", destroyScroll, "TOPLEFT", 0, 0)
	destroyContent.rows = {}
	AutoRollOptionsFrame_DestroyScrollContent = destroyContent

	for i = 1, DROW_COUNT do
		local row = CreateFrame("Frame", nil, destroyContent)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", destroyContent, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
		row:SetPoint("RIGHT", destroyContent, "RIGHT", -10, 0)
		row:Hide()

		local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		removeBtn:SetHeight(18)
		removeBtn:SetText("Remove")
		removeBtn:SetWidth(removeBtn:GetTextWidth() + 6)
		removeBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
		removeBtn:SetScript("OnClick", function(self)
			local n = self:GetParent().itemName
			if n then AutoRoll_Destroy[n] = nil; AutoRoll.RenderDestroyList() end
		end)
		local rText = removeBtn:GetFontString()
		if rText then
			rText:SetFont(rText:GetFont(), 11)
			rText:SetPoint("CENTER", removeBtn, "CENTER", 0, -1)
		end

		local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("LEFT", removeBtn, "RIGHT", 6, 0)
		label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		label:SetJustifyH("LEFT")
		row.label  = label
		row.remove = removeBtn
		destroyContent.rows[i] = row
	end

	destroyScroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, AutoRoll.RenderDestroyList)
	end)

	-- ── Tab switching ────────────────────────────────────────────────────────
	local function ShowTab(tab)
		if tab == 1 then
			panelRoll:Show()
			panelDestroy:Hide()
		else
			panelRoll:Hide()
			panelDestroy:Show()
			AutoRoll.RenderDestroyList()
		end
	end

	tabAutoRoll:SetScript("OnClick", function() ShowTab(1) end)
	tabDestroy:SetScript("OnClick",  function() ShowTab(2) end)

	AutoRollOptionsFrame = f
	tinsert(UISpecialFrames, "AutoRollOptionsFrame")
end

function AutoRoll.UpdateAutorollScroll() end

function AutoRoll.ToggleOptions()
	CreateOptionsFrame()
	AutoRoll.RenderAutorollList()
	if AutoRollOptionsFrame:IsShown() then
		AutoRollOptionsFrame:Hide()
	else
		AutoRollOptionsFrame:Show()
	end
end

function AutoRoll.ApplyOptionsFromUI()
	AutoRoll_Options.Enabled = AutoRollOptionsFrame_Enable:GetChecked() and true or false
end

local function DoHideRollFrame(rollId)
	for i = 1, (NUM_LOOT_ROLL_FRAMES or 4) do
		local frame = _G["GroupLootFrame" .. i]
		if frame and frame.rollID == rollId then
			frame:Hide()
		end
	end

	if LootRollFrame and LootRollFrame:IsShown() then
		LootRollFrame:Hide()
	end

	local E = ElvUI and ElvUI[1]
	local M = E and E.GetModule and E:GetModule('Misc')
	if M and M.RollBars then
		for _, frame in ipairs(M.RollBars) do
			if frame.rollID == rollId then
				frame.rollID = nil
				frame.time = nil
				frame:Hide()
				frame:ClearAllPoints()
			end
		end

		local prev = nil
		for _, frame in ipairs(M.RollBars) do
			if frame.rollID then
				frame:ClearAllPoints()
				if prev then
					frame:SetPoint("TOP", prev, "BOTTOM", 0, -4)
				else
					frame:SetPoint("TOP", AlertFrameHolder, "BOTTOM", 0, -4)
				end
				prev = frame
			end
		end
	else
		local visited = {}
		local function scan(parent, depth)
			if depth > 8 then return end
			local ok, children = pcall(function() return {parent:GetChildren()} end)
			if not ok then return end
			for _, child in ipairs(children) do
				if not visited[child] then
					visited[child] = true
					if child.rollID == rollId or child.rollid == rollId then
						child:Hide()
						child:ClearAllPoints()
					end
					scan(child, depth + 1)
				end
			end
		end
		scan(UIParent, 0)
	end
end

local _hideQueue = {}
local _hidePump = CreateFrame("Frame")
_hidePump:Hide()
_hidePump:SetScript("OnUpdate", function(self)
	for rollId in pairs(_hideQueue) do
		DoHideRollFrame(rollId)
		_hideQueue[rollId] = nil
	end
	self:Hide()
end)

local function HideRollFrame(rollId)
	_hideQueue[rollId] = true
	_hidePump:Show()
end

local function HookRollFrameButtons(rollId, itemName, itemQuality, canDisenchant)
	if not itemName then return end

	local frames = {}

	for i = 1, (NUM_LOOT_ROLL_FRAMES or 4) do
		local f = _G["GroupLootFrame" .. i]
		if f and f.rollID == rollId then
			table.insert(frames, f)
		end
	end

	local visited = {}
	local function scan(parent, depth)
		if depth > 8 then return end
		local ok, children = pcall(function() return {parent:GetChildren()} end)
		if not ok then return end
		for _, child in ipairs(children) do
			if not visited[child] then
				visited[child] = true
				if child.rollID == rollId then
					table.insert(frames, child)
				end
				scan(child, depth + 1)
			end
		end
	end
	scan(UIParent, 0)


	for _, frame in ipairs(frames) do
		frame._arData = {
			rollId       = rollId,
			name         = itemName,
			quality      = itemQuality,
			canDisenchant = canDisenchant,
		}
	end

	local rollTypeMap = {
		[AutoRoll.Roll.Need]        = { label = "Always Need on this",        fn = function(d) AutoRoll.RollNeed(d.name, d.rollId, d.quality) end },
		[AutoRoll.Roll.Greed]       = { label = "Always Greed on this",       fn = function(d) AutoRoll.RollGreed(d.name, d.rollId, d.quality) end },
		[AutoRoll.Roll.Disenchant]  = { label = "Always Disenchant on this",  fn = function(d) AutoRoll.RollDisenchant(d.name, d.rollId, d.quality, d.canDisenchant) end },
		[AutoRoll.Roll.Pass]        = { label = "Always Pass on this",        fn = function(d) AutoRoll.Pass(d.name, d.rollId, d.quality) end },
	}

	local function GetFrameData(btn)
		local f = btn:GetParent()
		while f do
			if f._arData then return f._arData end
			f = f:GetParent()
		end
	end

	local function HookButton(btn, hookRoll)
		if not btn or not hookRoll then return end
		local info = rollTypeMap[hookRoll]
		if not info then return end

		if not btn._autoRollHooked then
			btn._autoRollHooked = true

			local origOnEnter = btn:GetScript("OnEnter")
			btn:SetScript("OnEnter", function(self)
				if origOnEnter then origOnEnter(self) end
				if GameTooltip:IsShown() then
					GameTooltip:AddLine("Right-click: " .. info.label, 0.7, 0.7, 0.7)
					GameTooltip:Show()
				else
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:SetText("Right-click: " .. info.label, 0.7, 0.7, 0.7)
					GameTooltip:Show()
				end
			end)

			btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			local origOnClick = btn:GetScript("OnClick")
			btn:SetScript("OnClick", function(self, button)
				if button == "RightButton" then
					local data = GetFrameData(self)
					if data then
						info.fn(data)
						HideRollFrame(data.rollId)
					end
				elseif origOnClick then
					origOnClick(self, button)
				end
			end)
		end
	end

	local blizzButtonRolls = {
		["NeedButton"]       = AutoRoll.Roll.Need,
		["GreedButton"]      = AutoRoll.Roll.Greed,
		["DisenchantButton"] = AutoRoll.Roll.Disenchant,
		["PassButton"]       = AutoRoll.Roll.Pass,
	}

	for _, frame in ipairs(frames) do
		for btnName, roll in pairs(blizzButtonRolls) do
			local btn = _G[frame:GetName() and (frame:GetName() .. btnName) or ""] or frame[btnName]
			HookButton(btn, roll)
		end

		for _, child in ipairs({frame:GetChildren()}) do
			if child.rollType ~= nil then HookButton(child, child.rollType) end
			local ok, grandchildren = pcall(function() return {child:GetChildren()} end)
			if ok then
				for _, gc in ipairs(grandchildren) do
					if gc.rollType ~= nil then HookButton(gc, gc.rollType) end
				end
			end
		end
	end
end

local _hookQueue = {}
local _hookPump = CreateFrame("Frame")
_hookPump:Hide()
_hookPump:SetScript("OnUpdate", function(self)
	for rollId, info in pairs(_hookQueue) do
		HookRollFrameButtons(rollId, info.name, info.quality, info.canDisenchant)
		_hookQueue[rollId] = nil
	end
	self:Hide()
end)

function AutoRoll.HandleDestroyLoot()
	local numItems = GetNumLootItems()
	for i = 1, numItems do
		local _, name = GetLootSlotInfo(i)
		if name and AutoRoll_Destroy[name] then
			LootSlot(i)
		end
	end
end

function AutoRoll.ProcessDestroyQueue()
	for bag = 0, 4 do
		local slots = GetContainerNumSlots(bag)
		for slot = 1, slots do
			local id = GetContainerItemID(bag, slot)
			if id then
				local itemName = GetItemInfo(id)
				if itemName and AutoRoll_Destroy[itemName] then
					PickupContainerItem(bag, slot)
					if CursorHasItem() then
						DeleteCursorItem()
					end
				end
			end
		end
	end
end

function AutoRoll.OnLoad(self)
	SLASH_AUTOROLL1 = "/aroll"
	SlashCmdList["AUTOROLL"] = function()
		AutoRoll.ToggleOptions()
	end

	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("START_LOOT_ROLL")
	self:RegisterEvent("CANCEL_LOOT_ROLL")
	self:RegisterEvent("CONFIRM_LOOT_ROLL")
end

function AutoRoll.OnEvent(self, event, arg1, arg2)
	if event == "LOOT_OPENED" then
		if AutoRoll_Options.AutoDestroy then
			AutoRoll.HandleDestroyLoot()
		end
		return
	end

	if event == "BAG_UPDATE" then
		if AutoRoll_Options.AutoDestroy then
			AutoRoll.ProcessDestroyQueue()
		end
		return
	end

	if event == "ADDON_LOADED" and arg1 == "AutoRoll" then
		AutoRoll.EnsureOptions()
		AutoRoll.Initialize()
		return
	end

	if event == "START_LOOT_ROLL" then
		if not AutoRoll_Options.Enabled then return end
		local rollId = arg1
		local timeout = arg2 or 0
		local texture, name, count, quality, bindOnPickup, canNeed, canGreed, canDisenchant = GetLootRollItemInfo(rollId)

		local autoRolledByQuality = false
		if AutoRoll_Options.AutoGreedGreens then
			local playerLevel = UnitLevel("player") or 0
			local minLevel = AutoRoll_Options.AutoGreedGreensMinLevel or 60
			local quals = AutoRoll_Options.AutoGreedQualities or "green"
			local qualMatch = (quality == 2) or (quals == "greenblue" and quality == 3)
			if qualMatch and playerLevel >= minLevel then
				if not (name and AutoRoll_Autoroll[name]) then
					local rollChoice = AutoRoll_Options.AutoGreedRoll or "disenchant"
					local effectiveRoll
					if rollChoice == "greed" then
						effectiveRoll = AutoRoll.Roll.Greed
					elseif rollChoice == "pass" then
						effectiveRoll = AutoRoll.Roll.Pass
					else
							effectiveRoll = canDisenchant and AutoRoll.Roll.Disenchant or AutoRoll.Roll.Greed
					end
					RollOnLoot(rollId, effectiveRoll)
					HideRollFrame(rollId)
					autoRolledByQuality = true
				end
			end
		end

		if not autoRolledByQuality then
			if AutoRoll_Options.AutoLoot and name and AutoRoll_Autoroll[name] then
				local savedRoll = AutoRoll_Autoroll[name].roll
				local effectiveRoll = savedRoll
				if savedRoll == AutoRoll.Roll.Disenchant and not canDisenchant then
					effectiveRoll = AutoRoll.Roll.Greed
				end
				RollOnLoot(rollId, effectiveRoll)
				HideRollFrame(rollId)
			else
				AutoRoll.QueueLoot(rollId, timeout, texture, name, quality, canDisenchant)
					_hookQueue[rollId] = { name = name, quality = quality, canDisenchant = canDisenchant }
				_hookPump:Show()
			end
		end
		return
	end

	if event == "CANCEL_LOOT_ROLL" then
		AutoRoll.ClearLoot(arg1)
		return
	end

	if event == "CONFIRM_LOOT_ROLL" then
		if AutoRoll_Options.AutoConfirm then
			ConfirmLootRoll(arg1, arg2)
			StaticPopup_Hide("CONFIRM_LOOT_ROLL")
		end
		return
	end
end

function AutoRoll.Initialize()
	AutoRoll.CreateMinimapButton()
	AutoRoll.UpdateMinimapButtonPosition()
	SL_Print("loaded. Use /aroll to open options.")
end

function AutoRoll.CreateMinimapButton()
	if AutoRoll.MinimapButton then return end

	local b = CreateFrame("Button", "AutoRollMinimapButton", UIParent)
	b:SetWidth(22)
	b:SetHeight(22)
	b:SetFrameStrata("LOW")
	b:EnableMouse(true)
	b:SetMovable(true)
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("RightButton")

	local icon = b:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints(b)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetVertexColor(1, 1, 1, 1)
	b.icon = icon
	b:SetFrameLevel(Minimap:GetFrameLevel() + 3)

	b:SetScript("OnClick", function(_, button)
		if button == "LeftButton" then
			AutoRoll.ToggleOptions()
		end
	end)

	b:SetScript("OnDragStart", function()
		if IsShiftKeyDown() then
			b:StartMoving()
		end
	end)

	b:SetScript("OnDragStop", function()
		b:StopMovingOrSizing()

		local centerX, centerY = Minimap:GetCenter()
		local buttonX, buttonY = b:GetCenter()
		local dx = buttonX - centerX
		local dy = buttonY - centerY

		AutoRoll_Options.MinimapButtonPosition = math.deg(math.atan2(dy, dx))
		AutoRoll_Options.MinimapButtonRadius = math.sqrt(dx * dx + dy * dy)
		AutoRoll.UpdateMinimapButtonPosition()
	end)

	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("AutoRoll")
		GameTooltip:AddLine("Left click to open options", 1, 1, 1)
		GameTooltip:AddLine("Shift + right drag to move", 1, 1, 1)
		GameTooltip:Show()
	end)

	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	b:Hide()
	AutoRoll.MinimapButton = b
end

function AutoRoll.UpdateMinimapButtonPosition()
	if not AutoRoll.MinimapButton then return end

	if AutoRoll_Options.ShowMinimapButton then
		local angle = AutoRoll_Options.MinimapButtonPosition or 281
		local radius = AutoRoll_Options.MinimapButtonRadius or 80
		local rad = math.rad(angle)
		local x = math.cos(rad) * radius
		local y = math.sin(rad) * radius
		AutoRoll.MinimapButton:Show()
		AutoRoll.MinimapButton:ClearAllPoints()
		AutoRoll.MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
	else
		AutoRoll.MinimapButton:Hide()
	end
end

function AutoRoll.ApplyAutoRoll(itemName, roll)
	for i, loot in ipairs(AutoRoll.Queue) do
		if loot.name == itemName then
			RollOnLoot(loot.rollId, roll)
		end
	end
end

function AutoRoll.RollDisenchant(name, rollId, quality, canDisenchant)
	if name and rollId then
		AutoRoll_Autoroll[name] = { quality = quality or 0, roll = AutoRoll.Roll.Disenchant }
		InvalidateListCache()
		AutoRoll.RenderAutorollList()
		local effectiveRoll = canDisenchant and AutoRoll.Roll.Disenchant or AutoRoll.Roll.Greed
		RollOnLoot(rollId, effectiveRoll)
	end
end

function AutoRoll.QueueLoot(rollId, timeout, texture, name, quality, canDisenchant)
	table.insert(AutoRoll.Queue, {
		rollId = rollId, timeout = timeout, texture = texture,
		name = name, quality = quality,
		canDisenchant = canDisenchant and true or false,
	})
end

function AutoRoll.ClearLoot(rollId)
	for i, loot in ipairs(AutoRoll.Queue) do
		if loot.rollId == rollId then
			table.remove(AutoRoll.Queue, i)
			break
		end
	end
end

function AutoRoll.RollNeed(name, rollId, quality)
	if name and rollId then
		AutoRoll_Autoroll[name] = { quality = quality or 0, roll = AutoRoll.Roll.Need }
		InvalidateListCache()
		AutoRoll.RenderAutorollList()
		RollOnLoot(rollId, AutoRoll.Roll.Need)
	end
end

function AutoRoll.RollGreed(name, rollId, quality)
	if name and rollId then
		AutoRoll_Autoroll[name] = { quality = quality or 0, roll = AutoRoll.Roll.Greed }
		InvalidateListCache()
		AutoRoll.RenderAutorollList()
		RollOnLoot(rollId, AutoRoll.Roll.Greed)
	end
end

function AutoRoll.Pass(name, rollId, quality)
	if name and rollId then
		AutoRoll_Autoroll[name] = { quality = quality or 0, roll = AutoRoll.Roll.Pass }
		InvalidateListCache()
		AutoRoll.RenderAutorollList()
		RollOnLoot(rollId, AutoRoll.Roll.Pass)
	end
end


function AutoRoll.GetAutorollListData()
	if _listCache then return _listCache end
	local result = {}
	for name, info in pairs(AutoRoll_Autoroll) do
		table.insert(result, {
			name      = name,
			nameLower = name:lower(),
			quality   = info.quality or 0,
			roll      = info.roll or AutoRoll.Roll.Greed,
		})
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	_listCache = result
	return result
end

function AutoRoll.RollName(roll)
	if roll == AutoRoll.Roll.Need then
		return "Need"
	elseif roll == AutoRoll.Roll.Greed then
		return "Greed"
	elseif roll == AutoRoll.Roll.Pass then
		return "Pass"
	elseif roll == AutoRoll.Roll.Disenchant then
		return "Disenchant"
	end
	return "?"
end

function AutoRoll.AutorollListRemove(name)
	AutoRoll_Autoroll[name] = nil
	InvalidateListCache()
	AutoRoll.RenderAutorollList()
end

function AutoRoll.RenderAutorollList()
	if not AutoRollOptionsFrame then return end
	local content     = AutoRollOptionsFrame_AutorollScrollContent
	local scrollFrame = AutoRollOptionsFrame_AutorollScroll
	if not content or not scrollFrame then return end

	local data = AutoRoll.GetAutorollListData()

	-- Apply search filter: pre-lowercase the filter once, not per-item
	if AutoRoll.searchFilter then
		local f = AutoRoll.searchFilter  -- already lowercased when set
		local filtered = {}
		for _, info in ipairs(data) do
			if info.nameLower:find(f, 1, true) then
				table.insert(filtered, info)
			end
		end
		data = filtered
	end

	local ROW_HEIGHT = 20
	local ROW_COUNT  = #content.rows
	FauxScrollFrame_Update(scrollFrame, #data, ROW_COUNT, ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(scrollFrame)

	-- Cache roll name lookups to avoid repeated comparisons
	local rollNames = {
		[AutoRoll.Roll.Need]        = "Need",
		[AutoRoll.Roll.Greed]       = "Greed",
		[AutoRoll.Roll.Disenchant]  = "Disenchant",
		[AutoRoll.Roll.Pass]        = "Pass",
	}

	for i = 1, ROW_COUNT do
		local row  = content.rows[i]
		local info = data[i + offset]
		if info then
			row.itemName = info.name
			local c = ITEM_QUALITY_COLORS[info.quality]
			row.text:SetText(info.name)
			row.text:SetTextColor(c.r, c.g, c.b)
			row.dropdown:SetText(rollNames[info.roll] or "Greed")
			row:Show()
		else
			row:Hide()
		end
	end
end

function AutoRoll.RenderDestroyList()
	local content     = AutoRollOptionsFrame_DestroyScrollContent
	local scrollFrame = AutoRollOptionsFrame_DestroyScroll
	if not content or not scrollFrame then return end

	local data = {}
	for name in pairs(AutoRoll_Destroy) do table.insert(data, name) end
	table.sort(data)

	local ROW_HEIGHT = 20
	local ROW_COUNT  = #content.rows
	FauxScrollFrame_Update(scrollFrame, #data, ROW_COUNT, ROW_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(scrollFrame)

	for i = 1, ROW_COUNT do
		local row  = content.rows[i]
		local name = data[i + offset]
		if name then
			row.itemName = name
			row.label:SetText(name)
			row:Show()
		else
			row:Hide()
		end
	end
end

function AutoRoll.SetAutorollRoll(name, roll)
	if not AutoRoll_Autoroll[name] then return end
	AutoRoll_Autoroll[name].roll = roll
	InvalidateListCache()
	AutoRoll.RenderAutorollList()
end

function AutoRoll.RollNameShort(roll)
	if roll == AutoRoll.Roll.Need then
		return "N"
	elseif roll == AutoRoll.Roll.Greed then
		return "G"
	elseif roll == AutoRoll.Roll.Pass then
		return "P"
	elseif roll == AutoRoll.Roll.Disenchant then
		return "D"
	end
	return "?"
end

local e = CreateFrame("Frame")
e:RegisterEvent("ADDON_LOADED")
e:RegisterEvent("START_LOOT_ROLL")
e:RegisterEvent("CANCEL_LOOT_ROLL")
e:RegisterEvent("CONFIRM_LOOT_ROLL")
e:SetScript("OnEvent", AutoRoll.OnEvent)
AutoRoll.OnLoad(e)
