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
    if note == "E" then
        Bard.accidental_map["^" .. note] = "Fn"
    elseif note == "B" then
        Bard.accidental_map["^" .. note] = "Cn"
    else
        Bard.accidental_map["^" .. note] = base_notes[(Bard.table_indexof(base_notes, note) % 7) + 1] .. "b"
    end
    Bard.accidental_map["_" .. note] = note .. "b"
end


local sharpOrder = {"F","C","G","D","A","E","B"}
local flatOrder  = {"B","E","A","D","G","C","F"}
local letterFifths = { C = 0, D = 2, E = 4, F = -1, G = 1, A = 3, B = 5 }
local modeFifthsOffset = {
    ion = 0, maj = 0,
    dor = -2,
    phr = -4,
    lyd = 1,
    mix = -1,
    aeo = -3, min = -3, m = -3,
    loc = -5,
}


local function buildAccidentalsFromFifths(n)
    if n > 7 then n = 7 elseif n < -7 then n = -7 end
    local acc = {}
    if n > 0 then
        for i = 1, n do acc[sharpOrder[i]] = "^" end
    elseif n < 0 then
        for i = 1, -n do acc[flatOrder[i]] = "_" end
    end
    return acc
end


Bard.keyAccidentalCache = {}

---Resolves a raw K: field value (which may include trailing clef/other
---modifiers, e.g. "C clef=F4" or "D exp ^c") into an accidental map.
---@param rawKey string
function Bard.getKeyAccidentals(rawKey)
    rawKey = rawKey or "C"

    local keyToken = rawKey:match("^%s*(%S*)") or "C"
    if keyToken == "" then keyToken = "C" end

    local cached = Bard.keyAccidentalCache[keyToken]
    if cached then return cached end

    local result
    if keyToken:lower() == "none" or keyToken:lower() == "hp" or keyToken:lower() == "hp" then
        result = {}
    else
        local letter, accidental, mode = keyToken:match("^([A-Ga-g])([#b]?)(.*)$")
        if not letter then
            result = {}
        else
            letter = letter:upper()
            local accCount = 0
            if accidental == "#" then accCount = 1
            elseif accidental == "b" then accCount = -1 end

            local fifths = letterFifths[letter] + 7 * accCount

            local offset = 0
            mode = (mode or ""):lower()
            if mode == "m" then
                offset = modeFifthsOffset.m
            elseif mode ~= "" then
                offset = modeFifthsOffset[mode:sub(1, 3)] or 0
            end

            result = buildAccidentalsFromFifths(fifths + offset)
        end
    end

    Bard.keyAccidentalCache[keyToken] = result
    return result
end

-- Kept for backwards compatibility with anything referencing the old table name directly; now backed by the algorithmic resolver above.
Bard.key_accidentals = setmetatable({}, { __index = function(_, k) return Bard.getKeyAccidentals(k) end })

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

function Bard.convertMusicTicksToMilliseconds(ticks, bpm, baseNoteLength, tempoNoteLength)
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
        local implied = Bard.getKeyAccidentals(key)
        if implied and implied[base] then
            note.base = implied[base] .. base
        end
    end
end


function Bard.parseNoteToken(token, defaultTicks, key)

    -- Handle grace notes like gA, g^C'
    local chordBody, chordDur = token:match("^(%b[])(%d*/?%d*)$")
    if chordBody then
        local inner = chordBody:sub(2, -2)
        local notes = {}
        for accidental, base, octaveMod, duration in inner:gmatch("([_=^]*)([A-Ga-g])([',]*)(%d*/?%d*)") do
            local octave = base:match("%l") and 5 or 4
            for char in octaveMod:gmatch("[',]") do
                octave = octave + (char == "'" and 1 or -1)
            end
            local fullBase = accidental .. base:upper()
            local durToUse = (duration ~= "" and duration) or (chordDur ~= "" and chordDur) or "1"
            local ticks = Bard.getTicksFromLength(durToUse)
            local note = {
                rest = false,
                base = fullBase,
                octave = octave,
                ticks = ticks,
                explicitAccidental = (accidental ~= nil and accidental ~= "")
            }
            Bard.applyKeyAccidental(note, key)
            table.insert(notes, note)
        end

        return notes
    end

        -- this is a rest
    if token:match("^z") then
        local duration = token:match("^z(%d*/?%d*)") or "1"
        local ticks = Bard.getTicksFromLength(duration)
        return { { rest = true, ticks = ticks } }

    else
        -- Not a chord/rest/grace
        local notes = {}

        for accidental, base, octaveMod, duration in token:gmatch("([_=^]*)([A-Ga-g])([',]*)(%d*/?%d*)") do
            local octave = base:match("%l") and 5 or 4
            for char in octaveMod:gmatch("[',]") do
                octave = octave + (char == "'" and 1 or -1)
            end

            local fullBase = accidental .. base:upper()

            local ticks = Bard.getTicksFromLength(duration ~= "" and duration or "1")

            local note = {
                rest = false,
                base = fullBase,
                octave = octave,
                ticks = ticks,
                explicitAccidental = (accidental ~= nil and accidental ~= "")
            }

            Bard.applyKeyAccidental(note, key)
            table.insert(notes, note)
        end

        return notes
    end
end


function Bard.preprocessABC(abc)

    -- Normalize headers like "K: C" → "K:C"
    abc = abc:gsub("([A-Z]):%s+", "%1:")

    -- Insert default Key and Meter if missing
    if not abc:find("K:") then abc = "K:C\n" .. abc end
    if not abc:find("M:") then
        abc = "M:4/4\n" .. abc
    else
        abc = abc:gsub("M:%s*C|%s*", "M:2/2")
        abc = abc:gsub("M:%s*C%s*", "M:4/4")
    end
    -- Derive default L: based on M:, per the ABC 2.1 spec:
    -- if the meter ratio (top/bottom) is less than 0.75, default L is 1/16,
    -- otherwise it's 1/8. (There is no special "cut time -> 1/4" rule; the
    -- previous logic got 2/2, 3/2, 2/4, 3/8, 5/16, etc. wrong.)
    if not abc:find("L:") then
        local top, bottom = abc:match("M:(%d+)%s*/%s*(%d+)")
        if top and bottom then
            top, bottom = tonumber(top), tonumber(bottom)
            if (top / bottom) < 0.75 then
                abc = "L:1/16\n" .. abc
            else
                abc = "L:1/8\n" .. abc
            end
        else
            -- No readable M: found, fallback per spec
            abc = "L:1/8\n" .. abc
        end
    end

    -- Insert default tempo if missing
    if not abc:find("Q:") then
        abc = "Q:1/4=120\n" .. abc
    end

    -- Normalize durations like z/2 → z1/2
    abc = abc:gsub("z(/%d+)", "z1%1")
    abc = abc:gsub("([A-Ga-g])(/%d+)", "%11%2")

    -- Split into true lines first
    local lines = {}
    for line in abc:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local cleaned = {}

    for _, line in ipairs(lines) do
        local isHeaderLine = line:match("^%a:") ~= nil

        -- Strip quoted chord-symbol / annotation text (e.g. "Cmaj7", "^Fine")
        if not isHeaderLine then
            line = line:gsub('"[^"]*"', "")
        end

        if not isHeaderLine then
            line = line:gsub("([vu~.HLMOPTS])([_=^]?[A-Ga-g])", "%2") -- Remove decorations but keep notes
        end
        line = line:gsub("(%b[])%s*", "%1 ")   -- Add space after [chords]
        if not isHeaderLine then
            line = line:gsub("([_=^]?[A-Ga-g][',]*%d*/?%d*)%s*", "%1 ") -- Add space after single notes
        end
        line = line:gsub("(z%d*/?%d*)%s*", "%1 ") -- Add space after rests
        line = line:gsub("%%[^\n]*", "")   -- Remove comments

        local tupletPlaceholders = {}
        line = line:gsub("%(%d[:%d]*", function(m)
            table.insert(tupletPlaceholders, m)
            return "\1" .. #tupletPlaceholders .. "\1"
        end)

        line = line:gsub("[()]", "")

        -- Restore protected tuplet markers
        if #tupletPlaceholders > 0 then
            line = line:gsub("\1(%d+)\1", function(idx)
                return tupletPlaceholders[tonumber(idx)]
            end)
        end

        -- Remove ALL spaces inside true chords (skip [V:], [|] cases)
        line = line:gsub("%[(.-)%]", function(inner)
            local trimmed = inner:match("^%s*(.-)%s*$") or inner
            if trimmed:find("^V:") or trimmed:find("^|") then
                return "[" .. inner .. "]"
            else
                return "[" .. inner:gsub("%s+", "") .. "]"
            end
        end)

        --remove grace notes
        line = line:gsub("{[^}]*}", "")

        -- Remove decorations
        line = line:gsub("!.-!", "")

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
    local voiceOrder = {}
    local currentVoice = "default"
    voices[currentVoice] = {
        events = {},
        bpm = 180,
        key = "C",
        baseNoteLength = "1/8",
        defaultTicks = Bard.getTicksFromLength("1/8"),
        tempoNoteLength = "1/4",
        name = "default",
    }
    table.insert(voiceOrder, currentVoice)

    local currentTicks = {}
    currentTicks[currentVoice] = 0
    local totalTicks = 0

    local repeatBuffer = {}
    local recordingRepeat = false
    local inRepeat = false
    local currentEnding = nil
    local skipEnding = false
    local repeatPass = 1
    local insideVoltaEnding = false
    local fromStartBuffer = {}
    local tupletNotesRemaining = 0
    local tupletMultiplier = 1.0

    local brokenRhythm = nil
    local lastParsedNoteEvent = nil

    local curBPM = voices[currentVoice].bpm
    local curKey = voices[currentVoice].key
    local curBase = voices[currentVoice].baseNoteLength
    local curTempo = voices[currentVoice].tempoNoteLength

    local accMemory = {}
    local function resetMeasureMemory(v) accMemory[v] = {} end
    local function setAccidental(mem, v, octave, letter, seq)
        mem[v] = mem[v] or {}; mem[v][octave] = mem[v][octave] or {}; mem[v][octave][letter] = seq
    end
    local function getAccidental(mem, v, octave, letter)
        return mem[v] and mem[v][octave] and mem[v][octave][letter] or nil
    end
    resetMeasureMemory(currentVoice)

    for line in abc:gmatch("[^\r\n]+") do
        local header, value = line:match("^(%a):%s*(.+)$")

        if header == "T" or header == "X" or header == "%" then

        elseif header == "V" then
            local voiceId = value:match("^%s*(%S+)") or value
            local displayName = value:match('name%s*=%s*"([^"]*)"')
                    or value:match('nm%s*=%s*"([^"]*)"')
                    or voiceId

            currentVoice = voiceId
            accMemory[currentVoice] = accMemory[currentVoice] or {}
            if not voices[currentVoice] then
                voices[currentVoice] = {
                    events = {},
                    bpm = curBPM,
                    key = curKey,
                    baseNoteLength = curBase,
                    defaultTicks = Bard.getTicksFromLength(curBase),
                    tempoNoteLength = curTempo,
                    name = displayName,
                }
                table.insert(voiceOrder, currentVoice)
            end
            currentTicks[currentVoice] = currentTicks[currentVoice] or 0

        elseif header == "K" then
            voices[currentVoice].key = value

            curKey = value
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
                curTempo = noteLength
            else
                voices[currentVoice].tempoNoteLength = "1/4" -- Assume 1/4 note if not specified
                curTempo = "1/4"
            end

            curBPM = bpm
        elseif header == "L" then
            voices[currentVoice].baseNoteLength = value
            voices[currentVoice].defaultTicks = Bard.getTicksFromLength(value)

            curBase = value
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
                    repeatPass = 1
                    insideVoltaEnding = false

                elseif token == ":|" then
                    recordingRepeat = false
                    repeatPass = repeatPass + 1
                    skipEnding = false
                    insideVoltaEnding = false
                    local bufToUse = (#repeatBuffer > 0) and repeatBuffer or fromStartBuffer
                    for i = #bufToUse, 1, -1 do
                        table.insert(allTokens, tokenIndex + 1, bufToUse[i])
                    end
                    repeatBuffer = {}

                elseif token == ":|:" then
                    recordingRepeat = false
                    repeatPass = repeatPass + 1
                    skipEnding = false
                    insideVoltaEnding = false
                    local bufToUse = (#repeatBuffer > 0) and repeatBuffer or fromStartBuffer
                    for i = #bufToUse, 1, -1 do
                        table.insert(allTokens, tokenIndex + 1, bufToUse[i])
                    end
                    table.insert(allTokens, tokenIndex + 1 + #bufToUse, "|:")
                    repeatBuffer = {}

                elseif token:match("^|+$") or token:match("^|%]+$") then
                    resetMeasureMemory(currentVoice)
                    skipEnding = false
                    insideVoltaEnding = false
                    
                elseif token:match("^%[1$") or token:match("^%[2$") or token:match("^%[3$") then
                    currentEnding = tonumber(token:sub(2))
                    skipEnding = (currentEnding ~= repeatPass)
                    insideVoltaEnding = true

                elseif token:match("^%(%d") then
                    local n = tonumber(token:match("^%((%d)"))
                    if n and n > 0 then
                        tupletNotesRemaining = n
                        local tupletRatios = { [2]=3/2, [3]=2/3, [4]=3/4, [5]=4/5, [6]=2/3, [7]=4/7, [9]=2/3 }
                        tupletMultiplier = tupletRatios[n] or 1.0
                    end

                else
                    if token:find("[<>]") then
                        brokenRhythm = token:match("([<>])")
                        token = token:gsub("[<>]", "")
                    end

                    if not skipEnding and token ~= "" then
                        if recordingRepeat and not insideVoltaEnding then
                            table.insert(repeatBuffer, token)
                        end
                        table.insert(fromStartBuffer, token)

                        local isChord = token:match("^%b[]") ~= nil
                        local parsedNotes = Bard.parseNoteToken(token, voices[currentVoice].defaultTicks, voices[currentVoice].key)
                        if #parsedNotes > 0 then
                            for _, n in ipairs(parsedNotes) do
                                if not n.rest then
                                    local accSeq = n.base:match("^[_=^]+")
                                    local letter = n.base:sub(-1)
                                    if n.explicitAccidental and accSeq then
                                        setAccidental(accMemory, currentVoice, n.octave, letter, accSeq)
                                    else
                                        local memAcc = getAccidental(accMemory, currentVoice, n.octave, letter)
                                        if memAcc then n.base = memAcc .. letter end
                                    end
                                end
                            end

                            for _, note in ipairs(parsedNotes) do
                                if tupletNotesRemaining > 0 then
                                    note.ticks = math.max(1, math.floor(note.ticks * tupletMultiplier))
                                    tupletNotesRemaining = tupletNotesRemaining - 1
                                    if tupletNotesRemaining <= 0 then
                                        tupletMultiplier = 1.0
                                    end
                                end
                            end

                            if brokenRhythm and lastParsedNoteEvent then
                                local prevEvent = lastParsedNoteEvent
                                local origPrevTicks = prevEvent.ticks

                                if brokenRhythm == ">" then
                                    prevEvent.ticks = math.floor(prevEvent.ticks * 3 / 2)
                                    parsedNotes[1].ticks = math.floor(parsedNotes[1].ticks * 1 / 2)
                                elseif brokenRhythm == "<" then
                                    prevEvent.ticks = math.floor(prevEvent.ticks * 1 / 2)
                                    parsedNotes[1].ticks = math.floor(parsedNotes[1].ticks * 3 / 2)
                                end

                                prevEvent.durationMs = Bard.convertMusicTicksToMilliseconds(
                                    prevEvent.ticks,
                                    voices[currentVoice].bpm or 120,
                                    voices[currentVoice].baseNoteLength or "1/8",
                                    voices[currentVoice].tempoNoteLength or "1/4"
                                )

                                currentTicks[currentVoice] = currentTicks[currentVoice] + (prevEvent.ticks - origPrevTicks)

                                brokenRhythm = nil
                            end

                            local elapsedMs = Bard.convertMusicTicksToMilliseconds(
                                    currentTicks[currentVoice],
                                    voices[currentVoice].bpm or 120,
                                    voices[currentVoice].baseNoteLength or "1/8",
                                    voices[currentVoice].tempoNoteLength or "1/4"
                            )

                            local timeOffsetMs = math.floor(elapsedMs)

                            local chordStaggerMs = 4

                            if isChord and #parsedNotes > 1 then
                                for i, note in ipairs(parsedNotes) do
                                    local noteOffset = timeOffsetMs + ((i - 1) * chordStaggerMs)
                                    note.timeOffset = noteOffset
                                    note.durationMs = Bard.convertMusicTicksToMilliseconds(
                                            note.ticks,
                                            voices[currentVoice].bpm or 120,
                                            voices[currentVoice].baseNoteLength or "1/8",
                                            voices[currentVoice].tempoNoteLength or "1/4"
                                    )
                                    table.insert(voices[currentVoice].events, {
                                        timeOffset = timeOffsetMs + ((i - 1) * chordStaggerMs),
                                        notes = { note }
                                    })
                                end
                            else
                                for _, note in ipairs(parsedNotes) do
                                    note.timeOffset = timeOffsetMs
                                    note.durationMs = Bard.convertMusicTicksToMilliseconds(
                                            note.ticks,
                                            voices[currentVoice].bpm or 120,
                                            voices[currentVoice].baseNoteLength or "1/8",
                                            voices[currentVoice].tempoNoteLength or "1/4"
                                    )
                                    
                                end

                                table.insert(voices[currentVoice].events, {
                                    timeOffset = timeOffsetMs,
                                    notes = parsedNotes
                                })
                            end

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
                                totalTicks = math.max(totalTicks, currentTicks[currentVoice]) -- update total song ticks
                            end

                            lastParsedNoteEvent = parsedNotes[1] -- update for broken rhythm
                        end
                    end
                end

                tokenIndex = tokenIndex + 1
            end
        end
    end

    return voices, totalTicks, voiceOrder
end


---Lightweight scan for voice IDs referenced by V: headers, without doing a
---full parse. Used by the UI to decide whether to show the voice-picker
---button as the player edits/loads a tune (cheap enough to call on every
---text change, unlike Bard.parseABC).
---@param abc string
function Bard.getVoiceOrder(abc)
    local seen = {}
    local order = {}
    for line in (abc or ""):gmatch("[^\r\n]+") do
        local value = line:match("^V:%s*(.+)$")
        if value then
            local voiceId = value:match("^%s*(%S+)") or value
            local displayName = value:match('name%s*=%s*"([^"]*)"')
                    or value:match('nm%s*=%s*"([^"]*)"')
                    or voiceId
            if not seen[voiceId] then
                seen[voiceId] = true
                table.insert(order, { id = voiceId, name = displayName })
            end
        end
    end
    return order
end


function Bard.completeAction(player)
    local id = player:getUsername()
    if Bard.players[id] == false then return end    -- guard against re-entry

    local bard = Bard.players[id]
    if bard and bard.playingNotes then
        for _, note in ipairs(bard.playingNotes) do
            player:getEmitter():stopSound(note.id)
        end
    end
    Bard.players[id] = false

    local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
    local currentAction = actionQueue.queue[1]
    if currentAction and (currentAction.Type == "BardToTheBonePlayMusic") and currentAction.action then
        currentAction.action:forceStop()
    end

    Bard.players[id] = nil
end


function Bard.next(t) for k, _ in pairs(t) do return k end end

function Bard.startPlayback(player, abc, requestedVoice)
    local music, totalTicks, voiceOrder = Bard.parseABC(abc)

    local defaultVoiceName = "default"
    if requestedVoice and music[requestedVoice] then
        defaultVoiceName = requestedVoice
    elseif not music[defaultVoiceName] then
        defaultVoiceName = Bard.next(music)
    end

    local defaultVoice = music[defaultVoiceName]
    local bpm = defaultVoice.bpm
    local baseNoteLength = defaultVoice.baseNoteLength
    local tempoNoteLength = defaultVoice.tempoNoteLength or "1/4"

    local totalMilliseconds  = Bard.convertMusicTicksToMilliseconds(totalTicks, bpm, baseNoteLength, tempoNoteLength)
    local durationTicks = totalMilliseconds / (1000 / getAverageFPS())

    for _, voice in pairs(music) do voice.eventIndex = 1 end

    return music, durationTicks, voiceOrder --to convert ticks to milliseconds for playback deadline
end


function Bard.noteToMidi(note)
    local baseMap = {C=0, D=2, E=4, F=5, G=7, A=9, B=11}
    local accidentalOffset = {["^"] = 1, ["_"] = -1, ["="] = 0}
    local acc = note.base:sub(1, 1)
    local letter = note.base:sub(-1)
    local pitch = baseMap[letter] + (accidentalOffset[acc] or 0)
    return (note.octave + 1) * 12 + pitch
end


function Bard.midiToNote(midi, fallbackBase)
    local baseMap = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local pitchClass = midi % 12
    local octave = math.floor(midi / 12) - 1
    local name = baseMap[pitchClass + 1]
    local base = name:sub(1, 1)
    local acc = name:sub(2)
    local accidental = acc == "#" and "^" or (acc == "b" and "_" or "")
    return { base = accidental .. base, octave = octave, ticks = 1 }
end


function Bard.getSoundName(n)
    local mapped = Bard.accidental_map[n.base] or Bard.natural_map[n.base:sub(-1)]
    if not mapped then return nil end
    return mapped .. tostring(n.octave)
end


Bard.drumKitPieces = {
    [36] = "BassDrum1",     -- kick
    [38] = "AcousticSnare", -- snare (short drum on its own stand)
    [41] = "LowFloorTom",   -- floor tom (the tall standalone one)
    [47] = "LowMidTom",     -- rack tom 1 (one of the pair on top of the kick)
    [48] = "HiMidTom",      -- rack tom 2 (the other one of that pair)
    [49] = "CrashCymbal1",
    [51] = "RideCymbal1",
}

Bard.drumKitFallback = {
    [35] = 36, -- Acoustic Bass Drum   -> kick
    [37] = 38, -- Side Stick           -> snare
    [39] = 38, -- Hand Clap            -> snare
    [40] = 38, -- Electric Snare       -> snare
    [42] = 51, -- Closed Hi-Hat        -> ride (no hi-hat in this kit)
    [43] = 41, -- High Floor Tom       -> floor tom
    [44] = 51, -- Pedal Hi-Hat         -> ride (no hi-hat in this kit)
    [45] = 47, -- Low Tom              -> rack tom 1
    [46] = 49, -- Open Hi-Hat          -> crash (sustained "wash", closer to crash than a tom)
    [50] = 48, -- High Tom             -> rack tom 2
    [52] = 49, -- Chinese Cymbal       -> crash
    [53] = 51, -- Ride Bell            -> ride
    [54] = 51, -- Tambourine           -> ride
    [55] = 49, -- Splash Cymbal        -> crash
    [56] = 51, -- Cowbell              -> ride (closest to a "bell" tone here)
    [57] = 49, -- Crash Cymbal 2       -> crash
    [58] = 47, -- Vibraslap            -> rack tom 1
    [59] = 51, -- Ride Cymbal 2        -> ride
    [60] = 48, -- Hi Bongo             -> rack tom 2
    [61] = 47, -- Low Bongo            -> rack tom 1
    [62] = 48, -- Mute Hi Conga        -> rack tom 2
    [63] = 48, -- Open Hi Conga        -> rack tom 2
    [64] = 47, -- Low Conga            -> rack tom 1
    [65] = 48, -- High Timbale         -> rack tom 2
    [66] = 41, -- Low Timbale          -> floor tom
    [67] = 51, -- High Agogo           -> ride (bell-like)
    [68] = 47, -- Low Agogo            -> rack tom 1
    [69] = 51, -- Cabasa               -> ride
    [70] = 51, -- Maracas              -> ride
    [71] = 51, -- Short Whistle        -> ride
    [72] = 51, -- Long Whistle         -> ride
    [73] = 51, -- Short Guiro          -> ride
    [74] = 51, -- Long Guiro           -> ride
    [75] = 38, -- Claves               -> snare (rimshot-like click)
    [76] = 48, -- Hi Wood Block        -> rack tom 2
    [77] = 47, -- Low Wood Block       -> rack tom 1
    [78] = 47, -- Mute Cuica           -> rack tom 1
    [79] = 41, -- Open Cuica           -> floor tom
    [80] = 51, -- Mute Triangle        -> ride (bright/metallic)
    [81] = 51, -- Open Triangle        -> ride
}

---@param note table
---@param octaveShift number|nil optional correction if a given ABC source's
---       octave convention is off by whole octaves from this engine's C4=60
---@param pieces table|nil defaults to Bard.drumKitPieces
---@param fallback table|nil defaults to Bard.drumKitFallback
function Bard.percussionSoundName(note, octaveShift, pieces, fallback)
    if note.rest then return nil end
    pieces = pieces or Bard.drumKitPieces
    fallback = fallback or Bard.drumKitFallback

    local midi = Bard.noteToMidi(note) + ((octaveShift or 0) * 12)

    local sound = pieces[midi]
    if sound then return sound end

    local fallbackMidi = fallback[midi]
    return fallbackMidi and pieces[fallbackMidi]
end


Bard.soundCache = {}
---@param isPercussion boolean|nil
---@param octaveShift number|nil
---@param percussionPieces table|nil per-instrument override of Bard.drumKitPieces
---@param percussionFallback table|nil per-instrument override of Bard.drumKitFallback
function Bard.noteToSound(note, instrumentID, isPercussion, octaveShift, percussionPieces, percussionFallback)
    if note.rest then return nil end

    if isPercussion then
        local cacheKey = "PERC_" .. (instrumentID or "") .. "_" .. note.base .. tostring(note.octave)
        if Bard.soundCache[cacheKey] ~= nil then return Bard.soundCache[cacheKey] or nil end

        local sound = Bard.percussionSoundName(note, octaveShift, percussionPieces, percussionFallback)
        
        if sound and instrumentID and fileExists("media/sound/instruments/" .. instrumentID .. "/" .. sound .. ".ogg") then
            Bard.soundCache[cacheKey] = sound
            return sound
        end

        Bard.soundCache[cacheKey] = false
        return nil
    end

    local sound = Bard.getSoundName(note)
    local cacheKey = (instrumentID or "") .. "_" .. (sound or "?")
    if Bard.soundCache[cacheKey] ~= nil then return Bard.soundCache[cacheKey] or nil end

    if sound and instrumentID and fileExists("media/sound/instruments/" .. instrumentID .. "/" .. sound .. ".ogg") then
        Bard.soundCache[cacheKey] = sound
        return sound
    end

    -- Search nearby notes (±12 semitones)
    local semitoneOffsets = {}
    local isFlat = sound ~= nil and sound:sub(2, 2) == "b"
    for i = 1, 12 do
        if isFlat then
            table.insert(semitoneOffsets, -i)
            table.insert(semitoneOffsets, i)
        else
            table.insert(semitoneOffsets, i)
            table.insert(semitoneOffsets, -i)
        end
    end

    for _, offset in ipairs(semitoneOffsets) do
        local newNote = { base = note.base, octave = note.octave }
        local midi = Bard.noteToMidi(newNote)
        midi = midi + offset
        if midi >= 0 and midi <= 127 then
            newNote = Bard.midiToNote(midi, note.base)
            local altSound = Bard.getSoundName(newNote)
            if altSound and instrumentID and fileExists("media/sound/instruments/" .. instrumentID .. "/" .. altSound .. ".ogg") then
                Bard.soundCache[cacheKey] = altSound
                return altSound
            end
        end
    end

    Bard.soundCache[cacheKey] = false
    return nil
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.playLoadedSongs(player)
    if not player then return end
    local id = player:getUsername()
    local bard = Bard.players[id]
    if not bard then return end

    local music = bard.music
    local decay = bard.decay or 200
    local instrumentID = bard.instrumentID .. (bard.style or "")
    local isPercussion = bard.isPercussion
    local percussionOctaveShift = bard.percussionOctaveShift
    local percussionPieces = bard.percussionPieces
    local percussionFallback = bard.percussionFallback
    local selectedVoice = bard.selectedVoice -- nil or "All" => play every voice (old behavior)

    -- Initialize start and elapsed tracking if not already
    bard.startTime = bard.startTime or getTimestampMs()
    bard.lastUpdateTime = bard.lastUpdateTime or bard.startTime
    bard.elapsedTime = bard.elapsedTime or 0

    local now = getTimestampMs()
    local speedMultiplier = getGameSpeed()

    -- If game is paused, don't advance music, but still update lastUpdateTime to avoid jump later
    if speedMultiplier == 0 then
        bard.lastUpdateTime = now
        return
    end

    -- Advance elapsed time, scaled by speed
    bard.elapsedTime = bard.elapsedTime + (now - bard.lastUpdateTime) * speedMultiplier
    bard.lastUpdateTime = now

    bard.playingNotes = bard.playingNotes or {}

    local allDone = true

    for voiceId, data in pairs(music) do
        local isPlayed = (not selectedVoice) or selectedVoice == "All" or voiceId == selectedVoice

        if isPlayed then
        data.eventIndex = data.eventIndex or 1

        while data.eventIndex <= #data.events do
            local event = data.events[data.eventIndex]
            local eventTime = event.timeOffset

            local latencyBufferMs = 30
            if bard.elapsedTime + latencyBufferMs >= eventTime then
                for _, note in ipairs(event.notes) do
                    local sound = Bard.noteToSound(note, instrumentID, isPercussion, percussionOctaveShift, percussionPieces, percussionFallback)
                    if sound then
                        local instrumentSound = instrumentID and instrumentID .. "_" .. sound
                        ---print("ElapsedTime: "..bard.elapsedTime.."  Play: ", instrumentSound, " (", event.timeOffset, ")")
                        if instrumentID then
                            local soundID = player:getEmitter():playSound(instrumentSound)
                            player:getEmitter():setVolume(soundID, bard.volume/100)

                            table.insert(bard.playingNotes, {
                                id = soundID,
                                started = bard.elapsedTime,
                                duration = note.durationMs
                            })

                            addSound(player, player:getX(), player:getY(), player:getZ(), 20, 10)
                        end
                    end
                end

                data.eventIndex = data.eventIndex + 1
            else
                allDone = false
                break
            end
        end
        end
    end

    ---This keeps total notes that are active capped, stops the oldest note per tick
    --- as well as cuts notes off after their intended length + handles per instrument decay
    --decay is stored above, prior to instrumentID being set
    local playingNotes = {}
    for n, note in ipairs(bard.playingNotes) do
        local noteID = note.id
        if player:getEmitter():isPlaying(noteID) then
            local timeSinceStart = bard.elapsedTime - note.started

            if timeSinceStart >= note.duration + decay then
                player:getEmitter():stopSound(noteID)
            elseif #bard.playingNotes > 40 and n == 1 then
                player:getEmitter():stopSound(noteID)
            else
                if timeSinceStart >= note.duration then
                    -- In decay phase
                    local fadeProgress = (timeSinceStart - note.duration) / decay
                    local fadeVolume = bard.volume / 100 * (1 - fadeProgress)
                    fadeVolume = math.max(0, math.min(1, fadeVolume))
                    player:getEmitter():setVolume(noteID, fadeVolume)
                else
                    -- Still sustaining at full volume
                    player:getEmitter():setVolume(noteID, bard.volume / 100)
                end

                table.insert(playingNotes, note)
            end
        end
    end

    bard.playingNotes = playingNotes

    if allDone and (#playingNotes <= 0) then Bard.completeAction(player) end
end


Bard.instrumentSpecials = {}

function Bard.instrumentSpecials.sexySax(player)
    if ZombRand(100) < 7 then
        player:setVariable("BttB_Special", "BttB_SexySaxPlaying")
    end
end

---THESE MATCH THE SOUNDS IN SCRIPTS/sounds_BardToTheBone
-- The folders in sound/instruments/ are used as IDs
-- SEE: python script `autoGenSoundScripts.py`
Bard.instrumentData = {
    ["Base.Banjo"] = { decay = 300, soundDir = "banjo", anim = "strumming" },
    ["Base.GuitarAcoustic"] = { decay = 600, soundDir = "guitar", anim = "strumming" },
    ["Base.GuitarElectric"] = { decay = 800, soundDir = "electric_guitar", anim = "strumming", styles = { "Clean","Muted","Overdrive","Distortion","Harmonics" }, },
    ["Base.GuitarElectricBass"] = { decay = 900, soundDir = "electric_bass", anim = "strumming" },
    ["Base.Keytar"] = { decay = 700, soundDir = "keytar", anim = "Keytar", styles = { "Square","Sawtooth","Calliope","Chiff","Charang","Voice","Fifths","Brass" }, },
    ["Base.Harmonica"] = { decay = 200, soundDir = "harmonica", anim = "Harmonica" },
    ["Base.Saxophone"] = { decay = 400, soundDir = "saxophone", anim = "SaxPlaying", special = "sexySax"},
    ["Base.Violin"] = { decay = 100, soundDir = "violin", anim = "Violin", left = "Violin_Bow", right = "Violin" },
    ["Base.Xylophone"] = { decay = 250, soundDir = "xylophone", anim = "Xylophone", left = "Xylophone_Mallet", right = "Xylophone"},
    ["Base.Flute"] = { decay = 300, soundDir = "flute", anim = "Flute" },
    ["Base.Rubberducky"] = { decay = 150, soundDir = "bikehorn", anim = "Rubberducky", },
    ["Base.Trumpet"] = { decay = 500, soundDir = "trumpet", anim = "Trumpet" },
    ["Base.Whistle"] = { decay = 200, soundDir = "whistle", anim = "Whistle"},
    ["Base.Whistle_Bone"] = { decay = 200, soundDir = "whistle", anim = "Whistle"},
}


---SIMILAR TO ABOVE, BUT WITH MAPOBJECTS' GROUPNAMES, GETS POPULATED FIRST TIME `getInstrumentData` IS CALLED.
Bard.instrumentMapObjectData = {
    --[""] = { soundDir = "", anim = ""},
    ---["Kick Drum"] = { soundDir = "", anim = ""},
    ---["Tom Drum"] = { soundDir = "", anim = ""},
    ---["Snare Drum"] = { soundDir = "", anim = ""},

    --recreational_01_12,13  8,9
    ["Piano"] = { decay = 500, soundDir = "piano", anim = "Piano",
                  sprites = { "recreational_01_12", "recreational_01_13", "recreational_01_8", "recreational_01_9", }
    },

    --recreational_01_40,41  48,49
    ["Grand Piano"] = { decay = 800, soundDir = "grandPiano", anim = "Piano",
                        sprites = { "recreational_01_40", "recreational_01_41", "recreational_01_48", "recreational_01_49", }
    },


    ["Drum"] = { decay = 120, soundDir = "drumkit", anim = "Xylophone", isPercussion = true,
                      sprites = { "recreational_01_56", "recreational_01_57", "recreational_01_58", "recreational_01_59", "recreational_01_60", "recreational_01_61",
                                  "recreational_01_64", "recreational_01_65", "recreational_01_66", "recreational_01_67", "recreational_01_68", "recreational_01_69", },
    },

    ["Kick Drum"] = { decay = 120, soundDir = "drumkit", anim = "Xylophone", isPercussion = true,
                      sprites = { "recreational_01_56", "recreational_01_57", "recreational_01_58", "recreational_01_59", "recreational_01_60", "recreational_01_61",
                                  "recreational_01_64", "recreational_01_65", "recreational_01_66", "recreational_01_67", "recreational_01_68", "recreational_01_69", },
    },
    ["Tom Drum"] = { decay = 120, soundDir = "drumkit", anim = "Xylophone", isPercussion = true,
                     sprites = { "recreational_01_56", "recreational_01_57", "recreational_01_58", "recreational_01_59", "recreational_01_60", "recreational_01_61",
                                 "recreational_01_64", "recreational_01_65", "recreational_01_66", "recreational_01_67", "recreational_01_68", "recreational_01_69", },
    },
    ["Snare Drum"] = { decay = 120, soundDir = "drumkit", anim = "Xylophone", isPercussion = true,
                       sprites = { "recreational_01_56", "recreational_01_57", "recreational_01_58", "recreational_01_59", "recreational_01_60", "recreational_01_61",
                                   "recreational_01_64", "recreational_01_65", "recreational_01_66", "recreational_01_67", "recreational_01_68", "recreational_01_69", },
    },

}

Bard.populatedFromMapObjectData = false
function Bard.populateMapObjectData()
    if Bard.populatedFromMapObjectData then return end

    for name,data in pairs(Bard.instrumentMapObjectData) do
        local populatedSprites = {}
        for _,sprite in pairs(data.sprites) do
            populatedSprites[sprite] = true
        end
        Bard.instrumentData[name] = data
        Bard.instrumentData[name].playFromSprites = populatedSprites
    end

    Bard.populatedFromMapObjectData = true
end


Bard.validChecks = {}
function Bard.validChecks.bottleIsEmpty(item)
    local fluid = item:getFluidContainer()
    return fluid and fluid:isEmpty()
end

---SIMILAR TO ABOVE, BUT WITH TAGS, GETS POPULATED FIRST TIME `getInstrumentData` IS CALLED.
Bard.instrumentTagData = {
    [ItemTag.GLASS_BOTTLE] = { decay = 350, soundDir = "bottle", anim = "Bottle", validCheck = "bottleIsEmpty"},
}

Bard.populatedFromTagData = false

function Bard.populateTagData()
    if Bard.populatedFromTagData then return end

    for tag,data in pairs(Bard.instrumentTagData) do
        local items = getScriptManager():getItemsTag(tag)
        for i=0,items:size()-1 do
            ---@type Item
            local item = items:get(i)
            local moduleDotType = item:getFullName()
            Bard.instrumentData[moduleDotType] = data
        end
    end

    Bard.populatedFromTagData = true
end


---@param instrument InventoryItem|IsoObject
function Bard.getInstrumentData(instrument)
    Bard.populateTagData()
    Bard.populateMapObjectData()
    if not instrument then return end

    local data

    if instanceof(instrument, "IsoObject") then

        local properties = instrument:getProperties()
        local name = properties and properties:has("CustomName") and properties:get("CustomName")
        if name then
            data = Bard.instrumentData[name]
        end
    end

    if instanceof(instrument, "InventoryItem") then
        data = Bard.instrumentData[instrument:getFullType()]
    end

    if data and data.validCheck then if not Bard.validChecks[data.validCheck](instrument) then return end end

    return data
end


return Bard