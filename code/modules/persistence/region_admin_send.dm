// Send Player to Region (Admin tab), and the host's send_players request
// (nomads_lifecycle.dm, shard_group.py send-players, the launcher's Players
// dialog). An admin moves chosen players, or the ship one of them is aboard,
// to another region of the group without a trail, through the ordinary travel
// record (region_travel.dm): everything they wear and carry, skills, research,
// reading and languages go exactly as on a trail, and the transfer agent
// journals the trip. Nothing is copied or lost on the way.
//
// A dry run first lists who can go and why anyone cannot (the same checks the
// send makes again), and what is left behind (a mount, a pulled cart). The
// destination places each arrival where the admin chose:
//   "shore"   - the nearest dry outdoor shore on the coasts facing the land
//               they came from (the sea-lane sides, then any coast);
//   "coords"  - the given x,y,z, or the nearest safe floor close by;
//   "arrival" - where a traveller normally arrives (the trail back, a gate).
// A destination that cannot place them as asked uses its normal arrival.
// Each send and each arrival is written to the admin log and told to the
// admins of every region (group admin chat).

#define ADMIN_SEND_SHORE "shore"
#define ADMIN_SEND_COORDS "coords"
#define ADMIN_SEND_ARRIVAL "arrival"
// Deciseconds between two players of one send, so the agent records one trip at a time.
#define ADMIN_SEND_GAP 30
// Lines tried along each coast when looking for a shore.
#define ADMIN_SEND_SHORE_LINES 48
#define ADMIN_SEND_RECENT_MAX 20

// Who sent this character here, until its player takes it (audit only).
/mob/living/human/var/tmp/region_admin_sent = null

/mob/living/human/persistence_runtime_var(key)
	return key == "region_admin_sent" || ..()

// Recent outcomes, newest last, for the host's players answer and the verb.
var/global/list/region_admin_send_recent = list()
var/global/region_admin_send_running = FALSE

// The hidden gate one player leaves by.
/obj/structure/region_gate/admin_send
	name = "admin transfer"
	desc = "An admin is sending someone to another land."
	invisibility = 101
	icon = null
	mouse_opacity = 0
	// Never part of a save: it lasts only while one player is sent.
	should_save = FALSE
	var/list/landing = null

/obj/structure/region_gate/admin_send/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/admin_send/travel_extra(mob/living/human/H)
	return landing ? list("admin_send" = landing) : null

/obj/structure/region_gate/admin_send/attack_hand(mob/living/human/user)
	return

/obj/structure/region_gate/admin_send/attack_ghost(mob/user)
	return

// An admin may send anyone anywhere a trail could lead, and to lands across the sea.
/obj/structure/region_gate/admin_send/closed_reason()
	return region_admin_send_destination_refusal(destination, FALSE)

// ---------------------------------------------------------------- choices

/proc/region_admin_send_landing_name(mode)
	switch(mode)
		if(ADMIN_SEND_SHORE) return "the nearest dry shore"
		if(ADMIN_SEND_COORDS) return "the given coordinates"
	return "the normal arrival point"

// "Name (state)" = region id of every region a player can be sent to now.
/proc/region_admin_send_destinations()
	. = list()
	if(!shard_group.enabled) return
	for(var/id in shard_group.order)
		if(id == shard_group.region) continue
		var/list/peer = shard_group.peers[id]
		if(!islist(peer) || region_admin_send_kind_refusal(peer)) continue
		.["[peer["name"]] ([lowertext(peer["state"] || "unknown")])"] = id

// Null when players can be sent to id now (wake: a sleeping land counts as
// open, it is woken first), otherwise why not.
/proc/region_admin_send_destination_refusal(id, wake = TRUE)
	if(!shard_group.enabled) return "This server is not part of a region group."
	if(!istext(id) || id == shard_group.region) return "Choose another region."
	var/list/peer = shard_group.peers[id]
	if(!islist(peer)) return "[id] is not a region of this group."
	var/kind = region_admin_send_kind_refusal(peer)
	if(kind) return kind
	if(!transfer_bridge.ready()) return "The transfer agent is not ready here, so nobody can travel."
	if(!(id in transfer_bridge.peers)) return "The transfer agent here has no route to [peer["name"]]."
	if(shard_group.peer_closed(id)) return "[peer["name"]] is stopped and cannot be started for travellers now (kept down, or busy with a host action). Start it from the launcher or host first."
	if(shard_group.peer_transfers_held(id)) return "[peer["name"]]'s transfer agent is on hold, so it would refuse the arrival and the character would wait in limbo. An operator must clear the hold first."
	if(peer["state"] != "UP" && !(wake && shard_group.peer_wakeable(id))) return "[peer["name"]] is not answering ([lowertext(peer["state"] || "unknown")])."
	if(persistence_save_active()) return "This world is saving. Try again in a moment."
	return null

// Why nobody can be sent to peer for good, or null. Event regions keep their
// own transfer; the TDM worlds and the tutorial never keep a character; a free
// expedition slot holds no land yet.
/proc/region_admin_send_kind_refusal(list/peer)
	switch(peer["kind"])
		if("EVENT") return "[peer["name"]] is an event region: use Event Transfer, which keeps their characters here."
		if("BARRACKS", "BATTLE", "TUTORIAL", "GATEWAY") return "[peer["name"]] never keeps a character, so nobody can be sent there."
		if("EXPEDITION")
			if(peer["state"] == "UP" && peer["map"] == "A New Land") return "[peer["name"]] is a free slot with no land in it yet."
	return null

// The regions a ship can be sent to: those an ordinary crossing could reach,
// since only they make room for her off their coasts (naval/ship_crossing.dm).
/proc/region_admin_send_ship_destinations()
	. = list()
	var/list/lands = sea_crossing_destinations()
	for(var/name in lands)
		. += lands[name]

// list("landing" = mode, "by" = who, and "at" = list(x, y, z) for coordinates),
// or a text reason. at_text: "x,y,z".
/proc/region_admin_send_landing(mode, at_text, by)
	if(!(mode in list(ADMIN_SEND_SHORE, ADMIN_SEND_COORDS, ADMIN_SEND_ARRIVAL))) return "Choose shore, coords or arrival."
	. = list("landing" = mode, "by" = copytext("[by]", 1, 33))
	if(mode != ADMIN_SEND_COORDS) return
	var/list/parts = istext(at_text) && length(at_text) <= 24 ? splittext(at_text, ",") : list()
	if(parts.len != 3) return "Give the coordinates as x,y,z."
	var/list/at = list()
	for(var/part in parts)
		var/n = text2num(trim(part))
		if(!isnum(n) || n != round(n) || n < 1 || n > 10000) return "Give the coordinates as x,y,z (whole numbers)."
		at += n
	.["at"] = at

// TRUE when a travel payload's admin fields are absent or well formed.
/proc/region_admin_send_payload_ok(list/P)
	var/list/S = P["admin_send"]
	if(isnull(S)) return TRUE
	if(!islist(S) || !(S["landing"] in list(ADMIN_SEND_SHORE, ADMIN_SEND_COORDS, ADMIN_SEND_ARRIVAL))) return FALSE
	if(!istext(S["by"]) || !length(S["by"]) || length(S["by"]) > 32) return FALSE
	for(var/key in S)
		if(!(key in list("landing", "by", "at", "check", "checks"))) return FALSE
	if(!isnull(S["check"]) && (!istext(S["check"]) || length(S["check"]) != 32)) return FALSE
	if(!isnull(S["checks"]))
		var/list/checks = S["checks"]
		if(!islist(checks) || checks.len > 64) return FALSE
		for(var/part in checks)
			if(!istext(part) || length(part) > 40 || !istext(checks[part]) || length(checks[part]) != 32) return FALSE
	if(S["landing"] != ADMIN_SEND_COORDS) return isnull(S["at"])
	var/list/at = S["at"]
	if(!islist(at) || at.len != 3) return FALSE
	for(var/n in at)
		if(!isnum(n) || n != round(n) || n < 1 || n > 10000) return FALSE
	return TRUE

// ---------------------------------------------------------------- checks

// The ship H stands aboard, by her tiller, or null.
/proc/region_admin_send_tiller(mob/living/human/H)
	var/datum/craft/C = craft_at(get_turf(H))
	var/datum/craft_body/built/B = C ? C.body : null
	if(!istype(B)) return null
	for(var/turf/T in B.cells())
		var/obj/structure/hull_tiller/tiller = locate(/obj/structure/hull_tiller) in T
		if(tiller && tiller.craft == C) return tiller
	return null

// Null when H can be sent now, otherwise why not.
/proc/region_admin_send_refusal(mob/living/human/H)
	if(!istype(H) || QDELETED(H)) return "They are gone."
	if(H.client ? IsGuestKey(H.client.key) : !H.persistence_owner_ckey) return "Only characters with a BYOND account can travel."
	if(H.stat == DEAD) return "They are dead."
	if(H.region_arrival_pending) return "Their character has just arrived and is waiting for them."
	if(event_stash_holds(H)) return "They are away at an event."
	if(!isturf(H.loc)) return "They are inside \the [H.loc]. Get them out first."
	var/list/items = H.region_travel_items()
	// What cannot travel is left here on their tile (region_admin_send_leave_behind),
	// so only refuse when that would not be enough.
	if(istext(items) && !length(region_admin_send_left_behind(H))) return items
	return null

// What H wears or holds that cannot travel, as the things themselves: an item
// the record has no way to carry, or what in a bag stops the bag travelling
// (the bag and the rest of it go). Grabs and organs are never counted.
/proc/region_admin_send_left_behind(mob/living/human/H)
	. = list()
	var/list/known = list()
	for(var/slot_name in region_travel_slots)
		var/obj/item/I = H.get_equipped_item(region_travel_slots[slot_name])
		if(!I) continue
		known += I
		if(region_travel_worn_kind(I)) continue
		var/list/inside = list()
		if(istype(I, /obj/item/weapon/storage))
			for(var/atom/movable/A in I.contents)
				var/obj/item/C = A
				if(!istype(C) || !(region_travel_item_kind(C) || region_travel_loose_kind(C) || region_travel_generic_kind(C)))
					inside += A
		. += inside.len ? inside : list(I)
	for(var/obj/item/I in H)
		if(istype(I, /obj/item/organ) || istype(I, /obj/item/weapon/grab)) continue
		if(!(I in known)) . += I

// Leaves what cannot travel on H's tile, so the rest goes 1:1. Returns the
// names left and where, as text, or null when nothing was.
/proc/region_admin_send_leave_behind(mob/living/human/H)
	if(!istext(H.region_travel_items())) return null
	var/list/left = region_admin_send_left_behind(H)
	if(!left.len) return null
	var/turf/T = get_turf(H)
	var/list/names = list()
	for(var/atom/movable/A in left)
		names += A.name
		var/obj/item/weapon/storage/S = A.loc
		if(istype(S) && istype(A, /obj/item))
			S.remove_from_storage(A, T)
		else if(A.loc == H && istype(A, /obj/item))
			H.drop_from_inventory(A, T)
		if(A.loc != T)
			A.forceMove(T)
	return "[english_list(names)] at [T.x],[T.y],[T.z]"

// What stays behind when H is sent, as a list of text (never a refusal).
/proc/region_admin_send_warnings(mob/living/human/H)
	. = list()
	if(H.riding && H.riding_mob) . += "they get off \the [H.riding_mob], which stays here"
	else if(H.buckled) . += "they leave \the [H.buckled] behind"
	if(H.pulling) . += "they let go of \the [H.pulling]"
	if(istext(H.region_travel_items()))
		var/list/names = list()
		for(var/atom/movable/A in region_admin_send_left_behind(H))
			names += A.name
		. += "these cannot travel and are left on their tile here: [english_list(names)]"
	if(H.health < H.maxHealth) . += "they travel hurt, every wound as it is"
	if(!H.client)
		. += "they are offline: their character waits there for them"
		var/account = H.persistence_owner_ckey
		for(var/client/C in clients)
			if(C.ckey == account)
				. += "[account] is online here as [C.mob ? C.mob.name : "someone else"] and must join the other region to take the character"
				break

// One preflight row per character, in the order of bodies: ckey, name, ok,
// reason, warnings. A body gone since it was picked keeps its row, refused.
/proc/region_admin_send_preflight(list/bodies, id, list/landing, ship = FALSE)
	. = list()
	var/destination = region_admin_send_destination_refusal(id)
	if(!destination && ship && !(id in region_admin_send_ship_destinations()))
		destination = "A ship sails only to a land across the sea, or from there home to the mainland."
	var/list/tillers = list()
	for(var/i = 1 to length(bodies))
		var/mob/living/human/H = bodies[i]
		if(!istype(H) || QDELETED(H))
			. += list(list("ckey" = null, "name" = null, "ok" = FALSE, "reason" = "They are gone.", "warnings" = list()))
			continue
		var/list/row = list("ckey" = H.client ? H.client.ckey : H.persistence_owner_ckey, "name" = H.real_name, "ok" = FALSE, "reason" = destination, "warnings" = list())
		if(!row["reason"] && ship)
			var/obj/structure/hull_tiller/tiller = region_admin_send_tiller(H)
			if(!tiller)
				row["reason"] = "They are not aboard a ship."
			else if(tiller in tillers)
				row["reason"] = null
				row["warnings"] += "aboard the same ship"
			else
				tillers += tiller
				row["reason"] = region_admin_send_ship_refusal(tiller)
				if(!row["reason"]) row["warnings"] += "the [tiller.craft.name] goes with everyone and everything aboard"
		else if(!row["reason"])
			row["reason"] = region_admin_send_refusal(H)
			if(!row["reason"])
				// The destination decodes with the same rules; never send what it would drop.
				// The send records the owner first (region_admin_send_one); measure as it will.
				// With things to leave behind the record is measured again as they go.
				var/list/items = H.region_travel_items()
				if(islist(items))
					var/recorded = H.persistence_owner_ckey
					if(H.client && !recorded) H.persistence_owner_ckey = H.client.owner_key()
					var/payload = H.region_travel_payload(items, null, FALSE, list("admin_send" = landing))
					H.persistence_owner_ckey = recorded
					if(length(payload) > (findtext(payload, "\"ship\":") ? 393216 : 131072) || !region_travel_decode(payload))
						row["reason"] = "Something about them cannot make the journey (their record is too big or does not pass its check)."
		if(!row["reason"])
			row["ok"] = TRUE
			row["warnings"] += region_admin_send_warnings(H)
		. += list(row)

// Null when the ship can be sent now, otherwise why not.
/proc/region_admin_send_ship_refusal(obj/structure/hull_tiller/tiller)
	tiller.admin_crossing = TRUE
	. = tiller.crossing_refusal(null)
	tiller.admin_crossing = FALSE
	if(.) return
	var/list/packed = sea_crossing_pack(tiller)
	if(istext(packed)) return packed
	var/list/crew = packed["crew"]
	if(!crew.len) return "Nobody is aboard to sail her."
	for(var/mob/living/human/H in crew)
		if(H.client ? IsGuestKey(H.client.key) : !(agent_travel_account(H) || H.persistence_owner_ckey))
			return "[H.real_name] aboard has no BYOND account."
		if(H.stat != CONSCIOUS || H.restrained())
			return "[H.real_name] aboard cannot make the crossing like this."
		var/list/items = H.region_travel_items()
		if(istext(items)) return "[H.real_name]: [items]"
	return null

/proc/region_admin_send_report_html(list/rows, id, list/landing, ship)
	var/list/peer = shard_group.peers[id]
	var/list/lines = list("<b>Send to [html_encode(peer ? peer["name"] : id)] ([ship ? "with their ship" : html_encode(region_admin_send_landing_name(landing["landing"]))]): dry run</b>")
	if(landing["landing"] == ADMIN_SEND_COORDS && !ship)
		var/list/at = landing["at"]
		lines += "Landing at [at[1]],[at[2]],[at[3]], or the nearest safe floor close by."
	for(var/list/row in rows)
		var/who = "[html_encode(row["ckey"])] ([html_encode(row["name"])])"
		if(row["ok"])
			var/list/warnings = row["warnings"]
			lines += "<span class='notice'>Ready: [who][warnings.len ? ": [html_encode(jointext(warnings, "; "))]" : ""]</span>"
		else
			lines += "<span class='warning'>Refused: [who]: [html_encode(row["reason"])]</span>"
	return jointext(lines, "<br>")

// ---------------------------------------------------------------- sending

/proc/region_admin_send_note(text)
	region_admin_send_recent += list(list("time" = world.realtime, "text" = text))
	if(region_admin_send_recent.len > ADMIN_SEND_RECENT_MAX)
		region_admin_send_recent.Cut(1, 2)

// Tells the admins here and in every region (group admin chat), and logs it.
/proc/region_admin_send_tell(text)
	log_admin("Region transfer: [text]")
	message_admins("Region transfer: [html_encode(text)]")
	region_admin_send_note(text)
	// The other regions refuse raw markup in admin chat.
	region_asay_outbound("Region transfer", "host", replacetext(replacetext(text, "<", ""), ">", ""))

// Sends one character. Returns "departed" or why not. Sleeps.
/proc/region_admin_send_one(mob/living/human/H, id, list/landing)
	var/reason = region_admin_send_destination_refusal(id) || region_admin_send_refusal(H)
	if(reason) return reason
	var/list/peer = shard_group.peers[id]
	if(peer["state"] != "UP")
		reason = shard_group.wake_peer(id)
		if(reason) return reason
		reason = region_admin_send_refusal(H)
		if(reason) return reason
	H.stop_pulling()
	if(H.buckled)
		H.buckled.unbuckle_mob()
	var/left = region_admin_send_leave_behind(H)
	if(left)
		region_admin_send_tell("[H.real_name] could not take [left]; left there in [shard_group.name].")
		reason = region_admin_send_refusal(H)
		if(reason) return reason
	if(H.client)
		H.record_persistence_owner()
	var/obj/structure/region_gate/admin_send/gate = new(get_turf(H))
	gate.destination = id
	gate.landing = region_admin_send_checked_landing(H, id, landing)
	. = gate.depart(H)
	qdel(gate)

// The landing an admin send carries, with the fingerprint the destination
// checks the arrival against (region_admin_send_arrived), after keeping the
// snapshot on disk.
/proc/region_admin_send_checked_landing(mob/living/human/H, id, list/landing)
	var/list/print = region_admin_send_fingerprint(H)
	region_admin_send_snapshot(H, id, landing, print)
	. = landing.Copy()
	.["check"] = md5(json_encode(print))
	.["checks"] = region_admin_send_checks(print)

// What each of a ship's crew carries on an admin's crossing (ship_crossing.dm):
// she anchors as a crossing does, and each is checked 1:1 like anyone sent.
/proc/region_admin_send_crew_landing(mob/living/human/H, id, by)
	return region_admin_send_checked_landing(H, id, list("landing" = ADMIN_SEND_ARRIVAL, "by" = by))

// ---------------------------------------------------------------- 1:1

// Everything a trip must keep, as plain lists: identity, skills, research,
// reading, people and languages, hunger, thirst and wounds, and every item
// worn or held with everything inside it, at any depth (type, name, amount,
// reagents, colour). Two characters with the same fingerprint left and arrived
// alike. Contents are sorted, so the order things lie in a bag never counts.
/proc/region_admin_send_fingerprint(mob/living/human/H, arrived = FALSE)
	var/list/items = list()
	for(var/slot_name in region_travel_slots)
		var/obj/item/I = H.get_equipped_item(region_travel_slots[slot_name])
		if(I) items[slot_name] = region_admin_send_item_print(I, 0)
	var/list/skills = list()
	for(var/stat in H.stats)
		var/list/pair = H.stats[stat]
		// As the record carries them: JSON keeps six significant digits.
		if(islist(pair) && pair.len == 2)
			var/list/carried = json_decode(json_encode(pair))
			skills[stat] = list(round(carried[1], 0.01), round(carried[2], 0.01))
	return list("name" = H.real_name, "gender" = H.gender, "age" = H.age, "skills" = region_admin_send_sorted(skills),
		"research" = sortList(clean_recipe_node_ids(H.known_recipe_nodes)), "scholarship" = region_admin_send_sorted(clean_scholarship(H.scholarship)),
		"reading" = region_admin_send_sorted(clean_study_progress(H.study_progress)), "tongues" = region_admin_send_sorted(H.region_travel_tongues()),
		"nutrition" = clamp(round(H.nutrition), 0, 1000), "water" = clamp(round(H.water), 0, 1000),
		"wounds" = region_admin_send_sorted(H.region_travel_limbs()), "tox" = clamp(round(H.getToxLoss()), 0, 200),
		// The faction travels as its id; the arrival keeps it as its origin and
		// rejoins it only where it has a colony (colony_charter.dm).
		"faction" = arrived ? H.colony_origin : colony_faction_id(H), "items" = items)

// One short check per part of a fingerprint (each item slot on its own), so an
// arrival can say what differs, not only that something does.
/proc/region_admin_send_checks(list/print)
	. = list()
	for(var/key in print)
		if(key == "items")
			var/list/items = print["items"]
			for(var/slot_name in items)
				.["items:[slot_name]"] = md5(json_encode(items[slot_name]))
		else
			.[key] = md5(json_encode(print[key]))

// An associative list as sorted "key=value" text, nested lists included, so
// the order a world happened to fill it in never counts.
/proc/region_admin_send_sorted(list/L)
	if(!islist(L)) return L
	var/list/out = list()
	for(var/key in L)
		var/value = istext(key) && !isnull(L[key]) ? L[key] : null
		out += "[key]=[islist(value) ? json_encode(region_admin_send_sorted(value)) : value]"
	return sortList(out)

/proc/region_admin_send_item_print(obj/item/I, depth)
	var/list/R = list("type" = "[I.type]", "name" = I.name)
	if(istype(I, /obj/item/stack))
		var/obj/item/stack/S = I
		R["amount"] = S.amount
		// A stack travels as its good (a two-hundred coin pile is coins), not its exact type.
		var/kind = region_travel_item_kind(I)
		if(copytext(kind, 1, 7) == "stack:")
			R["type"] = kind
			R["name"] = null
	if(I.color) R["color"] = "[I.color]"
	if(I.reagents && I.reagents.reagent_list.len)
		var/list/held = list()
		for(var/datum/reagent/A in I.reagents.reagent_list)
			held += "[A.id]=[round(A.volume, 0.01)]"
		R["reagents"] = sortList(held)
	if(depth < 8)
		var/list/inside = list()
		for(var/obj/item/C in I)
			if(istype(C, /obj/item/organ)) continue
			inside += json_encode(region_admin_send_item_print(C, depth + 1))
		if(inside.len) R["contents"] = sortList(inside)
	return R

// The differences between two fingerprints, as text (empty when alike).
/proc/region_admin_send_fingerprint_diff(list/A, list/B)
	. = list()
	for(var/key in A | B)
		if(key == "items")
			for(var/slot_name in A["items"] | B["items"])
				if(json_encode(A["items"][slot_name]) != json_encode(B["items"][slot_name]))
					. += "[slot_name]: [region_admin_send_item_summary(A["items"][slot_name])] became [region_admin_send_item_summary(B["items"][slot_name])]"
		else if(json_encode(A[key]) != json_encode(B[key]))
			. += "[key] changed"

/proc/region_admin_send_item_summary(list/R)
	if(!islist(R)) return "nothing"
	var/list/inside = R["contents"]
	return "[R["name"]][inside ? " holding [inside.len]" : ""]"

// Keeps what the character takes, as the travel record (items, skills,
// research, reading, languages, faction, wounds), in
// data/transfer-snapshots/<region>-<ckey>-<time>.json before it leaves, so an
// admin can check or restore anything by hand if a trip ever goes wrong.
/proc/region_admin_send_snapshot(mob/living/human/H, id, list/landing, list/print)
	var/list/items = H.region_travel_items()
	if(!islist(items)) return null
	var/list/record = list("from" = shard_group.region, "to" = id, "landing" = landing, "realtime" = world.realtime,
		"turf" = list(H.x, H.y, H.z), "fingerprint" = print, "payload" = H.region_travel_payload(items, null, FALSE, list("admin_send" = landing)))
	var/path = "data/transfer-snapshots/[shard_group.region || "world"]-[H.persistence_owner_ckey]-[num2text(world.realtime, 20)].json"
	text2file(json_encode(record), path)
	return path

// Sends the ship tiller lies on, with everyone aboard. Null when she left, else why not. Sleeps.
/proc/region_admin_send_ship(obj/structure/hull_tiller/tiller, id, by)
	if(!tiller || QDELETED(tiller) || !tiller.craft) return "The ship is gone."
	tiller.admin_crossing = TRUE
	tiller.admin_crossing_by = by
	. = tiller.cross(id)
	if(!QDELETED(tiller))
		tiller.admin_crossing = FALSE
		tiller.admin_crossing_by = null

// Sends every ready body one after another. Sleeps; callers spawn it.
/proc/region_admin_send_run(list/bodies, id, list/landing, ship, by, mob/requester)
	if(region_admin_send_running)
		if(requester) to_chat(requester, SPAN_WARNING("Another region transfer is still running here. Try again when it finishes."))
		return FALSE
	region_admin_send_running = TRUE
	// A runtime part way through must never leave every later send refused.
	try
		region_admin_send_each(bodies, id, landing, ship, by)
	catch(var/exception/e)
		log_game("Region admin send: stopped part way: [e.name] ([e.file]:[e.line]).")
		region_admin_send_tell("[by]'s region transfer stopped part way: [e.name]. Check who was sent before trying again.")
	region_admin_send_running = FALSE
	return TRUE

// Waits out a save here (a departure asks for one soon after), up to two minutes.
/proc/region_admin_send_wait_for_save()
	var/waited = 0
	while(persistence_save_active() && waited < 1200)
		sleep(10)
		waited += 10

/proc/region_admin_send_each(list/bodies, id, list/landing, ship, by)
	var/list/peer = shard_group.peers[id]
	var/where = peer ? peer["name"] : id
	var/list/sent_ships = list()
	var/first = TRUE
	for(var/mob/living/human/H in bodies)
		if(!first) sleep(ADMIN_SEND_GAP)
		first = FALSE
		region_admin_send_wait_for_save()
		if(QDELETED(H)) continue
		var/account = H.client ? H.client.ckey : H.persistence_owner_ckey
		var/name = H.real_name
		var/result
		if(ship)
			var/obj/structure/hull_tiller/tiller = region_admin_send_tiller(H)
			if(tiller in sent_ships) continue
			sent_ships += tiller
			var/ship_name = tiller && tiller.craft ? tiller.craft.name : "ship"
			result = region_admin_send_ship(tiller, id, by)
			if(!result)
				region_admin_send_tell("[by] sent the [ship_name] (with [account]'s character [name] and the crew aboard; anyone who had to stay was told why) to [where].")
			else
				region_admin_send_tell("[by] could not send the [ship_name] to [where]: [result]")
			continue
		result = region_admin_send_one(H, id, landing)
		if(result == "departed")
			region_admin_send_tell("[by] sent [account]'s character [name] to [where] ([region_admin_send_landing_name(landing["landing"])]). Waiting for [where] to confirm the arrival.")
		else
			region_admin_send_tell("[by] could not send [account]'s character [name] to [where]: [result]")

// ---------------------------------------------------------------- arriving

// The tile an arrival sent by an admin lands on, or null for the normal arrival.
/proc/region_admin_send_arrival_turf(list/P, incoming)
	var/list/S = islist(P) ? P["admin_send"] : null
	if(!incoming || !islist(S)) return null
	var/turf/T = null
	if(S["landing"] == ADMIN_SEND_COORDS)
		var/list/at = S["at"]
		T = region_admin_send_near(locate(at[1], at[2], at[3]))
	else if(S["landing"] == ADMIN_SEND_SHORE)
		T = region_admin_send_shore(sea_crossing_sides(P["from"]), region_admin_send_surface_z())
	// Remembered for the arrival note (region_admin_send_arrived).
	if(T) P["admin_placed"] = TRUE
	return T

// The level whose coasts a shore landing looks along: where new characters
// start on this map (the surface of a land with levels below it), else the
// level its map edges cross on.
/proc/region_admin_send_surface_z()
	if(!map) return 1
	var/obj/map_metadata/nomads/N = map
	if(istype(N) && N.new_player_start_z) return N.new_player_start_z
	return map.edge_crossing_z

// T when a character can stand there, else the nearest safe floor within
// PERSISTENCE_RETURN_SEARCH_RANGE, else null.
/proc/region_admin_send_near(turf/T)
	if(!isturf(T)) return null
	if(persistence_character_turf_safe(T, null)) return T
	var/turf/nearest
	var/nearest_distance
	for(var/turf/O in orange(PERSISTENCE_RETURN_SEARCH_RANGE, T))
		var/distance = get_dist(T, O)
		if(nearest && distance >= nearest_distance) continue
		if(!persistence_character_turf_safe(O, null)) continue
		nearest = O
		nearest_distance = distance
	return nearest

// A shore tile: dry, outdoors, ground a walker can stand on, nothing in the way.
/proc/region_admin_send_shore_ok(turf/T)
	if(!region_edge_ground(T, TRUE) || !persistence_character_turf_safe(T, null)) return FALSE
	var/area/A = get_area(T)
	return A && A.location == AREA_OUTSIDE

// The first dry shore on the given sides (NORTH...), walking in from the map
// edge along lines spread from the middle of each side outwards. Null if none.
/proc/region_admin_send_shore(list/sides, z)
	for(var/d in sides)
		var/along = (d == NORTH || d == SOUTH) ? world.maxx : world.maxy
		var/spacing = max(1, round(along / ADMIN_SEND_SHORE_LINES))
		for(var/i = 0 to ADMIN_SEND_SHORE_LINES)
			var/a = round(along / 2) + (i % 2 ? 1 : -1) * round((i + 1) / 2) * spacing
			if(a < 1 || a > along) continue
			var/turf/T = region_admin_send_shore_line(d, a, z)
			if(T) return T
	return null

// Walks in from side d at position a: past the sea to the first land tile.
/proc/region_admin_send_shore_line(d, a, z)
	var/depth_max = round(((d == NORTH || d == SOUTH) ? world.maxy : world.maxx) / 2)
	var/saw_water = FALSE
	for(var/depth = 1 to depth_max)
		var/turf/T
		switch(d)
			if(NORTH) T = locate(a, world.maxy - depth + 1, z)
			if(SOUTH) T = locate(a, depth, z)
			if(EAST) T = locate(world.maxx - depth + 1, a, z)
			if(WEST) T = locate(depth, a, z)
		if(!T) return null
		if(istype(T, /turf/floor/beach/water))
			saw_water = TRUE
			continue
		// Land at the very edge is no coast; a cliff or wall after the sea is no landing.
		return saw_water && region_admin_send_shore_ok(T) ? T : null
	return null

// Logs and tells every region's admins where an admin's arrival was placed.
/proc/region_admin_send_arrived(mob/living/human/H, list/P, incoming, turf/at)
	var/list/S = islist(P) ? P["admin_send"] : null
	if(!istype(H) || !islist(S)) return
	var/here = shard_group.enabled ? shard_group.name : "this land"
	if(!incoming)
		region_admin_send_tell("[P["owner"]]'s character [H.real_name] was turned back by the destination and is back in [here] at [at.x],[at.y],[at.z].")
		return
	H.region_admin_sent = S["by"]
	var/placed = ""
	if(S["landing"] != ADMIN_SEND_ARRIVAL && !P["voyage"])
		placed = P["admin_placed"] ? " ([region_admin_send_landing_name(S["landing"])])" : " (the normal arrival point: [region_admin_send_landing_name(S["landing"])] was not found)"
	var/exact = ""
	if(istext(S["check"]))
		var/list/print = region_admin_send_fingerprint(H, TRUE)
		if(md5(json_encode(print)) == S["check"])
			exact = " Everything arrived exactly as it left."
		else
			var/list/differs = region_admin_send_checks_diff(S["checks"], region_admin_send_checks(print))
			exact = " WARNING: the character differs from what left[differs.len ? " ([english_list(differs)])" : ""]; compare with the snapshot in [P["from"]]'s data/transfer-snapshots."
	region_admin_send_tell("[P["owner"]]'s character [H.real_name] arrived in [here] from [region_ooc_region_name(P["from"])] at [at.x],[at.y],[at.z][placed], sent by [S["by"]].[exact] [region_travel_waiting_body(P["owner"]) == H ? "Waiting for them to join." : "They already have a living character here, so they keep playing that one and this body waits for an admin."]")

// The parts whose checks differ, by name ("skills", "items:back"), or an empty
// list when the sender sent none (an older sender).
/proc/region_admin_send_checks_diff(list/sent, list/here)
	. = list()
	if(!islist(sent))
		return
	for(var/part in sent | here)
		if(sent[part] != here[part])
			. += part

// The player took the character an admin sent here.
/proc/region_admin_send_claimed(mob/living/human/H)
	if(!H.region_admin_sent) return
	var/turf/T = get_turf(H)
	region_admin_send_tell("[H.ckey] joined [shard_group.enabled ? shard_group.name : "this land"] as [H.real_name][T ? " at [T.x],[T.y],[T.z]" : ""] (sent by [H.region_admin_sent]).")
	H.region_admin_sent = null

// ---------------------------------------------------------------- the host

// The host's players answer: everyone online and the latest transfers.
/proc/region_admin_send_host_players()
	var/list/players = list()
	for(var/client/C in clients)
		var/mob/living/human/H = C.mob
		var/turf/T = get_turf(C.mob)
		var/list/row = list("ckey" = C.ckey, "name" = istype(H) ? H.real_name : null, "playing" = istype(H) && H.stat != DEAD)
		if(T) row["at"] = list(T.x, T.y, T.z)
		var/obj/structure/hull_tiller/tiller = istype(H) ? region_admin_send_tiller(H) : null
		if(tiller) row["aboard"] = tiller.craft.name
		players += list(row)
	return list("players" = players, "recent" = region_admin_send_recent, "running" = region_admin_send_running, "destinations" = region_admin_send_destinations())

// The host's send: ckeys "a,b", to, landing, at "x,y,z", ship "1", dry_run "1".
// Returns the dry run; a real send runs on after the answer, and its outcome
// shows in admin chat and in the next players answer.
/proc/region_admin_send_host(list/input)
	var/list/result = list("send" = null, "rows" = list())
	var/list/landing = region_admin_send_landing(input["landing"], input["at"], "host")
	if(istext(landing))
		result["send"] = "refused:[landing]"
		return result
	var/ship = input["ship"] == "1"
	var/list/wanted = istext(input["ckeys"]) && length(input["ckeys"]) <= 1000 ? splittext(input["ckeys"], ",") : list()
	var/list/bodies = list()
	for(var/key in wanted)
		var/account = ckey(key)
		if(!account) continue
		var/mob/living/human/found = null
		for(var/mob/living/human/H in human_mob_list)
			if(QDELETED(H) || H.stat == DEAD) continue
			if((H.client && H.client.ckey == account) || (!H.client && H.persistence_owner_ckey == account))
				found = H
				break
		if(found)
			bodies |= found
		else
			result["rows"] += list(list("ckey" = account, "name" = null, "ok" = FALSE, "reason" = "No living character of theirs is in this land.", "warnings" = list()))
	if(!bodies.len)
		result["send"] = "refused:nobody to send"
		return result
	var/list/rows = region_admin_send_preflight(bodies, input["to"], landing, ship)
	result["rows"] += rows
	var/list/ready = list()
	for(var/i = 1 to rows.len)
		var/list/row = rows[i]
		if(row["ok"]) ready += bodies[i]
	if(input["dry_run"] == "1")
		result["send"] = "dry_run"
	else if(!ready.len)
		result["send"] = "refused:nobody can be sent now"
	else if(region_admin_send_running)
		result["send"] = "refused:another transfer is running"
	else
		result["send"] = "started"
		log_admin("The host started a region transfer of [ready.len] character\s to [input["to"]].")
		region_admin_send_run_async(ready, input["to"], landing, ship)
	return result

// The host's send runs on after its answer (the Topic must not wait for the trips).
/proc/region_admin_send_run_async(list/bodies, id, list/landing, ship)
	set waitfor = FALSE
	region_admin_send_run(bodies, id, landing, ship, "host", null)

#undef ADMIN_SEND_GAP
#undef ADMIN_SEND_SHORE_LINES
#undef ADMIN_SEND_RECENT_MAX
