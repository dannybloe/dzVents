-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'

local settings = require('dzVents_settings')
-- create a global for the log level

logLevel = settings['Log level']

LOG_INFO = 2
LOG_DEBUG = 3
LOG_ERROR = 1

local Domoticz = require('Domoticz')
local domoticz = Domoticz()

local EventHelpers = require('event_helpers')

local helpers = EventHelpers(domoticz)

helpers.dispatchDeviceEventsToScripts(devicechanged)

helpers.dumpCommandArray(domoticz.commandArray)

commandArray = domoticz.commandArray
return commandArray