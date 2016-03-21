local min = 'minute'
return {
	active = true,
	on = {
		['timer'] = 'every ' .. min
	},
	execute = function(domoticz)
		domoticz.notify('Me')
		return 'script_timer_table'
	end
}