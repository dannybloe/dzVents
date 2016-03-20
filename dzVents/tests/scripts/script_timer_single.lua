local min = 'minute'
return {
	active = true,
	on = {
		['timer'] = 'every ' .. min
	},
	execute = function(domoticz, device)
		return 'script_timer_table'
	end
}