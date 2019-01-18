var/database/database = null

/database/New()
	..()


/database/proc/newUID()
	return num2text(rand(1, 1000*1000*1000), 20)