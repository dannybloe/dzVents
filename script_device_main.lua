-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'
package.path = package.path .. ';' .. scriptPath .. '/dzVents/?.lua'

local settings = require('dzVents_settings')
-- create a global for the log level

logLevel = settings['Log level']

LOG_INFO = 2
LOG_DEBUG = 3
LOG_ERROR = 1

local EventHelpers = require('EventHelpers')
local helpers = EventHelpers()

commandArray = helpers.dispatchDeviceEventsToScripts()

return commandArray