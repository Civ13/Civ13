// Injected provider checks actual adapter contracts, not host custody.
var/list/admission_probe_failures = list()
world
	maxx = 1
	maxy = 1
	maxz = 1
	visibility = 0
	sleep_offline = 0
/world/OpenPort(port)
	return ..("none")
/datum
	var/should_save = TRUE
	proc/persistence_runtime_var(key)
		return FALSE
/datum/persistence_admission_policy/fixture
	var/ready_result = TRUE
	var/validate_result = TRUE
	var/change
	var/datum/persistence_admission_capability/observed
	recovery_ready(datum/persistence_admission_guard/guard, list/binding)
		if(change == "ready_guard_delete")
			del(guard)
			return TRUE
		if(change == "ready_policy_delete")
			del(src)
			return TRUE
		if(change == "ready_rebind") guard.bind(src, binding)
		if(change == "ready_revoke") guard.revoke()
		if(change == "ready_delete") del(observed)
		if(change == "ready_yield")
			spawn(0) guard.revoke()
			sleep(1)
		return ready_result
	authorize(datum/persistence_admission_guard/guard, action, list/binding)
		var/datum/persistence_admission_capability/C = new
		C.guard = guard
		C.policy = src
		C.revision = guard.revision
		C.action = action
		C.binding = binding.Copy()
		if(change == "authorize_revoke") guard.revoke()
		return C
	validate_capability(datum/persistence_admission_capability/C)
		if(change == "validate_guard_delete")
			del(C.guard)
			return TRUE
		if(change == "validate_policy_delete")
			del(src)
			return TRUE
		if(change == "validate_delete") del(C)
		if(change == "validate_action") C.action = "other"
		if(change == "validate_binding") C.binding["world"] = "foreign"
		if(change == "validate_revoke") C.guard.revoke()
		return validate_result
/world
	proc/check(value, message)
		if(!value) admission_probe_failures += "FAIL: [message]"
	proc/selection()
		return list("server" = "test-server", "world" = "test-world", "root" = "test-root", "process" = "test-process", "operation" = "test-operation", "generation" = 1, "members" = "test-manifest", "schema" = "existing-test-formats")
	proc/execute()
		var/datum/persistence_admission_guard/G = new
		var/datum/persistence_admission_policy/base = new
		var/datum/persistence_admission_policy/fixture/P = new
		check(!G.acquire("deploy"), "unbound guard denied")
		check(G.bind(base, selection()) && !G.acquire("deploy"), "base provider denies")
		check(base.reserve_restore(selection()) == FALSE && isnull(base.recover_pending(selection())) && isnull(base.finalize_restore(selection(), "recovery", "decision")), "base host methods unavailable")
		check(!G.bind(P, null), "missing binding rejected")
		var/list/extra = selection()
		extra["extra"] = "unexpected"
		check(!G.bind(P, extra), "extra binding rejected")
		for(var/key in selection())
			var/list/missing = selection()
			missing -= key
			check(!G.bind(P, missing), "missing [key] rejected")
			var/list/nonscalar = selection()
			nonscalar[key] = list("nested")
			check(!G.bind(P, nonscalar), "nonscalar [key] rejected")
		for(var/generation in list(0, -1, 1.5, "1"))
			var/list/invalid = selection()
			invalid["generation"] = generation
			check(!G.bind(P, invalid), "invalid generation rejected")
		var/list/source = selection()
		check(G.bind(P, source), "valid binding accepted")
		source["world"] = "mutated-caller"
		check(G.binding["world"] == "test-world", "binding scalar copy")
		check(!G.acquire(null) && !G.acquire("") && !G.acquire(5) && !G.acquire(list("deploy")), "malformed action denied")
		var/long_action = ""
		for(var/i = 1, i <= 129, i++) long_action += "a"
		check(!G.acquire(long_action), "overlong action denied")
		var/datum/persistence_admission_capability/C = G.acquire("deploy")
		check(C && G.permits(C, "deploy"), "valid capability accepted")
		check(!G.permits(C, "other"), "wrong action denied")
		C.action = "other"
		check(!G.permits(C, "deploy"), "changed capability action denied")
		C.action = "deploy"
		C.binding["world"] = "foreign"
		check(!G.permits(C, "deploy"), "foreign capability binding denied")
		C.binding = selection()
		C.revision--
		check(!G.permits(C, "deploy"), "stale revision denied")
		C.revision = G.revision
		C.policy = base
		check(!G.permits(C, "deploy"), "foreign policy denied")
		C.policy = P
		var/datum/persistence_admission_guard/other = new
		C.guard = other
		check(!G.permits(C, "deploy"), "foreign guard denied")
		C.guard = G
		G.revoke()
		check(!G.permits(C, "deploy"), "revoked capability denied")
		for(var/truthy in list(2, "yes", list("yes")))
			P.ready_result = truthy
			G.bind(P, selection())
			check(!G.acquire("deploy"), "ready exact TRUE required")
			P.ready_result = TRUE
			P.validate_result = truthy
			check(!G.acquire("deploy"), "validation exact TRUE required")
			P.validate_result = TRUE
		for(var/change in list("ready_revoke", "ready_rebind", "ready_yield", "authorize_revoke", "validate_binding", "validate_revoke"))
			P.change = change
			G.bind(P, selection())
			check(!G.acquire("deploy"), "callback [change] denied")
		P.change = "validate_action"
		G.bind(P, selection())
		check(!G.acquire("deploy"), "post-callback action recheck required")
		P.change = null
		for(var/deletion in list("ready_delete", "validate_delete"))
			G.bind(P, selection())
			C = G.acquire("deploy")
			P.observed = C
			P.change = deletion
			check(!G.permits(C, "deploy"), "callback [deletion] denies deleted capability")
			P.change = null
		G.bind(P, selection())
		C = G.acquire("deploy")
		spawn(0) G.revoke()
		sleep(1)
		check(!G.permits(C, "deploy"), "after-yield capability denied")
		check(!G.should_save && !P.should_save && !C.should_save, "adapter runtime only")
		for(var/deletion in list("ready_guard_delete", "ready_policy_delete", "validate_guard_delete", "validate_policy_delete"))
			G = new
			P = new
			G.bind(P, selection())
			C = G.acquire("deploy")
			P.change = deletion
			check(!G.permits(C, "deploy"), "callback [deletion] denies deleted owner")
		return TRUE
	New()
		OpenPort("none")
		..()
		try
			execute()
		catch(var/exception/e)
			admission_probe_failures += "UNEXPECTED: [e]"
		text2file(admission_probe_failures.len ? jointext(admission_probe_failures, "\n") : "PASS", "result.txt")
		shutdown()
