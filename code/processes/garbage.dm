// The time a datum was destroyed by the GC, or null if it hasn't been
/datum/var/gcDestroyed = 0
#define GC_COLLECTIONS_PER_RUN 300
#define GC_COLLECTION_TIMEOUT (30 SECONDS)
#define GC_FORCE_DEL_PER_RUN 30

var/list/delayed_garbage = list()

/process/garbage
	var/garbage_collect = TRUE			// Whether or not to actually do work
	var/total_dels 	= 0			// number of total del()'s
	var/tick_dels 	= 0			// number of del()'s we've done this tick
	var/soft_dels	= 0
	var/hard_dels 	= 0			// number of hard dels in total
	var/list/destroyed = list() // list of refID's of things that should be garbage collected
								// refID's are associated with the time at which they time out and need to be manually del()
								// we do this so we aren't constantly locating them and preventing them from being gc'd

	var/list/logging = list()	// list of all types that have failed to GC associated with the number of times that's happened.
								// the types are stored as strings

/process/garbage/setup()
	name = "garbage"
	schedule_interval = 5 SECONDS
	start_delay = 0.3 SECONDS

	for (var/garbage in delayed_garbage)
		qdel(garbage)

	delayed_garbage.Cut()
	delayed_garbage = null

	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.garbage = src

#ifdef GC_FINDREF
/world/loop_checks = FALSE
#endif

/process/garbage/fire()
	if (!garbage_collect)
		return

	tick_dels = 0
	var/time_to_kill = world.time - GC_COLLECTION_TIMEOUT
	var/checkRemain = GC_COLLECTIONS_PER_RUN
	var/remaining_force_dels = GC_FORCE_DEL_PER_RUN

	while (destroyed.len && --checkRemain >= 0)
		if (remaining_force_dels <= 0)
			#ifdef GC_DEBUG
			testing("GC: Reached max force dels per tick [dels] vs [maxDels]")
			#endif
			break // Server's already pretty pounded, everything else can wait 2 seconds
		var/refID = destroyed[1]
		var/GCd_at_time = destroyed[refID]
		if (GCd_at_time > time_to_kill)
			#ifdef GC_DEBUG
			testing("GC: [refID] not old enough, breaking at [world.time] for [GCd_at_time - time_to_kill] deciseconds until [GCd_at_time + collection_timeout]")
			#endif
			break // Everything else is newer, skip them
		var/datum/A = locate(refID)
		#ifdef GC_DEBUG
		testing("GC: [refID] old enough to test: GCd_at_time: [GCd_at_time] time_to_kill: [time_to_kill] current: [world.time]")
		#endif
		if (A && A.gcDestroyed == GCd_at_time) // So if something else coincidently gets the same ref, it's not deleted by mistake
			#ifdef GC_FINDREF
			LocateReferences(A)
			#endif
			// Something's still referring to the qdel'd object.  Kill it.

			// hey stop fucking spamming me when I start up the server - Kachnov
//			if (world.time > 6000)
//				testing("GC: -- \ref[A] | [A.type] was unable to be GC'd and was deleted --")

			logging["[A.type]"]++
			del(A)

			hard_dels++
			remaining_force_dels--
		else
			#ifdef GC_DEBUG
			testing("GC: [refID] properly GC'd at [world.time] with timeout [GCd_at_time]")
			#endif
			soft_dels++
		tick_dels++
		total_dels++
		destroyed.Cut(1, 2)
		PROCESS_TICK_CHECK

#undef GC_FORCE_DEL_PER_TICK
#undef GC_COLLECTION_TIMEOUT
#undef GC_COLLECTIONS_PER_TICK

// this process does not use current_list, which will be == null
/process/garbage/reset_current_list()
	return

#ifdef GC_FINDREF

/process/garbage/proc/LocateReferences(var/atom/A)
	testing("GC: Attempting to locate references to [A] | [A.type]. This is a potentially long-running operation.")
	if (istype(A))
		if (A.loc != null)
			testing("GC: [A] | [A.type] is located in [A.loc] instead of null")
		if (A.contents.len)
			testing("GC: [A] | [A.type] has contents: [jointext(A.contents)]")
	var/ref_count = 0
	for (var/atom/atom)
		ref_count += LookForRefs(atom, A)
	for (var/datum/datum)	// This is strictly /datum, not subtypes.
		ref_count += LookForRefs(datum, A)
	for (var/client/client)
		ref_count += LookForRefs(client, A)
	var/message = "GC: References found to [A] | [A.type]: [ref_count]."
	if (!ref_count)
		message += " Has likely been supplied as an 'in list' argment to a proc."
	testing(message)

/process/garbage/proc/LookForRefs(var/datum/D, var/datum/A)
	. = 0
	for (var/V in D.vars)
		if (V == "contents")
			continue
		if (!islist(D.vars[V]))
			if (D.vars[V] == A)
				testing("GC: [A] | [A.type] referenced by [D] | [D.type], var [V]")
				. += 1
		else
			. += LookForListRefs(D.vars[V], A, D, V)

/process/garbage/proc/LookForListRefs(var/list/L, var/datum/A, var/datum/D, var/V)
	. = 0
	for (var/F in L)
		if (!islist(F))
			if (F == A || L[F] == A)
				testing("GC: [A] | [A.type] referenced by [D] | [D.type], list [V]")
				. += 1
		else
			. += LookForListRefs(F, A, D, "[F] in list [V]")
#endif

/process/garbage/proc/AddTrash(datum/A)
	if (!istype(A) || A.gcDestroyed)
		return
	#ifdef GC_DEBUG
	testing("GC: AddTrash(\ref[A] - [A.type])")
	#endif
	A.gcDestroyed = world.time+1
	destroyed -= "\ref[A]" // Removing any previous references that were GC'd so that the current object will be at the end of the list.
	destroyed["\ref[A]"] = world.time+1

/process/garbage/statProcess()
	..()
	stat(null, "[garbage_collect ? "On" : "Off"], [destroyed.len] queued")
	stat(null, "Dels: [total_dels], [soft_dels] soft, [hard_dels] hard, [tick_dels] last run")

/process/garbage/htmlProcess()
	return ..() + "[garbage_collect ? "On" : "Off"], [destroyed.len] queued<br>Dels: [total_dels], [soft_dels] soft, [hard_dels] hard, [tick_dels] last run"

// Should be treated as a replacement for the 'del' keyword.
// Datums passed to this will be given a chance to clean up references to allow the GC to collect them.
/proc/qdel(var/datum/A)
	if (!A)
		return
	if (!istype(A))
		warning("qdel() passed object of type [A.type]. qdel() can only handle /datum types.")
		crash_with("qdel() passed object of type [A.type]. qdel() can only handle /datum types.")
		del(A)
		if (processes.garbage)
			processes.garbage.total_dels++
			processes.garbage.hard_dels++
	else if (!A.gcDestroyed)
		// Let our friend know they're about to get collected
		. = !A.Destroy()
		if (. && A)
			A.finalize_qdel()
	if (A && isatom(A))
		var/atom/AT = A
		AT.invisibility = 101
		AT.icon = null
		AT.icon_state = null
		if (ismovable(A))
			var/atom/movable/AM = A
			AM.loc = null // maybe fixes projectiles, hopefully doesn't break anything - Kachnov

/proc/qdel_list(var/list/L)
	if (!L)
		return
	if (!islist(L))
		warning("qdel_list() passed non-list object [L]. qdel_list() can only handle /list types.")
		crash_with("qdel_list() passed non-list object [L]. qdel_list() can only handle /list types.")
		del(L)
		if (processes.garbage)
			processes.garbage.total_dels++
			processes.garbage.hard_dels++
	for (var/D in L)
		L -= D
		if (isdatum(D))
			qdel(D)
	L = null // del(L) breaks observing and probably other stuff I have no idea why - Kachnov

// helper for testing
/datum/proc/qdeleted()
	qdel(src)

/datum/proc/finalize_qdel()
	if (IsPooled(src))
		PlaceInPool(src)
	else
		del(src)

/atom/finalize_qdel()
	if (IsPooled(src))
		PlaceInPool(src)
	else
		if (processes.garbage)
			processes.garbage.AddTrash(src)
		else
			delayed_garbage |= src

/icon/finalize_qdel()
	del(src)

/image/finalize_qdel()
	del(src)

/mob/finalize_qdel()
	del(src)

/turf/finalize_qdel()
	del(src)

// Default implementation of clean-up code.
// This should be overridden to remove all references pointing to the object being destroyed.
// Return true if the the GC controller should allow the object to continue existing. (Useful if pooling objects.)
/datum/proc/Destroy()
	nanomanager.close_uis(src)
	tag = null
	return

#ifdef TESTING
/client/var/running_find_references

/mob/verb/create_thing()
	set category = "Debug"
	set name = "Create Thing"

	var/path = input("Enter path")
	var/atom/thing = new path(loc)
	thing.find_references()

/atom/verb/find_references()
	set category = "Debug"
	set name = "Find References"
	set background = TRUE
	set src in world

	if (!usr || !usr.client)
		return

	if (usr.client.running_find_references)
		testing("CANCELLED search for references to a [usr.client.running_find_references].")
		usr.client.running_find_references = null
		return

	if (WWinput(usr, "Running this will create a lot of lag until it finishes.  You can cancel it by running it again.  Would you like to begin the search?", "Find References", "Yes", list("Yes", "No")) == "No")
		return

	// Remove this object from the list of things to be auto-deleted.
	if (garbage)
		garbage.destroyed -= "\ref[src]"

	usr.client.running_find_references = type
	testing("Beginning search for references to a [type].")
	var/list/things = list()
	for (var/client/thing)
		things += thing
	for (var/datum/thing)
		things += thing
	for (var/atom/thing)
		things += thing
	testing("Collected list of things in search for references to a [type]. ([things.len] Thing\s)")
	for (var/datum/thing in things)
		if (!usr.client.running_find_references) return
		for (var/varname in thing.vars)
			var/variable = thing.vars[varname]
			if (variable == src)
				testing("Found [type] \ref[src] in [thing.type]'s [varname] var.")
			else if (islist(variable))
				if (src in variable)
					testing("Found [type] \ref[src] in [thing.type]'s [varname] list var.")
	testing("Completed search for references to a [type].")
	usr.client.running_find_references = null

/client/verb/purge_all_destroyed_objects()
	set category = "Debug"
	if (garbage)
		while (garbage.destroyed.len)
			var/datum/o = locate(garbage.destroyed[1])
			if (istype(o) && o.gcDestroyed)
				del(o)
				garbage.dels++
			garbage.destroyed.Cut(1, 2)
#endif

#ifdef GC_DEBUG
#undef GC_DEBUG
#endif

#ifdef GC_FINDREF
#undef GC_FINDREF
#endif
