-- generic 'switch' class with timed options
-- supports chainging like:
-- switch(v1).for_min(v2).after_sec/min(v3)
-- switch(v1).within_min(v2).for_min(v3)
-- switch(v1).after_sec(v2).for_min(v3)

local function TimedCommand(domoticz, name, value)
	local valueValue = value
	local afterValue, forValue, randomValue

	local constructCommand = function()
		local command = {}
		table.insert(command, valueValue)
		if (randomValue ~= nil) then
			table.insert(command, 'RANDOM ' .. tostring(randomValue))
		end
		if (afterValue ~= nil) then
			table.insert(command, 'AFTER ' .. tostring(afterValue))
		end
		if (forValue ~= nil) then
			table.insert(command, 'FOR ' .. tostring(forValue))
		end

		local sCommand = table.concat(command, " ")
		log('Constructed command: ' .. sCommand, LOG_DEBUG)
		return sCommand
	end

	local latest, command, sValue = domoticz.sendCommand(name, constructCommand())
	return {
		['after_sec'] = function(seconds)
			afterValue = seconds
			latest[command] = constructCommand()
			return {
				['for_min'] = function(minutes)
					forValue = minutes
					latest[command] = constructCommand()
				end
			}
		end,
		['after_min'] = function(minutes)
			afterValue = minutes * 60
			latest[command] = constructCommand()
			return {
				['for_min'] = function(minutes)
					forValue = minutes
					latest[command] = constructCommand()
				end
			}
		end,
		['for_min'] = function(minutes)
			forValue = minutes
			latest[command] = constructCommand()
			return {
				['after_sec'] = function(seconds)
					afterValue = seconds
					latest[command] = constructCommand()
				end,
				['after_min'] = function(minutes)
					afterValue = minutes * 60
					latest[command] = constructCommand()
				end

			}
		end,
		['within_min'] = function(minutes)
			randomValue = minutes
			latest[command] = constructCommand()
			return {
				['for_minutes'] = function(minutes)
					forValue = minutes
					latest[command] = constructCommand()
				end
			}
		end
	}
end

return TimedCommand