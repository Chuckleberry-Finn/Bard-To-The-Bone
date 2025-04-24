local Bard = require "BardToTheBone_main"
Events.OnPlayerUpdate.Add(Bard.playLoadedSongs)

local context = require "BardToTheBone_contextMenu"
Events.OnPreFillInventoryObjectContextMenu.Add(context.addInventoryItemContext)