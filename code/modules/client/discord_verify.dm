// Verify Discord from inside the game.
//
// In Discord, /approveme without a ckey gives the player a private single-use
// code (CivilizationBot docs/ingame-verification.md). They type it here; BYOND
// has already signed them in, so the game vouches for the ckey and the code
// vouches for the Discord account. The game sends both to its own bot as the
// discord_verify webhook method and shows the bot's answer. A desktop bot
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

/proc/discord_verify_send(ckey, code)
	if(!webhook_enabled())
		return list("ok" = FALSE, "message" = "This server is not connected to the Discord bot. Use /approveme with your ckey in Discord instead.")
	var/query = "[config.webhook_address]?key=[url_encode(config.webhook_key)]&method=discord_verify&data=[url_encode(json_encode(list("ckey" = ckey, "code" = code)))]"
	var/list/http = world.Export(query)
	var/body = null
	if(islist(http) && http["CONTENT"])
		body = file2text(http["CONTENT"])
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
