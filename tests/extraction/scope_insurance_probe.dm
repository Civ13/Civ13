// Actor construction and action waiting are injected; gun constructors,
// installation/removal, payment, component graphs and disk I/O are native.
/mob/living/human/extraction_scope_probe
	var/tmp/list/corpse_probe_receipt
	var/tmp/obj/item/corpse_probe_weapon
	New()
		return
	incapacitated(incapacitation_flags = INCAPACITATION_DEFAULT)
		return FALSE
	update_icons()
		return

// Observe native release before qdel clears the retired human reference.
// Other injected actors do not carry a receipt and leave this hook inert.
/hook/corpse_retired/proc/extraction_scope_insurance(mob/living/human/body, turf/site)
	if (!istype(body, /mob/living/human/extraction_scope_probe))
		return TRUE
	var/mob/living/human/extraction_scope_probe/H = body
	if (H.corpse_probe_receipt)
		H.corpse_probe_receipt["count"]++
		H.corpse_probe_receipt["hand_clear"] = !H.r_hand
		H.corpse_probe_receipt["weapon_at_site"] = H.corpse_probe_weapon && H.corpse_probe_weapon.loc == site
	return TRUE

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
		// Exercise the production physical release with an injected actor. This
		// deliberately bypasses elapsed corpse age, not inventory drop callbacks.
		G.forceMove(H)
		H.r_hand = G
		tool.forceMove(T)
		var/list/corpse_graph = C.encode(G)
		var/corpse_revision = A.profile["revision"]
		H.stat = DEAD
		H.register_corpse_decay()
		var/list/corpse_receipt = list("count" = 0)
		H.corpse_probe_receipt = corpse_receipt
		H.corpse_probe_weapon = G
		H.retire_corpse()
		equipment_assert(corpse_receipt["count"] == 1 && corpse_receipt["hand_clear"] && corpse_receipt["weapon_at_site"] && !H && G.loc == T, "corpse retirement releases the actual configured insured weapon")
		equipment_assert(json_encode(C.encode(G)) == json_encode(corpse_graph) && O.extraction_item_id == scope_id && O.health == 41, "physical retirement preserves component IDs, insurance tokens, FIR and condition")
		equipment_assert(A.profile["revision"] == corpse_revision && A.profile["state"] == "raid" && !equipment_mail_entries(S, A.owner).len, "corpse retirement alone cannot settle the raid or credit insurance")
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
		for (var/list/entry in equipment_mail_entries(A.service, A.owner))
			for (var/list/node in entry["equipment"]["nodes"])
				equipment_assert(node["id"] != later_id, "new attachment cannot return through old weapon coverage")
				if (node["id"] == gun_id) guns++
				if (node["id"] == scope_id)
					scopes++
					equipment_assert(node["scalars"]["health"] == 41 && !node["scalars"]["A_attached"] && !node["found_in_raid"], "detached return preserves damage, identity and original FIR")
		equipment_assert(guns == (scenario == 1 ? 0 : 1) && scopes == (scenario == 2 ? 0 : 1), "unextracted covered components return exactly once")
		var/list/pending_ids = list()
		for (var/list/entry in equipment_mail_entries(S, A.owner)) pending_ids += entry["id"]
		equipment_assert(pending_ids.len && !A.claim_insurance_mail(pending_ids), "corpse component returns remain unavailable during the loss round")
		A.close()
		A = S.open("scopeowner")
		equipment_assert(!A.claim_insurance_mail(pending_ids), "reopening the corpse owner's account cannot advance component eligibility")
		A.close()
		equipment_assert(R.prepare("scopeadditionalround", list()), "one additional full round advances corpse component eligibility")
		A = S.open("scopeowner")
		equipment_assert(A.claim_insurance_mail(pending_ids) && !A.claim_insurance_mail(pending_ids), "eligible corpse components transfer to stash exactly once")
		A.close()
		qdel(tool)
