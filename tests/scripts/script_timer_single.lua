return {
	active = true,
	on = {
		['timer'] = 'every minute'
	},
	execute = function(domoticz, device)
		return 'script_timer_table'
	end
}