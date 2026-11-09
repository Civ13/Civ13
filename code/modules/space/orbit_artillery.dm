// ============================================================
// Orbital artillery (orbital stations, stage E)
// ------------------------------------------------------------
// A crewed station can mount an orbital battery and drop shells on a ground
// world of its group. The battery stands on the party's own station plane,
// cabled to power, and fires a salvo of three orbital shells. The strike
// rides the transfer agents like cross-world radio (tools/transfer_storage/
// radio.py: /strike/send, /strike/inbox) to the one region it names, and the
// target world decides whether it lands:
//
// - Spotter strike: someone of the firing party painted the spot with a
//   target designator in the last five minutes. 30 seconds of warning,
//   shells land within a tile, battery cooldown about ten minutes.
// - Imagery strike: the firing party's spy satellite (satellites.dm) watches
//   that world and the spot stands outdoors. 60 seconds of warning, shells
//   land within three tiles, cooldown about twenty minutes.
//
// Anything else and the shells burn up in the air. Everyone near the target
// sees the warning streak and hears the whistle before the impact. A strike
// never wakes a sleeping world, and every strike is logged on both worlds.
//
// Shells and cooldown are plain saved numbers on the battery, and a falling
// strike counts its warning down in plain seconds. Painted marks are runtime
// only (world.time), so a restart clears them.
// ============================================================

#define ORBIT_ARTILLERY_SALVO 3
#define ORBIT_ARTILLERY_SHELLS_MAX 6
#define ORBIT_ARTILLERY_SPOTTER_COOLDOWN 600
#define ORBIT_ARTILLERY_IMAGERY_COOLDOWN 1200
#define ORBIT_ARTILLERY_SPOTTER_WARNING 30
#define ORBIT_ARTILLERY_IMAGERY_WARNING 60
#define ORBIT_ARTILLERY_MARK_LIFE 3000
#define ORBIT_ARTILLERY_MARK_RANGE 3
#define ORBIT_ARTILLERY_POLL 50
#define ORBIT_ARTILLERY_WARN_RANGE 15

// Peer kinds a battery may not fire on.
var/global/list/orbit_artillery_closed_kinds = list("ORBIT", "RAILYARD", "BARRACKS", "BATTLE", "RAID")
// Painted spots on this world: list(party, turf, world.time painted). Runtime only.
var/global/list/orbit_artillery_marks = list()
var/global/orbit_artillery_next_poll = 0
var/global/orbit_artillery_busy = FALSE

// ---------------------------------------------------------------- shells

/obj/item/orbital_shell
	name = "orbital shell"
	desc = "A finned, heat-shielded shell for an orbital battery. It falls from orbit on its own; the battery only aims it."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "rocketcasing_booster"
	color = "#a0a0a0"
	w_class = ITEM_SIZE_HUGE
	flammable = FALSE

// ---------------------------------------------------------------- battery

/obj/structure/orbital_battery
	name = "orbital battery"
	desc = "A rack of guided shells on a gimbal, aimed at the ground below. On your station, cabled to power and loaded, it drops a salvo on a spot a spotter painted or your spy satellite can see."
	icon = 'icons/obj/cannon.dmi'
	icon_state = "modern_cannon"
	color = "#c8c8d8"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	powerneeded = 40
	var/shells = 0
	// Seconds until it can fire again.
	var/cooldown = 0

/obj/structure/orbital_battery/New()
	..()
	processing_objects |= src

/obj/structure/orbital_battery/Destroy()
	processing_objects -= src
	return ..()

/obj/structure/orbital_battery/process()
	if (cooldown > 0 && clients.len)
		cooldown = max(0, cooldown - 2)

/obj/structure/orbital_battery/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Shells: [shells]/[ORBIT_ARTILLERY_SHELLS_MAX]. A salvo takes [ORBIT_ARTILLERY_SALVO]."))
	if (cooldown > 0)
		to_chat(user, SPAN_WARNING("Its barrels are cooling: about [max(1, round(cooldown / 60))] minute\s left."))
	var/reason = mount_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))

/obj/structure/orbital_battery/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/orbital_shell))
		if (shells >= ORBIT_ARTILLERY_SHELLS_MAX)
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return
		if (!user.drop_from_inventory(W))
			return
		qdel(W)
		shells++
		to_chat(user, SPAN_NOTICE("You rack a shell into \the [src] ([shells]/[ORBIT_ARTILLERY_SHELLS_MAX])."))
		return
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			to_chat(user, SPAN_WARNING("It is already cabled."))
			return
		connect_cable(user, W)
		return
	return ..()

// Null when this battery stands where it can fire for user, otherwise why not.
/obj/structure/orbital_battery/proc/mount_refusal(mob/user)
	if (!orbit_world())
		return "It only works in orbit."
	var/owner = orbit_station_party(z)
	if (!owner)
		return "It must stand on a station."
	if (user && ishuman(user) && party_train_party_of(user) != owner)
		return "It answers only to the station's crew."
	if (!powersource)
		return "Run a cable to it to power it."
	return null

// The ground worlds it can fire on now, as name = region id.
/obj/structure/orbital_battery/proc/targets()
	var/list/found = list()
	if (!shard_group || !shard_group.enabled)
		return found
	for (var/id in shard_group.peers)
		var/list/peer = shard_group.peers[id]
		if (!islist(peer) || id == shard_group.region || (peer["kind"] in orbit_artillery_closed_kinds))
			continue
		if (peer["state"] != "UP")
			continue
		found["[istext(peer["name"]) ? peer["name"] : id]"] = id
	return found

// Null when a salvo in mode may fire on region now, otherwise why not.
/obj/structure/orbital_battery/proc/fire_refusal(mob/user, mode, region)
	var/reason = mount_refusal(user)
	if (reason)
		return reason
	if (shells < ORBIT_ARTILLERY_SALVO)
		return "Load at least [ORBIT_ARTILLERY_SALVO] orbital shells first ([shells] loaded)."
	if (cooldown > 0)
		return "Its barrels are still cooling."
	if (!(mode in list("spotter", "imagery")))
		return "Pick how to aim."
	var/list/worlds = targets()
	var/open = FALSE
	for (var/label in worlds)
		if (worlds[label] == region)
			open = TRUE
	if (!region || !open)
		return "That world is not below you right now."
	return null

/obj/structure/orbital_battery/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	var/reason = mount_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/list/worlds = targets()
	if (!length(worlds))
		to_chat(user, SPAN_WARNING("No ground world is awake below you."))
		return
	var/pick = player_input(user, "Fire on which world?", capitalize(name), null, "anything", worlds, TRUE)
	if (!pick || QDELETED(src) || !in_range(src, user))
		return
	var/aim = WWinput(user, "Spotter: fire on a spot your spotter painted with a target designator ([ORBIT_ARTILLERY_SPOTTER_WARNING] s warning). Imagery: fire on a spot your spy satellite sees outdoors ([ORBIT_ARTILLERY_IMAGERY_WARNING] s warning, twice the cooldown).", capitalize(name), "Cancel", list("Spotter", "Imagery", "Cancel"))
	if (aim == "Cancel" || QDELETED(src) || !in_range(src, user))
		return
	var/tx = player_input(user, "Target X coordinate", capitalize(name), null, "num", null, TRUE)
	var/ty = player_input(user, "Target Y coordinate", capitalize(name), null, "num", null, TRUE)
	if (!isnum(tx) || !isnum(ty) || QDELETED(src) || !in_range(src, user) || user.incapacitated())
		return
	var/result = fire(user, lowertext(aim), worlds[pick], round(tx), round(ty))
	to_chat(user, result ? SPAN_WARNING(result) : SPAN_DANGER("\The [src] slams [ORBIT_ARTILLERY_SALVO] shells down toward [pick] at [round(tx)], [round(ty)]."))

// Fires a salvo. Returns null once it fired, or why it did not.
/obj/structure/orbital_battery/proc/fire(mob/user, mode, region, tx, ty)
	var/reason = fire_refusal(user, mode, region)
	if (reason)
		return reason
	if (tx < 1 || ty < 1 || tx > 1000 || ty > 1000)
		return "Those coordinates are off the map."
	var/party = orbit_station_party(z)
	var/list/envelope = list("target" = region, "mode" = mode, "party" = party, "station" = copytext(name, 1, 33),
		"ckey" = (user && user.ckey) ? user.ckey : "-", "x" = tx, "y" = ty, "z" = 0, "shells" = ORBIT_ARTILLERY_SALVO)
	if (!send(envelope))
		return "The uplink is not answering. Nothing fired."
	shells -= ORBIT_ARTILLERY_SALVO
	cooldown = mode == "spotter" ? ORBIT_ARTILLERY_SPOTTER_COOLDOWN : ORBIT_ARTILLERY_IMAGERY_COOLDOWN
	log_game("Orbital strike: [user ? key_name(user) : "nobody"] of [party] fired a [mode] salvo from [x],[y],[z] at [region] [tx],[ty].")
	return null

/obj/structure/orbital_battery/proc/send(list/envelope)
	return orbit_artillery_send(envelope)

// Hands a strike to the local agent. TRUE when it took it.
/proc/orbit_artillery_send(list/envelope)
	if (!transfer_bridge.enabled())
		return FALSE
	var/list/answer = transfer_bridge.request("/strike/send", list("envelope" = envelope))
	return islist(answer) && answer["ok"]

// ---------------------------------------------------------------- designator

/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/rangefinder/target_designator
	name = "target designator"
	desc = "Laser binoculars that paint a spot for your station's orbital battery. Look through them and click a spot outdoors; the crew above has five minutes to fire on it."
	color = "#ffb0b0"

/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/rangefinder/target_designator/rangecheck(mob/living/human/H, atom/target)
	var/turf/T = get_turf(target)
	..()
	if (!H || !T || T.z != H.z || !H.looking)
		return
	var/reason = orbit_artillery_paint(H, T)
	to_chat(H, reason ? SPAN_WARNING(reason) : SPAN_NOTICE("You paint [T.x], [T.y] for your station. Its crew has five minutes to fire on it."))

// Paints T for H's party. Returns null once painted, or why not.
/proc/orbit_artillery_paint(mob/living/human/H, turf/T)
	var/party = party_train_party_of(H)
	if (!party)
		return "You have no party whose station could fire."
	if (!satellite_spy_sees(T))
		return "The laser cannot reach a spot under a roof."
	for (var/list/mark in orbit_artillery_marks.Copy())
		if (mark[1] == party && mark[2] == T)
			orbit_artillery_marks -= list(mark)
	orbit_artillery_marks += list(list(party, T, world.time))
	log_game("Orbital strike: [key_name(H)] of [party] painted [T.x],[T.y],[T.z].")
	return null

// The painted turf of party within reach of x,y on this world, or null.
/proc/orbit_artillery_mark(party, x, y)
	for (var/list/mark in orbit_artillery_marks.Copy())
		if (world.time - mark[3] > ORBIT_ARTILLERY_MARK_LIFE || QDELETED(mark[2]))
			orbit_artillery_marks -= list(mark)
			continue
		var/turf/T = mark[2]
		if (mark[1] == party && abs(T.x - x) <= ORBIT_ARTILLERY_MARK_RANGE && abs(T.y - y) <= ORBIT_ARTILLERY_MARK_RANGE)
			return T
	return null

// ---------------------------------------------------------------- arrival

// Called by the radio process: takes strikes aimed at this world.
/proc/orbit_artillery_tick()
	if (orbit_artillery_busy || world.time < orbit_artillery_next_poll || !transfer_bridge.enabled())
		return
	orbit_artillery_next_poll = world.time + ORBIT_ARTILLERY_POLL
	orbit_artillery_busy = TRUE
	var/list/answer = transfer_bridge.request("/strike/inbox", list())
	orbit_artillery_busy = FALSE
	if (!islist(answer) || !answer["ok"] || !islist(answer["result"]) || !islist(answer["result"]["envelopes"]))
		return
	var/count = 0
	for (var/list/envelope in answer["result"]["envelopes"])
		if (++count > 10)
			break
		orbit_artillery_arrive(envelope)

// Where a strike lands on this world and how: list(turf, warning seconds,
// scatter), or the reason it burns up, as text.
/proc/orbit_artillery_aim(list/envelope)
	if (!islist(envelope) || !istext(envelope["party"]) || !isnum(envelope["x"]) || !isnum(envelope["y"]))
		return "The strike was garbled."
	var/party = envelope["party"]
	if (envelope["mode"] == "spotter")
		var/turf/T = orbit_artillery_mark(party, envelope["x"], envelope["y"])
		if (!T)
			return "No spotter of [party] painted that spot."
		return list(T, ORBIT_ARTILLERY_SPOTTER_WARNING, 1)
	if (envelope["mode"] == "imagery")
		for (var/obj/structure/satellite_station/S in satellite_stations)
			if (QDELETED(S) || S.owner != party || !("spy" in S.satellites))
				continue
			var/turf/T = locate(envelope["x"], envelope["y"], S.z)
			if (!T || !satellite_spy_sees(T))
				return "The spy satellite of [party] cannot see that spot."
			return list(T, ORBIT_ARTILLERY_IMAGERY_WARNING, 3)
		return "[party] has no spy satellite over this world."
	return "The strike was garbled."

/proc/orbit_artillery_arrive(list/envelope)
	var/aim = orbit_artillery_aim(envelope)
	var/from = istext(envelope["source"]) ? envelope["source"] : "orbit"
	if (!islist(aim))
		log_game("Orbital strike: a salvo from [from] burned up: [aim]")
		return null
	var/list/A = aim
	var/turf/T = A[1]
	log_game("Orbital strike: [envelope["party"]] ([envelope["ckey"]]) from [from] lands on [T.x],[T.y],[T.z] in [A[2]] s.")
	var/obj/effect/orbital_strike/S = new(T)
	S.left = A[2]
	S.scatter = A[3]
	S.shells = isnum(envelope["shells"]) ? Clamp(envelope["shells"], 1, ORBIT_ARTILLERY_SHELLS_MAX) : ORBIT_ARTILLERY_SALVO
	S.warn()
	return S

// The streak in the sky over a target, counting down to the impact.
/obj/effect/orbital_strike
	name = "streak of fire"
	desc = "Something is falling from orbit, right here. Run."
	icon = 'icons/effects/effects.dmi'
	icon_state = "shieldsparkles"
	anchored = TRUE
	mouse_opacity = FALSE
	var/left = ORBIT_ARTILLERY_SPOTTER_WARNING
	var/scatter = 1
	var/shells = ORBIT_ARTILLERY_SALVO

/obj/effect/orbital_strike/New()
	..()
	processing_objects |= src

/obj/effect/orbital_strike/Destroy()
	processing_objects -= src
	return ..()

/obj/effect/orbital_strike/proc/warn()
	for (var/mob/M in range(ORBIT_ARTILLERY_WARN_RANGE, src))
		to_chat(M, SPAN_DANGER("A bright streak of fire falls out of the sky toward [get_dist(M, src) <= 2 ? "you" : "a spot [dir2text(get_dir(M, src))] of you"]! It will hit in about [left] seconds."))

/obj/effect/orbital_strike/process()
	left -= 2
	if (left == 10 || left == 11)
		for (var/mob/M in range(ORBIT_ARTILLERY_WARN_RANGE, src))
			to_chat(M, SPAN_DANGER("A rising shriek fills the air!"))
	if (left > 0)
		return
	impact()

// Drops every shell within scatter tiles of here, then goes.
/obj/effect/orbital_strike/proc/impact()
	var/turf/C = get_turf(src)
	processing_objects -= src
	if (C)
		for (var/i in 1 to shells)
			var/turf/T = locate(Clamp(C.x + rand(-scatter, scatter), 1, world.maxx), Clamp(C.y + rand(-scatter, scatter), 1, world.maxy), C.z)
			if (T)
				blast(T)
	qdel(src)

/obj/effect/orbital_strike/proc/blast(turf/T)
	explosion(T, 0, 1, 3, 4)

#undef ORBIT_ARTILLERY_SALVO
#undef ORBIT_ARTILLERY_SHELLS_MAX
#undef ORBIT_ARTILLERY_SPOTTER_COOLDOWN
#undef ORBIT_ARTILLERY_IMAGERY_COOLDOWN
#undef ORBIT_ARTILLERY_SPOTTER_WARNING
#undef ORBIT_ARTILLERY_IMAGERY_WARNING
#undef ORBIT_ARTILLERY_MARK_LIFE
#undef ORBIT_ARTILLERY_MARK_RANGE
#undef ORBIT_ARTILLERY_POLL
#undef ORBIT_ARTILLERY_WARN_RANGE
