local settings = {}

settings.fileName = "BardToTheBone_Settings.txt"
settings.values = {
    hideModSongs = false,
}
settings.loaded = false


function settings.load()
    if settings.loaded then return end
    settings.loaded = true

    local reader = getFileReader(settings.fileName, false)
    if not reader then return end

    local line = reader:readLine()
    while line ~= nil do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        local default = key and settings.values[key]
        if default ~= nil then
            if type(default) == "boolean" then
                settings.values[key] = (value == "true")
            elseif type(default) == "number" then
                settings.values[key] = tonumber(value) or default
            else
                settings.values[key] = value
            end
        end
        line = reader:readLine()
    end
    reader:close()
end


function settings.save()
    local writer = getFileWriter(settings.fileName, true, false)
    if not writer then return end

    local keys = {}
    for key,_ in pairs(settings.values) do table.insert(keys, key) end
    table.sort(keys)

    for _,key in ipairs(keys) do
        writer:write(key.."="..tostring(settings.values[key]).."\n")
    end
    writer:close()
end


function settings.get(key)
    settings.load()
    return settings.values[key]
end


function settings.set(key, value)
    settings.load()
    if settings.values[key] == value then return end
    settings.values[key] = value
    settings.save()
end


return settings