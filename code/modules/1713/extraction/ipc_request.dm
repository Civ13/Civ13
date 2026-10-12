// Exact Client::envelope serialization; service authentication is checked first.
/proc/extraction_ipc_identifier(value, digits_only = FALSE, limit = 96)
	if (!istext(value) || !length(value) || length(value) > limit) return FALSE
	var/alphabet = digits_only ? "0123456789" : "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
	for (var/i = 1, i <= length(value), i++)
		if (!findtextEx(alphabet, copytext(value, i, i + 1))) return FALSE
	return TRUE

/proc/extraction_ipc_request(list/bytes)
	if (!islist(bytes) || !length(bytes) || length(bytes) > 8192) return null
	var/text = ""
	for (var/value in bytes)
		if (!isnum(value) || value < 32 || value > 126 || round(value) != value) return null
		text += ascii2text(value)
	var/list/request
	try
		request = json_decode(text)
	catch
		return null
	var/list/fields = list("protocol", "request_id", "discord_id", "action", "expected_account_revision", "payload", "request_digest")
	if (!islist(request) || length(request) != length(fields)) return null
	for (var/i = 1, i <= length(fields), i++)
		if (request[i] != fields[i]) return null
	if (request["protocol"] != "civ13.safehouse.v1" || !extraction_ipc_identifier(request["request_id"]) || !extraction_ipc_identifier(request["discord_id"], TRUE, 22)) return null
	var/action = request["action"]
	if (!(action in list("link.challenge", "link.complete", "stash.inspect", "stash.detail", "room.inspect", "room.quote", "room.manage", "trade.quote", "trade.confirm", "trade.status", "market.browse", "market.list", "market.buy", "market.cancel"))) return null
	var/revision = request["expected_account_revision"]
	if (!isnull(revision) && (!isnum(revision) || revision < 0 || revision > 1000000 || round(revision) != revision)) return null
	if (isnull(revision) && (action in list("trade.quote", "trade.confirm", "market.list", "market.buy", "market.cancel", "room.quote", "room.manage"))) return null
	var/list/payload = request["payload"]
	if (!islist(payload) || length(payload) > 2) return null
	var/list/payload_fields
	switch (action)
		if ("link.challenge") payload_fields = list("challenge_id")
		if ("link.complete") payload_fields = list("challenge_id", "proof")
		if ("stash.inspect", "room.inspect") payload_fields = list("page")
		if ("stash.detail") payload_fields = list("item_id", "page")
		if ("market.browse") payload_fields = list("page")
		if ("room.quote") payload_fields = list("operation", "item_ids")
		if ("room.manage", "trade.confirm", "market.list", "market.buy", "market.cancel") payload_fields = list("confirmation_token")
		if ("trade.quote")
			if (payload["sale_kind"] in list("server_buyback", "player_listing")) payload_fields = list("item_ids", "sale_kind")
			else if (payload["sale_kind"] in list("player_purchase", "listing_cancel")) payload_fields = list("listing_id", "sale_kind")
			else return null
		if ("trade.status") payload_fields = list("operation_request_digest", "operation_request_id")
	if (length(payload) != length(payload_fields)) return null
	for (var/i = 1, i <= length(payload_fields), i++)
		var/field = payload_fields[i]
		if (!(field in payload)) return null
		if (field == "page")
			var/page_limit = action == "stash.detail" ? 31 : (action == "market.browse" ? 15 : 7)
			if (!isnum(payload[field]) || payload[field] < 0 || payload[field] > page_limit || round(payload[field]) != payload[field]) return null
		else if (field == "item_id")
			if (!extraction_ipc_identifier(payload[field], FALSE, 80)) return null
		else if (field == "operation")
			if (payload[field] != "upgrade") return null
		else if (field == "item_ids")
			var/list/ids = payload[field]
			if (!islist(ids) || !length(ids) || length(ids) > 16) return null
			var/list/seen = list()
			for (var/id in ids)
				if (!extraction_ipc_identifier(id, FALSE, 80) || seen[id]) return null
				seen[id] = TRUE
		else if (!extraction_ipc_identifier(payload[field], FALSE, 128)) return null
	var/digest = request["request_digest"]
	if (!istext(digest) || length(digest) != 64) return null
	var/list/unsigned = request.Copy()
	unsigned.Remove("request_digest")
	var/canonical = replacetext(json_encode(unsigned), "/", "\\/")
	if (!extraction_ipc_equal(extraction_sha256(canonical), digest)) return null
	// This also rejects duplicate keys, alternate escapes and numeric precision loss.
	if (replacetext(json_encode(request), "/", "\\/") != text) return null
	return request
