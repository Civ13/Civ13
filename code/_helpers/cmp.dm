/proc/cmp_numeric_dsc(a,b)
	return b - a

/proc/cmp_numeric_asc(a,b)
	return a - b

/proc/cmp_text_asc(a,b)
	return sorttext(b,a)

/proc/cmp_text_dsc(a,b)
	return sorttext(a,b)

/proc/cmp_subsystem_init(datum/controller/subsystem/a, datum/controller/subsystem/b)
	return initial(b.init_order) - initial(a.init_order)

/proc/cmp_subsystem_display(datum/controller/subsystem/a, datum/controller/subsystem/b)
	return sorttext(b.name, a.name)

/proc/cmp_subsystem_priority(datum/controller/subsystem/a, datum/controller/subsystem/b)
	return a.priority - b.priority

/proc/cmp_timer(datum/timedevent/a, datum/timedevent/b)
	return a.timeToRun - b.timeToRun

var/atom/cmp_dist_origin=null

/datum/qdel_item
	var/name = ""
	var/qdels = 0			//Total number of times it's passed thru qdel.
	var/destroy_time = 0	//Total amount of milliseconds spent processing this type's Destroy()
	var/failures = 0		//Times it was queued for soft deletion but failed to soft delete.
	var/hard_delete_time = 0//Total amount of milliseconds spent hard deleting this type.

/datum/qdel_item/New(mytype)
	name = "[mytype]"
