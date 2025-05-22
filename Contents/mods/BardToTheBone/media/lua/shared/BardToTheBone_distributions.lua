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
            if ProceduralDistributions.list[contID] then
                table.insert(ProceduralDistributions.list[contID].items, instrument)
                table.insert(ProceduralDistributions.list[contID].items, data.chance)
            end
        end
    end
end

return bardDistributions