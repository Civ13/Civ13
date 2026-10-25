// Prepared source only. Execution requires the separate reviewed controller.
// Production module/process and the two exact hooks are included by the DME.
// SNOW_NATIVE_HEAD/TREE/VERSION/MODE are immutable generated binding macros.
var/global/list/snow_fixture_assertions = list()
var/global/snow_fixture_failed = 0

/world
	maxx = 18
	maxy = 18
	maxz = 3
	turf = /turf/sky
	area = /area/caribbean
	visibility = 0
	hub = ""
	sleep_offline = FALSE
	fps = 10

/world/OpenPort(port)
	if (port != "none")
		..("none")
		return FALSE
	return ..("none")

/client/New()
	del(src)
	return

/world/Topic()
	return null

/proc/snow_fixture_assert(id, condition)
	if (id in snow_fixture_assertions)
		throw EXCEPTION("Duplicate fixture assertion: [id]")
	var/result = condition ? 1 : 0
	snow_fixture_assertions[id] = result
	if (!result)
		snow_fixture_failed++
	world.log << "SNOW_ASSERT [id]=[result]"

/proc/snow_fixture_reset()
	persistence_save_in_progress = FALSE
	persistence_active_operation = null
	persistence_load_recovery_required = FALSE
	for (var/obj/O in world)
		del(O)
	if (!snow_fixture_outdoors)
		snow_fixture_outdoors = new /area/caribbean
	snow_fixture_outdoors.location = AREA_OUTSIDE
	snow_fixture_outdoors.weather = WEATHER_WET
	snow_fixture_outdoors.weather_intensity = 1
	snow_fixture_outdoors.icon_state = "snow1"
	for (var/turf/T in world)
		if (T.type != /turf/sky)
			T = new /turf/sky(T)
		snow_fixture_outdoors.contents += T
	// Explicit fresh-case adapter state, never a reversible real-world helper.
	snowfall_ground = list()
	snowfall_ground_cursor = 1
	snowfall_ground_next = 0
	next_snowfall_ground_generation = 0
	snow_fixture_links = list()
	snow_fixture_temperature_calls = 0
	snow_fixture_topology_calls = 0

/proc/snow_fixture_put(kind = /turf/floor/dirt, px = 2, py = 2, pz = 1)
	var/turf/T = new kind(locate(px, py, pz))
	return T

/proc/snow_fixture_hold(which)
	persistence_save_in_progress = which == 1
	persistence_active_operation = which == 2 ? "fixture operation" : null
	persistence_load_recovery_required = which == 3

/proc/snow_fixture_registry_exact(expected_length)
	if (snowfall_ground.len != expected_length)
		return FALSE
	var/list/coordinates = list()
	for (var/i = 1, i <= snowfall_ground.len, i++)
		var/turf/T = snowfall_ground[i]
		if (!T || !T.snowfall_ground_eligible() || T.snowfall_ground_index != i || locate(T.x, T.y, T.z) != T)
			return FALSE
		var/key = snow_fixture_key(T)
		if (key in coordinates)
			return FALSE
		coordinates += key
	return TRUE

/proc/snow_fixture_appearance_count(turf/T, wanted_layer, wanted_plane)
	var/count = 0
	// Native overlays contain appearances, NOT /image datum references.
	for (var/A in T.overlays)
		if (A:icon == 'icons/turf/snow.dmi' && A:icon_state == "snow" && A:layer == wanted_layer && A:plane == wanted_plane)
			count++
	return count

/proc/snow_fixture_add_sentinel(turf/T)
	var/image/I = image('icons/turf/snow.dmi', icon_state = "snow", layer = 5)
	I.plane = T.plane
	T.overlays += I
	return I

// Causal control 1: omit only production overlay publication.
/proc/snow_fixture_case_appearance()
	snow_fixture_reset()
	var/turf/floor/T = snow_fixture_put()
	T.plane = 7
	var/image/sentinel = snow_fixture_add_sentinel(T)
	snow_fixture_assert("appearance_setup", isnull(T.flooring) && T.weather_snow == 0 && sentinel && snow_fixture_appearance_count(T, 5, 7) == 1)
	T.snowfall_ground_check()
	snow_fixture_assert("appearance_present", T.weather_snow == 1 && T.weather_snow_overlay && snow_fixture_appearance_count(T, 2.03, 7) == 1)
	snow_fixture_assert("appearance_sentinel_preserved", snow_fixture_appearance_count(T, 5, 7) == 1)

// Causal control 2: a live token meets a newly warm injected temperature.
/proc/snow_fixture_case_warm_debit()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	T.available_snow = 7
	T.snowfall_ground_check()
	var/token = T.snowfall_ground_generation
	snow_fixture_assert("warm_debit_setup", T.weather_snow == 1 && token > 0 && T.fixture_temperature_calls == 1)
	T.fixture_temperature_c = 2.5
	var/taken = T.take_snow(token, TRUE)
	snow_fixture_assert("warm_debit_rejects", !taken && T.weather_snow == 0 && T.snowfall_ground_generation != token && T.available_snow == 7)

// Causal control 3: invalidate a token by melting then creating a fresh layer.
/proc/snow_fixture_case_stale_reaccumulation()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	T.snowfall_ground_check()
	var/old_token = T.snowfall_ground_generation
	T.fixture_temperature_c = 2.5
	T.snowfall_ground_check()
	T.fixture_temperature_c = 0
	T.snowfall_ground_check()
	var/current_token = T.snowfall_ground_generation
	snow_fixture_assert("stale_reaccumulation_setup", T.weather_snow == 1 && old_token > 0 && current_token != old_token)
	var/taken = T.take_snow(old_token, TRUE)
	snow_fixture_assert("stale_after_reaccumulation", !taken && T.weather_snow == 1 && T.snowfall_ground_generation == current_token)

// Causal control 4: capture the CURRENT live token immediately before reload.
/proc/snow_fixture_case_reload_generation()
	snow_fixture_reset()
	var/turf/floor/T = snow_fixture_put()
	T.snowfall_ground_check()
	var/token = T.snowfall_ground_generation
	snow_fixture_assert("fresh_wait_reload_setup", T.weather_snow == 1 && token > 0 && token == T.snowfall_ground_generation && T.snowfall_ground_index > 0)
	T.after_load()
	var/reloaded_token = T.snowfall_ground_generation
	var/taken = T.take_snow(token, TRUE)
	snow_fixture_assert("fresh_wait_invalidated_by_reload", reloaded_token != token && !taken && T.weather_snow == 1)

// Causal control 5: zero AND one units under active cold snowfall, not the cap.
// One aggregate target keeps this causal control at exactly one failed ID.
/proc/snow_fixture_case_reload_sampling()
	snow_fixture_reset()
	var/turf/floor/zero = snow_fixture_put()
	var/turf/floor/one = snow_fixture_put(/turf/floor/grass, 3, 2, 1)
	one.snowfall_ground_check()
	snow_fixture_assert("reload_no_accrual_setup", zero.weather_snow == 0 && one.weather_snow == 1 && zero.snowfall_ground_index > 0 && one.snowfall_ground_index > 0)
	var/temperature_before = snow_fixture_temperature_calls
	var/topology_before = snow_fixture_topology_calls
	zero.after_load()
	one.after_load()
	snow_fixture_assert("reload_zero_no_accrual", zero.weather_snow == 0 && one.weather_snow == 1 && snow_fixture_temperature_calls == temperature_before && snow_fixture_topology_calls == topology_before)

// Causal control 6: native turf references can retarget. Coordinate/type/index
// and generation checks, not old_ref != new_ref, establish retirement.
/proc/snow_fixture_case_replacement()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	snow_fixture_put(/turf/floor/grass, 3, 2, 1)
	T.snowfall_ground_check()
	var/token = T.snowfall_ground_generation
	snow_fixture_assert("replacement_setup", snow_fixture_registry_exact(2) && T.weather_snow == 1 && token > 0)
	snow_fixture_put(/turf/floor/grass, 2, 2, 1)
	var/turf/current = locate(2, 2, 1)
	current.snowfall_ground_check()
	var/current_token = current.snowfall_ground_generation
	var/valid = current.type == /turf/floor/grass && current.weather_snow == 1 && current_token != token && snow_fixture_registry_exact(2)
	var/taken = current.take_snow(token, TRUE)
	valid = valid && !taken && current.weather_snow == 1 && current.snowfall_ground_generation == current_token
	snow_fixture_put(/turf/floor/wood, 2, 2, 1)
	current = locate(2, 2, 1)
	valid = valid && current.type == /turf/floor/wood && current.snowfall_ground_index == 0 && snow_fixture_registry_exact(1)
	snow_fixture_assert("replacement_registry_exact", valid)

/proc/snow_fixture_case_eligibility_weather()
	snow_fixture_reset()
	var/turf/floor/D = snow_fixture_put()
	var/turf/floor/G = snow_fixture_put(/turf/floor/grass, 3, 2, 1)
	snow_fixture_assert("exact_ground_eligible", D.snowfall_ground_eligible() && G.snowfall_ground_eligible())
	snow_fixture_assert("constructor_registers_null_flooring", isnull(D.flooring) && isnull(G.flooring) && snow_fixture_registry_exact(2))
	var/list/excluded = list(/turf/floor/dirt/fixture_subtype, /turf/floor/grass/fixture_subtype, /turf/floor/dirt/ploughed, /turf/floor/dirt/underground, /turf/floor/winter, /turf/floor/winter/grass, /turf/floor/beach/sand, /turf/floor/wood, /turf/floor/beach/water, /turf/floor/beach/water/ice)
	var/exclusions_ok = TRUE
	for (var/kind in excluded)
		var/turf/T = snow_fixture_put(kind, 4, 2, 1)
		T.snowfall_ground_check()
		if (T.snowfall_ground_eligible() || T.snowfall_ground_index || T.weather_snow || T.fixture_temperature_calls)
			exclusions_ok = FALSE
	snow_fixture_assert("subtype_and_authored_terrain_excluded", exclusions_ok)
	var/snow_ok = TRUE
	var/list/snow_icons = list("snow1", "snow2", "snow_storm", "rad_snow1", "rad_snow2", "rad_snow_storm")
	for (var/weather_kind in list(WEATHER_WET, WEATHER_EXTREME))
		for (var/state in snow_icons)
			D = snow_fixture_put()
			snow_fixture_outdoors.weather = weather_kind
			snow_fixture_outdoors.weather_intensity = 1
			snow_fixture_outdoors.icon_state = state
			D.snowfall_ground_check()
			if (D.weather_snow != 1)
				snow_ok = FALSE
	snow_fixture_assert("wet_extreme_snow_icons_accrue", snow_ok)
	var/no_snow_ok = TRUE
	var/list/non_snow_rows = list(list(WEATHER_NONE, 1, "snow1"), list(WEATHER_SMOG, 1, "snow2"), list(WEATHER_WET, 0, "snow1"), list(WEATHER_EXTREME, 0, "rad_snow_storm"), list(WEATHER_WET, 1, "rain"), list(WEATHER_WET, 1, "clear"), list(WEATHER_EXTREME, 1, "storm"))
	for (var/list/row in non_snow_rows)
		D = snow_fixture_put()
		snow_fixture_outdoors.weather = row[1]
		snow_fixture_outdoors.weather_intensity = row[2]
		snow_fixture_outdoors.icon_state = row[3]
		D.snowfall_ground_check()
		if (D.weather_snow || D.fixture_temperature_calls)
			no_snow_ok = FALSE
	snow_fixture_assert("clear_rain_zero_intensity_no_accrual", no_snow_ok)

/proc/snow_fixture_case_temperature_generation()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	var/empty_token = T.snowfall_ground_generation
	T.fixture_temperature_c = 0.5
	T.snowfall_ground_check()
	snow_fixture_assert("positive_temperature_no_stick", T.weather_snow == 0 && T.snowfall_ground_generation == empty_token)
	T.fixture_temperature_c = 0
	T.snowfall_ground_check()
	var/live_token = T.snowfall_ground_generation
	snow_fixture_assert("zero_temperature_creates_generation", T.weather_snow == 1 && live_token != empty_token)
	T.snowfall_ground_check()
	var/second_ok = T.weather_snow == 2 && T.snowfall_ground_generation == live_token
	T.snowfall_ground_check()
	snow_fixture_assert("accrual_caps_without_new_generation", second_ok && T.weather_snow == 2 && T.snowfall_ground_generation == live_token)
	T.fixture_temperature_c = 2
	T.snowfall_ground_check()
	snow_fixture_assert("two_c_preserves_existing_cover", T.weather_snow == 2 && T.snowfall_ground_generation == live_token)
	T.fixture_temperature_c = 2.5
	T.snowfall_ground_check()
	var/retired_token = T.snowfall_ground_generation
	snow_fixture_assert("above_two_c_retires_cover", T.weather_snow == 0 && retired_token != live_token && !T.weather_snow_overlay)
	snow_fixture_outdoors.weather = WEATHER_NONE
	T.fixture_temperature_c = 0
	var/temperature_before = snow_fixture_temperature_calls
	T.snowfall_ground_check()
	snow_fixture_assert("clear_cold_cannot_regenerate", T.weather_snow == 0 && T.snowfall_ground_generation == retired_token && snow_fixture_temperature_calls == temperature_before)
	snow_fixture_outdoors.weather = WEATHER_WET
	T.snowfall_ground_check(FALSE)
	var/no_add = T.weather_snow == 0
	T.snowfall_ground_check()
	T.fixture_temperature_c = 2.5
	T.snowfall_ground_check(FALSE)
	snow_fixture_assert("nonaccumulating_check_still_melts", no_add && T.weather_snow == 0 && !T.weather_snow_overlay)

/proc/snow_fixture_case_holds()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	var/check_holds = TRUE
	for (var/which = 1, which <= 3, which++)
		var/token = T.snowfall_ground_generation
		var/temperature_before = snow_fixture_temperature_calls
		var/topology_before = snow_fixture_topology_calls
		snow_fixture_hold(which)
		T.snowfall_ground_check()
		if (T.weather_snow || T.snowfall_ground_generation != token || snow_fixture_temperature_calls != temperature_before || snow_fixture_topology_calls != topology_before)
			check_holds = FALSE
		snow_fixture_hold(0)
	snow_fixture_assert("weather_persistence_holds_no_sampling", check_holds)
	T.snowfall_ground_check()
	T.available_snow = 9
	var/take_holds = TRUE
	for (var/which = 1, which <= 3, which++)
		var/token = T.snowfall_ground_generation
		var/image/owned = T.weather_snow_overlay
		var/temperature_before = snow_fixture_temperature_calls
		var/topology_before = snow_fixture_topology_calls
		snow_fixture_hold(which)
		var/taken = T.take_snow(token, TRUE)
		if (taken || T.weather_snow != 1 || T.available_snow != 9 || T.snowfall_ground_generation != token || T.weather_snow_overlay != owned || snow_fixture_temperature_calls != temperature_before || snow_fixture_topology_calls != topology_before)
			take_holds = FALSE
		snow_fixture_hold(0)
	snow_fixture_assert("take_persistence_holds_no_mutation", take_holds)

/proc/snow_fixture_case_exposure()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	var/turf/upper = locate(2, 2, 2)
	var/turf/top = locate(2, 2, 3)
	var/links_ok = snow_fixture_link(T, upper) && snow_fixture_link(upper, top)
	links_ok = links_ok && !snow_fixture_link(top, T) && !snow_fixture_link(T, top)
	snow_fixture_assert("topology_adapter_acyclic", links_ok)
	T.snowfall_ground_check()
	snow_fixture_assert("outdoor_multihop_sky_exposed", T.weather_snow == 1)
	var/area/caribbean/indoors = new
	indoors.location = AREA_INSIDE
	T = snow_fixture_put()
	indoors.contents += T
	T.snowfall_ground_check()
	var/areas_ok = T.weather_snow == 0
	var/area/snow_fixture_other/other = new
	other.contents += T
	T.snowfall_ground_check()
	snow_fixture_assert("indoor_noncaribbean_excluded", areas_ok && T.weather_snow == 0)
	snow_fixture_outdoors.contents += T
	var/obj/roof/R = new(T)
	T.snowfall_ground_check()
	var/source_blocked = T.weather_snow == 0
	del(R)
	var/obj/covers/C = new(T)
	T.snowfall_ground_check()
	source_blocked = source_blocked && T.weather_snow == 0
	del(C)
	snow_fixture_assert("source_roof_cover_no_accrual", source_blocked)
	T.snowfall_ground_check()
	R = new(T)
	T.snowfall_ground_check()
	var/cold_kept = T.weather_snow == 1
	snow_fixture_outdoors.weather = WEATHER_NONE
	T.fixture_temperature_c = 2.5
	T.snowfall_ground_check()
	snow_fixture_assert("cold_covered_persists_warm_covered_melts", cold_kept && T.weather_snow == 0)
	del(R)
	T.fixture_temperature_c = 0
	snow_fixture_outdoors.weather = WEATHER_WET
	upper = snow_fixture_put(/turf/floor/wood, 2, 2, 2)
	T.snowfall_ground_check()
	snow_fixture_assert("connected_constructed_floor_blocks", T.weather_snow == 0)
	var/open_ok = TRUE
	var/upper_blocked = TRUE
	for (var/kind in list(/turf/sky, /turf/floor/broken_floor, /turf/floor/space))
		T = snow_fixture_put()
		upper = snow_fixture_put(kind, 2, 2, 2)
		R = new(upper)
		T.snowfall_ground_check()
		if (T.weather_snow)
			upper_blocked = FALSE
		del(R)
		C = new(upper)
		T.snowfall_ground_check()
		if (T.weather_snow)
			upper_blocked = FALSE
		del(C)
		T.snowfall_ground_check()
		if (T.weather_snow != 1)
			open_ok = FALSE
	snow_fixture_assert("sky_broken_space_pass_exposure", open_ok)
	snow_fixture_assert("upper_roof_cover_blocks_open_types", upper_blocked)
	T = snow_fixture_put()
	R = new(top)
	T.snowfall_ground_check()
	var/connected_top_blocks = T.weather_snow == 0
	snow_fixture_links = list()
	T.snowfall_ground_check()
	snow_fixture_assert("connected_top_blocks_unconnected_top_irrelevant", connected_top_blocks && T.weather_snow == 1)
	del(R)

/proc/snow_fixture_case_appearance_lifecycle()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	T.plane = 7
	T.soil_nutrition = 37
	T.available_dirt = 13
	T.available_snow = 9
	var/base_type = T.type
	var/base_icon = T.icon
	var/base_state = T.icon_state
	var/obj/snow_fixture_sentinel/O = new(T)
	var/image/sentinel = snow_fixture_add_sentinel(T)
	T.snowfall_ground_check()
	var/image/owned = T.weather_snow_overlay
	T.snowfall_ground_icon()
	T.snowfall_ground_icon()
	snow_fixture_assert("positive_icon_reuses_owned_image_once", owned && T.weather_snow_overlay == owned && snow_fixture_appearance_count(T, 2.03, 7) == 1 && snow_fixture_appearance_count(T, 5, 7) == 1)
	T.overlays.Cut()
	T.overlays += sentinel
	T.snowfall_ground_icon()
	snow_fixture_assert("helper_rebuild_restores_owned_appearance", T.weather_snow_overlay == owned && snow_fixture_appearance_count(T, 2.03, 7) == 1 && snow_fixture_appearance_count(T, 5, 7) == 1)
	T.fixture_temperature_c = 2.5
	T.snowfall_ground_check()
	snow_fixture_assert("melt_clears_only_snow_appearance", !T.weather_snow_overlay && snow_fixture_appearance_count(T, 2.03, 7) == 0 && snow_fixture_appearance_count(T, 5, 7) == 1)
	T.fixture_temperature_c = 0
	T.snowfall_ground_check()
	var/token = T.snowfall_ground_generation
	var/taken = T.take_snow(token, TRUE)
	snow_fixture_assert("last_harvest_clears_only_snow_appearance", taken && !T.weather_snow_overlay && snow_fixture_appearance_count(T, 2.03, 7) == 0 && snow_fixture_appearance_count(T, 5, 7) == 1)
	snow_fixture_assert("cover_preserves_exact_substrate_contents", T.type == base_type && T.icon == base_icon && T.icon_state == base_state && T.soil_nutrition == 37 && T.available_dirt == 13 && T.available_snow == 9 && T.contents.len == 1 && O.loc == T && (O in T.contents))

/proc/snow_fixture_case_harvest()
	snow_fixture_reset()
	var/turf/T = snow_fixture_put()
	T.available_snow = 8
	T.snowfall_ground_check()
	T.snowfall_ground_check()
	var/token = T.snowfall_ground_generation
	var/first = T.take_snow(token, TRUE)
	snow_fixture_assert("first_take_preserves_live_generation", first && T.weather_snow == 1 && T.snowfall_ground_generation == token)
	var/second = T.take_snow(token, TRUE)
	snow_fixture_assert("last_take_retires_generation", second && T.weather_snow == 0 && T.snowfall_ground_generation != token)
	var/third = T.take_snow(token, TRUE)
	snow_fixture_assert("finite_generated_stock_no_legacy_fallback", !third && T.weather_snow == 0 && T.available_snow == 8)
	T.snowfall_ground_check()
	token = T.snowfall_ground_generation
	var/missing = T.take_snow()
	var/missing_source = T.take_snow(token)
	var/missing_token = T.take_snow(null, TRUE)
	var/wrong_source = T.take_snow(token, FALSE)
	snow_fixture_assert("missing_generation_source_reject_without_debit", !missing && !missing_source && !missing_token && !wrong_source && T.weather_snow == 1 && T.available_snow == 8 && T.snowfall_ground_generation == token)
	var/turf/authored = snow_fixture_put(/turf/floor/winter, 3, 2, 1)
	authored.available_snow = 3
	var/authored_token = authored.snowfall_ground_generation
	var/authored_taken = authored.take_snow(authored_token, FALSE)
	var/stolen = authored.take_snow(authored_token, TRUE)
	snow_fixture_assert("authored_predicate_and_stock_preserved", authored_taken && !stolen && authored.has_snow_cover() && authored.weather_snow == 0 && authored.available_snow == 2 && authored.snow_units() == 2 && authored.snow_units(TRUE) == 0)

/proc/snow_fixture_case_registry()
	snow_fixture_reset()
	var/turf/A = snow_fixture_put()
	var/turf/B = snow_fixture_put(/turf/floor/dirt, 3, 2, 1)
	var/turf/C = snow_fixture_put(/turf/floor/grass, 4, 2, 1)
	var/turf/D = snow_fixture_put(/turf/floor/grass, 5, 2, 1)
	var/token = A.snowfall_ground_generation
	A.snowfall_ground_register()
	snow_fixture_assert("duplicate_register_idempotent", snow_fixture_registry_exact(4) && A.snowfall_ground_generation == token)
	A.snowfall_ground_unregister()
	snow_fixture_assert("first_removal_index_repaired", A.snowfall_ground_index == 0 && D.snowfall_ground_index == 1 && snow_fixture_registry_exact(3))
	B.snowfall_ground_unregister()
	snow_fixture_assert("middle_removal_index_repaired", B.snowfall_ground_index == 0 && C.snowfall_ground_index == 2 && snow_fixture_registry_exact(2))
	C.snowfall_ground_unregister()
	var/last_ok = C.snowfall_ground_index == 0 && snow_fixture_registry_exact(1)
	C.snowfall_ground_unregister()
	D.snowfall_ground_unregister()
	D.snowfall_ground_unregister()
	snow_fixture_assert("last_repeated_unregister_idempotent", last_ok && D.snowfall_ground_index == 0 && snow_fixture_registry_exact(0))

/proc/snow_fixture_case_load_hooks()
	snow_fixture_reset()
	var/list/rows = list(list(-1, 0), list(0, 0), list(1, 1), list(2, 2), list(3, 2), list(1.5, 1), list("1", 0), list(null, 0))
	var/values_ok = TRUE
	var/icons_ok = TRUE
	var/no_sampling = TRUE
	for (var/list/row in rows)
		var/turf/floor/T = snow_fixture_put()
		// Seed an owned appearance first so zero normalization must remove it.
		T.weather_snow = 1
		T.snowfall_ground_icon()
		T.weather_snow = row[1]
		var/temperature_before = snow_fixture_temperature_calls
		var/topology_before = snow_fixture_topology_calls
		T.after_load()
		if (T.weather_snow != row[2])
			values_ok = FALSE
		var/expected_images = row[2] > 0 ? 1 : 0
		if (snow_fixture_appearance_count(T, 2.03, T.plane) != expected_images || (expected_images && !T.weather_snow_overlay) || (!expected_images && T.weather_snow_overlay))
			icons_ok = FALSE
		if (temperature_before != snow_fixture_temperature_calls || topology_before != snow_fixture_topology_calls)
			no_sampling = FALSE
	snow_fixture_assert("reload_values_native_round_clamp", values_ok)
	snow_fixture_assert("reload_values_rebuild_owned_icon", icons_ok)
	snow_fixture_assert("reload_values_do_not_sample_weather", no_sampling)
	var/turf/floor/excluded = snow_fixture_put(/turf/floor/wood, 3, 2, 1)
	excluded.weather_snow = 2
	excluded.snowfall_ground_icon()
	excluded.after_load()
	snow_fixture_assert("reload_ineligible_zeroes_cover", excluded.weather_snow == 0 && !excluded.weather_snow_overlay && excluded.snowfall_ground_index == 0)
	var/turf/floor/D = snow_fixture_put()
	var/list/zero_vars = D.get_saved_vars()
	D.weather_snow = 1
	var/list/positive_vars = D.get_saved_vars()
	var/count = 0
	for (var/key in positive_vars)
		if (key == "weather_snow")
			count++
	snow_fixture_assert("save_hook_units_only_when_positive_once", !("weather_snow" in zero_vars) && count == 1 && ("fixture_saved_sentinel" in zero_vars) && ("fixture_saved_sentinel" in positive_vars) && D.fixture_saved_sentinel == "durable fixture value")
	snow_fixture_assert("runtime_hook_excludes_three_snow_fields", D.persistence_runtime_var("weather_snow_overlay") && D.persistence_runtime_var("snowfall_ground_index") && D.persistence_runtime_var("snowfall_ground_generation") && !D.persistence_runtime_var("weather_snow"))
	var/unrelated_ok = D.persistence_runtime_var("fixture_parent_runtime") && !D.persistence_runtime_var("fixture_saved_sentinel")
	for (var/key in list("pickaxe_mining_owner", "mining_in_progress", "lighting_reserved", "affecting_lights", "lighting_overlay", "corners", "has_opaque_atom", "window_coeff_dirty", "next_calculate_window_coeff"))
		if (!D.persistence_runtime_var(key))
			unrelated_ok = FALSE
	snow_fixture_assert("runtime_hook_preserves_other_exclusions", unrelated_ok)

/proc/snow_fixture_case_process()
	snow_fixture_reset()
	for (var/i = 1, i <= 300, i++)
		var/px = ((i - 1) % 18) + 1
		var/py = round((i - 1) / 18) + 1
		snow_fixture_put(/turf/floor/dirt, px, py, 1)
	var/process/snowfall_ground/P = new
	P.setup()
	snow_fixture_assert("process_setup_registers_instance", processes.snowfall_ground == P)
	snow_fixture_assert("process_setup_metadata", P.name == "snowfall ground cover" && P.schedule_interval == 20 && P.start_delay == 100 && P.priority == PROCESS_PRIORITY_LOW && P.fires_at_gamestates.len == 1 && P.fires_at_gamestates[1] == GAME_STATE_PLAYING && snow_fixture_registry_exact(300))
	var/list/original_registry = snowfall_ground
	P.reset_current_list()
	snow_fixture_assert("process_does_not_copy_registry", snowfall_ground == original_registry)
	var/holds_ok = TRUE
	for (var/which = 1, which <= 3, which++)
		snowfall_ground_next = 0
		var/cursor_before = snowfall_ground_cursor
		var/temperature_before = snow_fixture_temperature_calls
		snow_fixture_hold(which)
		P.fire()
		if (snowfall_ground_next != 0 || snowfall_ground_cursor != cursor_before || snow_fixture_temperature_calls != temperature_before)
			holds_ok = FALSE
		snow_fixture_hold(0)
	snow_fixture_assert("process_persistence_holds_no_progress", holds_ok)
	// A new tick is a fixture adapter, not production scheduler acceptance.
	// If the real tick-usage guard cuts early, exact boundary remains unproven and
	// this assertion FAILS; a low count must never be accepted as 256 coverage.
	sleep(1)
	var/temperature_before = snow_fixture_temperature_calls
	P.fire()
	var/visits = snow_fixture_temperature_calls - temperature_before
	snow_fixture_assert("process_batch_exact_256", visits == 256 && snowfall_ground_cursor == 257)
	var/deadline_before = snowfall_ground_next
	var/cursor_before = snowfall_ground_cursor
	temperature_before = snow_fixture_temperature_calls
	P.fire()
	snow_fixture_assert("process_duplicate_fire_before_deadline_no_work", snow_fixture_temperature_calls == temperature_before && snowfall_ground_next == deadline_before && snowfall_ground_cursor == cursor_before)
	var/units = 0
	var/units_ok = TRUE
	for (var/turf/T in snowfall_ground)
		units += T.weather_snow
		if (T.weather_snow < 0 || T.weather_snow > 1)
			units_ok = FALSE
	snow_fixture_assert("process_visits_match_distinct_units", units_ok && units == visits && visits <= 256 && snow_fixture_registry_exact(300))
	// Explicit deadline reset services the wrap path without claiming timing.
	snowfall_ground_next = 0
	sleep(1)
	temperature_before = snow_fixture_temperature_calls
	P.fire()
	var/second_visits = snow_fixture_temperature_calls - temperature_before
	var/all_visited = TRUE
	for (var/turf/T in snowfall_ground)
		if (T.weather_snow < 1 || T.weather_snow > 2)
			all_visited = FALSE
	snow_fixture_assert("process_second_batch_wraps_registry", visits == 256 && second_visits == 256 && snowfall_ground_cursor == 213 && all_visited)

/proc/snow_fixture_elapsed(started)
	var/elapsed = world.timeofday - started
	if (elapsed < 0)
		elapsed += 864000
	return elapsed

/proc/snow_fixture_admit()
	if (world.byond_version != 516 || world.byond_build != 1688 || SNOW_NATIVE_VERSION != "516.1688")
		world.log << "SNOW_FATAL runtime_version"
		return FALSE
	if (!(SNOW_NATIVE_MODE in list("baseline", "overlay-omission", "melt-omission", "generation-omission", "reload-generation-omission", "reload-sampling", "del-unregister-omission")))
		world.log << "SNOW_FATAL mode"
		return FALSE
	if (world.OpenPort(19327) || world.port != 0)
		world.log << "SNOW_FATAL listener_not_closed"
		return FALSE
	if (fexists("snow-native-ready.json") || fexists("snow-native-go.json") || fexists("snow-native-result.json"))
		world.log << "SNOW_FATAL preexisting_receipt"
		return FALSE
	var/list/ready = list("head" = SNOW_NATIVE_HEAD, "tree" = SNOW_NATIVE_TREE, "version" = SNOW_NATIVE_VERSION, "mode" = SNOW_NATIVE_MODE, "port" = 0)
	if (!text2file(json_encode(ready), "snow-native-ready.json"))
		world.log << "SNOW_FATAL readiness_write"
		return FALSE
	var/started = world.timeofday
	while (!fexists("snow-native-go.json") && snow_fixture_elapsed(started) < 100)
		sleep(1)
	if (!fexists("snow-native-go.json") || snow_fixture_elapsed(started) >= 100 || world.port != 0)
		world.log << "SNOW_FATAL closure_ack_timeout"
		return FALSE
	var/ack_text = file2text("snow-native-go.json")
	if (!istext(ack_text) || length(ack_text) > 2048)
		world.log << "SNOW_FATAL closure_ack_size"
		return FALSE
	var/list/ack = json_decode(ack_text)
	if (!islist(ack) || ack.len != 6 || ack["head"] != SNOW_NATIVE_HEAD || ack["tree"] != SNOW_NATIVE_TREE || ack["version"] != SNOW_NATIVE_VERSION || ack["mode"] != SNOW_NATIVE_MODE || !isnum(ack["port"]) || ack["port"] != 0 || ack["ack"] != "owned-listener-census-v1")
		world.log << "SNOW_FATAL closure_ack_binding"
		return FALSE
	return TRUE

/world/New()
	OpenPort("none")
	if (world.port != 0 || !snow_fixture_admit())
		del(world)
		return
	if (SNOW_NATIVE_MODE == "baseline")
		snow_fixture_case_appearance()
		snow_fixture_case_warm_debit()
		snow_fixture_case_stale_reaccumulation()
		snow_fixture_case_reload_generation()
		snow_fixture_case_reload_sampling()
		snow_fixture_case_replacement()
		snow_fixture_case_eligibility_weather()
		snow_fixture_case_temperature_generation()
		snow_fixture_case_holds()
		snow_fixture_case_exposure()
		snow_fixture_case_appearance_lifecycle()
		snow_fixture_case_harvest()
		snow_fixture_case_registry()
		snow_fixture_case_load_hooks()
		snow_fixture_case_process()
	else if (SNOW_NATIVE_MODE == "overlay-omission")
		snow_fixture_case_appearance()
	else if (SNOW_NATIVE_MODE == "melt-omission")
		snow_fixture_case_warm_debit()
	else if (SNOW_NATIVE_MODE == "generation-omission")
		snow_fixture_case_stale_reaccumulation()
	else if (SNOW_NATIVE_MODE == "reload-generation-omission")
		snow_fixture_case_reload_generation()
	else if (SNOW_NATIVE_MODE == "reload-sampling")
		snow_fixture_case_reload_sampling()
	else if (SNOW_NATIVE_MODE == "del-unregister-omission")
		snow_fixture_case_replacement()
	if (world.port != 0)
		world.log << "SNOW_FATAL listener_reopened"
		del(world)
		return
	var/list/result = list("head" = SNOW_NATIVE_HEAD, "tree" = SNOW_NATIVE_TREE, "version" = SNOW_NATIVE_VERSION, "mode" = SNOW_NATIVE_MODE, "checks" = snow_fixture_assertions.len, "failed" = snow_fixture_failed, "assertions" = snow_fixture_assertions)
	if (!text2file(json_encode(result), "snow-native-result.json"))
		world.log << "SNOW_FATAL result_write"
		del(world)
		return
	world.log << "SNOW_RESULT [SNOW_NATIVE_MODE]"
	del(world)
	return
