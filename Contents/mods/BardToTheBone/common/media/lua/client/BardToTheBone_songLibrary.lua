local songLibrary = {}

songLibrary.modID = "BardToTheBone"
songLibrary.modDirectory = "media/songLibrary"
songLibrary.cacheDirectory = "BardToTheBoneSongLibrary"
songLibrary.placeholder = "placeholder.txt"
songLibrary.extensions = { abc = true, txt = true }

songLibrary.modSongs = nil
songLibrary.contentCache = {}


function songLibrary.isSongFile(fileName)
    if not fileName or fileName == songLibrary.placeholder then return false end
    if fileName:find("..", 1, true) then return false end
    local extension = fileName:match("%.([^%.]+)$")
    return (extension and songLibrary.extensions[extension:lower()]) or false
end


function songLibrary.getDisplayName(fileName)
    local name = fileName:gsub("%.[^%.]+$", ""):gsub("_", " ")
    return name
end


function songLibrary.ensureCacheDirectory()
    local files = listFilesInZomboidLuaDirectory(songLibrary.cacheDirectory)
    if files and files:size() > 0 then return end

    local writer = getFileWriter(songLibrary.cacheDirectory.."/"..songLibrary.placeholder, true, false)
    if writer then writer:close() end
end


function songLibrary.collectSongs(files, source)
    local songs = {}
    if not files then return songs end

    local seen = {}
    for i=0, files:size()-1 do
        local fileName = files:get(i)
        if songLibrary.isSongFile(fileName) and not seen[fileName] then
            seen[fileName] = true
            local title = songLibrary.getDisplayName(fileName)
            table.insert(songs, { title = title, searchTitle = title:lower(), fileName = fileName, source = source })
        end
    end

    table.sort(songs, function(a, b) return a.searchTitle < b.searchTitle end)
    return songs
end


function songLibrary.fetchSongs()
    songLibrary.ensureCacheDirectory()

    if not songLibrary.modSongs then
        songLibrary.modSongs = songLibrary.collectSongs(listFilesInModDirectory(songLibrary.modID, songLibrary.modDirectory), "mod")
    end

    local songs = songLibrary.collectSongs(listFilesInZomboidLuaDirectory(songLibrary.cacheDirectory), "cache")
    for _,song in ipairs(songLibrary.modSongs) do
        table.insert(songs, song)
    end

    return songs
end


function songLibrary.readSong(song)
    if not song or not song.fileName then return "" end

    local cached = (song.source == "mod") and songLibrary.contentCache[song.fileName]
    if cached then return cached end

    local reader
    if song.source == "mod" then
        reader = getModFileReader(songLibrary.modID, songLibrary.modDirectory.."/"..song.fileName, false)
    else
        reader = getFileReader(songLibrary.cacheDirectory.."/"..song.fileName, false)
    end
    if not reader then return "" end

    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()

    local content = table.concat(lines, "\n").."\n"
    if song.source == "mod" then songLibrary.contentCache[song.fileName] = content end

    return content
end


return songLibrary