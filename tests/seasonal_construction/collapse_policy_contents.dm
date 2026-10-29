// Preparation-only replacement for the historical probe's contents assertion.
// Observe dispatch only. Child/occupant consequences require separate evidence.
var/global/obj/covers/straw_wall/construction_contents_probe_target
var/global/construction_contents_probe_destroy_calls = 0

/obj/covers/straw_wall/Destroy()
	if (src == construction_contents_probe_target)
		construction_contents_probe_destroy_calls++
	return ..()

/proc/construction_probe_contents()
	var/obj/covers/straw_wall/W = new(locate(3,3,1))
	var/obj/item/child = new(W)
	var/obj/item/nested = new(child)
	var/obj/item/neighbor = new(locate(3,3,1))
	construction_contents_probe_target = W
	construction_contents_probe_destroy_calls = 0
	for (var/i = 1, i <= 16, i++) construction_probe_transition()
	W.check_seasonal_construction()
	durable_world_check(W.gc_destroyed && !W.seasonal_construction_index && W.health == 0 && W.seasonal_construction_due == 0 && construction_contents_probe_destroy_calls == 1, "occupied construction postponed terminal destruction or retained paid debt")
	W.check_seasonal_construction()
	durable_world_check(W.health == 0 && W.seasonal_construction_due == 0 && construction_contents_probe_destroy_calls == 1, "repeated service changed terminal debt or destruction dispatch")
	construction_contents_probe_target = null
	// Dispose fixture-owned objects without asserting their fate in normal hooks.
	qdel(child)
	qdel(nested)
	qdel(neighbor)
