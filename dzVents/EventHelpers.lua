local SCRIPTFOLDER = '/scripts'
local MAIN_METHOD = 'execute'

local utils = require('utils')

-- global log function
LOG_INFO = 2
LOG_DEBUG = 3
LOG_ERROR = 1

local function EventHelpers(settings, domoticz, scriptFolder, mainMethod)

	local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
	package.path = package.path .. ';' .. scriptPath .. '?.lua'
	package.path = package.path .. ';' .. scriptPath .. scriptFolder .. '/?.lua'

	if (domoticz == nil) then
		local Domoticz = require('Domoticz')
		local domoticz = Domoticz(settings)
	end

	if (scriptFolder == nil) then
		scriptFolder = SCRIPTFOLDER --default
	end

	local self = {
		['utils'] = utils, -- convenient for testing and stubbing
		['domoticz'] = domoticz,
		['scriptFolder'] = scriptFolder,
		['mainMethod'] = mainMethod or MAIN_METHOD,
		['deviceValueExtenstions'] = {
			['_Temperature'] = true,
			['_Dewpoint'] = true,
			['_Humidity'] = true,
			['_Barometer'] = true,
			['_Utility'] = true,
			['_Weather'] = true,
			['_Rain'] = true,
			['_RainLastHour'] = true,
			['_UV'] = true
		}
	}

	function self.print(msg)
		print(msg)
	end

	-- global function
	function self.log(msg, level)

		if (level == nil) then level = LOG_INFO end

		local lLevel = _G.logLevel==nil and 1 or _G.logLevel

		if (level <= lLevel) then
			self.print(msg)
		end
	end

	-- make a global log
	log = self.log

	function self.callEventHandler(eventHandler, device)
		if (eventHandler[self.mainMethod] ~= nil) then
			local ok, res = pcall(eventHandler[self.mainMethod], self.domoticz, device)
			if (ok) then
				eventHandler['__called'] = true
				return res
			else
				self.log('An error occured when calling event handler ' .. eventHandler.name, LOG_ERROR)
				self.log(res, LOG_ERROR) -- error info
			end
		else
			self.log('No' .. self.mainMethod .. 'function found in event handler ' .. eventHandler, LOG_ERROR)
		end
	end

	function self.reverseFind(s, target)
		-- string: 'this long string is a long string'
		-- string.findReverse('long') > 23, 26

		local reversed = string.reverse(s)
		local rTarget = string.reverse(target)
		-- reversed: gnirts gnol a si gnirts gnol siht
		-- rTarget = gnol

		local from, to = string.find(reversed, rTarget)
		if (from~=nil) then
			-- return 1 less
			local targetPos = string.len(s) - to + 1
			return targetPos, targetPos + string.len(target) - 1
		else
			return nil, nil
		end
	end

	function self.getDeviceNameByEvent(event)
		-- event can be of the form <device name>_<value extension>
		-- where device name can contain underscores as well
		-- we have to extract the device name here and peel away the
		-- known value extension

		local pos, len = self.reverseFind(event, '_')

		local name = event
		if (pos ~= nil and pos > 1) then -- cannot start with _ (we use that for our _always script)
			local valueExtension = string.sub(event, pos)

			-- only peel away the first part if the extension is known
			if (self.deviceValueExtenstions[valueExtension]) then
				name = string.sub(event, 1, pos - 1)
			end
		end
		return name
	end

	function self.scandir(directory)
		local pos, len
		local i, t, popen = 0, {}, io.popen
		local sep = string.sub(package.config,1,1)
		local cmd

		if (sep=='/') then
			cmd = 'ls -a "'..directory..'"'
		else
			-- assume windows for now
			cmd = 'dir "'..directory..'" /b /ad'
		end

		t = {}
		local pfile = popen(cmd)
		for filename in pfile:lines() do
			pos,len = string.find(filename, '.lua')

			if (pos and pos > 0 ) then
				table.insert(t, string.sub(filename, 1, pos-1))
				self.log('Found module in ' .. self.scriptFolder .. ' folder: ' .. t[#t], LOG_DEBUG)
			end

		end
		pfile:close()
		return t
	end

	function self.getDayOfWeek(testTime)
		local d
		if (testTime~=nil) then
			d = testTime.day
		else
			d = os.date('*t').wday
		end

		local lookup = {'sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat' }
		self.log('Current day .. ' .. lookup[d], LOG_DEBUG)
		return lookup[d]
	end

	function self.getNow(testTime)
		if (testTime==nil) then
			local timenow = os.date("*t")
			return timenow
		else
			self.log('h=' .. testTime.hour .. ' m=' .. testTime.min)
			return testTime
		end
	end

	function self.isTriggerByMinute(m, testTime)
		local time = self.getNow(testTime)
		return (time.min/m == math.floor(time.min/m))
	end

	function self.isTriggerByHour(h, testTime)
		local time = self.getNow(testTime)
		return (time.hour/h == math.floor(time.hour/h) and time.min==0)
	end

	function self.isTriggerByTime(t, testTime)
		local tm, th
		local time = self.getNow(testTime)

		-- specials: sunset, sunrise
		if (t == 'sunset' or t=='sunrise') then
			local minutesnow = time.min + time.hour * 60

			if (testTime~=nil) then
				if (t == 'sunset') then
					return (minutesnow == testTime['SunsetInMinutes'])
				else
					return (minutesnow == testTime['SunriseInMinutes'])
				end
			else
				if (t == 'sunset') then
					return (minutesnow == timeofday['SunsetInMinutes'])
				else
					return (minutesnow == timeofday['SunriseInMinutes'])
				end
			end

		end

		local pos = string.find(t, ':')

		if (pos~=nil and pos > 0) then
			th = string.sub(t, 1, pos-1)
			tm = string.sub(t, pos+1)

			if (tm == '*') then
				return (time.hour == tonumber(th))
			elseif (th == '*') then
				return (time.min == tonumber(tm))
			elseif (th~='*' and tm~='*') then
				return (tonumber(tm) == time.min and tonumber(th) == time.hour)
			else
				self.log('wrong time format', LOG_ERROR)
				return false
			end

		else
			self.log('Wrong time format, should be hh:mm ' .. tostring(t), LOG_DEBUG)
			return false
		end
	end

	function self.evalTimeTrigger(t, testTime)
		if (testTime) then self.log(t) end

		-- t is a single timer definition
		t = string.lower(t) -- normalize

		-- first get a possible on section (days)
		local onPos = string.find(t, ' on ')
		local days

		if (onPos ~= nil and onPos > 0) then
			days = string.sub(t, onPos + 4)
			t = string.sub(t, 1, onPos - 1)
		end

		-- now we can skip everything if the current day
		-- cannot be found in the days string
		if (days~=nil and string.find(days, self.getDayOfWeek(testTime)) == nil) then
			-- today is not part of this trigger definition
			return false
		end

		local m,h
		local words = {}
		for w in t:gmatch("%S+") do
			table.insert(words, w)
		end

		-- specials
		if (t == 'every minute') then
			return self.isTriggerByMinute(1, testTime)
		end

		if (t == 'every other minute') then
			return self.isTriggerByMinute(2, testTime)
		end

		if (t == 'every hour') then
			return self.isTriggerByHour(1, testTime)
		end

		if (t == 'every other hour') then
			return self.isTriggerByHour(2, testTime)
		end

		-- others

		if (words[1] == 'every') then

			if (words[3] == 'minutes') then
				m = tonumber(words[2])
				if (m ~= nil) then
					return self.isTriggerByMinute(m, testTime)
				else
					self.log(t .. ' is not a valid timer definition', LOG_ERROR)
				end
			elseif (words[3] == 'hours') then
				h = tonumber(words[2])
				if (h ~= nil) then
					return self.isTriggerByHour(h, testTime)
				else
					self.log(t .. ' is not a valid timer definition', LOG_ERROR)
				end
			end
		elseif (words[1] == 'at' or words[1] == 'at:') then
			-- expect a time stamp
			local time = words[2]
			return self.isTriggerByTime(time, testTime)
		end
	end

	function self.handleEvents(events, device)
		if (type(events) ~= 'table') then
			return
		end

		for eventIdx, eventHandler in pairs(events) do
			if (not eventHandler.__called) then
				self.log('=====================================================', LOG_INFO)
				self.log('>>> Handler: ' .. eventHandler.name , LOG_INFO)
				if (device) then
					self.log('>>> Device: "' .. device.name .. '" Index: ' .. tostring(device.id), LOG_INFO)
				end

				self.log('.....................................................', LOG_INFO)

				self.callEventHandler(eventHandler, device)

				self.log('.....................................................', LOG_INFO)
				self.log('<<< Done ', LOG_INFO)
				self.log('-----------------------------------------------------', LOG_INFO)
			else
				self.log('Skipping ' .. eventHandler.name .. '. Already executed', LOG_INFO)
			end
		end
	end

	function self.checkTimeDefs(timeDefs, testTime)
		-- accepts a table of timeDefs, if one of them matches with the
		-- current time, then it returns true
		-- otherwise it returns false
		for i, timeDef in pairs(timeDefs) do
			if (self.evalTimeTrigger(timeDef, testTime)) then
				return true
			end
		end
		return false
	end

	function self.getEventBindings(mode)
		local bindings = {}
		local errModules = {}
		local ok, modules, moduleName, i, event, j, device
		ok, modules = pcall( self.scandir, scriptPath .. self.scriptFolder)
		if (not ok) then
			self.log(modules, LOG_ERROR)
			return nil
		end

		for i, moduleName  in pairs(modules) do

			local module, skip
			ok, module = pcall(require, moduleName)
			if (ok) then
				if (type(module) == 'table') then
					skip = false
					if (module.active ~= nil) then
						local active = false
						if (type(module.active) == 'function') then
							active = module.active(self.domoticz)
						else
							active = module.active
						end

						if (not active) then
							skip = true
						end
					end
					if (not skip) then
						if ( module.on ~= nil and module[self.mainMethod]~= nil ) then
							module.name = moduleName
							for j, event in pairs(module.on) do
								if (mode == 'timer') then
									if (type(j) == 'number' and type(event) == 'string' and event == 'timer') then
										-- { 'timer' }
										-- execute every minute (old style)
										table.insert(bindings, module)
									elseif (type(j) == 'string' and j=='timer' and type(event) == 'string') then
										-- { ['timer'] = 'every minute' }
										if (self.evalTimeTrigger(event)) then
											table.insert(bindings, module)
										end
									elseif (type(j) == 'string' and j=='timer' and type(event) == 'table') then
										-- { ['timer'] = { 'every minute ', 'every hour' } }
										if (self.checkTimeDefs(event)) then
											-- this one can be executed
											table.insert(bindings, module)
										end
									end
								else
									if (event ~= 'timer' and j~='timer') then
										-- let's not try to resolve indexes to names here for performance reasons
										if (bindings[event] == nil) then
											bindings[event] = {}
										end
										table.insert(bindings[event], module)
									end
								end
							end
						else
							self.log('Script ' .. moduleName .. '.lua has no "on" and/or "' .. self.mainMethod .. '" section. Skipping', LOG_ERROR)
							table.insert(errModules, moduleName)
						end
					end
				else
					self.log('Script ' .. moduleName .. '.lua is not a valid module. Skipping', LOG_ERROR)
					table.insert(errModules, moduleName)
				end
			else
				table.insert(errModules, moduleName)
				self.log(module, LOG_ERROR)
			end
		end

		return bindings, errModules
	end

	function self.getTimerHandlers()
		return self.getEventBindings('timer')
	end

	function self.fetchHttpDomoticzData(ip, port, interval)

		local sep = string.sub(package.config,1,1)
		if (sep ~= '/') then return end -- only on linux

		if (ip == nil or port == nil) then
			self.log('Invalid ip for contacting Domoticz', LOG_ERROR)
			return
		end

		if (self.evalTimeTrigger(interval)) then
			self.utils.requestDomoticzData(ip, port)
		end

	end

	function self.dumpCommandArray(commandArray)
		local printed = false
		for k,v in pairs(commandArray) do
			if (type(v)=='table') then
				for kk,vv in pairs(v) do
					self.log('[' .. k .. '] = ' .. kk .. ': ' .. vv, LOG_INFO)
				end
			else
				self.log(k .. ': ' .. v, LOG_INFO)
			end
			printed = true
		end
		if(printed) then self.log('=====================================================', LOG_INFO) end
	end

	function self.findScriptForChangedDevice(changedDeviceName, allEventScripts)
		-- event could be like: myPIRLivingRoom
		-- or myPir(.*)
		self.log('Searching for scripts for changed device: '.. changedDeviceName, LOG_DEBUG)

		for scriptTrigger, scripts in pairs(allEventScripts) do
			if (string.find(scriptTrigger, '*')) then -- a wild-card was use
				-- turn it into a valid regexp
				scriptTrigger = string.gsub(scriptTrigger, "*", ".*")

				if (string.match(changedDeviceName, scriptTrigger)) then
					-- there is trigger for this changedDeviceName
					return scripts
				end
			else
				if (scriptTrigger == changedDeviceName) then
					-- there is trigger for this changedDeviceName
					return scripts
				end
			end
		end

		return nil
	end

	function self.dispatchDeviceEventsToScripts(changedDevices)
		if (changedDevices == nil) then
			-- get it from the globals
			changedDevices = devicechanged
		end

		local allEventScripts = self.getEventBindings()

		if (changedDevices ~=nil) then
			for changedDeviceName, changedDeviceValue in pairs(changedDevices) do

				self.log('Event in devicechanged: ' .. changedDeviceName .. ' value: ' .. changedDeviceValue, LOG_DEBUG)
				local scriptsToExecute

				-- find the device for this name
				-- could be MySensor or MySensor_Temperature
				-- the device returned would be MySensor in that case
				local baseName = self.getDeviceNameByEvent(changedDeviceName)
				local device = self.domoticz.devices[baseName]

				if (device~=nil) then
					-- first search by name
					scriptsToExecute = self.findScriptForChangedDevice(device.name, allEventScripts)

					if (scriptsToExecute ==nil) then
						-- search by id
						scriptsToExecute = allEventScripts[device.id]
					end
					if (scriptsToExecute ~=nil) then
						self.log('Handling events for: "' .. changedDeviceName .. '", value: "' .. changedDeviceValue .. '"', LOG_INFO)
						self.handleEvents(scriptsToExecute, device)
					end

				else
					-- this is weird.. basically impossible because the list of device objects is based on what
					-- Domoticz passes along.
				end
			end
		end
		self.dumpCommandArray(self.domoticz.commandArray)
		return self.domoticz.commandArray
	end

	return self

end

return EventHelpers