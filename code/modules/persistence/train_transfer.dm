// Physical consist transfer integration. Route planning and manifest validation
// are available, but destructive departures are deliberately not enabled until
// immutable world escrow and grouped account custody have native acceptance.
// This is not a fallback to independent character transfers.
/obj/structure/trains/var/tmp/train_transfer_busy = FALSE

/obj/structure/trains/persistence_runtime_var(key)
	if(key == "train_transfer_busy") return TRUE
	return ..()

/proc/train_transfer_departure_problem(obj/structure/trains/head, turf/edge)
	if(!head || QDELETED(head)) return "The train no longer exists."
	if(head.train_transfer_busy) return "This train already has a transfer in progress."
	if(!transfer_bridge.ready() || persistence_save_active()) return "The transfer network is unavailable or the world is saving."
	var/problem = train_route_departure_problem(head, edge)
	if(problem) return problem
	// Never run a deletion/recreation transport with an unprotected snapshot:
	// passengers can mutate inventories while the agent request sleeps.
	return "Physical train departures are not enabled: safe whole-train escrow and account custody are still being integrated."
