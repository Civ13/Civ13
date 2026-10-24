// Prepared only in this change. Native execution requires separate authorization.
#define TRUE 1
#define FALSE 0
#include "trim.dm"
/datum
	var/gc_destroyed
	var/gcDestroyed = 0
#include "movable_defaults.dm"
/datum/persistence_world_operation
	var/kind = "save"
	var/map_storage/storage
	var/backend_started = TRUE
	var/contents_started = TRUE
	var/mutation_started = FALSE
	var/restoring_players = FALSE
/datum/save_export_frame
	var/datum/source
	var/current_field
	var/entry = 1
/map_storage
	var/list/saving_export_stack = list()
	var/list/last_save_reference_failure
/datum/nomads_lifecycle_control
	proc/read_token()
		return "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	proc/read_revision()
		return "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	proc/boot_session()
		return "cccccccccccccccccccccccccccccccc"
/proc/nomads_lifecycle_hex(value, size)
	return istext(value) && length(value) == size
var/global/datum/nomads_lifecycle_control/nomads_lifecycle = new
var/global/map_storage/map_storage = new
var/global/datum/persistence_world_operation/persistence_active_operation
var/global/list/thrown_list = list()
var/global/list/processing_objects = list()
var/global/game_id = "probe-round"
#include "variable_observability.dm"

var/global/probe_failures = 0
/proc/check(condition, label)
	if(!condition)
		probe_failures++
		world.log << "FAIL: [label]"
/world
	maxx = 2
	maxy = 2
	maxz = 2
	visibility = 0
	hub = ""
/client/New()
	del(src)
/world/OpenPort(value)
	if(value == "none") return ..()
	return FALSE
/world/New()
	OpenPort("none")
	check(port == 0, "closed native port")
	if(port != 0)
		del(world)
		return
	text2file("closed", "probe-port-closed.txt")
	var/closure_deadline = world.time + 50
	while(!fexists("probe-port-closed.ack") && world.time < closure_deadline)
		sleep(1)
	check(trim(file2text("probe-port-closed.ack")) == "closed", "external socket closure acknowledged")
	if(trim(file2text("probe-port-closed.ack")) != "closed")
		del(world)
		return
	check(!variable_observability_enabled(), "default off")
	text2file("enabled", "config/variable-observability.txt")
	text2file(nomads_lifecycle.read_token(), "config/lifecycle-token.txt")
	text2file(nomads_lifecycle.read_revision(), "config/lifecycle-revision.txt")
	check(variable_observability_enabled(), "explicit local opt-in")
	var/publication_mode = trim(file2text("config/variable-probe-mode.txt"))
	if(publication_mode == "missing" || publication_mode == "unwritable" || publication_mode == "obstructed")
		if(publication_mode == "obstructed")
			check(file2text("data/desktop-supervisor/variable-observability/last-failure.json/retained-control.txt") == "retained obstruction", "nonempty output obstruction prepared")
			var/write_refused = FALSE
			try
				write_refused = !text2file("must not replace a directory", "data/desktop-supervisor/variable-observability/last-failure.json")
			catch
				write_refused = TRUE
			check(write_refused, "real file-versus-directory write refusal")
			check(file2text("data/desktop-supervisor/variable-observability/last-failure.json/retained-control.txt") == "retained obstruction", "direct write refusal preserves obstruction marker")
		var/list/unpublished = list("probe_publication" = publication_mode)
		check(!map_storage.variable_observability_publish(unpublished), "unavailable private output refused")
		check(map_storage.last_variable_failure == unpublished, "unavailable output retains in-memory evidence")
		if(publication_mode == "obstructed")
			check("last-failure.json/" in flist("data/desktop-supervisor/variable-observability/last-failure.json"), "output obstruction remains a directory")
			check(file2text("data/desktop-supervisor/variable-observability/last-failure.json/retained-control.txt") == "retained obstruction", "collector refusal preserves obstruction marker")
		else
			check(!fexists("data/desktop-supervisor/variable-observability/last-failure.json"), "unavailable output produced no file")
		check(!fexists("data/variable-observability-last-failure.json"), "no legacy public-path fallback")
		world.log << "VARIABLE_OBSERVABILITY publication=[publication_mode] failures=[probe_failures] native_collector_only=1"
		del(world)
		return
	check(publication_mode == "writable", "known publication mode")
	var/atom/movable/source = new(locate(1,1,1))
	var/atom/movable/target = new(locate(1,1,2))
	source.original_target = target
	var/list/inactive = variable_observability_object(source)
	var/list/throw_state = inactive["throw"]
	var/list/membership = inactive["thrown_list"]
	check(!throw_state["throwing"] && membership["membership"] == "absent", "inactive throw")
	source.throwing = TRUE
	thrown_list += source
	var/list/active = variable_observability_object(source)
	throw_state = active["throw"]
	membership = active["thrown_list"]
	check(throw_state["throwing"] && membership["membership"] == "present", "active throw")
	var/list/target_identity = throw_state["original_target"]
	var/list/target_turf = target_identity["turf"]
	check(target_turf["z"] == 2, "target physical z")
	persistence_active_operation = new
	persistence_active_operation.storage = map_storage
	persistence_active_operation.observability_id = "operation-1"
	persistence_active_operation.observability_started = world.time
	persistence_active_operation.observability_collecting = TRUE
	variable_observability_skipped(target)
	variable_observability_skipped("not retained")
	variable_observability_skipped(null, TRUE)
	check(persistence_active_operation.observability_fields_skipped == 2 && persistence_active_operation.observability_references_skipped == 1 && persistence_active_operation.observability_legacy_fields_skipped == 1, "existing policy skip decisions counted")
	var/datum/save_export_frame/frame = new
	frame.source = source
	frame.current_field = "original_target"
	map_storage.saving_export_stack += frame
	map_storage.last_save_reference_failure = list("kind" = "cross_level_object", "saved_z" = 1, "current_entry" = 0, "first_z" = 0, "first_entry" = 0)
	map_storage.variable_observability_capture(target)
	var/list/captured_source = map_storage.last_variable_failure["source"]
	check(captured_source["field"] == "original_target", "exact field captured")
	check(fexists("data/desktop-supervisor/variable-observability/last-failure.json"), "automatic private failure file")
	check(!fexists("data/variable-observability-last-failure.json"), "no legacy public-path output")
	check(fcopy("data/desktop-supervisor/variable-observability/last-failure.json", "data/desktop-supervisor/variable-observability/native-reference.json"), "reference capture retained for actual reader")
	map_storage.last_variable_failure = null
	map_storage.variable_observability_finish(persistence_active_operation, FALSE)
	check(map_storage.last_variable_failure["kind"] == "operation_failed", "failed operation snapshot")
	check(fcopy("data/desktop-supervisor/variable-observability/last-failure.json", "data/desktop-supervisor/variable-observability/native-operation-failure.json"), "operation capture retained for actual reader")
	var/atom/movable/container = source
	for(var/i = 1 to 9)
		container = new /atom/movable(container)
	var/list/deep = variable_observability_identity(container)
	check(deep["location_state"] == "depth_limit", "bounded containment depth")
	var/list/prefix = list()
	for(var/i = 1 to 256) prefix += i
	prefix += source
	membership = variable_observability_membership(prefix, source)
	check(membership["membership"] == "unknown" && membership["scanned"] == 256, "bounded registry unknown")
	var/snapshot = json_encode(active)
	del(target)
	check(json_encode(active) == snapshot, "deleted target cannot change capture")
	check(!source.original_target, "native clears deleted target")
	var/list/deleted_identity = variable_observability_identity(source.original_target)
	check(!deleted_identity["present"], "deleted reference not resolved")
	map_storage.variable_observability_publish(list("huge" = repeat_string(40000)))
	check(length(file2text("data/desktop-supervisor/variable-observability/last-failure.json")) <= 32768 + 2, "bounded disk output")
	world.log << "VARIABLE_OBSERVABILITY failures=[probe_failures] native_collector_only=1"
	del(world)
	return
/proc/repeat_string(count)
	var/value = ""
	for(var/i = 1 to count) value += "x"
	return value
