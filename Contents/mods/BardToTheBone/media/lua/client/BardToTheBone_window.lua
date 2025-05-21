require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"

local defaultSongs = require "BardToTheBone_defaultSongs"
local Bard = require "BardToTheBone_main"

BardUIWindow = ISCollapsableWindow:derive("BardUIWindow")


function BardUIWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
end

function BardUIWindow.onTextChange(box)
    if not box then return end
    box.parent:setSaveButtonStatus(true)
end

function BardUIWindow:initialise()
    ISCollapsableWindow.initialise(self)

    self.abcEntry = ISTextEntryBox:new("", self.padding, self:titleBarHeight() + self.padding, self.width - (self.padding*2), (self.height * 0.47))
    self.abcEntry:initialise()
    self.abcEntry:instantiate()
    self.abcEntry.onTextChange = BardUIWindow.onTextChange
    self.abcEntry:setMultipleLine(true)
    self.abcEntry:setMaxLines(999999)
    self.abcEntry.javaObject:setMaxTextLength(-1)
    self.abcEntry.javaObject:setWrapLines(true)
    self:addChild(self.abcEntry)

    local buttonY = self.abcEntry.y + self.abcEntry.height + self.padding

    local buttonHeight = self.height * 0.04
    local buttonWidth = self.width * 0.15

    self.saveButton = ISButton:new(self.padding, buttonY, buttonWidth, buttonHeight, "Save", self, BardUIWindow.onSave)
    self.saveButton:initialise()
    self.saveButton:instantiate()
    self:addChild(self.saveButton)

    local buttonOffset = (self.padding/2)+self.padding+buttonWidth

    self.loadButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, "Load All", self, BardUIWindow.onLoadAllButton)
    self.loadButton:initialise()
    self.loadButton:instantiate()
    self:addChild(self.loadButton)

    buttonOffset = buttonOffset + buttonWidth + (self.padding/2)

    self.newButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, "New", self, BardUIWindow.onNewButton)
    self.newButton:initialise()
    self.newButton:instantiate()
    self:addChild(self.newButton)

    buttonOffset = buttonOffset + buttonWidth + (self.padding/2)

    self.removeButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, "Remove", self, BardUIWindow.onRemoveButton)
    self.removeButton:initialise()
    self.removeButton:instantiate()
    self:addChild(self.removeButton)

    --[[
    self.closeButton = ISButton:new(self.width - 70, buttonY, 60, 25, "Close", self, BardUIWindow.close)
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self:addChild(self.closeButton)
    --]]

    local styles = self.styles~=nil

    local playWidth = (self.width*0.225)+(styles and 0 or buttonHeight)

    self.playButton = ISButton:new(self.width * 0.6875 , buttonY, playWidth, buttonHeight, "Play", self, BardUIWindow.onPlay)
    self.playButton:initialise()
    self.playButton:instantiate()
    self:addChild(self.playButton)

    self.styleButton = ISButton:new(self.width * 0.91 , buttonY, buttonHeight, buttonHeight, "*", self, BardUIWindow.onStyle)
    self.styleButton:initialise()
    self.styleButton:instantiate()
    self:addChild(self.styleButton)
    self.styleButton:setVisible(styles)

    local resizeOffset = self.resizable and self:resizeWidgetHeight() or 0
    local songListHeight = self.height - self.abcEntry.height - self.saveButton.height - (self.padding * 4) - self:titleBarHeight() - resizeOffset
    self.songList = ISScrollingListBox:new(self.padding, self.saveButton.y + self.saveButton.height + self.padding, self.width - (self.padding * 2), songListHeight)
    self.songList:initialise()
    self.songList:instantiate()

    local itemHeight = getTextManager():getFontHeight(UIFont.AutoNormSmall)+2
    
    self.songList.itemheight = itemHeight
    self.songList.doDrawItem = BardUIWindow.doDrawSong
    self.songList.onMouseDown = BardUIWindow.onSongClick
    self:addChild(self.songList)

    self.songs = {}

    self:setInfo(getText("IGUI_BardToTheBone_Info"))

    self:onLoadAll()
end


function BardUIWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end


function BardUIWindow:onSave()
    local notes = self.abcEntry:getText()
    if (not notes) then return end

    local title = notes:match("T:(.-)\n")
    local index = notes:match("X:(.-)\n")

    if not title then notes = "T:[No Title]\n"..notes end
    if not index then notes = "X:1\n"..notes end

    local song = self.songList.items[self.songList.selected]
    if not song then
        self.songList:addItem(title, notes)
    else
        song.text = title
        song.item = notes
    end

    local compiled = ""
    for i,songData in ipairs(self.songList.items) do
        compiled = compiled .. songData.item
    end

    local writer = getFileWriter("BardToTheBone_Songs.txt", true, false)
    writer:write(compiled)
    writer:close()

    self:onLoadAll(self.songList.selected)
    self:setSaveButtonStatus(false)
end


function BardUIWindow:fetchSavedSongs()
    local reader = getFileReader("BardToTheBone_Songs.txt", false)
    local content = ""

    if reader then
        local line = reader:readLine()
        while line ~= nil do
            content = content .. line .. "\n"
            line = reader:readLine()
        end
        reader:close()

    end

    if not reader or content == "" then
        for _,song in pairs(defaultSongs) do
            content = content .. song .. "\n\n"
        end
    end

    content = content:gsub("%s*$", "") .. "\n\n"
    return content
end


function BardUIWindow:onLoadAllButton() self:onLoadAll() end
function BardUIWindow:onLoadAll(index)
    self.abcEntry:setText("")
    local old_selected = index or self.songList.selected or 1
    self.songList:clear()

    local bigString = self:fetchSavedSongs()
    if bigString then
        local songs = {}

        local pos = 1
        while true do
            local start_pos = bigString:find("X:%s*%d+", pos)
            if not start_pos then break end

            local next_start = bigString:find("X:%s*%d+", start_pos + 1)
            local song_block = next_start and bigString:sub(start_pos, next_start - 1) or bigString:sub(start_pos)

            local title_found = song_block:match("T:(.-)\n")
            local title = title_found or "[No Title]"

            table.insert(songs, { title = title, content = song_block })

            if not next_start then break end
            pos = next_start
        end

        for _, song in ipairs(songs) do
            self.songList:addItem(song.title, song.content)
        end
    end

    self:loadSongAtIndex(old_selected)
end


function BardUIWindow:onNewButton()
    self.songList:addItem("New Song", "")
    self:loadSongAtIndex(self.songList:size())
end


function BardUIWindow:onRemoveButton()
    if not self.songList.selected then return end
    self.songList:removeItemByIndex(self.songList.selected)
    self:loadSongAtIndex(self.songList.selected)
    self:setSaveButtonStatus(true)
end


function BardUIWindow:setSaveButtonStatus(set)
    if set ~= nil then self.unsavedChanges = set end
    local r, g, b, a = 0, set==true and 0.5 or 0, 0, 0.5
    self.saveButton.backgroundColor = {r=r, g=g, b=b, a=a}
end


function BardUIWindow:doDrawSong(y, item, alt)
    local r, g, b, a = 1, 1, 1, 0.9
    self:drawRect(2, y+2, self:getWidth()-4, self.itemheight-2, ((self.selected == item.index) and 0.4) or 0.2, r, g, b)
    self:drawText(item.text, self.parent.padding, y+2, r, g, b, a, UIFont.AutoNormSmall)
    return y + item.height
end


function BardUIWindow:loadSongAtIndex(index)
    if not index then return end

    local item = self.songList.items[index]
    if not item then return end

    self.songList.selected = index
    self.abcEntry:setText(item.item)
    self.abcEntry:setYScroll(0)
end


function BardUIWindow:onSongClick(x, y)
    local index = self:rowAt(x, y)
    if not index then return end
    self.parent:loadSongAtIndex(index)
end


function BardUIWindow:onPlay()

    local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.character)
    local currentAction = actionQueue.queue[1]
    if currentAction and (currentAction.Type == "BardToTheBonePlayMusic") and currentAction.action then
        currentAction.action:forceStop()
        return
    end

    local notes = self.abcEntry:getText()
    if (not notes) then return end

    ISTimedActionQueue.add(BardToTheBonePlayMusic:new(self.character, self.instrument, notes, self.style))
end


function BardUIWindow:setStyle(style)
    self.style = style

    local id = self.character:getUsername()
    if Bard.players[id] then Bard.players[id].style = style end
end


function BardUIWindow:onStyle()
    local playerNum = self.character:getPlayerNum()
    self.contextMenu = ISContextMenu.get(playerNum,self:getX()+self.styleButton:getX()+self.styleButton:getWidth(), self:getY()+self.styleButton:getY())
    self.contextMenu.player = playerNum
    for _,style in pairs(self.styles) do
        ---@type ISContextMenu
        local option = self.contextMenu:addOption(style, self, BardUIWindow.setStyle, style)
        if style == self.style then option.notAvailable = true end
    end
end


function BardUIWindow:update()
    if not BardUIWindow.instance then return end

    if (self.isItem and (self.character:getPrimaryHandItem() ~= self.instrument))
            or (not self.isItem and (self.instrument:getSquare():DistToProper(self.character) > 1.5)) then
        BardUIWindow.instance:close()
    end
end

function BardUIWindow.open(character, instrument)
    local ui = BardUIWindow:new(character, instrument)
    ui:initialise()
    ui:addToUIManager()
    return ui
end

---@param instrument InventoryItem
function BardUIWindow:new(character, instrument)

    if BardUIWindow.instance then BardUIWindow.instance:close() end

    --- w:400, h:640
    local x, y = getCore():getScreenWidth()*0.1, getCore():getScreenHeight()*0.2
    local width, height = getCore():getScreenWidth()*0.2, getCore():getScreenHeight()*0.6

    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o:setResizable(false)
    ---@type IsoPlayer|IsoGameCharacter|IsoMovingObject
    o.character = character
    o.instrument = instrument
    o.unsavedChanges = false

    o.padding = width * 0.025

    o.isItem = instanceof(instrument, "InventoryItem")

    o.title = "Bard to the Bone - ".. (o.isItem and instrument:getDisplayName() or instrument:getTileName())

    if not o.isItem then
        o.character:faceThisObject(instrument)
    end

    local data = Bard.getInstrumentData(instrument)
    if data and data.styles then
        o.styles = data.styles
        o.style = data.styles[1]
    end

    BardUIWindow.instance = o

    return o
end