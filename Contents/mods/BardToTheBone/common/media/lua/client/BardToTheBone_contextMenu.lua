require "ISUI/ISInventoryPaneContextMenu"

local Bard = require "BardToTheBone_main"

local bardContext = {}

function bardContext.triggerTimedAction(character, instrument)

    if luautils.haveToBeTransfered(character, instrument) then
        ISTimedActionQueue.add(ISInventoryTransferAction:new(character, instrument, instrument:getContainer(), character:getInventory()))
    end

    --if not character:getInventory():contains(instrument) then return end

    local ui = BardUIWindow:new(200, 200, 400, 640, character, instrument)
    ui:initialise()
    ui:addToUIManager()
end

---@param context ISContextMenu
function bardContext.addInventoryItemContext(playerID, context, items)
    local playerObj = getSpecificPlayer(playerID)

    for _, v in ipairs(items) do

        ---@type InventoryItem
        local item = v
        local stack
        if not instanceof(v, "InventoryItem") then
            stack = v
            item = v.items[1]
        end

        local instrumentData = item and Bard.getInstrumentData(item)
        if instrumentData then
            local play = context:addOptionOnTop(getText("IGUI_BardToTheBone_Play"), playerObj, bardContext.triggerTimedAction, item)
            --play.iconTexture = getTexture()
            break
        end
    end
end

---SAVE THIS FOR IN WORLD OBJECTS, LIKE A PIANO OR GLOCKENSPIEL ?
function bardContext.addWorldContext(playerID, context, worldObjects, test)

    ---@type IsoObject|IsoGameCharacter|IsoPlayer
    local playerObj = getSpecificPlayer(playerID)
    local square

    for _,v in ipairs(worldObjects) do square = v:getSquare() end
    if not square then return false end

    if square and ( square:DistToProper(playerObj) <= 1.5 ) then
        local objects = square:getObjects()
        for i=0,objects:size()-1 do
            ---@type IsoObject
            local object = objects:get(i)
            if object and instanceof(object, "IsoObject") then
                print(object:getProperties():Is("GroupName"))
                --local option = context:addOptionOnTop(getText("IGUI_BardToTheBone_Play"), playerObj, bardContext.triggerTimedAction, playerObj)
                --return true
            end
        end
    end
    return false
end
Events.OnFillWorldObjectContextMenu.Add(bardContext.addWorldContext)


return bardContext