/obj/effect/spawner
	name = "object spawner"
	icon = 'icons/mob/screen/effects.dmi'

/obj/effect/spawner/ammospawner
	name = "ammo spawner"
	icon_state = "x3"
	var/create_path = /obj/item/ammo_casing/arrow
	var/max_amt = 1

/obj/effect/spawner/ammospawner/arrow
	name = "arrow spawner"
	create_path = /obj/item/ammo_casing/arrow

/obj/effect/spawner/ammospawner/stone
	name = "stone projectile spawner"
	create_path = /obj/item/ammo_casing/stone

/obj/effect/spawner/ammospawner/New()
	..()
	invisibility = 101
	spawnerproc()

/obj/effect/spawner/ammospawner/proc/spawnerproc()
	if (!src)
		return

	var/count = 0
	for (var/obj/O in src.loc)
		if (istype(O, create_path))
			count++
	if (count < max_amt)
		new create_path(src.loc)
	spawn(50)
		spawnerproc()

/obj/effect/spawner/objective_spawner
	name = "objective spawner"
	icon_state = "x2"
	var/activated = 1
	var/hostile = FALSE

/obj/effect/spawner/objective_spawner/New()
	..()
	invisibility = 101
	spawnerproc()

/obj/effect/spawner/objective_spawner/proc/spawnerproc()
	if (activated)
		spawn(100)
			var/obj/item/cursedtreasure/targetobjective = new/obj/item/cursedtreasure(src.loc)
			var/locationtomove = pick(latejoin_turfs["treasure-mark"])
			targetobjective.loc = locationtomove
			world.log << "DEBUG: Created treasure at [targetobjective.x], [targetobjective.y]"
			activated = 0
			qdel(src)
			return

/obj/effect/spawner/mobspawner
	name = "mob spawner"
	icon_state = "x2"
	var/activated = 1
	var/current_number = 0
	var/max_number = 10
	var/max_range = 10
	var/create_path = /mob/living/simple_animal/hostile/skeleton
	var/timer = 400
	var/scalable = 0 // when 1, it will only get active above x players
	var/scalable_nr = 10
	var/scalable_multiplyer = 1 //after how many times the scalable_nr it activates
	var/spawning = FALSE
	invisibility = 101
	var/hostile = FALSE

/obj/effect/spawner/mobspawner/skeletons
	name = "skeleton spawner"
	create_path = /mob/living/simple_animal/hostile/skeleton
	timer = 400

/obj/effect/spawner/mobspawner/skeletons/off
	activated = FALSE

/obj/effect/spawner/mobspawner/attacker
	name = "attacking skeleton spawner"
	create_path = /mob/living/simple_animal/hostile/skeleton/attacker

/obj/effect/spawner/mobspawner/New()
	..()
	invisibility = 101
	icon_state = "invisible"
	spawnerproc()

/obj/effect/spawner/mobspawner/proc/buff()
	if (map.chad_mode)
		if (hostile)
			max_number *= 2
		if (istype(src, /obj/effect/spawner/mobspawner/velociraptor))
			activated = 1

/obj/effect/spawner/mobspawner/proc/getEmptyTurf()
	var/nearbyObjects = range(max_range,src)
	var/list/turf/emptyTurfs = new
	var/invalid = FALSE
	for(var/turf/T in nearbyObjects)
		if (istype(T, /turf/wall) || istype(T, /turf/floor/dirt/underground) || istype (T, /turf/floor/beach/water))
			invalid = TRUE
		for(var/obj/structure/OB in T)
			invalid = TRUE
		for(var/obj/covers/OB in T)
			invalid = TRUE
		if (!invalid)
			emptyTurfs += T
	if (emptyTurfs.len)
		return pick(emptyTurfs)

/obj/effect/spawner/mobspawner/proc/spawnTarget()
	var/turf/emptyTurf = getEmptyTurf()
	if (emptyTurf)
		var/mob/living/simple_animal/spawnedMob = new create_path(emptyTurf)
		spawnedMob.origin = src
		current_number++

/obj/effect/spawner/mobspawner/proc/spawnerproc()

	if ((current_number < max_number) && (scalable == 0 || (clients.len > (scalable_nr*scalable_multiplyer))))
		spawning = TRUE
	if (current_number < 0)
		current_number = 0
	if (activated)
		if (spawning == TRUE)
			spawning = FALSE
			spawnTarget()

	spawn(rand(timer,timer*1.5))
		spawnerproc()

/obj/effect/spawner/mobspawner/turkeys
	name = "turkey spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/turkey_m
	timer = 3000

/obj/effect/spawner/mobspawner/turkeys_f
	name = "turkey spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/turkey_f
	timer = 3000

/obj/effect/spawner/mobspawner/panthers
	name = "panther spawner"
	hostile = TRUE
	max_number = 1
	max_range = 12
	create_path = /mob/living/simple_animal/hostile/panther
	timer = 3000

/obj/effect/spawner/mobspawner/panthers/jaguar
	name = "jaguar spawner"
	hostile = TRUE
	max_number = 1
	max_range = 12
	create_path = /mob/living/simple_animal/hostile/panther/jaguar
	timer = 3000


/obj/effect/spawner/mobspawner/bears
	name = "bear spawner"
	hostile = TRUE
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear
	timer = 3000

/obj/effect/spawner/mobspawner/bears/brown
	name = "brown bear spawner"
	hostile = TRUE
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/brown
	timer = 3000

/obj/effect/spawner/mobspawner/bears/polar
	name = "polar bear spawner"
	hostile = TRUE
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/polar
	timer = 3000

/obj/effect/spawner/mobspawner/bears/brown
	name = "brown bear spawner"
	hostile = TRUE
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/brown
	timer = 3000

/obj/effect/spawner/mobspawner/groundsloth
	name = "ground sloth spawner"
	hostile = TRUE
	max_number = 1
	max_range = 7
	create_path = /mob/living/simple_animal/hostile/groundsloth
	timer = 6000

/obj/effect/spawner/mobspawner/monkeys
	name = "monkey spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/monkey
	timer = 3000

/obj/effect/spawner/mobspawner/pirates
	name = "pirate spawner"
	create_path = /mob/living/simple_animal/hostile/pirate
	timer = 750

/obj/effect/spawner/mobspawner/british
	name = "redcoat spawner"
	max_number = 5
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/british
	timer = 750

/obj/effect/spawner/mobspawner/townmilitia
	name = "townmilitia spawner"
	max_number = 5
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/townmilitia
	timer = 750

/obj/effect/spawner/mobspawner/frogpoisonous
	name = "poisonous frog spawner"
	hostile = TRUE
	max_number = 1
	max_range = 12
	create_path = /mob/living/simple_animal/frog/poisonous
	timer = 4800

/obj/effect/spawner/mobspawner/frog
	name = "frog spawner"
	hostile = TRUE
	max_number = 4
	max_range = 12
	create_path = /mob/living/simple_animal/frog
	timer = 4800

/obj/effect/spawner/mobspawner/mouse
	name = "mouse spawner"
	max_number = 2
	max_range = 12
	create_path = /mob/living/simple_animal/mouse/gray
	timer = 3600

/obj/effect/spawner/mobspawner/snake
	name = "snake spawner"
	hostile = TRUE
	max_number = 1
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/poison/snake
	timer = 5000

/obj/effect/spawner/mobspawner/crab
	name = "crab spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/crab/small
	timer = 5000

/obj/effect/spawner/mobspawner/deer_m
	name = "stag spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/male
	timer = 3000

/obj/effect/spawner/mobspawner/deer_f
	name = "doe spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/female
	timer = 3000
/obj/effect/spawner/mobspawner/elk_m
	name = "elk stag spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/elk/male
	timer = 3000

/obj/effect/spawner/mobspawner/elk_f
	name = "elk doe spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/elk/male
	timer = 3000

/obj/effect/spawner/mobspawner/reindeer_m
	name = "reindeer stag spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/reindeer/male
	timer = 3000

/obj/effect/spawner/mobspawner/reindeer_f
	name = "reindeer doe spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/reindeer/female
	timer = 3000

/obj/effect/spawner/mobspawner/alligator
	name = "alligator spawner"
	hostile = TRUE
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/alligator
	timer = 5000

/obj/effect/spawner/mobspawner/goats_m
	name = "male goat spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/goat
	timer = 5000

/obj/effect/spawner/mobspawner/goats_f
	name = "female goat spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/goat/female
	timer = 5000

/obj/effect/spawner/mobspawner/sheep_m
	name = "male sheep spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/sheep
	timer = 5000

/obj/effect/spawner/mobspawner/sheep_f
	name = "female sheep spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/sheep/female
	timer = 5000

/obj/effect/spawner/mobspawner/camel
	name = "camel spawner"
	max_number = 2
	max_range = 8
	create_path = /mob/living/simple_animal/camel
	timer = 5000

/obj/effect/spawner/mobspawner/wolves
	name = "wolf spawner"
	hostile = TRUE
	max_number = 4
	max_range = 8
	create_path = /mob/living/simple_animal/hostile/wolf
	timer = 3000

/obj/effect/spawner/mobspawner/wolves/white
	name = "white wolf spawner"
	hostile = TRUE
	max_number = 4
	max_range = 8
	create_path = /mob/living/simple_animal/hostile/wolf/white
	timer = 3000

/obj/effect/spawner/mobspawner/mammoth
	name = "mammoth spawner"
	max_number = 1
	max_range = 11
	create_path = /mob/living/simple_animal/hostile/mammoth
	timer = 7200
/obj/effect/spawner/mobspawner/troll
	name = "troll spawner"
	max_number = 1
	max_range = 11
	create_path = /mob/living/simple_animal/hostile/troll
	timer = 7200
/obj/effect/spawner/mobspawner/penguins
	name = "penguin spawner"
	max_number = 2
	max_range = 13
	create_path = /mob/living/simple_animal/penguin
	timer = 3000

/obj/effect/spawner/mobspawner/rabbits
	name = "rabbit spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/rabbit
	timer = 3000

/obj/effect/spawner/mobspawner/velociraptor
	name = "raptor spawner"
	hostile = TRUE
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/dinosaur/velociraptor
	timer = 3000
	activated = 0

////////////////////OBJ SPAWNER///////////
/obj/effect/spawner/objspawner
	name = "obj spawner"
	icon_state = "x1"
	var/activated = 1
	var/max_number = 35
	var/max_range = 13
	var/create_path = /obj/structure/wild/tree/live_tree
	var/timer = 6000
	var/spawning = FALSE
	invisibility = 101

/obj/effect/spawner/objspawner/New()
	..()
	invisibility = 101
	icon_state = "invisible"
	spawnerproc()

/obj/effect/spawner/objspawner/proc/getEmptyTurf()
	var/nearbyObjects = range(max_range,src)
	var/list/turf/emptyTurfs = new
	var/invalid = FALSE
	for(var/turf/T in nearbyObjects)
		if (istype(T, /turf/wall) || istype(T, /turf/floor/dirt/underground) || istype (T, /turf/floor/beach/water))
			invalid = TRUE
		for(var/obj/structure/OB in T)
			invalid = TRUE
		for(var/obj/covers/OB in T)
			invalid = TRUE
		if (!invalid)
			emptyTurfs += T
	if (emptyTurfs.len)
		return pick(emptyTurfs)

/obj/effect/spawner/objspawner/proc/getCurrent()
	var/count = 0
	for (var/obj/O in range(max_range,src))
		if (istype(O, create_path))
			count++
	if (count < max_number)
		return TRUE
	else
		return FALSE
/obj/effect/spawner/objspawner/proc/spawnTarget()
	var/turf/emptyTurf = getEmptyTurf()
	if (emptyTurf)
		new create_path(emptyTurf)

/obj/effect/spawner/objspawner/proc/spawnerproc()

	if (getCurrent() == TRUE)
		spawning = TRUE
	if (activated)
		if (spawning == TRUE)
			spawning = FALSE
			spawnTarget()

	spawn(rand(timer,timer*1.5))
		spawnerproc()


/obj/effect/spawner/objspawner/tree
	name = "tree spawner"
	icon_state = "x1"
	max_number = 35
	max_range = 13
	create_path = /obj/structure/wild/tree/live_tree
	timer = 6000

/obj/effect/spawner/objspawner/palm
	name = "palm spawner"
	icon_state = "x1"
	max_number = 13
	max_range = 13
	create_path = /obj/structure/wild/palm
	timer = 6000

/obj/effect/spawner/objspawner/jungle
	name = "jungle tree spawner"
	icon_state = "x1"
	max_number = 26
	max_range = 13
	create_path = /obj/structure/wild/jungle
	timer = 6000

/obj/effect/spawner/objspawner/acacia
	name = "acacia tree spawner"
	icon_state = "x1"
	max_number = 10
	max_range = 13
	create_path = /obj/structure/wild/jungle/acacia
	timer = 7500

/obj/effect/spawner/objspawner/medpine
	name = "mediterranean pine tree spawner"
	icon_state = "x1"
	max_number = 18
	max_range = 13
	create_path = /obj/structure/wild/jungle/medpine
	timer = 6000

//ore spanwers for extended games
/obj/effect/spawner/orespawner
	name = "ore spawner"
	icon_state = "x1"
	var/active = FALSE
/obj/effect/spawner/orespawner/New()
	..()
	invisibility = 101
	icon_state = "invisible"

/obj/effect/spawner/orespawner/proc/do_spawn()
	var/turf/sourceturf = get_turf(src)
	if (active)
		if (!istype(sourceturf, /turf/floor/dirt) || istype(sourceturf, /turf/floor/dirt/underground))
			return
		else
			sourceturf.ChangeTurf(/turf/floor/mining)
			return
	else
		if (istype(sourceturf, /turf/floor/dirt))
			return
		else
			sourceturf.ChangeTurf(/turf/floor/dirt)
			return
		return