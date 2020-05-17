/mob/living/human/proc/get_assignment_noid()
	if (original_job && original_job.title == "N/A")
		return original_job.title
	if (!mind || !mind.assigned_job)
		return ""
	return mind.assigned_job.title
