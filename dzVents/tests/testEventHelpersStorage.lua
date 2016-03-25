_G._ = require 'lodash'
local GLOBAL = false
local LOCAL = true
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

describe('event helpers', function()
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


end)