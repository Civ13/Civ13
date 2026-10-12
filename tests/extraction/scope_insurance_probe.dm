// Actor construction and action waiting are injected; gun constructors,
// installation/removal, payment, component graphs and disk I/O are native.
/mob/living/human/extraction_scope_probe
	New()
		return
	incapacitated(incapacitation_flags = INCAPACITATION_DEFAULT)
		return FALSE
	update_icons()
		return
/obj/item/weapon/gun/projectile/semiautomatic/sks/extraction_scope_probe
	wait_for_configuration(mob/living/human/H, delay)
		return TRUE

/proc/equipment_scope_insurance_probe(datum/extraction_equipment_codec/C)
	for (var/scenario in 1 to 3)
		var/datum/extraction_service/S = new
		S.store.root = "data/scope_insurance[scenario]/"
		var/datum/extraction_session/A = S.open("scopeowner")
		var/turf/T = locate(3,6,1)
		var/mob/living/human/extraction_scope_probe/H = new(T)
		var/obj/item/weapon/screwdriver/tool = new(H)
		var/obj/item/weapon/gun/projectile/semiautomatic/sks/extraction_scope_probe/G = new(T)
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso1/O = new(T)
		equipment_assert(G.install_configuration(O, H, TRUE), "native scope installs before insurance purchase")
		var/list/graph = C.encode(G)
		var/gun_id = G.extraction_item_id
		var/scope_id = O.extraction_item_id
		var/list/stash = list(list("id" = gun_id, "equipment" = graph))
		for (var/i in 1 to 5)
			var/obj/item/extraction_salvage/part = new(T)
			var/list/part_graph = C.encode(part)
			stash += list(list("id" = part.extraction_item_id, "equipment" = part_graph))
			qdel(part)
		equipment_assert(A.checkpoint_home(stash), "scope fixture provisions actual premium")
		qdel(G)
		var/datum/extraction_insurance_returns/R = new(S, C)
		var/list/offer = R.quote(A, list(gun_id), "scoperound")
		var/list/raid = R.paid_deploy(A, offer, "PMC")
		equipment_assert(raid && offer["cost"] >= 2, "insurance charges for gun, individual scope and native reusable components")
		G = C.decode(raid["issued"][1]["equipment"], H)
		O = G.scope
		H.r_hand = G
		equipment_assert(O && O.extraction_insurance_token && G.remove_configuration(O, H) && O.loc == T && !G.scope, "native scope removal preserves covered identity")
		O.health = 41
		var/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pso1/later = new(T)
		equipment_assert(G.install_configuration(later, H, TRUE) && !later.extraction_insurance_token, "post-purchase attachment receives no coverage")
		C.encode(later)
		var/later_id = later.extraction_item_id
		G.forceMove(T)
		H.r_hand = null
		var/list/roots = list()
		if (scenario == 1)
			equipment_assert(A.extract(raid["sequence"], list(list("id" = gun_id, "equipment" = C.encode(G)))), "weapon extracts while original scope remains behind")
			qdel(G)
			roots += O
		else
			equipment_assert(A.forfeit(raid["sequence"]), "original weapon remains recoverable after loss")
			roots += G
			if (scenario == 2)
				var/datum/extraction_session/B = S.open("scoperecipient")
				var/list/other = B.begin_raid(list())
				equipment_assert(B.extract(other["sequence"], list(list("id" = scope_id, "equipment" = C.encode(O)))), "other account extracts original detached scope")
				B.close()
				qdel(O)
			else roots += O
		A.close()
		equipment_assert(R.prepare("scoperound", roots), "covered components reconcile independently")
		A = S.open("scopeowner")
		var/guns = 0
		var/scopes = 0
		for (var/list/entry in A.profile["insurance_mailbox"])
			for (var/list/node in entry["equipment"]["nodes"])
				equipment_assert(node["id"] != later_id, "new attachment cannot return through old weapon coverage")
				if (node["id"] == gun_id) guns++
				if (node["id"] == scope_id)
					scopes++
					equipment_assert(node["scalars"]["health"] == 41 && !node["scalars"]["A_attached"] && !node["found_in_raid"], "detached return preserves damage, identity and original FIR")
		equipment_assert(guns == (scenario == 1 ? 0 : 1) && scopes == (scenario == 2 ? 0 : 1), "unextracted covered components return exactly once")
		A.close()
		qdel(tool)
		qdel(H)
