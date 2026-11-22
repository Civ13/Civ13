/mob/observer/ghost/verb/moveup()
	set name = "Move Upwards"
	set category = "Ghost"
	if (z < world.maxz && incorporeal_step_allowed(locate(x, y, z+1))) // spirit_observe.dm
		persistence_set_z(z+1)


/mob/observer/ghost/verb/movedown()
	set name = "Move Downwards"
	set category = "Ghost"
	if (z > 1 && incorporeal_step_allowed(locate(x, y, z-1)))
		persistence_set_z(z-1)