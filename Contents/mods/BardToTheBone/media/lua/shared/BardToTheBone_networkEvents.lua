if isServer() then
    local function onClientCommand(_module, _command, _player, _data)
        if _module ~= "BardToTheBone" then return end
        if _command == "update" then sendServerCommand(_module, _command, _data) end
    end
    Events.OnClientCommand.Add(onClientCommand)--what the server gets from the client
end

if isClient() then
    local handler = require "BardToTheBone_networkHandler"
    local function onServerCommand(_module, _command, _data)
        if _module ~= "BardToTheBone" then return end
        if _command == "update" then handler.receiveUpdate(_data) end
    end
    Events.OnServerCommand.Add(onServerCommand)--what clients gets from the server
end