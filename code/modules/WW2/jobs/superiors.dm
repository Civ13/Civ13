/mob/living/carbon/human/proc/is_superior_of(var/mob/living/carbon/human/H)
	if (!original_job)
		return FALSE
	if (!H.original_job)
		return FALSE
	if (original_job.base_type_flag() != H.original_job.base_type_flag())
		return FALSE
	if (original_job.is_officer && !H.original_job.is_officer)
		return TRUE
	if (original_job.is_commander)
		if (!H.original_job.is_commander || H.original_job.is_petty_commander)
			return TRUE
	return FALSE