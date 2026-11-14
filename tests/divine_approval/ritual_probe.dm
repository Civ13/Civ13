// Optional native assertions. Include after civ13.dme and probe.dm in the
// reviewed network-contained fixture; never start the normal game for this.
/mob/living/divine_ritual_probe
	var/obj/item/probe_focus
	var/probe_session = ""
/mob/living/divine_ritual_probe/get_active_hand()
	return probe_focus
/mob/living/divine_ritual_probe/get_inactive_hand()
	return null
/datum/divine_use_request/ritual/probe/participant_identity(mob/living/divine_ritual_probe/member)
	return member.probe_session
/datum/divine_use_request/ritual/probe/participant_ready(mob/living/member)
	return member && !QDELETED(member) && member.stat == CONSCIOUS

/proc/divine_ritual_probe()
	var/mob/living/divine_ritual_probe/leader = new(locate(2, 2, 1))
	var/mob/living/divine_ritual_probe/second = new(locate(3, 2, 1))
	var/mob/living/divine_ritual_probe/third = new(locate(2, 3, 1))
	leader.probe_session = "leader"
	second.probe_session = "second"
	third.probe_session = "third"
	var/obj/item/focus = new(leader)
	leader.probe_focus = focus
	var/datum/divine_covenant_runtime/probe/C = new(leader, "patron", list(), list("vigil"))
	C.active = TRUE
	var/list/enrolled = list(leader, second, third)
	var/datum/divine_use_request/ritual/probe/R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	divine_probe_assert(R.state == "requested", "ritual requires a new approval")
	divine_probe_assert(!R.start_channel(), "cannot channel before approval")
	enrolled.Cut()
	divine_probe_assert(R.participants.len == 3, "caller roster does not alias request")
	divine_probe_assert(R.approve(null) && R.start_channel(), "approved ritual can start")
	divine_probe_assert(!R.start_channel(), "channel cannot restart or refresh")
	divine_probe_assert(!R.consume(leader, "vigil", third, "vigil-v1"), "cannot consume before duration")
	R.channel_ready_at = world.time // simulated clock boundary, not a timing claim
	divine_probe_assert(!R.consume(leader, "vigil", third, "other"), "changed scope refuses")
	divine_probe_assert(R.consume(leader, "vigil", third, "vigil-v1"), "completed exact channel consumes")
	divine_probe_assert(!R.consume(leader, "vigil", third, "vigil-v1"), "replay refuses")
	enrolled = list(leader, second, third)
	R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	R.approve(null)
	R.start_channel()
	second.probe_session = "changed"
	divine_probe_assert(!R.current() && R.state == "cancelled", "session change cancels")
	second.probe_session = "second"
	divine_probe_assert(!R.current(), "returning session cannot restore cancelled channel")
	R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	R.approve(null)
	R.start_channel()
	R.invalidate_channel() // adapter reports departure before return
	divine_probe_assert(!R.current(), "event invalidation survives leave and return")
	R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	leader.probe_focus = null
	divine_probe_assert(!R.current(), "losing focus cancels")
	leader.probe_focus = focus
	second.probe_session = "leader"
	R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	divine_probe_assert(R.state == "cancelled", "same session cannot count twice")
	second.probe_session = "second"
	R = new(C, "vigil", third, "vigil-v1", list(leader, second), focus)
	divine_probe_assert(R.state == "cancelled", "too few participants refuses")
	R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	R.approve(null)
	R.deadline = world.time + R.channel_duration
	divine_probe_assert(!R.start_channel(), "insufficient approval lifetime refuses")
	R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	R.participants -= second
	divine_probe_assert(!R.current(), "removed participant cannot silently shrink roster")
	R = new(C, "vigil", third, "vigil-v1", enrolled, focus)
	R.participants[2] = null
	divine_probe_assert(!R.current(), "cleared participant cannot be skipped")
	return divine_probe_failures == 0
