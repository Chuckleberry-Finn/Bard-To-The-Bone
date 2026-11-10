require "TimedActions/ISBaseTimedAction"

local Bard = require "BardToTheBone_main"
local netWorkHandler = require "BardToTheBone_networkHandler"

---@class BardToTheBonePlayMusic : ISBaseTimedAction
BardToTheBonePlayMusic = ISBaseTimedAction:derive("BardToTheBonePlayMusic")

function BardToTheBonePlayMusic:isValid()
    local held = self.heldItem and (self.character:getPrimaryHandItem() == self.item)
    local square = (not self.heldItem) and self.item:getSquare()
    local near = square and (square:DistToProper(self.character) <= 1.5)
    return (held or near)
end


function BardToTheBonePlayMusic:start()
    --self:setOverrideHandModels(self.item, nil)
    local id = self.character:getUsername()

    local instrumentData = Bard.getInstrumentData(self.item)
    if not instrumentData then
        Bard.players[id] = nil
        self.pausedBard = nil
        ISTimedActionQueue.getTimedActionQueue(self.character):resetQueue()
        return
    end

    local resumed = self.pausedBard
    if resumed then
        self.pausedBard = nil
        resumed.action = self
        resumed.playingNotes = {}
        resumed.delayedNotes = {}
        resumed.networkBatch = nil
        resumed.networkPerformance = nil
        resumed.lastUpdateTime = getTimestampMs()
        resumed.nextAmpCheck = nil
        if resumed.bandStart then Bard.skipTo(resumed, Bard.serverNow() - resumed.bandStart) end
        Bard.players[id] = resumed
    else
        self:startPlayback(id, instrumentData)
    end

    self:setOverrideHandModels(instrumentData.right or self.item, instrumentData.left)

    if instrumentData.anim then
        self:setActionAnim("BttB_"..instrumentData.anim)
        local defaultVoiceId = (self.voiceOrder and self.voiceOrder[1]) or Bard.next(Bard.players[id].music)
        local bpm = Bard.players[id].music[defaultVoiceId].bpm or 180
        self.character:setVariable("BttB_playSpeed", (1 * (bpm / 180)))
    end

    self.character:clearVariable("BttB_Special")
    if instrumentData.special then
        Bard.instrumentSpecials[instrumentData.special](self.character)
    end
end


function BardToTheBonePlayMusic:startPlayback(id, instrumentData)
    Bard.players[id] = {}
    Bard.players[id].action = self
    Bard.players[id].music = self.music
    Bard.players[id].volume = self.volume
    Bard.players[id].duration = self.maxTime
    Bard.players[id].instrumentID = instrumentData.soundDir
    Bard.players[id].startTime = getTimestampMs()
    Bard.players[id].decay = instrumentData.decay
    Bard.players[id].isPercussion = instrumentData.isPercussion
    Bard.players[id].percussionOctaveShift = instrumentData.percussionOctaveShift
    Bard.players[id].percussionPieces = instrumentData.percussionPieces
    Bard.players[id].percussionFallback = instrumentData.percussionFallback
    Bard.players[id].selectedVoice = self.voice
    Bard.players[id].songKey = self.songKey
    Bard.players[id].song = self.song
    Bard.players[id].family = instrumentData.family
    Bard.players[id].needsAmp = instrumentData.needsAmp
    Bard.players[id].ampStyles = instrumentData.ampStyles
    Bard.players[id].styles = instrumentData.styles

    if isClient() and Bard.clock.offset then
        local bandStart = Bard.findBand(self.songKey, self.songDuration)
        Bard.players[id].bandStart = bandStart or Bard.serverNow()
        Bard.players[id].joinedBand = bandStart ~= nil
        Bard.skipTo(Bard.players[id], Bard.serverNow() - Bard.players[id].bandStart)
    end
    Bard.requestClock(self.character)

    if instrumentData.styles then
        local style = self.style or instrumentData.styles[1]
        Bard.players[id].style = style
    end
end


function BardToTheBonePlayMusic:endPlayback()
    local paused = self.action and (self.character:getTimedActionToRetrigger() == self.action)
    self.pausedBard = paused and Bard.players[self.character:getUsername()] or nil
    Bard.completeAction(self.character, true, nil, paused)
end

function BardToTheBonePlayMusic:perform()
    Bard.completeAction(self.character, true)
    ISBaseTimedAction.perform(self)
end

function BardToTheBonePlayMusic:forceStop()
    self:endPlayback()
    ISBaseTimedAction.forceStop(self)
end
function BardToTheBonePlayMusic:stop()
    self:endPlayback()
    ISBaseTimedAction.stop(self)
end

function BardToTheBonePlayMusic:update()
    local bard = Bard.players[self.character:getUsername()]
    if bard and bard.elapsedTime and self.songDuration > 0 then
        local progress = self.maxTime * ((bard.elapsedTime - (bard.timeShift or 0)) / self.songDuration)
        self:setCurrentTime(math.max(0, math.min(self.maxTime - 1, progress)))
    end

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

    local music, duration, voiceOrder, durationMs = Bard.startPlayback(character, abcNotation, voice)
    o.music = music
    o.voiceOrder = voiceOrder
    o.songKey = Bard.getSongKey(abcNotation)
    o.songDuration = durationMs or 0
    o.maxTime = duration or 1

    return o
end