require "TimedActions/ISBaseTimedAction"

local Bard = require "BardToTheBone_main"

---@class BardToTheBonePlayMusic : ISBaseTimedAction
BardToTheBonePlayMusic = ISBaseTimedAction:derive("BardToTheBonePlayMusic")

function BardToTheBonePlayMusic:isValid()
    return self.character:getInventory():contains(self.item)
end

function BardToTheBonePlayMusic:start()
    self:setOverrideHandModels(self.item, nil)
    local id = self.character:getUsername()
    Bard.players[id] = {}
    Bard.players[id].music = self.music
    Bard.players[id].duration = self.maxTime
    local instrumentID = Bard.getInstrumentID(self.item)
    Bard.players[id].instrumentID = instrumentID
    Bard.players[id].startTime = getTimestampMs()
end

function BardToTheBonePlayMusic:perform()
    Bard.forceStop(self.character)
    ISBaseTimedAction.perform(self)
end

function BardToTheBonePlayMusic:forceStop()
    Bard.forceStop(self.character)
    ISBaseTimedAction.forceStop(self)
end
function BardToTheBonePlayMusic:stop()
    Bard.forceStop(self.character)
    ISBaseTimedAction.stop(self)
end

function BardToTheBonePlayMusic:update() end

---@param character IsoGameCharacter
function BardToTheBonePlayMusic:new(character, instrument, abcNotation) --time, recipe, container, containers)
    if not instrument or not character or not abcNotation then return end
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.item = instrument
    o.stopOnWalk = false
    o.stopOnAim = true
    o.stopOnRun = true
    o.ignoreHandsWounds = true
    o.caloriesModifier = 0.5
    o.forceProgressBar = true

    local music, duration = Bard.startPlayback(character, abcNotation)
    o.music = music
    o.maxTime = duration or 1

    return o
end