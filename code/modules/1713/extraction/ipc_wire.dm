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
