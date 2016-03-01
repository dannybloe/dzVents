-- this class assumes acces to the domoticz
-- global tables

-- class for last update information
local function Time(sDate)
	local today = os.date('*t')
	local time = {}
	if (sDate ~= nil and sDate ~= '') then

		local y,mon,d,h,min,s = string.match(sDate, "(%d+)%-(%d+)%-(%d+)% (%d+):(%d+):(%d+)")
		local d = os.time{year=y,month=mon,day=d,hour=h,min=min,sec=s }
		time = os.date('*t', d)

		time.raw = sDate
		time.isToday = (today.year == time.year and
				today.month==time.month and
				today.day==time.day)

		-- calculate how many minutes that was from now
		local tToday = os.time{
			day=today.day,
			year=today.year,
			month=today.month,
			hour=today.hour,
			min=today.min,
			sec=today.sec
		}

		local diff = math.floor((os.difftime(tToday, d) / 60))

		time['minutesAgo'] = diff
	end

	local self = time
	self['current'] = today

	return self
end

-- simple string splitting method
-- coz crappy LUA doesn't have this natively... *sigh*
function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

-- Class for devices
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
		domoticz.sendCommand(self.name, newState)
	end

	-- generic 'switch' function wrapper
	-- timingOption can be like AFTER 2 or RANDOM 30
	local function switch(value, timingOption)
		if (extra==nil) then timingOption = '' end
		domoticz.sendCommand(self.name, value ..timingOption)
	end

	-- some convenient methods
	function self.switchOn(timingOption) switch('On', timingOption) end
	function self.switchOff(timingOption) switch('Off', timingOption) end
	function self.close(timingOption) switch('Close', timingOption) end
	function self.open(timingOption) switch('Open', timingOption) end
	function self.activate(timingOption) switch('Activate', timingOption) end
	function self.deactivate(timingOption) switch('Deactivate', timingOption) end

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

--	function self.updateSelector(value)
--		-- untested
--		domoticz.sendCommand('SwtichLight', self.id .. '|')
--		self.update(0, distance)
--	end

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

-- class for variables
local function Variable(domoticz, name, value)
	local self = {
		['nValue'] = tonumber(value),
		['value'] = value,
		['lastUpdate'] = Time(uservariables_lastupdate[name])
	}

	-- send an update to domoticz
	function self.set(value)
		domoticz.sendCommand('Variable:' .. name, tostring(value))
	end

	return self
end

-- main class
local function Domoticz()

	-- the new instance
	local self = {
		['commandArray']= {},
		['devices'] = {},
		['changedDevices']={},
		['security'] = globalvariables["Security"],
		['time'] = {
			['isDayTime'] = timeofday['Daytime'],
			['isNightTime'] = timeofday['Nighttime'],
			['sunriseInMinutes'] = timeofday['SunriseInMinutes'],
			['sunsetInMinutes'] = timeofday['SunsetInMinutes']
		},
		['variables'] = {},
		['PRIORITY_LOW'] = -2,
		['PRIORITY_MODERATE'] = -1,
		['PRIORITY_NORMAL'] = 0,
		['PRIORITY_HIGH'] = 1,
		['PRIORITY_EMERGENCY'] = 2,
		['HUM_NORMAL'] = 0,
		['HUM_COMFORTABLE'] = 1,
		['HUM_DRY'] = 2,
		['HUM_WET'] = 3,
		['BARO_STABLE'] = 0,
		['BARO_SUNNY'] = 1,
		['BARO_CLOUDY'] = 2,
		['BARO_UNSTABLE'] = 3,
		['BARO_THUNDERSTORM'] = 4,
		['BARO_UNKNOWN'] = 5,
		['BARO_CLOUDY_RAIN'] = 6,
		['ALERTLEVEL_GREY'] = 0,
		['ALERTLEVEL_GREEN'] = 1,
		['ALERTLEVEL_YELLOW'] = 2,
		['ALERTLEVEL_ORANGE'] = 3,
		['ALERTLEVEL_RED'] = 4,
		['SECURITY_DISARMED'] = 'Disarmed',
		['SECURITY_ARMEDAWAY'] = 'Armed Away',
		['SECURITY_ARMEDHOME'] = 'Armed Home'
	}

	-- add domoticz commands to the commandArray
	function self.sendCommand(command, value)
		table.insert(self.commandArray, {[command] = value})
	end

	-- return the device object by event name
	-- even name can be like MySensor_Temperature
	function self.getDeviceByEvent(eventName)

		if (eventName == '*') then return nil end -- special case

		local pos, len = string.find(eventName, '_')
		local name = eventName

		-- check for the _ addition
		if (pos ~= nil and pos > 1) then -- should be larger than 1!
			name = string.sub(eventName, 1, pos-1)
		end

		local device = self.devices[name]

		if (device == nil) then
			print('Cannot find a device by the event name ' .. eventName)
		end

		return device
	end

	-- have domoticz send a push notification
	function self.notify(subject, message, priority)
		-- set defaults
		if (priority == nil) then priority = self.PRIORITY_NORMAL end
		if (message == nil) then message = '' end

		self.sendCommand('SendNotification', subject .. '#' .. message .. '#' .. tostring(priority))
	end

	-- have domoticz send an email
	function self.email(subject, message, mailTo)
		self.sendCommand('SendEmail', subject .. '#' .. message .. '#' .. mailTo)
	end

	-- have domoticz open a url
	function self.openURL(url)
		self.sendCommand('OpenURL', url)
	end

	-- send a scene switch command
	function self.setScene(scene, value)
		self.sendCommand('Scene:' .. scene, value)
	end

	-- send a group switch command
	function self.switchGroup(group, value)
		self.sendCommand('Group:' .. group, value)
	end

	-- bootstrap the variables section
	local function createVariables()
		for name, value in pairs(uservariables) do
			local var = Variable(self, name, value)
			self.variables[name] = var
		end

	end

	-- process a otherdevices table for a given attribute and
	-- set the attribute on the appropriate device object
	local function setDeviceAttribute(otherdevicesTable, attribute, tableName)
		for name, value in pairs(otherdevicesTable) do

			if (name ~= nil and name ~= '') then -- sometimes domoticz seems to do this!! ignore...

				-- get the device
				local device = self.devices[name]

				if (device == nil) then
					print ('Cannot find the device. Skipping:  ' .. name .. ' ' .. value)
				else
					if (attribute == 'lastUpdate') then
						device.addAttribute(attribute, Time(value))
					elseif (attribute == 'rawData') then
						device.addAttribute(attribute, string.split(value, ';'))
					elseif (attribute == 'id') then
						device.addAttribute(attribute, value)

						-- create lookup by id
						self.devices[value] = device

						-- create the changedDevices entry when changed
						-- we do it at this moment because at this stage
						-- the device just got his id
						if (device.changed) then
							self.changedDevices[device.name] = device
							self.changedDevices[value] = device -- id lookup
						end
					else
						device.addAttribute(attribute, value)
					end

					if (tableName ~=nil) then
						local deviceAttributeName = name .. '_' ..
								string.upper(string.sub(tableName,1,1)) ..
								string.sub(tableName,2)

						-- now we have to transfer the changed information for attributes
						-- if that is availabel
						if (devicechanged and devicechanged[deviceAttributeName]~= nil) then
							device.setAttributeChanged(attribute)
						end
					end
				end
			end
		end
	end

	local function createDevices()
		-- first create the device objects
		for name, state in pairs(otherdevices) do
			self.devices[name] = Device(self, name, state)
		end

		-- then fill them with attributes from the
		-- global tables handed over by Domoticz
		for tableName, tableData in pairs(_G) do

			-- only deal with global <otherdevices_*> tables
			if (string.find(tableName, 'otherdevices_')~=nil) then

				-- extract the part after 'otherdevices_'
				-- That is the unprocesses attribute name
				local oriAttribute = string.sub(tableName, 14)
				local attribute = oriAttribute

				-- now process some specials
				if (attribute) == 'idx' then
					attribute = 'id'
				end
				if (attribute == 'lastupdate') then
					attribute = 'lastUpdate'
				end
				if (attribute == 'svalues') then
					attribute = 'rawData'
				end

				-- now let's get and store the stuff
				setDeviceAttribute(tableData, attribute, oriAttribute)

			end
		end
	end

	createVariables()
	createDevices()

	return self
end

return Domoticz
