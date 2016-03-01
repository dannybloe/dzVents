-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.7

-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'
local helpers = require('event_helpers')

local Domoticz = require('Domoticz')
local domoticz = Domoticz()

--local domoticz = helpers.getData()
local eventBindings = helpers.getEventBindings(domoticz)

if (eventBindings == nil) then
	return domoticz.commandArray -- end of the line
end

devicechanged['*'] = ''  -- trigger for * events

if (devicechanged~=nil) then
	for event, value in pairs(devicechanged) do
		--print('event ' .. event)
		local bindings
		local device = domoticz.getDeviceByEvent(event)

		if (device~=nil) then
			bindings = eventBindings[event] or eventBindings[device.id]
		else
			bindings = eventBindings[event]
		end

		if (bindings~=nil) then
			print('Handling events for: "' .. event .. '", value: "' .. value .. '"')
			helpers.handleEvents(bindings, domoticz, device)
		end

	end
end

helpers.dumpCommandArray(domoticz.commandArray)

commandArray = domoticz.commandArray
return commandArray