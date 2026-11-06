local bardNetworkHandler = {}

bardNetworkHandler.relayRange = 60

---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.sendUpdate(player)
    if not player then return end

    local sq = player:getSquare()
    if not sq then return end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()

    local dataToSend = { x, y, z }

    if isClient() then
        sendClientCommand(player, "BardToTheBone", "update", dataToSend)
    else
        bardNetworkHandler.receiveUpdate(dataToSend)
    end
end


---@param listener IsoPlayer|IsoGameCharacter
function bardNetworkHandler.applyToListener(listener, x, y, z)
    if not listener then return end

    local lx, ly, lz = listener:getX(), listener:getY(), listener:getZ()
    local dist = IsoUtils.DistanceTo(x, y, z, lx, ly, lz)

    if dist <= 30 then
        --listener:getStats():setAnger(listener:getStats():getAnger()+0.1)
        local stats = listener:getStats()
        stats:set(CharacterStat.BOREDOM, stats:get(CharacterStat.BOREDOM) - 0.5 )
        stats:set(CharacterStat.UNHAPPINESS, stats:get(CharacterStat.UNHAPPINESS) - 0.5 )
    end
end


function bardNetworkHandler.receiveUpdate(data)--x, y, z

    local x, y, z = data[1], data[2], data[3]

    if isServer() then
        local players = getOnlinePlayers()
        for i=0, players:size()-1 do
            bardNetworkHandler.applyToListener(players:get(i), x, y, z)
        end
        return
    end

    for i=0, getNumActivePlayers()-1 do
        bardNetworkHandler.applyToListener(getSpecificPlayer(i), x, y, z)
    end
end

---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.sendNotes(player, data)
    if not player or not isClient() or player:isInvisible() then return end
    sendClientCommand(player, "BardToTheBone", "notes", data)
end


---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.sendStop(player)
    if not player or not isClient() then return end
    sendClientCommand(player, "BardToTheBone", "stop", {})
end


---@param sender IsoPlayer|IsoGameCharacter
function bardNetworkHandler.relayToNearby(sender, command, data, ignoreRange)
    if not sender or not data then return end
    data.id = sender:getOnlineID()

    local sx, sy, sz = sender:getX(), sender:getY(), sender:getZ()
    local players = getOnlinePlayers()
    for i=0, players:size()-1 do
        local listener = players:get(i)
        if listener ~= sender then
            local inRange = ignoreRange or (IsoUtils.DistanceTo(sx, sy, sz, listener:getX(), listener:getY(), listener:getZ()) <= bardNetworkHandler.relayRange)
            if inRange then sendServerCommand(listener, "BardToTheBone", command, data) end
        end
    end
end

return bardNetworkHandler