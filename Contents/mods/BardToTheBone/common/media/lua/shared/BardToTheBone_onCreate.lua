BardToTheBone_OnCreate = {}

BardToTheBone_OnCreate.ocarinaTints = {
    { name = "White", r = 1.00, g = 1.00, b = 1.00 },
    { name = "Clay", r = 0.82, g = 0.48, b = 0.30 },
    { name = "Blue", r = 0.30, g = 0.50, b = 0.92 },
    { name = "Green", r = 0.36, g = 0.68, b = 0.38 },
    { name = "Red", r = 0.86, g = 0.22, b = 0.20 },
    { name = "Black", r = 0.24, g = 0.24, b = 0.25 },
    { name = "Purple", r = 0.58, g = 0.36, b = 0.86 },
    { name = "Pink", r = 0.96, g = 0.56, b = 0.74 },
    { name = "Gold", r = 0.95, g = 0.76, b = 0.30 },
}

function BardToTheBone_OnCreate.applyTint(item)
    local name = item:getModData().BttB_Tint
    if not name then return end
    for _, tint in ipairs(BardToTheBone_OnCreate.ocarinaTints) do
        if tint.name == name then
            item:setColorRed(tint.r)
            item:setColorGreen(tint.g)
            item:setColorBlue(tint.b)
            item:setColor(Color.new(tint.r, tint.g, tint.b, 1))
            item:setCustomColor(true)
            return
        end
    end
end

function BardToTheBone_OnCreate.ocarina(item)
    local tints = BardToTheBone_OnCreate.ocarinaTints
    item:getModData().BttB_Tint = tints[ZombRand(#tints) + 1].name
    BardToTheBone_OnCreate.applyTint(item)
end
