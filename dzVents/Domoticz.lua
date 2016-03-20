local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'

local EventHelpers = require('EventHelpers')
local Device = require('Device')
local Variable = require('Variable')
local Time = require('Time')
local TimedCommand = require('TimedCommand')
local utils = require('utils')

LOG_INFO = 2
LOG_DEBUG = 3
LOG_ERROR = 1

-- simple string splitting method
-- coz crappy LUA doesn't have this natively... *sigh*
function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

-- main class
local function Domoticz(settings)

	-- the new instance
	local self = {
		['settings'] = settings,
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
        ['SOUND_DEFAULT'] = 'pushover',
        ['SOUND_BIKE'] = 'bike',
        ['SOUND_BUGLE'] = 'bugle',
        ['SOUND_CASH_REGISTER'] = 'cashregister',
        ['SOUND_CLASSICAL'] = 'classical',
        ['SOUND_COSMIC'] = 'cosmic',
        ['SOUND_FALLING'] = 'falling',
        ['SOUND_GAMELAN'] = 'gamelan',
        ['SOUND_INCOMING'] = 'incoming',
        ['SOUND_INTERMISSION'] = 'intermission',
        ['SOUND_MAGIC'] = 'magic',
        ['SOUND_MECHANICAL'] = 'mechanical',
        ['SOUND_PIANOBAR'] = 'pianobar',
        ['SOUND_SIREN'] = 'siren',
        ['SOUND_SPACEALARM'] = 'spacealarm',
        ['SOUND_TUGBOAT'] = 'tugboat',
        ['SOUND_ALIEN'] = 'alien',
        ['SOUND_CLIMB'] = 'climb',
        ['SOUND_PERSISTENT'] = 'persistent',
        ['SOUND_ECHO'] = 'echo',
        ['SOUND_UPDOWN'] = 'updown',
        ['SOUND_NONE'] = 'none',
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
		['SECURITY_ARMEDHOME'] = 'Armed Home',
		['LOG_INFO'] = 2,
		['LOG_DEBUG'] = 3,
		['LOG_ERROR'] = 1,
	}

	local function setIterators(context, collection)
		collection['forEach'] = function(func)
			for i, item in pairs(collection) do
				if (type(item) ~= 'function' and type(i)~='number') then
					func(item, i)
				end
			end
		end

		collection['filter'] = function(filter)
			local res = {}
			for i, item in pairs(collection) do
				if (type(item) ~= 'function' and type(i)~='number') then
					if (filter(item)) then
						res[i] = item
					end
				end
			end
			setIterators(res, res)
			return res
		end
	end

	setIterators(self, self.devices)
	setIterators(self, self.changedDevices)
	setIterators(self, self.variables)


	-- add domoticz commands to the commandArray
	function self.sendCommand(command, value)
		table.insert(self.commandArray, {[command] = value})

		-- return a reference to the newly added item
		return self.commandArray[#self.commandArray], command, value
	end

	-- have domoticz send a push notification
	function self.notify(subject, message, priority, sound)
		-- set defaults
		if (priority == nil) then priority = self.PRIORITY_NORMAL end
		if (message == nil) then message = '' end
        if (sound == nil) then sound = self.SOUND_DEFAULT end

		self.sendCommand('SendNotification', subject .. '#' .. message .. '#' .. tostring(priority) .. '#' .. tostring(sound))
	end

	-- have domoticz send an email
	function self.email(subject, message, mailTo)
		if (mailTo==nil) then
			log('No mail to is provide', LOG_DEBUG)
		else
			if (subject == nil) then subject = '' end
			if (message == nil) then message = '' end
			self.sendCommand('SendEmail', subject .. '#' .. message .. '#' .. mailTo)
		end
	end

	-- have domoticz send an sms
	function self.sms(message)
		self.sendCommand('SendSMS', message)
	end

	-- have domoticz open a url
	function self.openURL(url)
		self.sendCommand('OpenURL', url)
	end

	-- send a scene switch command
	function self.setScene(scene, value)
		return TimedCommand(self, 'Scene:' .. scene, value)
	end

	-- send a group switch command
	function self.switchGroup(group, value)
		return TimedCommand(self, 'Group:' .. group, value)
	end

	if (_G.TESTMODE) then
		function self._getUtilsInstance()
			return utils
		end
	end

	function self.fetchHttpDomoticzData()
		utils.requestDomoticzData(
			self.settings['Domoticz ip'],
			self.settings['Domoticz port']
		)
	end

	function self.log(message, level)
		log(message, level)
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
			-- log('otherdevices table :' .. name .. ' value: ' .. value, LOG_DEBUG)
			if (name ~= nil and name ~= '') then -- sometimes domoticz seems to do this!! ignore...

				-- get the device
				local device = self.devices[name]

				if (device == nil) then
					log('Cannot find the device. Skipping:  ' .. name .. ' ' .. value, LOG_ERROR)
				else
					if (attribute == 'lastUpdate') then
						device.addAttribute(attribute, Time(value))
					elseif (attribute == 'rawData') then
						device._sValues = value
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

	local function dumpTable(t, level)
		for attr, value in pairs(t) do
			if (type(value) ~= 'function') then
				if (type(value) == 'table') then
					print(level .. attr .. ':')
					dumpTable(value, level .. '    ')
				else
					print(level .. attr .. ': ' .. value)
				end
			end
		end
	end

	-- doesn't seem to work well for some weird reasone
	function self.logDevice(device)
		print('----------------------------')
		print('Device: ' .. device.name)
		print('----------------------------')
		dumpTable(device, '> ')
	end

	local function readHttpDomoticzData()
		local httpData = {
			['result'] = {}
		}

		-- figure out what os this is
		local sep = string.sub(package.config,1,1)
		if (sep~='/') then return httpData end -- only on linux

		if utils.fileExists(utils.getDevicesPath()) then
			local ok, module

			ok, module = pcall(require, 'devices')
			if (ok) then
				if (type(module) == 'table') then
					httpData = module
				end
			else
				-- cannot be loaded
				log('devices.lua cannot be loaded', LOG_ERROR)
				log(module, LOG_ERROR)
			end
		end
		return httpData
	end

	local function createDevices()
		-- first create the device objects
		for name, state in pairs(otherdevices) do
			local wasChanged = (devicechanged~=nil and devicechanged[name] ~= nil)
			self.devices[name] = Device(self, name, state, wasChanged)
		end

		-- then fill them with attributes from the
		-- global tables handed over by Domoticz
		for tableName, tableData in pairs(_G) do

			-- only deal with global <otherdevices_*> tables
			if (string.find(tableName, 'otherdevices_')~=nil) then
				log('Found ' .. tableName .. ' adding this as a possible attribute', LOG_DEBUG)
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
				if (attribute == 'rain_lasthour') then
					attribute = 'rainLastHour'
				end

				-- now let's get and store the stuff
				setDeviceAttribute(tableData, attribute, oriAttribute)

			end
		end

		local httpData = readHttpDomoticzData()

		if (httpData) then
			for i, httpDevice in pairs(httpData.result) do
				if (self.devices[httpDevice['Name']]) then
					local device = self.devices[httpDevice['Name']]
					device['batteryLevel'] = httpDevice.BatteryLevel
					device['signalLevel'] = httpDevice.SignalLevel
					device['deviceSubType'] = httpDevice.SubType
					device['deviceType'] = httpDevice.Type
					device['hardwareName'] = httpDevice.HardwareName
					device['hardwareType'] = httpDevice.HardwareType
					device['hardwareId'] = httpDevice.HardwareID
					device['hardwareTypeVal'] = httpDevice.HardwareTypeVal
					device['switchType'] = httpDevice.SwitchType
					device['switchTypeValue'] = httpDevice.SwitchTypeVal

					if (device.deviceType == 'Heating' and device.deviceSubType == 'Zone') then
						device.setPoint = tonumber(device.rawData[2])
						device.heatingMode = device.rawData[3]
					end

					if (device.deviceType ==  'Lux' and device.deviceSubType == 'Lux') then
						device.lux = tonumber(device.rawData[1])
					end

					if (device.deviceType ==  'General' and device.deviceSubType == 'kWh') then
						device.WhTotal = tonumber(device.rawData[2])
						device.WhToday = tonumber(device.rawData[1])
					end
					if (device.deviceType ==  'P1 Smart Meter' and device.deviceSubType == 'Energy') then
						device.WActual = tonumber(device.rawData[5])
					end

					if (device.deviceType == 'Thermostat' and device.deviceSubType == 'SetPoint') then
						device.setPoint = tonumber(device.rawData[1])
					end


				end
			end
		end
	end

	createVariables()
	createDevices()

	return self
end

return Domoticz
