// Historical fixture: the off-map sleep teleport was removed from the game.
// These two helpers are frozen here, verbatim from their last production copy,
// so the native probe keeps an actor that crosses levels and round-trips saves.
// They exercise the save-reference diagnostics and the production buckling and
// movement helpers; they are not game behavior.
/mob/living/human/proc/enter_protected_sleep()
	if (persistence_sleep_transfer_blocked() || inducedSSD)
		return FALSE
	var/turf/return_turf = get_turf(src)
	var/turf/sleep_turf = locate(1,1,1)
	if (!return_turf || !sleep_turf)
		return FALSE
	// Retain the return point before unbuckling; hooks must not change it.
	if (!release_protected_sleep_buckle() || persistence_sleep_transfer_blocked() || get_turf(src) != return_turf)
		return FALSE
	drop_item()
	// Inventory hooks may yield or move/rebuckle the body; recheck before transfer.
	if (persistence_sleep_transfer_blocked() || inducedSSD || buckled || !return_turf || !sleep_turf || get_turf(src) != return_turf)
		return FALSE
	var/previous_lastx = lastx
	var/previous_lasty = lasty
	var/previous_lastz = lastz
	var/previous_sleeping = sleeping
	lastx = return_turf.x
	lasty = return_turf.y
	lastz = return_turf.z
	sleeping = 66
	inducedSSD = TRUE
	forceMove(sleep_turf)
	if (!sleep_turf || get_turf(src) != sleep_turf)
		lastx = previous_lastx
		lasty = previous_lasty
		lastz = previous_lastz
		sleeping = previous_sleeping
		inducedSSD = FALSE
		return FALSE
	if (s_active)
		s_active.close(src)
	sleep_update()
	return TRUE

/mob/living/human/proc/complete_protected_wakeup()
	if (persistence_sleep_transfer_blocked() || !inducedSSD)
		return FALSE
	var/turf/return_turf = locate(lastx,lasty,lastz)
	if (!return_turf || is_protected_sleep_location(return_turf))
		return FALSE
	// Also repairs the reciprocal, distant bed link made by older sleep code.
	// Never release a different occupant through an inconsistent stale pointer.
	if (!release_protected_sleep_buckle() || persistence_sleep_transfer_blocked() || !return_turf || locate(lastx,lasty,lastz) != return_turf)
		return FALSE
	forceMove(return_turf)
	if (!return_turf || get_turf(src) != return_turf || is_protected_sleep_location(src) || persistence_sleep_transfer_blocked())
		return FALSE
	sleeping = 0
	inducedSSD = FALSE
	return TRUE
