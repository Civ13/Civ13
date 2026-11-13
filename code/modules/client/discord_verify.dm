// Verify Discord from inside the game.
//
// In Discord, /approveme without a ckey gives the player a private single-use
// code (CivilizationBot docs/ingame-verification.md). They type it here; BYOND
// has already signed them in, so the game vouches for the ckey and the code
// vouches for the Discord account. The game POSTs both to its own bot's
// discord_verify webhook (key in a header) and shows the bot's answer. A desktop bot
// relays the request to CivilizationBot, which does the actual registration.
// The link reaches this world with the next verified-list refresh.

#define DISCORD_VERIFY_COOLDOWN (10 SECONDS)

/client/var/tmp/discord_verify_next = 0
/client/var/tmp/discord_verify_busy = FALSE

// "abcd efgh" or "ABCD-EFGH" -> "ABCDEFGH"; null if it cannot be a code.
// Same alphabet as the bot: no 0/O or 1/I.
/proc/discord_verify_clean_code(code)
	if(!istext(code) || length(code) > 32)
		return null
	var/clean = uppertext(replacetext(replacetext(replacetext(code, " ", ""), "-", ""), "\t", ""))
	var/regex/valid = regex(@"^[A-HJ-NP-Z2-9]{8}$")
	if(valid.Find(clean))
		return clean
	return null

// The bot's answer as list("ok" = TRUE/FALSE, "message" = text). Never null.
/proc/discord_verify_parse_answer(body)
	var/list/answer = null
	if(istext(body) && length(body) <= 4096)
		try
			answer = json_decode(body)
		catch(var/exception/e)
			if(e) // bad JSON is a runtime in BYOND
				answer = null
	if(!islist(answer) || !istext(answer["message"]) || !length(answer["message"]))
		return list("ok" = FALSE, "message" = "The Discord bot did not answer. Try again in a minute, or use /approveme with your ckey in Discord.")
	return list("ok" = !!answer["ok"], "message" = copytext(answer["message"], 1, 401))

// Where to POST: WEBHOOK_ADDRESS + "/discord_verify", only when that address is
// loopback or https. The request carries the webhook key and a live code, so it
// never crosses a network in clear. Null otherwise.
/proc/discord_verify_endpoint(address)
	if(!istext(address) || length(address) > 2048)
		return null
	var/regex/safe = regex(@"^(https:/{2}[^\s/?#@]+|http:/{2}(127\.0\.0\.1|localhost|\[::1\])(:[0-9]+)?)(/[^\s?#]*)?$", "i")
	if(!safe.Find(address))
		return null
	var/regex/trailing = regex(@"/+$")
	address = trailing.Replace(address, "")
	return address + "/discord_verify"

// POST with the key in a header and ckey + code in the JSON body, so neither
// secret is ever part of a URL that a proxy or access log could keep.
/proc/discord_verify_send(ckey, code)
	if(!webhook_enabled())
		return list("ok" = FALSE, "message" = "This server is not connected to the Discord bot. Use /approveme with your ckey in Discord instead.")
	var/url = discord_verify_endpoint(config.webhook_address)
	if(!url)
		return list("ok" = FALSE, "message" = "Verifying from this server is not set up securely yet. Use /approveme in Discord instead.")
	var/datum/http_request/request = new
	request.prepare(RUSTG_HTTP_METHOD_POST, url, json_encode(list("ckey" = ckey, "code" = code)), list("Content-Type" = "application/json", "X-Webhook-Key" = config.webhook_key))
	request.begin_async()
	var/deadline = world.timeofday + 150
	while(!request.is_complete())
		if(world.timeofday > deadline || world.timeofday < deadline - 300) // midnight rollover
			break
		sleep(1)
	var/body = null
	if(request.is_complete())
		var/datum/http_response/response = request.into_response()
		if(response && !response.error)
			body = response.body
	return discord_verify_parse_answer(body)

/client/verb/verify_discord()
	set name = "Verify Discord"
	set category = "OOC"
	set desc = "Link this BYOND account to your Discord account with a code from /approveme."
	if(IsGuestKey(key))
		to_chat(src, "<span class='warning'>Guest accounts cannot be verified. Sign in to BYOND first.</span>")
		return
	if(verified_discord_id(ckey))
		to_chat(src, "<span class='notice'>This BYOND account is already linked to Discord.</span>")
		return
	if(discord_verify_busy)
		return
	if(world.time < discord_verify_next)
		to_chat(src, "<span class='warning'>Wait a few seconds before trying another code.</span>")
		return
	var/code = input(src, "In the Civ13 Discord, run /approveme and leave the ckey empty. CivilizationBot sends you a private code like ABCD-EFGH. Type it here.\n\nNever type a code someone else gave you: it would link your BYOND account to their Discord.", "Verify Discord") as text|null
	if(!code)
		return
	var/clean = discord_verify_clean_code(code)
	if(!clean)
		to_chat(src, "<span class='warning'>That is not a verification code. Codes are eight letters and digits, like ABCD-EFGH.</span>")
		return
	discord_verify_busy = TRUE
	discord_verify_next = world.time + DISCORD_VERIFY_COOLDOWN
	to_chat(src, "<span class='notice'>Checking your code with the Discord bot...</span>")
	var/player_ckey = ckey
	var/list/answer = discord_verify_send(player_ckey, clean)
	if(!src)
		return
	discord_verify_busy = FALSE
	log_admin("[player_ckey] used Verify Discord: [answer["ok"] ? "verified" : "refused"].")
	to_chat(src, "<span class='[answer["ok"] ? "good" : "warning"]'>[html_encode(answer["message"])]</span>")

#undef DISCORD_VERIFY_COOLDOWN
