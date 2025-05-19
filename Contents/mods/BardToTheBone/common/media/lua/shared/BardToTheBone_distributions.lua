require "Items/SuburbsDistributions"

local bardDistributions = {}

bardDistributions.instruments = {

    ["Xylophone"] = {
        chance = 4,
        containers = {
            "CrateRandomJunk",
            "CrateToys",
            "DaycareCounter",
            "DaycareDesk",
            "DaycareShelves",
            "Gifts",
            "GiftStoreToys",
            "GigamartToys",
            "CrateInstruments",
            "BandPracticeInstruments",
            "ClosetInstruments",
            "MusicStoreOthers",
        }
    }

}

function bardDistributions.addToDistributions()
    for instrument,data in pairs(bardDistributions.instruments) do
        for _,contID in pairs(data.containers) do
            table.insert(ProceduralDistributions.list[contID].items, instrument)
            table.insert(ProceduralDistributions.list[contID].items, data.chance)
        end
    end
end

return bardDistributions