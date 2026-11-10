require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISPanel"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "ISUI/ISImage"
require "RadioCom/ISUIRadio/ISSliderPanel"

local songLibrary = require "BardToTheBone_songLibrary"
local settings = require "BardToTheBone_settings"
local Bard = require "BardToTheBone_main"
local netWorkHandler = require "BardToTheBone_networkHandler"

BardUIWindow = ISCollapsableWindow:derive("BardUIWindow")

BardUIWindow.sourceColors = {
    abc = { r = 0.6, g = 0.72, b = 0.6, a = 0.9 },
    mod = { r = 0.6, g = 0.64, b = 0.72, a = 0.9 },
}

BardUIWindow.easyColor = { r = 0.35, g = 0.85, b = 0.35 }
BardUIWindow.middleColor = { r = 0.9, g = 0.85, b = 0.3 }
BardUIWindow.hardColor = { r = 0.95, g = 0.3, b = 0.25 }
BardUIWindow.hardGap = 5
BardUIWindow.difficultyAlpha = 0.6
BardUIWindow.difficultyPadding = 3
BardUIWindow.titleGap = 8
BardUIWindow.digitWidths = {}
BardUIWindow.difficultyDigits = {}
for difficulty = 0, 10 do
    local digits = {}
    for digit in tostring(difficulty):gmatch("%d") do table.insert(digits, digit) end
    BardUIWindow.difficultyDigits[difficulty] = digits
end
BardUIWindow.scoreInterval = 15
BardUIWindow.starWidth = 14
BardUIWindow.sortArrowScale = 0.5
BardUIWindow.volumeIconSize = 15
BardUIWindow.progressColor = { r = 0.4, g = 1.0, b = 0.3, a = 0.2 }
BardUIWindow.volumeIconAlpha = 0.8
BardUIWindow.volumeIconFadedAlpha = 0.35
BardUIWindow.volumeTextAlpha = 0.8
BardUIWindow.guideURL = "https://steamcommunity.com/linkfilter/?u=https://github.com/Chuckleberry-Finn/Bard-To-The-Bone"
BardUIWindow.starAlphaOff = 0.3
BardUIWindow.ampInterval = 60
BardUIWindow.missingAmpColor = { r = 0.85, g = 0.25, b = 0.2, a = 1 }
BardUIWindow.styleTextColor = { r = 1, g = 1, b = 1, a = 1 }
BardUIWindow.scoreCache = {}

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
    local editorFont = BardUIWindow.getSmallestFont()
    local editorText = "abc"
    local editorWidth = getTextManager():MeasureStringX(editorFont, editorText) + 4
    self.editorButton = ISButton:new(rowX, buttonY, editorWidth, buttonHeight, editorText, self, BardUIWindow.onEditorButton)
    self.editorButton:initialise()
    self.editorButton:instantiate()
    self.editorButton:setFont(editorFont)
    self.editorButton:setWidth(editorWidth)
    self.editorButton:setTooltip(getText("IGUI_BardToTheBone_ToggleEditor"))
    self:addChild(self.editorButton)

    rowX = self.editorButton.x + self.editorButton.width + (self.padding/2)
    local buttonWidth = (self.playRowBaseX - (self.padding/2) - rowX - (self.padding * 1.5)) / 4

    self.saveButton = ISButton:new(rowX, buttonY, buttonWidth, buttonHeight, getText("IGUI_BardToTheBone_Save"), self, BardUIWindow.onSave)
    self.saveButton:initialise()
    self.saveButton:instantiate()
    self:addChild(self.saveButton)

    local buttonOffset = self.saveButton.x + self.saveButton.width + (self.padding/2)

    self.revertButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, getText("IGUI_BardToTheBone_Revert"), self, BardUIWindow.onRevertButton)
    self.revertButton:initialise()
    self.revertButton:instantiate()
    self:addChild(self.revertButton)

    buttonOffset = self.revertButton.x + self.revertButton.width + (self.padding/2)

    self.newButton = ISButton:new(buttonOffset, buttonY, buttonWidth, buttonHeight, getText("IGUI_BardToTheBone_New"), self, BardUIWindow.onNewButton)
    self.newButton:initialise()
    self.newButton:instantiate()
    self:addChild(self.newButton)

    buttonOffset = self.newButton.x + self.newButton.width + (self.padding/2)

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

    self.editorRowEndX = self.removeButton.x + self.removeButton.width + (self.padding/2)
    self.playRowMaxWidth = (self.width * 0.225) + buttonHeight
    self.playRowBaseWidth = math.min(self.width - self.padding - self.editorRowEndX, self.playRowMaxWidth)
    self.playRowBaseX = self.width - self.padding - self.playRowBaseWidth
    self.playRowButtonHeight = buttonHeight
    self.buttonOverlap = 1
    self.borderOverlap = 2

    self.voiceButton = ISButton:new(self.playRowBaseX, buttonY, buttonHeight, buttonHeight, "v", self, BardUIWindow.onVoice)
    self.voiceButton:initialise()
    self.voiceButton:instantiate()
    self.voiceButton:setTooltip(getText("IGUI_BardToTheBone_VoiceTooltip"))
    self:addChild(self.voiceButton)
    self.voiceButton:setVisible(false)

    local playWidth = self.playRowBaseWidth

    self.playButton = ISButton:new(self.playRowBaseX, buttonY, playWidth, buttonHeight, getText("IGUI_BardToTheBone_Play"), self, BardUIWindow.onPlay)
    self.playButton:initialise()
    self.playButton:instantiate()
    self:addChild(self.playButton)

    self.playButtonDefaultColor = { r = self.playButton.backgroundColor.r, g = self.playButton.backgroundColor.g,
                                     b = self.playButton.backgroundColor.b, a = self.playButton.backgroundColor.a }
    self.playButtonDefaultColorMouseOver = { r = self.playButton.backgroundColorMouseOver.r, g = self.playButton.backgroundColorMouseOver.g,
                                              b = self.playButton.backgroundColorMouseOver.b, a = self.playButton.backgroundColorMouseOver.a }
    self.playButtonStopColor = { r = 0.45, g = 0.05, b = 0.05, a = 1 }
    self.playButtonStopColorMouseOver = { r = 0.6, g = 0.08, b = 0.08, a = 1 }

    self.voices = {}
    self.voice = nil -- nil/"All" => play every voice (matches old, pre-voice-picker behavior)

    local volumeRowY = self.playButton.y + self.saveButton.height + self.padding
    self.volumeRowY = volumeRowY

    local iconWidth = math.max(BardUIWindow.volumeIconSize, getTextManager():MeasureStringX(UIFont.Small, "100%"))
    self.volumeIcon = ISImage:new(self.padding, volumeRowY, iconWidth, buttonHeight, getTexture("Icon_Radio_Speaker"))
    self.volumeIcon:initialise()
    self.volumeIcon:instantiate()
    self.volumeIcon.window = self
    self.volumeIcon.prerender = BardUIWindow.renderVolumeIcon
    self:addChild(self.volumeIcon)

    self.volumeSlider = ISSliderPanel:new(self.padding, volumeRowY, self.width - (self.padding * 2), buttonHeight/2, self, BardUIWindow.setVolume)
    self.volumeSlider:initialise()
    self.volumeSlider:instantiate()
    self.volumeSlider.doToolTip = false
    self:addChild(self.volumeSlider)

    self.styleButton = ISButton:new(self.padding, volumeRowY, buttonHeight, buttonHeight, "", self, BardUIWindow.onStyle)
    self.styleButton:initialise()
    self.styleButton:instantiate()
    self.styleButton:setTooltip(getText("IGUI_BardToTheBone_StyleTooltip"))
    self:addChild(self.styleButton)

    self:layoutVolumeRow()
    self.volumeSlider:setCurrentValue(self.volume)

    local searchY = volumeRowY + buttonHeight + self.padding
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
    self.songList.doDrawItem = BardUIWindow.drawSongItem
    self.songList.onMouseDown = BardUIWindow.onSongListMouseDown
    self.starSetTexture = getTexture("media/ui/inventoryPanes/FavouriteYes.png")
    self.starUnsetTexture = getTexture("media/ui/inventoryPanes/FavouriteNo.png")
    self:addChild(self.songList)

    self.headerHeight = self.songList.itemheight + 2
    self.sortUpTexture = getTexture("media/ui/ArrowUp.png")
    self.sortDownTexture = getTexture("media/ui/ArrowDown.png")
    self.titleHeader = self:createSongHeader("title", getText("IGUI_BardToTheBone_ColumnSong"), getText("IGUI_BardToTheBone_ColumnSong_tooltip"))
    self.levelHeader = self:createSongHeader("level", getText("IGUI_BardToTheBone_ColumnLevel"), getText("IGUI_BardToTheBone_ColumnLevel_tooltip"))

    self.songListBaseY = songListY
    self.songListBaseHeight = songListHeight

    local optionsFont = BardUIWindow.getSmallestFont()
    local hideModLabel = getText("IGUI_BardToTheBone_HideVanillaSongs")
    local hideModWidth = buttonHeight + 10 + getTextManager():MeasureStringX(optionsFont, hideModLabel)
    local reloadLabel = getText("IGUI_BardToTheBone_ReloadSongs")
    local reloadWidth = getTextManager():MeasureStringX(optionsFont, reloadLabel) + (self.padding * 2)

    self.optionsPanel = ISPanel:new(self.padding, songListY, self.width - (self.padding * 2), (buttonHeight * 2) + self.padding)
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

    local favouritesLabel = getText("IGUI_BardToTheBone_FavouritesOnly")
    local favouritesWidth = buttonHeight + 10 + getTextManager():MeasureStringX(optionsFont, favouritesLabel)
    self.favouritesTickBox = ISTickBox:new(self.padding / 2, optionsY + buttonHeight, favouritesWidth, buttonHeight, "", self, BardUIWindow.onFavouritesOnly)
    self.favouritesTickBox:initialise()
    self.favouritesTickBox:instantiate()
    self.favouritesTickBox:setFont(optionsFont)
    self.optionsPanel:addChild(self.favouritesTickBox)
    self.favouritesTickBox:addOption(favouritesLabel)
    self.favouritesTickBox:setSelected(1, settings.get("favouritesOnly"))

    self.reloadButton = ISButton:new(self.optionsPanel.width - reloadWidth - (self.padding / 2), optionsY, reloadWidth, buttonHeight, reloadLabel, self, BardUIWindow.onReloadSongs)
    self.reloadButton:initialise()
    self.reloadButton:instantiate()
    self.reloadButton:setFont(optionsFont)
    self.optionsPanel:addChild(self.reloadButton)

    local guideLabel = getText("IGUI_BardToTheBone_SongGuide")
    local guideWidth = getTextManager():MeasureStringX(optionsFont, guideLabel) + (self.padding * 2)
    local optionButtonWidth = math.max(reloadWidth, guideWidth)
    self.guideButton = ISButton:new(self.optionsPanel.width - optionButtonWidth - (self.padding / 2), optionsY + buttonHeight, optionButtonWidth, buttonHeight, guideLabel, self, BardUIWindow.onGuideButton)
    self.guideButton:initialise()
    self.guideButton:instantiate()
    self.guideButton:setFont(optionsFont)
    self.guideButton:setTooltip(getText("IGUI_BardToTheBone_SongGuide_tooltip"))
    self.optionsPanel:addChild(self.guideButton)
    self.reloadButton:setWidth(optionButtonWidth)
    self.reloadButton:setX(self.optionsPanel.width - optionButtonWidth - (self.padding / 2))

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
    for _,button in ipairs({ self.editorButton, self.saveButton, self.revertButton, self.newButton, self.removeButton, self.voiceButton, self.playButton }) do
        button:setY(rowY)
    end
    for _,button in ipairs({ self.saveButton, self.revertButton, self.newButton, self.removeButton }) do
        button:setVisible(not collapsed)
    end

    local rowStart = collapsed and (self.editorButton.x + self.editorButton.width + (self.padding/2)) or self.editorRowEndX
    local rowEnd = self.width - self.padding
    self.playRowBaseWidth = math.min(rowEnd - rowStart, self.playRowMaxWidth)
    self.playRowBaseX = rowEnd - self.playRowBaseWidth

    self.volumeRowY = rowY + self.playRowButtonHeight + self.padding
    self:layoutPlayRow()

    local searchY = self.volumeRowY + self.playRowButtonHeight + self.padding
    self.searchEntry:setY(searchY)
    self.optionsButton:setY(searchY)

    local resizeOffset = self.resizable and self:resizeWidgetHeight() or 0
    self.songListBaseY = searchY + self.playRowButtonHeight + self.padding
    self.songListBaseHeight = self.height - self.songListBaseY - self:titleBarHeight() - resizeOffset
    self.optionsPanel:setY(self.songListBaseY)

    local offset = self.optionsPanel:isVisible() and (self.optionsPanel.height + (self.padding / 2)) or 0
    self:layoutSongHeader(self.songListBaseY + offset)
    self.songList:setY(self.songListBaseY + offset + self.headerHeight)
    self.songList:setHeight(self.songListBaseHeight - offset - self.headerHeight)
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
    local song = { source = "local", content = text, original = original, difficulty = original and original.difficulty }
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
    song.difficulty = nil
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
    song.difficulty = nil
    self:loadSong(song)
end


function BardUIWindow:onLoadAll()
    self:setEditorText("")

    local previous = self.selectedSong
    self.localSongs, self.librarySongs = songLibrary.fetchSongs()
    self:applyCachedScores()
    self.selectedSong = self:findSong(previous) or self.localSongs[1] or self.librarySongs[1]

    self:populateSongList()
    self:loadSong(self.selectedSong)
    self:setSaveButtonStatus(false)
end


function BardUIWindow:isSongVisible(song)
    if song == self.selectedSong then return true end
    if settings.get("hideModSongs") and song.source == "mod" then return false end
    if settings.get("favouritesOnly") and not songLibrary.isFavourite(song) then return false end
    if self.searchText == nil or self.searchText == "" then return true end
    local searchTitle = song.searchTitle or (song.title or ""):lower()
    return searchTitle:find(self.searchText, 1, true) ~= nil
end


function BardUIWindow:populateSongList(keepScroll)
    self.songList:clear()

    local sortBy = self:getSongSort()
    for _,favourites in ipairs({ true, false }) do
        local group = {}
        for _,songs in ipairs({ self.localSongs, self.librarySongs }) do
            for _,song in ipairs(songs) do
                if (songLibrary.isFavourite(song) == favourites) and self:isSongVisible(song) then table.insert(group, song) end
            end
        end
        if sortBy ~= "" then self:sortSongs(group, sortBy, settings.get("songSortDescending")) end
        for _,song in ipairs(group) do self:addSongToList(song) end
    end

    self:selectSongInList(keepScroll)
end


function BardUIWindow:getSongSort()
    local sortBy = settings.get("songSort") or ""
    if sortBy == "level" and not self.skillsEnabled then return "" end
    return sortBy
end


function BardUIWindow:sortSongs(songs, sortBy, descending)
    if sortBy == "title" then
        songLibrary.mergeSort(songs, function(a, b)
            if descending then return a.searchTitle > b.searchTitle end
            return a.searchTitle < b.searchTitle
        end)
        return
    end

    local levels = {}
    for _,song in ipairs(songs) do levels[song] = self:getSongDifficulty(song) end
    songLibrary.mergeSort(songs, function(a, b)
        local levelA, levelB = levels[a], levels[b]
        if levelA ~= levelB then
            if not levelA then return false end
            if not levelB then return true end
            if descending then return levelA > levelB end
            return levelA < levelB
        end
        return a.searchTitle < b.searchTitle
    end)
end


function BardUIWindow:createSongHeader(column, label, tooltip)
    local header = ISButton:new(self.padding, 0, 10, self.headerHeight, "", self, BardUIWindow.onSongHeader)
    header:initialise()
    header:instantiate()
    header.window = self
    header.column = column
    header.label = label
    header.internal = column
    header.render = BardUIWindow.renderSongHeader
    header:setTooltip(tooltip)
    self:addChild(header)
    return header
end


function BardUIWindow:layoutSongHeader(y)
    local listWidth = self.songList.width
    local digitWidth = BardUIWindow.getDigitWidth(self.songList.font)
    local levelWidth = getTextManager():MeasureStringX(UIFont.Small, self.levelHeader.label) + (digitWidth * 2) + BardUIWindow.difficultyPadding + 16

    self.levelHeader:setVisible(self.skillsEnabled == true)
    local titleWidth = self.skillsEnabled and (listWidth - levelWidth) or listWidth

    self.titleHeader:setX(self.padding)
    self.titleHeader:setY(y)
    self.titleHeader:setWidth(self.skillsEnabled and (titleWidth + self.borderOverlap) or titleWidth)
    self.levelHeader:setX(self.padding + titleWidth)
    self.levelHeader:setY(y)
    self.levelHeader:setWidth(levelWidth)
end


function BardUIWindow.renderSongHeader(button)
    local window = button.window
    local active = window:getSongSort() == button.column
    local textY = (button.height - getTextManager():getFontHeight(UIFont.Small)) / 2
    local alpha = (button.column == "level") and BardUIWindow.difficultyAlpha or 0.8
    local arrow = active and (settings.get("songSortDescending") and window.sortDownTexture or window.sortUpTexture)
    local arrowSize = math.min(10, button.height - 4) * BardUIWindow.sortArrowScale

    if button.column == "title" then
        button:drawText(button.label, 15, textY, 1, 1, 1, alpha, UIFont.Small)
        if arrow then
            local x = 15 + getTextManager():MeasureStringX(UIFont.Small, button.label) + 4
            button:drawTextureScaled(arrow, x, (button.height - arrowSize) / 2, arrowSize, arrowSize, alpha, 1, 1, 1)
        end
        return
    end

    local list = window.songList
    local scrollWidth = (list.vscroll and list.vscroll:isVisible()) and list.vscroll:getWidth() or 0
    local right = button.width - scrollWidth - BardUIWindow.difficultyPadding
    button:drawTextRight(button.label, right, textY, 1, 1, 1, alpha, UIFont.Small)
    if arrow then
        local x = right - getTextManager():MeasureStringX(UIFont.Small, button.label) - arrowSize - 4
        button:drawTextureScaled(arrow, x, (button.height - arrowSize) / 2, arrowSize, arrowSize, alpha, 1, 1, 1)
    end
end


function BardUIWindow:onSongHeader(button)
    local column = button.internal
    local current = self:getSongSort()
    if current ~= column then
        settings.set("songSort", column)
        settings.set("songSortDescending", false)
    elseif not settings.get("songSortDescending") then
        settings.set("songSortDescending", true)
    else
        settings.set("songSort", "")
        settings.set("songSortDescending", false)
    end
    self:populateSongList()
    local first = self.songList.items[1]
    if first then self:loadSong(first.item) end
    self.songList:setYScroll(0)
end


function BardUIWindow:addSongToList(song)
    local item = self.songList:addItem(song.title, song)
    local color = BardUIWindow.sourceColors[song.source]
    if color then
        item.textColor = color
        item.selectedTextColor = color
    end
end


function BardUIWindow:getSongDifficulty(song)
    if not self.skillsEnabled then return end
    local difficulty = song and song.difficulty
    if not difficulty then return end
    if self.isPercussion then return difficulty.percussion end
    return difficulty.melodic
end


function BardUIWindow.getDifficultyColor(gap)
    local t = math.max(0, math.min(1, gap / BardUIWindow.hardGap)) * 2
    local from, to = BardUIWindow.easyColor, BardUIWindow.middleColor
    if t > 1 then
        from, to = BardUIWindow.middleColor, BardUIWindow.hardColor
        t = t - 1
    end
    return from.r + (to.r - from.r) * t, from.g + (to.g - from.g) * t, from.b + (to.b - from.b) * t
end


function BardUIWindow.getDigitWidth(font)
    local width = BardUIWindow.digitWidths[font]
    if width then return width end
    width = 0
    for digit = 0, 9 do
        width = math.max(width, getTextManager():MeasureStringX(font, tostring(digit)))
    end
    BardUIWindow.digitWidths[font] = width
    return width
end


function BardUIWindow.fitText(font, text, width)
    local textManager = getTextManager()
    if textManager:MeasureStringX(font, text) <= width then return text end

    local low, high = 0, #text
    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        if textManager:MeasureStringX(font, text:sub(1, mid) .. "...") <= width then low = mid else high = mid - 1 end
    end
    while low > 0 and (text:byte(low + 1) or 0) >= 128 and (text:byte(low + 1) or 0) < 192 do low = low - 1 end

    local trimmed = text:sub(1, low):gsub("%s+$", "")
    return trimmed .. "..."
end


function BardUIWindow:getSongProgress(song)
    local bard = Bard.players[self.character:getUsername()]
    local playing = bard and bard.song
    if not playing then return end
    if playing ~= song then
        local key = songLibrary.getFavouriteKey(playing)
        if not key or key ~= songLibrary.getFavouriteKey(song) then return end
    end
    local action = bard.action
    if not action or not action.action then return end
    local delta = action:getJobDelta()
    if delta and delta > 0 then return math.min(1, delta) end
end


function BardUIWindow.drawSongItem(list, y, item, alt)
    if (y + list:getYScroll() + list.itemheight < 0) or (y + list:getYScroll() >= list.height) then
        return ISScrollingListBox.doDrawItem(list, y, item, alt)
    end

    local scrollWidth = (list.vscroll and list.vscroll:isVisible()) and list.vscroll:getWidth() or 0
    local right = list:getWidth() - scrollWidth - BardUIWindow.difficultyPadding
    local digitWidth = BardUIWindow.getDigitWidth(list.font)
    local available = right - (digitWidth * 2) - BardUIWindow.titleGap - 15

    if item.fittedWidth ~= available then
        item.fittedWidth = available
        item.fittedText = BardUIWindow.fitText(list.font, item.text, available)
    end

    local fullText = item.text
    local rowHeight = item.height
    item.text = item.fittedText
    item.height = rowHeight + 1
    ISScrollingListBox.doDrawItem(list, y, item, alt)
    item.height = rowHeight
    item.text = fullText
    local nextY = y + rowHeight

    local progress = list.parent and list.parent.getSongProgress and list.parent:getSongProgress(item.item)
    if progress then
        local c = BardUIWindow.progressColor
        list:drawRect(0, y, (list:getWidth() - scrollWidth) * progress, rowHeight, c.a, c.r, c.g, c.b)
    end

    local window = list.parent
    if window and songLibrary.getFavouriteKey(item.item) then
        local favourite = songLibrary.isFavourite(item.item)
        local texture = favourite and window.starSetTexture or window.starUnsetTexture
        if texture then
            local size = math.min(12, item.height - 2)
            list:drawTextureScaled(texture, 1, y + ((item.height - size) / 2), size, size, favourite and 1 or BardUIWindow.starAlphaOff, 1, 1, 1)
        end
    end
    local difficulty = window and window:getSongDifficulty(item.item)
    if not difficulty then return nextY end

    local r, g, b = BardUIWindow.getDifficultyColor(difficulty - (window.musicLevel or 0))
    local itemPadY = list.itemPadY or (item.height - list.fontHgt) / 2
    local digits = BardUIWindow.difficultyDigits[difficulty]
    local cellLeft = right - (digitWidth * #digits)
    for i, digit in ipairs(digits) do
        list:drawTextCentre(digit, cellLeft + (digitWidth * (i - 0.5)), y + itemPadY, r, g, b, BardUIWindow.difficultyAlpha, list.font)
    end
    return nextY
end


function BardUIWindow:applyCachedScores()
    for _,songs in ipairs({ self.localSongs, self.librarySongs }) do
        for _,song in ipairs(songs) do
            if (not song.difficulty) and song.content then
                song.difficulty = BardUIWindow.scoreCache[song.content]
            end
        end
    end
end


function BardUIWindow:refreshAmpStatus()
    self.ampTick = (self.ampTick or 0) + 1
    if self.ampTick < BardUIWindow.ampInterval then return end
    self.ampTick = 0

    local data = Bard.getInstrumentData(self.instrument)
    local needsAmp = data and data.ampStyles and self.style and data.ampStyles[self.style]
    local missing = needsAmp and not Bard.findPoweredAmp(self.character)
    local color = missing and BardUIWindow.missingAmpColor or BardUIWindow.styleTextColor
    local text = self.styleButton.textColor
    text.r, text.g, text.b, text.a = color.r, color.g, color.b, color.a
end


function BardUIWindow:scoreNextSong()
    self.scoreTick = (self.scoreTick or 0) + 1
    if self.scoreTick < BardUIWindow.scoreInterval then return end
    self.scoreTick = 0

    self.skillsEnabled = netWorkHandler.skillsEnabled()
    if not self.skillsEnabled then return end
    self.musicLevel = Bard.getMusicLevel(self.character, self.family)
    if Bard.players[self.character:getUsername()] then return end

    for _,songs in ipairs({ self.localSongs, self.librarySongs }) do
        for _,song in ipairs(songs) do
            if not song.difficulty then
                local content = songLibrary.readSong(song)
                local cached = BardUIWindow.scoreCache[content]
                if cached then
                    song.difficulty = cached
                else
                    song.difficulty = Bard.scoreSong(content)
                    BardUIWindow.scoreCache[content] = song.difficulty
                    return
                end
            end
        end
    end
end


function BardUIWindow:selectSongInList(keepScroll)
    self.songList.selected = 0
    if not self.selectedSong then return end

    for i,item in ipairs(self.songList.items) do
        if item.item == self.selectedSong then
            self.songList.selected = i
            if not keepScroll then self.songList:ensureVisible(i) end
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
    self:applyCachedScores()
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


function BardUIWindow:onGuideButton()
    if isSteamOverlayEnabled() then
        activateSteamOverlayToWebPage(BardUIWindow.guideURL)
    else
        openUrl(BardUIWindow.guideURL)
    end
end


function BardUIWindow:onFavouritesOnly(index, selected)
    settings.set("favouritesOnly", selected == true)
    self:populateSongList()
end


function BardUIWindow:toggleFavourite(song)
    if not songLibrary.getFavouriteKey(song) then return false end
    songLibrary.setFavourite(song, not songLibrary.isFavourite(song))
    local scroll = self.songList:getYScroll()
    self:populateSongList(true)
    self.songList:setYScroll(scroll)
    return true
end


function BardUIWindow.onSongListMouseDown(list, x, y)
    if x < BardUIWindow.starWidth then
        local row = list:rowAt(x, y)
        local item = list.items[row]
        local window = list.parent
        if item and window and window:toggleFavourite(item.item) then return true end
    end
    return ISScrollingListBox.onMouseDown(list, x, y)
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
    songLibrary.setFavourite(song, false)
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

    local action = BardToTheBonePlayMusic:new(self.character, self.instrument, notes, self.style, self.volume, self.voice)
    if action then action.song = self.selectedSong end
    ISTimedActionQueue.add(action)
    self:refreshPlayButtonState()
end


function BardUIWindow:setVolume(volume)
    self.volume = volume
    settings.set("instrumentVolume", math.floor(volume + 0.5))

    local id = self.character:getUsername()
    if Bard.players[id] then Bard.players[id].volume = volume end
end

function BardUIWindow.renderVolumeIcon(icon)
    local size = BardUIWindow.volumeIconSize
    local slider = icon.window.volumeSlider
    local showValue = slider and (slider.dragInside or slider:isMouseOver())
    local alpha = showValue and BardUIWindow.volumeIconFadedAlpha or BardUIWindow.volumeIconAlpha
    icon:drawTextureScaled(icon.texture, (icon.width - size) / 2, (icon.height - size) / 2, size, size, alpha, 1, 1, 1)
    if not showValue then return end
    local text = tostring(math.floor((icon.window.volume or 0) + 0.5)) .. "%"
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    icon:drawTextCentre(text, icon.width / 2, (icon.height - fontHeight) / 2, 1, 1, 1, BardUIWindow.volumeTextAlpha, UIFont.Small)
end


function BardUIWindow:layoutVolumeRow()
    local rowY = self.volumeRowY
    local height = self.playRowButtonHeight
    local gap = self.padding
    local textManager = getTextManager()

    self.volumeIcon:setX(self.padding)
    self.volumeIcon:setY(rowY)

    local styleWidth = 0
    if self.styles then
        for _,style in ipairs(self.styles) do
            styleWidth = math.max(styleWidth, textManager:MeasureStringX(self.styleButton.font or UIFont.Small, style))
        end
        styleWidth = styleWidth + (gap * 2)
        self.styleButton:setWidth(styleWidth)
        self.styleButton:setX(self.width - self.padding - styleWidth)
        self.styleButton:setY(rowY)
        self.styleButton.title = self.style or ""
    end
    self.styleButton:setVisible(self.styles ~= nil)

    local sliderX = self.volumeIcon.x + self.volumeIcon.width + (gap / 2)
    local sliderRight = self.styles and (self.width - self.padding - styleWidth - gap) or (self.width - self.padding)
    self.volumeSlider:setX(sliderX)
    self.volumeSlider:setWidth(sliderRight - sliderX)
    self.volumeSlider:setY(rowY + ((height - self.volumeSlider.height) / 2))
end


function BardUIWindow:setStyle(style)
    self.style = style
    self.styleButton.title = style or ""
    self.ampTick = BardUIWindow.ampInterval

    local id = self.character:getUsername()
    if Bard.players[id] then Bard.players[id].style = style end
end


function BardUIWindow:onStyle()
    local playerNum = self.character:getPlayerNum()
    self.contextMenu = ISContextMenu.get(playerNum,self:getX()+self.styleButton:getX()+self.styleButton:getWidth(), self:getY()+self.styleButton:getY())
    self.contextMenu.player = playerNum
    local data = Bard.getInstrumentData(self.instrument)
    local amplified = data and data.needsAmp and Bard.findPoweredAmp(self.character)
    for _,style in pairs(self.styles) do
        ---@type ISContextMenu
        local option = self.contextMenu:addOption(style, self, BardUIWindow.setStyle, style)
        local needsAmp = data and data.ampStyles and data.ampStyles[style] and not amplified
        if needsAmp then
            option.notAvailable = true
        elseif style == self.style then
            option.isDisabled = true
        end
        if needsAmp then
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("IGUI_BardToTheBone_NeedsAmp")
            option.toolTip = tooltip
        end
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
    local hasVoices = #self.voices > 1

    local baseWidth = self.playRowBaseWidth
    local voiceOffset = hasVoices and (self.playRowButtonHeight - self.borderOverlap) or 0

    self.voiceButton:setVisible(hasVoices)
    self.voiceButton:setX(self.playRowBaseX)

    self.playButton:setX(self.playRowBaseX + voiceOffset)
    self.playButton:setWidth(baseWidth - voiceOffset)

    if self.volumeRowY then self:layoutVolumeRow() end
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
    self:scoreNextSong()
    if self.styles then self:refreshAmpStatus() end
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
    self.isPercussion = data and data.isPercussion
    self.family = data and data.family
    self.musicLevel = Bard.getMusicLevel(character, self.family)
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

    o.volume = settings.get("instrumentVolume")

    local data = Bard.getInstrumentData(instrument)
    o.isPercussion = data and data.isPercussion
    o.family = data and data.family
    o.musicLevel = Bard.getMusicLevel(character, o.family)
    o.skillsEnabled = netWorkHandler.skillsEnabled()
    Bard.requestClock(character, true)
    if data and data.styles then
        o.styles = data.styles
        o.style = data.styles[1]
    end

    BardUIWindow.instance = o

    return o
end