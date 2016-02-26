-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.6

print('Handle timer events')

-- make sure we can find our modules
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'

commandArray = {}

local helpers = require('event_helpers')
local timerevents = helpers.getTimerHandlers()

commandArray = helpers.handleEvents(timerevents, nil, commandArray, nil, nil)

helpers.dumpCommandArray(commandArray)

return commandArray