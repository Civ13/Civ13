#include "../../code/modules/1713/extraction/account_store.dm"

/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

/world/New()
	world.OpenPort("none")
	var/datum/extraction_account_store/S = new
	S.root = "./"
	var/owner = world.params["owner"]
	var/action = world.params["action"]
	var/list/report = list("owner" = owner, "action" = action, "success" = FALSE)
	if (S.valid_owner(owner))
		if (action == "inspect")
			var/list/A = S.read_slot(owner, 0)
			var/list/B = S.read_slot(owner, 1)
			report["slots"] = list(A, B)
			report["success"] = !!A && !!B
			for (var/slot in 0 to 1)
				var/path = S.path_for(owner, slot, "intent")
				if (fexists(path))
					try
						report["intent[slot]"] = json_decode(file2text(path))
					catch
						report["success"] = FALSE
		else if (world.params["offline"] == "sole-server-stopped")
			var/generation = text2num(world.params["generation"])
			var/list/P
			if (action == "complete-snapshot") P = S.recover_snapshot(owner, generation, world.params["digest"])
			if (action == "retire-delivery") P = S.retire_pending_delivery(owner, generation, world.params["item"])
			if (action == "retire-vehicle" && world.params["loss"] == "forfeit-paid-car") P = S.retire_pending_vehicle(owner, generation, world.params["item"])
			if (action == "settle-loss" && world.params["loss"] == "discard-account-stash") P = S.settle_pending_loss(owner, generation, world.params["digest"])
			report["success"] = !!P
			if (P) report["revision"] = P["revision"]
	report["error"] = S.last_error
	text2file(json_encode(report), world.params["report"])
	del(world)
