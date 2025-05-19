require "ISUI/ISInventoryPaneContextMenu"

local Bard = require "BardToTheBone_main"

local bardContext = {}

---To get specific positions, I know there's a walktoF but I don't feel like dealing with vectors
bardContext.nonSquareLocation = {x=0,y=0,z=0}
function bardContext.nonSquareLocation:getX() return self.x end
function bardContext.nonSquareLocation:getY() return self.y end
function bardContext.nonSquareLocation:getZ() return self.z end

function bardContext.nonSquareLocation:set(square, xOffset, yOffset)
    bardContext.nonSquareLocation.x = square:getX()+xOffset
    bardContext.nonSquareLocation.y = square:getY()+yOffset
    bardContext.nonSquareLocation.z = square:getZ()
end


function bardContext.triggerTimedAction(character, instrument, square, dir)

    if instanceof(instrument, "InventoryItem") then
        if luautils.haveToBeTransfered(character, instrument) then
            local transfer = ISInventoryTransferAction:new(character, instrument, instrument:getContainer(), character:getInventory())
            transfer:setOnComplete(BardUIWindow.open, character, instrument)
            ISTimedActionQueue.add(transfer)
        end

        if character:getPrimaryHandItem() ~= instrument then
            local equip = ISEquipWeaponAction:new(character, instrument, 50, true)
            ISTimedActionQueue.add(equip)

            local wait = ISQueueActionsAction:new(character, BardUIWindow.open, instrument)
            ISTimedActionQueue.add(wait)
            return
        end
    end

    if square and ( square:DistToProper(character) > 1.51 ) then
        local xOffset = dir and dir == IsoDirections.E and 1.5 or 0
        local yOffset = dir and dir == IsoDirections.S and 1.5 or 0
        bardContext.nonSquareLocation:set(square, xOffset, yOffset)
        local walkTo = ISWalkToTimedAction:new(character, bardContext.nonSquareLocation)
        walkTo:setOnComplete(BardUIWindow.open, character, instrument)
        ISTimedActionQueue.add(walkTo)
        return
    end

    BardUIWindow.open(character, instrument)
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
            break
        end
    end
end

---SAVE THIS FOR IN WORLD OBJECTS, LIKE A PIANO OR GLOCKENSPIEL ?
function bardContext.addWorldContext(playerID, context, worldObjects, test)

    ---@type IsoObject|IsoGameCharacter|IsoPlayer
    local playerObj = getSpecificPlayer(playerID)
    local square

    for _,v in ipairs(worldObjects) do
        square = v:getSquare()
    end
    if not square then return false end

    if square then
        local objects = square:getObjects()
        for i=0,objects:size()-1 do
            ---@type IsoObject
            local object = objects:get(i)
            if object and instanceof(object, "IsoObject") then
                local data = Bard.getInstrumentData(object)
                if data then
                    local sprites = data.playFromSprites
                    local sprite = object:getSpriteName()
                    if (not sprites) or sprites[sprite] then
                        local dir = object:getFacing()
                        local sq = square
                        local play = context:addOptionOnTop(getText("IGUI_BardToTheBone_Play"), playerObj, bardContext.triggerTimedAction, object, sq, dir)
                        return true
                    end
                end
            end
        end
    end
    return false
end
Events.OnFillWorldObjectContextMenu.Add(bardContext.addWorldContext)


return bardContext