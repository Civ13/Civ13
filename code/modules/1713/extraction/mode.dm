#define EXTRACTION_HOUSES 16

var/global/list/extraction_house_markers = list()
var/global/list/extraction_raid_markers = list()
var/global/list/extraction_loot_markers = list()
var/global/list/extraction_npc_markers = list()
var/global/list/extraction_secure_crates = list()
var/global/obj/effect/extraction_hub_terminal/extraction_hub_terminal

// One map-owned raid-floor policy. Isolated fixtures without metadata retain
// the historical ground-floor rule; homes and the shared hub are never implied.
/proc/extraction_mission_z(level)
	var/obj/map_metadata/extraction_survival/M = map
	return istype(M) ? M.mission_z(level) : level == 1

/obj/map_metadata/extraction_survival/proc/mission_z(level)
	return level == 1

/obj/map_metadata/extraction_survival/proc/raid_arrival_turf()
	var/list/eligible = list()
	for (var/obj/effect/extraction_raid_marker/marker in extraction_raid_markers)
		var/turf/T = get_turf(marker)
		if (T && mission_z(T.z) && !T.density) eligible += T
	return eligible.len ? pick(eligible) : null
var/global/obj/structure/simple_door/key_door/extraction_room/extraction_room_door

/area/extraction_lock_room
	name = "Secure extraction room"
	dynamic_lighting = FALSE
	luminosity = TRUE

/obj/item/weapon/key/extraction_room
	name = "secure extraction room key"
	code = 81732
	extraction_found_in_raid = TRUE

/obj/structure/simple_door/key_door/extraction_room
	name = "secure extraction room door"
	var/tmp/unlocked_by
	var/tmp/unlocked_sequence
	var/tmp/secured_by
	New()
		..()
		keyslot.code = 81732
		extraction_room_door = src
	Open()
		secured_by = null
		return ..()
	attackby(obj/item/W, mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(H) || !istype(M) || !M.owned(H) || !Adjacent(H)) return
		var/was_locked = keyslot.locked
		..()
		if (was_locked && !keyslot.locked && istype(W, /obj/item/weapon/key/extraction_room))
			unlocked_by = H.extraction_session.owner
			unlocked_sequence = H.extraction_session.profile["raid_sequence"]
			secured_by = null
		if (!was_locked && keyslot.locked)
			secured_by = null
			if (!state && density && istype(get_area(H), /area/extraction_lock_room) && unlocked_by == H.extraction_session.owner && unlocked_sequence == H.extraction_session.profile["raid_sequence"])
				secured_by = unlocked_by

/area/extraction_hub
	name = "Safe hub concourse"
	dynamic_lighting = FALSE
	luminosity = TRUE

/obj/effect/extraction_hub_terminal
	name = "private house return terminal"
	desc = "Return to your account's private house. Equipment stays in private storage while visiting the shared concourse."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "anvil"
	anchored = TRUE
	New()
		..()
		extraction_hub_terminal = src
	attack_hand(mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(H) || !istype(M) || !Adjacent(H) || !M.owned(H) || H.z != 3) return
		var/choice = WWinput(H, "Return to your private house or start a vote for the next round. Map changes wait until this district closes and account settlement completes.", "Safe hub", "Cancel", list("Return home", "Vote next map", "Cancel"))
		if (!Adjacent(H) || !M.owned(H) || H.z != 3) return
		if (choice == "Return home") M.return_home(H)
		else if (choice == "Vote next map") M.start_map_vote(H)

/area/extraction_district
	name = "Industrial district"
	dynamic_lighting = FALSE
	luminosity = TRUE

/area/extraction_houses
	name = "Private safe houses"
	dynamic_lighting = FALSE
	luminosity = TRUE

/turf/floor/plating/extraction_house
	Enter(atom/movable/A, atom/oldloc)
		if (ismob(A))
			var/mob/living/human/H = A
			var/obj/map_metadata/extraction_survival/M = map
			if (!istype(H) || !istype(M) || !M.owned(H) || !H.extraction_session.house || z != H.extraction_session.house.z || get_dist(src, H.extraction_session.house) > 4 || H.extraction_session.profile["state"] != "home") return FALSE
		return ..()

/mob/living/human
	var/tmp/datum/extraction_session/extraction_session

/datum/extraction_session
	var/tmp/mob/living/human/body
	var/tmp/obj/effect/extraction_house_marker/house
	var/tmp/disconnected_at = 0
	var/tmp/transitioning = FALSE
	var/tmp/home_digest

/obj/effect/extraction_house_marker
	name = "private house terminal"
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "anvil"
	anchored = TRUE
	var/room = 1
	var/tmp/datum/extraction_session/session
	New()
		..()
		extraction_house_markers |= src
	Destroy()
		extraction_house_markers -= src
		session = null
		return ..()
	Del()
		extraction_house_markers -= src
		..()
	attack_hand(mob/user)
		var/mob/living/human/H = user
		if (!istype(H) || !session || session.body != H || H.client?.ckey != session.owner || session.transitioning || session.profile["state"] != "home" || !Adjacent(H)) return
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(M)) return
		var/choice = WWinput(H, "Carry your loadout to deploy. Insured deployment costs one workshop part per reusable equipment component, paid from parts left at home. Ammunition never returns. [M.round_briefing()] Leave equipment here before visiting the shared hub. House upgrades consume 5, 10, then 15 workshop parts. A level-two garage car costs 25 parts and has no fuel. Supplies exchange parts for game credits and sell crafting materials, gear and fuel.", "Private safe house", "Cancel", list("Deploy", "Deploy car", "Raid group", "Deploy as Scav", "Insure and deploy", "Inspect stash", "Insurance mail", "Visit hub", "Upgrade", "Buy car", "Supplies", "Link Discord", "Save stash", "Cancel"))
		if (session.body != H || !Adjacent(H) || session.transitioning) return
		switch (choice)
			if ("Deploy") M.deploy(H)
			if ("Deploy car") M.deploy_vehicle(H)
			if ("Raid group") M.manage_party(H)
			if ("Deploy as Scav") M.deploy(H, "Scav")
			if ("Insure and deploy") M.deploy(H, "PMC", TRUE)
			if ("Insurance mail") M.manage_insurance_mail(H)
			if ("Inspect stash") M.inspect_home_stash(H)
			if ("Save stash") M.save_home(session)
			if ("Upgrade") M.upgrade_house(session)
			if ("Buy car") M.buy_car(H)
			if ("Supplies") M.manage_supplies(H)
			if ("Link Discord") M.link_discord(H)
			if ("Visit hub") M.visit_hub(H)

/obj/map_metadata/extraction_survival/proc/visit_hub(mob/living/human/H)
	if (!owned(H) || H.stat != CONSCIOUS || !extraction_hub_terminal) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (S.transitioning || S.profile["state"] != "home" || H.z != S.house.z || get_dist(H, S.house) > 4 || player_roots(H).len) return FALSE
	if (!save_home(S)) return FALSE
	H.forceMove(get_turf(extraction_hub_terminal))
	return TRUE

/obj/map_metadata/extraction_survival/proc/return_home(mob/living/human/H)
	if (!owned(H) || H.stat != CONSCIOUS || !extraction_hub_terminal || !extraction_hub_terminal.Adjacent(H)) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (S.transitioning || S.profile["state"] != "home" || player_roots(H).len || S.house.session != S) return FALSE
	H.forceMove(get_turf(S.house))
	return TRUE

/obj/effect/extraction_raid_marker
	icon = null
	New()
		..()
		extraction_raid_markers |= src

/obj/effect/extraction_loot_marker
	New()
		..()
		extraction_loot_markers |= src

/obj/effect/extraction_npc_marker
	icon = null
	New()
		..()
		extraction_npc_markers |= src

/obj/effect/extraction_exit
	name = "extraction point"
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "anvil"
	anchored = TRUE
	var/allowed_faction = "all"
	var/forbid_backpack = FALSE
	// Shared balance settings, measured from this district's start.
	var/opens_after = 0
	var/extraction_fee = 0
	var/requires_vehicle = FALSE
	proc/available()
		var/obj/map_metadata/extraction_survival/M = map
		return istype(M) && M.round_id && !M.round_closing && world.time < M.round_deadline && world.time >= M.round_deadline - M.round_duration + opens_after
	proc/eligible(mob/living/human/H)
		var/obj/map_metadata/extraction_survival/M = map
		if (!available() || !istype(M) || !M.owned(H) || H.stat != CONSCIOUS || !extraction_mission_z(H.z) || !extraction_mission_z(z) || !Adjacent(H)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		if (S.profile["state"] != "raid" || !(allowed_faction in list("all", "PMC", "Scav"))) return FALSE
		if (allowed_faction != "all" && S.profile["raid_faction"] != allowed_faction) return FALSE
		if (!isnum(extraction_fee) || extraction_fee < 0 || extraction_fee > 1000000 || round(extraction_fee) != extraction_fee || S.profile["credits"] < extraction_fee) return FALSE
		if (forbid_backpack)
			var/list/pending = M.player_roots(H)
			var/list/seen = list()
			while (pending.len)
				var/obj/item/I = pending[1]
				pending.Cut(1, 2)
				if (seen[I] || seen.len >= EXTRACTION_EQUIPMENT_NODES) return FALSE
				seen[I] = TRUE
				if (istype(I, /obj/item/weapon/storage/backpack)) return FALSE
				for (var/obj/item/child in I.contents) pending += child
		return TRUE
	attack_hand(mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(H) || !istype(M) || !Adjacent(H)) return
		var/obj/structure/vehicleparts/axis/parked = M.nearby_raid_vehicle(H, src)
		if (parked && M.vehicle_exit_allowed(src))
			var/choice = WWinput(H, "Extract on foot or claim the parked [parked.name] and its boot cargo? Vehicle extraction requires the engine off, empty seats and a clear private bay.", "Extraction", "Cancel", list("Extract car", "On foot", "Cancel"))
			if (!Adjacent(H)) return
			if (choice == "Extract car") M.extract_vehicle(H, src, parked)
			else if (choice == "On foot") M.extract_player(H, src)
		else M.extract_player(H, src)

/obj/effect/extraction_exit/pmc
	name = "PMC extraction point"
	allowed_faction = "PMC"
	opens_after = 5 MINUTES

/obj/effect/extraction_exit/scav
	name = "Scav extraction point"
	allowed_faction = "Scav"
	opens_after = 5 MINUTES

/obj/effect/extraction_exit/manhole
	name = "manhole extraction - no backpacks"
	forbid_backpack = TRUE

/obj/effect/extraction_exit/locked_room
	name = "secure room extraction"
	eligible(mob/living/human/H)
		if (!..()) return FALSE
		var/obj/structure/simple_door/key_door/extraction_room/D = extraction_room_door
		if (!D || !D.loc || D.state || !D.density || D.isSwitchingStates || !D.keyslot?.locked || D.health <= 0 || D.secured_by != H.extraction_session.owner || D.unlocked_sequence != H.extraction_session.profile["raid_sequence"] || !istype(get_area(H), /area/extraction_lock_room)) return FALSE
		var/has_key = FALSE
		var/list/pending = map:player_roots(H)
		var/list/seen = list()
		while (pending.len)
			var/obj/item/I = pending[1]
			pending.Cut(1, 2)
			if (seen[I] || seen.len >= EXTRACTION_EQUIPMENT_NODES) return FALSE
			seen[I] = TRUE
			if (istype(I, /obj/item/weapon/key/extraction_room) && I.code == D.keyslot.code) has_key = TRUE
			for (var/obj/item/child in I.contents) pending += child
		if (!has_key) return FALSE
		for (var/mob/living/other in range(2, src))
			if (other != H && istype(get_area(other), /area/extraction_lock_room)) return FALSE
		return TRUE

/obj/effect/extraction_drop_box
	name = "account shipment drop box"
	desc = "Send a carried item and its contents to your private stash. Completed shipments survive death."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "anvil"
	anchored = TRUE
	attackby(obj/item/I, mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(H) && istype(M)) M.deposit_item(H, I, src)

/obj/effect/extraction_secure_crate
	name = "private secure storage crate"
	desc = "Account-bound storage. Completed deposits remain in your private stash when a raid fails."
	icon = 'icons/obj/storage.dmi'
	icon_state = "miningcaropen"
	anchored = TRUE
	var/room = 1
	New()
		..()
		extraction_secure_crates |= src
	proc/authorized(mob/living/human/H)
		var/obj/map_metadata/extraction_survival/M = map
		if (!istype(M) || !M.owned(H) || H.stat != CONSCIOUS || !Adjacent(H)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		return S.profile["state"] == "home" && !S.transitioning && S.house?.room == room && S.house.z == z && get_dist(src, S.house) <= 4
	attackby(obj/item/I, mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(H) && istype(M)) M.private_storage(H, I, src, TRUE)
	attack_hand(mob/user)
		var/mob/living/human/H = user
		if (!istype(H) || !authorized(H)) return
		var/list/options = list()
		for (var/obj/item/I in contents) options["[I.name] ([copytext(I.extraction_item_id,1,7)])"] = I
		if (!options.len)
			to_chat(H, "The secure crate is empty.")
			return
		var/choice = WWinput(H, "Withdraw a stored item to your private room.", name, "Cancel", options + list("Cancel"))
		var/obj/map_metadata/extraction_survival/M = map
		if (istype(M) && options[choice]) M.private_storage(H, options[choice], src, FALSE)

/obj/map_metadata/extraction_survival/proc/house_crate(datum/extraction_session/S)
	for (var/obj/effect/extraction_secure_crate/C in extraction_secure_crates)
		if (C.room == S.house?.room && C.z == S.house.z && get_dist(C, S.house) <= 4) return C
	return null

/obj/map_metadata/extraction_survival/proc/private_storage(mob/living/human/H, obj/item/I, obj/effect/extraction_secure_crate/C, deposit)
	if (!C?.authorized(H) || !I || (deposit ? I.loc != H : I.loc != C)) return FALSE
	var/atom/old_location = I.loc
	var/old_secure = I.extraction_secure_stored
	if (deposit) H.unEquip(I, TRUE)
	I.forceMove(deposit ? C : get_turf(C))
	I.extraction_secure_stored = deposit
	if (!save_home(H.extraction_session))
		I.forceMove(old_location)
		I.extraction_secure_stored = old_secure
		if (old_location == H) H.put_in_hands(I)
		return FALSE
	return TRUE

/obj/map_metadata/extraction_survival/proc/deposit_item(mob/living/human/H, obj/item/I, obj/effect/extraction_drop_box/box)
	if (!owned(H) || H.stat != CONSCIOUS || !extraction_mission_z(H.z) || !extraction_mission_z(box?.z) || !box.Adjacent(H) || I?.loc != H) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (S.transitioning || S.profile["state"] != "raid") return FALSE
	S.transitioning = TRUE
	var/list/entry = record_item(I)
	if (!entry || !S.deposit(S.profile["raid_sequence"], list(entry)))
		S.transitioning = FALSE
		to_chat(H, "Shipment rejected: full stash, unsupported gear, replay or account recovery lock.")
		return FALSE
	// The account credit is authoritative before retiring the materialized copy.
	H.unEquip(I, TRUE)
	qdel(I)
	S.transitioning = FALSE
	to_chat(H, "Shipment committed to your private stash.")
	return TRUE

/obj/map_metadata/extraction_survival
	ID = MAP_EXTRACTION_SURVIVAL
	title = "Extraction Survival"
	description = "Loot the industrial district, survive scavengers and hostile contractors, then extract to your private safe house."
	lobby_icon = "icons/lobby/battleroyale.png"
	faction_organization = list(CIVILIAN)
	faction1 = CIVILIAN
	faction2 = CIVILIAN
	ordinal_age = 8
	age = "2019"
	is_singlefaction = TRUE
	respawn_delay = 100
	gamemode = "Extraction Survival"
	valid_weather_types = list(WEATHER_NONE)
	no_time_of_day_cycle = TRUE
	var/datum/extraction_service/accounts = new
	var/datum/extraction_equipment_codec/codec = new
	var/list/npcs = list()
	var/list/raid_items = list()
	var/list/npc_corpses = list()
	var/uid = 0
	var/next_population = 0
	var/next_checkpoint = 0

/datum/job/civilian/extraction_survival
	title = "Independent Raider"
	spawn_location = "JoinLateExtraction"
	allowed_maps = list(MAP_EXTRACTION_SURVIVAL)
	min_positions = 1
	max_positions = 16
	is_outlaw = TRUE

/datum/job/civilian/extraction_survival/equip(mob/living/human/H)
	H.add_note("Role", "Use your private house terminal to deploy. Scavengers are neutral until provoked. Contractors are hostile. Click an extraction point and stay nearby for ten seconds to return with your equipment. Gear taken into a failed raid is lost.")
	H.setStat("strength", STAT_NORMAL)
	H.setStat("rifle", STAT_NORMAL)
	return TRUE

/obj/map_metadata/extraction_survival/update_win_condition()
	return game_over

/obj/map_metadata/extraction_survival/proc/identity(mob/living/human/H)
	return H?.client?.ckey

/obj/map_metadata/extraction_survival/proc/owned(mob/living/human/H)
	var/datum/extraction_session/S = H?.extraction_session
	return !round_closing && (!round_deadline || world.time < round_deadline) && S && S.active() && S.body == H && identity(H) == S.owner

/obj/map_metadata/extraction_survival/proc/record_item(obj/item/I)
	var/list/graph = codec.encode(I)
	if (!graph) return null
	if (!I.extraction_item_id)
		uid++
		I.extraction_item_id = md5("[world.realtime]-[rand(1,1000000)]-[uid]")
	I.should_save = FALSE
	return list("id" = I.extraction_item_id, "equipment" = graph, "salvage" = istype(I, /obj/item/extraction_salvage), "secure" = I.extraction_secure_stored)

/obj/map_metadata/extraction_survival/proc/player_roots(mob/living/human/H)
	var/list/items = list()
	if (!H) return items
	for (var/obj/item/I in H.contents)
		if (!istype(I, /obj/item/organ) && I.loc == H) items += I
	return items

/obj/map_metadata/extraction_survival/proc/home_roots(datum/extraction_session/S)
	var/list/items = player_roots(S.body)
	if (!S.house) return items
	// One fixed 9x9 room; no whole-world searches or saved turf references.
	for (var/turf/T in range(4, S.house))
		for (var/obj/item/I in T)
			if (I.loc == T && !(I in S.garage_parts) && !garage_cargo_turf(S, T)) items |= I
	var/obj/effect/extraction_secure_crate/C = house_crate(S)
	if (C)
		for (var/obj/item/I in C.contents)
			if (I.loc == C) items |= I
	var/obj/structure/component_workbench/extraction_private/B = house_workbench(S)
	if (B)
		for (var/obj/item/I in B.contents)
			if (I.loc == B) items |= I
	return items

/obj/map_metadata/extraction_survival/proc/records(list/items)
	if (items.len > 64) return null
	var/list/result = list()
	var/total_nodes = 0
	for (var/obj/item/I in items)
		var/list/entry = record_item(I)
		if (!entry) return null
		var/list/equipment = entry["equipment"]
		var/list/nodes = equipment["nodes"]
		total_nodes += nodes.len
		if (total_nodes > 2048) return null
		result += list(entry)
	return result

/obj/map_metadata/extraction_survival/proc/admit(mob/living/human/H)
	if (round_closing || !ensure_round() || !identity(H) || H.extraction_session) return FALSE
	if (!round_participants[identity(H)] && round_participants.len >= 32)
		to_chat(H, "This district has reached its account limit. Join the next round.")
		return FALSE
	var/obj/effect/extraction_house_marker/house
	for (var/obj/effect/extraction_house_marker/marker in extraction_house_markers)
		if (!marker.session)
			house = marker
			break
	if (!house)
		to_chat(H, "All private houses are occupied. Try again after a room is released.")
		return FALSE
	var/datum/extraction_session/S = accounts.open(identity(H))
	if (!S)
		to_chat(H, "Account unavailable: [accounts.last_error]")
		return FALSE
	S.body = H
	S.house = house
	house.session = S
	H.extraction_session = S
	H.should_save = FALSE
	H.status_flags |= GODMODE
	H.forceMove(get_turf(house))
	// The starter kit is granted once, durably, before its physical copy appears.
	if (S.profile["revision"] == 0)
		var/list/starter = list(new /obj/item/weapon/gun/projectile/pistol/m9beretta(get_turf(house)), new /obj/item/ammo_magazine/m9beretta(get_turf(house)), new /obj/item/clothing/under/us_uni/us_lightuni_modern(get_turf(house)), new /obj/item/clothing/shoes/jackboots(get_turf(house)))
		var/list/kit = records(starter)
		var/saved = kit && S.checkpoint_home(kit)
		for (var/obj/item/I in starter) qdel(I)
		if (!saved)
			release(S, FALSE)
			return FALSE
	var/list/stash = S.profile["stash"]
	// Validate the whole account before constructing any of its equipment.
	if (!S.valid_entries(stash, S.capacity()))
		release(S, FALSE)
		return FALSE
	for (var/list/entry in stash)
		if (!codec.validate(entry["equipment"]) || (entry["secure"] && !house_crate(S)))
			release(S, FALSE)
			return FALSE
	if (!restore_garage(S))
		to_chat(H, "Garage restoration blocked. The saved account remains unchanged; clear the bay or resolve the recovery lock.")
		release(S, FALSE)
		return FALSE
	for (var/list/entry in stash)
		var/obj/item/I = codec.decode(entry["equipment"], entry["secure"] ? house_crate(S) : get_turf(house))
		if (!I)
			to_chat(H, "Equipment restoration failed; account locked for recovery.")
			release(S, FALSE)
			return FALSE
		I.extraction_item_id = entry["id"]
		I.extraction_secure_stored = entry["secure"] == TRUE
	to_chat(H, "Private safe house level [S.profile["level"]]. Stash capacity: [S.capacity()] items. Use the terminal to save, upgrade or deploy.")
	S.home_digest = md5(json_encode(S.profile["stash"]))
	round_participants[S.owner] = TRUE
	return TRUE

/obj/map_metadata/extraction_survival/proc/save_home(datum/extraction_session/S)
	if (!S.active() || S.transitioning || S.profile["state"] != "home") return FALSE
	var/list/snapshot = records(home_roots(S))
	var/list/garage = garage_snapshot(S)
	if (!snapshot || isnull(garage) || !S.checkpoint_home(snapshot, garage))
		to_chat(S.body, "Stash save rejected. Unsupported equipment, capacity or recovery lock; nothing has been transferred.")
		return FALSE
	return TRUE

/obj/map_metadata/extraction_survival/proc/deploy(mob/living/human/H, raid_faction = "PMC", insured = FALSE)
	if (!owned(H) || H.stat != CONSCIOUS || !extraction_raid_markers.len) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (S.transitioning || S.profile["state"] != "home" || !S.house || H.z != S.house.z || get_dist(H, S.house) > 4 || !save_home(S)) return FALSE
	var/list/carried = player_roots(H)
	var/list/ids = list()
	if (carried.len > 16) return FALSE
	var/list/graphs = records(carried)
	if (!graphs) return FALSE
	var/carried_nodes = 0
	for (var/list/entry in graphs) carried_nodes += entry["equipment"]["nodes"].len
	if (raid_items.len + carried_nodes > 2048) return FALSE
	for (var/obj/item/I in carried) ids += I.extraction_item_id
	var/list/offer
	if (insured)
		if (insured_nodes_issued + carried_nodes > 4096) return FALSE
		offer = returns.quote(S, ids, round_id)
		if (!offer)
			to_chat(H, "Insurance requires eligible reusable equipment and enough workshop parts left at home.")
			return FALSE
		if (!confirm_insurance(H, offer) || !owned(H) || S.transitioning || !H.Adjacent(S.house) || json_encode(records(home_roots(S))) != json_encode(S.profile["stash"])) return FALSE
		// Confirmation yields to other players and NPC population updates.
		if (H.stat != CONSCIOUS || raid_items.len + carried_nodes > 2048 || insured_nodes_issued + carried_nodes > 4096) return FALSE
	var/turf/destination = raid_arrival_turf()
	if (!destination) return FALSE
	S.transitioning = TRUE
	var/list/raid = insured ? returns.paid_deploy(S, offer, raid_faction) : S.begin_raid(ids, raid_faction)
	if (!raid)
		S.transitioning = FALSE
		return FALSE
	leave_party(S.owner)
	if (insured)
		insured_nodes_issued += carried_nodes
		for (var/obj/item/I in home_roots(S))
			if (I.extraction_item_id in offer["payment"]) qdel(I)
		apply_issued_tokens(carried, raid["issued"])
	for (var/obj/item/I in carried)
		codec.set_raid_provenance(I, FALSE)
		track_loot(I)
	H.forceMove(destination)
	H.status_flags &= ~GODMODE
	S.transitioning = FALSE
	to_chat(H, "Raid [raid["sequence"]] started. Extract to keep your carried loot. Death or an interrupted server raid forfeits this loadout.")
	return TRUE

/obj/map_metadata/extraction_survival/proc/extract_player(mob/living/human/H, obj/effect/extraction_exit/E)
	if (!E?.eligible(H) || E.requires_vehicle) return FALSE
	var/datum/extraction_session/S = H.extraction_session
	if (S.transitioning || S.profile["state"] != "raid") return FALSE
	S.transitioning = TRUE
	var/sequence = S.profile["raid_sequence"]
	to_chat(H, "Extracting. Stay next to this point for ten seconds.")
	var/completed = wait_for_extraction(H, E)
	if (!completed || !E.eligible(H) || S.profile["raid_sequence"] != sequence)
		S.transitioning = FALSE
		return FALSE
	var/list/carried = player_roots(H)
	var/list/loot = records(carried)
	if (!loot || !S.extract(sequence, loot, E.extraction_fee))
		S.transitioning = FALSE
		to_chat(H, "Extraction rejected: unsupported equipment, full stash or recovery lock.")
		return FALSE
	for (var/obj/item/I in carried) raid_items -= I
	H.forceMove(get_turf(S.house))
	H.status_flags |= GODMODE
	S.transitioning = FALSE
	to_chat(H, "Extracted. Your equipment is now committed to your private stash.")
	return TRUE

/obj/map_metadata/extraction_survival/proc/wait_for_extraction(mob/living/human/H, obj/effect/extraction_exit/E)
	for (var/i in 1 to 10)
		if (!E.eligible(H) || !do_after(H, 1 SECOND, E, FALSE, can_move = TRUE) || !E.eligible(H)) return FALSE
	return TRUE

/obj/map_metadata/extraction_survival/proc/upgrade_house(datum/extraction_session/S)
	if (!owned(S?.body) || S.body.stat != CONSCIOUS || !S.body.Adjacent(S.house) || !save_home(S)) return FALSE
	var/list/cost = choose_upgrade_parts(S)
	var/datum/extraction_ipc_economy/economy = new(accounts)
	var/list/entries = economy.room_parts(S.profile, cost)
	if (!entries)
		to_chat(S.body, "Choose exactly [S.profile["level"] * 5] uninsured workshop parts for a house below level four.")
		return FALSE
	var/revision = S.profile["revision"]
	var/digest = md5(json_encode(S.profile))
	var/expiry = world.time + 2 MINUTES
	if (!confirm_house_upgrade(S, cost)) return FALSE
	if (!owned(S.body) || S.body.stat != CONSCIOUS || !S.body.Adjacent(S.house) || S.transitioning || world.time >= expiry || S.profile["revision"] != revision || md5(json_encode(S.profile)) != digest) return FALSE
	var/list/actual = records(home_roots(S))
	if (!actual || json_encode(actual) != json_encode(S.profile["stash"]))
		to_chat(S.body, "Your equipment changed after the quote. Choose the parts again.")
		return FALSE
	var/list/consumed = list()
	for (var/obj/item/extraction_salvage/I in home_roots(S))
		if (I.extraction_item_id in cost) consumed += I
	if (consumed.len != cost.len) return FALSE
	if (!S.upgrade(cost))
		to_chat(S.body, "Upgrade needs [S.profile["level"] * 5] workshop parts and a house below level four.")
		return FALSE
	for (var/obj/item/I in consumed)
		if (I.loc == S.body) S.body.unEquip(I, TRUE)
		qdel(I)
	to_chat(S.body, "House upgraded to level [S.profile["level"]], capacity [S.capacity()].")
	return TRUE

/obj/map_metadata/extraction_survival/proc/choose_upgrade_parts(datum/extraction_session/S)
	var/datum/extraction_ipc_economy/economy = new(accounts)
	var/list/options = list()
	for (var/list/entry in S.profile["stash"])
		if (entry["salvage"] && economy.eligible(entry)) options["Workshop part [entry["id"]]"] = entry["id"]
	var/list/selected = list()
	var/required = S.profile["level"] * 5
	if (required > 15 || options.len < required) return null
	while (selected.len < required)
		var/choice = WWinput(S.body, "Choose part [selected.len + 1] of [required]. These exact items will appear in the final upgrade quote.", "Upgrade parts", "Cancel", options + list("Cancel"))
		if (!owned(S.body) || !S.body.Adjacent(S.house) || !options[choice]) return null
		selected += options[choice]
		options -= choice
	return selected

/obj/map_metadata/extraction_survival/proc/confirm_house_upgrade(datum/extraction_session/S, list/ids)
	return WWinput(S.body, "Upgrade house [S.profile["level"]] to [S.profile["level"] + 1] for [ids.len] workshop parts? Selected item IDs: [jointext(ids, ", ")].", "Upgrade quote", "Cancel", list("Pay and upgrade", "Cancel")) == "Pay and upgrade"

/obj/map_metadata/extraction_survival/proc/home_stash_detail(mob/living/human/H, item_id, page)
	if (!supply_access(H) || !isnum(page) || page < 0 || page > 31 || round(page) != page) return null
	return extraction_ipc_detail_projection(H.extraction_session.profile, item_id, page)

/obj/map_metadata/extraction_survival/proc/stash_node_text(list/node)
	var/obj/item/prototype = text2path(node["type"])
	var/list/condition = node["condition"]
	var/list/ammunition = node["ammo_refs"]
	return "[initial(prototype.name)] - ID [node["id"]]; part [node["index"]], parent [node["parent"]]; found in raid: [node["found_in_raid"] ? "yes" : "no"]; condition [condition["health"]]/[condition["maxhealth"]]; material [node["material_key"]]; amount [node["amount"]]; ammunition links [json_encode(ammunition)]"

/obj/map_metadata/extraction_survival/proc/inspect_home_stash(mob/living/human/H)
	if (!supply_access(H) || !save_home(H.extraction_session)) return FALSE
	var/list/options = list()
	for (var/list/entry in H.extraction_session.profile["stash"])
		var/list/projection = extraction_ipc_root_projection(entry)
		var/list/root = projection["root"]
		if (!islist(root)) continue
		var/obj/item/prototype = text2path(root["type"])
		options["[initial(prototype.name)] - [entry["id"]]"] = entry["id"]
	if (!options.len)
		to_chat(H, "Your saved stash has no inspectable items.")
		return FALSE
	var/choice = WWinput(H, "Choose a saved item to inspect its original parts, condition, materials and ammunition. Item IDs distinguish otherwise identical items.", "Private stash", "Cancel", options + list("Cancel"))
	if (!supply_access(H) || !options[choice]) return FALSE
	var/page = 0
	while (page <= 31)
		var/list/detail = home_stash_detail(H, options[choice], page)
		if (!detail) return FALSE
		to_chat(H, "Item [detail["item_id"]], saved revision [detail["account_revision"]], parts page [page + 1]:")
		for (var/list/node in detail["nodes"]) to_chat(H, stash_node_text(node))
		if (isnull(detail["next_page"])) return TRUE
		if (WWinput(H, "More parts are available for this item.", "Stash details", "Close", list("Next page", "Close")) != "Next page") return TRUE
		page = detail["next_page"]
	return TRUE

/obj/map_metadata/extraction_survival/proc/release(datum/extraction_session/S, save = TRUE, leave_group = TRUE)
	if (leave_group) leave_party(S.owner)
	if (save && S.profile["state"] == "home" && !save_home(S)) return FALSE
	if (S.house)
		var/obj/structure/component_workbench/extraction_private/B = house_workbench(S)
		if (B) B.cancelled = TRUE
		for (var/obj/item/I in home_roots(S))
			if (I.loc == S.body && extraction_mission_z(S.body.z)) continue
			qdel(I)
		S.house.session = null
	retire_garage(S)
	if (S.body) S.body.extraction_session = null
	S.house = null
	S.body = null
	S.close()
	return TRUE

/obj/map_metadata/extraction_survival/tick()
	if (bot_spool?.enabled) bot_spool.poll()
	tick_parties()
	if (round_closing)
		close_round()
		return
	if (!ensure_round()) return
	if (world.time >= round_deadline)
		close_round()
		return
	if (!round_warning && world.time >= round_deadline - 5 MINUTES)
		round_warning = TRUE
		world << "The district closes in five minutes. Extract or send your gear home before the deadline."
	// Bounded active sessions; the existing map process provides the single timer.
	for (var/owner in accounts.sessions.Copy())
		var/datum/extraction_session/S = accounts.sessions[owner]
		if (!S.body || S.body.stat == DEAD)
			if (S.profile["state"] == "raid") S.forfeit(S.profile["raid_sequence"])
			if (S.body && S.body.stat == DEAD && extraction_mission_z(S.body.z)) S.body.do_rotting()
			release(S, FALSE)
			continue
		if (!S.body.client)
			if (!S.disconnected_at) S.disconnected_at = world.time
			if (world.time >= S.disconnected_at + 2 MINUTES && !S.transitioning)
				var/mob/living/human/H = S.body
				if (S.profile["state"] == "raid")
					S.forfeit(S.profile["raid_sequence"])
					H.death()
					H.do_rotting()
					H.ghostize()
					release(S, FALSE)
				else if (release(S))
					H.ghostize()
					qdel(H)
		else S.disconnected_at = 0
	if (world.time >= next_checkpoint)
		next_checkpoint = world.time + 30 SECONDS
		for (var/owner in accounts.sessions)
			var/datum/extraction_session/S = accounts.sessions[owner]
			if (!S.active() || S.transitioning || S.profile["state"] != "home") continue
			var/list/entries = records(home_roots(S))
			var/list/garage = garage_snapshot(S)
			if (entries && !isnull(garage) && (json_encode(entries) != json_encode(S.profile["stash"]) || json_encode(garage) != json_encode(S.profile["garage"]))) save_home(S)
	for (var/obj/item/I in raid_items.Copy())
		var/turf/T = get_turf(I)
		var/atom/holder = I.loc
		for (var/depth in 1 to EXTRACTION_EQUIPMENT_DEPTH)
			if (!isobj(holder)) break
			holder = holder.loc
		if (!I.loc || !T || !extraction_mission_z(T.z))
			raid_items -= I
		else if (isliving(holder) && holder:stat != DEAD) raid_items[I] = world.time + 30 MINUTES
		else if (world.time >= raid_items[I])
			// Claims retain their actual condition until the bounded round closes.
			if (contains_insured(I)) continue
			raid_items -= I
			qdel(I)
	// Simple-animal NPC bodies have already released their finite loadouts.
	// Human bodies use the shared production corpse lifecycle instead.
	for (var/mob/M in npc_corpses.Copy())
		if (!M.loc || world.time >= npc_corpses[M])
			npc_corpses -= M
			qdel(M)
	population_tick()

/obj/map_metadata/extraction_survival/proc/population_tick()
	if (world.time < next_population) return
	next_population = world.time + 30 SECONDS
	for (var/mob/living/simple_animal/hostile/human/extraction/N in npcs.Copy())
		if (!N.loc || N.stat == DEAD) npcs -= N
	if (npcs.len < 12 && extraction_npc_markers.len)
		var/obj/effect/extraction_npc_marker/marker = pick(extraction_npc_markers)
		var/turf/spawn_turf = get_turf(marker)
		if (!spawn_turf || !mission_z(spawn_turf.z) || spawn_turf.density) return
		var/near_player = FALSE
		for (var/owner in accounts.sessions)
			var/datum/extraction_session/S = accounts.sessions[owner]
			if (S.body?.z == marker.z && extraction_mission_z(S.body?.z) && get_dist(S.body, marker) < 12) near_player = TRUE
		if (!near_player)
			var/path = npcs.len % 3 == 2 ? /mob/living/simple_animal/hostile/human/extraction/contractor : /mob/living/simple_animal/hostile/human/extraction
			var/mob/living/simple_animal/hostile/human/extraction/N = new path(spawn_turf)
			N.pmc_contact_hostile = !N.contractor && npcs.len % 2 == 1
			npcs += N

/obj/map_metadata/extraction_survival/proc/track_loot(obj/item/I)
	if (!I) return FALSE
	var/list/pending = list(I)
	var/list/seen = list()
	var/position = 1
	while (position <= pending.len)
		var/obj/item/next = pending[position++]
		if (seen[next]) continue
		seen[next] = TRUE
		if (seen.len > EXTRACTION_EQUIPMENT_NODES || raid_items.len + seen.len > 2048) return FALSE
		for (var/obj/item/child in next.contents) pending += child
	for (var/obj/item/next in seen)
		next.should_save = FALSE
		raid_items[next] = world.time + 30 MINUTES
	return TRUE

/obj/map_metadata/extraction_survival/proc/spawn_loot(turf/T, path)
	if (!T || raid_items.len >= 2048) return null
	var/obj/item/I = new path(T)
	if (!codec.set_raid_provenance(I, TRUE))
		qdel(I)
		return null
	if (!track_loot(I))
		qdel(I)
		return null
	return I
