local abc_string = [[
X:3618
T:Cuckoo's Nest, The
T:An Spealad\'oir (The Mower)
R:hornpipe
H:Parts 2 and 3 sometimes played in opposite order for both versions.
D:Seamus Ennis: The Fox Chase
D:Willie Clancy: Erin's Lovely Lea (?)
D:De Dannan: Star Spangled Molly
D:Conal O'Grada: The Top of Coom
Z:id:hn-hornpipe-37
M:C|
K:G
dc|BcBA GBdg|fdcB cedc|BcBG FGAB|c2A2 A2dc|
BcBA GBdg|fdcB cedc|(3Bcd BG FGAc|B2G2 G2:|
|:z2|dggf gabg|afd^c d2de|fede fgaf|gfdB cedc|
BcBA GBdg|fdcB cedc|(3Bcd BG FGAc|B2G2 G2:|
|:Bc|dBGB dBGB|dBcA G2AB|cAFA cAFA|cBAG F2BA|
GABc dBdg|bgdB cedc|(3Bcd BG FGdc|B2G2 G2:|
"Version 2:"
dc|BcBA GBdg|fdcB cedc|BcBG FGAB|c2A2 A2dc|
BcBA GBdg|fdcB cedc|(3Bcd BG FGAc|B2G2 G2:|
|:Bc|dBGB dBGB|dBcA G2AB|cA=FA cA=FA|cBAG =F2BA|
GABc dg~g2|bgdB cedc|(3Bcd BG FGAc|B2G2 G2:|
|:z2|dggf gabg|afd^c d2de|=fede ^fgaf|gfdB cedc|
BcBA GBdg|fdcB cedc|(3Bcd BG FGAc|B2G2 G2:|
]]

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

function Bard.convertTicksToTempoDuration(ticks, bpm, baseNoteLength)
    local l_top, l_bottom = baseNoteLength:match("(%d+)%s*/%s*(%d+)")
    local fraction = tonumber(l_top) / tonumber(l_bottom)
    local secondsPerBeat = 60 / bpm
    local secondsPerTick = secondsPerBeat * fraction
    local simTicksPerSecond = 2 / getGameTime():getTrueMultiplier()
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
    -- Remove excessive rests
    abc = abc:gsub("(z%d*/?%d*%s*)+", "z ")
    -- Normalize bars and backslashes
    abc = abc:gsub("|%s*\\%s*", "|")
    -- Normalize title lines
    abc = abc:gsub("T:%s*from%s*.*\\", "T:Jurassic Theme")
    -- Remove duplicate K: lines within a voice
    abc = abc:gsub("K:[^\n]+\n%s*K:", "K:")
    -- Collapse triplet or tuplet syntax to a safer format
    abc = abc:gsub("%(%d+:?%d*:?%d*", "")  -- Remove malformed tuplets
    return abc
end


function Bard.parseABC(abc)

    Bard.preprocessABC(abc)

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
        elseif not header then

            local allTokens = {}
            for token in line:gmatch("%b[]") do
                table.insert(allTokens, token:sub(2, -2)) -- remove brackets
            end
            line = line:gsub("%b[]", "")
            for token in line:gmatch("[^%s]+") do
                table.insert(allTokens, token)
            end
            for _, token in ipairs(allTokens) do
                for _, note in ipairs(Bard.parseNoteToken(token, voices[currentVoice].defaultTicks, voices[currentVoice].key)) do
                    table.insert(voices[currentVoice].notes, note)
                end
            end

        end
    end
    return voices
end


function Bard.startPlayback(player, abc)
    local id = player:getUsername()
    print("Starting playback for player:", id)
    Bard.players[id] = Bard.parseABC(abc)
end


function Bard.noteToSound(note)
    if note.rest then return nil end
    print("Converting note:", note.base, "octave:", note.octave)
    local mapped = Bard.accidental_map[note.base] or Bard.natural_map[note.base:sub(-1)]
    if not mapped then print("No mapping for:", note.base) return nil end
    return mapped .. tostring(note.octave)
end


---@param player IsoPlayer|IsoGameCharacter|IsoMovingObject
function Bard.playLoadedSongs(player)
    local id = player:getUsername()
    local voices = Bard.players[id]

    if not voices then if isKeyDown(Keyboard.KEY_H) then Bard.startPlayback(player, abc_string) end return end

    local allDone = true

    for voiceId, data in pairs(voices) do
        if data.index <= #data.notes then
            data.timer = data.timer - 1
            if data.timer <= 0 then
                local note = data.notes[data.index]
                local sound = Bard.noteToSound(note)

                if sound then
                    getSoundManager():PlayWorldSound(sound, player:getSquare(), 0.2, 20.0, 1.0, false)
                end

                data.timer = Bard.convertTicksToTempoDuration(note.ticks, data.bpm, data.baseNoteLength)
                data.index = data.index + 1
            end
            allDone = false
        end
    end

    if allDone then
        print("Playback finished for player:", id)
        Bard.players[id] = nil
    end
end


return Bard