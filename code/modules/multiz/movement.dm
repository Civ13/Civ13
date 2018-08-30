/mob/observer/ghost/verb/moveup()
	set name = "Move Upwards"
	set category = "Ghost"
	if (z < world.maxz)
		z = z+1


/mob/observer/ghost/verb/movedown()
	set name = "Move Downwards"
	set category = "Ghost"
	if (z > 1)
		z = z-1