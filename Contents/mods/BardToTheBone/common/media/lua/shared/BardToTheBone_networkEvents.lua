if isServer() then
    local handler = require "BardToTheBone_networkHandler"
    local function onClientCommand(_module, _command, _player, _data)
        if _module ~= "BardToTheBone" then return end
        if _command == "update" then handler.receiveUpdate(_data)
        elseif _command == "notes" then handler.relayToNearby(_player, _command, _data)
        elseif _command == "stop" then handler.relayToNearby(_player, _command, _data, true)
        end
    end
    Events.OnClientCommand.Add(onClientCommand)--what the server gets from the client
end