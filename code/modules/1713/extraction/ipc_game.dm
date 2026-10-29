// Host injection is explicit. No key file, external process or network is opened.
/obj/map_metadata/extraction_survival
	var/tmp/datum/extraction_ipc_service/bot_ipc
	var/tmp/datum/extraction_ipc_spool/bot_spool

/obj/map_metadata/extraction_survival/proc/configure_bot_ipc(secret, enabled = FALSE)
	if (bot_ipc || !istext(secret) || length(secret) < 32 || length(secret) > 4096 || !islist(extraction_crypto_bytes(secret))) return FALSE
	bot_ipc = new(accounts.store)
	bot_ipc.key = secret
	bot_ipc.enabled = enabled == TRUE
	bot_ipc.economic_adapter = new /datum/extraction_ipc_economy(accounts)
	return !bot_ipc.enabled || bot_ipc.ready()

/obj/map_metadata/extraction_survival/proc/configure_bot_spool(directory, enabled = FALSE)
	if (!bot_ipc || bot_spool) return FALSE
	var/datum/extraction_ipc_spool/adapter = new(bot_ipc)
	adapter.root = directory
	if (!adapter.valid_root()) return FALSE
	adapter.enabled = enabled == TRUE
	bot_spool = adapter
	return !adapter.enabled || adapter.ready()

/obj/map_metadata/extraction_survival/proc/link_discord(mob/living/human/H)
	if (!owned(H) || H.stat != CONSCIOUS || !H.client) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (H.client.ckey != S.owner || S.transitioning || S.profile["state"] != "home" || !S.house || !S.house.Adjacent(H)) return FALSE
	if (!bot_ipc?.enabled || !bot_ipc.ready())
		to_chat(H, "Discord account linking is unavailable on this server.")
		return FALSE
	if (bot_ipc.profile["owners"][S.owner])
		to_chat(H, "Your safe-house account is already linked to Discord.")
		return FALSE
	if (!save_home(S)) return FALSE
	var/list/challenge = bot_ipc.issue_challenge(S.owner)
	if (!islist(challenge))
		to_chat(H, "A linking code could not be issued. Try again later.")
		return FALSE
	to_chat(H, "Complete safe-house linking with the Discord bot within five minutes. Challenge: [challenge["challenge_id"]] Proof: [challenge["proof"]]")
	return TRUE
