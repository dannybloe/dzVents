return {
	active = true,
	on = {
		'timer'
	},
	execute = function(domoticz, device)
		return 'script_timer_classic'
	end
}