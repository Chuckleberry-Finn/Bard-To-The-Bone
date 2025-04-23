-- Example ABC song (Killinaskully Thriller)
local abc_string = [[
X:1
T:LIBERTON POLKA
M:C|
L:1/8
Q:80
C:Traditional
S:March
K:HP
|: e2 | \
{g}A{d}B/2A/2{g}GA | \
{Gdc}dA{gfg}f2 |
{g}fe/2f/2{gf}ge | \
{g}d3/4B/4d3/4e/4{g}fd | \
{g}A{gBd}B/2A/2{g}G{d}A |
{Gdc}dA{gfg}f2 | \
{g}fe/2f/2{gf}gc | \
{gef}ed{gdc}d{c}d ::
{gef}e{g}f/2e/2{gcd}ce | \
{ag}ac{gef}e2 | \
{g}e{g}f/2e/2{Gdc}d{e}B |
{g}fe{gcd}c2 | \
{gef}e{g}f/2e/2{gcd}ce | \
{ag}ac{gef}e2 |
{g}e{g}f/2e/2{Gdc}dG | \
{gBd}BA{GAG}A2 :: \
e2 |
{g}A{d}c{g}A{d}c | \
{gef}e{g}f/2e/2{gcd}c2 | \
{gef}e{g}f/2e/2{Gdc}d{e}B |
{g}A{d}c{gcd}c2 | \
{g}A{d}c{g}A{d}c | \
{gef}e{g}f/2e/2{gcd}c2 |
{gef}e{g}f/2e/2{Gdc}d{g}G | \
{gBd}BA{GAG}A2 :: \
{ag}af{g}f{ag}a |
e{g}f/2e/2{gcd}c2 | \
{g}e{g}f/2e/2{Gdc}d{e}B | \
{g}fe{gcd}c2 |
{ag}af{g}f{ag}a | \
e{g}f/2e/2{gcd}c2 | \
{g}e{g}f/2e/2{Gdc}d{g}G |
{gBd}B{e}A{GAG}A2 :|
]]

local Bard = {}

Bard.players = {}

Bard.accidental_map = {}
Bard.natural_map = {}

--utility func
function Bard.table_indexof(t, val) for i, v in ipairs(t) do if v == val then return i end end end

-- Build maps programmatically
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


function Bard.convertTicksToTempoDuration(ticks, bpm, baseNoteLength)
    local l_top, l_bottom = baseNoteLength:match("(%d+)%s*/%s*(%d+)")
    local fraction = tonumber(l_top) / tonumber(l_bottom)
    local secondsPerBeat = 60 / bpm
    local secondsPerTick = secondsPerBeat * fraction
    local simTicksPerSecond = 10 / getGameTime():getTrueMultiplier()
    return math.max(1, math.floor(secondsPerTick * simTicksPerSecond * ticks))
end


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
    local notes = {}
    local defaultTicks = 30
    local key = "C"
    local bpm = 120
    local baseNoteLength = "1/8"
    local tripletActive = false
    local lastNote = nil

    for line in abc:gmatch("[^\r\n]+") do
        local header, value = line:match("^(%a):%s*(.+)$")
        if header == "L" then
            defaultTicks = Bard.getTicksFromLength(value)
            baseNoteLength = value
        elseif header == "K" then
            key = value:gsub("%s+", "")
        elseif header == "Q" then
            bpm = tonumber(value:match("(%d+)") or "120")
        elseif not (header == "X" or header == "T" or header == "M" or header == "R" or header == "V" or header == "Z" or header == "S") then
            -- Triplets
            if line:find("%(3") then
                tripletActive = true
                line = line:gsub("%(3", "") -- remove marker
            end

            -- Chords
            for chordText in line:gmatch("%b[]") do
                local chord = {}
                for accidental, base, octaveMod, duration in chordText:gmatch("([_=^]?)([A-Ga-g])([',]*)(%d*%.?%d*)") do
                    local name = accidental .. base:upper()
                    local octave = base:match("%l") and 5 or 4
                    for char in octaveMod:gmatch(".") do
                        if char == "," then octave = octave - 1
                        elseif char == "'" then octave = octave + 1 end
                    end
                    local durationTicks = defaultTicks
                    if duration ~= "" then
                        if duration:find("/") then
                            local div = tonumber(duration:match("/(%d+)")) or 2
                            durationTicks = math.floor(defaultTicks / div)
                        else
                            durationTicks = math.floor(defaultTicks * tonumber(duration))
                        end
                    end
                    if tripletActive then
                        durationTicks = math.floor(durationTicks * (2 / 3))
                    end

                    local note = {
                        rest = false,
                        base = name,
                        octave = octave,
                        ticks = durationTicks
                    }
                    Bard.applyKeyAccidental(note, key)
                    table.insert(chord, note)
                end
                table.insert(notes, { chord = chord })
                line = line:gsub("%b[]", "") -- remove chord block from line
            end

            -- Individual notes & articulation
            for prefix, accidental, base, octaveMod, duration, tie in line:gmatch("([~>%.%-]?)([_=^]?)([A-Ga-g])([',]*)(%d*%.?%d*)(%-?)") do
                local name = accidental .. base:upper()
                local octave = base:match("%l") and 5 or 4
                for char in octaveMod:gmatch(".") do
                    if char == "," then octave = octave - 1
                    elseif char == "'" then octave = octave + 1 end
                end
                local durationTicks = defaultTicks
                if duration ~= "" then
                    if duration:find("/") then
                        local div = tonumber(duration:match("/(%d+)")) or 2
                        durationTicks = math.floor(defaultTicks / div)
                    else
                        durationTicks = math.floor(defaultTicks * tonumber(duration))
                    end
                end
                if tripletActive then
                    durationTicks = math.floor(durationTicks * (2 / 3))
                end

                local note = {
                    rest = base:upper() == "Z",
                    base = name,
                    octave = octave,
                    ticks = durationTicks,
                    slur = (prefix == "~" or prefix == "-"),
                    accent = (prefix == ">"),
                    staccato = (prefix == "."),
                    tie = (tie == "-")
                }

                Bard.applyKeyAccidental(note, key)

                -- Adjust ticks for articulation
                if note.staccato then
                    note.ticks = math.floor(note.ticks * 0.5)
                elseif note.slur then
                    note.ticks = math.floor(note.ticks * 0.85)
                end

                -- Handle tie
                if note.tie and lastNote then
                    lastNote.ticks = lastNote.ticks + note.ticks
                else
                    table.insert(notes, note)
                    lastNote = note
                end
            end

            tripletActive = false -- reset
        end
    end

    return notes, bpm, baseNoteLength
end


function Bard.startPlayback(player, abc)
    local id = player:getUsername()
    local parsedNotes, bpm, baseNoteLength = Bard.parseABC(abc)
    Bard.players[id] = {
        song = parsedNotes,
        index = 1,
        timer = 0,
        bpm = bpm or 120,
        baseNoteLength = baseNoteLength or "1/8"
    }
end


function Bard.noteToSound(note)
    if note.rest then return nil end
    local mapped = Bard.accidental_map[note.base] or Bard.natural_map[note.base:sub(-1)]
    if not mapped then return nil end
    return mapped .. tostring(note.octave)
end


function Bard.playLoadedSongs(player)
    local id = player:getUsername()
    local bard = Bard.players[id]

    ---DEBUG
    if not bard then if isKeyDown(Keyboard.KEY_H) then Bard.startPlayback(player, abc_string) end return end

    if bard.timer > 0 then bard.timer = bard.timer - 1 return end

    local note = bard.song[bard.index]
    if note then
        local soundPath = Bard.noteToSound(note)
        if soundPath then getSoundManager():PlayWorldSound(soundPath, player:getSquare(), 0.2, 20.0, 1.0, false) end
        bard.timer = Bard.convertTicksToTempoDuration(note.ticks, bard.bpm, bard.baseNoteLength)
        bard.index = bard.index + 1
    else
        print("Playback done")
        Bard.players[id] = nil
    end
end


return Bard