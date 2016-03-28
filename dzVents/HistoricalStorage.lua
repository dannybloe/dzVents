local Time = require('Time')
local MAXLIMIT = 1000
local utils = require('Utils')

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
	-- IMPORTANT: data must be time-stamped in UTC format

	local newAdded = false
	if (maxItems == nil or maxItems > MAXLIMIT) then
		maxItems = MAXLIMIT
	end
	-- maybe we should make a limit anyhow in the number of items

	local self = {
		newValue = nil,
		storage = {} -- youngest first, oldest last
	}

	-- setup our internal list of history items
	-- already pruned to the bounds as set by maxItems and/or maxHours
	if (data == nil) then
		self.storage = {}
		self.size = 0
	else
		-- transfer to self
		-- that way we can easily prune or ditch based
		-- on maxItems and/or maxHours
		local count = 0
		for i, sample in ipairs(data) do
			local t = Time(sample.time, true) -- UTC

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

	function self.subset(from, to, _setIterators)
		if (from == nil or from < 1 ) then from = 1 end
		if (from and from > self.size) then return nil end
		if (to and from and to < from) then return nil end
		if (to==nil or to > self.size) then to = self.size end

		local res = {}
		for i = from, to do
			table.insert(res, self.storage[i])
		end
		if(_setIterators or _setIterators==nil) then
			setIterators(res, res)
		end
		return res
	end

	function self.subsetSince(minsAgo, hoursAgo, _setIterators)
		local totalMinsAgo
		local res = {}
		minsAgo = minsAgo~=nil and minsAgo or 0
		hoursAgo = hoursAgo~=nil and hoursAgo or 0

		totalMinsAgo = hoursAgo*60 + minsAgo

		for i = 1, self.size do
			if (self.storage[i].time.minutesAgo<=totalMinsAgo) then
				table.insert(res, self.storage[i])
			end
		end

		if(_setIterators or _setIterators==nil) then
			setIterators(res, res)
		end
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
				-- create a UTC time stamp
				time = os.date('!%Y-%m-%d %H:%M:%S'),
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

	function self.get(itemsAgo)
		local item = self.storage[itemsAgo]
		if (item == nil) then
			return nil
		else
			return item.value, item.time
		end
	end

	function self.getLatest()
		return self.get(1)
	end

	function self.getOldest()
		return self.get(self.size)
	end

	local function _getItemValue(item, attribute)
		local val
		if (attribute) then
			if (item.value[attribute] == nil) then
				utils.log('There is no attribute "' .. attribute .. '"', utils.LOG_ERROR)
			else
				val = tonumber(item.value[attribute])
			end
		else
			val = tonumber(item.value)
		end
		return val
	end

	local function _sum(items, attribute)
		local count = 0
		local sum = items.reduce(function(acc, item)
			local val = _getItemValue(item, attribute)
			count = count + 1

			return acc + val
		end, 0)
		return sum, count
	end

	local function _avg(items, attribute)
		if (items == nil) then return nil end

		local sum, count = _sum(items, attribute)
		return sum/count
	end

	function self.avg(from, to, attribute)
		local subset = self.subset(from, to)
		return _avg(subset, attribute)
	end

	function self.avgSince(minsAgo, hoursAgo, attribute)
		local subset = self.subsetSince(minsAgo, hoursAgo, attribute)
		return _avg(subset, attribute)
	end

	local function _min(items, attribute)
		if (items == nil) then return nil end

		local min = items.reduce(function(acc, item)
			local val = _getItemValue(item, attribute)
			if (acc == nil) then
				acc = val
			else
				if (val < acc) then
					acc = val
				end
			end

			return acc
		end, nil)
		return min
	end

	function self.min(from, to, attribute)
		local subset = self.subset(from, to)
		return _min(subset, attribute)
	end

	function self.minSince(minsAgo, hoursAgo, attribute)
		local subset = self.subsetSince(minsAgo, hoursAgo, attribute)
		return _min(subset, attribute)
	end

	local function _max(items, attribute)
		if (items == nil) then return nil end

		local max = items.reduce(function(acc, item)
			local val = _getItemValue(item, attribute)
			if (acc == nil) then
				acc = val
			else
				if (val > acc) then
					acc = val
				end
			end

			return acc
		end, nil)
		return max
	end

	function self.max(from, to, attribute)
		local subset = self.subset(from, to)
		return _max(subset, attribute)
	end

	function self.maxSince(minsAgo, hoursAgo, attribute)
		local subset = self.subsetSince(minsAgo, hoursAgo, attribute)
		return _max(subset, attribute)
	end

	function self.sum(from, to, attribute)
		local subset = self.subset(from, to)
		return _sum(subset, attribute)
	end

	function self.sumSince(minsAgo, hoursAgo, attribute)
		local subset = self.subsetSince(minsAgo, hoursAgo, attribute)
		return _sum(subset, attribute)
	end

	function self.smoothItem(itemIndex, variance, attribute)
		if (itemIndex<1 or itemIndex > self.size) then
			return nil
		end

		if (variance < 0) then variance = 0 end

		local from, to
		if ((itemIndex - variance)< 1) then
			from = 1
		else
			from = itemIndex - variance
		end

		if ((itemIndex + variance) > self.size) then
			to = self.size
		else
			to = itemIndex + variance
		end
		local avg = self.avg(from, to, attribute)
		return avg
	end

	function self.delta(referenceValue, itemIndex, variance, attribute)
		local value, item
		if (variance ~= nil) then
			value = self.smoothItem(itemIndex, variance, attribute)
		else
			value = _getItemValue(self.storage[itemIndex], attribute)
		end
		return tonumber(referenceValue - value)
	end

	return self
end

return HistoricalStorage