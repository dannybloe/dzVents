local _ = require 'lodash'

package.path = package.path .. ";../?.lua"

local LOG_INFO = 2
local LOG_DEBUG = 3
local LOG_ERROR = 1

describe('Domoticz', function()
	local Domoticz, domoticz, settings

	setup(function()
		_G.logLevel = 1
		_G.log = function()	end
		_G.TESTMODE = true

		_G.globalvariables = {}
		_G.timeofday = {
			Daytime = 'dt',
			Nighttime = 'nt',
			SunriseInMinutes = 'sunrisemin',
			SunsetInMinutes = 'sunsetmin'
		}

		_G.globalvariables = {
			Security = 'sec'
		}
		_G.devicechanged = {}
		_G.otherdevices = {}
		_G.otherdevices_temperature = {}
		_G.otherdevices_dewpoint = {}
		_G.otherdevices_humidity = {}
		_G.otherdevices_barometer = {}
		_G.otherdevices_utility = {}
		_G.otherdevices_weather = {}
		_G.otherdevices_rain = {}
		_G.otherdevices_rain_lasthour = {}
		_G.otherdevices_uv = {}
		_G.otherdevices_lastupdate = {}
		_G.otherdevices_idx = {}
		_G.uservariables = {}

		_G['uservariables_lastupdate'] = {
			['myVar'] = '2016-03-20 12:23:00'
		}

		settings = {
			['Domoticz ip'] = '10.0.0.8',
			['Domoticz port'] = '8080',
			['Fetch interval'] = 'every 30 minutes',
			['Enable http fetch'] = true,
			['Log level'] = 2
		}

		Domoticz = require('Domoticz')


	end)

	teardown(function()
		Domoticz = nil
		domoticz = nil
	end)

	before_each(function()
		domoticz = Domoticz(settings)
	end)

	after_each(function()
		domoticz = nil
	end)

	it('should instantiate', function()
		assert.is_not_nil(domoticz)
	end)

	describe('properties', function()
		it('should have time properties', function()
			assert.is_same(domoticz.time.isDayTime, 'dt')
			assert.is_same(domoticz.time.isNightTime, 'nt')
			assert.is_same(domoticz.time.sunriseInMinutes, 'sunrisemin')
			assert.is_same(domoticz.time.sunsetInMinutes, 'sunsetmin')
		end)

		it('should have settings', function()
			assert.is_equal(domoticz.settings, settings)
		end)

		it('should have security info', function()
			assert.is_same('sec', domoticz.security)
		end)

		it('should have priority constants', function()
			assert.is_same(domoticz['PRIORITY_LOW'], -2)
			assert.is_same(domoticz['PRIORITY_MODERATE'], -1)
			assert.is_same(domoticz['PRIORITY_NORMAL'], 0)
			assert.is_same(domoticz['PRIORITY_HIGH'], 1)
			assert.is_same(domoticz['PRIORITY_EMERGENCY'], 2)
		end)

		it('should have sound constants', function()
			assert.is_same(domoticz['SOUND_DEFAULT'], 'pushover')
			assert.is_same(domoticz['SOUND_BIKE'], 'bike')
			assert.is_same(domoticz['SOUND_BUGLE'], 'bugle')
			assert.is_same(domoticz['SOUND_CASH_REGISTER'], 'cashregister')
			assert.is_same(domoticz['SOUND_CLASSICAL'], 'classical')
			assert.is_same(domoticz['SOUND_COSMIC'], 'cosmic')
			assert.is_same(domoticz['SOUND_FALLING'], 'falling')
			assert.is_same(domoticz['SOUND_GAMELAN'], 'gamelan')
			assert.is_same(domoticz['SOUND_INCOMING'], 'incoming')
			assert.is_same(domoticz['SOUND_INTERMISSION'], 'intermission')
			assert.is_same(domoticz['SOUND_MAGIC'], 'magic')
			assert.is_same(domoticz['SOUND_MECHANICAL'], 'mechanical')
			assert.is_same(domoticz['SOUND_PIANOBAR'], 'pianobar')
			assert.is_same(domoticz['SOUND_SIREN'], 'siren')
			assert.is_same(domoticz['SOUND_SPACEALARM'], 'spacealarm')
			assert.is_same(domoticz['SOUND_TUGBOAT'], 'tugboat')
			assert.is_same(domoticz['SOUND_ALIEN'], 'alien')
			assert.is_same(domoticz['SOUND_CLIMB'], 'climb')
			assert.is_same(domoticz['SOUND_PERSISTENT'], 'persistent')
			assert.is_same(domoticz['SOUND_ECHO'], 'echo')
			assert.is_same(domoticz['SOUND_UPDOWN'], 'updown')
			assert.is_same(domoticz['SOUND_NONE'], 'none')
		end)

		it('should have humidity constants', function()
			assert.is_same(domoticz['HUM_NORMAL'], 0)
			assert.is_same(domoticz['HUM_COMFORTABLE'], 1)
			assert.is_same(domoticz['HUM_DRY'], 2)
			assert.is_same(domoticz['HUM_WET'], 3)
		end)

		it('should have barometer constants', function()
			assert.is_same(domoticz['BARO_STABLE'], 0)
			assert.is_same(domoticz['BARO_SUNNY'], 1)
			assert.is_same(domoticz['BARO_CLOUDY'], 2)
			assert.is_same(domoticz['BARO_UNSTABLE'], 3)
			assert.is_same(domoticz['BARO_THUNDERSTORM'], 4)
			assert.is_same(domoticz['BARO_UNKNOWN'], 5)
			assert.is_same(domoticz['BARO_CLOUDY_RAIN'], 6)
		end)

		it('should have alert level constants', function()
			assert.is_same(domoticz['ALERTLEVEL_GREY'], 0)
			assert.is_same(domoticz['ALERTLEVEL_GREEN'], 1)
			assert.is_same(domoticz['ALERTLEVEL_YELLOW'], 2)
			assert.is_same(domoticz['ALERTLEVEL_ORANGE'], 3)
			assert.is_same(domoticz['ALERTLEVEL_RED'], 4)
		end)

		it('should have security constants', function()
			assert.is_same(domoticz['SECURITY_DISARMED'], 'Disarmed')
			assert.is_same(domoticz['SECURITY_ARMEDAWAY'], 'Armed Away')
			assert.is_same(domoticz['SECURITY_ARMEDHOME'], 'Armed Home')
		end)

		it('should have log constants', function()
			assert.is_same(domoticz['LOG_INFO'], 2)
			assert.is_same(domoticz['LOG_DEBUG'], 3)
			assert.is_same(domoticz['LOG_ERROR'], 1)
		end)
	end)

	describe('commands', function()
		it('should send commands', function()
			local res, command, value = domoticz.sendCommand('do', 'it')
			assert.is_same('do', command)
			assert.is_same('it', value)
			assert.is_same({['do'] = 'it' }, res)
		end)

		it('should send multiple commands', function()
			domoticz.sendCommand('do', 'it')
			domoticz.sendCommand('and', 'some more')
			assert.is_same({{["do"]="it"}, {["and"]="some more"}}, domoticz.commandArray)
		end)

		it('should return a reference to a commandArray item', function()
			local res = domoticz.sendCommand('do', 'it')
			domoticz.sendCommand('and', 'some more')
			-- now change it
			res['do'] = 'cancel it'
			assert.is_same({{["do"]="cancel it"}, {["and"]="some more"}}, domoticz.commandArray)
		end)

		it('should notify', function()
			domoticz.notify('sub', 'mes', 1, 'noise')
			assert.is_same({{['SendNotification'] = 'sub#mes#1#noise'}}, domoticz.commandArray)
		end)

		it('should notify with defaults', function()
			domoticz.notify('sub')
			assert.is_same({{['SendNotification'] = 'sub##0#pushover'}}, domoticz.commandArray)
		end)

		it('should send email', function()
			domoticz.email('sub', 'mes', 'to@someone')
			assert.is_same({{['SendEmail'] = 'sub#mes#to@someone'}}, domoticz.commandArray)
		end)

		it('should send sms', function()
			domoticz.sms('mes')
			assert.is_same({{['SendSMS'] = 'mes'}}, domoticz.commandArray)
		end)

		it('should open a url', function()
			domoticz.openURL('some url')
			assert.is_same({{['OpenURL'] = 'some url'}}, domoticz.commandArray)
		end)

		it('should set a scene', function()
			local res = domoticz.setScene('scene1', 'on')
			assert.is_table(res)
			assert.is_same({{['Scene:scene1'] = 'on' }}, domoticz.commandArray)
		end)

		it('should switch a group', function()
			local res = domoticz.switchGroup('group1', 'on')
			assert.is_table(res)
			assert.is_same({{['Group:group1'] = 'on' }}, domoticz.commandArray)
		end)



	end)

	it('should fetch http data from domoticz', function()
		local utils = domoticz._getUtilsInstance()
		local ip, port
		utils.requestDomoticzData = function(i, p)
			ip = i
			port = p
		end
		domoticz.fetchHttpDomoticzData()
		assert.is_same(settings['Domoticz ip'], ip)
		assert.is_same(settings['Domoticz port'], port)
	end)

	it('should log', function()
		local logged = false
		_G.log = function()
			logged = true
		end
		domoticz.log('boeh', 1)
		assert.is_true(logged)
	end)
end)
