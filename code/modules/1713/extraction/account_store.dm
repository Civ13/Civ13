// Bounded two-slot account journal. Incomplete transfers fail closed.
#define EXTRACTION_STORE_VERSION 1
#define EXTRACTION_PROFILE_LIMIT 2097152

/datum/extraction_account_store
	var/root = "data/extraction_accounts/"
	var/last_error
	var/tmp/busy = FALSE
	var/tmp/test_fail_at = null

/datum/extraction_account_store/proc/valid_owner(owner)
	return istext(owner) && length(owner) > 0 && length(owner) <= 64 && ckey(owner) == owner && findtext(owner, "guest") != 1

/datum/extraction_account_store/proc/path_for(owner, slot, suffix)
	return "[root][owner]/[slot].[suffix]"

/datum/extraction_account_store/proc/fail(message)
	last_error = message
	return null

/datum/extraction_account_store/proc/valid_profile(list/P, owner)
	if (islist(P) && !isnull(P["raid_faction"]) && !(P["raid_faction"] in list("PMC", "Scav"))) return FALSE
	if (!islist(P)) return FALSE
	var/list/stash = P["stash"]
	return P["schema"] == EXTRACTION_STORE_VERSION && P["owner"] == owner && isnum(P["revision"]) && P["revision"] >= 0 && round(P["revision"]) == P["revision"] && isnum(P["level"]) && P["level"] >= 1 && P["level"] <= 4 && round(P["level"]) == P["level"] && islist(stash) && stash.len <= 64 && (P["state"] == "home" || P["state"] == "raid") && isnum(P["raid_sequence"]) && P["raid_sequence"] >= 0 && round(P["raid_sequence"]) == P["raid_sequence"]

// A newer intent without its exact committed payload blocks automatic rollback.
// The older slot may contain equipment already issued to an interrupted raid.
/datum/extraction_account_store/proc/read_slot(owner, slot)
	var/intent_path = path_for(owner, slot, "intent")
	if (!fexists(intent_path)) return list("generation" = 0)
	var/list/intent
	try
		intent = json_decode(file2text(intent_path))
	catch
		return fail("Malformed intent; preserve both slots for recovery")
	if (!islist(intent) || intent["owner"] != owner || intent["schema"] != EXTRACTION_STORE_VERSION || !isnum(intent["generation"]) || intent["generation"] < 1 || round(intent["generation"]) != intent["generation"])
		return fail("Invalid account intent")
	var/list/commit
	try
		commit = json_decode(file2text(path_for(owner, slot, "commit")))
	catch
		commit = null
	if (!islist(commit) || commit["generation"] != intent["generation"] || commit["digest"] != intent["digest"])
		return list("generation" = intent["generation"], "pending" = TRUE)
	var/payload = file2text(path_for(owner, slot, "snapshot"))
	if (!istext(payload) || length(payload) > EXTRACTION_PROFILE_LIMIT || md5(payload) != intent["digest"])
		return list("generation" = intent["generation"], "pending" = TRUE)
	var/list/profile
	try
		profile = json_decode(payload)
	catch
		return fail("Malformed committed snapshot")
	if (!valid_profile(profile, owner) || profile["revision"] != intent["generation"]) return fail("Invalid or unsupported profile")
	return list("generation" = intent["generation"], "profile" = profile)

/datum/extraction_account_store/proc/load_profile(owner)
	last_error = null
	if (!valid_owner(owner)) return fail("Stable registered account required")
	var/list/A = read_slot(owner, 0)
	var/list/B = read_slot(owner, 1)
	if (!A || !B) return null
	var/list/latest = A["generation"] > B["generation"] ? A : B
	if (latest["pending"]) return fail("Incomplete newest transfer; account locked for recovery")
	if (!latest["generation"])
		return list("schema" = EXTRACTION_STORE_VERSION, "owner" = owner, "revision" = 0, "level" = 1, "stash" = list(), "state" = "home", "raid_sequence" = 0)
	return latest["profile"]

// Native DM has no portable atomic rename. Each flushed, verified phase is
// copied into an inactive slot; its intent is the durable recovery barrier.
/datum/extraction_account_store/proc/write_phase(path, payload)
	var/temp = "[path].pending"
	if (fexists(temp) && !fdel(temp)) return FALSE
	text2file(payload, temp)
	// text2file appends a newline; compare the exact durable representation.
	var/durable = "[payload]\n"
	if (file2text(temp) != durable) return FALSE
	if (!fcopy(temp, path) || file2text(path) != durable) return FALSE
	fdel(temp)
	return TRUE

/datum/extraction_account_store/proc/commit_profile(owner, list/P)
	last_error = null
	if (busy || !valid_owner(owner) || !valid_profile(P, owner)) return fail("Invalid or concurrent write")
	busy = TRUE
	var/list/A = read_slot(owner, 0)
	var/list/B = read_slot(owner, 1)
	if (!A || !B || A["pending"] || B["pending"])
		busy = FALSE
		return fail("Account requires recovery")
	var/generation = max(A["generation"], B["generation"]) + 1
	if (P["revision"] != generation - 1 || generation > 1000000)
		busy = FALSE
		return fail("Stale revision or exhausted generation budget")
	var/list/candidate = P.Copy()
	candidate["revision"] = generation
	var/payload = json_encode(candidate)
	if (length(payload) > EXTRACTION_PROFILE_LIMIT)
		busy = FALSE
		return fail("Profile exceeds byte budget")
	var/slot = A["generation"] <= B["generation"] ? 0 : 1
	var/digest = md5("[payload]\n")
	var/intent = json_encode(list("schema" = EXTRACTION_STORE_VERSION, "owner" = owner, "generation" = generation, "digest" = digest))
	var/success = write_phase(path_for(owner, slot, "intent"), intent)
	if (success && test_fail_at != "intent") success = write_phase(path_for(owner, slot, "snapshot"), payload)
	else success = FALSE
	if (success && test_fail_at != "snapshot") success = write_phase(path_for(owner, slot, "commit"), json_encode(list("generation" = generation, "digest" = digest)))
	else success = FALSE
	busy = FALSE
	if (!success) return fail("Interrupted transfer; account locked for recovery")
	var/list/check = read_slot(owner, slot)
	if (!check || check["pending"] || check["generation"] != generation) return fail("Commit readback failed")
	P["revision"] = generation
	return TRUE
