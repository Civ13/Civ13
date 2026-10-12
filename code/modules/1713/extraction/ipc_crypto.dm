// SHA-256 words use two 16-bit limbs: DM numbers cannot represent every uint32.
// No external processes, libraries, keys, or network effects are involved here.
/proc/extraction_crypto_bytes(text)
	if (!istext(text) || length(text) > 65536) return null
	var/list/result = list()
	for (var/i = 1, i <= length(text), i++)
		var/value = text2ascii(text, i)
		if (value < 0 || value > 127) return null
		result += value
	return result

/proc/extraction_crypto_add(list/a, list/b)
	var/low = a[2] + b[2]
	return list((a[1] + b[1] + (low >= 65536)) & 65535, low & 65535)

/proc/extraction_crypto_xor(list/a, list/b)
	return list(a[1] ^ b[1], a[2] ^ b[2])

/proc/extraction_crypto_rotate(list/a, bits)
	if (bits == 16) return list(a[2], a[1])
	if (bits > 16)
		a = list(a[2], a[1])
		bits -= 16
	// Mask before shifting, keeping intermediates below 65536.
	var/mask = (1 << bits) - 1
	return list((a[1] >> bits) | ((a[2] & mask) << (16 - bits)), (a[2] >> bits) | ((a[1] & mask) << (16 - bits)))

/proc/extraction_crypto_shift(list/a, bits)
	if (bits >= 16) return list(0, a[1] >> (bits - 16))
	return list(a[1] >> bits, (a[2] >> bits) | ((a[1] & ((1 << bits) - 1)) << (16 - bits)))

/proc/extraction_crypto_sigma(list/a, first, second, third, shift = FALSE)
	return extraction_crypto_xor(extraction_crypto_xor(extraction_crypto_rotate(a, first), extraction_crypto_rotate(a, second)), shift ? extraction_crypto_shift(a, third) : extraction_crypto_rotate(a, third))

/proc/extraction_crypto_hexword(value)
	return list(text2num(copytext(value, 1, 5), 16), text2num(copytext(value, 5, 9), 16))

/proc/extraction_sha256_bytes(list/input)
	if (!islist(input) || length(input) > 65536) return null
	var/list/message = input.Copy()
	for (var/value in message)
		if (!isnum(value) || value != round(value) || value < 0 || value > 255) return null
	var/bit_length = length(message) * 8
	message += 128
	while ((length(message) % 64) != 56) message += 0
	for (var/i = 1, i <= 4, i++) message += 0
	message += (bit_length >> 24) & 255
	message += (bit_length >> 16) & 255
	message += (bit_length >> 8) & 255
	message += bit_length & 255
	var/list/initial = list("6a09e667", "bb67ae85", "3c6ef372", "a54ff53a", "510e527f", "9b05688c", "1f83d9ab", "5be0cd19")
	var/list/constants = list("428a2f98", "71374491", "b5c0fbcf", "e9b5dba5", "3956c25b", "59f111f1", "923f82a4", "ab1c5ed5", "d807aa98", "12835b01", "243185be", "550c7dc3", "72be5d74", "80deb1fe", "9bdc06a7", "c19bf174", "e49b69c1", "efbe4786", "0fc19dc6", "240ca1cc", "2de92c6f", "4a7484aa", "5cb0a9dc", "76f988da", "983e5152", "a831c66d", "b00327c8", "bf597fc7", "c6e00bf3", "d5a79147", "06ca6351", "14292967", "27b70a85", "2e1b2138", "4d2c6dfc", "53380d13", "650a7354", "766a0abb", "81c2c92e", "92722c85", "a2bfe8a1", "a81a664b", "c24b8b70", "c76c51a3", "d192e819", "d6990624", "f40e3585", "106aa070", "19a4c116", "1e376c08", "2748774c", "34b0bcb5", "391c0cb3", "4ed8aa4a", "5b9cca4f", "682e6ff3", "748f82ee", "78a5636f", "84c87814", "8cc70208", "90befffa", "a4506ceb", "bef9a3f7", "c67178f2")
	var/list/state = list()
	var/list/keys = list()
	for (var/value in initial) state += list(extraction_crypto_hexword(value))
	for (var/value in constants) keys += list(extraction_crypto_hexword(value))
	for (var/start = 1, start <= length(message), start += 64)
		var/list/words = list()
		for (var/i = 0, i < 16, i++)
			var/position = start + i * 4
			words += list(list(message[position] * 256 + message[position + 1], message[position + 2] * 256 + message[position + 3]))
		for (var/i = 17, i <= 64, i++)
			words += list(extraction_crypto_add(extraction_crypto_add(words[i - 16], extraction_crypto_sigma(words[i - 15], 7, 18, 3, TRUE)), extraction_crypto_add(words[i - 7], extraction_crypto_sigma(words[i - 2], 17, 19, 10, TRUE))))
		var/list/a = state[1], b = state[2], c = state[3], d = state[4], e = state[5], f = state[6], g = state[7], h = state[8]
		for (var/i = 1, i <= 64, i++)
			var/list/choice = list((e[1] & f[1]) ^ ((e[1] ^ 65535) & g[1]), (e[2] & f[2]) ^ ((e[2] ^ 65535) & g[2]))
			var/list/majority = list((a[1] & b[1]) ^ (a[1] & c[1]) ^ (b[1] & c[1]), (a[2] & b[2]) ^ (a[2] & c[2]) ^ (b[2] & c[2]))
			var/list/t1 = extraction_crypto_add(extraction_crypto_add(extraction_crypto_add(h, extraction_crypto_sigma(e, 6, 11, 25)), choice), extraction_crypto_add(keys[i], words[i]))
			var/list/t2 = extraction_crypto_add(extraction_crypto_sigma(a, 2, 13, 22), majority)
			h = g
			g = f
			f = e
			e = extraction_crypto_add(d, t1)
			d = c
			c = b
			b = a
			a = extraction_crypto_add(t1, t2)
		var/list/final_words = list(a, b, c, d, e, f, g, h)
		for (var/i = 1, i <= 8, i++) state[i] = extraction_crypto_add(state[i], final_words[i])
	var/list/output = list()
	for (var/list/word in state)
		output += word[1] >> 8
		output += word[1] & 255
		output += word[2] >> 8
		output += word[2] & 255
	return output

/proc/extraction_crypto_hex(list/bytes)
	if (!islist(bytes)) return null
	var/output = ""
	var/digits = "0123456789abcdef"
	for (var/value in bytes)
		output += copytext(digits, (value >> 4) + 1, (value >> 4) + 2)
		output += copytext(digits, (value & 15) + 1, (value & 15) + 2)
	return output

/proc/extraction_sha256(text)
	return extraction_crypto_hex(extraction_sha256_bytes(extraction_crypto_bytes(text)))

/proc/extraction_hmac_sha256(key, text)
	var/list/key_bytes = extraction_crypto_bytes(key)
	var/list/message = extraction_crypto_bytes(text)
	if (!islist(key_bytes) || !islist(message) || length(key_bytes) > 4096 || length(message) > 65472) return null
	if (length(key_bytes) > 64) key_bytes = extraction_sha256_bytes(key_bytes)
	while (length(key_bytes) < 64) key_bytes += 0
	var/list/inner = list()
	var/list/outer = list()
	for (var/value in key_bytes)
		inner += value ^ 54
		outer += value ^ 92
	inner.Add(message)
	outer.Add(extraction_sha256_bytes(inner))
	return extraction_crypto_hex(extraction_sha256_bytes(outer))
