// TRUE when A is an item that declares every quality in `quality` (TOOL_*
// flags in code/__defines/tools.dm). Null and non-items are never tools.
/proc/is_tool(atom/A, quality)
	if (!isitem(A))
		return FALSE
	var/obj/item/I = A
	return (I.tool_flags & quality) == quality

// Wrench fastening shared by fixed objects. Both return TRUE when the anchor
// changed; structures then get anchor_changed() so networks can rebuild.

// Instant: one ratchet and a message to the user.
/obj/proc/toggle_anchor(mob/user)
	if (magic_repo_id && magic_repo_unfasten_refused(user)) // repository_wards.dm
		return FALSE
	playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
	to_chat(user, anchored ? SPAN_NOTICE("You unfasten \the [src] from the floor.") : SPAN_NOTICE("You secure \the [src] to the floor."))
	anchored = !anchored
	anchor_toggled()
	return TRUE

// Timed: everyone nearby sees the work start and finish. Nothing changes if the
// wait is interrupted or someone else toggled it meanwhile. `label` replaces
// "\the [src]" in the messages.
/obj/proc/timed_toggle_anchor(mob/user, delay = 50, label = null)
	if (magic_repo_id && magic_repo_unfasten_refused(user)) // repository_wards.dm
		return FALSE
	if (!label)
		label = "\the [src]"
	var/was_anchored = anchored
	visible_message("<span class='warning'>[user] starts to [anchored ? "unsecure" : "secure"] [label] [anchored ? "from" : "to"] the ground.</span>")
	playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
	// A wrench in a better or worse metal changes the wait (tool_materials.dm).
	delay = tool_work_time(user.get_active_hand(), delay)
	if (!do_after(user, delay, src) || QDELETED(src) || anchored != was_anchored)
		return FALSE
	visible_message("<span class='warning'>[user] [anchored ? "unsecures" : "secures"] [label] [anchored ? "from" : "to"] the ground.</span>")
	anchored = !anchored
	anchor_toggled()
	return TRUE

/obj/proc/anchor_toggled()
	if (istype(src, /obj/structure))
		var/obj/structure/S = src
		S.anchor_changed()
