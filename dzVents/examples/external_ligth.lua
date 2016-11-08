-- External ligth
--
-- start on event only on nigth 
-- stop in 5 to 10 minutes after last event

return {
    active = true,
    on = {
        -- switchs name's witch turn ligth on 
        'PIR Entrée',
        'Ouverture Porte Cuisine',
        'Ouverture Porte Entree',
        'Ouverture Garage',
        'Portail',
        -- periodical check if we must switch ligth off
        timer = 'every 5 minutes'
    },
    execute = function(domoticz, switch, triggerInfo)
    	-- external ligth switch name
    	local external_ligth = domoticz.devices['Eclairage Extérieur']
    	
    	-- timed event : to sitch off ligth
        if (triggerInfo.type == domoticz.EVENT_TYPE_TIMER) then
			if (external_ligth.lastUpdate.minutesAgo > 5 ) then
				external_ligth.switchOff()
			end
    	else
    	-- all other events : turn ligth on, but only on nigth !
           	if (domoticz.time.isNightTime) then
	           	external_ligth.switchOn()
			end
        end   
    end
}
