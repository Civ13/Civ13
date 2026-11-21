// Native probe for lifetime accolades (code/modules/accolades/accolades.dm)
// on the shared player records store, local mode (no shard group).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/accolades/probe.dm 300
// It has no client, so the window's ownership guard and the per-minute count
// (which needs a played character) are covered by tests/accolades/test_accolades.py.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/accolade_probe/New()
	return
var/accolade_probe_durable = TRUE
/obj/map_metadata/accolade_probe/uses_durable_metadata()
	return accolade_probe_durable
var/acc_failures = 0
var/acc_runtime_error = FALSE
/proc/acc_check(condition, label)
	if (!condition)
		acc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	acc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/accolade_probe
		Master.start_timer_loop()
		acc_checks()
	catch(var/exception/e)
		acc_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = acc_failures, "runtime_error" = acc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/acc_checks()
	if (fexists("data/player_records.json"))
		fdel("data/player_records.json")
	shared_records.journal = null
	acc_check(accolades_earned_here(), "a durable world outside a group earns")
	acc_check(accolade_points("alice") == 0, "a new account has no points")

	// Meeting and claiming.
	acc_check(accolade_claim("alice", "sailor") == "You have not earned Sailor yet.", "an unmet accolade cannot be claimed")
	acc_check(accolade_meet("alice", "sailor"), "meeting an accolade records it")
	acc_check(!accolade_meet("alice", "sailor"), "an accolade is met only once")
	var/list/state = accolade_state("alice")
	acc_check(accolade_status(state, "sailor") == "ready", "a met accolade is ready to claim")
	acc_check(accolade_points("alice") == 0, "meeting pays nothing until claimed")
	var/list/claim = accolade_claim("alice", "sailor")
	acc_check(islist(claim) && claim["kind"] == "accolade", "a ready accolade can be claimed")
	acc_check(accolade_points("alice") == 10, "a claim pays its points")
	acc_check(istext(accolade_claim("alice", "sailor")), "an accolade is claimed once")
	acc_check(!accolade_meet("alice", "sailor"), "a claimed accolade is never met again")
	acc_check(accolade_points("alice") == 10, "a second claim pays nothing")
	acc_check(claim["id"] == accolade_record_id("accolade", "alice", "sailor"), "a claim has the same id on every region")
	acc_check(!accolade_meet("alice", "no_such_thing"), "unknown accolades are refused")

	// A copy of the same claim from another region stores once and pays once.
	shared_records.add("alice", "accolade", list("accolade" = "sailor", "points" = 10), id = accolade_record_id("accolade", "alice", "sailor"))
	accolade_forget("alice")
	acc_check(accolade_points("alice") == 10, "the same claim from two regions pays once")

	// Staff remove a claim: it cannot come back by claiming again.
	accolade_forget("alice")
	state = accolade_state("alice")
	var/list/claimed = state["claimed"]
	acc_check(shared_records.revoke(claimed["sailor"], "staffer", "Admin", "test"), "staff can remove a claim")
	accolade_forget("alice")
	state = accolade_state("alice")
	acc_check(accolade_status(state, "sailor") == "removed", "a removed claim shows as removed")
	acc_check(accolade_points("alice") == 0, "a removed claim pays nothing")
	acc_check(istext(accolade_claim("alice", "sailor")), "a removed claim cannot be claimed again")

	// A staff grant pays even unmet, and only once alongside a claim.
	shared_records.add("bob", "accolade", list("accolade" = "pioneer", "points" = 30, "grant" = 1), "staffer", "Admin")
	accolade_forget("bob")
	acc_check(accolade_points("bob") == 30, "a staff grant pays")
	acc_check(!accolade_meet("bob", "pioneer"), "a granted accolade is not met again")

	// Lands: Wanderer after three.
	accolade_note_land("carol", "gaia")
	accolade_note_land("carol", "gaia")
	accolade_note_land("carol", "europe")
	state = accolade_state("carol")
	acc_check(length(state["lands"]) == 2, "each land is recorded once")
	acc_check(accolade_status(state, "wanderer") == "open", "two lands are not enough for Wanderer")
	accolade_note_land("carol", "asia")
	accolade_forget("carol")
	acc_check(accolade_status(accolade_state("carol"), "wanderer") == "ready", "three lands meet Wanderer")
	acc_check(accolade_status(accolade_state("carol"), "world_traveller") == "open", "World Traveller needs a group's lands")

	// Guests and agents never earn.
	acc_check(isnull(accolade_account_ckey("guest12345")), "guest accounts never earn")
	acc_check(isnull(accolade_account_ckey("agent@ada")), "agent accounts never earn")
	acc_check(accolade_account_ckey("dave") == "dave", "a ckey earns as itself")

	// Lands that do not keep characters earn nothing, except First Steps.
	accolade_probe_durable = FALSE
	acc_check(!accolades_earned_here(), "a world that keeps no characters does not earn")
	acc_check(!accolade_meet("erin", "sailor"), "nothing is met where accolades are not earned")
	acc_check(accolade_meet("erin", "first_steps"), "First Steps is met in the tutorial too")
	accolade_probe_durable = TRUE
	shard_group.enabled = TRUE
	shard_group.kind = "BATTLE"
	acc_check(!accolades_earned_here(), "the battle world does not earn")
	shard_group.kind = "SURFACE"
	acc_check(accolades_earned_here(), "a surface land earns")
	shard_group.enabled = FALSE

	// Character progress: clean, full year, travel round trip.
	var/list/progress = accolade_progress_clean(list("minutes" = 12.7, "seasons" = list(SEASON_SPRING, "Monsoon", SEASON_SUMMER), "faction" = "Rome", "faction_minutes" = -4, "junk" = 1))
	acc_check(progress["minutes"] == 13 && length(progress["seasons"]) == 2 && progress["faction_minutes"] == 0 && !("junk" in progress), "progress is cleaned")
	acc_check(!accolade_full_year(list(SEASON_SPRING, SEASON_SUMMER, SEASON_FALL)), "three seasons are not a year")
	acc_check(accolade_full_year(list(SEASON_SPRING, SEASON_SUMMER, SEASON_FALL, SEASON_WINTER)), "four temperate seasons are a year")
	acc_check(accolade_full_year(list(SEASON_WET, SEASON_DRY)), "wet and dry seasons are a year")
	var/mob/living/human/H = new /mob/living/human(locate(5, 5, 1))
	H.known_recipe_nodes = list()
	H.persistence_owner_ckey = "frank"
	H.accolade_progress = list("minutes" = 30, "seasons" = list(SEASON_WINTER))
	var/payload_text = H.region_travel_payload(list())
	var/list/P = region_travel_decode(payload_text)
	var/list/carried = islist(P) ? P["accolades"] : null
	acc_check(islist(carried) && carried["minutes"] == 30, "progress travels with the character")

	// The window's sections build for an account with ready and claimed accolades.
	var/datum/accolade_window/W = new
	acc_check(istype(W), "the window datum builds")
	acc_check(length(accolade_catalog()) == 12, "twelve accolades in the first list")
