/proc/extraction_npc_probe()
	var/obj/map_metadata/extraction_survival/M = new
	M.accounts.store.root = "data/npc_extraction/"
	var/old_map = map
	map = M
	equipment_assert(M.ensure_round(), "NPC fixture starts durable district")
	var/turf/T = locate(7,7,1)
	var/obj/effect/extraction_exit/pmc/E = new(T)
	var/mob/living/simple_animal/hostile/human/extraction/contractor/N = new(T)
	M.npcs |= N
	equipment_assert(!E.npc_eligible(N), "PMC exit unavailable during initial five minutes")
	E.opens_after = 0
	equipment_assert(E.npc_eligible(N), "matching living PMC NPC can use open exit")
	E.allowed_faction = "Scav"
	equipment_assert(!E.npc_eligible(N), "wrong NPC faction denied")
	E.allowed_faction = "PMC"
	E.extraction_fee = 5
	equipment_assert(!E.npc_eligible(N), "NPC cannot invent payment")
	N.extraction_credits = 5
	equipment_assert(E.npc_eligible(N), "explicit NPC currency satisfies shared fee")
	E.requires_vehicle = TRUE
	equipment_assert(!E.npc_eligible(N), "NPC cannot use vehicle-only exit without actual transferable vehicle")
	E.requires_vehicle = FALSE
	E.forbid_backpack = TRUE
	var/obj/item/weapon/storage/backpack/B = new(N)
	equipment_assert(!E.npc_eligible(N), "NPC backpack denied at no-backpack exit")
	qdel(B)
	var/obj/effect/extraction_exit/locked_room/L = new(T)
	equipment_assert(!L.npc_eligible(N), "NPC cannot invent secured-room key or ownership")
	var/datum/extraction_session/S = M.accounts.open("npcvictim")
	var/obj/item/weapon/gun/projectile/semiautomatic/sks/extraction_scope_probe/G = new(T)
	var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso1/O = new(T)
	var/mob/living/human/extraction_scope_probe/H = new(T)
	var/obj/item/weapon/screwdriver/tool = new(H)
	equipment_assert(G.install_configuration(O, H, TRUE), "NPC stolen graph has actual attached optic")
	var/list/graph = M.codec.encode(G)
	var/gun_id = G.extraction_item_id
	var/scope_id = O.extraction_item_id
	var/list/stash = list(list("id" = gun_id, "equipment" = graph))
	for (var/i in 1 to 5)
		var/obj/item/extraction_salvage/part = new(T)
		stash += list(list("id" = M.codec.encode(part)["nodes"][1]["id"], "equipment" = M.codec.encode(part)))
		qdel(part)
	equipment_assert(S.checkpoint_home(stash), "NPC theft fixture pays actual insurance premium")
	qdel(G)
	var/list/offer = M.returns.quote(S, list(gun_id), M.round_id)
	var/list/raid = M.returns.paid_deploy(S, offer, "PMC")
	equipment_assert(raid, "insured native gun and optic deployed")
	G = M.codec.decode(raid["issued"][1]["equipment"], H)
	O = G.scope
	H.r_hand = G
	equipment_assert(G.remove_configuration(O, H) && O.loc == T, "insured optic detached as actual independent component")
	equipment_assert(O.extraction_item_id == scope_id && G.extraction_item_id == gun_id, "NPC theft preserves original detached component identities")
	H.r_hand = null
	O.forceMove(N)
	G.forceMove(N)
	M.track_loot(G)
	M.track_loot(O)
	equipment_assert(S.forfeit(S.profile["raid_sequence"]), "insured victim loses original raid gear")
	S.close()
	var/obj/item/extraction_salvage/historical = new(N)
	var/historical_token = md5("previous-round-insured-original")
	historical.extraction_insurance_token = historical_token
	equipment_assert(M.accounts.npc_journal.retire(M, N, E), "eligible NPC commits receipt before retiring originals")
	equipment_assert((!G || !G.loc) && (!O || !O.loc) && (!N || !N.loc), "successful NPC extraction retires original gun, detached component and body")
	var/datum/extraction_npc_journal/reopened = new(M.accounts)
	var/list/tokens = reopened.recovered(M.round_id)
	var/list/retired_ids = list()
	for (var/token in tokens) retired_ids[tokens[token]["id"]] = TRUE
	equipment_assert(tokens && retired_ids[gun_id] && retired_ids[scope_id], "native disk reopening preserves gun and detached component insurance suppression")
	equipment_assert(reopened.profile["npc_receipts"][1]["fee"] == 5, "NPC fee recorded in the same original-gear receipt")
	var/datum/extraction_insurance_inventory/index = new(M.accounts)
	var/list/statuses = index.build(M.round_id)
	equipment_assert(statuses && !statuses[historical_token] && tokens[historical_token], "historical NPC insured token does not block unrelated current-round claims")
	for (var/token in tokens)
		if (token == historical_token) continue
		equipment_assert(statuses && statuses[token]["status"] == "recovered", "NPC successful extraction suppresses every original insured component")
	equipment_assert(M.returns.prepare(M.round_id, list()) && M.returns.ready(), "round resolves after original stolen gear has left world")
	S = M.accounts.open("npcvictim")
	equipment_assert(S && !equipment_mail_entries(M.accounts, "npcvictim").len, "extracted stolen gun and detached optic never return to insured victim")
	S.close()
	qdel(tool)
	qdel(H)
	qdel(E)
	qdel(L)
	map = old_map
	M = new
	M.accounts.store.root = "data/npc_scav_wait/"
	map = M
	equipment_assert(M.ensure_round(), "Scav extraction district starts")
	var/mob/living/simple_animal/hostile/human/extraction/scav = new(T)
	M.npcs |= scav
	var/obj/effect/extraction_exit/scav/scav_exit = new(T)
	scav_exit.opens_after = 0
	scav.extraction_target = scav_exit
	var/obj/item/original = scav.carried_salvage
	equipment_assert(scav.extraction_tick(M) && original.loc == scav, "Scav begins actual adjacent wait without early retirement")
	sleep(11 SECONDS)
	scav.extraction_tick(M)
	equipment_assert(M.accounts.npc_journal.profile["phase"] == "complete" && M.accounts.npc_journal.profile["npc_receipts"]:len == 1 && (!original || !original.loc), "Scav actual elapsed wait commits and retires original carried loot")
	qdel(scav_exit)
	map = old_map
	// Durable uncertain retirement never authorizes a second insurance copy.
	for (var/cut in list("intent", "retired"))
		M = new
		M.accounts.store.root = "data/npc_pending[cut]/"
		map = M
		equipment_assert(M.ensure_round(), "NPC interruption district ready")
		E = new(T)
		E.opens_after = 0
		N = new(T)
		M.npcs |= N
		M.accounts.npc_journal.test_fail_at = cut
		equipment_assert(!M.accounts.npc_journal.retire(M, N, E), "NPC [cut] interruption does not report success")
		reopened = new(M.accounts)
		equipment_assert(!reopened.configure(M.round_id), "NPC [cut] uncertain retirement blocks restart reconciliation")
		qdel(N)
		qdel(E)
	map = old_map
