local bardNetworkHandler = {}

bardNetworkHandler.relayRange = 60
bardNetworkHandler.maxXpPerSecond = 2
bardNetworkHandler.maxXpWindowMs = 10000
bardNetworkHandler.xpTimes = {}
bardNetworkHandler.familyPerks = { Strings = "BardStrings", Keys = "BardKeys", Winds = "BardWinds", Percussion = "BardPercussion" }

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


function bardNetworkHandler.skillsEnabled()
    local options = SandboxVars.BardToTheBone
    return (not options) or (options.EnableSkills ~= false)
end


function bardNetworkHandler.getFamilyPerk(family)
    local id = family and bardNetworkHandler.familyPerks[family]
    return id and Perks[id]
end


function bardNetworkHandler.getXpMultiplier()
    local options = SandboxVars.BardToTheBone
    return options and options.XpMultiplier or 1
end


---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.sendXp(player, amount, family)
    local perk = bardNetworkHandler.getFamilyPerk(family)
    if not player or not amount or amount <= 0 or not perk or not bardNetworkHandler.skillsEnabled() then return end
    if isClient() then
        sendClientCommand(player, "BardToTheBone", "xp", { a = amount, f = family })
    else
        addXp(player, perk, amount * bardNetworkHandler.getXpMultiplier())
    end
end


---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.receiveXp(player, data)
    local amount = data and tonumber(data.a)
    local perk = data and bardNetworkHandler.getFamilyPerk(data.f)
    if not player or not amount or amount <= 0 or not perk or not bardNetworkHandler.skillsEnabled() then return end

    local id = player:getOnlineID()
    local now = getTimestampMs()
    local last = bardNetworkHandler.xpTimes[id] or (now - bardNetworkHandler.maxXpWindowMs)
    local window = math.min(now - last, bardNetworkHandler.maxXpWindowMs)
    bardNetworkHandler.xpTimes[id] = now

    local allowed = window / 1000 * bardNetworkHandler.maxXpPerSecond
    if allowed > 0 then addXp(player, perk, math.min(amount, allowed) * bardNetworkHandler.getXpMultiplier()) end
end


---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.sendClockRequest(player, localTime)
    if not player or not isClient() then return end
    sendClientCommand(player, "BardToTheBone", "clock", { t = localTime })
end


---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.replyClock(player, data)
    if not player or not data or not tonumber(data.t) then return end
    sendServerCommand(player, "BardToTheBone", "clock", { t = tonumber(data.t), s = getTimestampMs() })
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