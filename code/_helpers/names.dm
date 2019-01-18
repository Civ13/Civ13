/proc/customserver_name()
	if (!customserver_name)
		customserver_name = "Civilization 13"
	return customserver_name

/proc/set_world_name(var/name)

	customserver_name = name

	if (config && config.server_name)
		world.name = "[config.server_name]: [name]"
	else
		world.name = name
