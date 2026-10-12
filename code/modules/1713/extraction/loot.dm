// First-access tables use integer basis points and bounded, explicit outcomes.
/datum/extraction_loot_pool
	var/slots
	var/chance
	var/list/outcomes
	var/tmp/list/test_rolls
	New(kind)
		..()
		switch (kind)
			if ("ammunition")
				slots = 2
				chance = 8000
				outcomes = list(list("type" = "/obj/item/ammo_magazine/m9beretta", "rarity" = "common", "weight" = 900, "quantity" = 2), list("type" = "/obj/item/weapon/key/extraction_room", "rarity" = "rare", "weight" = 100, "quantity" = 1))
			if ("workshop")
				slots = 3
				chance = 7500
				outcomes = list(list("type" = "/obj/item/extraction_salvage", "rarity" = "common", "weight" = 900, "quantity" = 1), list("type" = "/obj/item/weapon/attachment/scope/adjustable/advanced/reddot", "rarity" = "rare", "weight" = 100, "quantity" = 1))
			if ("armory")
				slots = 1
				chance = 3500
				outcomes = list(list("type" = "/obj/item/weapon/gun/projectile/pistol/m9beretta", "rarity" = "rare", "weight" = 950, "quantity" = 1), list("type" = "/obj/item/weapon/attachment/scope/adjustable/advanced/reddot", "rarity" = "exceptional", "weight" = 50, "quantity" = 1))
	proc/valid()
		if (!isnum(slots) || round(slots) != slots || slots < 1 || slots > 4 || !isnum(chance) || round(chance) != chance || chance < 0 || chance > 10000 || !islist(outcomes) || outcomes.len < 1 || outcomes.len > 16) return FALSE
		var/datum/extraction_equipment_codec/C = new
		var/total = 0
		for (var/list/outcome in outcomes)
			if (!islist(outcome) || !istext(outcome["type"]) || !C.supported(text2path(outcome["type"])) || !(outcome["rarity"] in list("common", "rare", "exceptional"))) return FALSE
			var/weight = outcome["weight"]
			var/quantity = outcome["quantity"]
			if (!isnum(weight) || round(weight) != weight || weight < 1 || weight > 10000 || !isnum(quantity) || round(quantity) != quantity || quantity < 1 || quantity > 2) return FALSE
			total += weight
		return total <= 10000
	proc/draw(maximum)
		if (test_rolls)
			if (!test_rolls.len) return -1
			var/value = test_rolls[1]
			test_rolls.Cut(1, 2)
			return value
		return rand(0, maximum - 1)
	proc/plan()
		if (!valid()) return null
		var/list/result = list()
		var/total = 0
		for (var/list/outcome in outcomes) total += outcome["weight"]
		for (var/i in 1 to slots)
			var/appearance = draw(10000)
			if (appearance < 0 || appearance >= 10000) return null
			if (appearance >= chance) continue
			var/choice = draw(total)
			if (choice < 0 || choice >= total) return null
			var/cumulative = 0
			for (var/list/outcome in outcomes)
				cumulative += outcome["weight"]
				if (choice < cumulative)
					result += list(outcome.Copy())
					break
		return result

/obj/effect/extraction_loot_marker
	name = "sealed salvage container"
	icon = 'icons/obj/storage.dmi'
	icon_state = "miningcaropen"
	anchored = TRUE
	var/container_id = 0
	var/pool_kind = "workshop"
	var/tmp/list/profile
	var/tmp/busy = FALSE
	var/tmp/locked = FALSE
	var/tmp/last_error
	var/tmp/datum/extraction_loot_pool/test_pool
	var/tmp/test_fail_constructor_after = null
	var/tmp/test_fail_delivery_ack = FALSE
	proc/commit_container(obj/map_metadata/extraction_survival/M, list/candidate)
		if (locked || !M.loot_store.commit_profile("container[container_id]", candidate))
			locked = TRUE
			return FALSE
		profile = candidate
		return TRUE
	proc/prepare(obj/map_metadata/extraction_survival/M)
		if (locked || container_id < 1 || container_id > 64 || round(container_id) != container_id || !M.ensure_loot_epoch()) return FALSE
		if (!profile) profile = M.loot_store.load_profile("container[container_id]")
		if (!profile) return FALSE
		// A fresh raid must not silently discard an uncertain old delivery.
		if (profile["loot_state"] == "pending") return FALSE
		if (profile["raid_sequence"] != M.loot_epoch)
			var/list/fresh = json_decode(json_encode(profile))
			fresh["raid_sequence"] = M.loot_epoch
			fresh["stash"] = list()
			fresh["loot_state"] = "unopened"
			fresh["loot_plan"] = null
			if (!commit_container(M, fresh)) return FALSE
		if (profile["loot_state"] == "ready") return TRUE
		if (profile["loot_state"] == "unopened")
			var/datum/extraction_loot_pool/P = test_pool ? test_pool : new /datum/extraction_loot_pool(pool_kind)
			var/list/plan = P.plan()
			if (!islist(plan)) return FALSE
			var/list/rolled = json_decode(json_encode(profile))
			rolled["loot_plan"] = plan
			rolled["loot_state"] = "planned"
			if (!commit_container(M, rolled)) return FALSE
		if (profile["loot_state"] != "planned") return FALSE
		var/list/entries = list()
		var/list/constructed = list()
		var/complete = TRUE
		try
			var/list/plan = profile["loot_plan"]
			if (!islist(plan) || plan.len > 4) throw EXCEPTION("Invalid loot plan")
			for (var/list/outcome in plan)
				var/path = text2path(outcome["type"])
				if (!M.codec.supported(path) || !isnum(outcome["quantity"]) || outcome["quantity"] < 1 || outcome["quantity"] > 2 || round(outcome["quantity"]) != outcome["quantity"]) throw EXCEPTION("Invalid loot outcome")
				for (var/i in 1 to outcome["quantity"])
					if (!isnull(test_fail_constructor_after) && constructed.len >= test_fail_constructor_after) throw EXCEPTION("Injected loot construction failure")
					var/obj/item/I = new path(null)
					constructed += I
					if (!M.codec.set_raid_provenance(I, TRUE)) throw EXCEPTION("Loot graph rejected")
					var/list/entry = M.record_item(I)
					if (!entry) throw EXCEPTION("Loot serialization rejected")
					entries += list(entry)
		catch (var/exception/E)
			last_error = "[E]"
			complete = FALSE
		for (var/obj/item/I in constructed) qdel(I)
		if (!complete) return FALSE
		var/list/ready = json_decode(json_encode(profile))
		ready["stash"] = entries
		ready["loot_state"] = "ready"
		return commit_container(M, ready)
	proc/claim(obj/map_metadata/extraction_survival/M, mob/living/human/H, id)
		if (locked || !M.owned(H) || H.stat != CONSCIOUS || H.z != 1 || !Adjacent(H) || H.extraction_session.transitioning || H.extraction_session.profile["state"] != "raid" || !profile || profile["loot_state"] != "ready") return null
		var/list/entry
		var/list/candidate = json_decode(json_encode(profile))
		var/list/stash = candidate["stash"]
		for (var/list/next in stash)
			if (next["id"] == id) entry = next
		if (!entry || !M.codec.validate(entry["equipment"])) return null
		stash -= list(entry)
		candidate["loot_state"] = "pending"
		candidate["pending_item"] = entry
		// Debit before exposing a live object. Interrupted delivery stays pending
		// for reconciliation; restarting cannot replay it into another free copy.
		if (!commit_container(M, candidate)) return null
		var/obj/item/I = M.codec.decode(entry["equipment"], H)
		if (!I || !M.track_loot(I))
			if (I) qdel(I)
			locked = TRUE
			return null
		candidate = json_decode(json_encode(profile))
		candidate["loot_state"] = "ready"
		candidate["pending_item"] = null
		if (test_fail_delivery_ack) M.loot_store.test_fail_at = "intent"
		if (!commit_container(M, candidate))
			qdel(I)
			return null
		return I
	attack_hand(mob/user)
		var/mob/living/human/H = user
		var/obj/map_metadata/extraction_survival/M = map
		if (busy || !istype(H) || !istype(M) || !M.owned(H) || H.z != 1 || H.extraction_session.profile["state"] != "raid" || !Adjacent(H)) return
		busy = TRUE
		if (prepare(M))
			var/list/options = list()
			for (var/list/entry in profile["stash"])
				var/list/graph = entry["equipment"]
				var/list/nodes = graph["nodes"]
				var/list/root = nodes[1]
				var/list/scalars = root["scalars"]
				options["[scalars["name"]] ([copytext(entry["id"],1,7)])"] = entry["id"]
			if (options.len)
				var/choice = WWinput(H, "Take one generated item. This container does not restock during this raid.", name, "Cancel", options + list("Cancel"))
				if (options[choice]) claim(M, H, options[choice])
			else to_chat(H, "The container is empty.")
		else to_chat(H, "Container unavailable; pending delivery or recovery may require reconciliation.")
		busy = FALSE

/obj/map_metadata/extraction_survival
	var/datum/extraction_account_store/loot_store = new
	var/datum/extraction_account_store/loot_epoch_store = new
	var/loot_epoch = 0
	var/loot_epoch_locked = FALSE
	proc/ensure_loot_epoch()
		if (loot_epoch_locked) return FALSE
		if (loot_epoch) return TRUE
		loot_store.root = "data/extraction_loot/"
		loot_epoch_store.root = "data/extraction_world/"
		var/list/P = loot_epoch_store.load_profile("world")
		if (!P) return FALSE
		P["raid_sequence"]++
		if (!loot_epoch_store.commit_profile("world", P))
			loot_epoch_locked = TRUE
			return FALSE
		loot_epoch = P["raid_sequence"]
		return TRUE
