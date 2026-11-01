/*
	This state checks that the src_object is the same the as user
*/
/var/global/datum/topic_state/self_state/self_state = new()

/datum/topic_state/self_state/can_use_topic(var/src_object, var/mob/user)
	if (src_object != user)
		return STATUS_CLOSE
	return user.shared_nano_interaction()

// Personal read-only information remains available to observers/incapacitated
// owners, as the original browse readers were. It never permits a domain action.
/var/global/datum/topic_state/self_read_only/self_read_only_state = new()

/datum/topic_state/self_read_only/can_use_topic(var/src_object, var/mob/user)
	if (src_object != user || !user || !user.client)
		return STATUS_CLOSE
	return STATUS_UPDATE
