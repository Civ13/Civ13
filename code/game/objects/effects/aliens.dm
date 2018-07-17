/*
 * Acid
 */
/obj/effect/acid
	name = "acid"
	desc = "Burbling corrosive stuff. Probably a bad idea to roll around in it."
	icon_state = "acid"
	icon = 'icons/mob/alien.dmi'

	density = FALSE
	opacity = FALSE
	anchored = TRUE

	var/atom/target
	var/ticks = FALSE
	var/target_strength = FALSE

/obj/effect/acid/New(loc, supplied_target)
	..(loc)
	target = supplied_target

	if (isturf(target)) // Turf take twice as long to take down.
		target_strength = 8
	else
		target_strength = 4
	tick()

/obj/effect/acid/proc/tick()
	if (!target)
		qdel(src)

	ticks++
	if (ticks >= target_strength)
		target.visible_message("<span class='alium'>\The [target] collapses under its own weight into a puddle of goop and undigested debris!</span>")
		if (istype(target, /turf/wall)) // I hate turf code.
			var/turf/wall/W = target
			W.dismantle_wall(1)
		else
			qdel(target)
		qdel(src)
		return

	switch(target_strength - ticks)
		if (6)
			visible_message("<span class='alium'>\The [target] is holding up against the acid!</span>")
		if (4)
			visible_message("<span class='alium'>\The [target]\s structure is being melted by the acid!</span>")
		if (2)
			visible_message("<span class='alium'>\The [target] is struggling to withstand the acid!</span>")
		if (0 to TRUE)
			visible_message("<span class='alium'>\The [target] begins to crumble under the acid!</span>")
	spawn(rand(150, 200)) tick()