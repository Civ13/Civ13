/obj/effect/spawner
	name = "object spawner"
	icon = 'icons/mob/screen/effects.dmi'
	var/max_range = 10
/obj/effect/spawner/ammospawner
	name = "ammo spawner"
	icon_state = "x3"
	var/create_path = /obj/item/ammo_casing/arrow
	var/max_amt = 1

/obj/effect/spawner/ammospawner/arrow/bronze
	name = "bronze arrow spawner"
	create_path = /obj/item/ammo_casing/arrow/bronze

/obj/effect/spawner/ammospawner/stone
	name = "stone projectile spawner"
	create_path = /obj/item/ammo_casing/stone

/obj/effect/spawner/ammospawner/tomahawk
	name = "tomahawk spawner"
	create_path = /obj/item/weapon/material/thrown/tomahawk

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
	var/create_path = /mob/living/simple_animal/hostile/human/skeleton
	var/timer = 400
	var/scalable = 0 // when 1, it will only get active above x players
	var/scalable_nr = 10
	var/scalable_multiplyer = 1 //after how many times the scalable_nr it activates
	var/spawning = FALSE
	invisibility = 101
	var/hostile = FALSE

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

/obj/effect/spawner/proc/getEmptyTurf()
	var/list/turf/emptyTurfs = new
	for(var/turf/T in range(max_range,src))
		var/invalid = FALSE
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
		if (istype(spawnedMob, /mob/living/simple_animal/hostile/bear))
			var/mob/living/simple_animal/hostile/bear/B = spawnedMob
			if (prob(50))
				B.female = TRUE
		else if (istype(spawnedMob, /mob/living/simple_animal/hostile/wolf))
			var/mob/living/simple_animal/hostile/wolf/W = spawnedMob
			if (prob(50))
				W.female = TRUE
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

/obj/effect/spawner/mobspawner/skeletons
	name = "skeleton spawner"
	create_path = /mob/living/simple_animal/hostile/human/skeleton
	timer = 400

/obj/effect/spawner/mobspawner/compsognathus
	name = "compsognathus spawner"
	create_path = /mob/living/simple_animal/hostile/dinosaur/compsognathus
	timer = 400

/obj/effect/spawner/mobspawner/dimetrodon
	name = "dimetrodon spawner"
	hostile = TRUE
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/dinosaur/dimetrodon
	timer = 1500

/obj/effect/spawner/mobspawner/pachycephalosaurus
	name = "pachycephalosaurus spawner"
	hostile = TRUE
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/dinosaur/pachycephalosaurus
	timer = 1500

/obj/effect/spawner/mobspawner/skeletons/off
	activated = FALSE

/obj/effect/spawner/mobspawner/attacker
	name = "attacking skeleton spawner"
	create_path = /mob/living/simple_animal/hostile/human/skeleton/attacker

/obj/effect/spawner/mobspawner/ww2
	timer = 300

/obj/effect/spawner/mobspawner/ww2/jap
	name = "jap spawner"
	create_path = /mob/living/simple_animal/hostile/human/ww2_jap

/obj/effect/spawner/mobspawner/ww2/american
	name = "american spawner"
	create_path = /mob/living/simple_animal/hostile/human/ww2_american
	max_number = 6
	max_range = 3

/obj/effect/spawner/mobspawner/ww2/american/mg
	name = "american spawner"
	create_path = /mob/living/simple_animal/hostile/human/ww2_american/mg
	max_number = 2
	max_range = 3

/obj/effect/spawner/mobspawner/ww2/american/medic
	name = "american spawner"
	create_path = /mob/living/simple_animal/hostile/human/ww2_american/medic
	max_number = 2
	max_range = 3

/obj/effect/spawner/mobspawner/ww2/american/lead
	name = "american spawner"
	create_path = /mob/living/simple_animal/hostile/human/ww2_american/squad_leader
	max_number = 1
	max_range = 2

/obj/effect/spawner/mobspawner/boars
	name = "boars spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/boar_boar
	timer = 3000

/obj/effect/spawner/mobspawner/boars_f
	name = "boar gilt spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/boar_gilt
	timer = 3000

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

/obj/effect/spawner/mobspawner/horse
	name = "horse spawner"
	max_number = 4
	max_range = 15
	create_path = /mob/living/simple_animal/horse
	timer = 3000

/obj/effect/spawner/mobspawner/horse/beige
	name = "beige horse spawner"
	max_number = 4
	max_range = 15
	create_path = /mob/living/simple_animal/horse/beige
	timer = 3000

/obj/effect/spawner/mobspawner/horse/black
	name = "beige horse spawner"
	max_number = 4
	max_range = 15
	create_path = /mob/living/simple_animal/horse/black
	timer = 3000

/obj/effect/spawner/mobspawner/horse/white
	name = "beige horse spawner"
	max_number = 4
	max_range = 15
	create_path = /mob/living/simple_animal/horse/white
	timer = 3000

/obj/effect/spawner/mobspawner/panthers
	name = "panther spawner"
	hostile = TRUE
	max_number = 1
	max_range = 12
	create_path = /mob/living/simple_animal/hostile/panther
	timer = 3000

/obj/effect/spawner/mobspawner/leech
	name = "leech spawner"
	max_number = 2
	max_range = 13
	create_path = /mob/living/simple_animal/leech
	timer = 3000

/obj/effect/spawner/mobspawner/lion
	name = "lion spawner"
	hostile = TRUE
	max_number = 2
	max_range = 13
	create_path = /mob/living/simple_animal/hostile/sabertooth/lion
	timer = 3000


/obj/effect/spawner/mobspawner/lizard
	name = "lizard spawner"
	max_number = 2
	max_range = 13
	create_path = /mob/living/simple_animal/lizard
	timer = 3000

/obj/effect/spawner/mobspawner/fox
	name = "fox spawner"
	hostile = TRUE
	max_number = 2
	max_range = 12
	create_path = /mob/living/simple_animal/hostile/fox
	timer = 3000

/obj/effect/spawner/mobspawner/fox/arctic
	name = "arctic fox spawner"
	create_path = /mob/living/simple_animal/hostile/fox/arctic

/obj/effect/spawner/mobspawner/panthers/jaguar
	name = "jaguar spawner"
	hostile = TRUE
	max_number = 1
	max_range = 12
	create_path = /mob/living/simple_animal/hostile/panther/jaguar
	timer = 3000

/obj/effect/spawner/mobspawner/bat
	name = "bat spawner"
	max_number = 4
	max_range = 5
	create_path = /mob/living/simple_animal/blackbat
	timer = 5000


/obj/effect/spawner/mobspawner/bison
	name = "bison cow spawner"
	hostile = TRUE
	max_number = 3
	max_range = 10
	create_path = /mob/living/simple_animal/bison
	timer = 3000

/obj/effect/spawner/mobspawner/bison/bull
	name = "bison bull spawner"
	hostile = TRUE
	max_number = 3
	max_range = 10
	create_path = /mob/living/simple_animal/bisonbull
	timer = 3000

/obj/effect/spawner/mobspawner/buffalo
	name = "buffalo spawner"
	hostile = TRUE
	max_number = 4
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/buffalo
	timer = 3000

/obj/effect/spawner/mobspawner/bears
	name = "black bear boar spawner"
	hostile = TRUE
	max_number = 1
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/boar/black
	timer = 3000

/obj/effect/spawner/mobspawner/bears_f
	name = "black bear sow spawner"
	hostile = TRUE
	max_number = 1
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/sow/black
	timer = 3000

/obj/effect/spawner/mobspawner/bears/brown
	name = "brown bear boar spawner"
	hostile = TRUE
	max_number = 1
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/boar/brown
	timer = 3000

/obj/effect/spawner/mobspawner/bears_f/brown
	name = "brown bear sow spawner"
	hostile = TRUE
	max_number = 1
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/sow/brown
	timer = 3000

/obj/effect/spawner/mobspawner/bears/polar
	name = "polar bear boar spawner"
	hostile = TRUE
	max_number = 1
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/boar/polar
	timer = 3000

/obj/effect/spawner/mobspawner/bears_f/polar
	name = "polar bear sow spawner"
	hostile = TRUE
	max_number = 1
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/bear/sow/polar
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

/obj/effect/spawner/mobspawner/gorilla
	name = "gorilla spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/gorilla
	timer = 5000

/obj/effect/spawner/mobspawner/gorilla/gigantopithecus
	name = "gigantopithecus spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/gorilla/gigantopithecus
	timer = 5000

/obj/effect/spawner/mobspawner/gorilla/gigantopithecus/bigfoot
	name = "bigfoot spawner"
	max_number = 1
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/gorilla/gigantopithecus/bigfoot
	timer = 7200

/obj/effect/spawner/mobspawner/gorilla/gigantopithecus/yeti
	name = "gigantopithecus spawner"
	max_number = 1
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/gorilla/gigantopithecus/yeti
	timer = 7200

/obj/effect/spawner/mobspawner/pirates
	name = "pirate spawner"
	create_path = /mob/living/simple_animal/hostile/human/voyage/pirate
	timer = 750

/obj/effect/spawner/mobspawner/british
	name = "redcoat spawner"
	max_number = 5
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/human/voyage/british
	timer = 750

/obj/effect/spawner/mobspawner/townmilitia
	name = "townmilitia spawner"
	max_number = 5
	max_range = 10
	create_path = /mob/living/simple_animal/hostile/human/townmilitia
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

/obj/effect/spawner/mobspawner/mouse/sm
	name = "small mouse spawner"
	max_number = 1
	max_range = 1
	create_path = /mob/living/simple_animal/mouse/gray
	timer = 3600
/obj/effect/spawner/mobspawner/snake
	name = "snake spawner"
	hostile = TRUE
	max_number = 1
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/poison/snake
	timer = 5000

/obj/effect/spawner/mobspawner/snake/cobra
	name = "cobra spawner"
	hostile = TRUE
	max_number = 1
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/poison/snake/cobra
	timer = 5000

/obj/effect/spawner/mobspawner/snake/boa
	name = "boa constrictor spawner"
	hostile = TRUE
	max_number = 1
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/poison/snake/constrictor
	timer = 8000

/obj/effect/spawner/mobspawner/snake/python
	name = "python constrictor spawner"
	hostile = TRUE
	max_number = 1
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/poison/snake/constrictor/python
	timer = 7000

/obj/effect/spawner/mobspawner/chicken
	name = "chicken spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/chicken
	timer = 5000

/obj/effect/spawner/mobspawner/chicken/rooster
	name = "rooster spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/rooster
	timer = 5000

/obj/effect/spawner/mobspawner/crab
	name = "crab spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/crab/small
	timer = 5000

/obj/effect/spawner/mobspawner/crab/trill
	name = "Trilobite spawner"
	max_number = 2
	max_range = 5
	create_path = /mob/living/simple_animal/crab/small/trilobite
	timer = 5000

/obj/effect/spawner/mobspawner/deer
	name = "deer spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer
	timer = 3000

/obj/effect/spawner/mobspawner/deer/male
	name = "stag spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/male
	timer = 3000

/obj/effect/spawner/mobspawner/deer/female
	name = "doe spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/female
	timer = 3000

/obj/effect/spawner/mobspawner/dikdik_m
	name = "dik-dik stag spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/dikdik/male
	timer = 3000

/obj/effect/spawner/mobspawner/dikdik_f
	name = "dik-dik doe spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/dikdik/female
	timer = 3000

/obj/effect/spawner/mobspawner/elk_m
	name = "elk stag spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/elk/male
	timer = 3000

/obj/effect/spawner/mobspawner/elk_f
	name = "elk doe spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/elk/female
	timer = 3000

/obj/effect/spawner/mobspawner/reindeer_m
	name = "reindeer stag spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/reindeer/male
	timer = 3000

/obj/effect/spawner/mobspawner/reindeer_f
	name = "reindeer doe spawner"
	max_number = 2
	max_range = 10
	create_path = /mob/living/simple_animal/deer/reindeer/female
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

/obj/effect/spawner/mobspawner/cattle
	name = "random cow and bulls spawner"
	icon = 'icons/mob/animal.dmi'
	icon_state = "cow_random"
	max_number = 2
	max_range = 8
	create_path = /mob/living/simple_animal/cattle
	timer = 5000

/obj/effect/spawner/mobspawner/cattle/cow
	name = "cattle cow spawner"
	icon_state = "cow_spawner"
	create_path = /mob/living/simple_animal/cattle/cow

/obj/effect/spawner/mobspawner/cattle/bull
	name = "cattle bull spawner"
	icon_state = "bull_spawner"
	create_path = /mob/living/simple_animal/cattle/bull

/obj/effect/spawner/mobspawner/pig
	name = "pig boar spawner"
	max_number = 2
	max_range = 8
	create_path = /mob/living/simple_animal/pig_boar
	timer = 5000

/obj/effect/spawner/mobspawner/pig/gilt
	name = "pig gilt spawner"
	max_number = 2
	max_range = 8
	create_path = /mob/living/simple_animal/pig_gilt
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
/obj/effect/spawner/mobspawner/trex
	name = "trex spawner"
	max_number = 1
	max_range = 8
	create_path = /mob/living/simple_animal/hostile/dinosaur/trex
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
/obj/effect/spawner/mobspawner/seagull
	name = "seagul spawner"
	max_number = 2
	max_range = 13
	create_path = /mob/living/simple_animal/seagull
	timer = 3000
/obj/effect/spawner/mobspawner/parrot
	name = "parrot spawner"
	max_number = 2
	max_range = 13
	create_path = /mob/living/simple_animal/parrot
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

/obj/effect/spawner/mobspawner/velociraptor/on
	activated = TRUE

/obj/effect/spawner/mobspawner/cockroach
	name = "cockroach spawner"
	max_number = 4
	max_range = 20
	create_path = /mob/living/simple_animal/cockroach
	timer = 3600

//only spawns after large amounts of radiation
/obj/effect/spawner/mobspawner/cockroach/nuclear
	max_number = 3
	timer = 3200

/obj/effect/spawner/mobspawner/cockroach/nuclear/spawnerproc()

	if (global_radiation > 190)
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

/obj/effect/spawner/mobspawner/zombies
	name = "zombie spawner"
	hostile = TRUE
	max_number = 10
	max_range = 5
	create_path = /mob/living/simple_animal/hostile/human/zombie
	timer = 1000

/obj/effect/spawner/mobspawner/zombies/many
	max_number = 8
	max_range = 7
	timer = 300

/obj/effect/spawner/mobspawner/zombies/special
	activated = FALSE
	max_range = 9
	max_number = 14
	timer = 600

/obj/effect/spawner/mobspawner/voyage/brit/sword
	name = "brit spawner"
	hostile = TRUE
	max_number = 10
	max_range = 8
	create_path = /mob/living/simple_animal/hostile/human/voyage/british
	timer = 300


/obj/effect/spawner/mobspawner/voyage/brit/ranged
	name = "ranged brit spawner"
	hostile = TRUE
	max_number = 10
	max_range = 3
	create_path = /mob/living/simple_animal/hostile/human/voyage/british/ranged
	timer = 300

/obj/effect/spawner/mobspawner/zombies/special/getEmptyTurf()
	var/list/turf/emptyTurfs = new
	for(var/turf/T in range(max_range,src))
		var/invalid = FALSE
		if (istype(T, /turf/wall) || istype(T, /turf/floor/dirt/underground) || istype (T, /turf/floor/beach/water))
			invalid = TRUE
		for(var/obj/structure/OB in T)
			invalid = TRUE
		for(var/obj/covers/OB in T)
			invalid = TRUE
		for(var/mob/living/human/OB in view(4,T))
			if (OB.stat != DEAD)
				invalid = TRUE
		if (!invalid)
			emptyTurfs += T
	if (emptyTurfs.len)
		return pick(emptyTurfs)
////////////////////OBJ SPAWNER///////////
/obj/effect/spawner/objspawner
	name = "obj spawner"
	icon_state = "x1"
	var/activated = 1
	var/max_number = 35
	max_range = 7
	var/create_path = /obj/structure/wild/tree/live_tree
	var/timer = 6000
	var/spawning = FALSE
	invisibility = 101

/obj/effect/spawner/objspawner/New()
	..()
	invisibility = 101
	icon_state = "invisible"
	spawnerproc()

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
	create_path = /obj/structure/wild/tree/live_tree

/obj/effect/spawner/objspawner/tree/snow
	name = "snow tree spawner"
	create_path = /obj/structure/wild/tree/live_tree/snow


/obj/effect/spawner/objspawner/pine
	name = "pinetree spawner"
	create_path = /obj/structure/wild/tree/live_tree/pine

/obj/effect/spawner/objspawner/palm
	name = "palm spawner"
	max_number = 13
	create_path = /obj/structure/wild/palm

/obj/effect/spawner/objspawner/jungle
	name = "jungle tree spawner"
	max_number = 26
	create_path = /obj/structure/wild/jungle

/obj/effect/spawner/objspawner/bamboo
	name = "bamboo spawner"
	max_number = 16
	create_path = /obj/structure/wild/bamboo

/obj/effect/spawner/objspawner/acacia
	name = "acacia tree spawner"
	max_number = 10
	create_path = /obj/structure/wild/jungle/acacia
	timer = 7500

/obj/effect/spawner/objspawner/medpine
	name = "mediterranean pine tree spawner"
	icon_state = "x1"
	max_number = 18
	max_range = 13
	create_path = /obj/structure/wild/jungle/medpine
	timer = 6000

/obj/effect/spawner/objspawner/chinchona
	name = "chinchona spawner"
	max_number = 3
	max_range = 14
	create_path = /obj/structure/wild/junglebush/chinchona
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
