// Only startup, client identity and action waiting are injected. Equipment,
// account disk I/O, NPC decisions, placement and transitions are production.
/obj/map_metadata/extraction_survival/New()
	map = src
	icon = null

/process/mapswap/extraction_probe
	var/list/requests = list()
	execute_map_swap(winner)
		requests += winner

/obj/map_metadata/extraction_survival
	var/list/test_owners = list()
	var/test_wait = "complete"
	var/test_insurance_confirmation = TRUE
	var/test_party_confirmation = "accept"
	var/test_car_confirmation = TRUE
	var/test_ride_confirmation = TRUE
	var/test_vehicle_return_confirmation = TRUE
	var/test_supply_confirmation = TRUE
	confirm_supplies(mob/living/human/H, offer, price)
		if (test_supply_confirmation == "move")
			H.forceMove(locate(H.extraction_session.house.x + 4, H.extraction_session.house.y + 4, 2))
			return TRUE
		return test_supply_confirmation
	confirm_vehicle_return(mob/living/human/H, car_owner)
		if (test_vehicle_return_confirmation == "stale")
			for (var/obj/item/weapon/gun/G in H.contents) G.health--
			return TRUE
		return test_vehicle_return_confirmation
	confirm_party_vehicle(mob/living/human/H, datum/extraction_party/P)
		return test_ride_confirmation
	confirm_car_purchase(mob/living/human/H)
		if (test_car_confirmation == "move")
			var/obj/effect/extraction_house_marker/house = H.extraction_session.house
			H.forceMove(locate(house.x + 4, house.y + 4, house.z))
			return TRUE
		return test_car_confirmation
	confirm_party(mob/living/human/H, leader, faction)
		sleep(1)
		if (test_party_confirmation == "stale")
			var/datum/extraction_party/P = party_by_owner[leader]
			P.invalidate()
		return test_party_confirmation != "decline"
	confirm_insurance(mob/living/human/H, list/offer)
		return test_insurance_confirmation
	confirm_party_insurance(mob/living/human/H, list/offer)
		return test_insurance_confirmation
	identity(mob/living/human/H)
		return test_owners[H]
	wait_for_extraction(mob/living/human/H, obj/effect/extraction_exit/E)
		sleep(1)
		if (test_wait == "cancel") return FALSE
		if (test_wait == "move") H.forceMove(locate(3,3,1))
		if (test_wait == "dead") H.stat = DEAD
		if (test_wait == "faction") E.allowed_faction = "Scav"
		if (test_wait == "backpack") new /obj/item/weapon/storage/backpack(H)
		if (test_wait == "unlock")
			for (var/obj/item/weapon/key/extraction_room/K in H.contents) extraction_room_door.attackby(K, H)
		return TRUE

/proc/extraction_mode_probe()
	vote_handle_probe()
	makeDatumRefLists()
	var/obj/map_metadata/extraction_survival/M = map
	equipment_assert(istype(M), "original extraction map metadata loaded")
	M.accounts.store.root = "data/mode_accounts/"
	extraction_progression_probe(M)
	extraction_hub_probe(M)
	equipment_assert(extraction_house_markers.len == 16 && extraction_raid_markers.len == 4 && extraction_loot_markers.len == 27, "fixed room, deployment and loot pools")
	var/mob/living/human/A = new(locate(3,3,1))
	var/mob/living/human/B = new(locate(3,3,1))
	A.m_intent = "stealth"
	B.m_intent = "stealth"
	M.test_owners[A] = "fixturealice"
	M.test_owners[B] = "fixturebob"
	equipment_assert(M.admit(A) && M.admit(B), "separate durable accounts admitted")
	var/datum/extraction_session/SA = A.extraction_session
	var/datum/extraction_session/SB = B.extraction_session
	world.log << "Room A [SA.house.room] at [A.x],[A.y],[A.z]; room B [SB.house.room] at [B.x],[B.y],[B.z]"
	equipment_assert(SA.house != SB.house && A.z == 2 && B.z == 2, "private physical rooms differ")
	var/turf/other = locate(SB.house.x + 1, SB.house.y, SB.house.z)
	equipment_assert(!other.Enter(A, get_turf(A)), "other private room denies movement")
	equipment_assert(extraction_hub_terminal && extraction_hub_terminal.z == 3, "original shared hub separate from private rooms")
	equipment_assert(M.visit_hub(A) && A.z == 3 && SA.profile["stash"]:len == 4, "empty-handed hub visit checkpoints private equipment")
	equipment_assert(!M.deploy(A), "hub cannot deploy another room's loadout")
	equipment_assert(M.return_home(A) && get_turf(A) == get_turf(SA.house), "hub returns only to bound account room")
	var/list/items = M.home_roots(SA)
	equipment_assert(items.len == 4 && SA.profile["stash"]:len == 4, "starter issued once through journal")
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G
	for (var/obj/item/weapon/gun/projectile/pistol/m9beretta/I in items) G = I
	equipment_assert(G, "starter has conventional pistol")
	G.forceMove(A)
	var/obj/effect/extraction_secure_crate/private_crate = M.house_crate(SA)
	equipment_assert(private_crate && !private_crate.authorized(B), "secure crate access bound to active room owner")
	equipment_assert(M.private_storage(A, G, private_crate, TRUE) && G.loc == private_crate && G.extraction_secure_stored && SA.profile["stash"]:len == 4, "private crate deposit commits without copying equipment")
	equipment_assert(!M.private_storage(B, G, private_crate, FALSE), "another account cannot withdraw secure contents")
	equipment_assert(M.release(SA), "release checkpoints secure crate and retires physical graph")
	equipment_assert(!G.loc && !private_crate.contents.len, "idle room release leaves no retained crate items")
	equipment_assert(M.admit(A), "secure stash reload rebinds private instance")
	SA = A.extraction_session
	private_crate = M.house_crate(SA)
	G = locate() in private_crate.contents
	equipment_assert(G && G.extraction_secure_stored && M.home_roots(SA).len == 4, "actual stored gun restores inside rebound secure crate")
	equipment_assert(M.private_storage(A, G, private_crate, FALSE) && !G.extraction_secure_stored && G.loc == get_turf(private_crate), "owner withdraw commits secure-location change")
	var/obj/item/ammo_magazine/m9beretta/protected_magazine
	for (var/obj/item/ammo_magazine/m9beretta/I in M.home_roots(SA)) protected_magazine = I
	protected_magazine.forceMove(A)
	var/protected_id = protected_magazine.extraction_item_id
	equipment_assert(M.private_storage(A, protected_magazine, private_crate, TRUE), "spare equipment secured before raid")
	G.forceMove(A)
	M.codec.set_raid_provenance(G, TRUE)
	equipment_assert(!M.visit_hub(A) && A.z == 2, "carried equipment cannot enter shared hub")
	equipment_assert(M.deploy(A), "durable loadout debit precedes raid placement")
	equipment_assert(A.z == 1 && SA.profile["state"] == "raid" && SA.profile["stash"]:len == 3 && !(A.status_flags & GODMODE), "raid owns issued item and clears house immunity")
	equipment_assert(!G.extraction_found_in_raid && !G.ammo_magazine?.extraction_found_in_raid, "bringing gear into subsequent raid clears found-in-raid status")
	equipment_assert(SB.profile["stash"]:len == 4, "other account unaffected")
	loot_mode_probe(M, A)
	var/list/loot = M.records(M.player_roots(A))
	var/obj/effect/extraction_exit/exit = locate() in world
	var/obj/effect/extraction_exit/pmc/pmc_exit = locate() in world
	var/obj/effect/extraction_exit/scav/scav_exit = locate() in world
	var/obj/effect/extraction_exit/manhole/manhole = locate() in world
	A.forceMove(get_turf(pmc_exit))
	equipment_assert(pmc_exit.eligible(A), "PMC exit accepts durable PMC raid role")
	A.forceMove(get_turf(scav_exit))
	equipment_assert(!scav_exit.eligible(A), "Scav exit rejects PMC before wait")
	A.forceMove(get_turf(manhole))
	var/obj/item/weapon/storage/backpack/bag = new(A)
	equipment_assert(!manhole.eligible(A), "manhole denies carried backpack")
	var/obj/item/weapon/storage/backpack/outer = new(A)
	bag.forceMove(outer)
	equipment_assert(!manhole.eligible(A), "manhole denies nested backpack")
	qdel(bag)
	qdel(outer)
	equipment_assert(manhole.eligible(A), "manhole accepts inventory without backpack")
	M.test_wait = "backpack"
	equipment_assert(!M.extract_player(A, manhole) && !SA.transitioning && SA.profile["state"] == "raid", "backpack acquired during wait rejects final commit")
	for (var/obj/item/weapon/storage/backpack/I in A.contents) qdel(I)
	var/obj/effect/extraction_exit/locked_room/room_exit = locate() in world
	var/obj/item/weapon/key/extraction_room/room_key = locate() in world
	var/obj/structure/simple_door/key_door/extraction_room/door = extraction_room_door
	A.forceMove(locate(9,42,1))
	room_key.forceMove(A)
	door.attackby(room_key, A)
	equipment_assert(!door.keyslot.locked && door.unlocked_by == SA.owner, "matching real key records account unlock")
	// Native hand dispatch requires a real client; execute its production switch
	// here and leave real-client dispatch to the required concept video.
	door.SwitchState()
	sleep(11)
	equipment_assert(door.state && !door.density, "native keyed door opens")
	A.forceMove(get_turf(room_exit))
	equipment_assert(!room_exit.eligible(A), "open extraction room rejected")
	door.SwitchState()
	sleep(11)
	door.attackby(room_key, A)
	equipment_assert(room_exit.eligible(A), "player locks themselves inside keyed room")
	B.forceMove(locate(10,45,1))
	equipment_assert(!room_exit.eligible(A), "second room occupant rejects secure extraction")
	B.forceMove(get_turf(SB.house))
	M.test_wait = "unlock"
	equipment_assert(!M.extract_player(A, room_exit) && SA.profile["state"] == "raid", "unlock during timed extraction rejects commit")
	door.attackby(room_key, A)
	room_key.forceMove(get_turf(room_exit))
	equipment_assert(!room_exit.eligible(A), "losing matching key rejects secure extraction")
	qdel(room_key)
	A.forceMove(get_turf(exit))
	M.test_wait = "faction"
	equipment_assert(!M.extract_player(A, exit) && SA.profile["state"] == "raid", "faction eligibility changed during wait rejects final commit")
	exit.allowed_faction = "all"
	M.test_wait = "cancel"
	equipment_assert(!M.extract_player(A, exit) && !SA.transitioning && SA.profile["state"] == "raid", "cancelled extraction retains raid ownership")
	M.test_wait = "move"
	equipment_assert(!M.extract_player(A, exit) && !SA.transitioning && SA.profile["state"] == "raid", "leaving extraction area cannot bank loot")
	A.forceMove(get_turf(exit))
	M.test_wait = "dead"
	equipment_assert(!M.extract_player(A, exit) && !SA.transitioning && SA.profile["state"] == "raid", "death during wait cannot bank loot")
	A.stat = CONSCIOUS
	M.test_wait = "complete"
	equipment_assert(M.extract_player(A, exit) && A.z == 2 && (A.status_flags & GODMODE), "return commits equipment before private-house placement")
	equipment_assert(!SA.extract(SA.profile["raid_sequence"], loot), "return replay rejected")
	A.forceMove(get_turf(SA.house))
	for (var/i in 1 to 5) new /obj/item/extraction_salvage(get_turf(SA.house))
	equipment_assert(M.upgrade_house(SA), "physical upgrade consumes committed parts")
	equipment_assert(SA.profile["level"] == 2 && M.home_roots(SA).len == 4, "upgrade durable and physical copies retired")
	var/home = get_turf(SA.house)
	equipment_assert(M.release(SA), "clean release checkpoints stash")
	equipment_assert(!A.extraction_session && !length(M.home_roots(SA)), "release drops session ownership")
	A.forceMove(locate(3,3,1))
	equipment_assert(M.admit(A), "account reopens after room release")
	SA = A.extraction_session
	equipment_assert(SA.profile["level"] == 2 && M.home_roots(SA).len == 4 && home == get_turf(SA.house), "disk reload keeps upgrade and no second starter")
	items = M.home_roots(SA)
	G = null
	for (var/obj/item/weapon/gun/projectile/pistol/m9beretta/I in items) G = I
	G.forceMove(A)
	equipment_assert(M.deploy(A), "second deployment")
	var/obj/item/weapon/gun_mount/shipped_rail = new(G)
	var/obj/item/weapon/attachment/scope/adjustable/advanced/reddot/shipped_optic = new(shipped_rail)
	G.optic_rail = shipped_rail
	shipped_optic.A_attached = TRUE
	G.recompute_configuration()
	var/obj/effect/extraction_drop_box/box = locate() in world
	A.forceMove(get_turf(box))
	var/list/shipped_entry = M.record_item(G)
	SA.transitioning = TRUE
	equipment_assert(!M.deposit_item(A, G, box), "concurrent shipment transition rejected")
	SA.transitioning = FALSE
	equipment_assert(!M.deposit_item(B, G, box), "another account cannot deposit carried gear")
	equipment_assert(M.deposit_item(A, G, box) && !G.loc && SA.profile["state"] == "raid", "native nested shipment commits before physical gear retires")
	equipment_assert(!SA.deposit(SA.profile["raid_sequence"], list(shipped_entry)), "nested shipment receipt replay rejected")
	A.stat = DEAD
	M.tick()
	equipment_assert(!A.extraction_session && !M.accounts.sessions["fixturealice"] && A.corpse_decay_record, "death releases room and registers production bounded corpse lifecycle")
	var/datum/corpse_decay_record/decay = A.corpse_decay_record
	A.do_rotting()
	equipment_assert(A.corpse_decay_record == decay && A.loc && A.stat == DEAD, "repeated extraction death registration retains actual body and one decay record")
	var/datum/extraction_service/restarted = new
	restarted.store.root = M.accounts.store.root
	var/datum/extraction_session/reloaded = restarted.open("fixturealice")
	equipment_assert(reloaded && reloaded.profile["state"] == "home" && reloaded.profile["stash"]:len == 4, "death forfeits carried loadout but retains committed shipment across disk reopen")
	var/list/reloaded_stash = reloaded.profile["stash"]
	var/retained_secure = FALSE
	for (var/list/secure_entry in reloaded_stash)
		if (secure_entry["id"] == protected_id && secure_entry["secure"] == TRUE) retained_secure = TRUE
	equipment_assert(retained_secure, "private secure deposit survives death and native journal reopen")
	var/list/reloaded_entry = reloaded_stash[4]
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/shipped_gun = M.codec.decode(reloaded_entry["equipment"], locate(3,4,1))
	equipment_assert(shipped_gun && shipped_gun.scope && shipped_gun.scope.loc == shipped_gun.optic_rail && shipped_gun.extraction_item_id == shipped_entry["id"], "shipped actual nested gear restores with stable identity after death")
	qdel(shipped_gun)
	reloaded.close()
	var/list/stash_before = json_decode(json_encode(SB.profile["stash"]))
	SB.disconnected_at = world.time - 2 MINUTES
	M.tick()
	equipment_assert(!M.accounts.sessions["fixturebob"], "idle home disconnect checkpoints and releases")
	reloaded = restarted.open("fixturebob")
	equipment_assert(reloaded && json_encode(reloaded.profile["stash"]) == json_encode(stash_before), "idle account restores exact saved stash")
	reloaded.close()
	var/list/pool = list()
	for (var/i in 1 to 17)
		var/mob/living/human/H = new(locate(3,3,1))
		H.m_intent = "stealth"
		M.test_owners[H] = "pool[i]"
		pool += H
		equipment_assert(i <= 16 ? M.admit(H) : !M.admit(H), "fixed room pool exhaustion")
	equipment_assert(M.accounts.sessions.len == 16, "room/session count remains bounded")
	var/mob/living/human/duplicate = new(locate(3,3,1))
	M.test_owners[duplicate] = "pool1"
	equipment_assert(!M.admit(duplicate), "concurrent same-account body cannot obtain another room")
	for (var/mob/living/human/H in pool)
		if (H.extraction_session) M.release(H.extraction_session)
		qdel(H)
	equipment_assert(M.accounts.sessions.len == 0, "pool releases all session references")
	var/mob/living/simple_animal/hostile/human/extraction/scav = new(locate(8,8,1))
	var/mob/living/simple_animal/hostile/human/extraction/contractor/pmc = new(locate(10,8,1))
	M.npcs |= scav
	M.npcs |= pmc
	scav.handle_ai()
	equipment_assert(!scav.target_mob, "unprovoked scav stays neutral")
	scav.provoke(pmc)
	world.log << "Retaliation attacker stat=[pmc.stat] z=[pmc.z] visible=[pmc in view(12, scav)] aggressor=[scav.aggressor] clock=[world.time] decision=[scav.next_decision]"
	scav.handle_ai()
	equipment_assert(scav.target_mob == pmc, "scav retaliates against actual aggressor")
	pmc.handle_ai()
	equipment_assert(pmc.target_mob == scav, "contractor hunts neutral scav")
	var/ammo = scav.gun.ammo_magazine.stored_ammo.len
	sleep(1)
	scav.Shoot(pmc)
	equipment_assert(scav.gun.ammo_magazine.stored_ammo.len == ammo - 1, "NPC consumes actual finite ammunition")
	var/obj/item/weapon/gun/projectile/dropped = scav.gun
	scav.death()
	equipment_assert(scav.stat == DEAD && !(scav in M.npcs) && dropped.loc == get_turf(scav) && M.raid_items[dropped], "NPC corpse drops tracked equipment once")
	var/retained = M.raid_items.len
	scav.death()
	equipment_assert(M.raid_items.len == retained, "NPC death callback idempotent")
	equipment_assert(M.raid_items.len <= 2048 && M.npcs.len <= 12, "loot and NPC registries bounded")
	extraction_group_probe(M)
	extraction_vehicle_probe()
	extraction_round_probe(M)

/proc/extraction_round_probe(obj/map_metadata/extraction_survival/M)
	var/process/mapswap/extraction_probe/swapper = new
	equipment_assert(!M.accept_map_vote("UNSUPPORTED_MAP") && M.accept_map_vote(MAP_ALLEYWAY) && !swapper.selected_extraction_map(), "bounded hub selection rejects unsupported IDs and cannot switch before settlement")
	var/mob/living/human/H = new(locate(3,3,1))
	H.m_intent = "stealth"
	M.test_owners[H] = "roundowner"
	equipment_assert(M.admit(H), "round closure account opens private house")
	var/datum/extraction_session/S = H.extraction_session
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/G
	for (var/obj/item/weapon/gun/projectile/pistol/m9beretta/I in M.home_roots(S)) G = I
	G.forceMove(H)
	G.ammo_magazine = new /obj/item/ammo_magazine/m9beretta(G)
	for (var/i in 1 to 4) new /obj/item/extraction_salvage(get_turf(S.house))
	equipment_assert(M.save_home(S), "round fixture funds premium with obtainable workshop parts")
	var/list/offer = M.returns.quote(S, list(G.extraction_item_id), M.round_id)
	equipment_assert(offer, "mode uses authoritative current-round quote")
	M.test_insurance_confirmation = FALSE
	equipment_assert(!M.deploy(H, "PMC", TRUE) && S.profile["state"] == "home" && !S.profile["insurance_claims"], "cancelled terminal quote does not charge premium or issue claim")
	M.test_insurance_confirmation = TRUE
	equipment_assert(M.deploy(H, "PMC", TRUE) && G.extraction_insurance_token && S.profile["insurance_claims"].len == 1, "production paid deployment commits premium and binds actual physical tokens")
	H.forceMove(locate(8,8,1))
	G.health = 54
	var/id = G.extraction_item_id
	var/obj/item/weapon/storage/backpack/bag = new(locate(8,8,1))
	G.forceMove(bag)
	M.track_loot(bag)
	M.raid_items[bag] = world.time - 1
	M.raid_items[G] = world.time - 1
	M.tick()
	equipment_assert(bag.loc && G.loc == bag && G.health == 54, "ordinary expiry preserves insured child and uninsured outer container until bounded closure")
	// Actual worn root and nested equipment cross death and corpse retirement.
	var/token = G.extraction_insurance_token
	var/magazine_id = G.ammo_magazine.extraction_item_id
	bag.forceMove(H)
	H.back = bag
	H.death()
	equipment_assert(H.stat == DEAD && bag.loc == H && G.loc == bag, "native death leaves actual worn nested gear on the body")
	M.tick()
	equipment_assert(H.corpse_decay_record && !H.extraction_session, "insured death releases account through integrated corpse lifecycle")
	var/turf/death_site = get_turf(H)
	// Accelerated age only; production retirement, drop callbacks and bones run.
	H.corpse_decay_age = ABANDONED_ITEM_LIFETIME
	H.corpse_decay_seasons = ABANDONED_ITEM_SEASON_LIFETIME
	H.corpse_decay_record.check(world.time)
	var/obj/structure/religious/remains/decaying/bones = locate() in death_site
	equipment_assert((!H || !H.loc) && bones && bag.loc == death_site && G.loc == bag && G.extraction_item_id == id && G.extraction_insurance_token == token && G.ammo_magazine.extraction_item_id == magazine_id && G.health == 54, "bones transition releases original nested insured equipment with stable identity and condition")
	var/bones_count = 0
	for (var/obj/structure/religious/remains/decaying/B in death_site) bones_count++
	equipment_assert(bones_count == 1, "one dead body produces one bones root")
	bones.corpse_decay_age = ABANDONED_ITEM_LIFETIME
	bones.corpse_decay_seasons = ABANDONED_ITEM_SEASON_LIFETIME
	bones.corpse_decay_record.check(world.time)
	equipment_assert((!bones || !bones.loc) && bag.loc == death_site && G.loc == bag, "later bones expiry preserves useful actual gear for insurance reconciliation")
	var/mob/living/human/stranded = new(locate(3,3,1))
	stranded.m_intent = "stealth"
	M.test_owners[stranded] = "strandedowner"
	equipment_assert(M.admit(stranded), "live stranded participant opens private house")
	var/datum/extraction_session/stranded_session = stranded.extraction_session
	var/obj/item/stranded_gun
	for (var/obj/item/weapon/gun/projectile/pistol/m9beretta/I in M.home_roots(stranded_session)) stranded_gun = I
	stranded_gun.forceMove(stranded)
	equipment_assert(M.deploy(stranded), "live participant deploys uninsured loadout before closing")
	var/mob/living/human/sheltered = new(locate(3,3,1))
	sheltered.m_intent = "stealth"
	M.test_owners[sheltered] = "shelteredowner"
	equipment_assert(M.admit(sheltered), "home participant remains sheltered before closing")
	M.returns.test_fail_at = "after_prepare"
	var/list/closing_car_parts = list()
	for (var/obj/structure/vehicleparts/axis/A in M.raid_vehicles)
		closing_car_parts |= A
		closing_car_parts |= M.raid_vehicles[A]
	M.round_deadline = world.time
	M.tick()
	equipment_assert(M.round_closing && !M.game_over && G.loc && !M.accounts.open("roundowner"), "round deadline gates accounts before physical retirement and holds incomplete payout")
	equipment_assert(stranded.stat == DEAD && stranded.corpse_decay_record && !stranded.extraction_session && !sheltered.extraction_session && !M.accounts.sessions.len, "closing strands live raider and releases sheltered account before payout")
	M.returns.test_fail_at = null
	M.tick()
	equipment_assert(M.game_over && (!G || !G.loc) && (!bag || !bag.loc), "round retry retires physical graph before acknowledging completed settlement")
	equipment_assert(!M.raid_vehicles.len, "completed finite closure retires remaining physical raid car registry")
	for (var/obj/O in closing_car_parts) equipment_assert(!O.loc, "finite closure retires actual car parts and nested controller")
	swapper.restart_triggered = TRUE
	swapper.fire()
	equipment_assert(swapper.requests.len == 1 && swapper.requests[1] == MAP_ALLEYWAY && swapper.next_map_title == (map_id_to_title[MAP_ALLEYWAY] ? map_id_to_title[MAP_ALLEYWAY] : MAP_ALLEYWAY), "settled hub vote passes exact ordinary TDM ID to injected launcher without fallback")
	swapper.fire()
	equipment_assert(swapper.requests.len == 1, "scheduled map process does not dispatch completed selection twice")
	var/datum/extraction_session/stranded_reopen = M.accounts.open("strandedowner")
	equipment_assert(stranded_reopen && stranded_reopen.profile["state"] == "home" && stranded_reopen.profile["stash"].len == 3 && !stranded_reopen.profile["insurance_mailbox"], "stranded uninsured gun is lost while committed home equipment remains")
	stranded_reopen.close()
	var/datum/extraction_session/sheltered_reopen = M.accounts.open("shelteredowner")
	equipment_assert(sheltered_reopen && sheltered_reopen.profile["stash"].len == 4, "sheltered participant retains complete checkpoint across closing")
	sheltered_reopen.close()
	var/datum/extraction_session/reopened = M.accounts.open("roundowner")
	equipment_assert(reopened && reopened.profile["insurance_mailbox"].len == 1, "closed round credits one returned graph from actual lost gear")
	var/list/entry = reopened.profile["insurance_mailbox"][1]
	var/obj/item/weapon/gun/projectile/pistol/m9beretta/returned = M.codec.decode(entry["equipment"], locate(3,3,1))
	equipment_assert(returned && returned.extraction_item_id == id && returned.health == 54 && (!returned.ammo_magazine || !returned.ammo_magazine.stored_ammo.len), "round consumer preserves retirement condition and identity while excluding ammunition")
	qdel(returned)
	reopened.close()
	// A new mode may expose completed mail, but does not resume the old raid.
	var/obj/map_metadata/extraction_survival/next = new
	next.accounts.store.root = M.accounts.store.root
	H = new(locate(3,3,1))
	H.m_intent = "stealth"
	next.test_owners[H] = "roundowner"
	equipment_assert(next.admit(H), "next mode reopens committed mailbox in private house")
	equipment_assert(next.claim_mail(H) && !H.extraction_session.profile["insurance_mailbox"].len, "house consumer commits mailbox debit before materializing actual returned gun")
	var/found = 0
	for (var/obj/item/I in next.home_roots(H.extraction_session))
		if (I.extraction_item_id == id) found++
	equipment_assert(found == 1 && !next.claim_mail(H), "actual house delivery materializes one copy and denies replay")
	next.release(H.extraction_session)
