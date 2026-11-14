require "Items/SuburbsDistributions"

local bardDistributions = {}

bardDistributions.instruments = {

    ["Lute"] = {
        chance = 2,
        containers = {
            "CrateInstruments",
            "BandPracticeInstruments",
            "ClosetInstruments",
            "MusicStoreOthers",
        }
    },

    ["Harp"] = {
        chance = 1,
        containers = {
            "CrateInstruments",
            "BandPracticeInstruments",
            "MusicStoreOthers",
        }
    },

    ["Clarinet"] = {
        chance = 2,
        containers = {
            "CrateInstruments",
            "BandPracticeInstruments",
            "ClosetInstruments",
            "MusicStoreOthers",
        }
    },

    ["SnareDrum"] = {
        chance = 2,
        containers = {
            "CrateInstruments",
            "BandPracticeInstruments",
            "ClosetInstruments",
            "MusicStoreOthers",
        }
    },

    ["Bongos"] = {
        chance = 2,
        containers = {
            "CrateInstruments",
            "BandPracticeInstruments",
            "ClosetInstruments",
            "MusicStoreOthers",
        }
    },

    ["FrenchHorn"] = {
        chance = 2,
        containers = {
            "CrateInstruments",
            "BandPracticeInstruments",
            "ClosetInstruments",
            "MusicStoreOthers",
        }
    },

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
            if ProceduralDistributions.list[contID] then
                table.insert(ProceduralDistributions.list[contID].items, instrument)
                table.insert(ProceduralDistributions.list[contID].items, data.chance)
            end
        end
    end
end

return bardDistributions