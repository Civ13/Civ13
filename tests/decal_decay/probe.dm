#ifdef DECAL_BASELINE
// Declaration-only shim for the unused new process in the historical fixture.
/obj/effect/decal/cleanable
	var/decay_index = 0
	var/decay_deadline = null
/obj/effect/decal/cleanable/proc/unregister_decay()
	return
#endif

/world
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf

/obj/effect/decal/cleanable/decay_probe
	decay_timer = 30

/proc/decal_assert(ok, message)
	if (!ok)
		throw EXCEPTION(message)

/world/New()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "byond" = "[world.byond_version].[world.byond_build]")), "metadata.json")
	try
		var/process/decal_decay/P = new
		P.setup()
		var/process/garbage/G = new
		G.setup()
		var/obj/effect/decal/cleanable/decay_probe/early = new(locate(1,1,1))
		var/early_ref = "\ref[early]"
		qdel(early)
		early = null
		sleep(2)
#ifdef DECAL_BASELINE
		decal_assert(locate(early_ref), "baseline sleeping timer retains early-qdel decal")
#else
		decal_assert(!locate(early_ref), "early-qdel decal releases without sleeping timer")
#endif
		var/obj/effect/decal/cleanable/decay_probe/expired = new(locate(2,1,1))
		sleep(35)
#ifndef DECAL_BASELINE
		P.fire()
#endif
#ifdef DECAL_BASELINE
		decal_assert(expired && !expired.loc && !expired.gcDestroyed, "baseline timer calls Destroy without qdel bookkeeping")
#else
		decal_assert(expired && expired.gcDestroyed && !expired.loc, "expiry uses qdel bookkeeping")
#endif
		qdel(expired)
#ifndef DECAL_BASELINE
		decal_assert(!timed_cleanables.len, "expired registry released")
		var/obj/effect/decal/cleanable/decay_probe/fresh = new(locate(1,1,1))
		var/deadline = fresh.decay_deadline
		fresh.do_decay()
		decal_assert(timed_cleanables.len == 1 && fresh.decay_deadline == deadline, "duplicate scheduling neither grows registry nor extends lifetime")
		P.fire()
		decal_assert(!fresh.gcDestroyed, "unexpired decal survives")
		var/savefile/F = new("decal-save.sav")
		F["/format_version"] << 2
		map_storage.saving_z = 1
		var/ref = map_storage.BuildVarDirectory(F, fresh, 1)
		F.cd = map_storage.entry_path(F, ref)
		decal_assert(!("decay_index" in F.dir) && !("decay_deadline" in F.dir), "native serializer excludes runtime fields")
		F["decay_index"] << list("kind" = "value", "value" = 999999)
		F["decay_deadline"] << list("kind" = "value", "value" = -1)
		map_storage.clear_bookkeeping()
		var/obj/effect/decal/cleanable/decay_probe/restored = map_storage.Load_Entry(F, ref, null, locate(2,1,1))
		restored.after_load()
		decal_assert(restored.decay_index > 0 && restored.decay_index != 999999 && restored.decay_deadline >= world.time + 30, "restore ignores stale slots and grants existing lifetime")
		map_storage.clear_bookkeeping()
		qdel(restored); qdel(fresh)
		var/obj/effect/decal/cleanable/raw = new(locate(1,1,1))
		raw.schedule_decay(30)
		del(raw)
		decal_assert(!timed_cleanables.len, "raw Del releases timed registry")
		var/obj/effect/decal/cleanable/blood/B = new(locate(3,1,1))
		decal_assert(B in cleanables && B in processing_objects && B in global.blood, "blood joins existing registries")
		B.decay_deadline = world.time
		P.fire()
		decal_assert(B.gcDestroyed && !(B in cleanables) && !(B in processing_objects) && !(B in global.blood), "blood expiry releases subtype registries")
		for (var/cycle = 1, cycle <= 20, cycle++)
			for (var/n = 1, n <= 1024, n++)
				var/obj/effect/decal/cleanable/decay_probe/C = new(locate(1,1,1))
				C.decay_deadline = world.time
			P.fire()
			decal_assert(timed_cleanables.len == 768, "sweep is capped at256")
			P.fire(); P.fire(); P.fire()
			decal_assert(!timed_cleanables.len && !cleanables.len, "repeated disposal releases both registries")
			sleep(1)
#endif
		text2file("PASS: native decal lifecycle observation", "result.txt")
	catch (var/exception/e)
		text2file("FAIL: [e.name] at [e.file]:[e.line]", "result.txt")
	del(world)
