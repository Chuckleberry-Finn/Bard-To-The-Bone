require "TimedActions/ISBaseTimedAction"

local Bard = require "BardToTheBone_main"
local netWorkHandler = require "BardToTheBone_networkHandler"

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
    Bard.players[id].volume = self.volume
    Bard.players[id].duration = self.maxTime

    local instrumentData = Bard.getInstrumentData(self.item)
    if not instrumentData then
        Bard.players[id] = nil
        ISTimedActionQueue.getTimedActionQueue(self.character):resetQueue()
        return
    end
    Bard.players[id].instrumentID = instrumentData.soundDir
    Bard.players[id].startTime = getTimestampMs()
    Bard.players[id].decay = instrumentData.decay
    Bard.players[id].isPercussion = instrumentData.isPercussion
    Bard.players[id].percussionOctaveShift = instrumentData.percussionOctaveShift
    Bard.players[id].percussionPieces = instrumentData.percussionPieces
    Bard.players[id].percussionFallback = instrumentData.percussionFallback
    Bard.players[id].selectedVoice = self.voice

    if instrumentData.styles then
        local style = self.style or instrumentData.styles[1]
        Bard.players[id].style = style
    end

    self:setOverrideHandModels(instrumentData.right or self.item, instrumentData.left)

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

function BardToTheBonePlayMusic:update()
    self.ticks = self.ticks+1
    if self.ticks > 10 then
        self.ticks = 0
        netWorkHandler.sendUpdate(self.character)
    end
end


---@param character IsoGameCharacter
function BardToTheBonePlayMusic:new(character, instrument, abcNotation, style, volume, voice) --time, recipe, container, containers)
    if not instrument or not character or not abcNotation then return end
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.item = instrument
    o.stopOnWalk = false
    o.stopOnRun = true

    o.ticks = 0

    o.heldItem = instanceof(instrument, "InventoryItem")
    o.style = style
    o.volume = volume
    o.voice = voice

    o.caloriesModifier = 2.5

    local music, duration, voiceOrder = Bard.startPlayback(character, abcNotation, voice)
    o.music = music
    o.voiceOrder = voiceOrder
    o.maxTime = duration or 1

    return o
end