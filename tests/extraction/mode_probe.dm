// Only startup, client identity and action waiting are injected. Equipment,
// account disk I/O, NPC decisions, placement and transitions are production.
/obj/map_metadata/extraction_survival/New()
	map = src
	icon = null

/obj/map_metadata/extraction_survival
	var/list/test_owners = list()
	var/test_wait = "complete"
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
	makeDatumRefLists()
	var/obj/map_metadata/extraction_survival/M = map
	equipment_assert(istype(M), "original extraction map metadata loaded")
	equipment_assert(extraction_house_markers.len == 16 && extraction_raid_markers.len == 4 && extraction_loot_markers.len == 18, "fixed room, deployment and loot pools")
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
	M.codec.set_raid_provenance(G, TRUE)
	equipment_assert(!M.visit_hub(A) && A.z == 2, "carried equipment cannot enter shared hub")
	equipment_assert(M.deploy(A), "durable loadout debit precedes raid placement")
	equipment_assert(A.z == 1 && SA.profile["state"] == "raid" && SA.profile["stash"]:len == 3 && !(A.status_flags & GODMODE), "raid owns issued item and clears house immunity")
	equipment_assert(!G.extraction_found_in_raid && !G.ammo_magazine?.extraction_found_in_raid, "bringing gear into subsequent raid clears found-in-raid status")
	equipment_assert(SB.profile["stash"]:len == 4, "other account unaffected")
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
	equipment_assert(!A.extraction_session && !M.accounts.sessions["fixturealice"] && M.corpses[A], "death releases room and retains bounded raid corpse")
	var/datum/extraction_service/restarted = new
	var/datum/extraction_session/reloaded = restarted.open("fixturealice")
	equipment_assert(reloaded && reloaded.profile["state"] == "home" && reloaded.profile["stash"]:len == 4, "death forfeits carried loadout but retains committed shipment across disk reopen")
	var/list/reloaded_stash = reloaded.profile["stash"]
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
