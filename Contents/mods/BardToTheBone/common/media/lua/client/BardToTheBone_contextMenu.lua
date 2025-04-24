require "ISUI/ISInventoryPaneContextMenu"

local Bard = require "BardToTheBone_main"

local bardContext = {}

function bardContext.triggerTimedAction(character, instrument, abcNotation)

    abcNotation = [[
X:1
T:Twinkle, Twinkle Little Star in C
M:C
K:C
L:1/4
Q:88
vC C G G|A A G2|F F E E|D D C2|vG G F F|E E D2|
uG G F F|E E D2|vC C G G|A A G2|uF F E E|D D C2|]
]]

    ISTimedActionQueue.add(BardToTheBonePlayMusic:new(character, instrument, abcNotation))
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
            local play = context:addOptionOnTop(getText("IGUI_Play"), playerObj, bardContext.triggerTimedAction, item)
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