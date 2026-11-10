local modOptions = {}

modOptions.id = "BardToTheBone"


function modOptions.create()
    if not PZAPI or not PZAPI.ModOptions then return end
    local options = PZAPI.ModOptions:create(modOptions.id, getText("IGUI_BardToTheBone_ModOptions"))
    modOptions.mute = options:addTickBox("muteInstruments", getText("IGUI_BardToTheBone_MuteInstruments"), false, getText("IGUI_BardToTheBone_MuteInstruments_tooltip"))
    PZAPI.ModOptions:load()
end


function modOptions.isMuted()
    local option = modOptions.mute
    return option ~= nil and option:getValue() == true
end


Events.OnGameBoot.Add(modOptions.create)

return modOptions
