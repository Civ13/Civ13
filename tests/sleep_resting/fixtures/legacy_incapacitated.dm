/mob/proc/incapacitated(incapacitation_flags)
	if ((incapacitation_flags & INCAPACITATION_DISABLED) && (stat || paralysis || stunned || weakened || resting || sleeping || (status_flags & FAKEDEATH)))
		return TRUE

	if ((incapacitation_flags & INCAPACITATION_RESTRAINED) && restrained())
		return TRUE

	if ((incapacitation_flags & (INCAPACITATION_BUCKLED_PARTIALLY|INCAPACITATION_BUCKLED_FULLY)))
		var/buckling = buckled()
		if (buckling >= PARTIALLY_BUCKLED && (incapacitation_flags & INCAPACITATION_BUCKLED_PARTIALLY))
			return TRUE
		if (buckling == FULLY_BUCKLED && (incapacitation_flags & INCAPACITATION_BUCKLED_FULLY))
			return TRUE

	return FALSE
