// Immigration by smoke signal (Val, 2026-11-17).
//
// Whoever raises a smoke signal on the mainland is asked whether to invite
// newcomers. If they say yes, the fire is open to immigration while it stays
// lit under the open sky with someone awake near it, for up to
// IMMIGRATION_OPEN_TIME. The lobby then offers "Near <name>'s signal fire",
// naming the signaller's faction if they have one. The newcomer starts on a
// safe tile a short walk from the fire, as a nomad: nobody starts with a
// faction before joining it in play. Any player can invite.
//
// The offer ends at once when the fire goes out, is roofed over, moved,
// dismantled or deleted, and it is checked again at the moment a newcomer
// spawns, so nobody arrives at a fire that is gone.

#define IMMIGRATION_OPEN_TIME 18000 // deciseconds: 30 minutes per signal
#define IMMIGRATION_HOST_RANGE 15
#define IMMIGRATION_MIN_DISTANCE 6
#define IMMIGRATION_MAX_DISTANCE 20
#define IMMIGRATION_ATTEMPTS 60

var/global/list/immigration_fires = list()

/obj/structure/oven/fireplace
	var/immigration_until = 0 // world.time the invitation lapses; not saved.
	var/immigration_host = null // the inviter's character name; not saved.
	var/immigration_faction = null // their faction when they invited; not saved.
	var/list/immigration_declined = null // accounts that said no at this fire; not saved.

/obj/structure/oven/fireplace/persistence_runtime_var(key)
	return (key in list("immigration_until", "immigration_host", "immigration_faction", "immigration_declined")) || ..()

/obj/structure/oven/fireplace/Destroy()
	immigration_fires -= src
	return ..()

// Only the mainland takes immigrants. A world outside any group is its own mainland.
/proc/immigration_land()
	return !shard_group.enabled || !shard_group.mainland || shard_group.region == shard_group.mainland

// Someone awake and connected close to the fire, to meet whoever arrives.
/obj/structure/oven/fireplace/proc/immigration_host_near()
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (istype(H) && H.stat == CONSCIOUS && H.z == z && get_dist(H, src) <= IMMIGRATION_HOST_RANGE)
			return TRUE
	return FALSE

// The fire still stands lit under the open sky on the level newcomers start on.
/obj/structure/oven/fireplace/proc/immigration_standing()
	if (QDELETED(src) || !on || !isturf(loc) || !signal_fire_open_sky(src))
		return FALSE
	var/obj/map_metadata/nomads/N = map
	return istype(N) && N.new_player_start_z && z == N.new_player_start_z

/obj/structure/oven/fireplace/proc/immigration_close()
	immigration_until = 0
	immigration_host = null
	immigration_faction = null
	immigration_fires -= src

// Whether a newcomer may start at this fire right now. A fire that went out
// or ran out of time is closed for good; a host who stepped away only pauses it.
/obj/structure/oven/fireplace/proc/immigration_open()
	if (!immigration_until)
		return FALSE
	var/now = world.time
	if (now >= immigration_until || !immigration_standing() || !immigration_land())
		immigration_close()
		return FALSE
	return immigration_host_near()

// Asked after each smoke signal. Signalling again while open renews the time.
/obj/structure/oven/fireplace/proc/immigration_offer(mob/living/human/user)
	if (!istype(user) || !user.client || !immigration_land() || !immigration_standing())
		return
	var/open_for = IMMIGRATION_OPEN_TIME
	var/now = world.time
	if (immigration_until && now >= immigration_until)
		immigration_close()
	if (immigration_until)
		immigration_until = now + open_for
		return
	// Someone who said no at this fire is not asked again on every signal.
	var/account = user.client.ckey
	if (immigration_declined && (account in immigration_declined))
		return
	var/answer = WWinput(user, "Invite newcomers to start near this fire? For the next [round(open_for / 600)] minutes, new characters can choose to start a short walk from it, while it stays lit and someone awake stays close. They arrive as nomads.", "Invite newcomers", "No", list("Yes", "No"))
	if (answer == "No")
		if (!immigration_declined)
			immigration_declined = list()
		immigration_declined |= account
	if (answer != "Yes" || QDELETED(user) || user.stat != CONSCIOUS || !user.client || get_dist(user, src) > IMMIGRATION_HOST_RANGE || !immigration_standing())
		return
	var/lapses = world.time + open_for
	immigration_until = lapses
	immigration_host = user.real_name
	immigration_faction = (user.civilization && user.civilization != "none") ? user.civilization : null
	immigration_fires |= src
	to_chat(user, SPAN_NOTICE("Your fire now calls newcomers. Keep it lit and stay near it; signal again to keep the invitation going."))
	log_game("[key_name(user)] opened a signal fire to immigration at ([x],[y],[z]).")

// label -> fire, for the lobby's starting place question.
/proc/immigration_fire_choices()
	var/list/choices = list()
	for (var/obj/structure/oven/fireplace/F in immigration_fires.Copy())
		if (!F.immigration_open())
			continue
		var/label = "Near [F.immigration_host]'s signal fire[F.immigration_faction ? " ([F.immigration_faction])" : ""]"
		if (!(label in choices))
			choices[label] = F
	return choices

// Any open fire of this faction: the Faction List marks it as recruiting.
/proc/immigration_faction_calling(faction)
	for (var/obj/structure/oven/fireplace/F in immigration_fires.Copy())
		if (F.immigration_faction == faction && F.immigration_open())
			return TRUE
	return FALSE

// A safe start a short walk from the fire, or null.
/obj/structure/oven/fireplace/proc/immigration_ground()
	var/obj/map_metadata/nomads/N = map
	if (!istype(N))
		return null
	for (var/attempt = 1, attempt <= IMMIGRATION_ATTEMPTS, attempt++)
		var/angle = rand(0, 359)
		var/distance = rand(IMMIGRATION_MIN_DISTANCE, IMMIGRATION_MAX_DISTANCE)
		var/tx = round(x + distance * cos(angle), 1)
		var/ty = round(y + distance * sin(angle), 1)
		if (tx < 1 || ty < 1 || tx > world.maxx || ty > world.maxy)
			continue
		var/turf/T = locate(tx, ty, z)
		if (T && N.new_player_has_exit(T))
			return T
	return null

// The fire this lobby chose to start near, set by faction_start_prompt.
/mob/new_player/var/obj/structure/oven/fireplace/immigration_fire_choice = null

// Where this lobby's new character starts if it chose a signal fire. The fire
// is checked again here: if it is gone the player starts as usual.
/proc/immigration_start_turf(mob/new_player/lobby)
	if (!istype(lobby))
		return null
	var/obj/structure/oven/fireplace/F = lobby.immigration_fire_choice
	lobby.immigration_fire_choice = null
	if (!F)
		return null
	var/turf/T = F.immigration_open() ? F.immigration_ground() : null
	if (!T)
		to_chat(lobby, SPAN_WARNING("That signal fire is no longer calling. You start on your own instead."))
		return null
	var/turf/fire_turf = get_turf(F)
	to_chat(lobby, SPAN_NOTICE("You start a short walk from [F.immigration_host]'s signal fire. It is [signal_fire_bearing(T, fire_turf)]."))
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (istype(H) && H.stat == CONSCIOUS && H.z == F.z && get_dist(H, F) <= IMMIGRATION_HOST_RANGE)
			to_chat(H, SPAN_NOTICE("<b>A newcomer has answered the smoke signal and is arriving [signal_fire_bearing(get_turf(H), T)].</b>"))
	log_game("[key_name(lobby)] starts near [F.immigration_host]'s signal fire at ([T.x],[T.y],[T.z]).")
	return T

#undef IMMIGRATION_OPEN_TIME
#undef IMMIGRATION_HOST_RANGE
#undef IMMIGRATION_MIN_DISTANCE
#undef IMMIGRATION_MAX_DISTANCE
#undef IMMIGRATION_ATTEMPTS
