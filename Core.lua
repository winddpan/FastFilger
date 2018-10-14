local _, ns = ...

FastFilgerDB = FastFilgerDB or {}
local class = select(2, UnitClass("player"))
local debugPrint = false
local Filger = ns.Filger
local Misc = ns.Misc
local SpellGroups = {}

local LogEvents = {SPELL_AURA_REMOVED = true,
				   SPELL_AURA_APPLIED = true, 
				   SPELL_AURA_APPLIED_DOSE = true,
				   SPELL_AURA_REFRESH = true,
				   SPELL_PERIODIC_DAMAGE = false}

function Filger:OnEvent(event, unit)	
	if event == "SPELL_UPDATE_COOLDOWN" then
		for id, data in pairs(SpellGroups[self.Id].spells) do
			if data.filter == "CD" then
				local name, icon, count, duration, expirationTime, start, spid
				if data.spellID then
					name, _, icon = GetSpellInfo(data.spellID)
					if name then
						if data.absID then
							start, duration = GetSpellCooldown(data.spellID)
						else
							start, duration = GetSpellCooldown(name)
						end
						spid = data.spellID
					end
				elseif data.slotID then
					spid = data.slotID
					local slotLink = GetInventoryItemLink("player", data.slotID)
					if slotLink then
						name, _, _, _, _, _, _, _, _, icon = GetItemInfo(slotLink)
						start, duration = GetInventoryItemCooldown("player", data.slotID)
					end
				end
				if spid then
					if (duration or 0) > 1.5 then
						self.actives[spid] = {data = data, name = name, icon = icon, count = count, start = start, duration = duration, spid = spid, sort = data.sort}
						Filger.DisplayActives(self)
					end
				end
			end
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2 = CombatLogGetCurrentEventInfo()
		if LogEvents[eventType] then
			local target = GUIDRole(dstGUID)
			local caster = GUIDRole(srcGUID)
			if target then
				local spellId, spellName, spellSchool, auraType = select(12, CombatLogGetCurrentEventInfo())
				local data = SpellGroups[self.Id].spells[spellId]

				if data and (data.caster == nil or caster == data.caster or data.caster == "all") then
					local name, icon, count, duration, expirationTime, start, spid
					if data.filter == "BUFF" or data.filter == "DEBUFF" then
						if eventType ~= "SPELL_AURA_REMOVED" then
							local filter
							if data.filter == "BUFF" then
								filter = "HELPFUL"
							else 
								filter = "HARMFUL"
							end
							name, icon, count, _, duration, expirationTime, caster, _, _, spid = Filger:UnitAura(target, spellId, spellName, filter)
							if spid then
								self.actives[spid] = {data = data, name = name, icon = icon, count = count, start = expirationTime - duration, duration = duration, spid = spid, sort = data.sort}
							end
						else
							self.actives[spellId] = nil
						end
						Filger.DisplayActives(self)
					end
				end
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
		for spid, value in pairs(self.actives) do
			self.actives[spid] = nil
		end
		Filger.ResetGroup(self, SpellGroups[self.Id].spells)
	end
end

function Init()
	local Filger_Spells = ns.Filger_Spells
	
	if Filger_Spells and Filger_Spells["ALL"] then
		if not Filger_Spells[class] then
			Filger_Spells[class] = {}
		end

		for i = 1, #Filger_Spells["ALL"], 1 do
			local merge = false
			local spellListAll = Filger_Spells["ALL"][i]
			local spellListClass = nil
			for j = 1, #Filger_Spells[class], 1 do
				spellListClass = Filger_Spells[class][j]
				local mergeAll = spellListAll.Merge or false
				local mergeClass = spellListClass.Merge or false
				if spellListClass.Name == spellListAll.Name and (mergeAll or mergeClass) then
					merge = true
					break
				end
			end
			if not merge or not spellListClass then
				table.insert(Filger_Spells[class], Filger_Spells["ALL"][i])
			else
				for j = 1, #spellListAll, 1 do
					table.insert(spellListClass, spellListAll[j])
				end
			end
		end
	end


	if Filger_Spells and Filger_Spells[class] then
		for index in pairs(Filger_Spells) do
			if index ~= class then
				Filger_Spells[index] = nil
			end
		end

		for i = 1, #Filger_Spells[class], 1 do
			local group = { spells = {}}
			local jdx = {}
			local data = Filger_Spells[class][i]

			for j = 1, #data, 1 do
				local spn
				local id
				if data[j].spellID then
					spn = GetSpellInfo(data[j].spellID)
				else
					local slotLink = GetInventoryItemLink("player", data[j].slotID)
					if slotLink then
						spn = GetItemInfo(slotLink)
					end
				end
				if spn then
					local id = data[j].spellID or data[j].slotID
					data[j].sort = j
					group.spells[id] = data[j]
				else
					if debugPrint then
						print("|cffff0000WARNING: spell/slot ID ["..(data[j].spellID or data[j].slotID or "UNKNOWN").."] no longer exists! Report this to Shestak.|r")
					end
				end
				table.insert(jdx, j)
			end
			
			for _, v in ipairs(jdx) do
				table.remove(data, v)
			end

			group.data = data
			table.insert(SpellGroups, i, group)
		end


		for i = 1, #SpellGroups, 1 do
			local data = SpellGroups[i].data

			local movebar = CreateFrame("Frame", "FFilgerFrame"..i.."_"..data.Name.."Movebar", UIParent)
			movebar:Hide()
			movebar:SetFrameLevel(10)
			movebar:EnableMouse(true)
			movebar:SetMovable(true)
			movebar:RegisterForDrag("LeftButton")
			movebar:SetScript("OnDragStart", function(self) self:StartMoving() end)
			movebar:SetScript("OnDragStop", function(self)
				self:StopMovingOrSizing()
				local AnchorF, _, AnchorT, ax, ay = self:GetPoint()
				FastFilgerDB[data.Name] = {AnchorF, "UIParent", AnchorT, ax, ay}
			end)
			movebar:SetBackdrop({  bgFile = "Interface\\Buttons\\WHITE8x8" , })
			movebar:SetBackdropColor(0, 1, 0, 0.5)
			movebar:SetSize(data.IconSize or 37, data.IconSize or 37)
			movebar.Position = data.Position or "CENTER"
			
			if FastFilgerDB[data.Name] ~= nil then
				movebar:SetPoint(unpack(FastFilgerDB[data.Name]))
			else
				movebar:SetPoint(unpack(data.Position))
			end
			
			movebar.text = movebar:CreateFontString(nil, "OVERLAY")
			movebar.text:SetFont(STANDARD_TEXT_FONT, 12, "THINOUTLINE")
			movebar.text:SetPoint("CENTER")
			movebar.text:SetText(data.Name)
			
			local frame = CreateFrame("Frame", "FFilgerFrame"..i.."_"..data.Name, UIParent)
			frame.Id = i
			frame.Name = data.Name
			frame.Direction = data.Direction or "DOWN"
			frame.IconSide = data.IconSide or "LEFT"
			frame.NumPerLine = data.NumPerLine
			frame.Mode = data.Mode or "ICON"
			frame.enable = data.enable or "ON"
			frame.Interval = data.Interval * Misc.mult or 3 * Misc.mult
			frame:SetAlpha(data.Alpha or 1)
			frame.IconSize = data.IconSize or 37
			frame.BarWidth = data.BarWidth or 186
			frame.Position = data.Position or "CENTER"
			frame.actives = {}

			for _, data in pairs(SpellGroups[i].spells) do
				if data.filter == "CD" then
					frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
					break
				end
			end
			frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
			frame:RegisterEvent("PLAYER_TARGET_CHANGED")
			frame:RegisterEvent("PLAYER_ENTERING_WORLD")
			frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			frame:SetScript("OnEvent", Filger.OnEvent)
			frame.movebar = movebar
		end
	end
end

SlashCmdList["FastFilgerTest"] = function(msg)
	if msg:lower() == "" then
		print("|c0000FF00/ff test  锁定/解锁|r")
		print("|c0000FF00/ff reset   位置重置 |r")
	elseif msg:lower() == "test" then
		if UnitAffectingCombat("player") then print("正在战斗状态！") return end
		testMode = not testMode
		for i = 1, #SpellGroups, 1 do	
			local data = SpellGroups[i].data
			local frame = _G["FFilgerFrame"..i.."_"..data.Name]
			frame.actives = {}
			if testMode then
				local idx = 0
				for id, data in pairs(SpellGroups[i].spells) do
					local name, icon
					if data.spellID then
						name, _, icon = GetSpellInfo(data.spellID)
					elseif data.slotID then
						local slotLink = GetInventoryItemLink("player", data.slotID)
						if slotLink then
							name, _, _, _, _, _, _, _, _, icon = GetItemInfo(slotLink)
						end
					end
					frame.actives[id] = {data = data, name = name, icon = icon, count = 9, start = 0, duration = 0, spid = id, sort = data.sort}
					
					idx = idx + 1
					if idx >= Misc.maxTestIcon then
						break
					end
				end
			end
			
			if testMode then
				frame:SetScript("OnEvent", nil)
				frame.movebar:Show()
			else
				frame:SetScript("OnEvent", Filger.OnEvent)
				frame.movebar:Hide()
			end
			Filger.DisplayActives(frame)
		end
	elseif msg:lower() == "reset" then
		wipe(FastFilgerDB)
		for i = 1, #SpellGroups, 1 do
			local data = SpellGroups[i].data
			local frame = _G["FFilgerFrame"..i.."_"..data.Name]
			frame.movebar:ClearAllPoints()
			frame.movebar:SetPoint(unpack(data.Position))
		end
	end
end
SLASH_FastFilgerTest1 = "/ff"

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	SpellActivationOverlayFrame:SetFrameStrata("BACKGROUND")
	Init() 
	f:UnregisterEvent("PLAYER_ENTERING_WORLD") 
end)