// The time a datum was destroyed by the GC, or null if it hasn't been
/datum/var/gcDestroyed = 0
#define GC_COLLECTIONS_PER_RUN 300
#define GC_COLLECTION_TIMEOUT (30 SECONDS)
#define GC_FORCE_DEL_PER_RUN 30

var/list/delayed_garbage = list()
var/list/delayed_hard_garbage = list()

/process/garbage
	var/garbage_collect = TRUE			// Whether or not to actually do work
	var/queued_drained = 0 // Queue entries consumed, excluding direct deletion paths.
	var/total_dels 	= 0			// number of total del()'s
	var/tick_dels 	= 0			// number of del()'s we've done this tick
	var/soft_dels	= 0
	var/hard_dels 	= 0			// number of hard dels in total
	var/list/destroyed = list() // list of refID's of things that should be garbage collected
								// refID's are associated with the time at which they time out and need to be manually del()
								// we do this so we aren't constantly locating them and preventing them from being gc'd

	var/queue_high_water = 0
	var/enqueued = 0
	var/list/hard_references = list()
	var/list/logging = list()	// list of all types that have failed to GC associated with the number of times that's happened.
								// the types are stored as strings

/process/garbage/setup()
	name = "garbage"
	schedule_interval = 5 SECONDS
	start_delay = 0.3 SECONDS
	priority = PROCESS_PRIORITY_HIGH
	processes.garbage = src

	for (var/garbage in delayed_garbage)
		var/datum/A = garbage
		AddTrash(A)
		if (A in delayed_hard_garbage)
			hard_references["\ref[A]"] = A

	delayed_garbage.Cut()
	delayed_garbage = null
	delayed_hard_garbage = null

	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)

#ifdef GC_FINDREF
/world/loop_checks = FALSE
#endif

/process/garbage/fire()
	if (!garbage_collect)
		return

	ExpirePools(32)
	tick_dels = 0
	var/time_to_kill = world.time - GC_COLLECTION_TIMEOUT
	var/checkRemain = GC_COLLECTIONS_PER_RUN
	var/remaining_force_dels = GC_FORCE_DEL_PER_RUN

	while (destroyed.len && --checkRemain >= 0)
		var/refID = destroyed[1]
		var/GCd_at_time = destroyed[refID]
		if (GCd_at_time > time_to_kill)
			#ifdef GC_DEBUG
			#endif
			break // Everything else is newer, skip them
		var/datum/A = locate(refID)
		#ifdef GC_DEBUG
		#endif
		if (A && A.gcDestroyed == GCd_at_time) // So if something else coincidently gets the same ref, it's not deleted by mistake
			// A full hard-delete budget need not retain already-collected entries.
			if (remaining_force_dels <= 0)
				A = null
				break
			#ifdef GC_FINDREF
			LocateReferences(A)
			#endif
			// Something's still referring to the qdel'd object.  Kill it.
			logging["[A.type]"]++
			del(A)

			hard_dels++
			remaining_force_dels--
		else
			#ifdef GC_DEBUG
			#endif
			soft_dels++
		tick_dels++
		queued_drained++
		total_dels++
		hard_references -= refID
		destroyed.Cut(1, 2)
		A = null // Do not retain a mismatched live identity across a budget yield.
		PROCESS_TICK_CHECK

#undef GC_COLLECTION_TIMEOUT

// this process does not use current_list, which will be == null
/process/garbage/reset_current_list()
	return

#ifdef GC_FINDREF

/process/garbage/proc/LocateReferences(var/atom/A)
//	testing("GC: Attempting to locate references to [A] | [A.type]. This is a potentially long-running operation.")
	if (istype(A))
		if (A.loc != null)
//			testing("GC: [A] | [A.type] is located in [A.loc] instead of null")
		if (A.contents.len)
//			testing("GC: [A] | [A.type] has contents: [jointext(A.contents)]")
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
//				testing("GC: [A] | [A.type] referenced by [D] | [D.type], var [V]")
				. += 1
		else
			. += LookForListRefs(D.vars[V], A, D, V)

/process/garbage/proc/LookForListRefs(var/list/L, var/datum/A, var/datum/D, var/V)
	. = 0
	for (var/F in L)
		if (!islist(F))
			if (F == A || L[F] == A)
//				testing("GC: [A] | [A.type] referenced by [D] | [D.type], list [V]")
				. += 1
		else
			. += LookForListRefs(F, A, D, "[F] in list [V]")
#endif

/process/garbage/proc/AddTrash(datum/A)
	if (!istype(A) || A.gcDestroyed > 0)
		return
	#ifdef GC_DEBUG
//	testing("GC: AddTrash(\ref[A] - [A.type])")
	#endif
	A.gcDestroyed = world.time+1
	A.gc_destroyed = A.gcDestroyed
	destroyed -= "\ref[A]" // Removing any previous references that were GC'd so that the current object will be at the end of the list.
	destroyed["\ref[A]"] = A.gcDestroyed
	enqueued++
	queue_high_water = max(queue_high_water, destroyed.len)

/process/garbage/proc/oldest_queue_seconds()
	if (!destroyed.len)
		return 0
	return max(0, (world.time - destroyed[destroyed[1]]) / 10)

/process/garbage/statProcess(client/C)
	..(C)
	C.add_stat("[garbage_collect ? "On" : "Off"], [destroyed.len] queued, [queue_high_water] peak, [oldest_queue_seconds()]s oldest, [enqueued] enqueued, [hard_references.len] forced owners, [pooled_count] pooled")
	C.add_stat("Dels: [total_dels], [soft_dels] soft, [hard_dels] hard, [tick_dels] last run")

/process/garbage/htmlProcess()
	return ..() + "[garbage_collect ? "On" : "Off"], [destroyed.len] queued, [queue_high_water] peak, [oldest_queue_seconds()]s oldest, [enqueued] enqueued, [hard_references.len] forced owners, [pooled_count] pooled<br>Dels: [total_dels], [soft_dels] soft, [hard_dels] hard, [tick_dels] last run"

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
	if (A.gcDestroyed || A.gc_destroyed)
		return
	// Guard reentry without changing legacy cleanup checks inside Destroy.
	A.gc_destroyed = GC_CURRENTLY_BEING_QDELETED
	var/hint = A.Destroy()
	if (!A)
		return
	if (hint == QDEL_HINT_LETMELIVE)
		A.gc_destroyed = 0
		return
	A.gc_destroyed = GC_QUEUED_FOR_QUEUING
	// Pending callbacks must not retain or retire a reused target.
	if (processes.callproc)
		processes.callproc.unqueue(A)
	if (isatom(A))
		var/atom/AT = A
		AT.invisibility = 101
		AT.icon = null
		AT.icon_state = null
		if (ismovable(A))
			var/atom/movable/AM = A
			AM.loc = null
	switch (hint)
		if (QDEL_HINT_IWILLGC)
			A.gcDestroyed = world.time + 1
			A.gc_destroyed = A.gcDestroyed
		if (QDEL_HINT_HARDDEL_NOW)
			A.gcDestroyed = world.time + 1
			A.gc_destroyed = A.gcDestroyed
			del(A)
		if (QDEL_HINT_HARDDEL)
			if (processes.garbage)
				processes.garbage.AddTrash(A)
				processes.garbage.hard_references["\ref[A]"] = A
			else
				A.gcDestroyed = GC_QUEUED_FOR_QUEUING
				delayed_garbage |= A
				delayed_hard_garbage |= A
		else
			A.finalize_qdel()


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
		PlaceInPool(src, TRUE)
	else
		gcDestroyed = world.time + 1
		del(src)

/atom/finalize_qdel()
	if (IsPooled(src))
		PlaceInPool(src, TRUE)
	else
		if (processes.garbage)
			processes.garbage.AddTrash(src)
		else
			gcDestroyed = GC_QUEUED_FOR_QUEUING
			delayed_garbage |= src

/icon/finalize_qdel()
	gcDestroyed = world.time + 1
	del(src)

/image/finalize_qdel()
	gcDestroyed = world.time + 1
	del(src)

/mob/finalize_qdel()
	gcDestroyed = world.time + 1
	del(src)

/turf/finalize_qdel()
	gcDestroyed = world.time + 1
	del(src)
