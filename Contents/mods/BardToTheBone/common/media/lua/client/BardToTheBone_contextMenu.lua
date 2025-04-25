require "ISUI/ISInventoryPaneContextMenu"

local Bard = require "BardToTheBone_main"

local bardContext = {}

function bardContext.triggerTimedAction(character, instrument)
    if not character:getInventory():contains(instrument) then return end
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

        local instrumentID = item and Bard.getInstrumentID(item)
        if instrumentID then
            local play = context:addOptionOnTop(getText("IGUI_BardToTheBone_Play"), playerObj, bardContext.triggerTimedAction, item)
            --play.iconTexture = getTexture()
            break
        end
    end
end

---SAVE THIS FOR IN WORLD OBJECTS, LIKE A PIANO OR GLOCKENSPIEL ?
--[[
function bardContext.addWorldContext(playerID, context, worldObjects, test)

    ---@type IsoObject|IsoGameCharacter|IsoPlayer
    local playerObj = getSpecificPlayer(playerID)
    local square

    for _,v in ipairs(worldObjects) do square = v:getSquare() end
    if not square then return false end

    if square and ( square:DistToProper(playerObj) <= 1.5 ) then

        local validObjectCount = 0

        for i=0,square:getObjects():size()-1 do
            ---@type IsoObject|IsoWorldInventoryObject
            --TODO: CHECK FOR MAP OBJECTS NOT IsoWorldInventoryObject
            local object = square:getObjects():get(i)
            if object and instanceof(object, "IsoWorldInventoryObject") then
                local item = object:getItem()
                if item and TEST then
                    validObjectCount = validObjectCount+1
                end
            end
        end

        if validObjectCount > 0 then
            local option = context:addOptionOnTop(getText("IGUI_Play_Game"), worldObjects, gameNightWindow.open, playerObj, square)
            option.iconTexture = getTexture()
        end
    end
    return false
end
Events.OnFillWorldObjectContextMenu.Add(bardContext.addWorldContext)
-------------------------------------------------------------------------------------------]]

return bardContext