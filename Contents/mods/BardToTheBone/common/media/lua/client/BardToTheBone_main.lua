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

function Bard.convertTicksToMilliseconds(ticks, bpm, baseNoteLength, tempoNoteLength)
    local secondsPerTempoNote = 60 / bpm

    local l_top, l_bottom = baseNoteLength:match("(%d+)%s*/%s*(%d+)")
    l_top = tonumber(l_top) or 1
    l_bottom = tonumber(l_bottom) or 8
    local baseFraction = l_top / l_bottom

    local t_top, t_bottom = tempoNoteLength:match("(%d+)%s*/%s*(%d+)")
    t_top = tonumber(t_top) or 1
    t_bottom = tonumber(t_bottom) or 4
    local tempoFraction = t_top / t_bottom

    local ticksPerTempoNote = 120 * (tempoFraction / baseFraction)
    local secondsPerTick = secondsPerTempoNote / ticksPerTempoNote

    return ticks * secondsPerTick * 1000
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
    if token:match("^%b[]$") then
        -- This is a chord
        local inner = token:sub(2, -2) -- Remove [ and ]
        local notes = {}

        -- Separate multiple notes inside chord
        for noteToken in inner:gmatch("[^%s]+") do
            local duration = noteToken:match("%d*/?%d*") or ""
            local ticks = Bard.getTicksFromLength(duration ~= "" and duration or "1")

            for accidental, base, octaveMod in noteToken:gmatch("([_=^]*)([A-Ga-g])([',]*)") do
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
        end

        return notes
    else
        -- Not a chord
        local notes = {}
        local duration = token:match("%d*/?%d*") or ""
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
end


function Bard.preprocessABC(abc)
    -- Insert default Key and Meter if missing
    if not abc:find("K:") then abc = "K:C\n" .. abc end
    if not abc:find("M:") then
        abc = "M:4/4\n" .. abc
    else
        abc = abc:gsub("M:%s*C|%s*", "M:2/2")
        abc = abc:gsub("M:%s*C%s*", "M:4/4")
    end
    -- Derive default L: based on M: if missing
    if not abc:find("L:") then
        local meter = abc:match("M:(%d+)%s*/%s*(%d+)")
        if meter then
            local top, bottom = meter:match("(%d+)%s*/%s*(%d+)")
            top = tonumber(top)
            bottom = tonumber(bottom)

            if bottom == 2 and (top == 2 or top == 3) then
                -- M:2/2 or M:3/2 → Cut time → L:1/4
                abc = "L:1/4\n" .. abc
            else
                -- Otherwise, L:1/8
                abc = "L:1/8\n" .. abc
            end
        else
            -- No readable M: found, fallback
            abc = "L:1/8\n" .. abc
        end
    end

    -- Optional: Insert default tempo if missing
    if not abc:find("Q:") then
        abc = "Q:1/4=120\n" .. abc
    end

    -- Split into true lines first
    local lines = {}
    for line in abc:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local cleaned = {}
    local tag = "CLEAN"

    for _, line in ipairs(lines) do
        -- Light cleanup
        line = line:gsub("([vu~.HLMOPTS])([_=^]?[A-Ga-g])", "%2") -- Remove decorations but keep notes
        line = line:gsub("(%b[])%s*", "%1 ")   -- Add space after [chords]
        line = line:gsub("([_=^]?[A-Ga-g][',]*%d*/?%d*)%s*", "%1 ") -- Add space after single notes
        line = line:gsub("(z%d*/?%d*)%s*", "%1 ") -- Add space after rests

        -- Remove ALL spaces inside true chords (skip [V:], [|] cases)
        line = line:gsub("%[(.-)%]", function(inner)
            local trimmed = inner:match("^%s*(.-)%s*$") or inner
            if trimmed:find("^V:") or trimmed:find("^|") then
                return "[" .. inner .. "]"
            else
                return "[" .. inner:gsub("%s+", "") .. "]"
            end
        end)

        -- Detect messy artifacts
        if line:find("\\") or line:find("{") or line:find("}") or line:find("!%a+!") or line:find("T:%s*from") or line:find("z1/32") or line:find("z1/64") or line:find("z1/128") then
            tag = "MESSY"
            line = line:gsub("%%[^\n]*", "")   -- Remove comments
            line = line:gsub("!.-!", "")       -- Remove decorations
            line = line:gsub("%b{}", "")       -- Remove grace notes
            line = line:gsub("%b()", "")        -- Remove slurs
            -- Note: DO NOT touch | : [ ] (important for repeats/endings/tuplets)
        end

        -- Collapse spaces inside this line
        line = line:gsub("[ \t]+", " ")
        line = line:match("^%s*(.-)%s*$") or line -- Trim this line
        table.insert(cleaned, line)
    end

    -- Rejoin the cleaned lines into full text
    abc = table.concat(cleaned, "\n")

    -- Force newline after headers just in case
    abc = abc:gsub("([XTMKLQV]):%s*([^%\n]*)%s+", "%1:%2\n")

    -- Clean up spaces around newlines
    abc = abc:gsub(" *\n *", "\n")
    abc = abc:match("^%s*(.-)%s*$") or abc

    -- Optional: log processed output
    ---print("\nPROCESSED ABC:  ("..tag..")\n", abc, "\n\n_______")

    return abc
end


function Bard.parseABC(abc)
    abc = Bard.preprocessABC(abc)

    local voices = {}
    local currentVoice = "default"
    voices[currentVoice] = {
        events = {},
        bpm = 180,
        key = "C",
        baseNoteLength = "1/8",
        defaultTicks = Bard.getTicksFromLength("1/8"),
    }

    local currentTicks = {}
    currentTicks[currentVoice] = 0
    local totalTicks = 0

    local repeatBuffer = {}
    local recordingRepeat = false
    local inRepeat = false
    local currentEnding = nil
    local skipEnding = false
    local tupletNotesRemaining = 0
    local tupletMultiplier = 1.0

    local brokenRhythm = nil -- ">" or "<"
    local lastParsedNoteEvent = nil -- Track previous note for broken rhythm adjustments

    for line in abc:gmatch("[^\r\n]+") do
        local header, value = line:match("^(%a):%s*(.+)$")

        if header == "T" or header == "X" or header == "%" then
            -- Ignore

        elseif header == "V" then
            currentVoice = value
            voices[currentVoice] = voices[currentVoice] or {
                events = {},
                bpm = 180,
                key = "C",
                baseNoteLength = "1/8",
                defaultTicks = Bard.getTicksFromLength("1/8"),
            }
            currentTicks[currentVoice] = currentTicks[currentVoice] or 0

        elseif header == "K" then
            voices[currentVoice].key = value

        elseif header == "Q" then
            local noteLength, bpm = value:match("(%d+%s*/%s*%d+)%s*=%s*(%d+)")
            if bpm then
                bpm = tonumber(bpm)
            else
                bpm = tonumber(value:match("%d+")) or 120
            end
            voices[currentVoice].bpm = bpm

            if noteLength then
                voices[currentVoice].tempoNoteLength = noteLength
            else
                voices[currentVoice].tempoNoteLength = "1/4" -- Assume 1/4 note if not specified
            end

        elseif header == "L" then
            voices[currentVoice].baseNoteLength = value
            voices[currentVoice].defaultTicks = Bard.getTicksFromLength(value)

        elseif header == "M" then
            voices[currentVoice].meter = value -- Currently unused for timing

        elseif not header then
            -- It's a line of notes
            local allTokens = {}
            for token in line:gmatch("[^%s]+") do
                table.insert(allTokens, token)
            end

            local tokenIndex = 1
            while tokenIndex <= #allTokens do
                local token = allTokens[tokenIndex]

                ---print("token: ", token)

                if token == "|:" then
                    recordingRepeat = true
                    repeatBuffer = {}
                    inRepeat = true

                elseif token == ":|" then
                    recordingRepeat = false
                    for i = #repeatBuffer, 1, -1 do
                        table.insert(allTokens, tokenIndex + 1, repeatBuffer[i])
                    end
                    repeatBuffer = {}

                elseif token:match("^|+$") or token:match("^|%]+$") then
                    --ignore

                elseif token:match("^%[1$") or token:match("^%[2$") or token:match("^%[3$") then
                    currentEnding = tonumber(token:sub(2))
                    skipEnding = (currentEnding ~= 1)

                elseif token:match("^%(%d") then
                    local n = tonumber(token:match("^%((%d)"))
                    if n and n > 0 then
                        tupletNotesRemaining = n
                        tupletMultiplier = (n == 3) and (2/3) or (1.0)
                    end

                else
                    if token:find("[<>]") then
                        brokenRhythm = token:match("([<>])")
                        token = token:gsub("[<>]", "")
                    end

                    if not skipEnding and token ~= "" then
                        if recordingRepeat then
                            table.insert(repeatBuffer, token)
                        end

                        local isChord = token:match("^%b[]$") ~= nil
                        local parsedNotes = Bard.parseNoteToken(token, voices[currentVoice].defaultTicks, voices[currentVoice].key)
                        if #parsedNotes > 0 then

                            local elapsedMs = Bard.convertTicksToMilliseconds(
                                    currentTicks[currentVoice],
                                    voices[currentVoice].bpm or 120,
                                    voices[currentVoice].baseNoteLength or "1/8",
                                    voices[currentVoice].tempoNoteLength or "1/4"
                            )

                            local timeOffsetMs = math.floor(elapsedMs)

                            -- Apply tuplet scaling if active
                            for _, note in ipairs(parsedNotes) do
                                if tupletNotesRemaining > 0 then
                                    note.ticks = math.max(1, math.floor(note.ticks * tupletMultiplier))
                                    tupletNotesRemaining = tupletNotesRemaining - 1
                                    if tupletNotesRemaining <= 0 then
                                        tupletMultiplier = 1.0
                                    end
                                end
                            end

                            -- Apply broken rhythm adjustments
                            if brokenRhythm and lastParsedNoteEvent then
                                local prevEvent = lastParsedNoteEvent
                                local currentEvent = parsedNotes[1]

                                if brokenRhythm == ">" then
                                    prevEvent.ticks = math.floor(prevEvent.ticks * 3 / 2)
                                    currentEvent.ticks = math.floor(currentEvent.ticks * 1 / 2)
                                elseif brokenRhythm == "<" then
                                    prevEvent.ticks = math.floor(prevEvent.ticks * 1 / 2)
                                    currentEvent.ticks = math.floor(currentEvent.ticks * 3 / 2)
                                end

                                brokenRhythm = nil -- Clear after applying
                            end

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

                            lastParsedNoteEvent = parsedNotes[1] -- update for broken rhythm
                        end
                    end
                end

                tokenIndex = tokenIndex + 1
            end
        end
    end

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
    local baseNoteLength = defaultVoice.baseNoteLength
    local tempoNoteLength = defaultVoice.tempoNoteLength or "1/4"

    local totalSimTicks = Bard.convertTicksToMilliseconds(totalTicks, bpm, baseNoteLength, tempoNoteLength)

    local bufferTicks = math.ceil(0.5 * 60) -- 500ms safety buffer
    local durationTicks = totalSimTicks + bufferTicks

    return music, durationTicks * 100 --to convert ticks to milliseconds for playback deadline
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

        emitters[voiceId] = emitters[voiceId] or getWorld():getFreeEmitter()

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
                        ---print("startTime-now: "..startTime-now.."  Play: ", instrumentSound, " (", event.timeOffset, ")")
                        emitters[voiceId]:playSound(instrumentSound, player:getSquare())
                        addSound(player, player:getX(), player:getY(), player:getZ(), 20, 10)
                    ---else
                        ---print(note.rest and "Play: rest" or "ERROR: "..tostring(note.base)..tostring(note.octave), " (", event.timeOffset, ")")
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