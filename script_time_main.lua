-- Version 0.9.10

print('Handle timer events')

-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'

local settings = require('dzVents_settings')

-- create a global for the log level
logLevel = settings['Log level']

local helpers = require('event_helpers')
local Domoticz = require('Domoticz')
local domoticz = Domoticz()

local timerevents = helpers.getTimerHandlers(domoticz)

helpers.handleEvents(timerevents, domoticz)

helpers.dumpCommandArray(domoticz.commandArray)

if (settings['Enable http fetch']) then
	helpers.fetchHttpDomoticzData(
		settings['Domoticz ip'],
		settings['Domoticz port'],
		settings['Fetch interval']
	)
end

commandArray = domoticz.commandArray

return commandArray