-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.9

-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'
local helpers = require('event_helpers')

local settings = require('dzVents_settings')
-- create a global for the log level

logLevel = settings['Log level']

LOG_INFO = 2
LOG_DEBUG = 3
LOG_ERROR = 1

local Domoticz = require('Domoticz')
local domoticz = Domoticz()

local eventBindings = helpers.getEventBindings(domoticz)

if (eventBindings == nil) then
	return domoticz.commandArray -- end of the line
end

local function findBindingByEvent(event, allBindings)
	-- event could be like: myPIRLivingRoom
	-- or myPir(.*)
	log('findBindingByEvent: '.. event, LOG_DEBUG)

	for trigger, bindings in pairs(allBindings) do
		if (string.find(trigger, '*')) then
			trigger = string.gsub(trigger, "*", ".*")
			if (string.match(event, trigger)) then
				return bindings
			end
		else
			if (trigger == event) then
				return bindings
			end
		end
	end
	return nil
end

if (devicechanged~=nil) then
	for event, value in pairs(devicechanged) do
		log('Event in devicechanged: ' .. event .. ' value: ' .. value, LOG_DEBUG)
		local bindings
		local device = domoticz.getDeviceByEvent(event)

		if (device~=nil) then
			bindings = findBindingByEvent(event, eventBindings)
			if (bindings==nil) then
				bindings = eventBindings[device.id]
			end

			-- bindings = eventBindings[event] or eventBindings[device.id]
		else
			bindings = eventBindings[event]
		end

		if (bindings~=nil) then
			log('Handling events for: "' .. event .. '", value: "' .. value .. '"', LOG_INFO)
			helpers.handleEvents(bindings, domoticz, device)
		end

	end
end

helpers.dumpCommandArray(domoticz.commandArray)

commandArray = domoticz.commandArray
return commandArray