// Primitive experiment only: two cooperating BYOND worlds, synthetic files.
// These fixture adapters do not implement host exclusion or immutable readers.
#define RC_TRUE 1
#define RC_FALSE 0
#define RC_EXCEPTION(message) new /exception(message)

world
	name = "Civ13 offline reader contract"
	maxx = 1
	maxy = 1
	maxz = 1
	visibility = 0
	sleep_offline = RC_FALSE
	fps = 20

var/list/rc_handles = list()
var/list/rc_observations = list()
var/rc_role

/world/OpenPort(port)
	return ..("none")

/proc/rc_check(condition, message)
	if(!condition)
		throw RC_EXCEPTION(message)

/proc/rc_wait(signal)
	var/deadline = world.time + 200
	while(!fexists(signal))
		rc_check(world.time < deadline, "handshake timeout [signal]")
		sleep(1)

/proc/rc_signal(signal)
	rc_check(!fexists(signal), "duplicate handshake signal [signal]")
	rc_check(text2file("ready", signal), "failed handshake signal [signal]")

/proc/rc_copy_metadata(value)
	rc_check(istext(value) && length(value) <= 1024, "fixture metadata text/type limit")
	return value

/datum/rc_native_handle
	var/savefile/native_reader
	var/closed = RC_FALSE
	var/close_calls = 0
	New(path)
		..()
		rc_check(rc_handles.len < 32, "fixture handle allocation limit")
		rc_handles += src
		native_reader = new /savefile(path, 0.1)
	proc/opened()
		return !closed && native_reader && native_reader.name
	proc/close_once()
		if(closed)
			return RC_TRUE
		closed = RC_TRUE
		close_calls++
		native_reader = null
		return RC_TRUE
	proc/read_value()
		rc_check(opened(), "read after closed or rejected open")
		var/value
		native_reader["/value"] >> value
		return value
	proc/write_value(value)
		rc_check(opened(), "write after closed or rejected open")
		native_reader["/value"] << value
		native_reader.Flush()

/datum/rc_operation
	var/active = RC_TRUE

/datum/rc_member
	var/label
	var/kind
	var/datum/rc_operation/operation
	var/datum/rc_native_handle/handle
	var/copied_text
	var/closed = RC_FALSE
	proc/close_once()
		if(closed)
			return RC_TRUE
		closed = RC_TRUE
		if(handle)
			handle.close_once()
		copied_text = null
		return RC_TRUE

/datum/rc_selection
	var/datum/rc_operation/operation
	var/list/members = list()
	var/closed = RC_FALSE
	proc/require_member(datum/rc_operation/request, datum/rc_member/member, expected_kind)
		rc_check(!closed && operation && operation.active, "selection closed or operation inactive")
		rc_check(request == operation && member && member.operation == operation, "reader operation binding")
		rc_check((member in members) && !member.closed && member.kind == expected_kind, "reader member binding")
		return RC_TRUE
	proc/read_level(datum/rc_operation/request, datum/rc_member/member)
		require_member(request, member, "level")
		return member.handle.read_value()
	proc/read_metadata(datum/rc_operation/request, datum/rc_member/member)
		require_member(request, member, "metadata")
		return member.copied_text
	proc/close_once()
		if(closed)
			return RC_TRUE
		closed = RC_TRUE
		for(var/datum/rc_member/member in members)
			member.close_once()
		return RC_TRUE
	proc/acquire_selected(list/manifest, datum/rc_operation/request, inject_after_first = RC_FALSE)
		// Fixed synthetic members only; caller paths are never opened.
		rc_check(!operation && !closed && request && request.active, "selection acquisition state")
		rc_check(islist(manifest) && manifest.len == 2, "exact fixture manifest membership")
		var/list/seen = list()
		for(var/label in manifest)
			rc_check(istext(label) && (label in list("level1", "metadata")) && !(label in seen), "duplicate or unknown fixture member")
			seen += label
		rc_check(("level1" in seen) && ("metadata" in seen), "missing fixture member")
		operation = request
		try
			for(var/label in manifest)
				var/datum/rc_member/member = new
				member.label = label
				member.operation = operation
				members += member
				if(label == "level1")
					member.kind = "level"
					member.handle = new /datum/rc_native_handle("adapter_level.sav")
					rc_check(member.handle.opened(), "adapter member unavailable")
				else
					member.kind = "metadata"
					var/copied = file2text("adapter_metadata.txt")
					member.copied_text = rc_copy_metadata(copied)
				if(inject_after_first && members.len == 1)
					throw RC_EXCEPTION("injected partial acquisition")
		catch(var/exception/e)
			close_once()
			throw e
		return RC_TRUE

/proc/rc_check_adapter()
	var/type_rejected = RC_FALSE
	try
		rc_copy_metadata(42)
	catch(var/exception/e)
		type_rejected = RC_TRUE
	rc_check(type_rejected, "nontext metadata rejected")
	var/oversized = ""
	for(var/i = 1, i <= 1025, i++)
		oversized += "x"
	var/size_rejected = RC_FALSE
	try
		rc_copy_metadata(oversized)
	catch(var/exception/e)
		size_rejected = RC_TRUE
	rc_check(size_rejected, "oversized synthetic metadata rejected")
	rc_observations["utf8_length_e_acute"] = length("é")
	var/datum/rc_native_handle/seed = new("adapter_level.sav")
	rc_check(seed.opened(), "adapter seed open")
	seed.write_value("adapter A")
	seed.close_once()
	rc_check(text2file("metadata A", "adapter_metadata.txt"), "metadata seed")
	var/datum/rc_operation/operation = new
	var/datum/rc_selection/selection = new
	selection.acquire_selected(list("level1", "metadata"), operation)
	var/datum/rc_member/level = selection.members[1]
	var/datum/rc_member/metadata = selection.members[2]
	rc_check(selection.read_level(operation, level) == "adapter A", "bound native level read")
	var/original_text = selection.read_metadata(operation, metadata)
	rc_check(text2file(" appended B", "adapter_metadata.txt"), "metadata append")
	rc_check(selection.read_metadata(operation, metadata) == original_text && file2text("adapter_metadata.txt") != original_text, "copied metadata independent of subsequent file read")
	var/datum/rc_operation/foreign = new
	var/rejected = RC_FALSE
	try
		selection.read_level(foreign, level)
	catch(var/exception/e)
		rejected = RC_TRUE
	rc_check(rejected, "WRONG_OPERATION_REJECTED")
	var/datum/rc_member/foreign_member = new
	foreign_member.label = level.label
	foreign_member.kind = level.kind
	foreign_member.operation = operation
	rejected = RC_FALSE
	try
		selection.read_level(operation, foreign_member)
	catch(var/exception/e)
		rejected = RC_TRUE
	rc_check(rejected, "foreign member rejected")
	operation.active = RC_FALSE
	rejected = RC_FALSE
	try
		selection.read_metadata(operation, metadata)
	catch(var/exception/e)
		rejected = RC_TRUE
	rc_check(rejected, "inactive operation rejected")
	operation.active = RC_TRUE
	selection.close_once()
	selection.close_once()
	rc_check(level.closed && metadata.closed && level.handle.close_calls == 1, "selection close idempotent")
	rejected = RC_FALSE
	try
		selection.read_level(operation, level)
	catch(var/exception/e)
		rejected = RC_TRUE
	rc_check(rejected, "closed selection rejected")
	var/datum/rc_selection/partial = new
	rejected = RC_FALSE
	try
		partial.acquire_selected(list("level1", "metadata"), operation, RC_TRUE)
	catch(var/exception/e)
		rejected = RC_TRUE
	var/datum/rc_member/acquired = partial.members[1]
	rc_check(rejected && partial.closed && partial.members.len == 1 && acquired.closed && acquired.handle.close_calls == 1, "partial acquisition closes exact acquired member")
	var/datum/rc_selection/duplicate = new
	var/prior_handles = rc_handles.len
	rejected = RC_FALSE
	try
		duplicate.acquire_selected(list("level1", "level1"), operation)
	catch(var/exception/e)
		rejected = RC_TRUE
	rc_check(rejected && !duplicate.members.len && rc_handles.len == prior_handles, "duplicate manifest rejects before open")
	rc_observations["adapter_binding_and_cleanup"] = "PASS: fixture identity guards only"
	rc_observations["metadata_copy"] = "PASS: bounded synthetic text copied by value; no binary snapshot proof"

/proc/rc_owner()
	rc_check_adapter()
	var/datum/rc_native_handle/reader = new("selected.sav")
	rc_check(reader.opened(), "owner opens selected level")
	var/locked = reader.native_reader.Lock(0.1)
	rc_observations["owner_lock"] = locked
	rc_check(locked == RC_TRUE, "owner lock available")
	reader.write_value("A")
	// Same-world writers are a different boundary from other-world locks.
	var/datum/rc_native_handle/local_writer = new("selected.sav")
	rc_check(local_writer.opened(), "same-world cooperating writer opens")
	local_writer.write_value("LOCAL")
	rc_observations["same_world_retained_read"] = reader.read_value()
	local_writer.write_value("A")
	local_writer.close_once()
	rc_check(reader.read_value() == "A", "owner initial value")
	rc_signal("owner_locked.txt")
	rc_wait("peer_locked_checked.txt")
	rc_observations["owner_unlock_return"] = reader.native_reader.Unlock()
	rc_check(reader.read_value() == "A", "retained reader after unlock")
	rc_signal("owner_unlocked.txt")
	rc_wait("peer_shared_checked.txt")
	rc_check(reader.read_value() == "A", "retained reader after blocked peer write lock")
	reader.close_once()
	rc_signal("owner_closed.txt")
	rc_wait("peer_written.txt")
	var/datum/rc_native_handle/reopened = new("selected.sav")
	rc_check(reopened.opened(), "owner reopen after peer close")
	rc_observations["reopened_value"] = reopened.read_value()
	rc_check(reopened.read_value() == "B", "reopen observes cooperating peer write")
	reopened.close_once()

/proc/rc_peer()
	rc_wait("owner_locked.txt")
	var/datum/rc_native_handle/blocked = new("selected.sav")
	rc_observations["open_while_locked"] = !!blocked.opened()
	rc_check(!blocked.opened(), "other world open rejected while locked")
	blocked.close_once()
	rc_signal("peer_locked_checked.txt")
	rc_wait("owner_unlocked.txt")
	var/datum/rc_native_handle/shared = new("selected.sav")
	rc_check(shared.opened(), "shared read after unlock")
	rc_observations["shared_value"] = shared.read_value()
	rc_check(shared.read_value() == "A", "peer shared value")
	var/shared_lock = shared.native_reader.Lock(0.1)
	rc_observations["lock_while_owner_reads"] = shared_lock
	rc_check(shared_lock == RC_FALSE, "write lock refused while other world retains reader")
	shared.close_once()
	rc_signal("peer_shared_checked.txt")
	rc_wait("owner_closed.txt")
	var/datum/rc_native_handle/writer = new("selected.sav")
	rc_check(writer.opened(), "peer reopens after owner close")
	var/write_lock = writer.native_reader.Lock(0.1)
	rc_observations["lock_after_owner_close"] = write_lock
	rc_check(write_lock == RC_TRUE, "PEER_LOCK_AFTER_OWNER_CLOSE")
	writer.write_value("B")
	rc_observations["peer_unlock_return"] = writer.native_reader.Unlock()
	writer.close_once()
	rc_signal("peer_written.txt")

/world/New()
	OpenPort("none")
	..()
	rc_role = world.params["role"] == "peer" ? "peer" : "owner"
	var/result = "PASS"
	try
		if(rc_role == "peer")
			rc_peer()
		else
			rc_owner()
	catch(var/exception/e)
		result = "UNSUPPORTED: [e]"
		rc_observations["failure"] = "[e]"
	for(var/datum/rc_native_handle/handle in rc_handles)
		handle.close_once()
	rc_observations["role"] = rc_role
	rc_observations["byond_version"] = world.byond_version
	rc_observations["byond_build"] = world.byond_build
	rc_observations["result"] = result
	rc_observations["host_exclusion_verified"] = RC_FALSE
	rc_observations["production_provider_available"] = RC_FALSE
	text2file(json_encode(rc_observations), "[rc_role].json")
	text2file(result, "[rc_role].result")
	shutdown()
