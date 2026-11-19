// Native probe for the packed multi-depth mining floor registry
// (code/modules/multiz/mine_floor_registry.dm). Full production sources with ordinary
// startup disabled; run with
// python3 tests/ecology_spawning/run_linux.py . tests/mine_floor_registry/probe.dm
// The fixtures are compiled into the probe's resource file.
/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 4
	maxz = 1
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

var/mine_registry_failures = 0
var/mine_registry_runtime_error = FALSE
/proc/mine_registry_check(condition, label)
	if (!condition)
		mine_registry_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mine_registry_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		mine_registry_probe_run()
	catch(var/exception/e)
		mine_registry_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mine_registry_failures, "runtime_error" = mine_registry_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

#define PROBE_LINEAGE "gaia-probe_1"
/proc/mine_registry_probe_load(text, list/reserved = null)
	return mine_registry_from_json(text, PROBE_LINEAGE, 100, 100, 4, reserved)

/proc/mine_registry_probe_run()
	var/valid_text = file2text('fixtures/valid.json')
	var/negative_text = file2text('fixtures/negative.json')
	mine_registry_check(istext(valid_text) && istext(negative_text), "fixtures are compiled in")

	// Accepted and canonical.
	var/datum/mine_registry/R = mine_registry_probe_load(valid_text)
	mine_registry_check(istype(R), "valid fixture accepted ([istext(R) ? R : "ok"])")
	if (!istype(R))
		return
	mine_registry_check(R.lineage == PROBE_LINEAGE && R.generation == 7 && R.next_mine_id == 4, "header fields")
	var/list/mine_ids = list()
	for (var/datum/mine_registry_mine/M in R.mines)
		mine_ids += M.id
	mine_registry_check(mine_ids ~= list(1, 2, 3), "mines in canonical order")
	var/list/floor_keys = list()
	for (var/datum/mine_registry_floor/F in R.floors)
		floor_keys += "[F.mine_id]/[F.depth]@[F.z]:[F.x1],[F.y1]-[F.x2],[F.y2]#[F.placement_generation]"
	mine_registry_check(floor_keys ~= list("1/1@3:1,1-36,36#1", "1/2@4:65,65-100,100#1", "3/1@3:37,1-58,12#3"), "floors in canonical order with their fixed placements")

	// Round trip: stable text, stable identity and placement.
	var/first = R.to_json()
	var/datum/mine_registry/R2 = mine_registry_probe_load(first)
	mine_registry_check(istype(R2), "canonical text decodes")
	if (istype(R2))
		mine_registry_check(R2.to_json() == first, "second round trip is byte-identical")
	mine_registry_check(findtext(first, "\"schema\":[MINE_REGISTRY_SCHEMA_VERSION],\"lineage\":\"[PROBE_LINEAGE]\"") == 2, "header leads the encoding")
	mine_registry_check(!findtext(first, "index"), "runtime indexes are not encoded")

	// Identity rules.
	mine_registry_check(R.floor_state(1, 1) == MINE_FLOOR_PRESENT, "committed floor is present")
	mine_registry_check(R.floor_state(1, 3) == MINE_FLOOR_NEW, "next depth of an issued mine is new")
	mine_registry_check(R.floor_state(1, 4) == MINE_FLOOR_UNKNOWN, "skipping a depth is refused")
	mine_registry_check(R.floor_state(2, 1) == MINE_FLOOR_NEW, "issued mine with no floors may start at depth 1")
	mine_registry_check(R.floor_state(3, 5) == MINE_FLOOR_UNKNOWN, "depth beyond the limit is refused")
	mine_registry_check(R.floor_state(4, 1) == MINE_FLOOR_UNKNOWN, "unissued mine is refused")
	mine_registry_check(R.floor_state(1, 1.5) == MINE_FLOOR_UNKNOWN && R.floor_state("1", 1) == MINE_FLOOR_UNKNOWN, "malformed identities are refused")
	R2.floor_index -= "1/2"
	mine_registry_check(R2.floor_state(1, 2) == MINE_FLOOR_CORRUPT, "a committed depth without its record is corruption, not a request to generate")

	var/issued = R.issue_mine_id()
	mine_registry_check(issued == 4 && R.next_mine_id == 5, "issued id comes from the counter")
	var/datum/mine_registry/R3 = mine_registry_probe_load(R.to_json())
	mine_registry_check(istype(R3) && R3.next_mine_id == 5 && R3.floor_state(4, 1) == MINE_FLOOR_NEW, "issued id survives a round trip")
	if (istype(R3))
		mine_registry_check(R3.issue_mine_id() == 5, "ids are never reissued")
	R.limits["mines"] = length(R.mines)
	mine_registry_check(isnull(R.issue_mine_id()) && R.next_mine_id == 5, "full mine limit issues nothing")

	// Reserved regions and caller bounds.
	var/refused = mine_registry_probe_load(valid_text, list(list(3, 50, 10, 60, 20)))
	mine_registry_check(refused == "placement 3/1 overlaps a reserved region", "reserved region refused ([refused])")
	mine_registry_check(istype(mine_registry_probe_load(valid_text, list(list(3, 59, 1, 60, 20), list(4, 1, 1, 64, 64))), /datum/mine_registry), "touching but disjoint reserved regions accepted")
	refused = mine_registry_probe_load(valid_text, list(list(3, 50, 10, 40, 20)))
	mine_registry_check(refused == "reserved region is malformed", "inverted reserved region refused ([refused])")
	refused = mine_registry_from_json(valid_text, PROBE_LINEAGE, 99, 100, 4, null)
	mine_registry_check(refused == "placement 1/2 is outside the planes", "smaller world refuses the placement ([refused])")
	refused = mine_registry_from_json(valid_text, "gaia other", 100, 100, 4, null)
	mine_registry_check(refused == "expected lineage is malformed", "malformed expected lineage refused ([refused])")

	// Text-level refusals.
	refused = mine_registry_probe_load("{\"schema\":1,")
	mine_registry_check(refused == "registry text is not JSON", "broken JSON refused ([refused])")
	var/long = valid_text
	while (length(long) <= MINE_REGISTRY_MAX_TEXT)
		long += long
	refused = mine_registry_probe_load(long)
	mine_registry_check(refused == "registry text is too long", "oversized text refused before decoding ([refused])")
	refused = mine_registry_probe_load(null)
	mine_registry_check(refused == "registry text is missing", "missing text refused")

	// Fixture negative controls, each with its exact reason.
	var/list/cases = json_decode(negative_text)
	mine_registry_check(length(cases) >= 30, "negative fixtures loaded ([length(cases)])")
	for (var/list/C in cases)
		var/result = mine_registry_probe_load(json_encode(C["registry"]))
		mine_registry_check(result == C["expect"], "[C["name"]]: [istext(result) ? result : "accepted"]")
#undef PROBE_LINEAGE
