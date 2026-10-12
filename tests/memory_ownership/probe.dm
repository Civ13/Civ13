// Isolated native fixture: production GC, pool and callback scheduler bodies.
#define TRUE 1
#define FALSE 0
#define SECONDS * 10
#define MINUTES * 600
#define INFINITY 1e30
#define GAME_STATE_PREGAME 0
#define GAME_STATE_SETTING_UP 1
#define GAME_STATE_PLAYING 2
#define GAME_STATE_FINISHED 3
#define PROCESS_PRIORITY_HIGH 1
#define PROCESS_PRIORITY_VERY_HIGH 2
#define PROCESS_TICK_CHECK
#define isatom(X) istype(X, /atom)
#define ismovable(X) istype(X, /atom/movable)
#define isdatum(X) istype(X, /datum)
#define isDeleted(X) (!X || X:gcDestroyed)
#include "../../code/__defines/qdel.dm"
/datum
	var/gc_destroyed = 0
/datum/proc/Destroy()
	return QDEL_HINT_QUEUE
/process
	var/name
	var/schedule_interval
	var/start_delay
	var/priority
	var/list/fires_at_gamestates
	var/datum/current
/process/proc/setup()
/process/proc/fire()
/process/proc/reset_current_list()
/process/proc/statProcess(client/C)
/process/proc/htmlProcess()
	return ""
/client/proc/add_stat(value)
/datum/process_holder
	var/process/garbage/garbage
	var/process/callproc/callproc
var/datum/process_holder/processes = new
/proc/path2text(value)
	return "[value]"
/proc/warning(message)
	world.log << message
/proc/crash_with(message)
	throw message
/proc/log_debug(message)
	world.log << message
/proc/to_chat(target, message)
	return
/proc/pick_n_take(list/L)
	var/datum/D = L[L.len]
	L.Cut(L.len, L.len + 1)
	return D
// Type identities only; production constructors are covered by game probes.
/atom/movable/overlay
/atom/movable/lighting_overlay
/obj/effect/mist
/obj/effect/effect/steam
/obj/effect/sparks
/obj/effect/effect/smoke
/obj/effect/projectile
/datum/effect/effect/system/spark_spread
/datum/effect/effect/system/smoke_spread
/obj/effect/decal/cleanable/blood/splatter
/obj/item/stack/rods
#include "../../code/_helpers/datum_pool.dm"
#include "../../code/processes/garbage.dm"
#include "../../code/processes/callproc.dm"
var/cleanups = 0
var/assertions = 0
var/list/calls = list()
/obj/probe
	var/hint = QDEL_HINT_QUEUE
	var/reentry = FALSE
/obj/probe/startup
/obj/probe/cap1
/obj/probe/cap2
/obj/probe/cap3
/obj/probe/cap4
/obj/probe/cap5
/obj/probe/cap6
/obj/probe/cap7
/obj/probe/cap8
/obj/probe/cap9
/obj/probe/cap10
/obj/probe/cap11
/obj/unreviewed
/obj/probe/Destroy()
	cleanups++
	if (reentry && cleanups == 1)
		qdel(src)
	return hint
/datum/callback_probe/proc/hit(value)
	calls += value
/datum/callback_probe/proc/cancel_self()
	processes.callproc.unqueue(src)
	processes.callproc.queue(src, /datum/callback_probe/proc/hit, list(666), 100)
/datum/callback_probe/proc/raise_error()
	throw "expected callback failure"
/proc/check(ok, message)
	assertions++
	if (!ok)
		throw message
/world
	maxx = 2
	maxy = 2
	maxz = 1
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/New()
	world.OpenPort("none")
	try
		processes.garbage = new
		processes.callproc = new
		processes.callproc.setup()
		if (world.params["policy_tests"])
			pool_type_roots += /obj/probe
		var/scenario = world.params["case"]
		if (scenario == "memory")
			var/datum/callback_probe/target = new
			var/list/payload = list()
			payload.len = 2000000
			processes.callproc.queue(target, /datum/callback_probe/proc/hit, payload, 100)
			payload = null
			target.gcDestroyed = 1
			processes.callproc.fire()
			var/callproc_helper/held = processes.callproc.current
			var/retained = held && held.args ? held.args.len : 0
			held = null
			target = null
			text2file("retained_argument_slots=[retained]", "benchmark.txt")
		if (scenario == "benchmark")
			var/datum/callback_probe/target = new
			var/start = world.timeofday
			for (var/i = 1 to 150000)
				processes.callproc.queue(target, /datum/callback_probe/proc/hit, list(i), 0)
				processes.callproc.fire()
				calls.Cut()
			var/elapsed = world.timeofday - start
			var/list/retired = list()
			for (var/i = 1 to 4000)
				processes.callproc.queue(target, /datum/callback_probe/proc/hit, list(new /datum), 100)
				retired += processes.callproc.queue[1]
				processes.callproc.unqueue(target)
			var/retained = 0
			for (var/callproc_helper/C in retired)
				if (C.object || C.args)
					retained++
			text2file("elapsed_deciseconds=[elapsed] retained_cancelled_helpers=[retained] reserve=[processes.callproc.helpers.len]", "benchmark.txt")
		if (scenario == "callback" || !scenario)
			var/datum/callback_probe/target = new
			var/datum/argument = new
			processes.callproc.queue(target, /datum/callback_probe/proc/hit, list(111), 10)
			processes.callproc.queue(target, /datum/callback_probe/proc/hit, list(222), 0)
			processes.callproc.fire()
			check(calls.len == 1 && calls[1] == 222, "future callbacks do not block due work")
			var/callproc_helper/future = processes.callproc.queue[1]
			future.time = world.time
			processes.callproc.fire()
			check(calls.len == 2 && calls[2] == 111, "future callback executes when due")
			calls = list()
			for (var/i = 1 to 3)
				processes.callproc.queue(target, /datum/callback_probe/proc/hit, list(i), 0)
			check(!processes.callproc.unqueue(target, 0), "zero cancellation limit removes nothing")
			processes.callproc.unqueue(target, 1)
			processes.callproc.fire()
			check(calls.len == 2 && calls[1] == 2 && calls[2] == 3, "limited cancellation preserves ordered remaining calls")
			calls = list()
			for (var/i = 1 to 7000)
				processes.callproc.queue(target, /datum/callback_probe/proc/hit, list(argument), 100)
				var/callproc_helper/C = processes.callproc.queue[1]
				processes.callproc.unqueue(target)
				check(C && !C.object && !C.args && !C.function && C.time == -1, "cancel clears helper target and arguments")
				check(processes.callproc.helpers.len == 5000 && !processes.callproc.queue.len, "cancel preserves reusable reserve")
			processes.callproc.queue(target, /datum/callback_probe/proc/hit, null, 0)
			var/callproc_helper/C = processes.callproc.queue[1]
			C.object = null
			processes.callproc.fire()
			check(!C.args && !C.object && processes.callproc.helpers.len == 5000, "invalid target recycles helper")
			for (var/i = 1 to 5001)
				processes.callproc.queue(target, /datum/callback_probe/proc/hit, list(i), 0)
			processes.callproc.fire()
			check(calls.len == 5001 && calls[1] == 1 && calls[5001] == 5001, "reserve exhaustion preserves due call order")
			check(processes.callproc.helpers.len == 5000 && !processes.callproc.queue.len, "overflow helper discarded after release")
			calls = list()
			processes.callproc.queue(target, /datum/callback_probe/proc/cancel_self, null, 0)
			processes.callproc.fire()
			check(processes.callproc.queue.len == 1 && processes.callproc.helpers.len == 4999, "self cancellation does not erase reused helper work")
			future = processes.callproc.queue[1]
			future.time = world.time
			processes.callproc.fire()
			check(calls.len == 1 && calls[1] == 666 && processes.callproc.helpers.len == 5000, "reentrant scheduled work executes once")
			processes.callproc.queue(target, /datum/callback_probe/proc/raise_error, null, 0)
			var/caught = FALSE
			try
				processes.callproc.fire()
			catch
				caught = TRUE
			check(caught && !processes.callproc.queue.len && processes.callproc.helpers.len == 5000, "throwing callback releases helper before invocation")
			if ("by_object" in processes.callproc.vars)
				var/list/index = processes.callproc.vars["by_object"]
				check(!index.len, "all completed callbacks release cancellation index")
				var/list/targets = list()
				for (var/i = 1 to 60)
					var/datum/callback_probe/T = new
					targets += T
					for (var/j = 1 to 10)
						processes.callproc.queue(T, /datum/callback_probe/proc/hit, null, 100)
				check(index.len == 60 && processes.callproc.queue.len == 600, "index holds only targets with pending work")
				processes.callproc.unqueue(targets[30], 1)
				check(processes.callproc.queue.len == 599 && index[targets[30]]:len == 9, "indexed limited cancellation leaves other targets unchanged")
				for (var/datum/T in targets)
					processes.callproc.unqueue(T)
				check(!index.len && !processes.callproc.queue.len && processes.callproc.helpers.len == 5000, "indexed mass cancellation releases all owners")
				var/callproc_helper/released = processes.callproc.helpers[1]
				call(processes.callproc, "release_helper")(released)
				check(released && processes.callproc.helpers.len == 5000, "duplicate release leaves reserve membership intact")
		if (scenario == "turf" || !scenario)
			var/obj/probe/A = new
			qdel(A)
			var/count = processes.garbage.destroyed.len
			qdel(locate(1,1,1))
			check(processes.garbage.destroyed.len == count, "turf deletion preserves unrelated GC queue entry")
		if (scenario == "lifecycle" || !scenario)
			var/obj/probe/A = new(locate(1,1,1))
			cleanups = 0
			A.reentry = TRUE
			qdel(A)
			check(cleanups == 1 && QDELETED(A) && isDeleted(A), "reentry cleans once and deletion markers agree")
			var/obj/probe/live = new(locate(1,1,1))
			live.hint = QDEL_HINT_LETMELIVE
			qdel(live)
			check(live.loc && !QDELETED(live) && !isDeleted(live), "let-me-live preserves live state and location")
			var/obj/probe/immediate = new
			immediate.hint = QDEL_HINT_HARDDEL_NOW
			qdel(immediate)
			check(!immediate, "hard-delete-now hint deletes immediately")
		if (scenario == "pool" || !scenario)
			var/obj/probe/A = PoolOrNew(/obj/probe)
			cleanups = 0
			qdel(A)
			check(cleanups == 1 && QDELETED(A), "pooled deletion cleans once and remains retired")
			var/obj/probe/reused = PoolOrNew(/obj/probe)
			check(reused == A && !QDELETED(reused) && !isDeleted(reused), "pooled reuse resets deletion state")
			var/list/objects = list(reused)
			for (var/i = 1 to 110)
				objects += PoolOrNew(/obj/probe)
			for (var/obj/probe/O in objects)
				qdel(O)
			check(GlobalPool[/obj/probe].len == 100, "pool respects exact per-type cap")
		if (world.params["policy_tests"])
			var/obj/probe/free = new
			free.hint = QDEL_HINT_IWILLGC
			var/count = processes.garbage.destroyed.len
			qdel(free)
			check(free && QDELETED(free) && isDeleted(free) && processes.garbage.destroyed.len == count, "will-GC retires without a forced queue")
			var/obj/probe/hard = new
			hard.hint = QDEL_HINT_HARDDEL
			qdel(hard)
			var/refID = "\ref[hard]"
			check(processes.garbage.hard_references[refID] == hard, "hard-delete hint retains its queued target")
			var/obj/probe/identity = new
			qdel(identity)
			var/identity_ref = "\ref[identity]"
			// A mismatched queue stamp must not destroy a reused identity.
			processes.garbage.destroyed[identity_ref] = world.time - 1000
			processes.garbage.destroyed[refID] = world.time - 1000
			hard.gcDestroyed = world.time - 1000
			// Older existing entries otherwise stop the chronological sweep.
			for (var/key in processes.garbage.destroyed.Copy())
				if (key != refID && key != identity_ref)
					processes.garbage.destroyed -= key
			var/drained_before = processes.garbage.queued_drained
			var/total_before = processes.garbage.total_dels
			processes.garbage.fire()
			check(processes.garbage.queued_drained == drained_before + 2 && processes.garbage.total_dels == total_before + 2, "queue drain counter counts exactly the two consumed entries")
			check(!hard && !processes.garbage.hard_references.len, "forced deletion releases the strong queue owner")
			check(identity, "timestamp guard preserves a live reused identity")
			processes.garbage = null
			delayed_garbage = list()
			delayed_hard_garbage = list()
			var/obj/probe/early = new /obj/probe/startup
			cleanups = 0
			qdel(early)
			qdel(early)
			check(cleanups == 1 && QDELETED(early) && isDeleted(early) && (early in delayed_garbage), "startup queue retires and cleans once")
			var/obj/probe/early_hard = new /obj/probe/startup
			early_hard.hint = QDEL_HINT_HARDDEL
			qdel(early_hard)
			processes.garbage = new
			processes.garbage.setup()
			check(early.gcDestroyed > 0 && early.gc_destroyed == early.gcDestroyed, "startup queue becomes stamped without repeating cleanup")
			check(processes.garbage.hard_references["\ref[early_hard]"] == early_hard, "startup hard-delete ownership survives setup")
			var/obj/unreviewed/U = PoolOrNew(/obj/unreviewed)
			qdel(U)
			check(!GlobalPool[/obj/unreviewed], "unreviewed types do not create pools")
			for (var/typepath in typesof(/obj/probe))
				if (typepath == /obj/probe)
					continue
				var/list/batch = list()
				for (var/i = 1 to 101)
					batch += PoolOrNew(typepath)
				for (var/obj/probe/O in batch)
					qdel(O)
				check(GlobalPool[typepath].len <= 100, "each reviewed type stays capped")
			check(pooled_count == 1000 && pool_idle.len == 1000, "global pool ownership stays capped")
			for (var/datum/D in pool_idle)
				pool_idle[D] = world.time - 1
			ExpirePools(32)
			check(pooled_count == 968 && pool_idle.len == 968, "idle eviction has a strict per-sweep budget")
			var/datum/reused = GetFromPool(/obj/probe/cap1, null)
			check(reused && !QDELETED(reused) && pooled_count == 967 && pool_idle.len == 967, "reuse releases idle bookkeeping and resets state")
		text2file("PASS: [assertions] memory ownership assertions", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E]", "result.txt")
	if (world.params["case"] == "memory")
		sleep(20)
	del(world)
