require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISPanel"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "RadioCom/ISUIRadio/ISSliderPanel"

local songLibrary = require "BardToTheBone_songLibrary"
local settings = require "BardToTheBone_settings"
local Bard = require "BardToTheBone_main"

BardUIWindow = ISCollapsableWindow:derive("BardUIWindow")

BardUIWindow.sourceColors = {
    abc = { r = 0.6, g = 0.72, b = 0.6, a = 0.9 },
    mod = { r = 0.6, g = 0.64, b = 0.72, a = 0.9 },
}

BardUIWindow.smallFontOptions = { UIFont.Small, UIFont.NewSmall, UIFont.CodeSmall }

function BardUIWindow.getSmallestFont()
    local smallest, smallestHeight
    for _,font in ipairs(BardUIWindow.smallFontOptions) do
        local height = getTextManager():getFontHeight(font)
        if not smallestHeight or height < smallestHeight then
            smallest, smallestHeight = font, height
        end
    end
    return smallest
end


function BardUIWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
end

function BardUIWindow.onTextChange(box)
    if not box then return end
    if box.parent.loadingText then return end
    box.parent:onEditorChanged()
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
    self.playRowBaseX = self.width * 0.6875

    local rowX = self.padding
    self.editorButton = ISButton:new(rowX, buttonY, buttonHeight, buttonHeight, "", self, BardUIWindow.onEditorButton)
    self.editorButton:initialise()
    self.editorButton:instantiate()
    self.editorButton:setImage(getTexture("media/ui/inventoryPanes/Button_Collapse.png"))
    self.editorButton:forceImageSize(16, 16)
    self.editorButton:setTooltip(getText("IGUI_BardToTheBone_ToggleEditor"))
    self:addChild(self.editorButton)

    rowX = rowX + buttonHeight + (self.padding/2)
    local buttonWidth = (self.playRowBaseX - (self.padding/2) - rowX - (self.padding * 1.5)) / 4

    self.saveButton = ISButton:new(rowX, buttonY, buttonWidth, buttonHeight, getText("IGUI_BardToTheBone_Save"), self, BardUIWindow.onSave)
    self.saveButton:initialise()
    self.saveButton:instantiate()
    self:addChild(self.saveButton)

    local buttonOffset = rowX + buttonWidth + (self.padding/2)

    self.revertButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, getText("IGUI_BardToTheBone_Revert"), self, BardUIWindow.onRevertButton)
    self.revertButton:initialise()
    self.revertButton:instantiate()
    self:addChild(self.revertButton)

    buttonOffset = buttonOffset + buttonWidth + (self.padding/2)

    self.newButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, getText("IGUI_BardToTheBone_New"), self, BardUIWindow.onNewButton)
    self.newButton:initialise()
    self.newButton:instantiate()
    self:addChild(self.newButton)

    buttonOffset = buttonOffset + buttonWidth + (self.padding/2)

    self.removeButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, getText("IGUI_BardToTheBone_Remove"), self, BardUIWindow.onRemoveButton)
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

    self.playRowBaseWidth = (self.width*0.225)+(styles and 0 or buttonHeight)
    self.playRowButtonHeight = buttonHeight
    self.buttonOverlap = self.width * 0.0025

    self.voiceButton = ISButton:new(self.playRowBaseX, buttonY, buttonHeight, buttonHeight, "v", self, BardUIWindow.onVoice)
    self.voiceButton:initialise()
    self.voiceButton:instantiate()
    self:addChild(self.voiceButton)
    self.voiceButton:setVisible(false)

    local playWidth = self.playRowBaseWidth

    self.playButton = ISButton:new(self.width * 0.6875 , buttonY, playWidth, buttonHeight, getText("IGUI_BardToTheBone_Play"), self, BardUIWindow.onPlay)
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
    local searchWidth = self.width - (self.padding * 2) - buttonHeight + self.buttonOverlap

    self.searchText = ""
    self.searchEntry = ISTextEntryBox:new("", self.padding, searchY, searchWidth, buttonHeight)
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry.onTextChange = BardUIWindow.onSearchChange
    self.searchEntry:setPlaceholderText(getText("IGUI_FilterSearch"))
    self.searchEntry:setClearButton(true)
    self:addChild(self.searchEntry)

    self.optionsButton = ISButton:new(self.width - self.padding - buttonHeight, searchY, buttonHeight, buttonHeight, "", self, BardUIWindow.onOptionsButton)
    self.optionsButton:initialise()
    self.optionsButton:instantiate()
    self.optionsButton:setImage(getTexture("media/ui/inventoryPanes/Button_Gear.png"))
    self.optionsButton:forceImageSize(16, 16)
    self.optionsButton:setTooltip(getText("IGUI_BardToTheBone_Options"))
    self:addChild(self.optionsButton)

    local resizeOffset = self.resizable and self:resizeWidgetHeight() or 0
    local songListY = searchY + buttonHeight + self.padding
    local songListHeight = self.height - songListY - self:titleBarHeight() - resizeOffset
    self.songList = ISScrollingListBox:new(self.padding, songListY, self.width - (self.padding * 2), songListHeight)
    self.songList:initialise()
    self.songList:instantiate()

    self.songList.font = UIFont.Small
    self.songList.fontHgt = getTextManager():getFontHeight(self.songList.font)
    self.songList.itemPadY = 1
    self.songList.itemheight = self.songList.fontHgt + (self.songList.itemPadY * 2)
    self.songList:setOnMouseDownFunction(self, BardUIWindow.onSongSelected)
    self:addChild(self.songList)

    self.songListBaseY = songListY
    self.songListBaseHeight = songListHeight

    local optionsFont = BardUIWindow.getSmallestFont()
    local hideModLabel = getText("IGUI_BardToTheBone_HideVanillaSongs")
    local hideModWidth = buttonHeight + 10 + getTextManager():MeasureStringX(optionsFont, hideModLabel)
    local reloadLabel = getText("IGUI_BardToTheBone_ReloadSongs")
    local reloadWidth = getTextManager():MeasureStringX(optionsFont, reloadLabel) + (self.padding * 2)

    self.optionsPanel = ISPanel:new(self.padding, songListY, self.width - (self.padding * 2), buttonHeight + self.padding)
    self.optionsPanel:initialise()
    self.optionsPanel:instantiate()
    self:addChild(self.optionsPanel)
    self.optionsPanel:setVisible(false)

    local optionsY = self.padding / 2

    self.hideModTickBox = ISTickBox:new(self.padding / 2, optionsY, hideModWidth, buttonHeight, "", self, BardUIWindow.onHideModSongs)
    self.hideModTickBox:initialise()
    self.hideModTickBox:instantiate()
    self.hideModTickBox:setFont(optionsFont)
    self.optionsPanel:addChild(self.hideModTickBox)
    self.hideModTickBox:addOption(hideModLabel)
    self.hideModTickBox:setSelected(1, settings.get("hideModSongs"))

    self.reloadButton = ISButton:new(self.optionsPanel.width - reloadWidth - (self.padding / 2), optionsY, reloadWidth, buttonHeight, reloadLabel, self, BardUIWindow.onReloadSongs)
    self.reloadButton:initialise()
    self.reloadButton:instantiate()
    self.reloadButton:setFont(optionsFont)
    self.optionsPanel:addChild(self.reloadButton)

    self.localSongs = {}
    self.librarySongs = {}
    self.selectedSong = nil

    self:setInfo(getText("IGUI_BardToTheBone_Info"))

    self:layoutSections()
    self:onLoadAll()
    self:refreshVoiceButton()
    self:refreshPlayButtonState()
end


function BardUIWindow:layoutSections()
    local collapsed = settings.get("editorCollapsed")
    self.abcEntry:setVisible(not collapsed)

    local rowY = collapsed and (self:titleBarHeight() + self.padding) or (self.abcEntry.y + self.abcEntry.height + self.padding)
    for _,button in ipairs({ self.editorButton, self.saveButton, self.revertButton, self.newButton, self.removeButton, self.voiceButton, self.playButton, self.styleButton }) do
        button:setY(rowY)
    end

    self.volumeSlider:setY(rowY + self.playRowButtonHeight + self.padding)

    local searchY = self.volumeSlider.y + self.volumeSlider.height + self.padding
    self.searchEntry:setY(searchY)
    self.optionsButton:setY(searchY)

    local resizeOffset = self.resizable and self:resizeWidgetHeight() or 0
    self.songListBaseY = searchY + self.playRowButtonHeight + self.padding
    self.songListBaseHeight = self.height - self.songListBaseY - self:titleBarHeight() - resizeOffset
    self.optionsPanel:setY(self.songListBaseY)

    local offset = self.optionsPanel:isVisible() and (self.optionsPanel.height + (self.padding / 2)) or 0
    self.songList:setY(self.songListBaseY + offset)
    self.songList:setHeight(self.songListBaseHeight - offset)
end


function BardUIWindow:onEditorButton()
    settings.set("editorCollapsed", not settings.get("editorCollapsed"))
    self:layoutSections()
end


function BardUIWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if BardUIWindow.instance == self then
        BardUIWindow.instance = nil
    end
end


function BardUIWindow:setEditorText(text)
    self.loadingText = true
    self.abcEntry:setText(text)
    self.loadingText = false
end


function BardUIWindow:onEditorChanged()
    local song = self.selectedSong
    if not song or song.source ~= "local" then
        song = self:createLocalCopy(song)
    end
    if not song.fileName then song.content = self.abcEntry:getText() end

    self:setSaveButtonStatus(true)
    self:refreshVoiceButton()
end


function BardUIWindow:createLocalCopy(original)
    local text = self.abcEntry:getText()
    local song = { source = "local", content = text, original = original }
    songLibrary.setTitle(song, songLibrary.getTitle(text, original and original.title))

    table.insert(self.localSongs, song)
    songLibrary.sortSongs(self.localSongs)
    self.selectedSong = song
    self:populateSongList()
    return song
end


function BardUIWindow:onSave()
    local song = self.selectedSong
    if not song or song.source ~= "local" then return end

    local notes = self.abcEntry:getText()
    if (not notes) then return end

    local title = notes:match("T:(.-)\n")
    local index = notes:match("X:(.-)\n")

    if not title then notes = "T:[No Title]\n"..notes end
    if not index then notes = "X:1\n"..notes end

    if not songLibrary.saveSong(song, notes) then return end
    if notes ~= self.abcEntry:getText() then self:setEditorText(notes) end

    songLibrary.sortSongs(self.localSongs)
    self:setSaveButtonStatus(false)
    self:populateSongList()
end


function BardUIWindow:findSong(previous)
    if not previous or not previous.fileName then return end
    for _,songs in ipairs({ self.localSongs, self.librarySongs }) do
        for _,song in ipairs(songs) do
            if song.source == previous.source and song.fileName == previous.fileName then return song end
        end
    end
end


function BardUIWindow:onRevertButton()
    local song = self.selectedSong
    if not song or not self:hasUnsavedChanges() then return end

    if not song.fileName then
        local original = song.original
        self:removeLocalSong(song)
        if original then self:loadSong(original) end
        return
    end

    song.content = songLibrary.readSong({ fileName = song.fileName, source = song.source })
    self:loadSong(song)
end


function BardUIWindow:onLoadAll()
    self:setEditorText("")

    local previous = self.selectedSong
    self.localSongs, self.librarySongs = songLibrary.fetchSongs()
    self.selectedSong = self:findSong(previous) or self.localSongs[1] or self.librarySongs[1]

    self:populateSongList()
    self:loadSong(self.selectedSong)
    self:setSaveButtonStatus(false)
end


function BardUIWindow:isSongVisible(song)
    if song == self.selectedSong then return true end
    if settings.get("hideModSongs") and song.source == "mod" then return false end
    if self.searchText == nil or self.searchText == "" then return true end
    local searchTitle = song.searchTitle or (song.title or ""):lower()
    return searchTitle:find(self.searchText, 1, true) ~= nil
end


function BardUIWindow:populateSongList()
    self.songList:clear()

    for _,song in ipairs(self.localSongs) do
        if self:isSongVisible(song) then self:addSongToList(song) end
    end

    for _,song in ipairs(self.librarySongs) do
        if self:isSongVisible(song) then self:addSongToList(song) end
    end

    self:selectSongInList()
end


function BardUIWindow:addSongToList(song)
    local item = self.songList:addItem(song.title, song)
    local color = BardUIWindow.sourceColors[song.source]
    if color then
        item.textColor = color
        item.selectedTextColor = color
    end
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


function BardUIWindow:onOptionsButton()
    local visible = not self.optionsPanel:isVisible()
    self.optionsPanel:setVisible(visible)

    self:layoutSections()
end


function BardUIWindow:onReloadSongs()
    songLibrary.reload()

    local pending = {}
    for _,song in ipairs(self.localSongs) do
        if not song.fileName then table.insert(pending, song) end
    end

    self.localSongs, self.librarySongs = songLibrary.fetchSongs()
    for _,song in ipairs(pending) do
        table.insert(self.localSongs, song)
    end
    songLibrary.sortSongs(self.localSongs)

    self.selectedSong = self:findSong(self.selectedSong) or self.selectedSong
    self:populateSongList()
    self:refreshEditButtons()
end


function BardUIWindow:onHideModSongs(index, selected)
    settings.set("hideModSongs", selected == true)
    self:populateSongList()
end


function BardUIWindow:onNewButton()
    if settings.get("editorCollapsed") then self:onEditorButton() end

    local song = { source = "local", content = "" }
    songLibrary.setTitle(song, getText("IGUI_BardToTheBone_NewSong"))
    table.insert(self.localSongs, song)

    self.selectedSong = song
    self:populateSongList()
    self:loadSong(song)
end


function BardUIWindow:onRemoveButton()
    local song = self.selectedSong
    if not song or song.source ~= "local" then return end

    if not song.fileName then
        self:removeLocalSong(song)
        return
    end

    local modal = ISModalDialog:new(0, 0, 1, 1, getText("IGUI_BardToTheBone_RemoveConfirm", song.title), true, self, BardUIWindow.onRemoveConfirm, self.character:getPlayerNum(), song)
    modal:initialise()
    modal:addToUIManager()
end


function BardUIWindow:onRemoveConfirm(button, song)
    if not button or button.internal ~= "YES" then return end
    if song.fileName and not songLibrary.blankFile(song.fileName) then return end
    self:removeLocalSong(song)
end


function BardUIWindow:removeLocalSong(song)
    local index = Bard.table_indexof(self.localSongs, song)
    if not index then return end
    table.remove(self.localSongs, index)

    local nextSong = self.localSongs[index] or self.localSongs[index-1]
    self:setEditorText("")
    self.selectedSong = nextSong
    self:populateSongList()
    self:loadSong(nextSong)
    self:setSaveButtonStatus(false)
end


function BardUIWindow:setSaveButtonStatus(set)
    if set ~= nil then self.unsavedChanges = set end
    self:refreshEditButtons()
end


function BardUIWindow:hasUnsavedChanges()
    local song = self.selectedSong
    if not song or song.source ~= "local" then return false end
    return (self.unsavedChanges == true) or (not song.fileName)
end


function BardUIWindow:refreshEditButtons()
    local song = self.selectedSong
    local isLocal = (song ~= nil) and (song.source == "local")
    local unsaved = self:hasUnsavedChanges()

    self.saveButton:setEnable(unsaved)
    self.revertButton:setEnable(unsaved)
    self.removeButton:setEnable(isLocal)

    if unsaved then
        self.saveButton.backgroundColor = { r = 0, g = 0.5, b = 0, a = 0.5 }
    end
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
    self:setEditorText(self:getSongContent(song))
    self.abcEntry:setYScroll(0)
    self:setSaveButtonStatus(false)
    self:refreshVoiceButton()
end


function BardUIWindow:onSongSelected(song)
    self:loadSong(song)
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

    local allOption = self.contextMenu:addOption(getText("IGUI_BardToTheBone_AllVoices"), self, BardUIWindow.setVoice, "All")
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

    self.playButton.title = isPlayingThis and getText("IGUI_BardToTheBone_Stop") or getText("IGUI_BardToTheBone_Play")

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