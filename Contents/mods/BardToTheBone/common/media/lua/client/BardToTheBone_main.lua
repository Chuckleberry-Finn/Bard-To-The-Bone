local abc_string = [[
X:1
T:Debug Song
M:4/4
L:1/4
Q:100
V:1
K:C
C D E F|
V:2
K:C
G, A, B, C|
]]

-- BardToTheBone with full multi-voice support
local Bard = {}

Bard.voices = {}
Bard.players = {}
Bard.accidental_map = {}
Bard.natural_map = {}

-- Helper
function Bard.table_indexof(t, val) for i, v in ipairs(t) do if v == val then return i end end end

local base_notes = {"C", "D", "E", "F", "G", "A", "B"}
for _, note in ipairs(base_notes) do
    Bard.natural_map[note] = note .. "n"
    Bard.accidental_map["=" .. note] = note .. "n"
    if note ~= "E" and note ~= "B" then
        Bard.accidental_map["^" .. note] = base_notes[(Bard.table_indexof(base_notes, note) % 7) + 1] .. "b"
    end
    if note ~= "C" and note ~= "F" then
        Bard.accidental_map["_" .. note] = base_notes[((Bard.table_indexof(base_notes, note) - 2) % 7) + 1] .. "n"
    end
end

Bard.key_accidentals = {
    ["C"] = {}, ["Cmaj"] = {},
    ["G"] = {F = "^"},
    ["D"] = {F = "^", C = "^"},
    ["A"] = {F = "^", C = "^", G = "^"},
    ["E"] = {F = "^", C = "^", G = "^", D = "^"},
    ["B"] = {F = "^", C = "^", G = "^", D = "^", A = "^"},
    ["F"] = {B = "_"},
    ["Bb"] = {B = "_", E = "_"},
    ["Eb"] = {B = "_", E = "_", A = "_"},
    ["Ab"] = {B = "_", E = "_", A = "_", D = "_"},
    ["Em"] = {F = "^"}, ["Am"] = {}, ["Dm"] = {B = "_"},
    ["Gm"] = {B = "_", E = "_"}, ["Cm"] = {B = "_", E = "_", A = "_"}
}

function Bard.getTicksFromLength(length)
    local baseTicks = 120
    if length:find("/") then
        local top, bottom = length:match("(%d*)/(%d+)")
        top = tonumber(top) or 1
        bottom = tonumber(bottom)
        return math.floor(baseTicks * (top / bottom))
    else
        return math.floor(baseTicks * tonumber(length))
    end
end

function Bard.convertTicksToTempoDuration(ticks, bpm, baseNoteLength)
    local l_top, l_bottom = baseNoteLength:match("(%d+)%s*/%s*(%d+)")
    local fraction = tonumber(l_top) / tonumber(l_bottom)
    local secondsPerBeat = 60 / bpm
    local secondsPerTick = secondsPerBeat * fraction
    local simTicksPerSecond = 10 / getGameTime():getTrueMultiplier()
    return math.max(1, math.floor(secondsPerTick * simTicksPerSecond * ticks))
end

function Bard.applyKeyAccidental(note, key)
    local base = note.base:sub(-1)
    local acc = note.base:sub(1, 1)
    if acc ~= "^" and acc ~= "_" and acc ~= "=" then
        local implied = Bard.key_accidentals[key or "C"]
        if implied and implied[base] then
            note.base = implied[base] .. base
        end
    end
end

function Bard.parseABC(abc)
    local voices = {}
    local currentVoice = "default"
    voices[currentVoice] = {
        notes = {}, bpm = 120, key = "C", baseNoteLength = "1/8", defaultTicks = Bard.getTicksFromLength("1/8"), index = 1, timer = 0
    }

    for line in abc:gmatch("[^\r\n]+") do
        local header, value = line:match("^(%a):%s*(.+)$")
        if header == "V" then
            currentVoice = value
            voices[currentVoice] = voices[currentVoice] or {
                notes = {}, bpm = 120, key = "C", baseNoteLength = "1/8", defaultTicks = Bard.getTicksFromLength("1/8"), index = 1, timer = 0
            }
        elseif header == "K" then
            voices[currentVoice].key = value
        elseif header == "Q" then
            voices[currentVoice].bpm = tonumber(value:match("%d+")) or 120
        elseif header == "L" then
            voices[currentVoice].baseNoteLength = value
            voices[currentVoice].defaultTicks = Bard.getTicksFromLength(value)
        elseif not (header == "X" or header == "T" or header == "M" or header == "R" or header == "Z" or header == "S") then
            for base, duration in line:gmatch("([A-Ga-g])(%d*)") do
                local octave = base:match("%l") and 5 or 4
                local ticks = voices[currentVoice].defaultTicks
                if duration ~= "" then
                    ticks = tonumber(duration) * ticks
                end
                local note = { rest = false, base = base:upper(), octave = octave, ticks = ticks }
                Bard.applyKeyAccidental(note, voices[currentVoice].key)
                table.insert(voices[currentVoice].notes, note)
            end
        end
    end
    return voices
end

function Bard.startPlayback(player, abc)
    local id = player:getUsername()
    Bard.players[id] = Bard.parseABC(abc)
end


function Bard.noteToSound(note)
    if note.rest then return nil end
    print("Converting note:", note.base, "octave:", note.octave)
    local mapped = Bard.accidental_map[note.base] or Bard.natural_map[note.base:sub(-1)]
    if not mapped then print("No mapping for:", note.base) return nil end
    return mapped .. tostring(note.octave)
end


---@param player IsoPlayer|IsoMovingObject|IsoGameCharacter|IsoObject
function Bard.playLoadedSongs(player)
    local id = player:getUsername()
    local voices = Bard.players[id]
    if not voices then
        if isKeyDown(Keyboard.KEY_H) then
            Bard.startPlayback(player, abc_string)
        end
        return
    end

    local allDone = true
    local emitters = {}

    for voiceId, data in pairs(voices) do
        if data.timer > 0 then
            data.timer = data.timer - 1
            allDone = false
        elseif data.index <= #data.notes then
            local note = data.notes[data.index]
            local sound = Bard.noteToSound(note)
            if sound then
                print("Voice", voiceId, "Playing:", sound)
                emitters[voiceId] = emitters[voiceId] or getWorld():getFreeEmitter()
                emitters[voiceId]:playSound(sound, player:getSquare())
            end
            data.timer = Bard.convertTicksToTempoDuration(note.ticks, data.bpm, data.baseNoteLength)
            data.index = data.index + 1
            allDone = false
        end
    end

    if allDone then
        print("Playback finished for player:", id)
        Bard.players[id] = nil
    end
end


return Bard
