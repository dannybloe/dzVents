--require 'busted.runner'()

package.path = package.path .. ";../?.lua"

local LOG_INFO = 2
local LOG_DEBUG = 3
local LOG_ERROR = 1

describe("Logging", function()

	local helpers

	setup(function()
		_G._TEST = true
		helpers = require('event_helpers')
	end)

	teardown(function()
		_G._TEST = false
		helpers = nil
	end)

	-- tests to here
	it('shoud log INFO by default', function()
		_G.logLevel = LOG_INFO
		stub(_G, '_print')
		log('something')
		assert.stub(_G._print).was.called_with('something')
	end)

	it('shoud not log above level', function()
		_G.logLevel = LOG_INFO
		stub(_G, '_print')

		log('something', LOG_DEBUG)
		assert.stub(_G._print).was_not_called()

		_G.logLevel = LOG_ERROR
		log('error', LOG_INFO)
		assert.stub(_G._print).was_not_called()

		_G.logLevel = 0
		log('error', LOG_ERROR)
		assert.stub(_G._print).was_not_called()

	end)

end)


describe('File checking', function()
	local helpers

	setup(function()
		_G._TEST = true
		helpers = require('event_helpers')
	end)

	teardown(function()
		_G._TEST = false
		helpers = nil
	end)

	it('should return true if a file exists', function()
		assert.is_true(helpers.fileExists('testfile'))
	end)

	it('should return false if a file does not exist', function()
		assert.is_false(helpers.fileExists('blatestfile'))
	end)
end)

describe('Reverse find', function()
	local helpers

	setup(function()
		_G._TEST = true
		helpers = require('event_helpers')
	end)

	teardown(function()
		_G._TEST = false
		helpers = nil
	end)

	it('should find some string from behind', function()
		local s = 'my_Sensor_Temperature'
		local from, to = helpers.reverseFind(s, '_')
		assert.are_same(from, 10)
		assert.are_same(to, 10) -- lenght of _
	end)

	it('should find some string from behind (again)', function()
		local s = 'a_b'
		local from, to = helpers.reverseFind(s, 'b')
		assert.are_same(from, 3)
		assert.are_same(to, 3) -- lenght of _
	end)

	it('should find some string from behind (again)', function()
		local s = 'a_bbbb_c'
		local from, to = helpers.reverseFind(s, 'bb')
		assert.are_same(from, 5)
		assert.are_same(to, 6) -- lenght of _
	end)

	it('should return nil when not found', function()
		local s = 'mySensor_Temperature'
		local from, to = helpers.reverseFind(s, 'xx')
		assert.is_nil(from)
		assert.is_nil(to)
	end)
end)

describe('Device by event name', function()
	local helpers

	setup(function()
		_G._TEST = true
		helpers = require('event_helpers')
	end)

	teardown(function()
		_G._TEST = false
		helpers = nil
	end)

	it('should return the device name without value extension', function()
		local deviceName = helpers.getDeviceNameByEvent('mySensor')
		assert.are_same(deviceName, 'mySensor')

	end)

	it('should return the device name with a known value extension', function()
		local deviceName = helpers.getDeviceNameByEvent('mySensor_Temperature')
		assert.are_same('mySensor', deviceName)
	end)

	it('should return the device name with underscores and value extensions', function()
		local deviceName = helpers.getDeviceNameByEvent('my_Sensor_Temperature')
		assert.are_same('my_Sensor',  deviceName)
	end)

	it('should return the device name with underscores', function()
		local deviceName = helpers.getDeviceNameByEvent('my_Sensor_blaba')
		assert.are_same('my_Sensor_blaba', deviceName)
	end)

end)

describe('Loading modules', function()
	local helpers

	setup(function()
		_G._TEST = true
		helpers = require('event_helpers')
	end)

	teardown(function()
		_G._TEST = false
		helpers = nil
	end)

	it('should get a list of files in a folder', function()
		local files = helpers.scandir('scandir')
		local f = {'f1','f2','f3'}
		assert.are.same(f, files)
	end)
end)

describe('Evaluate time triggers', function()
	local helpers

	setup(function()
		_G._TEST = true
		helpers = require('event_helpers')
	end)

	teardown(function()
		_G._TEST = false
		helpers = nil
	end)

	it('should compare time triggers at the current time', function()
		assert.is_true(helpers.evalTimeTrigger('Every minute', {['hour']=13, ['min']=6}))

		assert.is_true(helpers.evalTimeTrigger('Every 2 minutes', {['hour']=13, ['min']=0}))
		assert.is_false(helpers.evalTimeTrigger('Every 2 minutes', {['hour']=13, ['min']=1}))

		assert.is_true(helpers.evalTimeTrigger('Every other minute', {['hour']=13, ['min']=0}))
		assert.is_false(helpers.evalTimeTrigger('Every other minute', {['hour']=13, ['min']=1}))

		assert.is_false(helpers.evalTimeTrigger('Every 5 minutes', {['hour']=13, ['min']=6}))

		assert.is_true(helpers.evalTimeTrigger('Every 10 minutes', {['hour']=13, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every 10 minutes', {['hour']=13, ['min']=10}))
		assert.is_true(helpers.evalTimeTrigger('Every 10 minutes', {['hour']=13, ['min']=20}))
		assert.is_true(helpers.evalTimeTrigger('Every 10 minutes', {['hour']=13, ['min']=30}))
		assert.is_true(helpers.evalTimeTrigger('Every 10 minutes', {['hour']=13, ['min']=40}))
		assert.is_true(helpers.evalTimeTrigger('Every 10 minutes', {['hour']=13, ['min']=50}))
		assert.is_false(helpers.evalTimeTrigger('Every 10 minutes', {['hour']=13, ['min']=11}))

		assert.is_true(helpers.evalTimeTrigger('Every 15 minutes', {['hour']=13, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every 15 minutes', {['hour']=13, ['min']=15}))
		assert.is_true(helpers.evalTimeTrigger('Every 15 minutes', {['hour']=13, ['min']=30}))
		assert.is_true(helpers.evalTimeTrigger('Every 15 minutes', {['hour']=13, ['min']=45}))
		assert.is_false(helpers.evalTimeTrigger('Every 15 minutes', {['hour']=13, ['min']=1}))

		assert.is_true(helpers.evalTimeTrigger('Every 20 minutes', {['hour']=13, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every 20 minutes', {['hour']=13, ['min']=20}))
		assert.is_true(helpers.evalTimeTrigger('Every 20 minutes', {['hour']=13, ['min']=40}))
		assert.is_false(helpers.evalTimeTrigger('Every 20 minutes', {['hour']=13, ['min']=2}))

		assert.is_true(helpers.evalTimeTrigger('Every 11 minutes', {['hour']=13, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every 11 minutes', {['hour']=13, ['min']=11}))
		assert.is_true(helpers.evalTimeTrigger('Every 11 minutes', {['hour']=13, ['min']=22}))

		assert.is_true(helpers.evalTimeTrigger('Every hour', {['hour']=13, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every hour', {['hour']=0, ['min']=0}))
		assert.is_false(helpers.evalTimeTrigger('Every hour', {['hour']=13, ['min']=1}))

		assert.is_true(helpers.evalTimeTrigger('Every other hour', {['hour']=0, ['min']=0}))
		assert.is_false(helpers.evalTimeTrigger('Every other hour', {['hour']=1, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every other hour', {['hour']=2, ['min']=0}))

		assert.is_true(helpers.evalTimeTrigger('Every 2 hours', {['hour']=0, ['min']=0}))
		assert.is_false(helpers.evalTimeTrigger('Every 2 hours', {['hour']=1, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every 2 hours', {['hour']=2, ['min']=0}))

		assert.is_true(helpers.evalTimeTrigger('Every 3 hours', {['hour']=0, ['min']=0}))
		assert.is_true(helpers.evalTimeTrigger('Every 3 hours', {['hour']=3, ['min']=0}))
		assert.is_false(helpers.evalTimeTrigger('Every 3 hours', {['hour']=2, ['min']=0}))

		assert.is_true(helpers.evalTimeTrigger('at 12:23', {['hour']=12, ['min']=23}))
		assert.is_false(helpers.evalTimeTrigger('at 12:23', {['hour']=13, ['min']=23}))
		assert.is_true(helpers.evalTimeTrigger('at 0:1', {['hour']=0, ['min']=1}))
		assert.is_true(helpers.evalTimeTrigger('at 0:01', {['hour']=0, ['min']=1}))
		assert.is_true(helpers.evalTimeTrigger('at 1:1', {['hour']=1, ['min']=1}))
		assert.is_true(helpers.evalTimeTrigger('at 10:10', {['hour']=10, ['min']=10}))


		assert.is_true(helpers.evalTimeTrigger('at *:10', {['hour']=10, ['min']=10}))
		assert.is_true(helpers.evalTimeTrigger('at *:10', {['hour']=11, ['min']=10}))
		assert.is_false(helpers.evalTimeTrigger('at *:10', {['hour']=11, ['min']=11}))
		assert.is_false(helpers.evalTimeTrigger('at *:*', {['hour']=11, ['min']=10}))
		assert.is_false(helpers.evalTimeTrigger('at 2:*', {['hour']=11, ['min']=10}))
		assert.is_true(helpers.evalTimeTrigger('at 2:*', {['hour']=2, ['min']=10}))

		assert.is_true(helpers.evalTimeTrigger('at 1:*', {['hour']=1, ['min']=11}))
		assert.is_true(helpers.evalTimeTrigger('at: 1:*', {['hour']=1, ['min']=11}))
		assert.is_false(helpers.evalTimeTrigger('at 1:*', {['hour']=2, ['min']=11}))
		assert.is_false(helpers.evalTimeTrigger('at *:3', {['hour']=2, ['min']=11}))
		assert.is_false(helpers.evalTimeTrigger('at *:5', {['hour']=2, ['min']=11}))
		assert.is_true(helpers.evalTimeTrigger('at *:5', {['hour']=2, ['min']=5}))

		assert.is_true(helpers.evalTimeTrigger('at *:5 on mon, tue, fri', {['hour']=2, ['min']=5, ['day']=6}))
		assert.is_false(helpers.evalTimeTrigger('at *:5 on sat', {['hour']=2, ['min']=5, ['day']=5}))

		assert.is_true(helpers.evalTimeTrigger('every other minute on mon, tue, fri', {['hour']=2, ['min']=4, ['day']=2}))
		assert.is_false(helpers.evalTimeTrigger('every other minute on mon, tue, fri', {['hour']=2, ['min']=4, ['day']=1}))

		assert.is_true(helpers.evalTimeTrigger('at sunset', {['hour']=1, ['min']=4, ['SunsetInMinutes']=64}))
		assert.is_false(helpers.evalTimeTrigger('at sunset', {['hour']=1, ['min']=4, ['SunsetInMinutes']=63}))

		assert.is_true(helpers.evalTimeTrigger('at sunrise', {['hour']=1, ['min']=4, ['SunriseInMinutes']=64}))
		assert.is_false(helpers.evalTimeTrigger('at sunrise', {['hour']=1, ['min']=4, ['SunriseInMinutes']=63}))

		assert.is_true(helpers.evalTimeTrigger('at sunrise on mon', {['hour']=1, ['min']=4, ['day']=2, ['SunriseInMinutes']=64}))
		assert.is_false(helpers.evalTimeTrigger('at sunrise on fri', {['hour']=1, ['min']=4, ['day']=2, ['SunriseInMinutes']=64}))
	end)

	it('should check time defs', function()
		assert.is_true(helpers.checkTimeDefs({ 'Every minute' }, {['hour']=13, ['min']=6}))
		assert.is_false(helpers.checkTimeDefs({ 'Every hour' }, {['hour']=13, ['min']=6}))
		assert.is_true(helpers.checkTimeDefs({ 'Every hour' }, {['hour']=13, ['min']=0}))

		assert.is_false(helpers.checkTimeDefs({ 'Every 2 minutes', 'every hour'}, {['hour']=13, ['min']=1}))
		assert.is_true(helpers.checkTimeDefs({ 'Every 2 minutes', 'every hour'}, {['hour']=13, ['min']=2}))

		assert.is_true(helpers.checkTimeDefs({ 'Every 5 minutes', 'every 3 minutes'}, {['hour']=13, ['min']=5}))
		assert.is_true(helpers.checkTimeDefs({ 'Every 5 minutes', 'every 3 minutes'}, {['hour']=13, ['min']=9}))
		assert.is_false(helpers.checkTimeDefs({ 'Every 5 minutes', 'every 3 minutes'}, {['hour']=13, ['min']=11}))

		assert.is_true(helpers.checkTimeDefs({ 'at *:3', 'at *:5', 'at 1:*'}, {['hour']=13, ['min']=5}))
		assert.is_true(helpers.checkTimeDefs({ 'at *:3', 'at *:5', 'at 1:*'}, {['hour']=13, ['min']=3}))

		assert.is_true(helpers.checkTimeDefs({ 'at *:3', 'at *:5', 'at 1:*'}, {['hour']=1, ['min']=11}))

		assert.is_false(helpers.checkTimeDefs({ 'at *:3', 'at *:5', 'at 1:*'}, {['hour']=2, ['min']=11}))
	end)

end)