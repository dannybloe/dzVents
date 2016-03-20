local function Device(domoticz, name, state)

	local changedAttributes = {} -- storage for changed attributes

	local self = {
		['name'] = name,
		['changed'] = (devicechanged~=nil and devicechanged[name] ~= nil)
	}

	-- some states will be 'booleanized'
	local function stateToBool(state)
		state = string.lower(state)
		if (state == 'open' or
				state == 'on' or
				state == 'active' or
				state == 'activated' or
				state == 'motion') then
			return true
		end
		if (state == 'closed' or
				state == 'off' or
				state == 'inactive' or
				state == 'deactived') then
			return false
		end

		return nil
	end

	-- extract dimming levels for dimming devices
	local level
	if (string.find(state, 'Set Level')) then
		level = string.match(state, "%d+") -- extract dimming value
		state = 'On' -- consider the device to be on
	end

	if (level) then self['level'] = level end

	if (state~=nil) then -- not all devices have a state like sensors
	if (type(state)=='string') then -- just to be sure
	self['state'] = state
	self['bState'] = stateToBool(self['state'])
	else
		self['state'] = state
	end
	end

	-- generic state update method
	function self.setState(newState)
		return TimedCommand(domoticz, self.name, newState)
	end

	-- some convenient methods
	function self.switchOn()
		return TimedCommand(domoticz, self.name, 'On')
	end

	function self.switchOff()
		return TimedCommand(domoticz, self.name, 'Off')
	end

	function self.close()
		return TimedCommand(domoticz, self.name, 'Close')
	end

	function self.open()
		return TimedCommand(domoticz, self.name, 'Open')
	end

	function self.activate()
		return TimedCommand(domoticz, self.name, 'Activate')
	end

	function self.deactivate()
		return TimedCommand(domoticz, self.name, 'Deactivate')
	end

	function self.dimTo(percentage)
		return TimedCommand(domoticz, self.name, 'Set Level ' .. tostring(percentage))
	end

	function self.switchSelector(level)
		return TimedCommand(domoticz, self.name, 'Set Level ' .. tostring(level))
	end
	-- generic update method for non-switching devices
	-- each part of the update data can be passed as a separate argument e.g.
	-- device.update(12,34,54) will result in a command like
	-- ['UpdateDevice'] = '<id>|12|34|54'
	function self.update(...)
		local command = self.id
		for i,v in ipairs({...}) do
			command = command .. '|' .. tostring(v)
		end

		domoticz.sendCommand('UpdateDevice', command)
	end

	-- update specials
	-- see http://www.domoticz.com/wiki/Domoticz_API/JSON_URL%27s
	function self.updateTemperature(temperature)
		self.update(0, temperature)
	end

	--[[
		status can be
	 	domoticz.HUM_NORMAL
		domoticz.HUM_COMFORTABLE
		domoticz.HUM_DRY
		domoticz.HUM_WET
	 ]]
	function self.updateHumidity(humidity, status)
		self.update(humidity, status)
	end

	--[[
		forecast:
	 	domoticz.BARO_STABLE
		domoticz.BARO_SUNNY
		domoticz.BARO_CLOUDY
		domoticz.BARO_UNSTABLE
		domoticz.BARO_THUNDERSTORM
		domoticz.BARO_UNKNOWN
		domoticz.BARO_CLOUDY_RAIN
	 ]]
	function self.updateBarometer(pressure, forecast)
		self.update(0, tostring(pressure) .. ';' .. tostring(forecast))
	end

	function self.updateTempHum(temperature, humidity, status)
		local value = tostring(temperature) .. ';' .. tostring(humidity) .. ';' .. tostring(status)
		self.update(0, value)
	end

	function self.updateTempHumBaro(temperature, humidity, status, pressure, forecast)
		local value = tostring(temperature) .. ';' ..
				tostring(humidity) .. ';' ..
				tostring(status) .. ';' ..
				tostring(pressure)  .. ';' ..
				tostring(forecast)
		self.update(0, value)
	end

	function self.updateRain(rate, counter)
		self.update(0, tostring(rate) .. ';' .. tostring(counter))
	end

	function self.updateWind(bearing, direction, speed, gust, temperature, chill)
		local value = tostring(bearing) .. ';' ..
				tostring(direction) .. ';' ..
				tostring(speed) .. ';' ..
				tostring(gust)  .. ';' ..
				tostring(temperature)  .. ';' ..
				tostring(chill)
		self.update(0, value)
	end

	function self.updateUV(uv)
		local value = tostring(uv) .. ';0'
		self.update(0, value)
	end

	function self.updateCounter(value)
		self.update(value) -- no 0??
	end

	function self.updateElectricity(power, energy)
		self.update(0, tostring(power) .. ';' .. tostring(energy))
	end

	--[[
		USAGE1= energy usage meter tariff 1
		USAGE2= energy usage meter tariff 2
		RETURN1= energy return meter tariff 1
		RETURN2= energy return meter tariff 2
		CONS= actual usage power (Watt)
		PROD= actual return power (Watt)
		USAGE and RETURN are counters (they should only count up).
		For USAGE and RETURN supply the data in total Wh with no decimal point.
		(So if your meter displays f.i. USAGE1= 523,66 KWh you need to send 523660)
	 ]]
	function self.updateP1(usage1, usage2, return1, return2, cons, prod)
		local value = tostring(usage1) .. ';' ..
				tostring(usage2) .. ';' ..
				tostring(return1) .. ';' ..
				tostring(return2)  .. ';' ..
				tostring(cons)  .. ';' ..
				tostring(prod)
		self.update(0, value)
	end

	function self.updateAirQuality(quality)
		self.update(quality)
	end

	function self.updatePressure(pressure)
		self.update(0, pressure)
	end

	function self.updatePercentage(percentage)
		self.update(0, percentage)
	end

	--[[
		USAGE= Gas usage in liter (1000 liter = 1 m³)
		So if your gas meter shows f.i. 145,332 m³ you should send 145332.
		The USAGE is the total usage in liters from start, not f.i. the daily usage.
	 ]]
	function self.updateGas(usage)
		self.update(0, usage)
	end

	function self.updateLux(lux)
		self.update(lux)
	end

	function self.updateVoltage(voltage)
		self.update(0, voltage)
	end

	function self.updateText(text)
		self.update(0, text)
	end

	--[[ level can be
	 	domoticz.ALERTLEVEL_GREY
	 	domoticz.ALERTLEVEL_GREEN
		domoticz.ALERTLEVEL_YELLOW
		domoticz.ALERTLEVEL_ORANGE
		domoticz.ALERTLEVEL_RED
	]]
	function self.updateAlertSensor(level, text)
		self.update(level, text)
	end

	--[[
	 distance in cm or inches, can be in decimals. For example 12.6
	 ]]
	function self.updateDistance(distance)
		self.update(0, distance)
	end

	-- returns true if an attribute is marked as changed
	function self.attributeChanged(attribute)
		return (changedAttributes[attribute] == true)
	end

	-- mark an attribute as being changed
	function self.setAttributeChanged(attribute)
		changedAttributes[attribute] = true
	end

	-- add attribute to this device
	function self.addAttribute(attribute, value)
		self[attribute] = value
	end

	return self
end

return Device