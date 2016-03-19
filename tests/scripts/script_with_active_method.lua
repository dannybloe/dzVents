return {
	active = function(x)
		return x.active()
	end,
	on = {
		'onscript_active'
	},
	execute = function(domoticz, device)
		return 'script_with_active_method'
	end
}