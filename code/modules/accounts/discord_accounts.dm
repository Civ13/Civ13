// Civ13 accounts keyed on Discord user IDs (docs/accounts/discord-accounts.md).
//
// An account key is "d:" followed by a Discord user ID. It can never equal a
// BYOND ckey, which holds only a-z and 0-9, so legacy ckey-keyed rows and
// account rows never collide. A client gets a Discord ID in one of two ways:
// - its ckey has a row in the verified list (SQL/approved.txt, written from
//   Civilizationbot's /approveme verifier), or
// - it joined with a launcher ticket (byond://host:port?civ13_ticket=...),
//   which the sign-in service (tools/account_signin) redeems once.
// A ticket binds only this connection: guest keys change every connect.

// Join tickets are URL-safe base64 from the sign-in service.
#define ACCOUNT_TICKET_MIN_LENGTH 32
#define ACCOUNT_TICKET_MAX_LENGTH 128

/client/var/tmp/account_ticket = null // the join-link ticket; redeemed once, never logged
/client/var/tmp/discord_id = null // set by a redeemed ticket, for this connection only

// is_discord_id(), is_account_key() and persistence_owner_valid() live in
// code/modules/persistence/player_reclaim.dm, which save fixtures build alone.

// The Discord ID behind a client: its redeemed ticket first, then the verified
// list for a real BYOND key. Guests without a ticket have none.
/proc/account_discord_id(client/C)
	if(!C) return null
	if(is_discord_id(C.discord_id)) return C.discord_id
	if(IsGuestKey(C.key)) return null
	return verified_discord_id(C.ckey)

// The key durable data should use for this client: "d:<id>" when a Discord ID
// is known, the ckey for an unlinked BYOND key, and null for an unsigned guest.
/proc/account_key(client/C)
	if(!C) return null
	var/id = account_discord_id(C)
	if(id) return "d:" + id
	if(IsGuestKey(C.key)) return null
	return C.ckey

// The ticket from a join link's topic, or null. Anything malformed is ignored.
/proc/account_ticket_from_topic(topic)
	if(!istext(topic) || !length(topic) || length(topic) > 2048) return null
	var/list/params = params2list(topic)
	var/ticket = params["civ13_ticket"]
	if(!istext(ticket) || length(ticket) < ACCOUNT_TICKET_MIN_LENGTH || length(ticket) > ACCOUNT_TICKET_MAX_LENGTH) return null
	var/static/regex/urlsafe = regex(@"^[A-Za-z0-9_-]+$")
	if(!urlsafe.Find(ticket)) return null
	return ticket

var/global/datum/account_signin/account_signin = new

// Off unless config/account_signin.json names the sign-in service's loopback
// port, its token file and this server's name:
// {"port": 47301, "token_file": "config/account-signin-token.txt", "server": "gaia"}
/datum/account_signin
	var/port = 0
	var/token = null
	var/server = null

/datum/account_signin/New()
	..()
	if(!fexists("config/account_signin.json")) return
	var/list/settings
	try
		settings = json_decode(file2text("config/account_signin.json"))
	catch
		world.log << "Account sign-in: config/account_signin.json is not valid JSON; Discord sign-in stays off."
		return
	if(!islist(settings) || !isnum(settings["port"]) || settings["port"] < 1024 || settings["port"] > 65535 || !istext(settings["token_file"]) || !istext(settings["server"]))
		world.log << "Account sign-in: config/account_signin.json needs port, token_file and server; Discord sign-in stays off."
		return
	var/name = settings["server"]
	if(!length(name) || length(name) > 64 || ckey(name) != name)
		world.log << "Account sign-in: the server name must be lowercase letters and digits; Discord sign-in stays off."
		return
	var/secret = fexists(settings["token_file"]) ? trim(file2text(settings["token_file"])) : null
	if(!istext(secret) || length(secret) < 32)
		world.log << "Account sign-in: the token file is missing or shorter than 32 characters; Discord sign-in stays off."
		return
	port = settings["port"]
	token = secret
	server = name

/datum/account_signin/proc/enabled()
	return port && token && server

// Redeems the client's join ticket once. The ticket is dropped whatever the
// answer, so it cannot be retried or logged later.
/datum/account_signin/proc/redeem(client/C)
	set waitfor = FALSE
	if(!C) return FALSE
	var/ticket = C.account_ticket
	C.account_ticket = null
	if(!ticket || !enabled()) return FALSE
	var/datum/http_request/R = new
	var/list/body = list("ticket" = ticket, "server" = server, "address" = C.address ? C.address : "127.0.0.1")
	R.prepare(RUSTG_HTTP_METHOD_POST, "http://127.0.0.1:[port]/redeem", json_encode(body), list("Content-Type" = "application/json", "X-Account-Token" = token))
	R.begin_async()
	var/deadline = world.timeofday + 50
	while(!R.is_complete())
		if(world.timeofday > deadline || world.timeofday < deadline - 100) break
		sleep(1)
	if(!R.is_complete())
		log_game("Account sign-in: the sign-in service did not answer for [key_name(C)].")
		return FALSE
	var/datum/http_response/response = R.into_response()
	var/list/answer
	if(!response.error && istext(response.body))
		try
			answer = json_decode(response.body)
		catch
			answer = null
	var/list/result = islist(answer) && answer["ok"] ? answer["result"] : null
	var/id = islist(result) ? result["discord_id"] : null
	if(!C || !is_discord_id(id))
		if(C) to_chat(C, SPAN_WARNING("Your Discord sign-in expired or was already used. Sign in again from the launcher."))
		return FALSE
	C.discord_id = id
	log_game("Account sign-in: [key_name(C)] signed in as Discord account [id].")
	to_chat(C, SPAN_NOTICE("Signed in with Discord."))
	return TRUE

#undef ACCOUNT_TICKET_MIN_LENGTH
#undef ACCOUNT_TICKET_MAX_LENGTH
