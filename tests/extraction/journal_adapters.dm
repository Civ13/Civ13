// Only the standalone journal probes use these fail-closed game boundaries.
// Native equipment and insurance probes compile the production implementations.
/datum/extraction_equipment_codec
	proc/validate(list/P)
		return FALSE
	proc/supported(path)
		return FALSE

/datum/extraction_insurance_returns
	var/list/profile
	proc/ready()
		return FALSE
