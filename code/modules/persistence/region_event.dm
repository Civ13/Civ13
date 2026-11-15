// Event regions (shard kind EVENT, docs/event-regions.md). An admin can send
// everyone, or chosen players, from their home land to an event region. Their
// home character is kept whole in its land while they are away: it is taken out
// of play into a hidden event stash on the tile where it stood, saved with the
// world, and frozen (no needs, no food going off), so nobody can see, hurt or
// rob it. When they come back, by an admin's send-back, the event's Leave Event
// verb or simply rejoining their land, the character steps out exactly as it
// was, where it stood or, if the admin chose so, beside its assigned bed (where
// it stood when it has no usable bed). Nobody lives in an event region: it never
// saves and keeps no homes, like the TDM Barracks.
//
// The worlds talk over loopback with the group's config/event-token.txt, which
// scripts/shard-group/shard_group.py setup writes when the group has an EVENT
// region. The home world tells the event world where each player came from; the
// event world tells each home world how to return them.

#define EVENT_RETURN_SPOT "spot"
#define EVENT_RETURN_BED "bed"
#define EVENT_ORIGINS_FILE "data/event_origins.json"

var/global/datum/region_event/region_event = new
// Every event stash in this world (built or loaded), so nothing walks the world for them.
var/global/list/event_stash_registry = list()

/datum/region_event
	var/configured = FALSE
	var/token = null
	// Event world only: ckey -> home region id, from the home worlds' arrival notes.
	var/list/origins = list()
	var/origins_loaded = FALSE

/datum/region_event/proc/configure()
	configured = TRUE
	token = null
	if(!shard_group.enabled || !fexists("config/event-token.txt") || length(file("config/event-token.txt")) > 128)
		return FALSE
	var/value = trim(file2text("config/event-token.txt"))
	if(length(value) < 16)
		return FALSE
	token = value
	return TRUE

/datum/region_event/proc/ready()
	if(!configured)
		configure()
	return !!token

/proc/region_event_world()
	return shard_group.enabled && shard_group.kind == "EVENT"

/proc/region_event_peer(id)
	if(!shard_group.enabled || !istext(id)) return FALSE
	var/list/peer = shard_group.peers[id]
	return islist(peer) && peer["kind"] == "EVENT"

// The group's event regions, as id -> name.
/proc/region_event_peers()
	. = list()
	if(!shard_group.enabled) return
	for(var/id in shard_group.order)
		var/list/peer = shard_group.peers[id]
		if(peer["kind"] == "EVENT")
			.[id] = peer["name"]

// Sends one message to a peer world over loopback. Wakes it first when asked.
// Returns the decoded reply, or null.
/datum/region_event/proc/tell(id, message, list/fields, wake = TRUE)
	if(!ready()) return null
	var/list/peer = shard_group.peers[id]
	if(!peer) return null
	if(peer["state"] != "UP")
		shard_group.poll_peer(id)
	if(peer["state"] != "UP")
		// A frozen world would hold this world on the connection until it thaws.
		if(!wake || shard_group.wake_peer(id)) return null
	var/list/query = list("[message]" = 1, "token" = token, "format" = "json")
	for(var/key in fields)
		query[key] = fields[key]
	var/answer = null
	try
		answer = world.Export("byond://[shard_group.peer_address(peer)]?[list2params(query)]")
	catch
		answer = null
	if(!istext(answer)) return null
	var/list/reply = null
	try
		reply = json_decode(answer)
	catch
		reply = null
	return islist(reply) && reply["ok"] ? reply : null

// ---------------------------------------------------------------------------
// The stash: a home character taken out of play while its player is at an event.

/obj/structure/event_stash
	name = "away at an event"
	desc = "Someone who is away at an event."
	icon = null
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	invisibility = 101
	mouse_opacity = 0
	// Saved: whose character this is, the event it left for, and how it comes back.
	var/owner_ckey = null
	var/event_region = null
	var/return_mode = EVENT_RETURN_SPOT
	var/sent_realtime = 0

/obj/structure/event_stash/New()
	..()
	event_stash_registry |= src

/obj/structure/event_stash/ex_act()
	return
/obj/structure/event_stash/fire_act()
	return
/obj/structure/event_stash/bullet_act(obj/item/projectile/P, def_zone)
	return PROJECTILE_FORCE_MISS
/obj/structure/event_stash/attackby(obj/item/O, mob/user, icon_x, icon_y)
	return
/obj/structure/event_stash/attack_hand(mob/user, icon_x, icon_y)
	return
/obj/structure/event_stash/relaymove(mob/user, direction)
	return
// Never in anyone's way: /obj/structure would bounce projectiles off it.
/obj/structure/event_stash/CanPass(atom/movable/mover, turf/target, height = 0, air_group = 0)
	return TRUE
// Nothing pulls, pushes or carries it off its tile.
/obj/structure/event_stash/Move()
	return FALSE

/obj/structure/event_stash/proc/body()
	for(var/mob/living/human/H in contents)
		if(H.persistence_owner_ckey == owner_ckey && !QDELETED(H))
			return H
	return null

// Where the character steps out: beside its bed when asked and it has a usable
// one, else the tile it stood on, else the nearest safe floor close by, else
// that tile anyway (it is where the character was).
/obj/structure/event_stash/proc/return_turf(mob/living/human/H, mode)
	var/turf/spot = get_turf(src)
	if(mode == EVENT_RETURN_BED)
		var/obj/structure/bed/B = region_home_bed(owner_ckey)
		if(B && B.valid_character_bed(H))
			return get_turf(B)
	if(!spot) return null
	if(persistence_character_turf_safe(spot, H))
		return spot
	var/turf/nearest
	var/nearest_distance
	for(var/turf/T in orange(PERSISTENCE_RETURN_SEARCH_RANGE, spot))
		var/distance = get_dist(spot, T)
		if(nearest && distance >= nearest_distance) continue
		if(!persistence_character_turf_safe(T, H)) continue
		nearest = T
		nearest_distance = distance
	return nearest ? nearest : spot

// Puts the character back into play. TRUE when it stepped out.
/obj/structure/event_stash/proc/release(mode = null)
	var/mob/living/human/H = body()
	if(!mode) mode = return_mode
	var/turf/destination = H ? return_turf(H, mode) : get_turf(src)
	// Anything else that ended up inside goes back out with it.
	for(var/atom/movable/AM in contents)
		if(AM != H)
			AM.forceMove(destination ? destination : loc)
	if(H && destination)
		H.forceMove(destination)
		if(H.loc != destination)
			// Movement is held (a level save): try again on the next call.
			return FALSE
		H.dir = SOUTH
		log_game("Event: [owner_ckey]'s character [H.real_name] came back from [event_region] at [destination.x],[destination.y],[destination.z] ([mode]).")
	qdel(src)
	return H && destination ? TRUE : FALSE

/obj/structure/event_stash/Destroy()
	// Never take a character down with the stash: put whoever is inside back out.
	event_stash_registry -= src
	var/turf/T = get_turf(src)
	for(var/atom/movable/AM in contents)
		if(T) AM.forceMove(T)
	return ..()

/proc/event_stash_of(account)
	if(!istext(account)) return null
	for(var/obj/structure/event_stash/S in event_stash_registry)
		if(S.owner_ckey == account && !QDELETED(S))
			return S
	return null

/proc/event_stashes()
	. = list()
	for(var/obj/structure/event_stash/S in event_stash_registry)
		if(!QDELETED(S)) . += S

// TRUE when A is held in an event stash, at any depth: its clock is stopped.
/proc/event_stash_holds(atom/A)
	var/atom/container = A ? A.loc : null
	for(var/depth = 1, depth <= 16 && container && !isturf(container), depth++)
		if(istype(container, /obj/structure/event_stash)) return TRUE
		container = container.loc
	return FALSE

// Why a character cannot be stashed right now, or null.
/proc/event_stash_refusal(mob/living/human/H, account)
	if(!istype(H) || QDELETED(H)) return "has no character"
	if(H.stat == DEAD) return "is dead"
	if(!istext(account) || H.persistence_owner_ckey != account) return "is not playing their own character"
	if(!isturf(H.loc)) return "is inside something"
	if(H.riding || H.driver || H.driver_vehicle || H.riding_mob) return "is riding or driving"
	if(persistence_save_active()) return "cannot leave during a save"
	return null

// Takes a home character out of play into a new stash on its tile.
/proc/event_stash_character(mob/living/human/H, account, event_id, mode = EVENT_RETURN_SPOT)
	if(event_stash_refusal(H, account) || event_stash_of(account)) return null
	if(H.buckled)
		H.release_protected_sleep_buckle()
	H.stop_pulling()
	for(var/obj/item/weapon/grab/G in list(H.l_hand, H.r_hand))
		qdel(G)
	for(var/obj/item/weapon/grab/G in H.grabbed_by)
		qdel(G)
	if(H.s_active) H.s_active.close(H)
	var/obj/structure/event_stash/S = new(get_turf(H))
	S.owner_ckey = H.persistence_owner_ckey
	S.event_region = event_id
	S.return_mode = mode == EVENT_RETURN_BED ? EVENT_RETURN_BED : EVENT_RETURN_SPOT
	S.sent_realtime = world.realtime
	H.forceMove(S)
	if(H.loc != S)
		qdel(S)
		return null
	log_game("Event: [S.owner_ckey]'s character [H.real_name] is kept at [S.x],[S.y],[S.z] while they are at [event_id].")
	return S

// A player coming back to their land: the character steps out before the
// ordinary reclaim hands it over (bed_return.dm prepare_character_return needs
// it on a tile). Only once the world could hand it over at all.
/map_storage/reclaim_saved_player(mob/new_player/lobby)
	if(lobby && lobby.client && !character_recovery_unready() && !player_restoration_blocked())
		var/obj/structure/event_stash/S = event_stash_of(lobby.client.ckey)
		if(S && S.release())
			to_chat(lobby, SPAN_NOTICE("Welcome back from the event. Your character is as you left it."))
	return ..()

// ---------------------------------------------------------------------------
// Home world: sending players to an event.

/proc/region_event_name(id)
	var/list/peer = shard_group.peers[id]
	return islist(peer) ? peer["name"] : "[id]"

/proc/region_event_send(mob/requester, list/picked, event_id, mode)
	set waitfor = FALSE
	// Open the event first, so nobody waits out of play while it wakes.
	var/list/peer = shard_group.peers[event_id]
	if(!peer) return
	if(peer["state"] != "UP")
		shard_group.poll_peer(event_id)
	if(peer["state"] != "UP")
		to_chat(requester, SPAN_NOTICE("Waking [html_encode(peer["name"])] first; players are sent once it is up."))
		var/why_not = shard_group.wake_peer(event_id)
		if(why_not)
			to_chat(requester, SPAN_WARNING("Nobody was sent: [why_not]"))
			return
	var/list/sending = list()
	var/list/refused = list()
	for(var/client/C in picked)
		var/mob/living/human/H = C.mob
		if(istype(H) && H.persistence_owner_ckey == C.ckey && H.stat != DEAD)
			var/why = event_stash_refusal(H, C.ckey)
			if(why)
				refused += "[C.key] [why]"
				to_chat(H, SPAN_WARNING("You could not be sent to the event: you [why]. Ask an admin to try again."))
				continue
			if(!event_stash_character(H, C.ckey, event_id, mode))
				refused += "[C.key] could not be kept safe"
				continue
		sending += C
	if(refused.len)
		to_chat(requester, SPAN_WARNING("Not sent: [jointext(refused, "; ")]."))
	if(!sending.len) return
	log_admin("[key_name(requester)] sent [sending.len] player\s to event region [event_id] (return: [mode]).")
	message_admins("[key_name_admin(requester)] sent [sending.len] player\s to [region_event_name(event_id)].")
	// The stashes are saved with the next world save; ask for it soon.
	shard_group.request_save_soon()
	var/list/ckeys = list()
	for(var/client/C in sending) ckeys += C.ckey
	// Tell the event world where these players came from (it wakes if asleep).
	if(!region_event.tell(event_id, "event_arrive", list("origin" = shard_group.region, "ckeys" = json_encode(ckeys))))
		log_game("Event: [event_id] did not take the arrival note for [ckeys.len] player\s; it will ask the world directory instead.")
	// The requester goes last, so the whole list is sent.
	sending -= requester ? requester.client : null
	if(requester && requester.client && (requester.client.ckey in ckeys))
		sending += requester.client
	for(var/client/C in sending)
		if(!C) continue
		to_chat(C, SPAN_NOTICE("You are going to [html_encode(region_event_name(event_id))] for an event. Your character here is kept safe and unchanged until you come back."))
		region_event_link(C, event_id)

// Links one player to region id; puts their character back if the link fails.
/proc/region_event_link(client/C, id)
	set waitfor = FALSE
	var/ckey = C.ckey
	if(shard_group.send_player(C, id, TRUE)) return
	if(region_event_world()) return
	var/obj/structure/event_stash/S = event_stash_of(ckey)
	if(S && C && S.body() && C.mob == S.body())
		S.release(EVENT_RETURN_SPOT)
		to_chat(C, SPAN_WARNING("The way to the event is closed, so you stay here."))
		message_admins("Event: [ckey] could not be linked to [id]; their character stays here.")

// ---------------------------------------------------------------------------
// Event world: sending players home.

/datum/region_event/proc/load_origins()
	if(origins_loaded) return
	origins_loaded = TRUE
	if(!fexists(EVENT_ORIGINS_FILE)) return
	var/list/saved = null
	try
		saved = json_decode(file2text(EVENT_ORIGINS_FILE))
	catch
		saved = null
	if(!islist(saved)) return
	for(var/ckey in saved)
		if(istext(ckey) && istext(saved[ckey]) && (saved[ckey] in shard_group.peers))
			origins[ckey] = saved[ckey]

/datum/region_event/proc/save_origins()
	if(fexists(EVENT_ORIGINS_FILE)) fdel(EVENT_ORIGINS_FILE)
	if(origins.len) text2file(json_encode(origins), EVENT_ORIGINS_FILE)

// The land a player at this event goes home to.
/datum/region_event/proc/origin_of(ckey)
	load_origins()
	var/home = origins[ckey]
	if(istext(home) && (home in shard_group.peers) && !region_event_peer(home)) return home
	// No arrival note (they came another way): ask the world directory.
	if(transfer_bridge && transfer_bridge.enabled())
		var/list/answer = transfer_bridge.request("/account", list("ckey" = ckey, "op" = "claim"))
		if(islist(answer) && answer["ok"] && islist(answer["result"]))
			var/list/result = answer["result"]
			home = result["home"]
			if(istext(home) && (home in shard_group.peers) && !region_event_peer(home)) return home
	return (shard_group.mainland in shard_group.peers) ? shard_group.mainland : null

/proc/region_event_send_home(mob/requester, list/picked, mode)
	set waitfor = FALSE
	var/list/by_home = list()
	for(var/client/C in picked)
		var/home = region_event.origin_of(C.ckey)
		if(!home)
			to_chat(C, SPAN_WARNING("Nobody knows where your home is. Ask an admin."))
			continue
		if(!by_home[home]) by_home[home] = list()
		var/list/group = by_home[home]
		group += C
	for(var/home in by_home)
		var/list/group = by_home[home]
		var/list/ckeys = list()
		for(var/client/C in group) ckeys += C.ckey
		// The home world learns the return mode first (it wakes if asleep).
		// A null mode (Leave Event) keeps what was chosen when they left.
		if(mode && !region_event.tell(home, "event_return", list("mode" = mode, "ckeys" = json_encode(ckeys))))
			log_game("Event: [home] did not take the return note; those characters return as chosen when they left.")
		for(var/client/C in group)
			if(!C) continue
			region_event.origins -= C.ckey
			to_chat(C, SPAN_NOTICE("The event is over for you. Back to [html_encode(region_event_name(home))]!"))
			region_event_link(C, home)
	region_event.save_origins()
	if(requester)
		log_admin("[key_name(requester)] sent [picked.len] player\s home from the event ([mode]).")
		message_admins("[key_name_admin(requester)] sent [picked.len] player\s home from the event.")

/client/proc/region_event_leave()
	set name = "Leave Event"
	set category = "OOC"
	if(!region_event_world()) return
	if(WWinput(src, "Leave the event and go back to your own land?", "Leave Event", "Stay", list("Go back", "Stay")) != "Go back")
		return
	region_event_send_home(null, list(src), null)

/mob/new_player/Login()
	. = ..()
	if(!QDELETED(src) && client && client.mob == src && region_event_world())
		client.verbs |= /client/proc/region_event_leave
		to_chat(src, SPAN_NOTICE("This is an event. Nothing here is kept; your own character waits safely at home. Use Leave Event (OOC) to go back at any time."))

// ---------------------------------------------------------------------------
// The loopback messages.

/datum/world_topic/event_arrive
	keyword = "event_arrive"

/datum/world_topic/event_arrive/Run(list/input)
	if(!region_event_world() || !region_event.ready() || input["token"] != region_event.token)
		return list("ok" = 0)
	var/origin = input["origin"]
	if(!istext(origin) || !(origin in shard_group.peers) || region_event_peer(origin))
		return list("ok" = 0)
	var/list/ckeys = null
	try
		ckeys = json_decode(input["ckeys"])
	catch
		ckeys = null
	if(!islist(ckeys) || ckeys.len > 500)
		return list("ok" = 0)
	region_event.load_origins()
	for(var/account in ckeys)
		if(istext(account) && length(account) <= 64 && account == ckey(account))
			region_event.origins[account] = origin
	region_event.save_origins()
	return list("ok" = 1)

/datum/world_topic/event_return
	keyword = "event_return"

/datum/world_topic/event_return/Run(list/input)
	if(!shard_group.enabled || region_event_world() || !region_event.ready() || input["token"] != region_event.token)
		return list("ok" = 0)
	var/mode = input["mode"]
	if(!(mode in list(EVENT_RETURN_SPOT, EVENT_RETURN_BED)))
		return list("ok" = 0)
	var/list/ckeys = null
	try
		ckeys = json_decode(input["ckeys"])
	catch
		ckeys = null
	if(!islist(ckeys) || ckeys.len > 500)
		return list("ok" = 0)
	var/list/found = list()
	for(var/account in ckeys)
		var/obj/structure/event_stash/S = istext(account) ? event_stash_of(account) : null
		if(S)
			S.return_mode = mode
			found += account
	return list("ok" = 1, "found" = found)

/hook/startup/proc/region_event_startup()
	region_event.configure()
	return TRUE

#undef EVENT_ORIGINS_FILE
#undef EVENT_RETURN_SPOT
#undef EVENT_RETURN_BED
