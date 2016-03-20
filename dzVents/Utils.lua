local self = {}

function self.fileExists(name)
	local f=io.open(name,"r")
	if f~=nil then
		io.close(f)
		return true
	else
		return false
	end
end

function self.getDevicesPath()
	return debug.getinfo(1).source:match("@?(.*/)") .. 'devices.lua'
end

function self.osExecute(cmd)
	os.execute(cmd)
end

function self.getSed(target, replacement)
	return "sed 's/" .. target .. "/" .. replacement .. "/'"
end

function self.requestDomoticzData(ip, port)
	-- create a bunch of commands that will convert
	-- the json returned from Domoticz into a lua table
	-- of course you can use json parsers but that either
	-- requires installing packages or takes a lot
	-- of lua processing power since the json can be huge
	-- the call is detached from the Domoticz process to it more or less
	-- runs in its own process, not blocking execution of Domoticz
	local sed1 = self.getSed("],", "},")
	local sed2 = self.getSed('   "', '   ["')
	local sed3 = self.getSed('         "','         ["')
	local sed4 = self.getSed('" :', '"]=')
	local sed5 = self.getSed(': \\[', ': {')
	local sed6 = self.getSed('= \\[', '= {')
	local filePath = self.getDevicesPath()
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
	self.osExecute(cmd)
end

return self