	operation.finish(TRUE)
	persistence_startup_recovery_status = null
	// Restart recovery reclaims waiting clients after consuming its intent.
	return 1
