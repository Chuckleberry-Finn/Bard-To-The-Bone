local bardNetworkHandler = {}

---@param player IsoPlayer|IsoGameCharacter
function bardNetworkHandler.sendUpdate(player)
    if not player then return end

    local sq = player:getSquare()
    if not sq then return end
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()

    local dataToSend = { x, y, z }

    if isClient() then
        sendClientCommand(player, "BardToTheBone", "update", {dataToSend})
    else
        bardNetworkHandler.receiveUpdate(dataToSend)
    end
end


function bardNetworkHandler.receiveUpdate(data)--x, y, z

    local x, y, z = data[1], data[2], data[3]
    local listener = getPlayer()
    local lx, ly, lz = listener:getX(), listener:getY(), listener:getZ()
    local dist = IsoUtils.DistanceTo(x, y, z, lx, ly, lz)

    if dist <= 30 then
        local bodyDamage = listener:getBodyDamage()
        --listener:getStats():setAnger(listener:getStats():getAnger()+0.1)
        bodyDamage:setBoredomLevel(math.max(0,bodyDamage:getBoredomLevel()-0.1))
        bodyDamage:setUnhappynessLevel(math.max(0,bodyDamage:getUnhappynessLevel()-0.1))
    end
end

return bardNetworkHandler