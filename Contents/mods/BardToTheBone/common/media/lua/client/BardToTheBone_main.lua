local Bard = {}

Bard.voices = {}
Bard.players = {}
Bard.accidental_map = {}
Bard.natural_map = {}

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
    ["G"] = {F = "^"}, ["D"] = {F = "^", C = "^"}, ["A"] = {F = "^", C = "^", G = "^"},
    ["E"] = {F = "^", C = "^", G = "^", D = "^"}, ["B"] = {F = "^", C = "^", G = "^", D = "^", A = "^"},
    ["F"] = {B = "_"}, ["Bb"] = {B = "_", E = "_"}, ["Eb"] = {B = "_", E = "_", A = "_"},
    ["Ab"] = {B = "_", E = "_", A = "_", D = "_"},
    ["Em"] = {F = "^"}, ["Am"] = {}, ["Dm"] = {B = "_"}, ["Gm"] = {B = "_", E = "_"}, ["Cm"] = {B = "_", E = "_", A = "_"}
}

function Bard.getTicksFromLength(length)
    local baseTicks = 120
    if length:find("/") then
        local num, den = length:match("(%d*)/(%d+)")
        num = tonumber(num) or 1
        return math.min(960, math.floor(baseTicks * (num / tonumber(den))))
    elseif tonumber(length) then
        return math.floor(baseTicks * tonumber(length))
    end
    return baseTicks
end


function Bard.convertTicksToSimDuration(ticks, bpm, baseNoteLength)
    local l_top, l_bottom = baseNoteLength:match("(%d+)%s*/%s*(%d+)")
    if not l_top or not l_bottom then l_top, l_bottom = 1, 8 end
    local fraction = tonumber(l_top) / tonumber(l_bottom)
    local secondsPerBeat = 60 / bpm
    local secondsPerTick = secondsPerBeat * fraction
    local trueMultiplier = getGameTime():getTrueMultiplier()
    local frameRate = getPerformance():getFramerate()
    local baseFrameRate = 60
    local simTicksPerSecond = (frameRate / baseFrameRate) * (1 / trueMultiplier)
    local simulatedDurationSeconds = secondsPerTick * simTicksPerSecond * ticks

    return simulatedDurationSeconds * 60
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


function Bard.parseNoteToken(token, defaultTicks, key)
    if token:match("^z") then
        local duration = token:match("z(%d*/?%d*)") or "1"
        local ticks = Bard.getTicksFromLength(duration)
        return { { rest = true, ticks = ticks } }
    end

    local notes = {}
    local duration = token:match("%d+/?%d*") or ""
    local ticks = Bard.getTicksFromLength(duration ~= "" and duration or "1")
    for accidental, base, octaveMod in token:gmatch("([_=^]*)([A-Ga-g])([',]*)") do
        local octave = 4
        if base:match("%l") then octave = 5 end
        for char in octaveMod:gmatch("[',]") do
            octave = octave + (char == "'" and 1 or -1)
        end
        local fullBase = accidental .. base:upper()
        local note = { rest = false, base = fullBase, octave = octave, ticks = ticks }
        Bard.applyKeyAccidental(note, key)
        table.insert(notes, note)
    end
    return notes
end


function Bard.preprocessABC(abc)
    -- Insert default Key and Meter if missing
    if not abc:find("K:") then abc = "K:C\n" .. abc end
    if not abc:find("M:") then abc = "M:4/4\n" .. abc end

    -- Split into true lines first
    local lines = {}
    for line in abc:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local cleaned = {}
    local tag = "CLEAN"

    for _, line in ipairs(lines) do
        -- Light cleanup
        line = line:gsub("%s*[vu]%u%s*", " ") -- Remove fake voice switches
        line = line:gsub("(%b[])%s*", "%1 ")   -- Space after [chords]
        line = line:gsub("([_=^]?[A-Ga-g][',]*%d*/?%d*)%s*", "%1 ") -- After notes
        line = line:gsub("(z%d*/?%d*)%s*", "%1 ") -- After rests

        -- Detect messy artifacts
        if line:find("\\") or line:find("{") or line:find("}") or line:find("!%a+!") or line:find("T:%s*from") or line:find("z1/32") or line:find("z1/64") or line:find("z1/128") then
            tag = "MESSY"
            line = line:gsub("%%[^\n]*", "")
            line = line:gsub("!.-!", "")
            line = line:gsub("%(%d+:?%d*:?.-?", "")
            line = line:gsub("%b()", "")
            line = line:gsub("[~.><\"]", "")
            line = line:gsub("[%|:]+", " ")
        end

        -- Collapse spaces inside this line
        line = line:gsub("[ \t]+", " ")
        line = line:match("^%s*(.-)%s*$") or line -- Trim this line

        table.insert(cleaned, line)
    end

    -- Rejoin the cleaned lines into full text
    abc = table.concat(cleaned, "\n")

    -- Force newline after headers just in case
    abc = abc:gsub("([XTMKLQ]):%s*([^%\n]*)%s+", "%1:%2\n")

    -- Clean up any remaining messy spaces around newlines
    abc = abc:gsub(" *\n *", "\n")
    abc = abc:match("^%s*(.-)%s*$") or abc

    -- Optional: log processed output
    print("\nPROCESSED ABC:  ("..tag..")\n", abc, "\n\n_______")

    return abc
end


function Bard.parseABC(abc)
    abc = Bard.preprocessABC(abc)

    local voices = {}
    local currentVoice = "default"
    voices[currentVoice] = {
        events = {},
        bpm = 120,
        key = "C",
        baseNoteLength = "1/8",
        defaultTicks = Bard.getTicksFromLength("1/8"),
    }

    local currentTicks = {}
    currentTicks[currentVoice] = 0
    local totalTicks = 0 -- New: track total ticks across all voices (longest one)

    for line in abc:gmatch("[^\r\n]+") do
        local header, value = line:match("^(%a):%s*(.+)$")

        if header == "T" or header == "X" or header == "%" then
            -- Ignore
        elseif header == "V" then
            currentVoice = value
            voices[currentVoice] = voices[currentVoice] or {
                events = {},
                bpm = 120,
                key = "C",
                baseNoteLength = "1/8",
                defaultTicks = Bard.getTicksFromLength("1/8"),
            }
            currentTicks[currentVoice] = currentTicks[currentVoice] or 0

        elseif header == "K" then
            voices[currentVoice].key = value

        elseif header == "Q" then
            voices[currentVoice].bpm = tonumber(value:match("%d+")) or 120

        elseif header == "L" then
            voices[currentVoice].baseNoteLength = value
            voices[currentVoice].defaultTicks = Bard.getTicksFromLength(value)

        elseif header == "M" then
            voices[currentVoice].meter = value

        elseif not header then
            -- It's a line of notes
            local allTokens = {}
            for token in line:gmatch("[^%s]+") do
                table.insert(allTokens, token)
            end

            for _, token in ipairs(allTokens) do

                local isChord = token:match("^%b[]$") ~= nil


                local parsedNotes = Bard.parseNoteToken(token, voices[currentVoice].defaultTicks, voices[currentVoice].key)
                if #parsedNotes > 0 then

                    local bpm = voices[currentVoice].bpm
                    local secondsPerBeat = 60 / bpm
                    local ticksPerBeat = 120

                    local elapsedSeconds = (currentTicks[currentVoice] / ticksPerBeat) * secondsPerBeat
                    local timeOffsetMs = math.floor(elapsedSeconds * 1000)

                    table.insert(voices[currentVoice].events, {
                        timeOffset = timeOffsetMs,
                        notes = parsedNotes,
                    })

                    if parsedNotes[1] and parsedNotes[1].ticks then
                        if isChord then
                            local maxTicks = 0
                            for _, note in ipairs(parsedNotes) do
                                maxTicks = math.max(maxTicks, note.ticks or 0)
                            end
                            currentTicks[currentVoice] = currentTicks[currentVoice] + maxTicks
                        else
                            currentTicks[currentVoice] = currentTicks[currentVoice] + parsedNotes[1].ticks
                        end
                    end
                end
            end

        end
    end

    -- Return totalTicks separately to calculate true duration later
    return voices, totalTicks
end


function Bard.forceStop(player)
    local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
    local currentAction = actionQueue.queue[1]
    if currentAction and (currentAction.Type == "BardToTheBonePlayMusic") and currentAction.action then
        currentAction.action:forceStop()
    end
    local id = player:getUsername()
    Bard.players[id] = nil
end


function Bard.startPlayback(player, abc)
    local music, totalTicks = Bard.parseABC(abc)

    local defaultVoiceName = "default"
    if not music[defaultVoiceName] then
        defaultVoiceName = next(music)
    end

    local defaultVoice = music[defaultVoiceName]
    local bpm = defaultVoice.bpm
    local secondsPerBeat = 60 / bpm
    local ticksPerBeat = 120
    local realSeconds = (totalTicks / ticksPerBeat) * secondsPerBeat

    local trueMultiplier = getGameTime():getTrueMultiplier()
    local simAdjustedSeconds = realSeconds / trueMultiplier

    local durationTicks = math.ceil(simAdjustedSeconds * 60)

    local bufferTicks = math.ceil(0.5 * 60) -- 500ms buffer
    durationTicks = durationTicks + bufferTicks

    return music, durationTicks * 100
end



function Bard.noteToSound(note)
    if note.rest then return nil end
    local mapped = Bard.accidental_map[note.base] or Bard.natural_map[note.base:sub(-1)]
    if not mapped then return nil end
    return mapped .. tostring(note.octave)
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.playLoadedSongs(player)
    if not player then return end
    local id = player:getUsername()
    local bard = Bard.players[id]
    if not bard then return end

    local music = bard.music
    local instrumentID = bard.instrumentID
    local startTime = bard.startTime
    local now = getTimestampMs()

    local allDone = true
    local emitters = {}

    for voiceId, data in pairs(music) do
        data.eventIndex = data.eventIndex or 1

        while data.eventIndex <= #data.events do
            local event = data.events[data.eventIndex]
            local eventTime = startTime + event.timeOffset

            local latencyBufferMs = 30
            if now + latencyBufferMs >= eventTime then
                -- Play all notes in this event
                for _, note in ipairs(event.notes) do
                    local sound = Bard.noteToSound(note)
                    if sound then
                        local instrumentSound = instrumentID .. "_" .. sound
                        print("Play: ", instrumentSound, " (", event.timeOffset, ")")
                        emitters[voiceId] = emitters[voiceId] or getWorld():getFreeEmitter()
                        emitters[voiceId]:playSound(instrumentSound, player:getSquare())
                        addSound(player, player:getX(), player:getY(), player:getZ(), 20, 10)
                    end
                end

                -- Move to the next event
                data.eventIndex = data.eventIndex + 1
            else
                -- If the next event is not ready yet, stop checking
                allDone = false
                break
            end
        end
    end

    if allDone then
        Bard.players[id] = nil
    end
end




---THESE MATCH THE SOUNDS IN SCRIPTS/sounds_BardToTheBone
-- The folders in sound/instruments/ are used as IDs
-- SEE: python script `autoGenSoundFiles.py`
Bard.instrumentIDtoType = {
    ["Base.Banjo"] = "banjo",
    ["Base.GuitarElectric"] = "electric_guitar",
    ["Base.GuitarAcoustic"] = "guitar",
    ["Base.Harmonica"] = "harmonica",
    ["Base.Saxophone"] = "saxophone",
    ["Base.Violin"] = "violin",
}

function Bard.getInstrumentID(instrument)
    return Bard.instrumentIDtoType[instrument:getFullType()]
end


return Bard