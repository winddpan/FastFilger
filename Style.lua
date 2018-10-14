local _, ns = ...

local mult = 1
local raidColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
local barColor = {raidColor.r, raidColor.g, raidColor.b}
local buffBorderColor = {49/255, 213/255, 78/255}
local debuffBorderColor = {249/255, 51/255, 26/255}
local Media = "Interface\\AddOns\\ShestakUI_Filger\\Media\\"
local font = Media.."number.ttf"
local barfg = Media.."White"
local back = Media.."HalBackground"
local border = Media.."GlowTex"
local barbg = Media.."Texture"

local function SetBackdrop(parent)
	local F = CreateFrame("Frame", nil, parent)
	F:SetFrameLevel(4)
	F:SetPoint("TOPLEFT", -1 * mult, 1 * mult)
	F:SetPoint("BOTTOMRIGHT", 1 * mult, -1 * mult)
	F:SetBackdrop({
		bgFile = back, 
		edgeFile = border, 
		insets = {left = 1 * mult, right = 1 * mult, top = 1 * mult, bottom = 1 * mult},
		tile = false, tileSize = 0, 
		edgeSize = 3 * mult,
	})
	F:SetBackdropColor(0, 0, 0, 0)
	F:SetBackdropBorderColor(0, 0, 0, .75)
	
	F.Border = CreateFrame("Frame", nil, F)
    F.Border:SetPoint("TOPLEFT", 3, -3)
    F.Border:SetPoint("BOTTOMRIGHT", -3, 3)
    F.Border:SetBackdrop({ 
		edgeFile = "Interface\\Buttons\\WHITE8x8" , edgeSize = 1,
	})
	F.Border:SetBackdropColor(0, 0, 0, 0.2)
	F.Border:SetBackdropBorderColor(0, 0, 0, 1)
    F.Border:SetFrameLevel(5)
	parent.Border = F.Border
	
	return F
end

function SetTemplate(group, bar)
	if bar.cfg then return end
	if bar.statusbar then
		bar.statusbar:SetStatusBarTexture(barfg)			-- bar_FG
		bar.statusbar:SetStatusBarColor(unpack(barColor))
	end
	if bar.bg then
		SetBackdrop(bar.bg)
	end
	if bar.background then
		bar.background:SetTexture(barbg)		-- bar_BG
	end
	SetBackdrop(bar)
	bar.cfg = true
end

function UpdateBarStyle(f, bar, value)
	if bar.Border ~= nil then
		if value.data.filter == "DEBUFF" then
			bar.Border:SetBackdropBorderColor(unpack(debuffBorderColor))
		else
			bar.Border:SetBackdropBorderColor(unpack(buffBorderColor))
		end
	end
end