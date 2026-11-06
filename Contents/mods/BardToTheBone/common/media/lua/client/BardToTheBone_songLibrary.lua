local defaultSongs = require "BardToTheBone_defaultSongs"
local settings = require "BardToTheBone_settings"

local songLibrary = {}

songLibrary.modID = "BardToTheBone"
songLibrary.modDirectory = "media/songLibrary"
songLibrary.cacheDirectory = "BardToTheBoneSongLibrary"
songLibrary.oldSongsFile = "BardToTheBone_Songs.txt"
songLibrary.placeholder = "placeholder.txt"
songLibrary.extensions = { abc = true, txt = true }
songLibrary.maxFileNameLength = 60

songLibrary.modSongs = nil
songLibrary.contentCache = {}
songLibrary.localFiles = {}
songLibrary.blankFiles = {}


function songLibrary.getExtension(fileName)
    local extension = fileName and fileName:match("%.([^%.]+)$")
    return extension and extension:lower()
end


function songLibrary.isSongFile(fileName)
    if not fileName or fileName == songLibrary.placeholder then return false end
    if fileName:find("..", 1, true) then return false end
    local extension = songLibrary.getExtension(fileName)
    return (extension and songLibrary.extensions[extension]) or false
end


function songLibrary.getDisplayName(fileName)
    local name = fileName:gsub("%.[^%.]+$", ""):gsub("_", " ")
    return name
end


function songLibrary.getTitle(content, fallback)
    local title = content and (content.."\n"):match("T:%s*([^\r\n]-)%s*[\r\n]")
    if title and title ~= "" then return title end
    return fallback or "[No Title]"
end


function songLibrary.setTitle(song, title)
    song.title = title
    song.searchTitle = title:lower()
end


function songLibrary.readLines(reader)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    return table.concat(lines, "\n").."\n"
end


function songLibrary.getCachePath(fileName)
    return songLibrary.cacheDirectory.."/"..fileName
end


function songLibrary.writeFile(fileName, content)
    local writer = getFileWriter(songLibrary.getCachePath(fileName), true, false)
    if not writer then return false end
    writer:write(content)
    writer:close()
    return true
end


function songLibrary.splitSongs(bigString)
    local songs = {}
    local pos = 1
    while true do
        local start_pos = bigString:find("X:%s*%d+", pos)
        if not start_pos then break end

        local next_start = bigString:find("X:%s*%d+", start_pos + 1)
        local song_block = next_start and bigString:sub(start_pos, next_start - 1) or bigString:sub(start_pos)
        table.insert(songs, song_block)

        if not next_start then break end
        pos = next_start
    end
    return songs
end


function songLibrary.makeFileName(title, currentFileName)
    local base = (title or ""):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "_")
    if base == "" then base = "Song" end
    base = base:sub(1, songLibrary.maxFileNameLength)

    local candidate = base..".txt"
    local count = 1
    while songLibrary.localFiles[candidate] and candidate ~= currentFileName do
        count = count + 1
        candidate = base.."_"..count..".txt"
    end
    return candidate
end


function songLibrary.saveSong(song, content)
    local title = songLibrary.getTitle(content)
    local fileName = songLibrary.makeFileName(title, song.fileName)

    if not songLibrary.writeFile(fileName, content) then return false end

    if song.fileName and song.fileName ~= fileName then
        songLibrary.blankFile(song.fileName)
    end

    songLibrary.localFiles[fileName] = true
    songLibrary.blankFiles[fileName] = nil

    song.fileName = fileName
    song.content = content
    song.source = "local"
    songLibrary.setTitle(song, title)
    return true
end


function songLibrary.blankFile(fileName)
    if songLibrary.getExtension(fileName) ~= "txt" then return false end
    if not songLibrary.writeFile(fileName, "") then return false end
    songLibrary.localFiles[fileName] = nil
    songLibrary.blankFiles[fileName] = true
    return true
end


function songLibrary.importOldSongs()
    if settings.get("importedSongsFile") then return end
    songLibrary.collectLocalSongs()

    local content = songLibrary.readLines(getFileReader(songLibrary.oldSongsFile, false))
    local blocks = (content and content:match("%S")) and songLibrary.splitSongs(content) or defaultSongs

    for _,block in ipairs(blocks) do
        local song = {}
        songLibrary.saveSong(song, block:gsub("%s*$", "").."\n")
    end

    settings.set("importedSongsFile", true)
end


function songLibrary.ensureCacheDirectory()
    local files = listFilesInZomboidLuaDirectory(songLibrary.cacheDirectory)
    if files and files:size() > 0 then return end

    songLibrary.writeFile(songLibrary.placeholder, "")
end


function songLibrary.sortSongs(songs)
    table.sort(songs, function(a, b) return a.searchTitle < b.searchTitle end)
    return songs
end


function songLibrary.collectModSongs()
    local songs = {}
    local files = listFilesInModDirectory(songLibrary.modID, songLibrary.modDirectory)
    if not files then return songs end

    local seen = {}
    for i=0, files:size()-1 do
        local fileName = files:get(i)
        if songLibrary.isSongFile(fileName) and not seen[fileName] then
            seen[fileName] = true
            local song = { fileName = fileName, source = "mod" }
            songLibrary.setTitle(song, songLibrary.getDisplayName(fileName))
            table.insert(songs, song)
        end
    end

    return songLibrary.sortSongs(songs)
end


function songLibrary.collectLocalSongs()
    local localSongs, abcSongs = {}, {}
    songLibrary.localFiles = {}
    songLibrary.blankFiles = {}

    local files = listFilesInZomboidLuaDirectory(songLibrary.cacheDirectory)
    if not files then return localSongs, abcSongs end

    for i=0, files:size()-1 do
        local fileName = files:get(i)
        if songLibrary.isSongFile(fileName) then
            if songLibrary.getExtension(fileName) == "txt" then
                local content = songLibrary.readLines(getFileReader(songLibrary.getCachePath(fileName), false)) or ""
                if content:match("%S") then
                    songLibrary.localFiles[fileName] = true
                    local song = { fileName = fileName, source = "local", content = content }
                    songLibrary.setTitle(song, songLibrary.getTitle(content, songLibrary.getDisplayName(fileName)))
                    table.insert(localSongs, song)
                else
                    songLibrary.blankFiles[fileName] = true
                end
            else
                local song = { fileName = fileName, source = "abc" }
                songLibrary.setTitle(song, songLibrary.getDisplayName(fileName))
                table.insert(abcSongs, song)
            end
        end
    end

    return songLibrary.sortSongs(localSongs), songLibrary.sortSongs(abcSongs)
end


function songLibrary.reload()
    songLibrary.modSongs = nil
    songLibrary.contentCache = {}
end


function songLibrary.fetchSongs()
    songLibrary.importOldSongs()
    songLibrary.ensureCacheDirectory()

    if not songLibrary.modSongs then
        songLibrary.modSongs = songLibrary.collectModSongs()
    end

    local localSongs, abcSongs = songLibrary.collectLocalSongs()
    local librarySongs = abcSongs
    for _,song in ipairs(songLibrary.modSongs) do
        table.insert(librarySongs, song)
    end

    return localSongs, librarySongs
end


function songLibrary.readSong(song)
    if not song or not song.fileName then return "" end
    if song.content then return song.content end

    local cached = (song.source == "mod") and songLibrary.contentCache[song.fileName]
    if cached then return cached end

    local content
    if song.source == "mod" then
        content = songLibrary.readLines(getModFileReader(songLibrary.modID, songLibrary.modDirectory.."/"..song.fileName, false))
    else
        content = songLibrary.readLines(getFileReader(songLibrary.getCachePath(song.fileName), false))
    end
    content = content or ""

    if song.source == "mod" then songLibrary.contentCache[song.fileName] = content end
    return content
end


return songLibrary