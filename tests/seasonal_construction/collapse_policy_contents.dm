// Preparation-only replacement for the historical probe's contents assertion.
// Normal destruction may delete contained atoms; no custom relocation/rescue.
/proc/construction_probe_contents()
	var/obj/covers/straw_wall/W = new(locate(3,3,1))
	var/obj/item/child = new(W)
	var/obj/item/nested = new(child)
	var/obj/item/neighbor = new(locate(3,3,1))
	for (var/i = 1, i <= 16, i++) construction_probe_transition()
	W.check_seasonal_construction()
	durable_world_check(W.gc_destroyed && !W.seasonal_construction_index && W.seasonal_construction_due == 0, "occupied construction postponed terminal destruction or retained paid debt")
	durable_world_check(child.gc_destroyed && nested.gc_destroyed && !neighbor.gc_destroyed && neighbor.loc == locate(3,3,1), "normal movable destruction did not own contained atoms or changed the turf neighbor")
	qdel(neighbor)
