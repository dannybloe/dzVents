local Time = require('Time')
local MAXLIMIT = 1000

if (_G.TESTMODE) then
	MAXLIMIT = 10
end

local function setIterators(object, collection)
	object['forEach'] = function(func)
		for i, item in ipairs(collection) do
			if (type(item) ~= 'function') then
				func(item, i)
			end
		end
	end

	object['reduce'] = function(func, accumulator)
		for i, item in ipairs(collection) do
			accumulator = func(accumulator, item, i)
		end
		return accumulator
	end

	object['filter'] = function(filter)
		local res = {}
		for i, item in ipairs(collection) do
			if (type(item) ~= 'function') then
				if (filter(item)) then
					res[i] = item
				end
			end
		end
		setIterators(res, res)
		return res
	end
end


local function HistoricalStorage(data, maxItems, maxHours)
	local newAdded = false
	if (maxItems == nil or maxItems > MAXLIMIT) then
		maxItems = MAXLIMIT
	end
	-- maybe we should make a limit anyhow in the number of items

	local self = {
		newValue = nil,
		storage = {} -- youngest first, oldest last
	}

	if (data == nil) then
		self.storage = {}
		self.size = 0
	else
		-- transfer to self
		-- that way we can easily prune or ditch based
		-- on maxItems and/or maxHours
		local now = os.date('*t')
		local count = 0
		for i, sample in ipairs(data) do
			local t = Time(sample.time)

			if (count < maxItems) then
				local add = true
				if (maxHours~=nil and t.hoursAgo>maxHours) then
					add = false
				end
				if (add) then
					table.insert(self.storage, { time = t, value = sample.value })
					count = count + 1
				end
			end
		end
		self.size = count
	end

	-- extend with filter and forEach
	setIterators(self, self.storage)

	function self.getSubSet(from, to)
		if (from < 1) then from = 1 end
		if (from > self.size) then return nil end
		if (to < from) then return nil end
		if (to > self.size) then to = self.size end

		local res = {}
		for i = from, to do
			table.insert(res, self.storage[i])
		end
		setIterators(res, res)
		return res
	end

	function self._getForStorage()
		local res = {}

		local to = self.size

		if (newAdded and self.size == MAXLIMIT) then
			-- drop the last item
			to = self.size - 1
		end

		for i = 1, to do
			table.insert(res, {
				time = self.storage[i].time.raw,
				value = self.storage[i].value
			})
		end

		-- add the new one if there's any at the start
		if (newAdded) then
			table.insert(res, 1, {
				time = os.date('%Y-%m-%d %H:%M:%S'),
				value = self.newValue
			})
		end
		return res
	end

	function self.setNew(value)
		self.newValue = value
		newAdded = true
	end

	function self.getNew(value)
		return self.newValue
	end

	function self.getPrevious(itemsAgo)
		local item = self.storage[itemsAgo]
		if (item == nil) then
			return nil
		else
			return item.value, item.time
		end
	end

	function self.getLatest()
		return self.getPrevious(1)
	end

	function self.getOldest()
		return self.getPrevious(self.size)
	end

	return self
end

return HistoricalStorage