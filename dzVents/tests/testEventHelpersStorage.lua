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
		local context = helpers.getStorageContext(script_data, LOCAL)

		assert.is_same({'a','b','c', 'g'}, keys(context))
		assert.is_same('', context.a)
		assert.is_same(1, context.b)
		assert.is_same({x=1, y=2}, context.c)
		assert.is_same(666, context.g)
	end)

	it('should write a storage context', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]
		local context = helpers.getStorageContext(script_data, LOCAL)

		context['a'] = 'a new value'
		context['b'] = 100
		context['c'] = {x=12, y=23 }
		context['g'] = 22
		context['d'] = 'should not be stored'

		helpers.writeStorageContext(script_data, context, LOCAL)

		local exists = utils.fileExists(script_data.dataFilePath)

		assert.is_true(exists)
		-- check if it was properly stored

		local newContext = helpers.getStorageContext(script_data, LOCAL)
		assert.is_same({'a','b','c', 'g'}, keys(newContext))
		assert.is_same('a new value', newContext.a)
		assert.is_same(100, newContext.b)
		assert.is_same({x=12, y=23}, newContext.c)
		assert.is_same(22, newContext.g)
	end)

	it('should write local storage inside the script', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]

		local res = helpers.callEventHandler(script_data,{name = 'somedevice'})

		-- should pass the arguments to the execute function
		-- and catch the results from the function
		local newContext = helpers.getStorageContext(script_data, LOCAL)

		assert.is_same({'a','b','c', 'g'}, keys(newContext))
		assert.is_same('this is set from script', newContext.a)
		assert.is_same(245, newContext.b)
		assert.is_same(87, newContext.g)
		assert.is_same({x=10, y=20}, newContext.c)

	end)

	it('should have a default global context', function()
		local bindings = helpers.getEventBindings()
		local script_data = bindings['somedevice'][1]
		local context = helpers.getStorageContext(script_data, GLOBAL)

		assert.is_same({'g','h'}, keys(context))
		assert.is_same(666, context.g)
		assert.is_same(true, context.h)
	end)

	it('should write a global storage context', function()
		local bindings = helpers.getEventBindings()
		local context = helpers.getStorageContext(nil, GLOBAL)

		context['g'] = 777
		context['h'] = false
		context['d'] = 'should not be stored'

		helpers.writeStorageContext(nil, context, GLOBAL)

		local exists = utils.fileExists('../tests/scripts/storage/__data_global_data.lua')

		assert.is_true(exists)
		-- check if it was properly stored

		local newContext = helpers.getStorageContext(nil, GLOBAL)
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
		local localContext = helpers.getStorageContext(script_data, LOCAL)
		local globalContext = helpers.getStorageContext(nil, GLOBAL)

		assert.is_same({'a','b','c', 'g'}, keys(localContext))
		assert.is_same('this is set from script', localContext.a)
		assert.is_same(245, localContext.b)
		assert.is_same(87, localContext.g)
		assert.is_same({x=10, y=20}, localContext.c)

		assert.is_same({'g', 'h'}, keys(globalContext))
		assert.is_same(999, globalContext.g)
		assert.is_same(false, globalContext.h)
	end)

	describe('#onlyHistorical storage', function()
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
			assert.is_same(10, hs.newValue)
		end)

		it('should return the new value', function()
			local hs = HS(data)
			hs.setNew(10)
			assert.is_same(10, hs.getNew())
		end)

		it('should return a stored value', function()
			local hs = HS(data)
			local value, time = hs.getPrevious(1)
			assert.is_same(data[1].time, time.raw)
			assert.is_same(data[1].value, value)

			value, time = hs.getPrevious(4)
			assert.is_same(data[4].time, time.raw)
			assert.is_same(data[4].value, value)

		end)

		it('should get the latest', function()
			local hs = HS(data)
			local value, time = hs.getLatest()
			assert.is_same(data[1].time, time.raw)
			assert.is_same(data[1].value, value)
		end)

		it('should get the oldest', function()
			local hs = HS(data)
			local value, time = hs.getOldest()

			assert.is_same(data[10].time, time.raw)
			assert.is_same(data[10].value, value)
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
		end)

		it('should return some more subsets', function()
			local hs = HS(data)

			assert.is_same(hs.storage, hs.subset(nil,nil, false))
			assert.is_nil(hs.subset(2,1, false))
			assert.is_nil(hs.subset(12,nil, false))
			assert.is_same(hs.storage, hs.subset(1,12, false))
		end)

		it('should return a subset by period', function()
			local hs = HS(data)
			local subset = hs.subsetPeriod(0, 2, false)
			assert.is_same({10,9,8}, _.pluck(subset, {'value'}))

			subset = hs.subsetPeriod(59, nil , false)
			assert.is_same({10}, _.pluck(subset, {'value'}))

			subset = hs.subsetPeriod(nil, 1000 , false)
			assert.is_same({10,9,8,7,6,5,4,3,2,1}, _.pluck(subset, {'value'}))

			subset = hs.subsetPeriod(nil, nil , false)
			assert.is_same({10}, _.pluck(subset, {'value'}))
		end)


		it('should return data for storage', function()
			local hs = HS(data)
			hs.setNew(11)
			-- oldest value is ditched, rest is shifted, new one is number 1 now
			local newData = hs._getForStorage()
			assert.is_same(11, newData[1].value)
			assert.is_same(10, _.size(newData))
			assert.is_same(2, newData[10].value)
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


		end)

		it('should have iterators: filter', function()
			local hs = HS(data)

			local res =	hs.filter(function(item)
				return ((item.value/2) == math.floor(item.value/2))
			end)

			local sum = 0
			res.forEach(function(item)
				sum = sum + item.value
			end)
			assert.is_same(10, sum) -- all even values added
		end)

		it('should have iterators: reduce', function()
			local hs = HS(data)

			local sum =	hs.reduce(function(acc, item)
				return acc + item.value
			end, 0)
			assert.is_same(55, sum)
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
		end)


		it('should return average over a time period', function()
			local hs = HS(data)
			local avg = hs.avgSince(0,2)
			assert.is_same(9, avg) -- 10,9,8
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
			local avg = hs.avgSince(0,2, 'bla')
			assert.is_same(9, avg) -- 10,9,8
		end)

		it('should return the minimum value of a range', function()
			data[5].value = -20
			local hs = HS(data)
			local min = hs.min()
			assert.is_same(-20,min)

			min = hs.min(1, 4)
			assert.is_same(7,min) -- 10,9,8,7

		end)

		it('should return the minimum value over a period', function()
			data[2].value = -20
			local hs = HS(data)
			local min = hs.minSince(0, 2) -- since 2 hours
			assert.is_same(-20,min)
		end)

		it('should return the maximum value of a range', function()
			data[5].value = 20
			local hs = HS(data)
			local min = hs.max()
			assert.is_same(20,min)

			min = hs.max(1, 4)
			assert.is_same(10,min) -- 10,9,8,7

		end)

		it('should return the maximum value over a period', function()
			data[2].value = 20
			local hs = HS(data)
			local min = hs.maxSince(0, 2) -- since 2 hours
			assert.is_same(20,min)
		end)
	end)

end)