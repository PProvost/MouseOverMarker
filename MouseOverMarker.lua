--[[
Name: MouseOverMarker
Author: Quaiche
Description: Simple mouse-over raid target marking

Copyright 2010 Quaiche

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local addonName, ns = ...
local f -- Event handler frame

-----------------------------------------------------------------
-- Table of GUIDs for marks assigned to mobs.
-- Used to know if a mark is still in use. If a mob's GUID is 
-- here, that mark won't be used.
local usedMarks = {}

-----------------------------------------------------------------
-- Debug and print helpers
local function Print(...) print("|cFF33FF99"..addonName.."|r:", ...) end
local debugf = tekDebug and tekDebug:GetFrame(addonName)
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

-----------------------------------------------------------------
-- Determines if a unit is markable or not
local function IsMarkableUnit(unit)
	local creatureType = UnitCreatureType(unit)
	return UnitExists(unit) and (UnitCanAttack("player", unit) or UnitIsEnemy("player", unit)) and not UnitIsDead(unit) and  creatureType ~= "Critter" and creatureType ~= "Totem" and not UnitPlayerControlled(unit)  and not UnitIsPlayer(unit)
end

-----------------------------------------------------------------
-- Forcably clear all marks
local total = 0
local function ClearMarks()
	-- Cycle each mark onto "player"
	for i = 8,1,-1 do
		Debug("Clearing mark #"..i)
		usedMarks[i] = nil
		SetRaidTarget("player", i)
	end
	-- Minitimer to force the final mark clear on "player"
	f:SetScript("OnUpdate", function(self,elapsed)
		total = total + elapsed
		if total >= 0.5 then
			f:SetScript("OnUpdate", nil)
			SetRaidTarget("player", 0)
			total = 0
		end
	end) -- force a final clear after 1/2 sec... 
end

-----------------------------------------------------------------
-- Determines the next available mark
local function NextMarkIndex()
	for index = 8,1,-1 do
		if usedMarks[index] == nil then 
			Debug("Next mark is #"..index)
			return index 
		end
	end
	Debug("No next mark available")
end

-----------------------------------------------------------------
-- Scanning functions
local function ScanUnit(unit)
	local index = GetRaidTargetIndex(unit)
	if index then 
		Debug("Unit "..unit.." found to have mark #"..index)
		usedMarks[index] = UnitGUID(unit) 
	end
end

local function ScanRaid()
	for i=1,GetNumRaidMembers() do 
		ScanUnit("raid"..i)
		ScanUnit("raid"..i.."target")
	end
end

local function ScanParty()
	for i=1,GetNumPartyMembers() do 
		ScanUnit("party"..i)
		ScanUnit("party"..i.."target")
	end
end

-----------------------------------------------------------------
-- Marks the given unit with the next available mark
local function MarkUnit(unit)
	-- Only mark if it is a markable unit and doesn't already have a mark
	if not IsMarkableUnit(unit) then return end
	if GetRaidTargetIndex(unit) then return end

	-- Get the next mark
	local markIndex = NextMarkIndex()
	if not markIndex then return end -- no marks left

	-- Mark em up!
	Debug("Marking unit "..unit.." with mark #"..markIndex)
	usedMarks[markIndex] = UnitGUID(unit)
	SetRaidTarget(unit, markIndex)
end

-- Debug helper function that returns the current used mark list as a string.
local function GetUsedMarksString()
	local result = ""
	for i = 8,1,-1 do
		result = result..i..":"..tostring(usedMarks[i])
		if i < 8 then result = result..", " end
	end
	return result
end

-----------------------------------------------------------------
-- Event handler frame
f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")

function f:ADDON_LOADED(event, addon)
	if addon ~= addonName then return end

	f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	f:RegisterEvent("RAID_TARGET_UPDATE")
	f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

	LibStub("tekKonfig-AboutPanel").new(nil, addonName) -- Make first arg nil if no parent config panel
	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil
end

-- Called for every mouseover event
function f:UPDATE_MOUSEOVER_UNIT()
	if not IsAltKeyDown() then return end
	MarkUnit("mouseover")
end

-- Fired when raid target icons are assigned or cleared
function f:RAID_TARGET_UPDATE()
	-- Check player's target
	local targetIndex = GetRaidTargetIndex("target")
	if targetIndex then 
		Debug("Unit target found to have mark #"..targetIndex)
		usedMarks[targetIndex] = UnitGUID('target') 
	end

	-- Check party/raid and their targets
	if GetNumRaidMembers() > 0 then
		ScanRaid()
	elseif GetNumPartyMembers() > 0 and UnitInRaid("player") == false then
		ScanParty()
	end
end

-- Receives all combat log events... keep it short and sweet
function f:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if (type=="UNIT_DIED") or (type=="PARTY_KILL") then
		for markIndex,unitGUID in pairs(usedMarks) do
			if unitGUID==destGUID then
				Debug("Removing mark from "..destName.." {"..destGUID.."}")
				usedMarks[markIndex] = nil
				break
			end
		end
	end
end

-----------------------------------------------------
-- Keybindings globals

BINDING_HEADER_MOUSEOVERMARKER = "MouseOverMarker"
BINDING_NAME_MOUSEOVERMARKER_CLEAR = "Clear and reset marks"
BINDING_NAME_MOUSEOVERMARKER_MARKTARGET = "Mark the current target"

function MouseOverMarker_ClearMarks()
	ClearMarks()
end

function MouseOverMarker_MarkTarget()
	if not UnitExists("target") then return end
	MarkUnit("target")
end

