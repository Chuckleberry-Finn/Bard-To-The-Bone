require "XpSystem/ISUI/ISCharacterInfo"

local netWorkHandler = require "BardToTheBone_networkHandler"

local skillPanel = {}

skillPanel.originalLoadPerk = ISCharacterInfo.loadPerk

function ISCharacterInfo.loadPerk(self)
    local perks = skillPanel.originalLoadPerk(self)
    if Perks.BardPerformance and not netWorkHandler.skillsEnabled() then perks[Perks.BardPerformance] = nil end
    return perks
end

return skillPanel
