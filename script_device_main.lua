-- Version 0.9.10

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

local allEventScripts = helpers.getEventBindings(domoticz)

if (allEventScripts == nil) then
	return domoticz.commandArray -- end of the line
end

local function findScriptsForChangedDevice(changedDeviceName, allEventScripts)
	-- event could be like: myPIRLivingRoom
	-- or myPir(.*)
	log('Searching for scripts for changed device: '.. changedDeviceName, LOG_DEBUG)

	for scriptTrigger, scripts in pairs(allEventScripts) do
		if (string.find(scriptTrigger, '*')) then -- a wild-card was use
			-- turn it into a valid regexp
			scriptTrigger = string.gsub(scriptTrigger, "*", ".*")

			if (string.match(changedDeviceName, scriptTrigger)) then
				-- there is trigger for this changedDeviceName
				return scripts
			end
		else
			if (scriptTrigger == changedDeviceName) then
				-- there is trigger for this changedDeviceName
				return scripts
			end
		end
	end
	return nil
end

-- Note that if there is a wild-card trigger that matches the name of every device name in devicechanged
-- it will call that script for every changed device!!

if (devicechanged~=nil) then
	for changedDeviceName, changedDeviceValue in pairs(devicechanged) do
		log('Event in devicechanged: ' .. changedDeviceName .. ' value: ' .. changedDeviceValue, LOG_DEBUG)
		local scriptsToExecute

		-- find the device for this name
		-- could be MySensor or MySensor_Temperature
		-- the device returned would be MySensor in that case
		local device = domoticz.getDeviceByEvent(changedDeviceName)

		if (device~=nil) then
			-- first search by name
			scriptsToExecute = findScriptsForChangedDevice(changedDeviceName, allEventScripts)

			if (scriptsToExecute ==nil) then
				-- search by id
				scriptsToExecute = allEventScripts[device.id]
			end

			if (scriptsToExecute ~=nil) then
				log('Handling events for: "' .. changedDeviceName .. '", value: "' .. changedDeviceValue .. '"', LOG_INFO)
				helpers.handleEvents(scriptsToExecute, domoticz, device)
			end

		else
			-- this is weird.. basically impossible because the list of device objects is based on what
			-- Domoticz passes along.
		end


	end
end

helpers.dumpCommandArray(domoticz.commandArray)

commandArray = domoticz.commandArray
return commandArray