// Incomplete runtime adapter contract. No host provider or installed world fence.
/datum/persistence_admission_policy
	should_save = FALSE
	proc/recovery_ready(datum/persistence_admission_guard/guard, list/binding)
		return FALSE
	proc/authorize(datum/persistence_admission_guard/guard, action, list/binding)
		return null
	proc/validate_capability(datum/persistence_admission_capability/capability)
		return FALSE
	proc/reserve_restore(list/binding)
		// Must durably reserve AND mark mutation-started before returning TRUE.
		return FALSE
	proc/recover_pending(list/binding)
		return null
	proc/finalize_restore(list/binding, recovery_id, decision)
		return null

/datum/persistence_admission_capability
	should_save = FALSE
	var/datum/persistence_admission_guard/guard
	var/datum/persistence_admission_policy/policy
	var/revision
	var/action
	var/list/binding
	persistence_runtime_var(key)
		return (key in list("guard", "policy", "revision", "action", "binding")) || ..()

/datum/persistence_admission_guard
	should_save = FALSE
	var/datum/persistence_admission_policy/policy
	var/list/binding
	var/revision = 0
	persistence_runtime_var(key)
		return (key in list("policy", "binding", "revision")) || ..()
	proc/revoke()
		revision++
		policy = null
		binding = null
		return TRUE
	proc/bind(datum/persistence_admission_policy/provider, list/selection)
		revoke()
		if(!istype(provider) || !valid_binding(selection)) return FALSE
		policy = provider
		binding = selection.Copy()
		return TRUE
	proc/valid_binding(list/selection)
		if(!islist(selection) || selection.len != 8) return FALSE
		for(var/key in list("server", "world", "root", "process", "operation", "members", "schema"))
			if(!istext(selection[key]) || !length(selection[key]) || length(selection[key]) > 1024) return FALSE
		var/generation = selection["generation"]
		return isnum(generation) && generation > 0 && round(generation) == generation
	proc/same_binding(list/selection)
		if(!valid_binding(binding) || !valid_binding(selection)) return FALSE
		for(var/key in binding)
			if(selection[key] != binding[key]) return FALSE
		return TRUE
	proc/current(datum/persistence_admission_policy/provider, expected_revision, list/selection)
		return provider && policy == provider && revision == expected_revision && same_binding(selection)
	proc/acquire(action)
		if(!istext(action) || !length(action) || length(action) > 128 || !policy || !valid_binding(binding)) return null
		var/datum/persistence_admission_policy/provider = policy
		var/expected_revision = revision
		var/list/selection = binding.Copy()
		if(provider.recovery_ready(src, selection.Copy()) != TRUE || !src || !current(provider, expected_revision, selection)) return null
		var/datum/persistence_admission_capability/capability = provider.authorize(src, action, selection.Copy())
		if(!src || !current(provider, expected_revision, selection) || !permits(capability, action)) return null
		return capability
	proc/permits(datum/persistence_admission_capability/capability, action)
		if(!capability_matches(capability, action)) return FALSE
		var/datum/persistence_admission_policy/provider = policy
		var/expected_revision = revision
		var/list/selection = binding.Copy()
		if(!provider || provider.recovery_ready(src, selection.Copy()) != TRUE || !src || !current(provider, expected_revision, selection) || !capability_matches(capability, action)) return FALSE
		if(provider.validate_capability(capability) != TRUE || !src || !current(provider, expected_revision, selection)) return FALSE
		// Provider calls may yield or mutate the capability. Recheck every field.
		return capability_matches(capability, action)
	proc/capability_matches(datum/persistence_admission_capability/capability, action)
		if(!src || !istext(action) || !length(action) || length(action) > 128 || !istype(capability)) return FALSE
		return capability.guard == src && capability.policy == policy && capability.revision == revision && capability.action == action && same_binding(capability.binding)
