# ezVents
Simplified event system for home automation software Domoticz

About
=============
Domoticz' event system checks its script folder and calls every script it can find if the name starts with `script_device`. Even when the device hasn't changed. If you have many scripts then each call can take quite some time because Domoticz will build all the device tables for each call.

This script makes this more efficient. The idea is that there are only two script files called by Domoticz: 

* `script_device_main.lua`
* `script_time_main.lua`

Both scripts will then do the dispatching to your actual event scripts and all the Domoticz tables will be constructed only once. This will save memory and most importantly: execution time.

Note: there are two other scripts that Domoticz might call: `script_security..` and `script_variable..`. They will not be affected by this code.

Installing
=============
Copy the files `event_helpers.lua`, `script_time_main.lua`, `script_device_main.lua` and `example.lua` to the domoticz script folder
`../domoticz/scripts/lua`.
 
In that same folder create a sub folder called `scripts`. This is the folder where your event scripts will be loaded from by this code. 

Each event script is in fact a Lua module that is loaded by `script_time_main.lua` and `script_device_main.lua`. Each event script has to follow a certain structure, otherwise Lua cannot load them. The file `example.lua` has a skeleton for such a script: 


```
return {
    active = false,                  -- set to true to activate this script, 
                                     --can also be a function returning either true or false
    on = {
        'My switch',                 -- name of the device
        'My sensor_Temperature',
        'My sensor',
        258,                         -- index of the device
        ['timer'] = 'every minute',  -- causes this script to be called every minute (see below for more options)
        '*'                          -- script is always executed
    },
    
    execute = function(value, deviceName, deviceIndex)
        local commandArray = {}

        -- example
        if (value == 'On') then
            commandArray['SendNotification'] = 'I am on!'
        end

        return commandArray
    end
}
```

This module has three basic parts:

* `on`: This is a table with one or more trigger events. It is either the name of your device, the index of your device (the name may change, the index will usually stay the same), a '*' which makes the script be executed every cycle, the string or table 'timer' which makes the script execute every minute (see below). Or a **combination**. So you can put as many triggers in there as you like.
* `active`: this is a boolean value. When set to false, the script will not be called. This is handy for when you are still coding the script or when you want to disable it. You can also make this a function: `active = function() .... end`. The fuction should return a boolean of course. So for example you could check for a Domoticz variable or switch and prevent the script from being executed. **But be careful to keep the function lightweight because in every event cycle *all* the active functions will be called, even if the triggers are not met. The whole point of ezVents is that as little Lua logic is being called as possible. Only the logic for the scripts that match the triggers.**
* `execute`: This is the actual logic of your script. You can copy the code from your existing script into this section. When a device triggers the script, it will receive the value of the device, its name and index. This saves you a couple of lines of code since in most scripts you probably check for this value to begin with.

timer options
-------------
There are several options for time triggers. First, as you perhaps know, Domoticz event system only calls timer events every minute. So the smallest interval you can use for timer triggers is... you guessed it... one minute. But to prevent you from coding all kinds of timer functions, you can have all kinds of timer triggers that can all be combined for your convenience (all times are in 24hr format!):

```
on = {
    'timer'                            -- the simplest form, causes the script to be called every minute
    ['timer'] = 'every minute',        -- same as above: every minute
    ['timer'] = 'every other minute',  -- minutes: xx:00, xx:02, xx:04, ..., xx:58
    
    ['timer'] = 'every <xx> minutes',  -- starting from xx:00 triggers every xx minutes (0 > xx < 60)

    ['timer'] = 'every hour',          -- 00:00, 01:00, ..., 23:00  (24x per 24hrs)
    ['timer'] = 'every other hour',    -- 00:00, 02:00, ..., 22:00  (12x per 24hrs)
    ['timer'] = 'every <xx> hours',    -- starting from 00:00, triggers every xx hours (0 > xx < 24)
    
    ['timer'] = 'at 13:45',            -- specific time
    ['timer'] = 'at *:45',             -- every 45th minute in the hour
    ['timer'] = 'at 15:*',             -- every minute between 15:00 and 16:00
    ['timer'] = 'at 13:45 on mon,tue', -- at 13:45 only on monday en tuesday (must be english!)
    ['timer'] = 'every hour on sat',   -- you guessed it correctly
    ['timer'] = 'at sunset',           -- uses sunset/sunrise info from Domoticz
    ['timer'] = 'at sunrise',
    ['timer'] = 'at sunset on sat,sun'
    
    -- and last but not least, you can create a table with multiples:
    ['timer'] = {'at 13:45', 'at 18:37', 'every 3 minutes},

},
```
**One important note: if Domoticz for whatever reason skips a beat (skips a timer event) then you may miss the trigger! So you may have to build in some fail-safe checks or some redundancy if you have critical time-based stuff to control.**


That's all there is to it. And of course you can use this alongside what you already have in place. And slowly move your scripts over one by one.

Oh, this code is tested on a linux file system. It should work on Windows. Let me know if it doesn't. There is some code in event_helpers.lua that reads the inside of a folder. 

Good luck.

v 0.9.6
