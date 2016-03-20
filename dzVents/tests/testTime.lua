local _ = require 'lodash'

package.path = package.path .. ";../?.lua"

local LOG_INFO = 2
local LOG_DEBUG = 3
local LOG_ERROR = 1

describe('Time', function()
	local utils
	local t
	local raw, now, past

	setup(function()
		_G.logLevel = 1
		_G.log = function()	end
		Time = require('Time')
	end)

	teardown(function()
		Time = nil
	end)

	before_each(function()

		now = os.date('*t')
		local d = os.time(now) - 300   -- minus 5 minutes

		past = os.date('*t', d)
		raw = tostring(past.year) .. '-' ..
				tostring(past.month) .. '-' ..
				tostring(past.day) .. ' ' ..
				tostring(past.hour) .. ':' ..
				tostring(past.min) .. ':' ..
				tostring(past.sec)
		t = Time(raw)
	end)

	after_each(function()
		t = nil
	end)


	it('should instantiate', function()
		assert.not_is_nil(t)
	end)

	it('should have today', function()
		assert.is_same(t.current, now)
	end)

	it('should have minutesAgo', function()
		assert.is_same(5, t.minutesAgo)
	end)

	it('should have secondsAgo', function()
		assert.is_same(300, t.secondsAgo)
	end)

	it('should have a raw time', function()
		assert.is_same(raw, t.raw)
	end)

	it('should have isToday', function()
		assert.is_true(t.isToday)
	end)

	it('should have time properties', function()
		assert.is_same(past.year, t.year)
		assert.is_same(past.moth, t.mont)
		assert.is_same(past.day, t.day)
		assert.is_same(past.hour, t.hour)
		assert.is_same(past.min, t.min)
		assert.is_same(past.sec, t.sec)
	end)
end)
