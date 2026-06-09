/proc/cmp_numeric_dsc(a,b)
	return b - a

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
