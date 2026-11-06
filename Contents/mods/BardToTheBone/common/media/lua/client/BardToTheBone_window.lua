require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"
require "RadioCom/ISUIRadio/ISSliderPanel"

local defaultSongs = require "BardToTheBone_defaultSongs"
local songLibrary = require "BardToTheBone_songLibrary"
local settings = require "BardToTheBone_settings"
local Bard = require "BardToTheBone_main"

BardUIWindow = ISCollapsableWindow:derive("BardUIWindow")

BardUIWindow.sourceColors = {
    saved = { r = 1, g = 1, b = 1 },
    cache = { r = 0.7, g = 1, b = 0.7 },
    mod = { r = 0.7, g = 0.8, b = 1 },
}


function BardUIWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
end

function BardUIWindow.onTextChange(box)
    if not box then return end
    box.parent:setSaveButtonStatus(true)
    box.parent:refreshVoiceButton()
end

function BardUIWindow.onSearchChange(box)
    if not box then return end
    box.parent.searchText = box:getInternalText():lower()
    box.parent:populateSongList()
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

    self.playRowBaseX = self.width * 0.6875
    self.playRowBaseWidth = (self.width*0.225)+(styles and 0 or buttonHeight)
    self.playRowButtonHeight = buttonHeight
    self.buttonOverlap = self.width * 0.0025

    self.voiceButton = ISButton:new(self.playRowBaseX, buttonY, buttonHeight, buttonHeight, "v", self, BardUIWindow.onVoice)
    self.voiceButton:initialise()
    self.voiceButton:instantiate()
    self:addChild(self.voiceButton)
    self.voiceButton:setVisible(false)

    local playWidth = self.playRowBaseWidth

    self.playButton = ISButton:new(self.width * 0.6875 , buttonY, playWidth, buttonHeight, "Play", self, BardUIWindow.onPlay)
    self.playButton:initialise()
    self.playButton:instantiate()
    self:addChild(self.playButton)

    self.playButtonDefaultColor = { r = self.playButton.backgroundColor.r, g = self.playButton.backgroundColor.g,
                                     b = self.playButton.backgroundColor.b, a = self.playButton.backgroundColor.a }
    self.playButtonDefaultColorMouseOver = { r = self.playButton.backgroundColorMouseOver.r, g = self.playButton.backgroundColorMouseOver.g,
                                              b = self.playButton.backgroundColorMouseOver.b, a = self.playButton.backgroundColorMouseOver.a }
    self.playButtonStopColor = { r = 0.45, g = 0.05, b = 0.05, a = 1 }
    self.playButtonStopColorMouseOver = { r = 0.6, g = 0.08, b = 0.08, a = 1 }

    self.styleButton = ISButton:new(self.width * 0.91 , buttonY, buttonHeight, buttonHeight, "*", self, BardUIWindow.onStyle)
    self.styleButton:initialise()
    self.styleButton:instantiate()
    self:addChild(self.styleButton)
    self.styleButton:setVisible(styles)

    self.voices = {}
    self.voice = nil -- nil/"All" => play every voice (matches old, pre-voice-picker behavior)

    local sliderY = self.playButton.y + self.saveButton.height + self.padding
    self.volumeSlider = ISSliderPanel:new(self.padding, sliderY, self.width - (self.padding * 2), buttonHeight/2, self, BardUIWindow.setVolume)
    self.volumeSlider:initialise()
    self.volumeSlider:instantiate()
    self:addChild(self.volumeSlider)
    self.volumeSlider:setCurrentValue(self.volume)

    local searchY = self.volumeSlider.y + self.volumeSlider.height + self.padding
    local hideModLabel = getText("IGUI_BardToTheBone_HideModSongs")
    local hideModWidth = buttonHeight + 10 + getTextManager():MeasureStringX(UIFont.Small, hideModLabel)
    local searchWidth = self.width - (self.padding * 3) - hideModWidth

    self.searchText = ""
    self.searchEntry = ISTextEntryBox:new("", self.padding, searchY, searchWidth, buttonHeight)
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry.onTextChange = BardUIWindow.onSearchChange
    self.searchEntry:setPlaceholderText(getText("IGUI_FilterSearch"))
    self.searchEntry:setClearButton(true)
    self:addChild(self.searchEntry)

    self.hideModTickBox = ISTickBox:new(self.searchEntry.x + searchWidth + self.padding, searchY, hideModWidth, buttonHeight, "", self, BardUIWindow.onHideModSongs)
    self.hideModTickBox:initialise()
    self.hideModTickBox:instantiate()
    self:addChild(self.hideModTickBox)
    self.hideModTickBox:addOption(hideModLabel)
    self.hideModTickBox:setSelected(1, settings.get("hideModSongs"))

    local resizeOffset = self.resizable and self:resizeWidgetHeight() or 0
    local songListY = searchY + buttonHeight + self.padding
    local songListHeight = self.height - songListY - self:titleBarHeight() - resizeOffset
    self.songList = ISScrollingListBox:new(self.padding, songListY, self.width - (self.padding * 2), songListHeight)
    self.songList:initialise()
    self.songList:instantiate()

    local itemHeight = getTextManager():getFontHeight(UIFont.AutoNormSmall)+2

    self.songList.itemheight = itemHeight
    self.songList.doDrawItem = BardUIWindow.doDrawSong
    self.songList.onMouseDown = BardUIWindow.onSongClick
    self:addChild(self.songList)

    self.savedSongs = {}
    self.librarySongs = {}
    self.selectedSong = nil

    self:setInfo(getText("IGUI_BardToTheBone_Info"))

    self:onLoadAll()
    self:refreshVoiceButton()
    self:refreshPlayButtonState()
end


function BardUIWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if BardUIWindow.instance == self then
        BardUIWindow.instance = nil
    end
end


function BardUIWindow:onSave()
    local notes = self.abcEntry:getText()
    if (not notes) then return end

    local title = notes:match("T:(.-)\n")
    local index = notes:match("X:(.-)\n")

    if not title then notes = "T:[No Title]\n"..notes end
    if not index then notes = "X:1\n"..notes end

    local song = self.selectedSong
    local savedIndex = song and (song.source == "saved") and Bard.table_indexof(self.savedSongs, song)
    if savedIndex then
        song.title = title
        song.content = notes
    else
        table.insert(self.savedSongs, { title = title, content = notes, source = "saved" })
        savedIndex = #self.savedSongs
    end

    local compiled = ""
    for _,songData in ipairs(self.savedSongs) do
        compiled = compiled .. songData.content:gsub("%s*$", "") .. "\n\n"
    end

    local writer = getFileWriter("BardToTheBone_Songs.txt", true, false)
    writer:write(compiled)
    writer:close()

    self:onLoadAll(savedIndex)
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
function BardUIWindow:onLoadAll(savedIndex)
    self.abcEntry:setText("")

    local previous = self.selectedSong
    if not savedIndex and previous and previous.source == "saved" then
        savedIndex = Bard.table_indexof(self.savedSongs, previous)
    end

    self.savedSongs = {}
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
            table.insert(self.savedSongs, { title = song.title, content = song.content, source = "saved" })
        end
    end

    self.librarySongs = songLibrary.fetchSongs()

    local selected = savedIndex and self.savedSongs[savedIndex]
    if not selected and previous and previous.fileName then
        for _,song in ipairs(self.librarySongs) do
            if song.source == previous.source and song.fileName == previous.fileName then
                selected = song
                break
            end
        end
    end

    self.selectedSong = selected or self.savedSongs[1] or self.librarySongs[1]
    self:populateSongList()
    self:loadSong(self.selectedSong)
end


function BardUIWindow:isSongVisible(song)
    if settings.get("hideModSongs") and song.source == "mod" then return false end
    if self.searchText == nil or self.searchText == "" then return true end
    local searchTitle = song.searchTitle or (song.title or ""):lower()
    return searchTitle:find(self.searchText, 1, true) ~= nil
end


function BardUIWindow:populateSongList()
    self.songList:clear()

    for _,song in ipairs(self.savedSongs) do
        if self:isSongVisible(song) then self.songList:addItem(song.title, song) end
    end

    for _,song in ipairs(self.librarySongs) do
        if self:isSongVisible(song) then self.songList:addItem(song.title, song) end
    end

    self:selectSongInList()
end


function BardUIWindow:selectSongInList()
    self.songList.selected = 0
    if not self.selectedSong then return end

    for i,item in ipairs(self.songList.items) do
        if item.item == self.selectedSong then
            self.songList.selected = i
            self.songList:ensureVisible(i)
            return
        end
    end
end


function BardUIWindow:onHideModSongs(index, selected)
    settings.set("hideModSongs", selected == true)
    self:populateSongList()
end


function BardUIWindow:onNewButton()
    self.searchText = ""
    self.searchEntry:setText("")

    local song = { title = "New Song", content = "", source = "saved" }
    table.insert(self.savedSongs, song)
    self.selectedSong = song
    self:populateSongList()
    self:loadSong(song)
end


function BardUIWindow:onRemoveButton()
    local song = self.selectedSong
    local savedIndex = song and (song.source == "saved") and Bard.table_indexof(self.savedSongs, song)
    if not savedIndex then return end

    table.remove(self.savedSongs, savedIndex)
    self.abcEntry:setText("")
    self.selectedSong = self.savedSongs[savedIndex] or self.savedSongs[savedIndex-1]
    self:populateSongList()
    self:loadSong(self.selectedSong)
    self:setSaveButtonStatus(true)
end


function BardUIWindow:setSaveButtonStatus(set)
    if set ~= nil then self.unsavedChanges = set end
    local r, g, b, a = 0, set==true and 0.5 or 0, 0, 0.5
    self.saveButton.backgroundColor = {r=r, g=g, b=b, a=a}
end


function BardUIWindow:doDrawSong(y, item, alt)
    if (y + self:getYScroll() + self.itemheight < 0) or (y + self:getYScroll() >= self.height) then
        return y + item.height
    end

    local color = BardUIWindow.sourceColors[item.item and item.item.source] or BardUIWindow.sourceColors.saved
    local r, g, b, a = color.r, color.g, color.b, 0.9
    self:drawRect(2, y+2, self:getWidth()-4, self.itemheight-2, ((self.selected == item.index) and 0.4) or 0.2, r, g, b)
    self:drawText(item.text, self.parent.padding, y+2, r, g, b, a, UIFont.AutoNormSmall)
    return y + item.height
end


function BardUIWindow:getSongContent(song)
    if not song then return "" end
    if song.content then return song.content end
    return songLibrary.readSong(song)
end


function BardUIWindow:loadSong(song)
    if not song then return end

    self.selectedSong = song
    self:selectSongInList()
    self.abcEntry:setText(self:getSongContent(song))
    self.abcEntry:setYScroll(0)
    self:refreshVoiceButton()
end


function BardUIWindow:onSongClick(x, y)
    local index = self:rowAt(x, y)
    local item = index and self.items[index]
    if not item then return end
    self.parent:loadSong(item.item)
end


function BardUIWindow:onPlay()

    local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.character)
    local currentAction = actionQueue.queue[1]
    local isBardAction = currentAction and (currentAction.Type == "BardToTheBonePlayMusic") and currentAction.action

    if isBardAction then
        local sameInstrument = (currentAction.item == self.instrument)
        currentAction:forceStop()
        if sameInstrument then
            self:refreshPlayButtonState()
            return
        end
    end

    local notes = self.abcEntry:getText()
    if (not notes) then
        self:refreshPlayButtonState()
        return
    end

    ISTimedActionQueue.add(BardToTheBonePlayMusic:new(self.character, self.instrument, notes, self.style, self.volume, self.voice))
    self:refreshPlayButtonState()
end


function BardUIWindow:setVolume(volume)
    self.volume = volume

    local id = self.character:getUsername()
    if Bard.players[id] then Bard.players[id].volume = volume end
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


function BardUIWindow:setVoice(voice)
    self.voice = voice

    local id = self.character:getUsername()
    if Bard.players[id] then Bard.players[id].selectedVoice = voice end
end


function BardUIWindow:onVoice()
    local playerNum = self.character:getPlayerNum()
    self.contextMenu = ISContextMenu.get(playerNum,self:getX()+self.voiceButton:getX()+self.voiceButton:getWidth(), self:getY()+self.voiceButton:getY())
    self.contextMenu.player = playerNum

    local allOption = self.contextMenu:addOption("All", self, BardUIWindow.setVoice, "All")
    if (not self.voice) or self.voice == "All" then allOption.notAvailable = true end

    for _, v in ipairs(self.voices) do
        ---@type ISContextMenu
        local option = self.contextMenu:addOption(v.name, self, BardUIWindow.setVoice, v.id)
        if v.id == self.voice then option.notAvailable = true end
    end
end


function BardUIWindow:layoutPlayRow()
    local styles = self.styles ~= nil
    local hasVoices = #self.voices > 1

    local baseWidth = (self.width * 0.225) + (styles and 0 or self.playRowButtonHeight)
    local voiceOffset = hasVoices and (self.playRowButtonHeight - self.buttonOverlap) or 0

    self.voiceButton:setVisible(hasVoices)
    self.voiceButton:setX(self.playRowBaseX)

    self.playButton:setX(self.playRowBaseX + voiceOffset)
    self.playButton:setWidth(baseWidth - voiceOffset)

    self.styleButton:setVisible(styles)
end


function BardUIWindow:refreshVoiceButton()
    local text = self.abcEntry and self.abcEntry:getText() or ""
    self.voices = Bard.getVoiceOrder(text)

    -- Drop the selection if it no longer exists in the (possibly edited) tune
    if self.voice and self.voice ~= "All" then
        local stillValid = false
        for _, v in ipairs(self.voices) do
            if v.id == self.voice then stillValid = true; break end
        end
        if not stillValid then self.voice = nil end
    end

    self:layoutPlayRow()

    local id = self.character:getUsername()
    if Bard.players[id] then Bard.players[id].selectedVoice = self.voice end
end


function BardUIWindow:update()
    if not BardUIWindow.instance then return end

    local square = (not self.isItem) and self.instrument:getSquare()
    if (self.isItem and (self.character:getPrimaryHandItem() ~= self.instrument))
            or (not self.isItem and ((not square) or (square:DistToProper(self.character) > 1.5))) then
        BardUIWindow.instance:close()
        return
    end

    self:refreshPlayButtonState()
end


function BardUIWindow:refreshPlayButtonState()
    local actionQueue = ISTimedActionQueue.getTimedActionQueue(self.character)
    local currentAction = actionQueue.queue[1]
    local isBardAction = currentAction and (currentAction.Type == "BardToTheBonePlayMusic") and currentAction.action
    local isPlayingThis = isBardAction and (currentAction.item == self.instrument)

    local target = isPlayingThis and self.playButtonStopColor or self.playButtonDefaultColor
    local targetMouseOver = isPlayingThis and self.playButtonStopColorMouseOver or self.playButtonDefaultColorMouseOver

    self.playButton.title = isPlayingThis and "Stop" or "Play"

    self.playButton.backgroundColor.r = target.r
    self.playButton.backgroundColor.g = target.g
    self.playButton.backgroundColor.b = target.b
    self.playButton.backgroundColor.a = target.a

    self.playButton.backgroundColorMouseOver.r = targetMouseOver.r
    self.playButton.backgroundColorMouseOver.g = targetMouseOver.g
    self.playButton.backgroundColorMouseOver.b = targetMouseOver.b
    self.playButton.backgroundColorMouseOver.a = targetMouseOver.a
end


function BardUIWindow.open(character, instrument)
    if BardUIWindow.instance then
        BardUIWindow.instance:switchInstrument(character, instrument)
        return BardUIWindow.instance
    end

    local ui = BardUIWindow:new(character, instrument)
    ui:initialise()
    ui:addToUIManager()
    return ui
end



---@param character IsoGameCharacter
---@param instrument InventoryItem|IsoObject
function BardUIWindow:switchInstrument(character, instrument)
    self.character = character
    self.instrument = instrument
    self.isItem = instanceof(instrument, "InventoryItem")
    self.title = "Bard to the Bone - " .. (self.isItem and instrument:getDisplayName() or instrument:getTileName())

    if not self.isItem then
        self.character:faceThisObject(instrument)
    end

    local data = Bard.getInstrumentData(instrument)
    if data and data.styles then
        self.styles = data.styles
        self.style = data.styles[1]
    else
        self.styles = nil
        self.style = nil
    end

    self:layoutPlayRow()

    local id = self.character:getUsername()
    if Bard.players[id] then
        Bard.players[id].selectedVoice = self.voice
    end

    self:refreshPlayButtonState()
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

    o.volume = 100

    local data = Bard.getInstrumentData(instrument)
    if data and data.styles then
        o.styles = data.styles
        o.style = data.styles[1]
    end

    BardUIWindow.instance = o

    return o
end