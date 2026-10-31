// One budgeted owner for all clients; no perpetual loop per tree presenter.
/process/visibility/setup()
	name = "Geometric visibility"
	schedule_interval = 1
	priority = PROCESS_PRIORITY_HIGH
	processes.visibility = src

/process/visibility/fire()
	for(current in current_list)
		var/client/C = current
		if(C)
			C.reconcile_geometric_los()
		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/visibility/reset_current_list()
	PROCESS_USE_FASTEST_LIST(clients)
