local bardNetworkHandler = {}

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


--- There is an IsoUtils function by this same name added in B42
function bardNetworkHandler.DistanceTo(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end


function bardNetworkHandler.receiveUpdate(data)--x, y, z

    local x, y, z = data[1], data[2], data[3]
    local listener = getPlayer()
    local lx, ly, lz = listener:getX(), listener:getY(), listener:getZ()
    local dist = bardNetworkHandler.DistanceTo(x, y, z, lx, ly, lz)

    if dist <= 30 then
        local bodyDamage = listener:getBodyDamage()
        --listener:getStats():setAnger(listener:getStats():getAnger()+0.1)
        bodyDamage:setBoredomLevel(math.max(0,bodyDamage:getBoredomLevel()-0.5))
        bodyDamage:setUnhappynessLevel(math.max(0,bodyDamage:getUnhappynessLevel()-0.5))
    end
end

return bardNetworkHandler