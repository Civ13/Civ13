/obj/effect/kana
	icon = 'icons/effects/kana.dmi'
	icon_state = "1"
	layer = 10

/obj/effect/kana/New(_loc, var/atom/movable/master = null)
	..(_loc)

	var/ix = x
	var/iy = y
	var/iz = z

	var/master_ix = master ? master.x : 0
	var/master_iy = master ? master.y : 0
	var/master_iz = master ? master.z : 0

	var/time = 0
	spawn while (src)
		sleep(0.33)
		pixel_x = rand(-5,5)
		pixel_y = rand(-5,5)
		if (prob(33))
			color = rgb(rand(127,255), rand(127,255), rand(127,255))
		if (master)
			x = ix + (master.x - master_ix)
			y = iy + (master.y - master_iy)
			z = iz + (master.z - master_iz)
		time += 0.33
		if (time >= 65)
			qdel(src)
			return