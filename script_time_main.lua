-- make sure we can find our modules
local currentPath = debug.getinfo(1).source:match("@?(.*/)")
package.path = package.path .. ';' .. currentPath .. '/dzVents/?.lua'

local EventHelpers = require('EventHelpers')
local helpers = EventHelpers()

commandArray = helpers.dispatchTimerEventsToScripts()

return commandArray