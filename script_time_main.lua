-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.7

print('Handle timer events')

-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'

local helpers = require('event_helpers')
local Domoticz = require('Domoticz')
local domoticz = Domoticz()

local timerevents = helpers.getTimerHandlers(domoticz)

helpers.handleEvents(timerevents, domoticz)

helpers.dumpCommandArray(domoticz.commandArray)

commandArray = domoticz.commandArray

return commandArray