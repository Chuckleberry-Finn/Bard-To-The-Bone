local netWorkHandler = require "BardToTheBone_networkHandler"
local modOptions = require "BardToTheBone_modOptions"

local Bard = {}

Bard.voices = {}
Bard.players = {}
Bard.remotePlayers = {}
Bard.networkSequence = 0
Bard.networkBatchMs = 200
Bard.networkDelayMs = 150
Bard.remoteIdleMs = 5000
Bard.minimumBareTempo = 20
Bard.ampRange = 3
Bard.ampCheckMs = 2000
Bard.unpluggedVolume = 0.5
Bard.ampNoiseRadius = 40
Bard.ampNames = { ["Guitar Amplifier"] = true }
Bard.ampSprites = { ["recreational_01_72"] = true }
Bard.clock = { requested = 0 }
Bard.clockRefreshMs = 60000
Bard.bandDelayMs = 500
Bard.bandJoinWindowMs = 3000
Bard.xpPerMinute = 10
Bard.xpSendMs = 5000
Bard.xpActiveMs = 2000
Bard.familiarPlayMs = 30000
Bard.familiarBonus = 0.04
Bard.familiarMaxPlays = 5
Bard.newInstrumentMs = 900000
Bard.newInstrumentBonus = 0.25
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
    if not length or length == "" then return baseTicks end
    if length:find("/") then
        local num, slashes, den = length:match("^(%d*)(/+)(%d*)$")
        if not slashes then return baseTicks end
        num = tonumber(num) or 1
        den = tonumber(den) or (2 ^ #slashes)
        return baseTicks * (num / den)
    elseif tonumber(length) then
        return baseTicks * tonumber(length)
    end
    return baseTicks
end


function Bard.getBarTicks(meter, baseNoteLength)
    local top, bottom = (meter or ""):match("(%d+)%s*/%s*(%d+)")
    top, bottom = tonumber(top) or 4, tonumber(bottom) or 4
    local lTop, lBottom = (baseNoteLength or ""):match("(%d+)%s*/%s*(%d+)")
    lTop, lBottom = tonumber(lTop) or 1, tonumber(lBottom) or 8
    return 120 * (top / bottom) / (lTop / lBottom)
end


Bard.tupletDefaults = { [2] = 3, [3] = 2, [4] = 3, [6] = 2, [8] = 3 }

function Bard.getTupletDefault(p, meter)
    if Bard.tupletDefaults[p] then return Bard.tupletDefaults[p] end
    local top, bottom = (meter or ""):match("(%d+)%s*/%s*(%d+)")
    top, bottom = tonumber(top), tonumber(bottom)
    local compound = bottom == 8 and (top == 6 or top == 9 or top == 12)
    return compound and 3 or 2
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


function Bard.parseNoteToken(token, defaultTicks, key, barTicks)

    local chordBody, chordDur, chordTie = token:match("^(%b[])([%d/]*)(%-?)$")
    if chordBody then
        local inner = chordBody:sub(2, -2)
        local chordMultiplier = Bard.getTicksFromLength(chordDur) / 120
        local notes = {}
        for accidental, base, octaveMod, duration, tie in inner:gmatch("([_=^]*)([A-Ga-gzx])([',]*)([%d/]*)(%-?)") do
            if base == "z" or base == "x" then
                table.insert(notes, { rest = true, ticks = Bard.getTicksFromLength(duration) * chordMultiplier })
            else
                local octave = base:match("%l") and 5 or 4
                for char in octaveMod:gmatch("[',]") do
                    octave = octave + (char == "'" and 1 or -1)
                end
                local note = {
                    rest = false,
                    base = accidental .. base:upper(),
                    octave = octave,
                    ticks = Bard.getTicksFromLength(duration) * chordMultiplier,
                    explicitAccidental = (accidental ~= nil and accidental ~= ""),
                    tie = (tie == "-") or (chordTie == "-"),
                }
                Bard.applyKeyAccidental(note, key)
                table.insert(notes, note)
            end
        end

        return notes
    end

    local restDur = token:match("^[zx]([%d/]*)$")
    if restDur then
        return { { rest = true, ticks = Bard.getTicksFromLength(restDur) } }
    end

    local bars = token:match("^Z(%d*)$")
    if bars then
        return { { rest = true, ticks = (tonumber(bars) or 1) * (barTicks or 960) } }
    end

    local notes = {}

    for accidental, base, octaveMod, duration, tie in token:gmatch("([_=^]*)([A-Ga-g])([',]*)([%d/]*)(%-?)") do
        local octave = base:match("%l") and 5 or 4
        for char in octaveMod:gmatch("[',]") do
            octave = octave + (char == "'" and 1 or -1)
        end

        local note = {
            rest = false,
            base = accidental .. base:upper(),
            octave = octave,
            ticks = Bard.getTicksFromLength(duration),
            explicitAccidental = (accidental ~= nil and accidental ~= ""),
            tie = (tie == "-"),
        }

        Bard.applyKeyAccidental(note, key)
        table.insert(notes, note)
    end

    return notes
end

function Bard.normalizeBar(run, closed)
    local leading = run:sub(1, 1) == ":"
    local trailing = run:sub(-1) == ":"
    if leading and trailing then return ":|:" end
    if leading then return ":|" end
    if trailing then return "|:" end
    if closed then return "|]" end
    return "|"
end


---Splits one line of music into tokens. Inline fields like [K:G] or [V:2] become their own header lines.
---@param line string
function Bard.tokenizeMusicLine(line)
    local lines, tokens = {}, {}
    local function flush()
        if #tokens > 0 then
            table.insert(lines, table.concat(tokens, " "))
            tokens = {}
        end
    end

    local i, len = 1, #line
    while i <= len do
        local c = line:sub(i, i)
        local nextChar = line:sub(i + 1, i + 1)

        if c == "!" or c == "+" then
            local close = line:find(c, i + 1, true)
            i = (close or len) + 1

        elseif c == "{" then
            local close = line:find("}", i + 1, true)
            i = (close or len) + 1

        elseif c == "[" and nextChar:match("%a") and line:sub(i + 2, i + 2) == ":" then
            local close = line:find("]", i + 1, true) or (len + 1)
            flush()
            table.insert(lines, line:sub(i + 1, close - 1))
            i = close + 1

        elseif c == "[" and nextChar:match("%d") then
            table.insert(tokens, "[" .. nextChar)
            i = i + 2

        elseif c == "|" or c == ":" or (c == "[" and nextChar == "|") then
            local start = (c == "[") and (i + 1) or i
            local run = line:match("^[|:]+", start)
            local stop = start + #run
            local closed = line:sub(stop, stop) == "]" and run:sub(-1) == "|"
            if closed then stop = stop + 1 end

            if run:find("|", 1, true) or run == "::" then
                table.insert(tokens, Bard.normalizeBar(run, closed))
                local volta = line:match("^%d", stop)
                if volta then
                    table.insert(tokens, "[" .. volta)
                    stop = stop + 1
                end
            end
            i = stop

        elseif c == "[" then
            local close = line:find("]", i + 1, true) or (len + 1)
            local chordNotes = {}
            local inner = line:sub(i + 1, close - 1):gsub("!.-!", ""):gsub("%+.-%+", "")
            for note in inner:gmatch("[_=^]*[A-Ga-gzx][',]*[%d/]*%-?") do
                table.insert(chordNotes, note)
            end
            local suffix = line:match("^[%d/]*%-?", close + 1) or ""
            if #chordNotes > 0 then
                table.insert(tokens, "[" .. table.concat(chordNotes) .. "]" .. suffix)
            end
            i = close + 1 + #suffix

        elseif c == "(" and nextChar:match("%d") then
            local tuplet = line:match("^%(%d+[:%d]*", i)
            table.insert(tokens, tuplet)
            i = i + #tuplet

        elseif c:match("[_=^A-Ga-g]") then
            local note = line:match("^[_=^]*[A-Ga-g][',]*[%d/]*%-?", i)
            if note then
                table.insert(tokens, note)
                i = i + #note
            else
                i = i + 1
            end

        elseif c == "z" or c == "x" then
            local rest = line:match("^[zx][%d/]*", i)
            table.insert(tokens, "z" .. rest:sub(2))
            i = i + #rest

        elseif c == "Z" then
            local rest = line:match("^Z%d*", i)
            table.insert(tokens, rest)
            i = i + #rest

        elseif c == ">" or c == "<" then
            local broken = line:match("^[<>]+", i)
            table.insert(tokens, broken)
            i = i + #broken

        elseif c == "-" then
            local last = tokens[#tokens]
            if last and (last:match("^[_=^]*[A-Ga-g]") or last:match("^%[[^%d]")) and last:sub(-1) ~= "-" then
                tokens[#tokens] = last .. "-"
            end
            i = i + 1

        else
            i = i + 1
        end
    end

    flush()
    return lines
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

    local cleaned = {}

    for line in abc:gmatch("[^\r\n]+") do
        local isHeaderLine = line:match("^%a:") ~= nil

        if isHeaderLine then
            line = line:gsub("%%[^\n]*", "")   -- Remove comments
            line = line:match("^%s*(.-)%s*$") or line
            if line ~= "" then table.insert(cleaned, line) end
        else
            -- Strip quoted chord-symbol / annotation text (e.g. "Cmaj7", "^Fine")
            line = line:gsub('"[^"]*"', "")
            line = line:gsub("%%[^\n]*", "")   -- Remove comments

            for _, musicLine in ipairs(Bard.tokenizeMusicLine(line)) do
                table.insert(cleaned, musicLine)
            end
        end
    end

    abc = table.concat(cleaned, "\n")

    -- Optional: log processed output
    ---print("\nPROCESSED ABC:  ("..tag..")\n", abc, "\n\n_______")

    return abc
end

function Bard.parseABC(abc)
    local percussionVoiceIds = Bard.getPercussionVoiceIds(abc)

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
        meter = "4/4",
        name = "default",
    }
    table.insert(voiceOrder, currentVoice)

    local voiceTime = {}
    voiceTime[currentVoice] = 0
    local pendingTies = {}
    pendingTies[currentVoice] = {}
    local totalTime = 0
    local tuneNumber = 1
    local hasNotes = false

    local repeatBuffer = {}
    local recordingRepeat = false
    local currentEnding = nil
    local skipEnding = false
    local repeatPass = 1
    local insideVoltaEnding = false
    local fromStartBuffer = {}
    local tupletNotesRemaining = 0
    local tupletMultiplier = 1.0

    local brokenRhythm = nil
    local lastParsedNotes = nil
    local lastAdvanceTicks = 0

    local curBPM = voices[currentVoice].bpm
    local curKey = voices[currentVoice].key
    local curBase = voices[currentVoice].baseNoteLength
    local curTempo = voices[currentVoice].tempoNoteLength
    local curMeter = voices[currentVoice].meter

    local chordStaggerMs = 4

    local accMemory = {}
    local function resetMeasureMemory(v) accMemory[v] = {} end
    local function setAccidental(mem, v, octave, letter, seq)
        mem[v] = mem[v] or {}; mem[v][octave] = mem[v][octave] or {}; mem[v][octave][letter] = seq
    end
    local function getAccidental(mem, v, octave, letter)
        return mem[v] and mem[v][octave] and mem[v][octave][letter] or nil
    end
    resetMeasureMemory(currentVoice)

    local function toMs(ticks)
        local voice = voices[currentVoice]
        return Bard.convertMusicTicksToMilliseconds(ticks, voice.bpm or 120, voice.baseNoteLength or "1/8", voice.tempoNoteLength or "1/4")
    end

    local function recordToken(token)
        if recordingRepeat and not insideVoltaEnding then
            table.insert(repeatBuffer, token)
        end
        table.insert(fromStartBuffer, token)
    end

    local function ensureVoice(voiceId, displayName)
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
                meter = curMeter,
                name = displayName,
                isPercussionVoice = percussionVoiceIds[currentVoice] or false,
            }
            table.insert(voiceOrder, currentVoice)
        end
        voiceTime[currentVoice] = voiceTime[currentVoice] or 0
        pendingTies[currentVoice] = pendingTies[currentVoice] or {}
        lastParsedNotes = nil
    end

    local function startNewTune()
        tuneNumber = tuneNumber + 1
        curKey = "C"
        ensureVoice(Bard.getTuneVoiceId(tuneNumber, "default"), "Part " .. tuneNumber)
        repeatBuffer = {}
        fromStartBuffer = {}
        recordingRepeat = false
        repeatPass = 1
        skipEnding = false
        insideVoltaEnding = false
        tupletNotesRemaining = 0
        tupletMultiplier = 1.0
        brokenRhythm = nil
        lastParsedNotes = nil
    end

    local function applyHeader(header, value)
        if header == "X" then
            if hasNotes then startNewTune() end

        elseif header == "T" then
            if tuneNumber > 1 and currentVoice == Bard.getTuneVoiceId(tuneNumber, "default") then
                voices[currentVoice].name = value
            end

        elseif header == "V" then
            local voiceId = value:match("^%s*(%S+)") or value
            local displayName = value:match('name%s*=%s*"([^"]*)"')
                    or value:match('nm%s*=%s*"([^"]*)"')
                    or voiceId

            ensureVoice(Bard.getTuneVoiceId(tuneNumber, voiceId), displayName)

        elseif header == "K" then
            voices[currentVoice].key = value
            curKey = value

        elseif header == "Q" then
            local noteLength, bpm = value:match("(%d+%s*/%s*%d+)%s*=%s*(%d+)")
            if bpm then
                bpm = tonumber(bpm)
            else
                bpm = tonumber(value:match("%d+")) or 120
                if bpm < Bard.minimumBareTempo then bpm = 120 end
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
            voices[currentVoice].meter = value
            curMeter = value
        end
    end

    for line in abc:gmatch("[^\r\n]+") do
        local header, value = line:match("^(%a):%s*(.+)$")

        if header then
            applyHeader(header, value)

        else
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

                elseif token == "|" or token == "|]" then
                    if not skipEnding then recordToken(token) end
                    resetMeasureMemory(currentVoice)
                    skipEnding = false
                    insideVoltaEnding = false

                elseif token:match("^%[%d$") then
                    currentEnding = tonumber(token:sub(2))
                    skipEnding = (currentEnding ~= repeatPass)
                    insideVoltaEnding = true

                elseif token:match("^%(%d") then
                    if not skipEnding then
                        recordToken(token)
                        local p, q, r = token:match("^%((%d+):?(%d*):?(%d*)")
                        p = tonumber(p)
                        if p and p > 0 then
                            q = tonumber(q) or Bard.getTupletDefault(p, voices[currentVoice].meter)
                            tupletNotesRemaining = tonumber(r) or p
                            tupletMultiplier = q / p
                        end
                    end

                elseif token:match("^[<>]+$") then
                    if not skipEnding then
                        recordToken(token)
                        brokenRhythm = token
                    end

                elseif not skipEnding then
                    recordToken(token)

                    local voice = voices[currentVoice]
                    local isChord = token:match("^%[") ~= nil
                    local parsedNotes = Bard.parseNoteToken(token, voice.defaultTicks, voice.key, Bard.getBarTicks(voice.meter, voice.baseNoteLength))
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

                        if tupletNotesRemaining > 0 then
                            for _, note in ipairs(parsedNotes) do
                                note.ticks = note.ticks * tupletMultiplier
                            end
                            tupletNotesRemaining = tupletNotesRemaining - 1
                            if tupletNotesRemaining <= 0 then
                                tupletMultiplier = 1.0
                            end
                        end

                        if brokenRhythm and lastParsedNotes then
                            local shortFactor = 0.5 ^ #brokenRhythm
                            local longFactor = 2 - shortFactor
                            local lengthenFirst = brokenRhythm:sub(1, 1) == ">"
                            local prevFactor = lengthenFirst and longFactor or shortFactor
                            local nextFactor = lengthenFirst and shortFactor or longFactor

                            for _, n in ipairs(lastParsedNotes) do
                                n.ticks = n.ticks * prevFactor
                                if n.durationMs then n.durationMs = n.durationMs * prevFactor end
                            end
                            voiceTime[currentVoice] = voiceTime[currentVoice] + toMs((lastAdvanceTicks * prevFactor) - lastAdvanceTicks)

                            for _, n in ipairs(parsedNotes) do
                                n.ticks = n.ticks * nextFactor
                            end
                        end
                        brokenRhythm = nil

                        local advanceTicks = parsedNotes[1].ticks or 0
                        if isChord then
                            for _, chordNote in ipairs(parsedNotes) do
                                if chordNote.ticks and chordNote.ticks < advanceTicks then advanceTicks = chordNote.ticks end
                            end
                        end

                        local timeOffsetMs = math.floor(voiceTime[currentVoice])
                        local ties = pendingTies[currentVoice] or {}
                        local nextTies = {}
                        local playable = {}

                        for _, note in ipairs(parsedNotes) do
                            if not note.rest then
                                note.durationMs = toMs(note.ticks)
                                local midi = Bard.noteToMidi(note)
                                local tiedFrom = ties[midi]
                                if tiedFrom then
                                    tiedFrom.durationMs = math.max(tiedFrom.durationMs, timeOffsetMs + note.durationMs - tiedFrom.timeOffset)
                                    if note.tie then nextTies[midi] = tiedFrom end
                                else
                                    table.insert(playable, note)
                                    if note.tie then nextTies[midi] = note end
                                end
                            end
                        end
                        pendingTies[currentVoice] = nextTies

                        if isChord and #playable > 1 then
                            for i, note in ipairs(playable) do
                                note.timeOffset = timeOffsetMs + ((i - 1) * chordStaggerMs)
                                table.insert(voice.events, {
                                    timeOffset = note.timeOffset,
                                    notes = { note }
                                })
                            end
                        elseif #playable > 0 then
                            for _, note in ipairs(playable) do
                                note.timeOffset = timeOffsetMs
                            end
                            table.insert(voice.events, {
                                timeOffset = timeOffsetMs,
                                notes = playable
                            })
                        end

                        voiceTime[currentVoice] = voiceTime[currentVoice] + toMs(advanceTicks)
                        totalTime = math.max(totalTime, voiceTime[currentVoice]) -- update total song time
                        lastParsedNotes = parsedNotes -- update for broken rhythm
                        lastAdvanceTicks = advanceTicks
                        hasNotes = true
                    end
                end

                tokenIndex = tokenIndex + 1
            end
        end
    end

    local firstOffset
    for _, voice in pairs(voices) do
        local first = voice.events[1]
        if first and ((not firstOffset) or first.timeOffset < firstOffset) then
            firstOffset = first.timeOffset
        end
    end

    if firstOffset and firstOffset > 0 then
        for _, voice in pairs(voices) do
            for _, event in ipairs(voice.events) do
                event.timeOffset = event.timeOffset - firstOffset
                for _, note in ipairs(event.notes) do
                    note.timeOffset = event.timeOffset
                end
            end
        end
        totalTime = totalTime - firstOffset
    end

    return voices, totalTime, voiceOrder
end

function Bard.getPercussionVoiceIds(abc)
    local flagged = {}
    local currentVoice = "default"
    for line in (abc or ""):gmatch("[^\r\n]+") do
        local vValue = line:match("^V:%s*(.+)$")
        if vValue then
            currentVoice = vValue:match("^%s*(%S+)") or vValue
            if currentVoice == "10" then flagged[currentVoice] = true end
        elseif line:match("^%%%%MIDI%s+channel%s+10%s*$") then
            flagged[currentVoice] = true
        end
    end
    return flagged
end


---Lightweight scan for voice IDs referenced by V: headers, without doing a
---full parse. Used by the UI to decide whether to show the voice-picker
---button as the player edits/loads a tune (cheap enough to call on every
---text change, unlike Bard.parseABC).
---@param abc string
function Bard.getTuneVoiceId(tuneNumber, voiceId)
    if tuneNumber <= 1 then return voiceId end
    return tuneNumber .. ":" .. voiceId
end


function Bard.getVoiceOrder(abc)
    local seen = {}
    local order = {}
    local function addVoice(voiceId, displayName)
        if not seen[voiceId] then
            seen[voiceId] = true
            table.insert(order, { id = voiceId, name = displayName })
        end
    end

    local tuneCount = 0
    for _ in (abc or ""):gmatch("\nX:") do tuneCount = tuneCount + 1 end
    if (abc or ""):match("^X:") then tuneCount = tuneCount + 1 end

    local tuneNumber = 0
    for line in (abc or ""):gmatch("[^\r\n]+") do
        if line:match("^X:") then
            tuneNumber = tuneNumber + 1
        end

        local title = line:match("^T:%s*(.-)%s*$")
        if title and tuneCount > 1 and tuneNumber >= 1 then
            addVoice(Bard.getTuneVoiceId(tuneNumber, "default"), title)
        end

        local values = {}
        local headerValue = line:match("^V:%s*(.+)$")
        if headerValue then table.insert(values, headerValue) end
        for inlineValue in line:gmatch("%[V:%s*([^%]]+)%]") do table.insert(values, inlineValue) end

        for _, value in ipairs(values) do
            local voiceId = value:match("^%s*(%S+)") or value
            local displayName = value:match('name%s*=%s*"([^"]*)"')
                    or value:match('nm%s*=%s*"([^"]*)"')
                    or voiceId
            addVoice(Bard.getTuneVoiceId(math.max(tuneNumber, 1), voiceId), displayName)
        end
    end
    return order
end


---@param skipQueueStop boolean|nil pass true when called from BardToTheBonePlayMusic:perform()/
function Bard.completeAction(player, skipQueueStop, finished, paused)
    local id = player:getUsername()
    if Bard.players[id] == false then return end    -- guard against re-entry

    local bard = Bard.players[id]
    if bard and bard.mistakes then
        Bard.flushMusicXp(player, bard)
        if bard.songKey and (not paused) and (finished or bard.activeMs >= Bard.familiarPlayMs) then
            local data = Bard.getMusicData(player)
            data.songs[bard.songKey] = (data.songs[bard.songKey] or 0) + 1
        end
    end
    if bard and bard.playingNotes then
        for _, note in ipairs(bard.playingNotes) do
            player:getEmitter():stopSoundLocal(note.id)
        end
    end
    if bard and isClient() then
        if finished then
            Bard.flushNetworkNotes(player, bard, bard.instrumentID .. (bard.style or ""), bard.decay or 200, true)
        else
            netWorkHandler.sendStop(player)
        end
    end
    Bard.players[id] = false

    if not skipQueueStop then
        local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
        local currentAction = actionQueue.queue[1]
        if currentAction and (currentAction.Type == "BardToTheBonePlayMusic") and currentAction.action then
            currentAction:forceStop()
        end
    end

    Bard.players[id] = nil
end


function Bard.next(t) for k, _ in pairs(t) do return k end end

function Bard.startPlayback(player, abc, requestedVoice)
    local music, totalMilliseconds, voiceOrder = Bard.parseABC(abc)

    local durationTicks = getGameTime():getMultiplierFromTimeDelta(totalMilliseconds / 1000)

    for _, voice in pairs(music) do
        voice.eventIndex = 1
        Bard.getVoiceStats(voice)
    end

    return music, durationTicks, voiceOrder, totalMilliseconds --to convert ticks to milliseconds for playback deadline
end


Bard.midiBaseMap = {C=0, D=2, E=4, F=5, G=7, A=9, B=11}
Bard.midiAccidentalOffset = {["^"] = 1, ["_"] = -1, ["="] = 0}

function Bard.noteToMidi(note)
    local acc = note.base:sub(1, 1)
    local letter = note.base:sub(-1)
    local pitch = Bard.midiBaseMap[letter] + (Bard.midiAccidentalOffset[acc] or 0)
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


Bard.pitchNames = { "Cn", "Db", "Dn", "Eb", "En", "Fn", "Gb", "Gn", "Ab", "An", "Bb", "Bn" }

function Bard.getSoundName(n)
    if not Bard.midiBaseMap[n.base:sub(-1)] then return nil end
    local midi = Bard.noteToMidi(n)
    return Bard.pitchNames[(midi % 12) + 1] .. tostring(math.floor(midi / 12) - 1)
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
    local isPercussion = bard.isPercussion
    local percussionOctaveShift = bard.percussionOctaveShift
    local percussionPieces = bard.percussionPieces
    local percussionFallback = bard.percussionFallback

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

    if not bard.mistakes then Bard.initPerformance(player, bard) end
    if bard.selectedVoice ~= bard.mistakesVoice then Bard.updateMusicLevel(player, bard) end

    -- Advance elapsed time, scaled by speed
    local delta = (now - bard.lastUpdateTime) * speedMultiplier
    if bard.bandStart then
        local songTime = Bard.serverNow() - bard.bandStart
        delta = math.max(0, songTime - bard.elapsedTime)
        bard.elapsedTime = songTime
    else
        bard.elapsedTime = bard.elapsedTime + delta
    end
    bard.lastUpdateTime = now

    if (not bard.nextAmpCheck) or bard.elapsedTime >= bard.nextAmpCheck then
        bard.nextAmpCheck = bard.elapsedTime + Bard.ampCheckMs
        bard.amplified = bard.needsAmp and Bard.findPoweredAmp(player) or false
    end
    local instrumentID = bard.instrumentID .. (Bard.getPlayableStyle(bard) or "")

    bard.playingNotes = bard.playingNotes or {}

    local allDone = true
    local madeSound = false
    local mistakes = bard.mistakes

    for voiceId, data in pairs(music) do
        if Bard.isVoicePlayed(bard, voiceId, data) then
        data.eventIndex = data.eventIndex or 1

        while data.eventIndex <= #data.events do
            local event = data.events[data.eventIndex]
            local eventTime = event.timeOffset

            local latencyBufferMs = 30
            if bard.elapsedTime - bard.timeShift + latencyBufferMs >= eventTime then
                local slip = 0
                if mistakes.slip > 0 and ZombRandFloat(0, 1) < mistakes.slip then slip = ZombRandFloat(0, mistakes.slipMs) end

                for _, note in ipairs(event.notes) do
                    local sound = Bard.noteToSound(note, instrumentID, isPercussion, percussionOctaveShift, percussionPieces, percussionFallback)
                    if sound and instrumentID then
                        bard.lastNoteTime = bard.elapsedTime
                        if Bard.performNote(player, bard, note, sound, instrumentID, eventTime, slip) then madeSound = true end
                    end
                end

                if mistakes.hesitate > 0 and ZombRandFloat(0, 1) < mistakes.hesitate then
                    if bard.bandStart then
                        bard.stumbleUntil = bard.elapsedTime + ZombRandFloat(250, mistakes.hesitateMs)
                    else
                        bard.timeShift = bard.timeShift + ZombRandFloat(250, mistakes.hesitateMs)
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

    if madeSound and SandboxVars.BardToTheBone.AttractZombies then
        local radius = bard.amplified and Bard.ampNoiseRadius or 20
        addSound(player, player:getX(), player:getY(), player:getZ(), radius, 10)
    end

    local waiting = Bard.playDelayedNotes(player, bard, instrumentID)

    if isClient() then Bard.flushNetworkNotes(player, bard, instrumentID, decay) end

    Bard.updateMusicXp(player, bard, delta)

    local playingNotes = Bard.updatePlayingNotes(player, bard, bard.elapsedTime)

    if allDone and (waiting <= 0) and (#playingNotes <= 0) then Bard.completeAction(player, nil, true) end
end


function Bard.isVoicePlayed(bard, voiceId, data)
    if data.isPercussionVoice and not bard.isPercussion then return false end
    local selectedVoice = bard.selectedVoice
    return (not selectedVoice) or selectedVoice == "All" or voiceId == selectedVoice
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.performNote(player, bard, note, sound, instrumentID, eventTime, slip)
    local mistakes = bard.mistakes
    local duration = note.durationMs
    local gain = 1

    if bard.stumbleUntil and bard.elapsedTime < bard.stumbleUntil then return false end

    if mistakes.gain > 0 then
        if ZombRandFloat(0, 1) < mistakes.miss then return false end
        if ZombRandFloat(0, 1) < mistakes.wrong then
            sound = Bard.getWrongSound(bard, note, instrumentID) or sound
        end
        if ZombRandFloat(0, 1) < mistakes.hold then duration = duration * ZombRandFloat(0.4, 1.6) end
        gain = 1 - ZombRandFloat(0, mistakes.gain)
    end

    if bard.needsAmp and not bard.amplified then gain = gain * Bard.unpluggedVolume end

    local localDelay = slip + (bard.bandStart and Bard.bandDelayMs or 0)
    if localDelay > 0 then
        table.insert(bard.delayedNotes, { at = bard.elapsedTime + localDelay, sound = sound, duration = duration, gain = gain })
    else
        Bard.playNote(player, bard, instrumentID, sound, duration, bard.elapsedTime, gain)
    end

    if isClient() then Bard.queueNetworkNote(bard, sound, eventTime + bard.timeShift + slip, duration, gain) end
    return true
end


function Bard.getPlayableStyle(bard)
    local style = bard.style
    if style and bard.ampStyles and bard.ampStyles[style] and not bard.amplified then
        return bard.styles and bard.styles[1] or style
    end
    return style
end


function Bard.isAmpObject(object)
    if not object then return false end
    local sprite = object:getSprite()
    local spriteName = sprite and sprite:getName()
    if spriteName and Bard.ampSprites[spriteName] then return true end
    local properties = object:getProperties()
    if not properties then return false end
    local custom = properties:has("CustomName") and properties:get("CustomName")
    if not custom then return false end
    local group = properties:has("GroupName") and properties:get("GroupName")
    local name = group and (group .. " " .. custom) or custom
    return (Bard.ampNames[name] or Bard.ampNames[custom]) and true or false
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.findPoweredAmp(player)
    local square = player:getSquare()
    if not square then return false end
    local cell = getCell()
    local x, y, z = square:getX(), square:getY(), square:getZ()
    for dx = -Bard.ampRange, Bard.ampRange do
        for dy = -Bard.ampRange, Bard.ampRange do
            local ampSquare = cell:getGridSquare(x + dx, y + dy, z)
            if ampSquare and (ampSquare:haveElectricity() or ampSquare:hasGridPower()) then
                local objects = ampSquare:getObjects()
                for i = 0, objects:size() - 1 do
                    if Bard.isAmpObject(objects:get(i)) then return true end
                end
            end
        end
    end
    return false
end


function Bard.serverNow()
    return getTimestampMs() + (Bard.clock.offset or 0)
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.requestClock(player, force)
    if not isClient() or not player then return end
    local now = getTimestampMs()
    if (not force) and Bard.clock.offset and (now - (Bard.clock.at or 0)) < Bard.clockRefreshMs then return end
    Bard.clock.requested = now
    netWorkHandler.sendClockRequest(player, now)
end


function Bard.receiveClock(data)
    if not data or not data.t or not data.s then return end
    local now = getTimestampMs()
    local rtt = now - data.t
    if rtt < 0 then return end
    local clock = Bard.clock
    local stale = (now - (clock.at or 0)) >= Bard.clockRefreshMs
    if (not clock.offset) or stale or rtt <= (clock.rtt or rtt) then
        clock.offset = data.s + (rtt / 2) - now
        clock.rtt = rtt
        clock.at = now
    end
end


function Bard.findBand(songKey, durationMs)
    if not songKey or not Bard.clock.offset then return end
    local now = getTimestampMs()
    local serverNow = Bard.serverNow()
    local best, bestReceived
    for _, state in pairs(Bard.remotePlayers) do
        if state.songKey == songKey and state.bandStart and state.lastReceived and (now - state.lastReceived) <= Bard.bandJoinWindowMs then
            local position = serverNow - state.bandStart
            if position >= 0 and ((not durationMs) or position < durationMs) then
                if (not bestReceived) or state.lastReceived > bestReceived then
                    best, bestReceived = state.bandStart, state.lastReceived
                end
            end
        end
    end
    return best
end


function Bard.skipTo(bard, songTime)
    for _, data in pairs(bard.music) do
        data.eventIndex = data.eventIndex or 1
        while data.eventIndex <= #data.events and data.events[data.eventIndex].timeOffset < songTime do
            data.eventIndex = data.eventIndex + 1
        end
    end
    bard.elapsedTime = songTime
end


function Bard.getWrongSound(bard, note, instrumentID)
    local step = (ZombRand(10) < 7) and 1 or 2
    if ZombRand(2) == 0 then step = -step end
    local wrong = Bard.midiToNote(Bard.noteToMidi(note) + step)
    return Bard.noteToSound(wrong, instrumentID, bard.isPercussion, bard.percussionOctaveShift, bard.percussionPieces, bard.percussionFallback)
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.playDelayedNotes(player, bard, instrumentID)
    local waiting = {}
    for _, note in ipairs(bard.delayedNotes) do
        if note.at <= bard.elapsedTime then
            Bard.playNote(player, bard, instrumentID, note.sound, note.duration, bard.elapsedTime, note.gain)
        else
            table.insert(waiting, note)
        end
    end
    bard.delayedNotes = waiting
    return #waiting
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.playNote(player, state, instrumentID, sound, durationMs, started, gain)
    if modOptions.isMuted() then return end
    local emitter = player:getEmitter()
    local soundID = emitter:playSoundImpl(instrumentID .. "_" .. sound, nil)
    emitter:setVolume(soundID, state.volume/100 * (gain or 1))

    table.insert(state.playingNotes, {
        id = soundID,
        started = started,
        duration = durationMs,
        gain = gain or 1
    })
end


---This keeps total notes that are active capped, stops the oldest note per tick
--- as well as cuts notes off after their intended length + handles per instrument decay
---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.updatePlayingNotes(player, state, elapsed)
    local emitter = player:getEmitter()
    local decay = state.decay or 200
    local volume = state.volume or 100

    local muted = modOptions.isMuted()
    local playingNotes = {}
    for n, note in ipairs(state.playingNotes) do
        local noteID = note.id
        if emitter:isPlaying(noteID) then
            local timeSinceStart = elapsed - note.started

            if muted or timeSinceStart >= note.duration + decay then
                emitter:stopSoundLocal(noteID)
            elseif #state.playingNotes > 40 and n == 1 then
                emitter:stopSoundLocal(noteID)
            else
                local noteVolume = volume / 100 * (note.gain or 1)
                if timeSinceStart >= note.duration then
                    -- In decay phase
                    local fadeProgress = (timeSinceStart - note.duration) / decay
                    local fadeVolume = noteVolume * (1 - fadeProgress)
                    fadeVolume = math.max(0, math.min(1, fadeVolume))
                    emitter:setVolume(noteID, fadeVolume)
                else
                    -- Still sustaining at full volume
                    emitter:setVolume(noteID, noteVolume)
                end

                table.insert(playingNotes, note)
            end
        end
    end

    state.playingNotes = playingNotes
    return playingNotes
end


function Bard.queueNetworkNote(bard, sound, timeOffset, durationMs, gain)
    local batch = bard.networkBatch
    if not batch then
        batch = { startedAt = bard.elapsedTime, n = {}, t = {}, d = {}, g = {} }
        bard.networkBatch = batch
    end
    table.insert(batch.n, sound)
    table.insert(batch.t, math.floor(timeOffset))
    table.insert(batch.d, math.floor(durationMs or 0))
    table.insert(batch.g, math.floor((gain or 1) * 100))
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.flushNetworkNotes(player, bard, instrumentID, decay, force)
    local batch = bard.networkBatch
    if not batch then return end
    if (not force) and ((bard.elapsedTime - batch.startedAt) < Bard.networkBatchMs) then return end
    bard.networkBatch = nil

    Bard.networkSequence = Bard.networkSequence + 1
    bard.networkPerformance = bard.networkPerformance or Bard.networkSequence

    netWorkHandler.sendNotes(player, {
        s = Bard.networkSequence,
        p = bard.networkPerformance,
        i = instrumentID,
        v = bard.volume,
        dc = decay,
        n = batch.n,
        t = batch.t,
        d = batch.d,
        g = batch.g,
        S = bard.bandStart,
        k = bard.songKey,
    })
end


function Bard.receiveNotes(data)
    if not data or not data.id or not data.n then return end
    local performer = getPlayerByOnlineID(data.id)
    if not performer or performer:isLocalPlayer() then return end

    local now = getTimestampMs()
    local state = Bard.remotePlayers[data.id]
    if state and data.s <= state.sequence then return end

    local firstOffset
    for _, offset in ipairs(data.t) do
        if not firstOffset or offset < firstOffset then firstOffset = offset end
    end
    firstOffset = firstOffset or 0

    if not state then
        state = { playingNotes = {}, queue = {} }
        Bard.remotePlayers[data.id] = state
    end

    if state.performance ~= data.p then
        state.performance = data.p
        state.anchor = now + Bard.networkDelayMs - firstOffset
    end

    state.sequence = data.s
    state.songKey = data.k
    state.bandStart = data.S
    state.player = performer
    state.instrumentID = data.i
    state.volume = data.v
    state.decay = data.dc
    state.lastReceived = now

    local base = state.anchor
    if data.S and Bard.clock.offset then base = data.S + Bard.bandDelayMs - Bard.clock.offset end
    for k, sound in ipairs(data.n) do
        table.insert(state.queue, { sound = sound, at = base + data.t[k], duration = data.d[k], gain = (data.g and data.g[k] or 100) / 100 })
    end
end


function Bard.stopRemotePlayer(id)
    local state = Bard.remotePlayers[id]
    if not state then return end

    if state.player then
        for _, note in ipairs(state.playingNotes) do
            state.player:getEmitter():stopSoundLocal(note.id)
        end
    end
    Bard.remotePlayers[id] = nil
end


function Bard.receiveStop(data)
    if not data or not data.id then return end
    Bard.stopRemotePlayer(data.id)
end


function Bard.updateRemotePlayers()
    local now = getTimestampMs()

    for id, state in pairs(Bard.remotePlayers) do
        local player = state.player
        if (not player) or (getPlayerByOnlineID(id) ~= player) then
            Bard.remotePlayers[id] = nil
        else
            local queue = {}
            for _, note in ipairs(state.queue) do
                if note.at <= now then
                    Bard.playNote(player, state, state.instrumentID, note.sound, note.duration, now, note.gain)
                else
                    table.insert(queue, note)
                end
            end
            state.queue = queue

            local playingNotes = Bard.updatePlayingNotes(player, state, now)
            if (#queue <= 0) and (#playingNotes <= 0) and ((now - state.lastReceived) > Bard.remoteIdleMs) then
                Bard.remotePlayers[id] = nil
            end
        end
    end
end


function Bard.getSongKey(abc)
    local hash = 5381
    for i = 1, #abc do
        hash = (hash * 33 + abc:byte(i)) % 4294967296
    end
    return tostring(hash)
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.getMusicData(player)
    local modData = player:getModData()
    modData.BardToTheBone = modData.BardToTheBone or {}
    local data = modData.BardToTheBone
    data.songs = data.songs or {}
    data.instruments = data.instruments or {}
    return data
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.getMusicLevel(player, family)
    local perk = netWorkHandler.getFamilyPerk(family)
    if not perk or not netWorkHandler.skillsEnabled() then return 10 end
    return player:getPerkLevel(perk)
end


function Bard.getMistakes(level, difficulty)
    local s = math.min(1, math.max(0, (difficulty or 10) - level) / 10 + math.max(0, 10 - level) / 40)
    return {
        wrong = 0.12 * s * s,
        miss = 0.05 * s * s,
        hold = 0.15 * s,
        gain = 0.4 * s,
        slip = 0.3 * s,
        slipMs = 40 + 140 * s,
        hesitate = 0.004 * s * s,
        hesitateMs = 250 + 600 * s,
    }
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.updateMusicLevel(player, bard)
    local level = Bard.getMusicLevel(player, bard.family)
    if (level ~= bard.level) or (bard.selectedVoice ~= bard.mistakesVoice) then
        bard.level = level
        bard.mistakesVoice = bard.selectedVoice
        bard.mistakes = Bard.getMistakes(level, Bard.getSongDifficulty(Bard.getComplexity(bard), bard.isPercussion))
    end
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.initPerformance(player, bard)
    bard.timeShift = bard.timeShift or 0
    bard.delayedNotes = bard.delayedNotes or {}
    bard.activeMs = bard.activeMs or 0
    bard.countedMs = bard.countedMs or 0
    bard.pendingXp = bard.pendingXp or 0
    bard.lastXpSend = bard.lastXpSend or 0
    Bard.updateMusicLevel(player, bard)
    bard.xpBonus = Bard.getXpBonus(player, bard)
end


function Bard.getVoiceStats(data)
    if data.stats then return data.stats end

    local stats = { notes = 0, together = 0, accidentals = 0, changes = 0 }
    local previous, previousLength
    for _, event in ipairs(data.events) do
        for _, note in ipairs(event.notes) do
            if not note.rest then
                stats.notes = stats.notes + 1
                if previous and (event.timeOffset - previous) <= 20 then stats.together = stats.together + 1 end
                previous = event.timeOffset
                stats.first = stats.first or event.timeOffset
                stats.last = event.timeOffset
                local midi = Bard.noteToMidi(note)
                stats.low = math.min(stats.low or midi, midi)
                stats.high = math.max(stats.high or midi, midi)
                if #note.base > 1 then stats.accidentals = stats.accidentals + 1 end
                local length = note.durationMs or 0
                if previousLength and math.abs(length - previousLength) > previousLength * 0.15 then stats.changes = stats.changes + 1 end
                previousLength = length
            end
        end
    end

    data.stats = stats
    return stats
end


function Bard.getComplexity(bard)
    local key = bard.selectedVoice or "All"
    bard.complexity = bard.complexity or {}
    if bard.complexity[key] then return bard.complexity[key] end

    local notes, together, accidentals, changes = 0, 0, 0, 0
    local low, high, first, last

    for voiceId, data in pairs(bard.music) do
        if Bard.isVoicePlayed(bard, voiceId, data) then
            local stats = Bard.getVoiceStats(data)
            if stats.notes > 0 then
                notes = notes + stats.notes
                together = together + stats.together
                accidentals = accidentals + stats.accidentals
                changes = changes + stats.changes
                low = math.min(low or stats.low, stats.low)
                high = math.max(high or stats.high, stats.high)
                first = math.min(first or stats.first, stats.first)
                last = math.max(last or stats.last, stats.last)
            end
        end
    end

    if notes <= 0 then
        bard.complexity[key] = 0
        return 0
    end

    local seconds = math.max(1, (last - first) / 1000)
    local density = math.min(3, 0.5 + (notes / seconds) / 6)
    local range, accidentalShare = 0, 0
    if not bard.isPercussion then
        range = math.min(36, high - low) / 72
        accidentalShare = (accidentals / notes) * 0.3
    end
    local polyphony = (together / notes) * 0.4
    local rhythm = (changes / notes) * 0.5

    local complexity = density * (1 + range + accidentalShare + polyphony + rhythm)
    bard.complexity[key] = complexity
    return complexity
end


Bard.difficultySpan = 5.8
Bard.percussionDifficultySpan = 3.7

function Bard.getSongDifficulty(complexity, isPercussion)
    local span = isPercussion and Bard.percussionDifficultySpan or Bard.difficultySpan
    return math.max(0, math.min(10, (complexity - 1) * 10 / span))
end


function Bard.scoreSong(abc)
    local music = Bard.parseABC(abc)
    local melodic = Bard.getComplexity({ music = music, isPercussion = false })
    local percussion = Bard.getComplexity({ music = music, isPercussion = true })
    return {
        melodic = (melodic > 0) and math.floor(Bard.getSongDifficulty(melodic) + 0.5) or nil,
        percussion = (percussion > 0) and math.floor(Bard.getSongDifficulty(percussion, true) + 0.5) or nil,
    }
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.getXpBonus(player, bard)
    local data = Bard.getMusicData(player)
    local plays = math.min(bard.songKey and data.songs[bard.songKey] or 0, Bard.familiarMaxPlays)
    local bonus = 1 + plays * Bard.familiarBonus
    if (data.instruments[bard.instrumentID] or 0) < Bard.newInstrumentMs then bonus = bonus + Bard.newInstrumentBonus end
    return bonus
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.updateMusicXp(player, bard, delta)
    if bard.lastNoteTime and (bard.elapsedTime - bard.lastNoteTime) <= Bard.xpActiveMs then
        bard.activeMs = bard.activeMs + delta
        bard.pendingXp = bard.pendingXp + (delta / 60000) * Bard.xpPerMinute * Bard.getComplexity(bard) * bard.xpBonus
    end
    if (bard.elapsedTime - bard.lastXpSend) >= Bard.xpSendMs then Bard.flushMusicXp(player, bard) end
end


---@param player IsoPlayer|IsoGameCharacter
function Bard.flushMusicXp(player, bard)
    bard.lastXpSend = bard.elapsedTime or 0

    local data = Bard.getMusicData(player)
    local instrument = bard.instrumentID
    if instrument then
        data.instruments[instrument] = (data.instruments[instrument] or 0) + (bard.activeMs - bard.countedMs)
    end
    bard.countedMs = bard.activeMs

    if bard.pendingXp > 0 then
        netWorkHandler.sendXp(player, bard.pendingXp, bard.family)
        bard.pendingXp = 0
    end

    Bard.updateMusicLevel(player, bard)
    bard.xpBonus = Bard.getXpBonus(player, bard)
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
    ["Base.Banjo"] = { decay = 300, soundDir = "banjo", family = "Strings", anim = "strumming" },
    ["Base.GuitarAcoustic"] = { decay = 600, soundDir = "guitar", family = "Strings", anim = "strumming" },
    ["Base.GuitarElectric"] = { decay = 800, soundDir = "electric_guitar", family = "Strings", anim = "strumming", styles = { "Clean","Muted","Overdrive","Distortion","Harmonics" }, needsAmp = true, ampStyles = { Overdrive = true, Distortion = true }, },
    ["Base.GuitarElectricBass"] = { decay = 900, soundDir = "electric_bass", family = "Strings", anim = "strumming", needsAmp = true, },
    ["Base.Keytar"] = { decay = 700, soundDir = "keytar", family = "Keys", anim = "Keytar", styles = { "Square","Sawtooth","Calliope","Chiff","Charang","Voice","Fifths","Brass" }, },
    ["Base.Harmonica"] = { decay = 200, soundDir = "harmonica", family = "Winds", anim = "Harmonica" },
    ["Base.Saxophone"] = { decay = 400, soundDir = "saxophone", family = "Winds", anim = "SaxPlaying", special = "sexySax"},
    ["Base.Violin"] = { decay = 100, soundDir = "violin", family = "Strings", anim = "Violin", left = "Violin_Bow", right = "Violin" },
    ["Base.Xylophone"] = { decay = 250, soundDir = "xylophone", family = "Percussion", anim = "Xylophone", left = "Xylophone_Mallet", right = "Xylophone"},
    ["Base.Flute"] = { decay = 300, soundDir = "flute", family = "Winds", anim = "Flute" },
    ["Base.Rubberducky"] = { decay = 150, soundDir = "bikehorn", family = "Winds", anim = "Rubberducky", },
    ["Base.Trumpet"] = { decay = 500, soundDir = "trumpet", family = "Winds", anim = "Trumpet" },
    ["Base.Whistle"] = { decay = 200, soundDir = "whistle", family = "Winds", anim = "Whistle"},
    ["Base.Whistle_Bone"] = { decay = 200, soundDir = "whistle", family = "Winds", anim = "Whistle"},
}


---SIMILAR TO ABOVE, BUT WITH MAPOBJECTS' GROUPNAMES, GETS POPULATED FIRST TIME `getInstrumentData` IS CALLED.
Bard.instrumentMapObjectData = {
    --[""] = { soundDir = "", anim = ""},

    --recreational_01_12,13  8,9
    ["Piano"] = { decay = 500, soundDir = "piano", family = "Keys", anim = "Piano",
                  sprites = { "recreational_01_12", "recreational_01_13", "recreational_01_8", "recreational_01_9", }
    },

    --recreational_01_40,41  48,49
    ["Grand Piano"] = { decay = 800, soundDir = "grandPiano", family = "Keys", anim = "Piano",
                        sprites = { "recreational_01_40", "recreational_01_41", "recreational_01_48", "recreational_01_49", }
    },


    ["Drum"] = { decay = 120, soundDir = "drumkit", family = "Percussion", anim = "Xylophone", isPercussion = true,
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
    [ItemTag.GLASS_BOTTLE] = { decay = 350, soundDir = "bottle", family = "Winds", anim = "Bottle", validCheck = "bottleIsEmpty"},
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