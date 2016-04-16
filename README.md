<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of contents**

- [About](#about)
- [Installing](#installing)
  - [Quickstart](#quickstart)
- [How does it to work?](#how-does-it-to-work)
  - [Adapting or creating your scripts](#adapting-or-creating-your-scripts)
  - [*timer* trigger options](#timer-trigger-options)
- [The domoticz object](#the-domoticz-object)
  - [Domoticz object API](#domoticz-object-api)
    - [Domoticz attributes:](#domoticz-attributes)
    - [Domoticz methods](#domoticz-methods)
    - [Iterators](#iterators)
    - [Contants](#contants)
  - [Device object API](#device-object-api)
    - [Device attributes](#device-attributes)
    - [Device methods](#device-methods)
  - [Variable object API](#variable-object-api)
    - [Variable attributes](#variable-attributes)
    - [Variable methods](#variable-methods)
  - [Switch timing options (delay, duration)](#switch-timing-options-delay-duration)
- [Final note](#final-note)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

About
=============
dzVents (|diː ziː vɛnts| short for Domotiz Easy Events) brings Lua scripting in Domoticz to whole new level. Writing scripts for Domoticz has never been so easy. Not only can you define triggers more easily, and have full control over timer-based scripts with extensive scheduling support, dzVents presents you with an easy to use API to all necessary information in Domoticz. No longer do you have to combine all kinds of information given to you by Domoticzs in many different data tables. You don't have to construct complex commandArrays anymore. dzVents encapsulates all the Domoticz peculiarities regarding controlling and querying your devices. And on top of that, script performance has increased a lot if you have many scripts because Domoticz will fetch all device information only once for all your device scripts and timer scripts.
 
Let's start with an example. Let's say you have a switch that when activated, it should activate another switch but only if the room temperature is above a certain level. And when done, it should send a notification. This is how it looks like in dzVents:

```
return {
	active = true,
	on = {
		'Room switch'
	},
	execute = function(domoticz, roomSwitch)
		if (roomSwitch.state == 'On' and domoticz.devices['Living room'].temperature > 18) then
			domoticz.devices['Another switch'].switchOn()
			domoticz.notify('This rocks!', 
			                'Turns out that it is getting warm here', 
			                domoticz.PRIORITY_LOW)
		end
	end
}

```
Or you have a timer script that should be executed every 10 minutes but only on weekdays and have it do something with some user variables and only during daytime:

```
return {
	active = true, 
	on = {
		['timer'] = {'Every 10 minutes on mon,tue,wed,thu,fri'}
	},
	execute = function(domoticz)	
		-- check time of the day
		if (domoticz.time.isDayTime and domoticz.variables['myVar'].nValue == 10) then
			domoticz.variables['anotherVar'].set(15)
			--activate my scene
			domoticz.setScene('Evening lights', 'On')
			if (domoticz.devices['My PIR'].lastUpdate.minutesAgo > 5) then
                domoticz.devices['Bathroom lights'].switchOff()
            end
		end			
	end
}
```
Or you want to detect a humidity rise since the past 5 minutes:
```
return {
	active = true, 
	on = { ['timer'] = 'every 5 minutes },
	data = { previousHumidity = { initial = 100 } },
	execute = function(domoticz)	
		local bathroomSensor = domoticz.devices['BathroomSensor']
		if (bathroomSensor.humidity - domoticz.data.previousHumidity) >= 5) then
			-- there was a significant rise
			domoticz.devices['Ventilator'].switchOn()
		end
		-- store current value for next cycle
		domoticz.data.previousHumidity = bathroomSensor.humidity
	end
}
```
Just to give you an idea! Everything that was previously scattered around in a dozen Lua tables is now logically available in the domoticz object structure. From there you can get to all the information and you can control the devices.

Installing
=============
*First of all, installing dzVents will not affect any of the scripts you have already in place so you can try dzVents without disrupting things.*

Note: this code is *not* tested on a non-linux machine like Windows. I'm almost certain you will have complications. 

Download the latest release from [GitHub](https://github.com/dannybloe/dzVents/releases), unzip it. 
Form the extracted zip folder copy the following to the Domoticz script folder (`/path/to/domoticz/scripts/lua`):

 -  The `dzVents` folder. This folder contains all the dzVents logic
 - `script_time_main.lua`
 - `script_device_main.lua`
 - `dzVents_settings.lua` and 
 - the folder `scripts` 

After doing so you will have this structure:
```
domoticz/
	scripts/
		lua/
			dzVents/
				... <dzVents files> ...
				examples/ 
				tests/
			scripts/
			script_time_main.lua
			script_device_main.lua
			dzVents_settings.lua
			... <other stuff that was already there> ...
```

Edit the file `dzVents_settings.lua` and enter the ip number and port number of your Domoticz instance. Make sure that you don't need a username/password for local networks (see Domoticz settings) or dzVents will not be able to fetch additional data like battery status and device type information! If you don't want  or need this then you can set `['Enable http fetch']` to `false`.

The scripts folder is where you put your new Lua event scripts. You can give them any name with the `.lua` extension (no need for *script_device* nor *script_time* prefixing).

Quickstart
-------------
After you placed the dzVents files in the right location we can do a quick test if everything works:

 - Pick a switch in your Domoticz system. Note down the exact name of the switch. If you don't have a switch then you can create a Dummy switch and use that one.
 - Create a new script in the `scripts/` folder. Call it `test.lua`.
 - Open `test.lua` in an editor and fill it with this code and change `<exact name of the switch>` with the .. you guessed it... exact name of the switch device:
 
```
return {
	active = true,
	on = {
		'<exact name of the switch>'
	},
	execute = function(domoticz, switch)
		if (switch.state == 'On') then
			domoticz.notify('Hey!', 'I am on!',
			domoticz.PRIORITY_NORMAL)
		else
			domoticz.notify('Hey!', 'I am off!',
			domoticz.PRIORITY_NORMAL)
		end
	end
}
```
 - Save the script
 - Open the Domoticz log in the browser
 - In Domoticz (another tab perhaps) press the switch. 
 - You can watch the log in Domoticz and it should show you that indeed it triggered your script.
 - Assuming of course that you have configured the notify options in Domoticz. Otherwise you can change the lines with `domoticz.notify` to `domoticz.email(<your address>)`.

The [examples folder](/dzVents/examples) has a couple of example scripts

How does it to work?
============
Normally, every time a device is updated in Domoticz it scans the script folder `../domoticz/scripts/lua` and executes *every script it can find starting with script_device* but before it does so, for each and every script, it builds all the necessary global Lua tables. This takes quite some time especially when you have a lot of scripts. Also, you have to program logic in every script to prevent the code from being executed when you don't want to (e.g. the device wasn't updated).
 
dzVents optimizes this process. All the event scripts that you make using dzVents will have to sit in the scripts folder and the two main script `script_device_main.lua` and `script_time.main.lua` make sure the right event scripts are called. Don't change these two files. 

All other scripts can live alongside the dzVents scripts. However, in order to have them work with dzVents you have to adapt them a little (and move them over to the scripts folder).

*Note: there are two other kinds of scripts that Domoticz might call: `script_security..` and `script_variable..`. They will not be affected by dzVents just yet.*

So, how to adapt the scripts?

Adapting or creating your scripts
----------------------------------
In order for your scripts to work with dzVents, they have to be turned into a Lua module. Basically you make sure it returns a Lua table (object) with a couple of predefined keys `active`, `on` and `execute`.. Here is an example:

```
return {
    active = true,
    on = {
        'My switch'
    },
    execute = function(domoticz, device)
        -- your script logic goes here, something like this:
        
        if (device.state == 'On') then
            domoticz.notify('I am on!', '', domoticz.PRIORITY_LOW)
        end        
    end
}
```
Simply said, if you want to turn your existing script into a script that can be used with dzVents, you put it inside the execute function.

So, the module returns a table with these sections (keys):
```
return {
    active = ... ,
    on = { ... },
    data = { ... },
    execute = function(domoticz, device, triggerInfo)
		...
    end
}
```
* **on = { .. }**: (*don't confuse this with **on**/off, it is more like: **on** < some event > **execute** < code >*). This is a Lua table (kind of an array) with **one or more** trigger events:
    * The name of your device between string quotes. **You can use the asterisk (\*) wild-card here e.g. `PIR_*` or `*_PIR` .** Note that in one cycle several devices could have been updated. If you have a script with a wild-card trigger that matches all the names of these changed devices, then this script will be executed *for all these changed devices*.  
    * The index of your device (the name may change, the index will usually stay the same), 
    * The string or table 'timer' which makes the script execute every minute (see the section **timer trigger options** [below](#timer-trigger-options)). 
    * Or a **combination**.
     
    So you can put as many triggers in there as you like and only if one of those is met, then the **execute** part is executed by dzVents.
* **active = true/false**: this can either be:
	* a boolean value (`true` or `false`, no quotes!). When set to `false`, the script will not be called. This is handy for when you are still writing the script and you don't want it to be executed just yet or when you simply want to disable it. 
	* A function returning `true` or `false`. The function will receive the domoticz object with all the information about you domoticz instance: `active = function(domoticz) .... end`. So for example you could check for a Domoticz variable or switch and prevent the script from being executed. **However, be aware that for *every script* in your scripts folder, this active function will be called, every cycle!! So, it is better to put all your logic in the execute function instead of in the active function.** Maybe it is better to not allow a function here at all... /me wonders.
* **execute = function(domoticz, device, triggerInfo)**: This part should be a function that is called by dzVents and contains the actual logic. You can copy the code from your existing script into this section. The execute function receives three possible parameters:
	* the [domoticz object](#domoticz-object-api). This gives access to almost everything in your Domoticz system including all methods to manipulate them like modifying switches or sending notifications. *There shouldn't be any need to manipulate the commandArray anymore.* (If there is a need, please let me know and I'll fix it). More about the domoticz object below. 
	* the actual [device](#device-object-api) that was defined in the **on** part and caused the script to be called. **Note: of course, if the script was triggered by a timer event, this parameter is *nil*! You may have to test this in your code if your script is triggered by timer events AND device events**
	* information about what triggered the script. This is a small table with two keys:
		* **triggerInfo.type**: (either domoticz.EVENT_TYPE_TIMER  or domoticz.EVENT_TYPE_DEVICE): was the script executed due to a timer event or a device-change event.
		* **triggerInfo.trigger**: which timer rule triggered the script in case the script was called due to a timer event. See below for the possible timer trigger options. Note that dzVents lists the first timer definition that matches the current time so if there are more timer triggers that could have been triggering the script, dzVents only picks the first for this trigger property.
* **data = { .. }**: A Lua table defining variables that will be persisted between script runs. These variables can get a value in your execute function (e.g. `domoticz.data.previousTemperature = device.temperature`) and the next time the script is executed this value is again available in your code (e.g. `if (domoticz.data.previousTemperature < 20) then ...`. For more info see ...

*timer* trigger options
-------------
There are several options for time triggers. It is important to know that Domoticz timer events are only trigger once every minute. So that is the smallest interval for you timer scripts. However, dzVents gives you a great many options to have full control over when and how often your timer scripts are called (all times are in 24hr format!). You can create full schedules (sorry about the weird bracket syntax, that's just Lua):

```
on = {
    'timer'                            -- the simplest form, causes the script to be called every minute
    ['timer'] = 'every minute',        -- same as above: every minute
    ['timer'] = 'every other minute',  -- minutes: xx:00, xx:02, xx:04, ..., xx:58
    ['timer'] = 'every <xx> minutes',  -- starting from xx:00 triggers every xx minutes
                                       -- (0 > xx < 60)
    ['timer'] = 'every hour',          -- 00:00, 01:00, ..., 23:00  (24x per 24hrs)
    ['timer'] = 'every other hour',    -- 00:00, 02:00, ..., 22:00  (12x per 24hrs)
    ['timer'] = 'every <xx> hours',    -- starting from 00:00, triggers every xx 
                                       -- hours (0 > xx < 24)
    ['timer'] = 'at 13:45',            -- specific time
    ['timer'] = 'at *:45',             -- every 45th minute in the hour
    ['timer'] = 'at 15:*',             -- every minute between 15:00 and 16:00
    ['timer'] = 'at 13:45 on mon,tue', -- at 13:45 only on Monday en Tuesday (english)
    ['timer'] = 'every hour on sat',   -- you guessed it correctly
    ['timer'] = 'at sunset',           -- uses sunset/sunrise info from Domoticz
    ['timer'] = 'at sunrise',
    ['timer'] = 'at sunset on sat,sun'
    
    -- and last but not least, you can create a table with multiples:
    ['timer'] = {'at 13:45', 'at 18:37', 'every 3 minutes'},

},
```
**One important note: if Domoticz, for whatever reason, skips a beat (skips a timer event) then you may miss the trigger! So you may have to build in some fail-safe checks or some redundancy if you have critical time-based stuff to control. There is nothing dzVents can do about it**

The domoticz object
===================
And now the most interesting part. Before, all the device information was scattered around in a dozen global Lua tables like `otherdevices` or `devicechanged`. You had to write a lot of code to collect all this information and build your logic around it. And, when you want to update switches and stuff you had to fill the commandArray with often low-level stuff in order to make it work.

**IMPORTANT: Make sure that all your devices have unique names!! dzVents doesn't check for duplicates!!**

Fear no more: introducing the **domoticz object**.

The domoticz object contains everything that you need to know in your scripts and all the methods (hopefully) to manipulate your devices and sensors. Getting this information has never been more easy: 

`domoticz.time.isDayTime` or `domoticz.devices['My sensor'].temperature` or `domoticz.devices['My sensor'].lastUpdate.minutesAgo`.   

So this object structure contains all the information logically arranged where you would expect it to be. Also, it harbors methods to manipulate Domoticz or devices. dzVents will create the commandArray contents for you and all you have to do is something like `domoticz.devices[123].switchOn().for_min(5).after_sec(10)` or `domoticz.devices['My dummy sensor'].updateBarometer(1034, domoticz.BARO_THUNDERSTORM)`.

*The intention is that you don't have to construct low-level commandArray-commands for Domoticz anymore!* Please let me know if there is anything missing there. Of course there is a method `domotiz.sendCommand(..)` that allows you to send raw Domoticz commands in case there indeed is some update function missing.

Domoticz object API
-----------
The domoticz object holds all information about your Domoticz system. It has a couple of global attributes and methods to query and manipulate your system. It also has a collection of **devices** and **variables** (user variables in Domoticz) and when applicable, a collection of **changedDevices**. There three collection each have two iterator functions: `forEach(function)` and `filter(function)` to make searching for devices easier. See iterators below.

### Domoticz attributes:

 - **changedDevices**: *Table*. A collection holding all the devices that have been updated in this cycle.
 - **devices**: *Table*. A collection with all the *device objects*. You can get a device by its name or id: `domoticz.devices[123]` or `domoticz.devices['My switch']`. See **Device object** below. 
 - **security**: Holds the state of the security system e.g. `Armed Home` or `Armed Away`.
 - **time**: Current system time:
	 - **day**: *Number*
	 - **hour**: *Number*
	 - **isToday**: *Boolean*. Indicates if the device was updated today
	 - **month**: *Number*
	 - **min**: *Number*
 	 - **raw**: *String*. Generated by Domoticz
	 - **sec**: *Number*
	 - **year**: *Number*
	 - **isDayTime**
	 - **isNightTime**
	 - **sunsetInMinutes**
	 - **sunriseInMinutes**
 - **variables**: *Table*. A collection holding all the user *variable objects* as defined in Domoticz. See **Variable object** for the attributes.  

### Domoticz methods

 - **email(subject, message, mailTo)**: *Function*. Send email.
 - **fetchHttpDomoticzData**: *Function*. This will trigger a script that will download the device data from Domoticz and stores this on the filesystem for dzVents to use. This data contains information like battery level and device type information that can only be fetched through an http call. Normally dzVents will do this automatically in the background if it is enabled in the `dzVents_settings.lua` file. If you want to do this manually through an event script perhaps (you can use a switch trigger for instance) then you can disable the automatic fetching by changing the setting in `dzVents_settings.lua` and create your own event.
 - **log(message, [level]):** *Function*. Creates a logging entry in the Domoticz log but respects the log level settings. You can provide the loglevel: `domoticz.LOG_INFO`, `domoticz.LOG_DEBUG` or `domoticz.LOG_ERROR`. In `dzVents_settings.lua` you can specify which kind of log message will be printed.
 - **notify(subject, message, priority, sound)**: *Function*. Send a notification (like Prowl). Priority can be like `domoticz.PRIORITY_LOW, PRIORITY_MODERATE, PRIORITY_NORMAL, PRIORITY_HIGH, PRIORITY_EMERGENCY`. For sound see the SOUND constants below.
 - **openURL(url)**: *Function*. Have Domoticz 'call' a URL.
 - **sendCommand(command, value)**: *Function*. Generic command method (adds it to the commandArray) to the list of commands that are being sent back to domoticz. *There is likely no need to use this directly. Use any of the device methods instead (see below).*
 - **setScene(scene, value)**: *Function*. E.g. `domoticz.setScene('My scene', 'On')`. Supports timing options. See below.
 - **sms(message)**: *Function*. Sends an sms if it is configured in Domoticz. 
 - **switchGroup(group, value)**: *Function*. E.g. `domoticz.switchGroup('My group', 'Off')`. Supports timing options. See below.

### Iterators
The domoticz object has three collections (tables): devices, changedDevices and variables. In order to make iterating over these collections easier dzVents has two iterator methods so you don't need to use the `pair()` or `ipairs()` function anymore (less code to write):

 1. **forEach(function):** Executes a provided function once per array element. The function receives the item in the collection (device or variable) and the key and the collection itself. If you return *false* in the function then the loop is aborted.
 2. **filter(function):** returns items in the collection for which the function returns true.

Best to illustrate with an example:

```
	domoticz.devices.forEach(function(device, key)
		if (device.batteryLevel < 20) then
			-- do something
		end
	end)
```
Or using a filter:
```
	local deadDevices = domoticz.devices.filter(function(device)
		return (device.lastUpdate.minutesAgo > 60)
	end)
	deadDevices.forEach(function(zombie)
		-- do something
	end)
```
Of course you can chain:
```
	domoticz.devices.filter(function(device)
		return (device.lastUpdate.minutesAgo > 60)
	end).forEach(function(zombie)
		-- do something with the zombie
	end)
```

### Contants

 - **ALERTLEVEL_GREY**, **ALERTLEVEL_GREEN**, **ALERTLEVEL_ORANGE**, **ALERTLEVEL_RED**, **ALERTLEVEL_YELLOW**: For updating text sensors.
 - **BARO_CLOUDY**, **BARO_CLOUDY_RAIN**, **BARO_STABLE**, **BARO_SUNNY**, **BARO_THUNDERSTORM**, **BARO_UNKNOWN**, **BARO_UNSTABLE**: For updating barometric values.
 - **HUM_COMFORTABLE**, **HUM_DRY**, **HUM_NORMAL**, **HUM_WET**: Constant for humidity status.
 - **LOG_DEBUG**, **LOG_ERROR**, **LOG_INFO**: For logging messages.
 - **PRIORITY_LOW**, **PRIORITY_MODERATE**, **PRIORITY_NORMAL**, **PRIORITY_HIGH**, **PRIORITY_EMERGENCY**: For notification priority.
 - **SECURITY_ARMEDAWAY**, **SECURITY_ARMEDHOME**, **SECURITY_DISARMED**: For security state.
 - **SOUND_ALIEN** , **SOUND_BIKE**, **SOUND_BUGLE**, **SOUND_CASH_REGISTER**, **SOUND_CLASSICAL**, **SOUND_CLIMB** , **SOUND_COSMIC**, **SOUND_DEFAULT** , **SOUND_ECHO**, **SOUND_FALLING**  , **SOUND_GAMELAN**, **SOUND_INCOMING**, **SOUND_INTERMISSION**, **SOUND_MAGIC** , **SOUND_MECHANICAL**, **SOUND_NONE**, **SOUND_PERSISTENT**, **SOUND_PIANOBAR** , **SOUND_SIREN** , **SOUND_SPACEALARM**, **SOUND_TUGBOAT**  , **SOUND_UPDOWN**: For notification sounds. 
 

Device object API
------
Each device in Domoticz can be found in the `domoticz.devices` collection as listed above. The device object has a set of fixed attributes like *name* and *id*. Many devices though (like sensors) have special attributes like *temperature*, *humidity* etc. These attributes are also available on each device object *when applicable*. However, some attributes are not exposed by Domoticz to the event scripts. Fortunately dzVents will fetch this information through http and extends this missing information to the device data it already got from Domoticz. If you still find some attributes missing you can check the rawData property of a device. Most likely you will find it there:

```
	domoticz.devices['mySensor'].temperature
	domoticz.devices['myLightSensor'].rawData[1] -- lux value, rawData is an indexed table!
```

### Device attributes

 - **batteryLevel**: *Number* (note this is the raw value from Domoticcz and can be 255)
 - **bState**: *Boolean*. Is true for some commong states like 'On' or 'Open' or 'Motion'. 
 - **barometer**: Only when applicable.
 - **changed**: *Boolean*. True if the device was changed
 - **deviceSubType**: *String*. See Domoticz devices table in Domoticz GUI.
 - **deviceType**: *String*. See Domoticz devices table in Domoticz GUI.
 - **dewpoint**: Only when applicable. 
 - **hardwareName**: *String*. See Domoticz devices table in Domoticz GUI.
 - **hardwareId**: *Number*. See Domoticz devices table in Domoticz GUI.
 - **hardwareType**: *String*. See Domoticz devices table in Domoticz GUI.
 - **hardwareTypeVal**: *Number*. See Domoticz devices table in Domoticz GUI.
 - **humidity**: Only when applicable.
 - **id**: *Number*. Id of the device
 - **lastUpdate**: 
	 - **day**: *Number*
	 - **hour**: *Number*
 	 - **hoursAgo**: *Number*. Number of hours since the last update.
	 - **isToday**: *Boolean*. Indicates if the device was updated today
	 - **month**: *Number*
	 - **min**: *Number*
	 - **minutesAgo**: *Number*. Number of minutes since the last update.
	 - **raw**: *String*. Generated by Domoticz
	 - **sec**: *Number*
	 - **secondsAgo**: *Number*. Number of seconds since the last update.
	 - **year**: *Number*
 - **level**: *Number*. For dimmers and other 'Set Level..%' devices this holds the level like selector switches.
 - **lux**: *Number*. Lux level for light sensors.
 - **name**: *String*. Name of the device
 - **rain**: Only when applicable.
 - **rainLastHour**: Only when applicable.
 - **rawData**: *Table*:  Not all information from a device is available as a named attribute on the device object. That is because Domoticz doesn't provide this as such. If you have a multi-sensor for instance then you can find all data points in this **rawData** *String*. It is an array (Lua table). E.g. to get the Lux value of a sensor you can do this: `local lux = mySensor.rawData[1]` (assuming it is the first value that is passed by Domoticz). Note that the values are string types!! So if you expect a number, convert it first (`tonumber(device.rawData[1]`).
 - **signalLevel**: *String*. See Domoticz devices table in Domoticz GUI.
 - **state**: *String*. For switches this holds the state like 'On' or 'Off'. For dimmers that are on, it is also 'On' but there is a level attribute holding the dimming level. **For selector switches** (Dummy switch) the state holds the *name* of the currently selected level. The corresponding numeric level of this state can be found in the **rawData** attribute: `device.rawData[1]`.
 - **setPoint**: *Number*. Holds the set point for thermostat like devices. 
 - **heatingMode**: *String*. For zoned thermostats like EvoHome.
 - **switchType**: *String*. See Domoticz devices table in Domoticz GUI.
 - **switchTypeValue**: *Number*. See Domoticz devices table in Domoticz GUI.
 - **temperature**: Only when applicable.
 - **utility**: Only when applicable.
 - **uv**: Only when applicable.
 - **weather**: Only when applicable.
 - **WActual**: *Number*. Current Watt usage.
 - **WhToday**: *Number*. Total Wh usage of the day. Note the unit is Wh and not kWh.
 - **WhTotal**: *Number*. Total Wh (incremental).
 - **winddir**: Only when applicable.
 - **windgust**: Only when applicable.
 - **windspeed**: Only when applicable.

### Device methods

 - **attributeChanged(attributeName)**: *Function*. Returns  a boolean (true/false) if the attribute was changed in this cycle. E.g. `device.attributeChanged('temperature')`.
 - **close()**: *Function*.  Set device to Close if it supports it. Supports timing options. See below.
 - **dimTo(percentage)**: *Function*.  Switch a dimming device on and/or dim to the specified level. Supports timing options. See below.
 - **open()**: *Function*.  Set device to Open if it supports it. Supports timing options. See below.
 - **setState(newState)**: *Function*. Generic update method for switch-like devices. E.g.: device.setState('On'). Supports timing options. See below.
 - **stop()**: *Function*.  Set device to Stop if it supports it (e.g. blinds). Supports timing options. See below.
 - **switchOff()**: *Function*.  Switch device off it is supports it. Supports timing options. See below.
 - **switchOn()**: *Function*.  Switch device on if it supports it. Supports timing options. See below.
 - **switchSelector(level)**:  *Function*. Switches a selector switch to a specific level (numeric value, see the edit page in Domoticz for such a switch to get a list of the values). Supports timing options. See below.
 - **update(< params >)**: *Function*. Generic update method. Accepts any number of parameters that will be sent back to Domoticz. There is no need to pass the device.id here. It will be passed for you. Example to update a temperature: `device.update(0,12)`. This will eventually result in a commandArray entry `['UpdateDevice']='<idx>|0|12'`
 - **toggleSwitch()**: *Function*. Toggles the state of the switch (if it is togglable) like On/Off, Open/Close etc.
 - **updateAirQuality(quality)**: *Function*. 
 - **updateAlertSensor(level, text)**: *Function*. Level can be domoticz.ALERTLEVEL_GREY, ALERTLEVEL_GREE, ALERTLEVEL_YELLOW, ALERTLEVEL_ORANGE, ALERTLEVEL_RED
 - **updateBarometer(pressure, forecast)**: *Function*. Update barometric pressure. Forecast can be domoticz.BARO_STABLE, BARO_SUNNY, BARO_CLOUDY, BARO_UNSTABLE, BARO_THUNDERSTORM, BARO_UNKNOWN, BARO_CLOUDY_RAIN 
 - **updateCounter(value)**: *Function*. 
 - **updateDistance(distance)**: *Function*. 
 - **updateElectricity(power, energy)**: *Function*. 
 - **updateGas(usage)**: *Function*. 
 - **updateHumidity(humidity, status)**: *Function*. Update humidity. status can be domoticz.HUM_NORMAL, HUM_COMFORTABLE, HUM_DRY, HUM_WET 
 - **updateLux(lux)**: *Function*. 
 - **updateP1(sage1, usage2, return1, return2, cons, prod)**: *Function*. 
 - **updatePercentage(percentage)**: *Function*. 
 - **updatePressure(pressure)**: *Function*. 
 - **updateRain(rate, counter)**: *Function*. Update rain sensor.
 - **updateTemperature(temperature)**: *Function*. Update temperature sensor.
 - **updateTempHum(temperature, humidity, status)**: *Function*. For status options see updateHumidity.
 - **updateTempHumBaro(temperature, humidity, status, pressure, forecast)**: *Function*. 
 - **updateText(text)**: *Function*. 
 - **updateUV(uv)**: *Function*. 
 - **updateVoltage(voltage)**: *Function*. 
 - **updateWind(bearing, direction, speed, gust, temperature, chill)**: *Function*. 

> "Hey!! I don't see my sensor readings in the device object!! Where is my LUX value for instance?"

That may be because Domoticz doesn't pass all the device data as named attributes. If you cannot find your attribute then you can inspect the **rawData** attribute of the device. This is a table (array) of values. So for a device that has a Lux value you may access it like this:

    local lux = mySensor.rawData[0]

Other devices may have more stuff in the rawData attribute like wind direction, energy info etc etc.

###Switch timing options (delay, duration)
To specify a duration or a delay for the various switch command you can do this:

    -- switch on for 2 minutes after 10 seconds
    device.switchOn().after_sec(10).for_min(2) 
    
    -- switch on for 2 minutes after a randomized delay of 1-10 minutes
    device.switchOff().within_min(10).for_min(2) 
    device.close().for_min(15)
    device.open().after_sec(20)
    device.open().after_min(2)

 - **after_sec(seconds)**: *Function*. Activates the command after a certain amount of seconds.
 - **after_min(minutes)**: *Function*. Activates the command after a certain amount of minutes.
 - **for_min(minutes)**: *Function*. Activates the command for the duration of a certain amount of minutes (cannot be specified in seconds).
 - **within_min(minutes)**: *Function*. Activates the command within a certain period *randomly*.

Note that **dimTo()** doesn't support **duration()**.

Variable object API
------
User variables created in Domoticz have these attributes and methods:

### Variable attributes

 - **nValue**: *Number*. **value** cast to number.
 - **value**: Raw value coming from Domoticz
 - **lastUpdate**: 
	 - **day**: *Number*
	 - **hour**: *Number*
	 - **hoursAgo**: *Number*. Number of hours since the last update.
	 - **isToday**: *Boolean*. Indicates if the device was updated today
	 - **min**: *Number*
	 - **minutesAgo**: *Number*. Number of minutes since the last update.
	 - **month**: *Number*
	 - **raw**: *String*. Generated by Domoticz
	 - **sec**: *Number*
	 - **year**: *Number*

### Variable methods

 - **set(value)**: *Function*. Tells Domoticz to update the variable. *No need to cast it to a string first (it will be done for you).*

Persistent data
===
In many situations you need to store some device state or other information in your scripts for later use. Like knowing what the state was of a device the previous time the script was executed or what the temperature in a room was 10 minutes ago. Without dzVents you had to resort to user variables. These are global variables that you create in the Domoticz GUI and that you can access in your scripts like: domoticz.variables['previousTemperature']. 

Now, for some this is rather inconvenient and they want to control this state information in the event scripts themselves (like me). dzVents has a solution for that: **persistent script data**. This can either be on the script level or on a global level.

Script level persistent variables
----
Persistent script variables are available in your scripts and whatever value put in them is persisted and can be retrieved in the next script run. 

Here is an example. Let's say you want to send a notification if some switch has been actived 5 times:

```
return {
    active = true,
    on = {
	    'MySwitch'
	},
    data = { 
	    counter = {initial=0} 
	},
    execute = function(domoticz, switch)
		if (domoticz.data.counter = 5) then
			domoticz.notify('The switch was pressed 5 times!')
			domoticz.data.counter = 0 -- reset the counter
		else
			domoticz.data.counter = domoticz.data.counter + 1
		end
    end
}
```
Here you see the `data` section defining a persistent variable called `counter`. It also defines an initial value.  From then on you can read and set the variable in your script.

You can define as many variables as you like and put whatever value in there that you like. It doesn't have to be just a number,  you can even put the entire device state in it:

```
return {
    active = true,
    on = {
	    'MySwitch'
	},
    data = { 
	    previousState = {initial=nil} 
	},
    execute = function(domoticz, switchDevice)
	    -- set the previousState:
		domoticz.data.previousState = switchDevice
		
		-- read something from the previousState:
		if (domoticz.data.previousState.temperature > .... ) then
		end
    end
}
```
**Note that you cannot call methods on previousState like switchOn(). Only the data is persisted.**

###Size matters and watch your speed!!
If you decide to put tables in the persistent data (or arrays) beware to not let them grow as it will definitely slow down script execution because dzVents has to serialize and deserialize the data back and from the file system. Better is to use the historical option as described below. 

Global persistent variables
---
Next to script level variables you can also define global variables. As script level variables are only available in the scripts that define them, global variables can be accessed and changed in every script. All you have to do is create a script file called `global_data.lua` in your scripts folder with this content:

```
return {
	data = {
		peopleAtHome = { initial = false },
		heatingProgramActive = { initial = false }
	}
}
```
Just define the variables that you need and access them in your scripts:
```
return {
    active = true,
    on = {
	    'WindowSensor'
	},
    execute = function(domoticz, windowSensor)
		if (domoticz.globalData.heatingProgramActive and windowSensor.state == 'Open') then
			domoticz.notify("Hey don't open the window when the heating is on!")
		end
    end
}
```
A special kind of persistent variables: *history = true*
---
In some situation, storing a previous value for a sensor is not enough and you would like to have more previous values for example when you want to calculate an average over several readings or see if there was a constant rise or decrease. Of course you can define a persistent variable holding a table:

```
return {
    active = true,
    on = {
	    'MyTempSensor'
	},
	data = {
		previousData = { initial = {} }
	},
    execute = function(domoticz, sensor)
		-- add new data
		table.insert(domoticz.data.previousData, sensor.temperature)

		-- calculate the average
		local sum = 0, count = 0
		for i, temp in pairs(domoticz.data.previousData) do
			sum = sum + temp
			count = count + 1
		end
		local average = sum / count
    end
}
```
The problem with this is that you have to do a lot of bookkeeping yourself to make sure that there is too much data to store (see below how it works) and many statistical stuff requires a lot of code. Fortunately, dzVents has done this for you:
```
return {
    active = true,
    on = {
	    'MyTempSensor'
	},
	data = {
		temperatures = { history = true, maxItems = 10 }
	},
    execute = function(domoticz, sensor)
		-- add new data
		domoticz.data.temperatures.setNew(sensor.temperature)

		-- average
		local average = domoticz.data.temperatures.avg()
		
		-- maximum value in the past hour:
		local max = domoticz.data.temperatures.maxSince('01:00:00') 
    end
}
```
###Historical variables API
####Defining
You define a script variable or global variable in the data section and set `history = true`:
```
	..
	data = {
		var1 = { history = true, maxItems = 10, maxHours = 1, maxMinutes = 5 }
	}
```

 - **maxItems**: *Number*. Controls how many items are stored in the variable. maxItems wins over maxHours and maxMinutes.
 - **maxHours**: *Number*. Data older than `maxHours` from now will be discarded.  So if you set it to 2 than data older than 2 hours will be removed at the beginning of the script. 
 - **maxMinutes**: *Number*. Same as maxHours but, you guessed it: for minutes this time..
 All these options can be combined but maxItems wins. **And again: don't store too much data. Just put only in there what you really need!** 


#### Setting
When you defined your historical variable you can add a new value to the list like this:

    domoticz.data.myVar.setNew(value)

As soon as you do that, this new value is put on top of the list and shifts the older values one place down the line. If `maxItems` was reached then the oldest value will be discarded.  *All methods like calculating averages or sums will immediately use this new value!* So, if you don't want this to happen set the new value at the end of your script or after you have done your analysis.

Basically you can put any kind of data in the historical variable. It can be a numbers, strings but also more complex data like tables. However, in order to be able to use the statistical methods you will have to set numeric values or tell dzVents how to get a numeric value from you data. More on that later.

#### Getting. It's all about time!
Getting values from a historical variable is basically done by using an index where 1 is the newest value , 2 is the second to newest and so on:

    domoticz.data.myVar.storage[5]

However, all data in the storage is time-stamped so getting something from the internal storage will get you this:
```
	local item = domoticz.data.myVar.getLatest()
	print(item.time.secondsAgo) -- access the time stamp
	print(item.data) -- access the data
```
The time attribute by itself is a table with many properties that help you inspect the data points more easily:

 - **day**: *Number*.
 - **hour**: *Number*
 - **isToday**: *Boolean*. 
 - **month**: *Number*
 - **min**: *Number*
 - **minutesAgo**: *Number*.  How many minutes ago from the current time the data was stored.
 - **raw**: *String*. Formatted time.
 - **sec**: *Number*
 - **secondsAgo**: *Number*. Number of seconds since the last update.
 - **year**: *Number*
 - **utcSystemTime**: *Table*. UTC system time:
	 - **day**: *Number*
	 - **hour**: *Number*
	 - **month**: *Number*
	 - **min**: *Number*
	 - **sec**: *Number*
	 - **year**: *Number*
 - **utcTime**: *Table*. Time stamp in UTC time:
	 - **day**: *Number*
	 - **hour**: *Number*
	 - **month**: *Number*
	 - **min**: *Number*
	 - **sec**: *Number*
	 - **year**: *Number*
 
####Interacting with your data. Statistics!
Once you have data points in your historical variable you have interact with it and get all kinds of statistical information from you set. Many of the methods require an index, an index-range or a time specification.

**Index**
When you have to provide an index, you have to start counting from 1 (that's Lua). 1 is the youngest value (and beware, if you have called setNew first, then the first item is that new value!). The higher the index, the older the data. You can always check the size of the set by inspecting `myVar.size`. 

**Time specification (timeAgo)**
Many functions require you to specify a moment in the past. You do this by passing a string in this format:

    hh:mm:ss
   
  Where hh is the amount of hours ago, mm the amount of minutes and ss the amount of seconds. They will all be added together and you don't have to consider 60 minute boundaries etc. So this is a valid time specification:
  

    12:88:03

Which will point to the data point at or around `12*3600 + 88*60 + 3 = 48.483` seconds in the past.

**Getting data points:**

 - **subset([fromIdx], [toIdx])**:  Returns a subset of the stored data. If you omit `fromIdx` then it starts at 1. If you omit `toIdx` then it takes all items until the end of the set (oldest). So `myVar.subset()` returns all data.
 - **subsetSince([timeAgo])**: Returns a subset of the stored data since the relative time specified by timeAgo. So calling `myVar.subsetSince('00:60:00')` returns all items that have been added to the list in the past 60 minutes.
 - **get([idx])**: Returns the idx-th item in the set. Same as `myVar.storage[idx]`.
 - **size**: Return the amount of data points in the set.
 - **storage**: The actual data storage. This is a Lua table (array) holding all the item. Use `myVar.get()` to get items from the set.
 - **getAtTime(timeAgo)**: Returns the data point closest to the moment as specified by `timeAgo`. So `myVar.getAtTime('1:00:00')` returns the item that is closest to one hour old. So it may be a bit younger or a bit older than 1 hour.
 - **getLatest():** Returns the youngest item in the set. Same as `myVar.get(1)`.
 - **getOldest()**: Returns the oldest item in the set. Same as `myVar.get(myVar.size)`.
 - **reset():** Removes all the items from the set. Could be handy if you want to start over. It could be a good practice to do this often when you know you don't need older data. For instance when you turn on a heater and you just want to monitor rising temperatures starting from this moment when the heater is activated. If you don't need data points from before, then you may call reset.

**Statistical functions:**
In order to use the statistical functions you have to put numerical data in the set. Or you have to provide a function for getting this data. So, if it is just numbers you can just do this:

    myVar.setNew(myDevice.temperature) -- adds a number to the set
    myVar.avg() -- returns the average
    
If, however you add more complex data or you want to do a computation first, then you have to tell dzVents how to get to this data. So let's say you do this to add data to the set:

    myVar.setNew( { 'person' = 'John', waterUsage = u })
    
Where `u` is some variable that got its value earlier. Now if you want to calculate the average water usage then dzVents will not be able to do this because it doesn't know the value is actually in the `waterUsage` attribute.

To make this work you have to provide a **getValue function** when you define myVar:

    return {
	    active = true,
	    on = {...},
	    data = {
			myVar = { 
				history = true, 
				maxItems = 10,
				getValue = function(item) 
					return item.data.waterUsage -- return number!!
				end
			}
	    },
	    execute = function()...end
    }
    
This function tells dzVents when it tries to sum up values (needed for averaging) that the value is to get from the waterUsage attribute. **The getValue function has to return a number**.

Of course, if you don't intend to use any of these statistical functions you can put whatever you want in the set. Even mixup data. No-one cares but you.

**Functions**:

 - **avg([fromIdx], [toIdx], [default])**: Calculates the average of all item values within the range `fromIdx` to `toIdx`. You can specify a `default` value for when there is no data in the set. 
 - **avgSince(timeAgo, default)**: Calculates the average of all data points since `timeAgo`. Returns `default` if there is no data.
 - **min([fromIdx], [toIdx])**: Returns the lowest value in the range defined by fromIdx and toIdx.
 - **minSince(timeAgo)**: Same as **min** but now within the `timeAgo` interval.
 - **max([fromIdx], [toIdx])**: Returns the highest value in the range defined by fromIdx and toIdx.
 - **maxSince(timeAgo)**: Same as **max** but now within the `timeAgo` interval.
 - **sum([fromIdx], [toIdx])**: Returns the summation of all values in the range defined by fromIdx and toIdx.
 - **sumSince(timeAgo)**: Same as **sum** but now within the `timeAgo` interval.
 - **delta(fromIdx, toIdx, [smoothRange], [default])**:  Returns the delta (difference) between items specified by `fromIdx` and `toIdx`. You have to provide a valid range (no nil values). When you want to do data smoothing (see below) when comparing then specify the smoothRange. Returns `default` if there is not enough data.
 - **deltaSince(timeAgo,  [smoothRange], [default])**: Same as **delta** but now within the `timeAgo` interval.
 - **localMin([smoothRange], default)**:  Returns the first minimum value (and the item holding the minimal value) in the past. So if you have this range of values (from new to old): 10 8 7 5 3 4 5 6.  Then it will return 3 because older values and newer values are higher. You can use if you want to know at what time a temperature started to rise. E.g.:```
local value, item = myVar.localMin()
print(' minimum was : ' .. value .. ': ' .. item.time.secondsAgo .. ' seconds ago' )
```
 - **localMax([smoothRange], default)**:  Same as **localMin** but now for the maximum value.
 - **smoothItem(itemIdx, [smoothRange])**: Returns a the value of `itemIdx` in the set but smoothed by averaging with its neighbors. The amount of neighbors is set by `smoothRange`.


**About data smoothing**
Suppose you store temperatures in the historical variable. These temperatures my have extremes. Sometimes these extremes could be due to sensor reading errors. In order to reduce the effect of these so called spikes, you could smooth out values. It is like blurring the data. Here is an example. The Raw column could be your temperatures.

| Time | Raw | range=1 | range=2 |
|------|-----|---------|---------|
| 1    | 18  | 20,0    | 23,0    |
| 2    | 22  | 21,7    | 24,2    |
| 3    | 25  | 27,3    | 25,1    |
| 4    | 35  | 27,7    | 26,3    |
| 5    | 23  | 28,7    | 26,7    |
| 6    | 28  | 26,0    | 25,7    |
| 7    | 27  | 23,7    | 25,0    |
| 8    | 16  | 22,7    | 24,9    |
| 9    | 25  | 24,0    | 25,5    |
| 10   | 31  | 28,3    | 26,7    |
| 11   | 29  | 28,7    | 28,3    |
| 12   | 26  | 30,0    | 29,9    |
| 13   | 35  | 30,3    | 30,3    |
| 14   | 30  | 32,0    | 30,5    |
| 15   | 31  | 30,3    | 29,8    |
| 16   | 30  | 29,7    | 29,2    |
| 17   | 28  | 26,7    | 27,7    |
| 18   | 22  | 27,3    | 26,7    |
| 19   | 32  | 24,3    | 26,0    |
| 20   | 19  | 25,5    | 25,7    |

If you make a chart you can make it even more visible:
![Smothing](dzVents/smoothing.png)


Settings
===
As mentioned in the install section there is a settings file: dzVents_settings.lua. There you can set a couple of parameters for how dzVents operates:

 - **Domoticz ip**: *Number*. IP-address of your Domoticz instance.
 - **Domoticz port**: *Number*. Port number used to contact Domoticz over IP.
 - **Enable http fetch**: *Boolean*: Controls wether or not dzVents will fetch device data using http. Some information is not passed to the scripts by Domoticz like battery status or group or scene information. dzVents will fetch this data for you using this interval property:
 - **Fetch interval**: *String*. Default is 'every 30 minutes' but you can increase this if you need more recent values in your device objects. See [timer trigger options](#timer-trigger-options).
 - **Log level**: *Number*. 1: Errors, 2: Errors + info, 3: Debug info + Errors + Info, 0: As silent as possible. This part is stil a bit experimental and may not give you all the information you need in the logs. Besides, Domoticz tends to choke on too many log messages and may decide not to show them all. You can alway put a print statement here or there or use the `domoticz.log()` API (see [Domoticz object API](#domoticz-object-api)).

Final note
==
If you don't want to rewrite all your scripts at once you can have dzVents live along side your other scripts. They do not influence each other at all. You can move your scripts over one by one as you see fit to the scripts folder dzVents uses.

Oh, this code is tested on a linux file system. It should work on Windows. Let me know if it doesn't. There is some code in event_helpers.lua that is need to get a list of all the script in the scripts folder. 

Another note: I haven't tested all the various `device.update*` methods. Please let me know if I made any mistakes there or fix them yourselves and create a pull request (or email me) in GitHub.

Good luck and hopefully you enjoy using dzVents.
