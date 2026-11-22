// Join-screen relay for CivilizationBot's lobby channel (Val, 2026-11-17).
//
// - Lobby chat (new_player Say, new_player.dm) goes out as "lobbymessage".
// - Messages typed in the Discord lobby channel arrive in SQL/discord2lobby.txt
//   (world.dm messaging loop) and show only to players on the join screen.
// - Arrival lines: a short public notice when someone settles on the join
//   screen, and another when that same player then enters the world.
//
// Only a world with its own webhook posts (webhook_enabled). People taken
// straight back to their character, travellers arriving from another region
// and staff hidden under a fake key never get a notice, since they are not on
// the join screen a few seconds after logging in. The first minutes after the
// round starts are skipped because everyone reconnecting after a restart lands
// on the join screen at once.
#define LOBBY_RELAY_SETTLE 50 // deciseconds a player must stay on the join screen
#define LOBBY_RELAY_COOLDOWN 6000 // deciseconds between join-screen notices per ckey
#define LOBBY_RELAY_QUIET_START 3000 // deciseconds after world start with no notices

var/global/list/lobby_relay_last_notice = list() // ckey = world.time of the last join-screen notice
var/global/list/lobby_relay_waiting = list() // ckey = TRUE while announced and still on the join screen

// Arrivals also carry readable text: a bot without the "kind" field (older
// CivilizationBot, e.g. the civ13.com host) relayed them as "key: (NULL)".
/proc/webhook_send_lobby_arrival(key, kind)
	var/line = kind == "entered" ? "[key] entered the world." : "[key] is on the join screen."
	var/list/query = list("ckey" = key, "kind" = kind, "message" = line)
	webhook_send("lobbymessage", query)

/proc/lobby_relay_hidden(client/C)
	return !C || (C.holder && C.holder.fakekey)

/proc/lobby_relay_arrival(mob/new_player/P)
	if (!webhook_enabled() || QDELETED(P) || !P.client || P.client.mob != P)
		return FALSE
	if (!ticker || ticker.current_state != GAME_STATE_PLAYING || world.time < LOBBY_RELAY_QUIET_START)
		return FALSE
	var/client/C = P.client
	if (lobby_relay_hidden(C))
		return FALSE
	var/last = lobby_relay_last_notice[C.ckey]
	if (!isnull(last) && world.time - last < LOBBY_RELAY_COOLDOWN)
		lobby_relay_waiting[C.ckey] = TRUE
		return FALSE
	lobby_relay_last_notice[C.ckey] = world.time
	lobby_relay_waiting[C.ckey] = TRUE
	webhook_send_lobby_arrival(C.key, "join_screen")
	return TRUE

/proc/lobby_relay_entered(ckey, client/C)
	if (!ckey || !lobby_relay_waiting[ckey])
		return FALSE
	if (C && istype(C.mob, /mob/new_player))
		return FALSE // back on the join screen
	lobby_relay_waiting -= ckey // disconnected, observing or playing: one chance only
	if (!C || !isliving(C.mob))
		return FALSE
	if (!webhook_enabled() || lobby_relay_hidden(C))
		return FALSE
	webhook_send_lobby_arrival(C.key, "entered")
	return TRUE

// Discord lobby channel lines, shown to the join screen only.
/proc/discord_lobby_show(sender, msg)
	log_discord("LOBBY [sender]: [msg]")
	if (!config.ooc_allowed)
		return FALSE
	for (var/mob/new_player/P in new_player_mob_list)
		if (P.client)
			to_chat(P, CHAT_TYPED(CHAT_OOC, create_text_tag("lobby", "LOBBY:", P.client) + "<IMG src='\ref[text_tag_icons]' class='text_tag' iconstate='discord' alt='Discord'><span class='deadsay'><b>[sender]</b>:</span> [msg]"))
	return TRUE

/mob/new_player/Login()
	. = ..()
	if (!webhook_enabled())
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(lobby_relay_arrival), src), LOBBY_RELAY_SETTLE)

/mob/new_player/Logout()
	var/client/C = my_client
	var/old_ckey = C ? C.ckey : null
	. = ..()
	if (old_ckey)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(lobby_relay_entered), old_ckey, C), 5)

#undef LOBBY_RELAY_SETTLE
#undef LOBBY_RELAY_COOLDOWN
#undef LOBBY_RELAY_QUIET_START
