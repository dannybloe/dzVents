-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path = package.path .. ';' .. scriptPath .. '?.lua'
package.path = package.path .. ';' .. scriptPath .. '/dzVents/?.lua'

local settings = require('dzVents_settings')

-- create a global for the log level
logLevel = settings['Log level']

local Domoticz = require('Domoticz')
local domoticz = Domoticz()

local EventHelpers = require('EventHelpers')
local helpers = EventHelpers(domoticz)

-- todo: one call to do it all
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