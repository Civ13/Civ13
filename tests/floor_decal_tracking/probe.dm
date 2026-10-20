// Actual production decal writer/reset and seasonal reader, native list/image
// semantics, and standard real serializer with isolated world-save adapters.
world
	name = "Civ13 isolated floor decal tracking"
	maxx = 16
	maxy = 8
	maxz = 1
	turf = /turf/floor
	visibility = 0
	sleep_offline = FALSE

/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/client/New()
	del(src)
/world/Error(exception/e)
	world.log << "FAIL diagnostic: [e]"
	shutdown()

/atom/proc/initialize()
	return
/atom/proc/set_dir(value)
	dir = value
/atom/movable
	var/anchored = FALSE
/turf
	var/list/decals
	var/season = "WINTER"
	var/uses_winter_overlay = TRUE
	var/icon_updates = 0
/turf/floor
	var/base_name = "plating"
	var/base_desc = "floor"
	var/base_icon = 'icons/turf/floors.dmi'
	var/base_icon_state = "plating"
	var/decl/flooring/flooring
	var/broken
	var/burnt
	var/flooring_override
/decl/flooring
	var/build_type
/turf/proc/set_light(value)
	return
/turf/proc/levelupdate()
	return
/proc/get_base_turf_by_area(turf/T)
	return /turf/floor
/turf/proc/update_icon(force)
	icon_updates++

var/fixture_checks = 0
var/fixture_failures = 0
/proc/check(condition, label)
	fixture_checks++
	if (!condition)
		fixture_failures++
		world.log << "FAIL [label]"
		throw EXCEPTION("assertion: [label]")

/proc/keys_equal(list/value, list/expected)
	if (!islist(value) || value.len != expected.len) return FALSE
	for (var/i = 1, i <= expected.len, i++)
		if (value[i] != expected[i]) return FALSE
	return TRUE

/proc/initialized_tracking_lists()
	var/list/identities = list()
	var/count = 0
	for (var/turf/T in world)
		if (!isnull(T.floor_decal_cache_keys))
			count++
			identities["\ref[T.floor_decal_cache_keys]"] = TRUE
	world.log << "TRACKING initialized_turfs=[count] distinct_native_lists=[identities.len]"
	return count

/proc/add_decal(turf/T, state)
	var/obj/effect/floor_decal/D = new(T)
	D.icon_state = state
	var/cache_key = "[D.alpha]-[D.color]-[D.dir]-[D.icon_state]-[D.layer]"
	D.initialize()
	return cache_key

/proc/seasonal_states(turf/T)
	var/list/states = list()
	for (var/obj/O in T)
		states += O.icon_state
	return states

/proc/roundtrip(turf/T, path)
	var/map_storage/S = new("decal-fixture")
	S.saving_z = 1
	var/savefile/F = new(path)
	F["/format_version"] << 2
	var/entry = S.BuildVarDirectory(F, T)
	F.Flush()
	S.clear_bookkeeping()
	F = null
	F = new(path)
	var/turf/result = S.Load_Entry(F, entry, old_turf = T)
	S.clear_bookkeeping()
	F = null
	return result

/proc/legacy(turf/T, value, path, include_key = TRUE)
	var/map_storage/S = new("decal-legacy-fixture")
	var/savefile/F = new(path)
	F["/entries/1/type"] << /turf/floor
	if (include_key) F["/entries/1/floor_decal_cache_keys"] << value
	F.Flush()
	F = null
	F = new(path)
	var/turf/result = S.Load_Entry(F, 1, old_turf = T)
	S.clear_bookkeeping()
	F = null
	return result

/world/New()
	..()
	OpenPort("none")
	text2file("closed", "port-closed.txt")
	spawn (0)
		try
			var/eager = world.params["eager"] == "1"
			var/bare = eager ? world.maxx * world.maxy : 0
			check(initialized_tracking_lists() == bare, "bare turf allocation count")
			var/turf/A = locate(1,1,1)
			var/turf/B = locate(2,1,1)
			var/key1 = add_decal(A, "corner_white")
			check(keys_equal(A.floor_decal_cache_keys, list(key1)), "first decal records key")
			check(initialized_tracking_lists() == (eager ? bare : 1), "only first decorated turf allocates")
			var/list/first_list = A.floor_decal_cache_keys
			add_decal(A, "corner_white")
			check(A.floor_decal_cache_keys == first_list && first_list.len == 1, "duplicate keeps same list and unique key")
			var/key2 = add_decal(A, "bordercolor")
			check(keys_equal(A.floor_decal_cache_keys, list(key1,key2)), "insertion order preserved")
			add_decal(B, "bordercolor")
			check(A.floor_decal_cache_keys != B.floor_decal_cache_keys, "two turf lists have independent identity")
			check(keys_equal(A.floor_decal_cache_keys,list(key1,key2)) && keys_equal(B.floor_decal_cache_keys,list(key2)), "second turf does not contaminate first")
			check(initialized_tracking_lists() == (eager ? bare : 2), "two decorated turf allocations")
			fixture_season(A)
			check(keys_equal(seasonal_states(A),list("corner_white","bordercolor")), "season reproduces keys in insertion order")
			var/turf/C = locate(3,1,1)
			fixture_season(C)
			var/list/states = seasonal_states(C)
			check(!states.len && (eager ? islist(C.floor_decal_cache_keys) : isnull(C.floor_decal_cache_keys)), "bare seasonal reader does not allocate")
			C.floor_decal_cache_keys = null
			fixture_season(C)
			check(isnull(C.floor_decal_cache_keys), "explicit null seasonal reader does not allocate")
			C.floor_decal_cache_keys = list()
			fixture_season(C)
			states = seasonal_states(C)
			check(!states.len, "empty seasonal reader")
			B.season = "SPRING"
			fixture_season(B)
			states = seasonal_states(B)
			check(!states.len, "spring suppresses seasonal decals")
			B.season = "WINTER"
			B.uses_winter_overlay = FALSE
			fixture_season(B)
			states = seasonal_states(B)
			check(!states.len, "disabled winter overlay suppresses seasonal decals")
			var/turf/D = locate(4,1,1)
			var/obj/covers/cover = new(D)
			add_decal(D,"corner_white")
			check((eager ? !D.floor_decal_cache_keys.len : isnull(D.floor_decal_cache_keys)) && cover.overlays.len == 1, "cover path does not allocate turf tracking")
			var/turf/E = locate(5,1,1)
			E = new /turf(E)
			add_decal(E,"corner_white")
			check(eager ? !E.floor_decal_cache_keys.len : isnull(E.floor_decal_cache_keys), "nonfloor path does not allocate tracking")
			var/obj/effect/floor_decal/reset/reset = new(A)
			reset.initialize()
			check(!A.decals.len && A.icon_updates == 1, "reset clears decals and updates icon")
			check(keys_equal(A.floor_decal_cache_keys,list(key1,key2)), "reset preserves historical tracking semantics")
			var/turf/floor/cleaned = locate(8,1,1)
			add_decal(cleaned,"corner_white")
			cleaned.make_plating()
			check(isnull(cleaned.decals) && !cleaned.overlays.len, "plating cleanup clears appearance")
			check(keys_equal(cleaned.floor_decal_cache_keys,list(key1)), "plating retains historical tracking semantics")
			cleaned.make_grass()
			cleaned = locate(8,1,1)
			check(eager ? !cleaned.floor_decal_cache_keys.len : isnull(cleaned.floor_decal_cache_keys), "grass replacement has fresh tracking")
			var/turf/Floor = locate(6,1,1)
			add_decal(Floor,"corner_white")
			Floor = new /turf/floor(Floor)
			check(eager ? !Floor.floor_decal_cache_keys.len : isnull(Floor.floor_decal_cache_keys), "replacement turf has no previous tracking")
			// Ordinary turfs use a saved-var allowlist which does not contain this
			// field. Test that contract and explicit/legacy field preservation.
			check(!("floor_decal_cache_keys" in A.get_saved_vars()), "ordinary turf allowlist unchanged")
			A.map_storage_saved_vars += ";floor_decal_cache_keys"
			A = roundtrip(A,"populated.sav")
			check(keys_equal(A.floor_decal_cache_keys,list(key1,key2)), "typed disk roundtrip preserves keys")
			A.floor_decal_cache_keys += "private"
			check(keys_equal(B.floor_decal_cache_keys,list(key2)), "roundtrip retains independent ownership")
			C = roundtrip(locate(7,1,1),"absent.sav")
			check(eager ? islist(C.floor_decal_cache_keys) : isnull(C.floor_decal_cache_keys), "absent saved field keeps declaration default")
			C.floor_decal_cache_keys = null
			C.map_storage_saved_vars += ";floor_decal_cache_keys"
			C = roundtrip(C,"null.sav")
			check(isnull(C.floor_decal_cache_keys), "typed null disk roundtrip")
			C.floor_decal_cache_keys = list()
			C.map_storage_saved_vars += ";floor_decal_cache_keys"
			C = roundtrip(C,"empty.sav")
			check(islist(C.floor_decal_cache_keys) && !C.floor_decal_cache_keys.len, "typed empty disk roundtrip")
			C = legacy(C,"**emptylist","legacy-empty.sav")
			check(islist(C.floor_decal_cache_keys) && !C.floor_decal_cache_keys.len, "legacy empty list remains supported")
			check(add_decal(C,"corner_white") == key1 && keys_equal(C.floor_decal_cache_keys,list(key1)), "legacy empty accepts first decal")
			C = legacy(C,"**null","legacy-null.sav")
			check(isnull(C.floor_decal_cache_keys), "legacy null remains supported")
			C = legacy(C,list(key2,key1),"legacy-list.sav")
			check(keys_equal(C.floor_decal_cache_keys,list(key2,key1)), "legacy list order remains supported")
			C = legacy(C,null,"legacy-absent.sav",FALSE)
			check(eager ? islist(C.floor_decal_cache_keys) : isnull(C.floor_decal_cache_keys), "legacy absent field keeps declaration default")
			if (!fixture_failures) world.log << "PASS floor decal tracking [fixture_checks] checks"
			else world.log << "FAILED floor decal tracking [fixture_failures]/[fixture_checks]"
		catch (var/exception/e)
			world.log << "FAIL exception: [e]"
		shutdown()
