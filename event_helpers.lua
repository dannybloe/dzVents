-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.6

-- make sure we can find our modules
local SCRIPTFOLDER = 'scripts'
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'
package.path    = package.path .. ';' .. scriptPath .. SCRIPTFOLDER .. '/?.lua'


local MAIN_METHOD = 'execute'

-- load the mddule and call the MAIN_METHOD
-- also has some error handling
function callEventHandler(eventHandler, value, name, index)
	if (eventHandler[MAIN_METHOD] ~= nil) then
		local ok2, res = pcall(eventHandler[MAIN_METHOD], value, name, index)
		if (ok2) then
			return res
		else
			print('An error occured when calling event handler ' .. eventHandler.name)
			print(res) -- error info
		end
	else
		print('No' .. MAIN_METHOD .. 'function found in event handler ' .. eventHandler)
	end
	return {}
end

-- return the index of a given device name
-- strips any additions like _Temperature first
function getIndex(device, otherdevices_idx)
	if (otherdevices_idx == nil) then
		-- old system
		return 0
	end

	-- first get the name, it could be 'My temperature_humidity', we only need the part before the _
	local name = device
	local pos, len = string.find(device, '_')
	if (pos ~= nil and pos > 1) then -- cannot start with _ (we use that for our _always script)
		name = string.sub(device, 1, pos-1)
	end
	-- now find the index in the table otherdevices_idx
	local idx = otherdevices_idx[name]

	return idx
end

function length(t)
	local count = 0
	if (type(t) == 'table') then
		for i,j in pairs(t) do
			count = count + 1
		end
	end
	return count
end

function handleEvents(events, deviceValue, commandArray, deviceName, deviceIndex)
	local commands

	if (type(events) ~= 'table') then
		return commandArray
	end

	for eventIdx, eventHandler in pairs(events) do
		print('=====================================================')
		print('>>> Handler: ' .. eventHandler.name )
		if (deviceName) then
			print('>>> Device: "' .. deviceName .. '" Index: ' .. deviceIndex)
		end
		print('.....................................................')

		commands = callEventHandler(eventHandler, deviceValue, deviceName, deviceIndex)

		print('.....................................................')
		print('<<< Done ')
		print('-----------------------------------------------------')

		-- commandIndex = commandIndex + 1
		for k,v in pairs(commands) do
			if (type(k) == 'number' and type(v) == 'table') then
				table.insert(commandArray, v)
			else
				table.insert(commandArray, {[k]=v})
			end

		end
	end

	return commandArray, commandIndex
end

function getEventBindings(mode)
	local bindings = {}
	local ok, modules, moduleName, i, event, j, device
	ok, modules = pcall( scandir, scriptPath .. '/' .. SCRIPTFOLDER)
	if (not ok) then
		print(modules)
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
						active = module.active()
					else
						active = module.active
					end

					if (not active) then
						skip = true
					end
				end
				if (not skip) then
					if ( module.on ~= nil and module[MAIN_METHOD]~= nil ) then
						module.name = moduleName
						for j, event in pairs(module.on) do
							if (mode == 'timer') then
								if (type(j) == 'number' and type(event) == 'string' and event == 'timer') then
									-- { 'timer' }
									-- execute every minute (old style)
									table.insert(bindings, module)
								elseif (type(j) == 'string' and j=='timer' and type(event) == 'string') then
									-- { ['timer'] = 'every minute' }
									if (evalTimeTrigger(event)) then
										table.insert(bindings, module)
									end
								elseif (type(j) == 'string' and j=='timer' and type(event) == 'table') then
									-- { ['timer'] = { 'every minute ', 'every hour' } }
									if (checkTimeDefs(event)) then
										-- this one can be executed
										table.insert(bindings, module)
									end
								end
							else
								if (event ~= 'timer') then
									-- let's not try to resolve indexes to names here for performance reasons
									if ( bindings[event] == nil) then
										bindings[event] = {}
									end
									table.insert(bindings[event], module)
								end
							end
						end
					else
						print('Script ' .. moduleName .. '.lua has no "on" and/or "' .. MAIN_METHOD .. '" section. Skipping')
					end
				end
			else
				print('Script ' .. moduleName .. '.lua is not a valid module. Skipping')
			end
		else
			print(module)
		end
	end

	return bindings
end

function getTimerHandlers()
	return getEventBindings('timer')
end

function scandir(directory)
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

	local pfile = popen(cmd)
	for filename in pfile:lines() do

		pos,len = string.find(filename, '.lua')
		if (pos and pos > 0 ) then
			i = i + 1
			t[i] = string.sub(filename, 1, pos-1)
			-- print('module ' .. t[i])
		end

	end
	pfile:close()
	return t
end

function dumpCommandArray(commandArray)
	local printed = false
	for k,v in pairs(commandArray) do
		if (type(v)=='table') then
			for kk,vv in pairs(v) do
				print('[' .. k .. '] = ' .. kk .. ': ' .. vv)
			end
		else
			print(k .. ': ' .. v)
		end
		printed = true
	end
	if(printed) then print('=====================================================') end
end

function getNow(testTime)
	if (testTime==nil) then
		local timenow = os.date("*t")
		return timenow
	else
		print('h=' .. testTime.hour .. ' m=' .. testTime.min)
		return testTime
	end
end

function isTriggerByMinute(m, testTime)
	local time = getNow(testTime)
	return (time.min/m == math.floor(time.min/m))
end

function isTriggerByHour(h, testTime)
	local time = getNow(testTime)
	return (time.hour/h == math.floor(time.hour/h) and time.min==0)
end

function isTriggerByTime(t, testTime)
	local tm, th
	local time = getNow(testTime)

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
			print('wrong time format')
			return false
		end

	else
		print ('Wrong time format, should be hh:mm')
		return false
	end
end

function getDayOfWeek(testTime)
	local d
	if (testTime~=nil) then
		d = testTime.day
	else
		d = os.date('*t').wday
	end

	local lookup = {'sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat' }
	print('Current day .. ' .. lookup[d])
	return lookup[d]
end

function evalTimeTrigger(t, testTime)
	if (testTime) then print(t) end
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
	if (days~=nil and string.find(days, getDayOfWeek(testTime)) == nil) then
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
		return isTriggerByMinute(1, testTime)
	end

	if (t == 'every other minute') then
		return isTriggerByMinute(2, testTime)
	end

	if (t == 'every hour') then
		return isTriggerByHour(1, testTime)
	end

	if (t == 'every other hour') then
		return isTriggerByHour(2, testTime)
	end

	-- others

	if (words[1] == 'every') then

		if (words[3] == 'minutes') then
			m = tonumber(words[2])
			if (m ~= nil) then
				return isTriggerByMinute(m, testTime)
			else
				print (t .. ' is not a valid timer definition')
			end
		elseif (words[3] == 'hours') then
			h = tonumber(words[2])
			if (h ~= nil) then
				return isTriggerByHour(h, testTime)
			else
				print (t .. ' is not a valid timer definition')
			end
		end
	elseif (words[1] == 'at' or words[1] == 'at:') then
		-- expect a time stamp
		local time = words[2]
		return isTriggerByTime(time, testTime)
	end
end

-- accepts a table of timeDefs, if one of them matches with the
-- current time, then it returns true
-- otherwise it returns false
function checkTimeDefs(timeDefs, testTime)
	for i, timeDef in pairs(timeDefs) do
		if (evalTimeTrigger(timeDef, testTime)) then
			return true
		end
	end
	return false
end

return {
	callEventHandler = callEventHandler,
	getIndex = getIndex,
	handleEvents = handleEvents,
	getEventBindings = getEventBindings,
	getTimerHandlers = getTimerHandlers,
	dumpCommandArray = dumpCommandArray,
	length = length,
	evalTimeTrigger=evalTimeTrigger,
	checkTimeDefs = checkTimeDefs
}
