local function Time(sDate)
	local today = os.date('*t')
	local time = {}
	if (sDate ~= nil and sDate ~= '') then
		local y,mon,d,h,min,s = string.match(sDate, "(%d+)%-(%d+)%-(%d+)% (%d+):(%d+):(%d+)")
		local d = os.time{year=y,month=mon,day=d,hour=h,min=min,sec=s }
		time = os.date('*t', d)

		time.raw = sDate
		time.isToday = (today.year == time.year and
				today.month==time.month and
				today.day==time.day)

		-- calculate how many minutes that was from now
		local tToday = os.time{
			day=today.day,
			year=today.year,
			month=today.month,
			hour=today.hour,
			min=today.min,
			sec=today.sec
		}

		local diff = math.floor((os.difftime(tToday, d) / 60))

		time['minutesAgo'] = diff
		time['secondsAgo'] = diff * 60
		time['hoursAgo'] = math.floor(diff / 60)
	end

	local self = time
	self['current'] = today

	return self
end

return Time