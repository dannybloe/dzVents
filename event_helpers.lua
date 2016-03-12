-- Created by: Danny Bloemendaal, danny@bloemeland.nl
-- Version 0.9.9

-- make sure we can find our modules
local SCRIPTFOLDER = 'scripts'
local scriptPath = debug.getinfo(1).source:match("@?(.*/)")
package.path    = package.path .. ';' .. scriptPath .. '?.lua'
package.path    = package.path .. ';' .. scriptPath .. SCRIPTFOLDER .. '/?.lua'

local MAIN_METHOD = 'execute'

-- global log function

LOG_INFO = 2
LOG_DEBUG = 3
LOG_ERROR = 1

function log(msg, level)
	if (level == nil) then level = LOG_INFO end
	if (logLevel == level) then
		print(msg)
	end
end

local function callEventHandler(eventHandler, device, domoticz)
	if (eventHandler[MAIN_METHOD] ~= nil) then
		local ok2, res = pcall(eventHandler[MAIN_METHOD], device, domoticz)
		if (ok2) then
			return res
		else
			log('An error occured when calling event handler ' .. eventHandler.name, LOG_ERROR)
			log(res, LOG_ERROR) -- error info
		end
	else
		log('No' .. MAIN_METHOD .. 'function found in event handler ' .. eventHandler, LOG_ERROR)
	end
	return {}
end


local function reverseFind(s, target)
	-- string: 'this long string is a long string'
	-- string.findReverse('long') > 23, 26

	local reversed = string.reverse(s)
	local rTarget = string.reverse(target)
	-- reversed: gnirts gnol a si gnirts gnol siht
	-- rTarget = gnol

	local from, to = string.find(reversed, rTarget)
	if (from~=nil) then
		local targetPos = string.len(s) - to
		return targetPos, targetPos + string.len(target)
	else
		return nil, nil
	end
end

local function getDeviceNameByEvent(event)
	local pos, len = reverseFind(event, '_')
	local name = event
	if (pos ~= nil and pos > 1) then -- cannot start with _ (we use that for our _always script)
		name = string.sub(event, 1, pos)
	end
	return name
end

local function scandir(directory)
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
			log('Found module in ' .. SCRIPTFOLDER .. ' folder: ' .. t[i], LOG_DEBUG)
		end

	end
	pfile:close()
	return t
end

local function getNow(testTime)
	if (testTime==nil) then
		local timenow = os.date("*t")
		return timenow
	else
		log('h=' .. testTime.hour .. ' m=' .. testTime.min)
		return testTime
	end
end

local function isTriggerByMinute(m, testTime)
	local time = getNow(testTime)
	return (time.min/m == math.floor(time.min/m))
end

local function isTriggerByHour(h, testTime)
	local time = getNow(testTime)
	return (time.hour/h == math.floor(time.hour/h) and time.min==0)
end

local function isTriggerByTime(t, testTime)
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
			log('wrong time format', LOG_ERROR)
			return false
		end

	else
		log('Wrong time format, should be hh:mm ' .. tostring(t), LOG_DEBUG)
		return false
	end
end


local function evalTimeTrigger(t, testTime)
	if (testTime) then log(t) end

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
				log(t .. ' is not a valid timer definition', LOG_ERROR)
			end
		elseif (words[3] == 'hours') then
			h = tonumber(words[2])
			if (h ~= nil) then
				return isTriggerByHour(h, testTime)
			else
				log(t .. ' is not a valid timer definition', LOG_ERROR)
			end
		end
	elseif (words[1] == 'at' or words[1] == 'at:') then
		-- expect a time stamp
		local time = words[2]
		return isTriggerByTime(time, testTime)
	end
end

local function handleEvents(events, domoticz, device)
	local commands

	if (type(events) ~= 'table') then
		return commandArray
	end

	for eventIdx, eventHandler in pairs(events) do
		log('=====================================================', LOG_INFO)
		log('>>> Handler: ' .. eventHandler.name , LOG_INFO)
		if (device) then
			log('>>> Device: "' .. device.name .. '" Index: ' .. tostring(device.id), LOG_INFO)
		end

		log('.....................................................', LOG_INFO)

		callEventHandler(eventHandler, domoticz, device)

		log('.....................................................', LOG_INFO)
		log('<<< Done ', LOG_INFO)
		log('-----------------------------------------------------', LOG_INFO)
	end
end

local function getEventBindings(domoticz, mode)
	local bindings = {}
	local ok, modules, moduleName, i, event, j, device
	ok, modules = pcall( scandir, scriptPath .. '/' .. SCRIPTFOLDER)
	if (not ok) then
		log(modules, LOG_ERROR)
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
						active = module.active(domoticz)
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
						log('Script ' .. moduleName .. '.lua has no "on" and/or "' .. MAIN_METHOD .. '" section. Skipping', LOG_ERROR)
					end
				end
			else
				log('Script ' .. moduleName .. '.lua is not a valid module. Skipping', LOG_ERROR)
			end
		else
			log(module, LOG_ERROR)
		end
	end

	return bindings
end

local function getTimerHandlers(domoticz)
	return getEventBindings(domoticz, 'timer')
end

local function getDevicesPath()
	return debug.getinfo(1).source:match("@?(.*/)") .. 'devices.lua'
end

local function requestDomoticzData(ip, port)

	function getSed(target, replacement)
		return "sed 's/" .. target .. "/" .. replacement .. "/'"
	end

	-- create a bunch of commands that will convert
	-- the json returned from Domoticz into a lua table
	-- of course you can use json parsers but that either
	-- requires installing packages or takes a lot
	-- of lua processing power since the json can be huge
	-- the call is detached from the Domoticz process to it more or less
	-- runs in its own process, not blocking execution of Domoticz
	local sed1 = getSed("],", "},")
	local sed2 = getSed('   "', '   ["')
	local sed3 = getSed('         "','         ["')
	local sed4 = getSed('" :', '"]=')
	local sed5 = getSed(': \\[', ': {')
	local sed6 = getSed('= \\[', '= {')
	local filePath = getDevicesPath()
	local cmd = "{ echo 'return ' ; curl 'http://" ..
			ip .. ":" .. port ..
			"/json.htm?type=devices&displayhidden=1&filter=all&used=true' -s " ..
			"; } " ..
			" | " .. sed1 ..
			" | " .. sed2 ..
			" | " .. sed3 ..
			" | " .. sed4 ..
			" | " .. sed5 ..
			" | " .. sed6 .. " > " .. filePath .. " 2>/dev/null &"

	-- this will create a lua-requirable file with fetched data
	log('Fetching Domoticz data: ' .. cmd, LOG_DEBUG)
	os.execute(cmd)

end

local function fileExists(name)
	local f=io.open(name,"r")
	if f~=nil then
		io.close(f)
		return true
	else
		return false
	end
end


local function fetchHttpDomoticzData(ip, port, interval)

	local sep = string.sub(package.config,1,1)
	if (sep ~= '/') then return end -- only on linux

	if (ip == nil or port == nil) then
		log('Invalid ip for contacting Domoticz', LOG_ERROR)
		return
	end

	if (evalTimeTrigger(interval)) then
		requestDomoticzData(ip, port)
	end

end

local function dumpCommandArray(commandArray)
	local printed = false
	for k,v in pairs(commandArray) do
		if (type(v)=='table') then
			for kk,vv in pairs(v) do
				log('[' .. k .. '] = ' .. kk .. ': ' .. vv, LOG_INFO)
			end
		else
			log(k .. ': ' .. v, LOG_INFO)
		end
		printed = true
	end
	if(printed) then log('=====================================================', LOG_INFO) end
end

local function getDayOfWeek(testTime)
	local d
	if (testTime~=nil) then
		d = testTime.day
	else
		d = os.date('*t').wday
	end

	local lookup = {'sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat' }
	log('Current day .. ' .. lookup[d], LOG_DEBUG)
	return lookup[d]
end


-- accepts a table of timeDefs, if one of them matches with the
-- current time, then it returns true
-- otherwise it returns false
local function checkTimeDefs(timeDefs, testTime)
	for i, timeDef in pairs(timeDefs) do
		if (evalTimeTrigger(timeDef, testTime)) then
			return true
		end
	end
	return false
end

return {
	handleEvents = handleEvents,
	getEventBindings = getEventBindings,
	getTimerHandlers = getTimerHandlers,
	dumpCommandArray = dumpCommandArray,
	evalTimeTrigger = evalTimeTrigger,
	reverseFind = reverseFind,
	fetchHttpDomoticzData = fetchHttpDomoticzData,
	requestDomoticzData = requestDomoticzData,
	fileExists = fileExists
}
