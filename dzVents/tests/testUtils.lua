local _ = require 'lodash'

package.path = package.path .. ";../?.lua"

local LOG_INFO = 2
local LOG_DEBUG = 3
local LOG_ERROR = 1

describe('event helpers', function()
	local utils

	setup(function()
		_G.logLevel = 1

		utils = require('utils')

	end)

	teardown(function()
		utils = nil
	end)

	it('should return true if a file exists', function()
		assert.is_true(utils.fileExists('testfile'))
	end)

	it('should return false if a file does not exist', function()
		assert.is_false(utils.fileExists('blatestfile'))
	end)

	it('should return the devices.lua path', function()
		assert.is_same( '../devices.lua', utils.getDevicesPath())
	end)

	it('should fetch the http data', function()
		_G.log = function()

		end
		local cmd

		utils.osExecute = function(c)
			cmd = c
		end

		utils.requestDomoticzData('0.0.0.0', '8080')

		local expected = "{ echo 'return ' ; curl 'http://0.0.0.0:8080/json.htm?type=devices&displayhidden=1&filter=all&used=true' -s ; }  | sed 's/],/},/' | sed 's/   \"/   [\"/' | sed 's/         \"/         [\"/' | sed 's/\" :/\"]=/' | sed 's/: \\[/: {/' | sed 's/= \\[/= {/' > ../devices.lua 2>/dev/null &"

		assert.is_same(expected, cmd)
	end)

end)
