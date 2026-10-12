// Isolated native fixture: production GC, pool and callback scheduler bodies.
#define TRUE 1
#define FALSE 0
#define SECONDS * 10
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
#include "../../code/_helpers/datum_pool.dm"
#include "../../code/processes/garbage.dm"
#include "../../code/processes/callproc.dm"
var/cleanups = 0
var/assertions = 0
var/list/calls = list()
/obj/probe
	var/hint = QDEL_HINT_QUEUE
	var/reentry = FALSE
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
/world/New()
	try
		processes.garbage = new
		processes.callproc = new
		processes.callproc.setup()
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
		text2file("PASS: [assertions] memory ownership assertions", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E]", "result.txt")
	if (world.params["case"] == "memory")
		sleep(20)
	del(world)
