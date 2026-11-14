// Disabled phase-one contract. No verbs, globals, UI or effect dispatch.
// Call only from a server-owned adapter after resolving character and target.
// Runtime approvals are intentionally not portable or restored from a save.
// Snapshot comparisons cannot detect leave-and-return events. The integrating
// adapter must invalidate the covenant on movement, client/body changes,
// authority changes and transfer BEFORE these boundaries can be reused.

/datum/divine_covenant_runtime
	should_save = FALSE
	var/mob/caster
	var/client/caster_client
	var/deity_id
	var/list/operator_ckeys = list()
	var/list/allowed_spells = list()
	var/revision = 1
	var/active = FALSE

/datum/divine_covenant_runtime/New(mob/subject, patron, list/operators, list/spells)
	..()
	caster = subject
	caster_client = subject ? subject.client : null
	deity_id = patron
	operator_ckeys = operators ? operators.Copy() : list()
	allowed_spells = spells ? spells.Copy() : list()
	// A server adapter must explicitly activate this covenant after validation.

/datum/divine_covenant_runtime/proc/current()
	return active && caster && !QDELETED(caster) && caster_client && caster.client == caster_client && caster_client.mob == caster

/datum/divine_covenant_runtime/proc/operator_allowed(client/operator)
	return current() && operator && operator.holder && (operator.holder.rights & R_ADMIN) && (operator.ckey in operator_ckeys)

/datum/divine_covenant_runtime/proc/operator_key(client/operator)
	return operator_allowed(operator) ? operator.ckey : null

/datum/divine_covenant_runtime/proc/invalidate()
	active = FALSE
	revision++

/datum/divine_covenant_runtime/Destroy()
	invalidate()
	caster = null
	caster_client = null
	operator_ckeys = null
	allowed_spells = null
	return ..()

/datum/divine_use_request
	should_save = FALSE
	var/datum/divine_covenant_runtime/covenant
	var/covenant_revision
	var/spell_id
	var/atom/target
	var/turf/caster_origin
	var/turf/target_origin
	var/scope_key // Server-generated immutable effect/cost specification ID.
	var/state = "invalid"
	var/deadline = 0
	var/client/approver
	var/approver_ckey
	var/approved_deity

/datum/divine_use_request/New(datum/divine_covenant_runtime/grant, spell, atom/destination, scope, lifetime = 300)
	..()
	if (!grant || !grant.current() || !(spell in grant.allowed_spells))
		return
	if (!destination || QDELETED(destination) || !get_turf(destination) || !get_turf(grant.caster))
		return
	if (!istext(scope) || !length(scope) || !isnum(lifetime) || lifetime < 1 || lifetime > 600)
		return
	covenant = grant
	covenant_revision = grant.revision
	spell_id = spell
	target = destination
	caster_origin = get_turf(grant.caster)
	target_origin = get_turf(destination)
	scope_key = scope
	deadline = world.time + lifetime
	state = "requested"

/datum/divine_use_request/proc/current()
	if (state != "requested" && state != "approved")
		return FALSE
	if (world.time >= deadline)
		state = "expired"
		return FALSE
	if (!covenant || QDELETED(covenant) || !covenant.current() || covenant.revision != covenant_revision || !(spell_id in covenant.allowed_spells))
		state = "cancelled"
		return FALSE
	if (!target || QDELETED(target) || get_turf(covenant.caster) != caster_origin || get_turf(target) != target_origin)
		state = "cancelled"
		return FALSE
	return TRUE

/datum/divine_use_request/proc/approve(client/operator)
	if (!current() || state != "requested")
		return FALSE
	var/key = covenant.operator_key(operator)
	if (!key)
		return FALSE
	approver = operator
	approver_ckey = key
	approved_deity = covenant.deity_id
	state = "approved"
	log_admin("Divine use approved by [approver_ckey] as [approved_deity]: [spell_id], [scope_key]")
	return TRUE

/datum/divine_use_request/proc/deny(client/operator)
	if (!current() || !covenant.operator_allowed(operator))
		return FALSE
	state = "denied"
	log_admin("Divine use denied by [operator.ckey] as [covenant.deity_id]: [spell_id], [scope_key]")
	return TRUE

/datum/divine_use_request/proc/cancel(client/requester)
	if (!current() || requester != covenant.caster_client)
		return FALSE
	state = "cancelled"
	return TRUE

// The adapter rechecks resources, range and spell-specific legality immediately
// before this synchronous call. There must be no yield between those checks,
// consuming this approval, charging resources and applying the effect. Failure
// after consumption fails closed: no implicit refund or reusable approval.
/datum/divine_use_request/proc/consume(mob/subject, spell, atom/destination, scope)
	if (!current() || state != "approved")
		return FALSE
	if (subject != covenant.caster || spell != spell_id || destination != target || scope != scope_key)
		return FALSE
	if (covenant.operator_key(approver) != approver_ckey || covenant.deity_id != approved_deity)
		state = "cancelled"
		return FALSE
	state = "consumed"
	log_admin("Divine use consumed: [spell_id], [scope_key]; approved by [approver_ckey] as [approved_deity]")
	return TRUE

/datum/divine_use_request/Destroy()
	state = "cancelled"
	covenant = null
	target = null
	caster_origin = null
	target_origin = null
	approver = null
	return ..()
