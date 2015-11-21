#!/usr/bin/lua

threshold=20
expire_time=10

function syslog(log)
	os.execute("logger "..log)
end

function os.capture(cmd, raw)
	local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
	if raw then return s end
	s = string.gsub(s, '^%s+', '')
	s = string.gsub(s, '%s+$', '')
	s = string.gsub(s, '[\n\r]+', ' ')
	return s
end

function values(t)
     local i = 0
     return function()
         i = i + 1
         return t[i]
     end
end

function sleep(n)
	os.execute("sleep "..n)
end

function get_signal_by_mac(mac)
        cmd_get_signal_by_mac=cmd_get_signal_head..mac..cmd_get_signal_tail
        return os.capture(cmd_get_signal_by_mac)
end

function get_snr_by_mac(mac)
	local cmd_get_snr_by_mac = cmd_get_snr_by_mac_head..mac..cmd_get_snr_by_mac_tail
	local temp= tonumber(os.capture(cmd_get_snr_by_mac))
	return temp
end

function cmp(mac)
	local current = math.abs(get_signal_by_mac(mac))
	local old     = math.abs(connected_table[mac])
	if(current > old) and (current - old) > threshold then
		return true
	else
		return	false
	end
end

function sta_is_expire(mac,snr_current)
	local time    = connected_table[mac][2]
	local expire_time = connected_table[mac][3]

	if snr_current < threshold and time >= expire_time then
		return true
	elseif snr_current < threshold then
		connected_table[mac][2] = time + interval
	elseif snr_current > threshold then
		connected_table[mac][2] = 0
	end
	return false
end

function sta_is_reassoc(mac)
	for index=1, #disassociated_array do
		if disassociated_array[index] == mac then
			return true
		end
	end
	return false
end

function disassoc_sta(mac)
	os.execute(cmd_disassoc_sta..mac)
end

function insert_sta_to_disassociated_array(mac)
	table.insert(disassociated_array,mac)
end

function rm_sta_from_tab(table,mac) -- table: connected_table or disassociated_array
	table[mac]=nil
end

connected_table = {}
disassociated_array  = {}
cmd_disassoc_sta    = "hostapd_cli -i wlan0 disassociate "
cmd_get_mac    	    = "iw dev wlan0 station dump | grep Station | awk '{print $2}'"
cmd_get_signal_head = "iw dev wlan0 station dump \| grep "
cmd_get_signal_tail = " -A 9 \| grep \"signal\:\" \| awk \'\{print $2\}\'"
cmd_get_snr_by_mac_head  = "iwinfo wlan0 assoclist | grep "
cmd_get_snr_by_mac_tail  = " \| awk '{print $8}' \| sed \'s\/\)\/\/g\'"

--[[
res = tostring(os.capture(cmd_get_mac))
for mac in string.gmatch(res,"[^%s]+") do
 	      	connected_table[mac]=get_signal_by_mac(mac)
-- 		connected_table[mac] = {get_snr_by_mac(mac),os.time()}    	
end
]]

while true do
	res = string.upper(tostring(os.capture(cmd_get_mac)))
	for mac in string.gmatch(res,"[^%s]+") do
		local snr = get_snr_by_mac(mac)
		print("mac:"..mac..",snr: "..snr)
		if snr < threshold then
			print("disassociate: "..mac)
			disassoc_sta(mac)
		end
	end
	sleep(2)
end

--[[
while true do
	res = string.upper(tostring(os.capture(cmd_get_mac)))
	for mac in string.gmatch(res,"[^%s]+") do
		if connected_table[mac] == nil then
			connected_table[mac] = get_snr_by_mac(mac)
		elseif connected_table[mac] < threshold then
			syslog("disassociate:"..mac.."because snr is "..connected_table[mac])
			disassoc_sta(mac)
			connected_table[mac]=nil
		end
	end
	sleep(5)
end
]]

-- connected_table[mac]={duration,expire_time}
--[[
while true do
	res = string.upper(tostring(os.capture(cmd_get_mac)))
	for mac in string.gmatch(res,"[^%s]+") do
		local snr = get_snr_by_mac(mac)
		if connected_table[mac] == nil and disassociated_array[mac] == nil then
			connected_table[mac]= {0,expire_time}
		elseif connected_table[mac] == nil and disassociated_array[mac] then
			connected_table[mac]= {0,expire_time}
			rm_sta_from_tab(disassociated_array,mac)
		elseif sta_is_expire(mac,snr) then
			disassoc_sta(mac)
			rm_sta_from_tab(connected_table,mac)
			table.insert(disassociated_array,mac)
		end
	end

	sleep(interval)
end
]]
