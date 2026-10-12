// Immutable final replies use a publication marker, not a partially read file.
// Bot poll must honor .reply.pending. This transport stays disabled by default.
var/global/list/extraction_ipc_spool_owners = list()

/datum/extraction_ipc_spool
	var/enabled = FALSE
	var/root = "data/safehouse_spool/"
	var/datum/extraction_ipc_service/service
	var/busy = FALSE
	var/blocked = FALSE
	var/last_error
	var/next_poll = 0
	var/cursor = 1
	var/test_fail_at
	New(datum/extraction_ipc_service/adapter)
		..()
		service = adapter
	proc/valid_root()
		if (!istext(root) || length(root) < 6 || length(root) > 128 || copytext(root, 1, 6) != "data/" || copytext(root, length(root)) != "/" || findtext(root, "//")) return FALSE
		var/alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-/"
		for (var/i = 1, i <= length(root), i++)
			if (!findtextEx(alphabet, copytext(root, i, i + 1))) return FALSE
		return TRUE
	proc/ready()
		if (!enabled || blocked || busy || !valid_root() || !service?.ready()) return FALSE
		if (extraction_ipc_spool_owners[root] && extraction_ipc_spool_owners[root] != src) return FALSE
		if (!extraction_ipc_spool_owners[root] && length(extraction_ipc_spool_owners) >= 8) return FALSE
		extraction_ipc_spool_owners[root] = src
		return TRUE
	proc/release()
		enabled = FALSE
		if (extraction_ipc_spool_owners[root] == src) extraction_ipc_spool_owners.Remove(root)
	proc/path(id, suffix)
		if (!extraction_ipc_identifier(id, FALSE, 64) || length(id) != 64 || !(suffix in list("request", "reply", "reply.pending"))) return null
		for (var/i = 1, i <= 64, i++)
			if (!findtextEx("0123456789abcdef", copytext(id, i, i + 1))) return null
		return "[root][id].[suffix]"
	proc/read(path)
		if (!istext(path) || !fexists(path)) return null
		if (length(file(path)) > 12001) return null
		var/text = file2text(path)
		if (!istext(text) || length(text) > 12001) return null
		// Bounded transport whitespace may include Windows CRLF. The signed
		// body remains untouched; only whitespace outside the envelope is removed.
		while (length(text) && (text2ascii(text, 1) in list(9, 10, 13, 32))) text = copytext(text, 2)
		while (length(text) && (text2ascii(text, length(text)) in list(9, 10, 13, 32))) text = copytext(text, 1, length(text))
		return length(text) <= 12000 ? text : null
	proc/historical_request(wire, id)
		var/prefix = "{\"protocol\":\"civ13.safehouse.ipc.v1\",\"issued_at\":"
		if (!istext(wire) || copytext(wire, 1, length(prefix) + 1) != prefix) return null
		var/end = findtextEx(wire, ",", length(prefix) + 1)
		if (!end) return null
		var/issued = copytext(wire, length(prefix) + 1, end)
		var/list/request = extraction_ipc_request(extraction_ipc_verify(wire, service.key, issued))
		return islist(request) && extraction_sha256(request["request_id"]) == id ? request : null
	proc/recover(id)
		var/pending_path = path(id, "reply.pending")
		var/reply_path = path(id, "reply")
		var/marker = read(pending_path)
		var/list/request = historical_request(read(path(id, "request")), id)
		var/list/response = service.durable_response(request)
		if (!istext(marker) || !islist(request) || !islist(response)) return FALSE
		var/list/envelope
		try
			envelope = json_decode(marker)
		catch
			return FALSE
		if (!islist(envelope) || envelope["protocol"] != "civ13.safehouse.ipc.v1") return FALSE
		// Reuse the original signed marker, including its original expiry. No
		// uncertain economic request or expired reply gets a new time window.
		var/prefix = "{\"protocol\":\"civ13.safehouse.ipc.v1\",\"issued_at\":"
		var/end = findtextEx(marker, ",", length(prefix) + 1)
		var/issued = copytext(marker, length(prefix) + 1, end)
		var/list/bytes = extraction_ipc_verify(marker, service.key, issued, "reply")
		if (!islist(bytes) || extraction_ipc_base64_encode(extraction_crypto_bytes(json_encode(response))) != envelope?["body"]) return FALSE
		var/existing = read(reply_path)
		if (existing != marker)
			// Only an unpublished marker authorizes replacing incomplete bytes.
			if (fexists(reply_path) && !fdel(reply_path)) return FALSE
			if (!fcopy(pending_path, reply_path) || read(reply_path) != marker) return FALSE
		if (test_fail_at == "before_remove") return FALSE
		return fdel(pending_path) && !fexists(pending_path)
	proc/process(id, now_text)
		if (!ready() || !path(id, "request")) return FALSE
		if (fexists(path(id, "reply.pending"))) return recover(id)
		if (fexists(path(id, "reply"))) return TRUE
		var/wire = read(path(id, "request"))
		var/list/request = extraction_ipc_request(extraction_ipc_verify(wire, service.key, now_text))
		if (!islist(request) || extraction_sha256(request["request_id"]) != id) return FALSE
		busy = TRUE
		var/list/result = service.process_wire(wire, now_text)
		busy = FALSE
		if (!islist(result) || !(result["status"] in list("committed", "rejected"))) return FALSE
		var/list/durable = service.durable_response(request)
		if (!islist(durable) || json_encode(durable) != json_encode(result)) return FALSE
		var/sealed = extraction_ipc_seal(extraction_crypto_bytes(json_encode(result)), service.key, now_text)
		if (!istext(sealed)) return FALSE
		var/pending_path = path(id, "reply.pending")
		if (test_fail_at == "before_marker") return FALSE
		if (fexists(pending_path) || !text2file(sealed, pending_path) || read(pending_path) != sealed) return FALSE
		if (test_fail_at == "after_marker") return FALSE
		if (test_fail_at == "partial_write")
			text2file("{partial", path(id, "reply"))
			return FALSE
		return recover(id)
	proc/poll(now_text)
		if (!ready() || world.time < next_poll) return FALSE
		next_poll = world.time + 10
		if (isnull(now_text)) now_text = extraction_ipc_now()
		var/list/files = flist(root)
		if (!islist(files) || length(files) > 256)
			blocked = TRUE
			last_error = "Private spool directory missing or over capacity"
			return FALSE
		if (!length(files)) return TRUE
		if (cursor > length(files)) cursor = 1
		for (var/count = 1, count <= min(8, length(files)), count++)
			var/name = files[cursor]
			cursor = cursor >= length(files) ? 1 : cursor + 1
			if (length(name) != 72 || copytext(name, 65) != ".request") continue
			process(copytext(name, 1, 65), now_text)
		return TRUE
