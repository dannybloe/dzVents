return {
	active = true,
	on = {
		'somedevice'
	},
	storage = {
		a = { initial = '' },
		b = { initial = 1 },
		c = { initial = {x=1, y=2} },
		g = { initial = 666 } -- this one is local (there's also a global with this name)
	},
	execute = function(domoticz, device)
		domoticz.storage.a = 'this is set from script'
		domoticz.storage.b = 245
		domoticz.storage.c.x=10
		domoticz.storage.c.y=20
		domoticz.storage.g = 87

		domoticz.globalStorage.g = 999
		domoticz.globalStorage.h = false
	end
}