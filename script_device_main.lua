-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.6

-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'

commandArray = {}

local helpers = require('event_helpers')
local eventBindings = helpers.getEventBindings()

if (eventBindings == nil) then
	return commandArray -- end of the line
end

devicechanged['*'] = ''  -- trigger for * events

if (devicechanged~=nil) then
	for event, value in pairs(devicechanged) do
		local idx = helpers.getIndex(event, otherdevices_idx)

		if (eventBindings[event] ~= nil) then
			-- there are event handlers for this device
			print('Handling events for: "' .. event .. '", value: "' .. value .. '"')
			commandArray = helpers.handleEvents(eventBindings[event], value, commandArray, event, idx)
		end

		-- see if there is an indexed eventhandler
		if (eventBindings[idx] ~= nil) then
			print('Handling events for: "' .. event .. '", value: "' .. value .. '", index: ' .. tostring(idx))
			commandArray = helpers.handleEvents(eventBindings[idx], value, commandArray, event, idx)
		end
	end
end

helpers.dumpCommandArray(commandArray)

return commandArray