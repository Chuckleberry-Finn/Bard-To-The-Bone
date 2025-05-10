require "TimedActions/ISBaseTimedAction"

local Bard = require "BardToTheBone_main"

---@class BardToTheBonePlayMusic : ISBaseTimedAction
BardToTheBonePlayMusic = ISBaseTimedAction:derive("BardToTheBonePlayMusic")

function BardToTheBonePlayMusic:isValid()
    local held = self.heldItem and (self.character:getPrimaryHandItem() == self.item)
    local near = (not self.heldItem) and (self.item:getSquare():DistToProper(self.character) <= 1.5)
    return (held or near)
end


function BardToTheBonePlayMusic:start()
    --self:setOverrideHandModels(self.item, nil)
    local id = self.character:getUsername()
    Bard.players[id] = {}
    Bard.players[id].music = self.music
    Bard.players[id].duration = self.maxTime
    local instrumentData = Bard.getInstrumentData(self.item)
    Bard.players[id].instrumentID = instrumentData.soundDir
    Bard.players[id].startTime = getTimestampMs()

    if instrumentData then

        if self.heldItem then
            self:setOverrideHandModels(instrumentData.right or self.item, instrumentData.left)
        end

        if instrumentData.anim then
            self:setActionAnim("BttB_"..instrumentData.anim)
            local defaultVoiceId = Bard.next(Bard.players[id].music)
            local bpm = Bard.players[id].music[defaultVoiceId].bpm or 180
            self.character:setVariable("BttB_playSpeed", (1 * (bpm / 180)))
        end

        self.character:clearVariable("BttB_Special")
        if instrumentData.special then
            Bard.instrumentSpecials[instrumentData.special](self.character)
        end
    end
end

function BardToTheBonePlayMusic:perform()
    Bard.completeAction(self.character)
    ISBaseTimedAction.perform(self)
end

function BardToTheBonePlayMusic:forceStop()
    Bard.completeAction(self.character)
    ISBaseTimedAction.forceStop(self)
end
function BardToTheBonePlayMusic:stop()
    Bard.completeAction(self.character)
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
    o.stopOnRun = true

    o.heldItem = instanceof(self.item, "InventoryItem")

    local music, duration = Bard.startPlayback(character, abcNotation)
    o.music = music
    o.maxTime = duration or 1

    return o
end