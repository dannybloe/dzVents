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

Just to give you an idea! Everything that was previously scattered around in a dozen Lua tables is now logically available in the domoticz object structure. From there you can get to all the information and you can control the devices.

Installing
=============
Copy the files `event_helpers.lua`, `script_time_main.lua`, `script_device_main.lua`, `Domoticz.lua`, `dzVents_settings.lua` and the folder `scripts` to the Domoticz script folder
`../domoticz/scripts/lua`.

Edit the file `dzVents_settings.lua` and enter the ip number and port number of your Domoticz instance. Make sure that you don't need a username/password for local networks (see Domoticz settings) or dzVents will not be able to fetch additional data like battery status and device type information! If you don't want this then you can set `['Enable http fetch']` to `false`.

In the scripts folder there is an example.lua file. The scripts in that folder are used by the dzVents *_main.lua script files. All scripts in that folder are scanned by dzVents and the triggers are read and the code executed only when necessary.  

Getting it to work
============
Normally, every time a device is updated in Domoticz it scans the script folder `../domoticz/scripts/lua` and executes *every script it can find starting with script_device* but before it does so, for each and every script, it builds all the necessary global Lua tables. This takes quite some time especially when you have a lot of scripts. Also, you have to program logic in every script to prevent the code from being executed when you don't want to (e.g. the device wasn't updated).
 
dzVents optimizes this process. The idea is that there is only one `script_device_main.lua` and one `script_time.main.lua`. All other scripts you can move and rename them perhaps to a more sane name to the `scripts` sub folder and modularize them (an easy process, more on that later). Every script defines one or more triggers and dzVents only executes the scripts when those triggers are met.

*Note: there are two other kinds of scripts that Domoticz might call: `script_security..` and `script_variable..`. They will not be affected by this code (yet).*

Eventhough your logic in these scripts will stay more or less the same, you have to adapt your script a little:

Adapting or creating your scripts
----------------------------------
In order for your scripts to work with dzVents, they have to be turned into a Lua module. There is already an example called `example.lua` that shows you how to do this. Basically you make sure it returns a Lua table with a couple of predefined keys. Here is an example:

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

So, you add a little bit of code *around* your original logic (you return a Lua table). So this module return a table with three keys:

* **on**: This is a table (or array) with **one or more** trigger events. It is either:
    * the name of your device between string quotes. **You can use the asterisk (\*) wild-card here e.g. `PIR_*` or `*_PIR` .** Note that in one cycle several devices could have been updated. If you have a script with a wild-card trigger that matches all the names of these changed devices, then this script will be executed *for all these changed devices*.  
    * the index of your device (the name may change, the index will usually stay the same), 
    * the string or table 'timer' which makes the script execute every minute (see the section **timer trigger options** below). 
    * Or a **combination**.
     
    So you can put as many triggers in there as you like and only if one of those is met, then the execute part is executed by dzVents.
* **active**: this can either be:
	* a boolean value (true or false, no quotes!). When set to false, the script will not be called. This is handy for when you are still writing the script and you don't want it to be executed just yet or when you simply want to disable it. 
	* A function returning true or false. The function will receive the domoticz object with all the information about you domoticz instance: `active = function(domoticz) .... end`. So for example you could check for a Domoticz variable or switch and prevent the script from being executed. **However, be aware that for *every script* in your scripts folder, this active function will be called, every cycle!! So, it is better to put all your logic in the execute function instead of in the active function.** Maybe it is better to not allow a function here at all... /me wonders.
* **execute**: This is the actual logic of your script. You can copy the code from your existing script into this section. What is special is that dzVents will pass the domoticz object and for device triggers, the device that caused the trigger to be executed. These two objects are all you need to access all the data that Domoticz exposes to the event scripts. They also have all the methods needed to modify devices in Domoticz like modifying switches or sending notifcations. *There shouldn't be any need to manipulate the commandArray anymore.* (If there is a need, please let me know and I'll fix it). More about the domoticz object below.

**Note: if you have a script with *both a device trigger and a timer trigger* then only in the case of when a device update occurs, the changed device is passed into the execute function. When the timer triggers the script then this second parameter is `nil`.** You will have to check for this situation in you script. 

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
**One important note: if Domoticz ,for whatever reason, skips a beat (skips a timer event) then you may miss the trigger! So you may have to build in some fail-safe checks or some redundancy if you have critical time-based stuff to control. There is nothing dzVents can do about it**

The domoticz object
===================
And now the most interesting part. Before, all the device information was scattered around in a dozen global Lua tables like `otherdevices` or `devicechanged`. You had to write a lot of code to collect all this information and build your logic around it. And, when you want to update switches and stuff you had to fill the commandArray with often low-level stuff in order to make it work.

**IMPORTANT: Make sure that all your devices have unique names!! dzVents doesn't check for duplicates!!**

Fear no more: introducing the **domoticz resource object**.

The domoticz object contains everything that you need to know in your scripts and all the methods (hopefully) to manipulate your devices and sensors. Getting this information has never been more easy: 

`domoticz.time.isDayTime` or `domoticz.devices['My sensor'].temperature` or `domoticz.devices['My sensor'].lastUpdate.minutesAgo`.   

So this object structure contains all the information logically arranged where you would expect it to be. Also, it harbors methods to manipulate Domoticz or devices. dzVents will create the commandArray contents for you and all you have to do is something like `domoticz.devices[123].switchOn().for_min(5).after_sec(10)` or `domoticz.devices['My dummy sensor'].updateBarometer(1034, domoticz.BARO_THUNDERSTORM)`.

*The intention is that you don't have to construct low-level commandArray-commands for Domoticz anymore!* Please let me know if there is anything missing there. Of course there is a method `domotiz.sendCommand(..)` that allows you to send raw Domoticz commands in case there indeed is some update function missing.

This is the total structure/api of the **domoticz** object:

 - **security**: Holds the state of the security system e.g. `Armed Home` or `Armed Away`.
 - **time**:
	 - **isDayTime**
	 - **isNightTime**
	 - **sunriseInMinutes**
	 - **sunsetInMinutes**
 - **sendCommand(command, value)**: *Function*. Generic command method (adds it to the commandArray) to the list of commands that are being sent back to domoticz. *There is likely no need to use this directly. Use any of the device methods instead (see below).*
 - **notify(subject, message, priority, sound)**: *Function*. Send a notification (like Prowl). Priority can be like `domoticz.PRIORITY_LOW, PRIORITY_MODERATE, PRIORITY_NORMAL, PRIORITY_HIGH, PRIORITY_EMERGENCY`. Sound can be like `domoticz.SOUND_DEFAULT, domoticz.SOUND_BIKE, etc.`
 - **email(subject, message, mailTo)**: *Function*. Send email.
 - **openURL(url)**: *Function*. Have Domoticz 'call' a URL.
 - **setScene(scene, value)**: *Function*. E.g. `domoticz.setScene('My scene', 'On')`. Supports timing options. See below.
 - **switchGroup(group, value)**: *Function*. E.g. `domoticz.switchGroup('My group', 'Off')`. Supports timing options. See below.
 - **fetchHttpDomoticzData**: *Function*. This will trigger a script that will download the device data from Domoticz and stores this on the filesystem for dzVents to use. This data contains information like battery level and device type information that can only be fetched through an http call. Normally dzVents will do this automatically in the background if it is enabled in the `dzVents_settings.lua` file. If you want to do this manually through an event script perhaps (you can use a switch trigger for instance) then you can disable the automatic fetching by changing the setting in `dzVents_settings.lua` and create your own event.
 - **devices**: a table with all the *device objects*. You can get a device by its name or id: `domoticz.devices[123]` or `domoticz.devices['My switch']`. See **Device object** below.
 - **changedDevices**: a table holding all the devices that have been updated in this cycle.
 - **variables**: a table holding all the user *variable objects* as defined in Domoticz. See **Variable object** for the attributes.  
 - **PRIORITY_LOW**: Constant for notification priority.
 - **PRIORITY_MODERATE**: Constant for notification priority.
 - **PRIORITY_NORMAL**: Constant for notification priority.
 - **PRIORITY_HIGH**: Constant for notification priority.
 - **PRIORITY_EMERGENCY**: Constant for notification priority.
 - **HUM_NORMAL**: Constant for humidity status.
 - **HUM_COMFORTABLE**: Constant for humidity status.
 - **HUM_DRY**: Constant for humidity status.
 - **HUM_WET**: Constant for humidity status.
 - **BARO_STABLE**:  Constant for barometric forecast.
 - **BARO_SUNNY**:  Constant for barometric forecast.
 - **BARO_CLOUDY**:  Constant for barometric forecast.
 - **BARO_UNSTABLE**:  Constant for barometric forecast.
 - **BARO_THUNDERSTORM**:  Constant for barometric forecast.
 - **BARO_UNKNOWN**:  Constant for barometric forecast.
 - **BARO_CLOUDY_RAIN**:  Constant for barometric forecast.
 - **ALERTLEVEL_GREY**: Constant for alert sensors.
 - **ALERTLEVEL_GREEN**: Constant for alert sensors.
 - **ALERTLEVEL_YELLOW**: Constant for alert sensors.
 - **ALERTLEVEL_ORANGE**: Constant for alert sensors.
 - **ALERTLEVEL_RED**: Constant for alert sensors.
 - **SECURITY_DISARMED**: Constant for security state
 - **SECURITY_ARMEDAWAY**: Constant for security state
 - **SECURITY_ARMEDHOME**: Constant for security state

**Device object:**

 - **name**: String. Name of the device
 - **id**: Number. Id of the device
 - **changed**: Boolean. True if the device was changed
 - **lastUpdate**: 
	 - **raw**: String. Generated by Domoticz
	 - **year**: Number
	 - **month**: Number
	 - **day**: Number
	 - **hour**: Number
	 - **min**: Number
	 - **sec**: Number
	 - **isToday**: Boolean. Indicates if the device was updated today
	 - **minutesAgo**: Number. Number of minutes since the last update.
 - **state**: String. For switches this holds the state like 'On' or 'Off'. For dimmers that are on, it is also 'On' but there is a level
attribute holding the dimming level. **For selector switches** (Dummy switch) the state holds the *name* of the currently selected level. The corresponding numeric level of this state can be found in the **rawData** attribute: `device.rawData[1]`.
 - **bState**: Boolean. Is true for some commong states like 'On' or 'Open' or 'Motion'. 
 - **Level**: Number. For dimmers and other 'Set Level..%' devices this holds the level like selector switches.
 - **rawData**: *Table*:  Not all information from a device is available as a named attribute on the device object. That is because Domoticz doesn't provide this as such. If you have a multi-sensor for instance then you can find all data points in this **rawData** attribute. It is an array (Lua table). E.g. to get the Lux value of a sensor you can do this: `local lux = mySensor.rawData[1]` (assuming it is the first value that is passed by Domoticz).
 - **batteryLevel**: Number (note this is the raw value from Domoticcz and can be 255)
 - **signalLevel**: String. See Domoticz devices table in Domoticz GUI.
 - **deviceSubType**: String. See Domoticz devices table in Domoticz GUI.
 - **deviceType**: String. See Domoticz devices table in Domoticz GUI.
 - **hardwareName**: String. See Domoticz devices table in Domoticz GUI.
 - **hardwareId**: Number. See Domoticz devices table in Domoticz GUI.
 - **hardwareType**: String. See Domoticz devices table in Domoticz GUI.
 - **hardwareTypeVal**: Number. See Domoticz devices table in Domoticz GUI.
 - **switchType**: String. See Domoticz devices table in Domoticz GUI.
 - **switchTypeValue**: Number. See Domoticz devices table in Domoticz GUI.
 - **< device_attribute >**: All sensor attributes like *temperature* or *humidity* are available on the device object. E.g.: `domoticz.device['My sensor'].temperature`.
 - **setState(newState)**: *Function*. Generic update method for switch-like devices. E.g.: device.setState('On'). Supports timing options. See below.
 - **attributeChanged(attributeName)**: *Function*. Returns  a boolean (true/false) if the attribute was changed in this cycle. E.g.
`device.attributeChanged('temperature')`.
 - **switchOn()**: *Function*.  Switch device on if it supports it. Supports timing options. See below.
 - **switchOff()**: *Function*.  Switch device off it is supports it. Supports timing options. See below.
 - **dimTo(percentage)**: *Function*.  Switch a dimming device on and/or dim to the specified level. Supports timing options. See below.
 - **switchSelector(level)**:  *Function*. Switches a selector switch to a specific level (numeric value, see the edit page in Domoticz for such a switch to get a list of the values). Supports timing options. See below.
 - **open()**: *Function*.  Set device to Open if it supports it. Supports timing options. See below.
 - **close()**: *Function*.  Set device to Close if it supports it. Supports timing options. See below.
 - **activate()**: *Function*.  Activate the device if it supports it. Supports timing options. See below.
 - **deactive()**: *Function*.  Deactivate the device if it supports it. Supports timing options. See below.
 - **update(< params >)**: *Function*. Generic update method. Accepts any number of parameters that will be sent back to Domoticz. There is no need to
pass the device.id here. It will be passed for you. Example to update
a temperature: `device.update(0,12)`. This will eventually result in
a commandArray entry `['UpdateDevice']='<idx>|0|12'`
 - **updateTemperature(temperature)**: *Function*. Update temperature sensor.
 - **updateHumidity(humidity, status)**: *Function*. Update humidity. status can be domoticz.HUM_NORMAL, HUM_COMFORTABLE, HUM_DRY, HUM_WET 
 - **updateBarometer(pressure, forecast)**: *Function*. Update barometric pressure. Forecast can be domoticz.BARO_STABLE, BARO_SUNNY,
BARO_CLOUDY, BARO_UNSTABLE, BARO_THUNDERSTORM, BARO_UNKNOWN,
BARO_CLOUDY_RAIN 
 - **updateTempHum(temperature, humidity, status)**: *Function*. For status options see updateHumidity.
 - **updateTempHumBaro(temperature, humidity, status, pressure, forecast)**: *Function*. 
 - **updateRain(rate, counter)**: *Function*. Update rain sensor.
 - **updateWind(bearing, direction, speed, gust, temperature, chill)**: *Function*. 
 - **updateUV(uv)**: *Function*. 
 - **updateCounter(value)**: *Function*. 
 - **updateElectricity(power, energy)**: *Function*. 
 - **updateP1(sage1, usage2, return1, return2, cons, prod)**: *Function*. 
 - **updateAirQuality(quality)**: *Function*. 
 - **updatePressure(pressure)**: *Function*. 
 - **updatePercentage(percentage)**: *Function*. 
 - **updateGas(usage)**: *Function*. 
 - **updateLux(lux)**: *Function*. 
 - **updateVoltage(voltage)**: *Function*. 
 - **updateText(text)**: *Function*. 
 - **updateAlertSensor(level, text)**: *Function*. Level can be domoticz.ALERTLEVEL_GREY, ALERTLEVEL_GREE, ALERTLEVEL_YELLOW,
ALERTLEVEL_ORANGE, ALERTLEVEL_RED
 - **updateDistance(distance)**: *Function*.

**"Hey!! I don't see my sensor readings in the device object!! Where is my LUX value for instance?"**
That may be because Domoticz doesn't pass all the device data as named attributes. If you cannot find your attribute then you can inspect the **rawData** attribute of the device. This is a table (array) of values. So for a device that has a Lux value you may access it like this:

    local lux = mySensor.rawData[0]
Other devices may have more stuff in the rawData attribute like wind direction, energy info etc etc.


**Variable object**:

 - **value**: Raw value coming from Domoticz
 - **nValue**: Number. **value** cast to number.
 - **set(value)**: *Function*. Tells Domoticz to update the variable. *No need to cast it to a string first (it will be done for you).*
 - **lastUpdate**: 
	 - **raw**: String. Generated by Domoticz
	 - **year**: Number
	 - **month**: Number
	 - **day**: Number
	 - **hour**: Number
	 - **min**: Number
	 - **sec**: Number
	 - **isToday**: Boolean. Indicates if the device was updated today
	 - **minutesAgo**: Number. Number of minutes since the last update.

**Switch timing options**
To specify a duration or a delay for the various switch command you can do this:

    -- switch on for 2 minutes after 10 seconds
    device.switchOn().after_sec(10).for_min(2) 
    
    -- switch on for 2 minutes after a randomized delay of 1-10 minutes
    device.switchOff().within_min(10).for_min(2) 
    device.close().for_min(15)
    device.open().after_sec(20)
    device.open().after_min(2)

 - **after_sec(seconds)**
 - **after_min(minutes)**
 - **for_min(minutes)**
 - **within_min(minutes)**

Note that **dimTo()** doesn't support **duration()**.

That's all there is to it. 

If you don't want to rewrite all your scripts at once you can have dzVents live along side your other scripts. The do not influence each other at all. You can move your scripts over one by one as you see fit to the scripts folder dzVents uses.

Oh, this code is tested on a linux file system. It should work on Windows. Let me know if it doesn't. There is some code in event_helpers.lua that is need to get a list of all the script in the scripts folder. 

Another note: I haven't tested all the various `device.update*` methods. Please let me know if I made any mistakes there or fix them yourselves and create a pull request (or email me) in GitHub.

Good luck and hopefully you enjoy using dzVents.

- Danny Bloemendaal, danny at bloemeland dot nl