-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.6
-- See readme.md for a description

return {
	active = false,                  -- set to true to activate this script,
								     --can also be a function returning either true or false
	on = {
		'My switch',                 -- name of the device
		'My sensor_Temperature',
		'My sensor',
		258,                         -- index of the device
		['timer'] = 'every minute',  -- see readme for more options and schedules
		'*',                         -- script is always executed in every 'device update cycle' (many times a minute!)
	},

	execute = function(value, deviceName, deviceIndex)
		local commandArray = {}

		-- example
		if (value == 'On') then
			commandArray['SendNotification'] = 'I am on!'
		end

		return commandArray
	end
}