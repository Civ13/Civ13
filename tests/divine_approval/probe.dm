// Include only in an isolated full-game fixture after civ13.dme.
#include "../../code/modules/divine/approval.dm"

/datum/divine_covenant_runtime/probe
	var/permit = TRUE
/datum/divine_covenant_runtime/probe/current()
	return active && caster && !QDELETED(caster)
/datum/divine_covenant_runtime/probe/operator_key(client/operator)
	return permit ? "probe_operator" : null

var/divine_probe_failures = 0
/proc/divine_probe_assert(condition, label)
	if (!condition)
		divine_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/proc/divine_approval_probe()
	var/mob/M = new(locate(1, 1, 1))
	var/obj/T = new(locate(2, 1, 1))
	var/datum/divine_covenant_runtime/probe/C = new(M, "patron", list(), list("mercy"))
	C.active = TRUE
	var/datum/divine_use_request/R = new(C, "mercy", T, "bounded-v1")
	divine_probe_assert(R.state == "requested", "knowledge does not approve a use")
	divine_probe_assert(!R.consume(M, "mercy", T, "bounded-v1"), "pending use refuses")
	divine_probe_assert(R.approve(null), "explicit operator boundary approves once")
	divine_probe_assert(!R.approve(null), "same request cannot be reapproved")
	divine_probe_assert(!R.consume(M, "mercy", T, "changed"), "changed scope refuses")
	divine_probe_assert(R.consume(M, "mercy", T, "bounded-v1"), "approved exact scope consumes")
	divine_probe_assert(!R.consume(M, "mercy", T, "bounded-v1"), "replay refuses")
	var/datum/divine_use_request/S = new(C, "mercy", T, "bounded-v1")
	divine_probe_assert(!S.consume(M, "mercy", T, "bounded-v1"), "another request needs another approval")
	S.approve(null)
	C.permit = FALSE
	divine_probe_assert(!S.consume(M, "mercy", T, "bounded-v1"), "revoked operator refuses")
	C.permit = TRUE
	S = new(C, "mercy", T, "bounded-v1")
	S.approve(null)
	C.revision++
	divine_probe_assert(!S.consume(M, "mercy", T, "bounded-v1"), "changed grant refuses")
	S = new(C, "mercy", T, "bounded-v1")
	S.approve(null)
	S.deadline = world.time
	divine_probe_assert(!S.consume(M, "mercy", T, "bounded-v1"), "expired approval refuses")
	S = new(C, "mercy", T, "bounded-v1")
	S.approve(null)
	T.loc = locate(3, 1, 1)
	divine_probe_assert(!S.consume(M, "mercy", T, "bounded-v1"), "target movement refuses")
	var/datum/divine_covenant_runtime/real_boundary = new(M, "patron", list(), list("mercy"))
	divine_probe_assert(!real_boundary.operator_key(null), "real boundary never authorizes null client")
	return divine_probe_failures == 0
