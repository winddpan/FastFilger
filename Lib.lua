local addon, ns = ...
local Filger = {}
local Filger_Spells = Filger_Spells or {}
local MyUnits = {player = true, vehicle = true, pet = true}
local class = select(2, UnitClass("player"))

local Misc = CreateFrame("Frame")
Misc.font = "Interface\\Addons\\"..addon.."\\Media\\".."number.ttf"
Misc.numSize = 14                   -- 层数, 计时条的计时数字大小
Misc.barNumSize = 12                -- 计时条的计时数字大小
Misc.barNameSize = 12               -- 计时条法术名称字体大小
Misc.maxTestIcon = 8                -- 测试模式下,每项显示最大图标数量
Misc.mult = 1 

function Filger:SetTemplate(bar)
    SetTemplate(self, bar)
end

function Filger:UpdateBarStyle(bar, value)
    UpdateBarStyle(self, bar, value)
end

function GUIDRoles(uid)
    if uid == nil then
        return nil
    end
    local contians = false
    local result = {}
    if UnitGUID("target") == uid then
        result["target"] = true
        contians = true
    end
    if UnitGUID("focus") == uid then
        result["focus"] = true
        contians = true
    end
    if UnitGUID("player") == uid then
        result["player"] = true
        contians = true
    end
    if contians then
        return result
    end
    return nil
end

function Filger:UnitAura(unitID, inSpellID, spell, filter, absID)
    if absID then
        for i = 1, 40 do
            local name, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitAura(unitID, i, filter)
            if not name then break end
            if spellID == inSpellID then
                return name, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID
            end
        end
    else
        local name, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID = AuraUtil.FindAuraByName(spell, unitID, filter)
        if name then
            return name, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID
        end
    end
    return nil
end

function Filger:UpdateCD()
    local time = self.value.start + self.value.duration - GetTime()

    if self:GetParent().Mode == "BAR" then
        self.statusbar:SetValue(time)
        if time <= 60 then
            self.time:SetFormattedText("%.1f", time)
        else
            self.time:SetFormattedText("%d:%.2d", time / 60, time % 60)
        end
    end
    if time < 0 then
        local frame = self:GetParent()
        frame.actives[self.value.spid] = nil
        self:SetScript("OnUpdate", nil)
        Filger.DisplayActives(frame)
    end
end

function Filger:DisplayActives()
    if not self.actives then return end
    if not self.bars then self.bars = {} end
    local id = self.Id
    local index = 1
    local previous = nil

    for _, b in pairs(self.actives) do
        local bar = self.bars[index]
        if not bar then
            bar = CreateFrame("Frame", "FilgerAnchor"..id.."Frame"..index, self)
            bar:SetScale(1)
            bar:SetFrameStrata("Medium")

            if index == 1 then
                bar:SetAllPoints(self.movebar)
            ----- The next line ----
            elseif self.NumPerLine and index % self.NumPerLine == 1 then
                previous = self.bars[index - self.NumPerLine]
                if self.Direction == "RIGHT" or self.Direction == "LEFT" then
                    bar:SetPoint("TOP", previous, "BOTTOM", 0, -self.Interval)
                else
                    bar:SetPoint("LEFT", previous, "RIGHT", self.Interval, 0)
                end
            ---------------------------------------
            else
                if self.Direction == "UP" then
                    bar:SetPoint("BOTTOM", previous, "TOP", 0, self.Interval)
                elseif self.Direction == "RIGHT" then
                    bar:SetPoint("LEFT", previous, "RIGHT", self.Mode == "ICON" and self.Interval or (self.BarWidth + self.Interval + 7), 0)
                elseif self.Direction == "LEFT" then
                    bar:SetPoint("RIGHT", previous, "LEFT", self.Mode == "ICON" and -self.Interval or -(self.BarWidth + self.Interval + 7), 0)
                else
                    bar:SetPoint("TOP", previous, "BOTTOM", 0, -self.Interval)
                end
            end

            if bar.icon then
                bar.icon = _G[bar.icon:GetName()]
            else
                bar.icon = bar:CreateTexture("$parentIcon", "BORDER")
                bar.icon:SetPoint("TOPLEFT", 2 * Misc.mult, -2 * Misc.mult)
                bar.icon:SetPoint("BOTTOMRIGHT", -2 * Misc.mult, 2 * Misc.mult)
                bar.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            end

            if self.Mode == "ICON" then
                if bar.cooldown then
                    bar.cooldown = _G[bar.cooldown:GetName()]
                else
                    bar.cooldown = CreateFrame("Cooldown", "$parentCD", bar, "CooldownFrameTemplate")
                    bar.cooldown:SetAllPoints(bar.icon)
                    bar.cooldown:SetReverse()
                    bar.cooldown:SetFrameLevel(2)
                end

                if bar.count then
                    bar.count = _G[bar.count:GetName()]
                else
                    bar.count = bar:CreateFontString("$parentCount", "OVERLAY")
                    bar.count:SetFont(Misc.font, Misc.numSize, "THINOUTLINE")
                    bar.count:SetShadowOffset(1 * Misc.mult, -1 * Misc.mult)
                    bar.count:SetPoint("BOTTOMRIGHT", 0, 2)
                    bar.count:SetJustifyH("CENTER")
                end
            else
                local barHeight = floor(self.IconSize *0.33)
                if bar.statusbar then
                    bar.statusbar = _G[bar.statusbar:GetName()]
                else
                    bar.statusbar = CreateFrame("StatusBar", "$parentStatusBar", bar)
                    bar.statusbar:SetWidth(self.BarWidth * Misc.mult)
                    bar.statusbar:SetHeight(barHeight * Misc.mult)
                    if self.IconSide == "LEFT" then
                        bar.statusbar:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 3 * Misc.mult, 3 * Misc.mult)
                    elseif self.IconSide == "RIGHT" then
                        bar.statusbar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -3 * Misc.mult, 3 * Misc.mult)
                    end
                end
                bar.statusbar:SetMinMaxValues(0, 1)
                bar.statusbar:SetValue(0)

                if bar.bg then
                    bar.bg = _G[bar.bg:GetName()]
                else
                    bar.bg = CreateFrame("Frame", "$parentBG", bar.statusbar)
                    bar.bg:SetPoint("TOPLEFT", -3 * Misc.mult, 3 * Misc.mult)
                    bar.bg:SetPoint("BOTTOMRIGHT", 3 * Misc.mult, -3 * Misc.mult)
                    bar.bg:SetFrameStrata("BACKGROUND")
                end

                if bar.background then
                    bar.background = _G[bar.background:GetName()]
                else
                    bar.background = bar.statusbar:CreateTexture(nil, "BACKGROUND")
                    bar.background:SetAllPoints()
                    bar.background:SetVertexColor(0, 0, 0, .4)
                end

                if bar.time then
                    bar.time = _G[bar.time:GetName()]
                else
                    bar.time = bar.statusbar:CreateFontString("$parentTime", "OVERLAY")
                    bar.time:SetFont(Misc.font, Misc.barNumSize, "OUTLINE")
                    bar.time:SetShadowOffset(1 * Misc.mult, -1 * Misc.mult)
                    bar.time:SetPoint("BOTTOMRIGHT", bar.statusbar, 0, barHeight-1)
                    bar.time:SetJustifyH("RIGHT")
                end

                if bar.count then
                    bar.count = _G[bar.count:GetName()]
                else
                    bar.count = bar:CreateFontString("$parentCount", "OVERLAY")
                    bar.count:SetFont(Misc.font, Misc.barNumSize, "THINOUTLINE")
                    bar.count:SetShadowOffset(1 * Misc.mult, -1 * Misc.mult)
                    bar.count:SetPoint("BOTTOMRIGHT", 1, 1)
                    bar.count:SetJustifyH("CENTER")
                end

                if bar.spellname then
                    bar.spellname = _G[bar.spellname:GetName()]
                else
                    bar.spellname = bar.statusbar:CreateFontString("$parentSpellName", "OVERLAY")
                    bar.spellname:SetFont(GameTooltipText:GetFont(), Misc.barNameSize, "OUTLINE")
                    bar.spellname:SetShadowOffset(1 * Misc.mult, -1 * Misc.mult)
                    bar.spellname:SetPoint("BOTTOMLEFT", bar.statusbar, 0, barHeight-1)
                    bar.spellname:SetPoint("RIGHT", bar.time, "LEFT")
                    bar.spellname:SetJustifyH("LEFT")
                end
            end
            bar.spellID = 0
            self.bars[index] = bar
        end
        
        Filger.SetTemplate(self, bar)

        previous = bar
        index = index + 1
    end

    local temp = {}
    for _, value in pairs(self.actives) do
        table.insert(temp, value)
    end
    
    local function comp(element1, elemnet2)
        return element1.sort <= elemnet2.sort
    end
    table.sort(temp, comp)

    index = 1
    for activeIndex, value in pairs(temp) do
        local bar = self.bars[index]
        bar.spellName = GetSpellInfo(value.spid)
        if self.Mode == "BAR" then
            bar.spellname:SetText(bar.spellName)
        end
        bar.icon:SetTexture(value.icon)
        if value.count and value.count > 1 then
            bar.count:SetText(value.count)
            bar.count:Show()
        else
            bar.count:Hide()
        end
        if value.duration and value.duration > 0 then
            if self.Mode == "ICON" then
                CooldownFrame_Set(bar.cooldown, value.start, value.duration, 1)
                if value.data.filter == "CD" or value.data.filter == "ICD" then
                    bar.value = value
                    bar:SetScript("OnUpdate", Filger.UpdateCD)
                else
                    bar:SetScript("OnUpdate", nil)
                end
                bar.cooldown:Show()
            else
                bar.statusbar:SetMinMaxValues(0, value.duration)
                bar.value = value
                bar:SetScript("OnUpdate", Filger.UpdateCD)
            end
        else
            if self.Mode == "ICON" then
                bar.cooldown:Hide()
            else
                bar.statusbar:SetMinMaxValues(0, 1)
                bar.statusbar:SetValue(1)
                bar.time:SetText("")
            end
            bar:SetScript("OnUpdate", nil)
        end
        bar.spellID = value.spid
        bar:SetWidth(self.IconSize or 37)
        bar:SetHeight(self.IconSize or 37)
        bar:SetAlpha(value.data.opacity or 1)
        if self.enable == "OFF" then
            bar:Hide()
        elseif self.enable == "ON" then
            bar:Show()
        else
            bar:Show()
        end
        Filger.UpdateBarStyle(self, bar, value)

        index = index + 1
    end

    for i = index, #self.bars, 1 do
        local bar = self.bars[i]
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
    end
end

function Filger:ResetGroup(spells)  
    local needUpdate = false
    for id, data in pairs(spells) do
        local found = false
        local name, icon, count, duration, start, spid
        spid = 0

        if data.filter == "BUFF" then
            local caster, spn, expirationTime
            spn, _, _ = GetSpellInfo(data.spellID)
            if spn then
                name, icon, count, _, duration, expirationTime, caster, _, _, spid = Filger:UnitAura(data.unitID, data.spellID, spn, "HELPFUL", data.absID)
                if name and (data.caster ~= 1 and (caster == data.caster or data.caster == "all") or MyUnits[caster]) then
                    start = expirationTime - duration
                    found = true
                end
            end
        elseif data.filter == "DEBUFF" then
            local caster, spn, expirationTime
            spn, _, _ = GetSpellInfo(data.spellID)
            if spn then
                name, icon, count, _, duration, expirationTime, caster, _, _, spid = Filger:UnitAura(data.unitID, data.spellID, spn, "HARMFUL", data.absID)
                if name and (data.caster ~= 1 and (caster == data.caster or data.caster == "all") or MyUnits[caster]) then
                    start = expirationTime - duration
                    found = true
                end
            end
        elseif data.filter == "CD" then
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
            if name and (duration or 0) > 1.5 then
                found = true
            end
        end

        if found then
            if not self.actives[spid] then
                self.actives[spid] = {data = data, name = name, icon = icon, count = count, start = start, duration = duration, spid = spid, sort = data.sort}
                needUpdate = true
            else
                if (self.actives[spid].count ~= count or self.actives[spid].start ~= start or self.actives[spid].duration ~= duration) then
                    self.actives[spid].count = count
                    self.actives[spid].start = start
                    self.actives[spid].duration = duration
                    needUpdate = true
                end
            end
        else
            if self.actives and self.actives[spid] then
                self.actives[spid] = nil
                needUpdate = true
            end
        end
    end

    if self.actives then
        Filger.DisplayActives(self)
    end
end

ns.Filger = Filger
ns.Misc = Misc