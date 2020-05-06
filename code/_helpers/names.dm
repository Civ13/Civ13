/proc/customserver_name()
	if (!customserver_name)
		if (config.server_name)
			customserver_name = config.server_name
		else
			customserver_name = "Chaos Rising"
	return customserver_name