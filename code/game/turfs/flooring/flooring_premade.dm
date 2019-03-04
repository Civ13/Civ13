/turf/floor/carpet
	name = "carpet"
	icon = 'icons/turf/floors.dmi'
	icon_state = "carpet"
	initial_flooring = /decl/flooring/carpet

/turf/floor/wood
	name = "wooden floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood"
	initial_flooring = /decl/flooring/wood

/turf/floor/grass
	name = "wild grass"
	icon = 'icons/turf/floors.dmi'
	icon_state = "grass0"
	initial_flooring = /decl/flooring/grass
	is_diggable = TRUE
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE
	var/obj/structure/wild/wild = null

/turf/floor/grass/ex_act(severity)
	return

/turf/floor/grass/New()
	..()
	grass_turf_list += src
	icon_state = "grass[rand(0,3)]"

/turf/floor/grass/proc/plant()
	// 3x3 clumps of grass - original code
	if (prob(1))
		if (!locate(/obj/structure/wild/bush) in range(3, src))
			if (!locate(/obj/item) in range(3, src))
				for (var/turf/floor/grass/G in range(3, src))
					if (!locate(/obj/structure) in G)
						var/dist = get_dist(src, G)
						if (prob(100-(dist*5)))
							G.wild = new/obj/structure/wild/bush(G)
	// huge grassy areas - adapted from Drymouth Gulch
	else
		if (locate(/obj/structure) in src)
			return
		if (locate(/obj/item) in src)
			return
		if (prob(0.1)) // default is 0.1
			wild = new/obj/structure/wild/bush(src)
		else
			var/chance = FALSE
			for (var/turf/floor/grass/T in range(1,src))
				if (T.wild)
					chance += 40 // default is 40
			if (prob(chance))
				wild = new/obj/structure/wild/bush(src)


/turf/floor/dirt
	name = "dirt"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt"
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE
	available_dirt = 3
	is_diggable = TRUE
	initial_flooring = /decl/flooring/dirt

/turf/floor/dirt/flooded
	name = "flood plains dirt"
	icon = 'icons/turf/floors.dmi'
	icon_state = "flood_dirt"
	desc = "a fertile dirt patch, flooded during the wet season."
	uses_winter_overlay = FALSE
	may_become_muddy = TRUE
	available_dirt = 3
	is_diggable = TRUE
	initial_flooring = /decl/flooring/flooded

/turf/floor/dirt/winter
	name = "snowy dirt"
	icon = 'icons/turf/snow.dmi'
	icon_state = "dirt"
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE
	available_snow = 2
	available_dirt = 0
	is_diggable = TRUE
	initial_flooring = /decl/flooring/snow_dirt

/turf/floor/dirt/burned
	name = "burned ground"
	icon_state = "burned_dirt"
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE
	available_dirt = 1
	is_diggable = TRUE
	initial_flooring = null

/turf/floor/dirt/underground
	name = "underground rock"
	icon = 'icons/turf/walls.dmi'
	icon_state = "rocky"
	uses_winter_overlay = FALSE
	may_become_muddy = TRUE
	available_dirt = 0
	is_diggable = FALSE
	is_mineable = TRUE
	opacity = TRUE
	density = TRUE
	desc = "This space is blocked off by soft earth and rocks. Can be digged."
	icon = 'icons/turf/walls.dmi'
	icon_state = "rocky"
	initial_flooring = null

/turf/floor/dirt/underground/empty
	name = "rock debris"
	icon_state = "rock_debris1"

/turf/floor/dirt/underground/empty/New()
	..()
	icon_state = "rock_debris[rand(1,2)]"

/turf/floor/dirt/ploughed
	name = "ploughed field"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt_ploughed"
	is_plowed = TRUE
	initial_flooring = null

/turf/floor/dirt/ploughed/flooded
	name = "ploughed field"
	icon = 'icons/turf/floors.dmi'
	icon_state = "flood_dirt_ploughed"
	is_plowed = TRUE
	initial_flooring = null

/turf/floor/dirt/dust
	name = "dry dirt"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dust"
	interior = FALSE
	stepsound = "dirt"
	available_dirt = 2
	may_become_muddy = FALSE
	is_diggable = TRUE
	initial_flooring = /decl/flooring/dust

/turf/floor/dirt/jungledirt
	name = "dirt"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt"
	interior = FALSE
	stepsound = "dirt"
	available_dirt = 2
	may_become_muddy = TRUE
	is_diggable = TRUE
	initial_flooring = /decl/flooring/dirt


/turf/floor/mining
	name = "minerals"
	icon = 'icons/turf/floors.dmi'
	icon_state = "minerals"
	interior = FALSE
	stepsound = "dirt"
	available_dirt = 2
	may_become_muddy = TRUE
	is_diggable = FALSE
	initial_flooring = null