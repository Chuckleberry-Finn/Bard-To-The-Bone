local Bard = require "BardToTheBone_main"
Events.OnPlayerUpdate.Add(Bard.playLoadedSongs)
Events.OnTick.Add(Bard.updateRemotePlayers)
Events.OnCreatePlayer.Add(function(_, player) Bard.updateWornInstruments(player) end)
Events.OnClothingUpdated.Add(function(player) if instanceof(player, "IsoPlayer") and player:isLocalPlayer() then Bard.updateWornInstruments(player) end end)
Events.OnPlayerUpdate.Add(Bard.checkWornInstruments)
Events.OnCreatePlayer.Add(function(_, player) Bard.retintContainer(player:getInventory()) end)
Events.OnRefreshInventoryWindowContainers.Add(Bard.retintInventoryPage)
Events.LoadGridsquare.Add(Bard.retintSquare)

local function onServerCommand(_module, _command, _data)
    if _module ~= "BardToTheBone" then return end
    if _command == "notes" then Bard.receiveNotes(_data)
    elseif _command == "stop" then Bard.receiveStop(_data)
    elseif _command == "clock" then Bard.receiveClock(_data)
    end
end
Events.OnServerCommand.Add(onServerCommand)

local context = require "BardToTheBone_contextMenu"
Events.OnPreFillInventoryObjectContextMenu.Add(context.addInventoryItemContext)