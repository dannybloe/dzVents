_G._ = require 'lodash'
local GLOBAL = false
local LOCAL = true
_G.TESMODE = true

package.path = package.path .. ";../?.lua"

local clock = os.clock
function sleep(n)  -- seconds
	local t0 = clock()
	while clock() - t0 <= n do end
end

local function keys(t)
	local keys = _.keys(t)
	return _.sortBy(keys, function(k)
		return tostring(k)
	end)
end

local function values(t)
	local values = _.values(t)
	table.sort(values)
	return values
end

describe('event helper storage', function()
	local EventHelpers, helpers, utils

	local domoticz = {
		['settings'] = {},
		['name'] = 'domoticz', -- used in script1
		['devices'] = {
			['device1'] = { name = '' },
			['onscript1'] = { name = 'onscript1', id = 1 },
			['onscript4'] = { name = 'onscript4', id = 4 },
			['on_script_5'] = { name = 'on_script_5', id = 5 },
			['wildcard'] = { name = 'wildcard', id = 6 },
			['someweirddevice'] = { name = 'someweirddevice', id = 7 },
			['mydevice'] = { name = 'mydevice', id = 8 }
		}
	}

	setup(function()
		local settings = {
			['Log level'] = 1
		}

		_G.TESTMODE = true

		EventHelpers = require('EventHelpers')
	end)

	teardown(function()
		helpers = nil
	end)

	before_each(function()
		helpers = EventHelpers(settings, domoticz)
		utils = helpers._getUtilsInstance()
		utils.print = function() end
		os.remove('../tests/scripts/storage/__data_script_data.lua')
		os.remove('../tests/scripts/storage/__data_global_data.lua')
	end)

	after_each(function()
		helpers = nil
		utils = nil
	end)


	it('should get a default local storage context', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]
		local context = helpers.getStorageContext(script_data.data, script_data.dataFileName)

		assert.is_same({'a','b','c','d','e','g'}, keys(context))
		assert.is_same('', context.a)
		assert.is_same(1, context.b)
		assert.is_same({x=1, y=2}, context.c)
		assert.is_same(666, context.g)
	end)

	it('should write a storage context', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]
		local context = helpers.getStorageContext(script_data.data, script_data.dataFileName)

		context['a'] = 'a new value'
		context['b'] = 100
		context['c'] = {x=12, y=23 }
		context['d'].setNew(100)
		context['e'].setNew(200)
		context['g'] = 22
		context['p'] = 'should not be stored'

		--helpers.writeStorageContext(script_data, context, LOCAL)
		helpers.writeStorageContext(
			script_data.data,
			script_data.dataFilePath,
			script_data.dataFileName,
			context)

		local exists = utils.fileExists(script_data.dataFilePath)

		assert.is_true(exists)
		-- check if it was properly stored

		local newContext = helpers.getStorageContext(script_data.data, script_data.dataFileName)
		assert.is_same({'a','b','c', 'd', 'e', 'g'}, keys(newContext))
		assert.is_same('a new value', newContext.a)
		assert.is_same(100, newContext.b)
		assert.is_same({x=12, y=23}, newContext.c)
		assert.is_same(100, newContext.d.getLatest())
		assert.is_same(200, newContext.e.getLatest())
		assert.is_same(22, newContext.g)
	end)

	it('should write local storage inside the script', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]

		local res = helpers.callEventHandler(script_data,{name = 'somedevice'})

		-- should pass the arguments to the execute function
		-- and catch the results from the function
		local newContext = helpers.getStorageContext(script_data.data, script_data.dataFileName)
		assert.is_same({'a','b','c','d','e','g'}, keys(newContext))
		assert.is_same('this is set from script', newContext.a)
		assert.is_same(245, newContext.b)
		assert.is_same(123, newContext.d.getLatest())
		assert.is_same(456, newContext.e.getLatest())
		assert.is_same(87, newContext.g)
		assert.is_same({x=10, y=20}, newContext.c)

	end)

	it('should have a default global context', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]
		local context = helpers.getStorageContext(helpers.globalsDefinition, '__data_global_data')

		assert.is_same({'g','h'}, keys(context))
		assert.is_same(666, context.g)
		assert.is_same(true, context.h)
	end)

	it('should write a global storage context', function()
		local bindings = helpers.getEventBindings()
		local context = helpers.getStorageContext(helpers.globalsDefinition, '__data_global_data')

		context['g'] = 777
		context['h'] = false
		context['d'] = 'should not be stored'

		helpers.writeStorageContext(
			helpers.globalsDefinition,
			helpers.scriptsFolderPath .. '/storage/__data_global_data.lua',
			helpers.scriptsFolderPath .. '/storage/__data_global_data',
			context)


		local exists = utils.fileExists('../tests/scripts/storage/__data_global_data.lua')

		assert.is_true(exists)
		-- check if it was properly stored

		local newContext = helpers.getStorageContext(helpers.globalsDefinition, '__data_global_data')
		assert.is_same({'g','h'}, keys(newContext))
		assert.is_same(777, newContext.g)
		assert.is_same(false, newContext.h)
		assert.is_nil(newContext.d)
	end)

	it('should write global storage after running script', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]

		local res = helpers.callEventHandler(script_data,{name = 'somedevice'})

		-- should pass the arguments to the execute function
		-- and catch the results from the function
		local localContext = helpers.getStorageContext(script_data.data,script_data.dataFileName)
		local globalContext = helpers.getStorageContext(helpers.globalsDefinition, '__data_global_data')

		assert.is_same({'a','b','c','d','e','g'}, keys(localContext))
		assert.is_same('this is set from script', localContext.a)
		assert.is_same(245, localContext.b)
		assert.is_same(87, localContext.g)
		assert.is_same({x=10, y=20}, localContext.c)

		assert.is_same({'g', 'h'}, keys(globalContext))
		assert.is_same(999, globalContext.g)
		assert.is_same(false, globalContext.h)
	end)

	describe('Historical storage', function()
		local HS = require('HistoricalStorage')
		local data = {}

		local function getTime(minHours)
			local past = os.date('!*t', os.time() - minHours * 3600)
			local raw = tostring(past.year) .. '-' ..
					tostring(past.month) .. '-' ..
					tostring(past.day) .. ' ' ..
					tostring(past.hour) .. ':' ..
					tostring(past.min) .. ':' ..
					tostring(past.sec)

			return raw
		end

		before_each(function()
			local i
			for i=0, 9 do
				table.insert(data, {
					time = getTime(i),
					value = (10-i)
				})
			end
		end)

		after_each(function()
			data = {}
		end)

		it('should instantiate with nothing', function()
			local hs = HS()
			assert.is_same(0, hs.size)
		end)

		it('should instantiate with data', function()
			local hs = HS(data)
			assert.is_same(10, hs.size)
		end)

		it('should respect max items', function()
			local hs = HS(data,2)
			assert.is_same(2, hs.size)
		end)

		it('should respect max hours', function()
			local hs = HS(data,nil, 3)
			assert.is_same(4, hs.size)
			assert.is_same(0, hs.storage[1].time.hoursAgo)
			assert.is_same(1, hs.storage[2].time.hoursAgo)
			assert.is_same(2, hs.storage[3].time.hoursAgo)
			assert.is_same(3, hs.storage[4].time.hoursAgo)
		end)

		it('should set a value', function()
			local hs = HS(data)
			hs.setNew(10)
			assert.is_same(10, hs.storage[1].value)

			-- empty
			hs = HS()
			hs.setNew(10)
			assert.is_same(10, hs.storage[1].value)
		end)

		it('should return the new value', function()
			local hs = HS(data)
			hs.setNew(10)
			assert.is_same(10, hs.getNew())

			-- empty
			hs = HS()
			hs.setNew(10)
			assert.is_same(10, hs.getNew())
		end)

		it('should return a stored value', function()
			local hs = HS(data)
			local value, time = hs.get(1)
			assert.is_same(data[1].time, time.raw)
			assert.is_same(data[1].value, value)

			value, time = hs.get(4)
			assert.is_same(data[4].time, time.raw)
			assert.is_same(data[4].value, value)

			-- empty
			hs = HS()
			value, time = hs.get(1)
			assert.is_nil(value)
			assert.is_nil(time)
		end)

		it('should get the latest', function()
			local hs = HS(data)
			local value, time = hs.getLatest()
			assert.is_same(data[1].time, time.raw)
			assert.is_same(data[1].value, value)

			-- empty
			hs = HS()
			value, time = hs.getLatest()
			assert.is_nil(value)
			assert.is_nil(time)
		end)

		it('should get the oldest', function()
			local hs = HS(data)
			local value, time = hs.getOldest()

			assert.is_same(data[10].time, time.raw)
			assert.is_same(data[10].value, value)

			-- empty
			hs = HS()
			value, time = hs.getOldest()
			assert.is_nil(value)
			assert.is_nil(time)
		end)

		it('should reset', function()
			local hs = HS(data)
			assert.is_same(10, hs.size)
			hs.reset()
			assert.is_same(0, hs.size)
			assert.is_nil(hs.getLatest())
		end)

		it('should return a subset', function()
			local hs = HS(data)
			local sub = hs.subset(2,4)
			local values = {}
			local count = sub.reduce(function(acc, s)
				acc = acc + 1
				return acc
			end, 0)

			sub.forEach(function(item)
				table.insert(values, item.value)
			end)

			assert.is_same(3, count)
			assert.is_same({9,8,7}, values)

			-- empty
			hs = HS()
			sub, length = hs.subset(2,4)
			assert.is_same(0, length)
		end)

		it('should return some more subsets', function()
			local hs = HS(data)

			assert.is_same(hs.storage, hs.subset(nil,nil, false))
			assert.is_same({}, hs.subset(2,1, false))
			assert.is_same({}, hs.subset(12,nil, false))
			assert.is_same(hs.storage, hs.subset(1,12, false))
		end)

		it('should return a subset since period ago', function()
			local hs = HS(data)
			local subset = hs.subsetSince(0, 0, 2, false)
			assert.is_same({10,9,8}, _.pluck(subset, {'value'}))

			subset = hs.subsetSince(60, 59, 0, false)
			assert.is_same({10,9}, _.pluck(subset, {'value'}))

			subset = hs.subsetSince(60, 59, 1, false)
			assert.is_same({10,9,8}, _.pluck(subset, {'value'}))

			subset = hs.subsetSince(0, 59, nil , false)
			assert.is_same({10}, _.pluck(subset, {'value'}))

			subset = hs.subsetSince(nil, nil, 1000 , false)
			assert.is_same({10,9,8,7,6,5,4,3,2,1}, _.pluck(subset, {'value'}))

			subset = hs.subsetSince(nil, nil, nil , false)
			assert.is_same({10}, _.pluck(subset, {'value'}))

			hs = HS()
			local subset, length = hs.subsetSince(nil,nil,nil,false)
			assert.is_same({}, subset)
			assert.is_same(0, length)
		end)

		it('should return data for storage', function()
			local hs = HS(data)
			hs.setNew(11)
			-- oldest value is ditched, rest is shifted, new one is number 1 now
			local newData = hs._getForStorage()
			assert.is_same(11, newData[1].value)
			assert.is_same(10, _.size(newData))
			assert.is_same(2, newData[10].value)

			hs = HS()
			assert.is_same({}, hs._getForStorage())
		end)

		it('should return all when no new value is set', function()
			local hs = HS(data)
			local newData = hs._getForStorage()
			assert.is_same(data, newData)
		end)

		it('should have iterators: forEach', function()
			local hs = HS(data)

			local sum = 0
			hs.forEach(function(item)
				sum = sum + item.value
			end)
			assert.is_same(55, sum)

			local hs = HS()
			local sum = 0
			hs.forEach(function(item)
				sum = sum + item.value
			end)
			assert.is_same(0, sum)
		end)

		it('should have iterators: filter', function()
			local hs = HS(data)

			local res =	hs.filter(function(item)
				return ((item.value/2) == math.floor(item.value/2)) -- even numbers
			end)

			local sum = 0
			res.forEach(function(item)
				sum = sum + item.value
			end)
			assert.is_same(10, sum) -- all even values added

			hs = HS()
			res =	hs.filter(function(item)
				return ((item.value/2) == math.floor(item.value/2))
			end)
			sum = 0
			res.forEach(function(item)
				sum = sum + item.value
			end)
			assert.is_same(0, sum)
		end)

		it('should have iterators: reduce', function()
			local hs = HS(data)

			local sum =	hs.reduce(function(acc, item)
				return acc + item.value
			end, 0)
			assert.is_same(55, sum)

			hs = HS()
			local sum =	hs.reduce(function(acc, item)
				return acc + item.value
			end, 0)
			assert.is_same(0, sum)

		end)

		it('should have iterators: find', function()
			local hs = HS(data)

			local item, index
			item, index = hs.find(function(item, i, collection)
				return (item.value == 5)
			end)
			assert.is_same(5, item.value)

			-- inverse
			item, index = hs.find(function(item, i, collection)
				return (item.value == 2)
			end, -1)
			assert.is_same(9, index)
			assert.is_same(2, item.value)

			-- should return nil when not found
			item, index = hs.find(function(item, i, collection)
				return (item.value == 554)
			end)

			assert.is_nil(index)
			assert.is_nil(item)

			hs = HS()
			item, index = hs.find(function(item, i, collection)
				return (item.value == 5)
			end)
			assert.is_nil(item)
		end)


		it('should have reduce a filtered set', function()
			local hs = HS(data)

			local res =	hs.filter(function(item)
				return ((item.value/2) == math.floor(item.value/2))
			end)

			local sum =	res.reduce(function(acc, item)
				return acc + item.value
			end, 0)
			assert.is_same(10, sum) -- all even values added
		end)

		it('should return the average', function()
			local hs = HS(data)
			assert.is_same(5.5, hs.avg(1,10))

			assert.is_same(10, hs.avg(1,1))
			assert.is_same(6, hs.avg(3,7))

			hs = HS()
			assert.is_same(nil, hs.avg(1,10))
		end)


		it('should return average over a time period', function()
			local hs = HS(data)
			local avg = hs.avgSince(0, 0, 2)
			assert.is_same(9, avg) -- 10,9,8

			hs = HS()
			assert.is_same(nil, hs.avgSince(1,10))
		end)

		it('should avg over an attribute', function()
			local data = {}
			local i
			for i=0, 9 do
				table.insert(data, {
					time = getTime(i),
					value = {['bla'] = (10-i)}
				})
			end

			local hs = HS(data)
			local avg = hs.avgSince(0,0,2, 'bla')
			assert.is_same(9, avg) -- 10,9,8
		end)

		it('should return the minimum value of a range', function()
			data[5].value = -20
			local hs = HS(data)
			local min = hs.min()
			assert.is_same(-20,min)

			min = hs.min(1, 4)
			assert.is_same(7,min) -- 10,9,8,7

			hs = HS()
			assert.is_nil(hs.min(1, 4))
		end)

		it('should return the minimum value over a period', function()
			data[4].value = -20
			local hs = HS(data)
			local min = hs.minSince(0, 0, 4) -- since 2 hours
			assert.is_same(-20,min)

			min = hs.minSince(0, 120, 0) -- since 3 hours
			assert.is_same(8,min)

			hs = HS()
			assert.is_nil(hs.minSince(1, 4))

		end)

		it('should return the maximum value of a range', function()
			data[5].value = 20
			local hs = HS(data)
			local min = hs.max()
			assert.is_same(20,min)

			min = hs.max(1, 4)
			assert.is_same(10,min) -- 10,9,8,7

			hs = HS()
			assert.is_nil(hs.max())
		end)

		it('should return the maximum value over a period', function()
			data[5].value = 20
			local hs = HS(data)
			local max = hs.maxSince(0, 60, 3)
			assert.is_same(20,max)

			hs = HS()
			assert.is_nil(hs.maxSince())
		end)

		it('should return the sum of a range', function()
			local hs = HS(data)
			local sum = hs.sum()
			assert.is_same(55,sum)

			sum = hs.sum(1, 4)
			assert.is_same(34,sum) -- 10,9,8,7
		end)

		it('should return the sum over a period', function()
			data[5].value = 20
			local hs = HS(data)
			local sum = hs.sumSince(0, 60, 3) -- since 2 hours
			assert.is_same(54,sum)

			hs = HS()
			assert.is_nil(hs.sumSince(1))
		end)

		it('should smooth an item with its neighbours', function()
			local hs = HS(data)
			local avged = hs.smoothItem(5, 3)
			assert.is_same(6, avged)

			avged = hs.smoothItem(2, 2)
			assert.is_same(8.5, avged)

			avged = hs.smoothItem(9, 2)
			assert.is_same(2.5, avged)

			avged = hs.smoothItem(1, 0)
			assert.is_same(10, avged)

			avged = hs.smoothItem(1000, 0)
			assert.is_nil(avged)

			avged = hs.smoothItem(1, 2)
			assert.is_same(9, avged)

			hs = HS()
			assert.is_nil(hs.smoothItem(1,1))
		end)

		it('should return the delta value', function()
			local hs = HS(data)
			hs.setNew(20)
			-- 20[1] 10[2], 9[3], 8[4], 7[5], 6[6], 5[7], 4[8], 3[9], 2[10] dropped: 1

			local nosmooth = hs.delta(1, 6)  -- 6 > 20 = 14
			assert.is_same(14, nosmooth)
			local smooth = hs.delta(1, 10, 2)  -- 3 > 13  = 10
			assert.is_same(10, smooth)

			smooth = hs.delta(2, 10, 2)  -- 3 > 13  = 10
			assert.is_same(8.75, smooth)

			hs = HS()
			assert.is_nil(hs.delta(1, 4))

		end)

		it('should return a delta value since a specifc time', function()
			local hs = HS(data)
			local smooth = hs.deltaSince(0,0,5,2)
			assert.is_same(4, smooth)

			smooth = hs.deltaSince(0, 0, 15, 2, nil, 22)
			-- beyond the limits, return default value (22)
			assert.is_same(22, smooth)
		end)

		it('should return an item at a specific time', function()
			local hs = HS(data)
			local item, index = hs.getAtTime(0, 2, 2)

			assert.is_same(3, index)
			assert.is_same(7200, item.time.secondsAgo)

			item, index = hs.getAtTime(0, 30, 2)
			assert.is_same(4, index)
			assert.is_same(10800, item.time.secondsAgo)

			item, index = hs.getAtTime(60, 89, 1)
			assert.is_same(4, index)
			assert.is_same(10800, item.time.secondsAgo)

			item, index = hs.getAtTime(-1, 0, 0)
			assert.is_same(1, index)
			assert.is_same(0, item.time.secondsAgo)

			item, index = hs.getAtTime(0, 0, 1200)
			assert.is_nil(index)
			assert.is_nil(item)

			hs = HS()
			assert.is_nil(hs.getAtTime(60, 89, 1))
		end)

	end)

end)