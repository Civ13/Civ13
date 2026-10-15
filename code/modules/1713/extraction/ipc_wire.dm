// Disabled transport helpers. Unix seconds are decimal text, never a DM float.
/proc/extraction_ipc_time(value)
	if (!istext(value) || !length(value) || length(value) > 10 || (length(value) > 1 && copytext(value, 1, 2) == "0")) return null
	var/days = 0
	var/seconds = 0
	for (var/i = 1, i <= length(value), i++)
		var/digit = text2ascii(value, i) - 48
		if (digit < 0 || digit > 9) return null
		seconds = seconds * 10 + digit
		days = days * 10 + round(seconds / 86400)
		seconds %= 86400
	return list(days, seconds)

/proc/extraction_ipc_elapsed(list/later, list/earlier)
	if (!islist(later) || !islist(earlier)) return null
	var/day_difference = later[1] - earlier[1]
	if (abs(day_difference) > 1) return day_difference > 0 ? 172800 : -172800
	return day_difference * 86400 + later[2] - earlier[2]

/proc/extraction_ipc_time_text(list/time)
	if (!islist(time) || length(time) != 2 || !isnum(time[1]) || !isnum(time[2]) || time[1] < 0 || time[1] > 115740 || time[2] < 0 || time[2] >= 86400 || round(time[1]) != time[1] || round(time[2]) != time[2]) return null
	var/day_text = "[time[1]]"
	var/carry = time[2]
	var/result = ""
	for (var/i = length(day_text), i >= 1, i--)
		var/value = (text2ascii(day_text, i) - 48) * 86400 + carry
		result = "[value % 10][result]"
		carry = round(value / 10)
	while (carry > 0)
		result = "[carry % 10][result]"
		carry = round(carry / 10)
	while (length(result) > 1 && copytext(result, 1, 2) == "0") result = copytext(result, 2)
	return result

/proc/extraction_ipc_calendar(value)
	if (!istext(value) || length(value) != 19 || copytext(value, 5, 6) != "-" || copytext(value, 8, 9) != "-" || copytext(value, 11, 12) != " " || copytext(value, 14, 15) != ":" || copytext(value, 17, 18) != ":") return null
	for (var/i = 1, i <= 19, i++)
		if (i in list(5, 8, 11, 14, 17)) continue
		var/digit = text2ascii(value, i)
		if (digit < 48 || digit > 57) return null
	var/year = text2num(copytext(value, 1, 5))
	var/month = text2num(copytext(value, 6, 8))
	var/day = text2num(copytext(value, 9, 11))
	var/hour = text2num(copytext(value, 12, 14))
	var/minute = text2num(copytext(value, 15, 17))
	var/second = text2num(copytext(value, 18, 20))
	if (year < 1970 || year > 2100 || month < 1 || month > 12 || hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) return null
	var/list/month_days = list(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
	if (!(year % 4) && ((year % 100) || !(year % 400))) month_days[2] = 29
	if (day < 1 || day > month_days[month]) return null
	var/days = day - 1
	for (var/current = 1970, current < year, current++) days += 365 + !!(!(current % 4) && ((current % 100) || !(current % 400)))
	for (var/current = 1, current < month, current++) days += month_days[current]
	return list(days, hour * 3600 + minute * 60 + second)

/proc/extraction_ipc_now()
	return extraction_ipc_clock(time2text(world.realtime, "YYYY-MM-DD hh:mm:ss", 0), world.timeofday)

/proc/extraction_ipc_after(value, seconds)
	var/list/time = extraction_ipc_time(value)
	if (!islist(time) || !isnum(seconds) || round(seconds) != seconds || seconds < 0 || seconds > 3600) return null
	time[2] += seconds
	if (time[2] >= 86400)
		time[2] -= 86400
		time[1]++
	return extraction_ipc_time_text(time)

/proc/extraction_ipc_clock(coarse_text, precise_ticks)
	var/list/coarse = extraction_ipc_calendar(coarse_text)
	if (!islist(coarse) || !isnum(precise_ticks) || precise_ticks < 0 || precise_ticks >= 864000) return null
	var/seconds = round(precise_ticks / 10)
	// Rounded realtime can select the adjacent day around midnight. The precise
	// UTC time-of-day determines which side of that midnight the date belongs to.
	var/difference = seconds - coarse[2]
	if (difference < -43200) coarse[1]++
	else if (difference > 43200) coarse[1]--
	coarse[2] = seconds
	return extraction_ipc_time_text(coarse)

/proc/extraction_ipc_equal(left, right)
	if (!istext(left) || !istext(right) || length(left) != 64 || length(right) != 64) return FALSE
	var/difference = 0
	for (var/i = 1, i <= 64, i++) difference |= text2ascii(left, i) ^ text2ascii(right, i)
	return difference == 0

/proc/extraction_ipc_base64_encode(list/bytes)
	if (!islist(bytes) || length(bytes) > 65536) return null
	var/alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	var/output = ""
	for (var/i = 1, i <= length(bytes), i += 3)
		var/a = bytes[i]
		var/b = i + 1 <= length(bytes) ? bytes[i + 1] : 0
		var/c = i + 2 <= length(bytes) ? bytes[i + 2] : 0
		var/first = (a >> 2) + 1
		var/second = (((a & 3) << 4) | (b >> 4)) + 1
		var/third = (((b & 15) << 2) | (c >> 6)) + 1
		var/fourth = (c & 63) + 1
		output += copytext(alphabet, first, first + 1) + copytext(alphabet, second, second + 1)
		output += i + 1 <= length(bytes) ? copytext(alphabet, third, third + 1) : "="
		output += i + 2 <= length(bytes) ? copytext(alphabet, fourth, fourth + 1) : "="
	return output

/proc/extraction_ipc_base64_decode(value, limit = 8192)
	if (!istext(value) || !length(value) || length(value) % 4 || length(value) > ((limit + 2) / 3) * 4) return null
	var/alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	var/list/bytes = list()
	for (var/i = 1, i <= length(value), i += 4)
		var/list/parts = list()
		for (var/j = 0, j < 4, j++)
			var/character = copytext(value, i + j, i + j + 1)
			if (character == "=")
				if (i + 3 != length(value) || j < 2) return null
				parts += 0
			else
				var/index = findtextEx(alphabet, character)
				if (!index) return null
				parts += index - 1
		bytes += (parts[1] << 2) | (parts[2] >> 4)
		if (copytext(value, i + 2, i + 3) != "=") bytes += ((parts[2] & 15) << 4) | (parts[3] >> 2)
		if (copytext(value, i + 3, i + 4) != "=") bytes += ((parts[3] & 3) << 6) | parts[4]
	if (length(bytes) > limit || extraction_ipc_base64_encode(bytes) != value) return null
	return bytes

/proc/extraction_ipc_verify(wire, key, now_text, direction = "request")
	if (!istext(wire) || length(wire) > 12000 || !istext(key) || length(key) < 32 || length(key) > 4096 || !(direction in list("request", "reply"))) return null
	// Exact compact envelope emitted by AsyncSpool; extra or duplicate fields fail.
	var/prefix = "{\"protocol\":\"civ13.safehouse.ipc.v1\",\"issued_at\":"
	if (copytext(wire, 1, length(prefix) + 1) != prefix) return null
	var/expires_marker = ",\"expires_at\":"
	var/body_marker = ",\"body\":\""
	var/expires_start = findtextEx(wire, expires_marker, length(prefix) + 1)
	var/body_start = findtextEx(wire, body_marker, expires_start + 1)
	if (!expires_start || !body_start) return null
	var/issued = copytext(wire, length(prefix) + 1, expires_start)
	var/expires = copytext(wire, expires_start + length(expires_marker), body_start)
	var/list/issued_time = extraction_ipc_time(issued)
	var/list/expires_time = extraction_ipc_time(expires)
	var/list/now = extraction_ipc_time(now_text)
	if (!islist(issued_time) || !islist(expires_time) || !islist(now)) return null
	var/lifetime = extraction_ipc_elapsed(expires_time, issued_time)
	if (lifetime < 0 || lifetime > 120 || extraction_ipc_elapsed(issued_time, now) > 5 || extraction_ipc_elapsed(expires_time, now) < 0) return null
	var/list/envelope
	try
		envelope = json_decode(wire)
	catch
		return null
	if (!islist(envelope) || !istext(envelope["body"]) || !istext(envelope["mac"])) return null
	var/body = envelope["body"]
	var/mac = envelope["mac"]
	var/rebuilt = "[prefix][issued][expires_marker][expires][body_marker][replacetext(body, "/", "\\/")]\",\"mac\":\"[mac]\"}"
	if (rebuilt != wire || length(mac) != 64) return null
	var/signed = "civ13.safehouse.ipc.v1\n[direction]\n[issued]\n[expires]\n[body]"
	if (!extraction_ipc_equal(extraction_hmac_sha256(key, signed), mac)) return null
	// Parsing request JSON, digest and account binding belong to the handler.
	return extraction_ipc_base64_decode(body)

// DM represents booleans as numbers. The insurance wire contract requires
// JSON booleans, so convert only the validated projection's exact field tokens
// before signing. Persisted native receipts keep their ordinary numeric values.
/proc/extraction_ipc_reply_json(list/result)
	var/body = json_encode(result)
	if (result["action"] == "insurance.inspect" && result["status"] == "committed")
		for (var/list/E in result["data"]["entries"])
			if (!(E["found_in_raid"] in list(FALSE, TRUE))) return null
		body = replacetext(body, "\"found_in_raid\":0", "\"found_in_raid\":false")
		body = replacetext(body, "\"found_in_raid\":1", "\"found_in_raid\":true")
	return body

/proc/extraction_ipc_seal(list/bytes, key, now_text, direction = "reply")
	if (!islist(bytes) || !length(bytes) || length(bytes) > 8192 || !istext(key) || length(key) < 32 || length(key) > 4096 || !(direction in list("request", "reply")) || !islist(extraction_ipc_time(now_text))) return null
	var/body = extraction_ipc_base64_encode(bytes)
	var/expires = extraction_ipc_after(now_text, 120)
	var/mac = extraction_hmac_sha256(key, "civ13.safehouse.ipc.v1\n[direction]\n[now_text]\n[expires]\n[body]")
	if (!istext(body) || !istext(expires) || !istext(mac)) return null
	return "{\"protocol\":\"civ13.safehouse.ipc.v1\",\"issued_at\":[now_text],\"expires_at\":[expires],\"body\":\"[replacetext(body, "/", "\\/")]\",\"mac\":\"[mac]\"}"
