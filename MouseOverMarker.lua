local addonName, ns = ...

local L = setmetatable({}, {__index=function(t,i) return i end})

local function Print(...) print("|cFF33FF99"..addonName.."|r:", ...) end
local debugf = tekDebug and tekDebug:GetFrame(addonName)
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

local function IsMarkableUnit(unit)
	local creatureType = UnitCreatureType(unit)
	return UnitExists(unit) and (UnitCanAttack("player", unit) or UnitIsEnemy("player", unit)) and not UnitIsDead(unit) and  creatureType ~= "Critter" and creatureType ~= "Totem" and not UnitPlayerControlled(unit)  and not UnitIsPlayer(unit)
end

-- Table of GUIDs for marks assigned to mobs.
-- Used to know if a mark is still in use. If a mob's GUID is 
-- here, that mark won't be used.
local usedMarks = {}

local nextMark = 8
local function NextMarkIndex()
	local current = nextMark
	-- TODO: Is the next mark taken?
	if nextMark > 0 then nextMark = nextMark - 1 end
	return current
end

local function ScanRaid()
	local index
	for i=1,GetNumRaidMembers() do
		index = GetRaidTargetIndex("raid"..i)
		if index then usedMarks[index] = UnitGUID("raid"..i) end
	end
end

local function ScanParty()
	local index
	for i=1,GetNumPartyMembers() do
		index = GetRaidTargetIndex("party"..i)
		if index then usedMarks[index] = UnitGUID("raid"..i) end
	end
end

local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")

-- Minitimer to set player to raid target 0
local total = 0
local function FinalMarkReset(self, elapsed)
	total = total + elapsed
	if total >= 0.5 then
		f:SetScript("OnUpdate", nil)
		SetRaidTarget("player", 0)
		total = 0
	end
end

function f:ADDON_LOADED(event, addon)
	if addon ~= addonName then return end

	f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	f:RegisterEvent("RAID_TARGET_UPDATE")

	LibStub("tekKonfig-AboutPanel").new(nil, addonName) -- Make first arg nil if no parent config panel

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil
end

function f:UPDATE_MOUSEOVER_UNIT()
	local unit = "mouseover"

	-- We good to go?
	if not IsMarkableUnit(unit) then return end
	if not IsAltKeyDown() then return end

	-- Preserve previously set marks
	local currentRaidTargetIndex = GetRaidTargetIndex(unit)
	if currentRaidTargetIndex then return end

	-- Get the next mark
	local nextMark = NextMarkIndex()
	if nextMark==0 then return end -- no marks left

	-- Mark em up!
	usedMarks[nextMark] = UnitGUID("mouseover")
	SetRaidTarget(unit, nextMark)
end

-- Fired when raid target icons are assigned or cleared
function f:RAID_TARGET_UPDATE()
	-- TODO: scan party/raid to see if any marks are set that we need to skip over
	if GetNumRaidMembers() > 0 then
		ScanRaid()
	elseif GetNumPartyMembers() > 0 and UnitInRaid("player") == false then
		ScanParty()
	end
end

-- Global function for keybinding :(
function MouseOverMarker_ClearMarks()
	for i = 8,0,-1 do
		usedMarks[i] = nil
		SetRaidTarget("player", i)
	end
	f:SetScript("OnUpdate", FinalMarkReset) -- force a final clear after 1/2 sec... 
	nextMark = 8
end

