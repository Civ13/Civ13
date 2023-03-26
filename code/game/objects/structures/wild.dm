var/list/seed_list
var/list/seed_list_sea
var/list/seed_list_temperate
var/list/seed_list_tundra
var/list/seed_list_taiga
var/list/seed_list_desert
var/list/seed_list_semiarid
var/list/seed_list_savanna
var/list/seed_list_jungle

/obj/structure/wild
	icon = 'icons/obj/flora/wild.dmi'
	icon_state = "tree"
	var/deadicon = "icons/obj/flora/wild.dmi"//Rad stuff what to turn into
	var/deadicon_state = "burnedtree1"//Rad stuff what to turn into
	anchored = TRUE
	var/sways = FALSE
	var/amount = 0 //how much wood to drop. 0 = none
	var/health = 100
	var/maxhealth = 100
	layer = 3.2
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/seedtimer = 1
	var/mob/living/human/stored_unit = null
	var/edible = FALSE
	var/leaves = 0
	var/max_leaves = 0
	var/branches = 0
	var/max_branches = 0

/obj/structure/wild/proc/grow_branch()
	if (max_branches <= 0)
		return
	spawn(12000)
		if (src && branches < max_branches)
			branches = min(branches+1, max_branches)
		return

/obj/structure/wild/proc/seedtimer_proc()
	spawn(6000)
		seedtimer = 1
		return

/obj/structure/wild/proc/generate_seed_list(var/biome)
	//generate seed list for empty list, called once per first empty entry in pick_seed_by_biome()
	var/list/s_list
	var/obj/item/stack/farming/seeds/seed_check
	s_list = typesof(/obj/item/stack/farming/seeds)
	s_list -= /obj/item/stack/farming/seeds
	s_list -= /obj/item/stack/farming/seeds/herbs //Technically it's not a seed
	if (biome)
		for (var/S in s_list)
			seed_check = new S
			if (!(biome in seed_check.biomes))
				s_list -= S
			qdel(seed_check)
	switch (biome)
		if ("sea")				seed_list_sea = s_list
		if ("temperate")		seed_list_temperate = s_list
		if ("tundra")			seed_list_tundra = s_list
		if ("taiga")			seed_list_taiga = s_list
		if ("desert")			seed_list_desert = s_list
		if ("semiarid")			seed_list_semiarid = s_list
		if ("savanna")			seed_list_savanna = s_list
		if ("jungle")			seed_list_jungle = s_list
		else 					seed_list = s_list

/obj/structure/wild/proc/pick_seed_by_biome(var/biome = "")
	biome = ckey(biome)
	switch (biome)
		if ("sea")
			if (!seed_list_sea)
				generate_seed_list(biome)
			return pick(seed_list_sea)
		if ("temperate")
			if (!seed_list_temperate)
				generate_seed_list(biome)
			return pick(seed_list_temperate)
		if ("tundra")
			if (!seed_list_tundra)
				generate_seed_list(biome)
			return pick(seed_list_tundra)
		if ("taiga")
			if (!seed_list_taiga)
				generate_seed_list(biome)
			return pick(seed_list_taiga)
		if ("desert")
			if (!seed_list_desert)
				generate_seed_list(biome)
			return pick(seed_list_desert)
		if ("semiarid")
			if (!seed_list_semiarid)
				generate_seed_list(biome)
			return pick(seed_list_semiarid)
		if ("savanna")
			if (!seed_list_savanna)
				generate_seed_list(biome)
			return pick(seed_list_savanna)
		if ("jungle")
			if (!seed_list_jungle)
				generate_seed_list(biome)
			return pick(seed_list_jungle)
		else
			if (!seed_list)
				generate_seed_list(biome)
			return pick(seed_list)

/obj/structure/wild/proc/pickseed()
	var/area/caribbean/A = get_area(get_turf(src))
	if (!A)
		return
	if (map.ID != MAP_NOMADS_PANGEA && map.ID != MAP_NOMADS_CONTINENTAL && map.ID != MAP_NOMADS_NEW_WORLD && map.ID != MAP_NOMADS_MEDITERRANEAN)
		return pick_seed_by_biome()
	else
		return pick_seed_by_biome(A.climate)

/obj/structure/wild/Destroy()
	if (amount > 0)
		var/obj/item/stack/material/wood/wooddrop = new /obj/item/stack/material/wood
		wooddrop.amount = amount
	for (var/obj/o in get_turf(src))
		if (o.special_id == "seasons")
			qdel(o)
	..()

/obj/structure/wild/fire_act(temperature)
	if (prob(35 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

// it's windy out
/obj/structure/wild/proc/sway()
	if (!sways)
		return
	icon_state = "[initial(icon_state)]_swaying_[pick("left", "right")]"

/obj/structure/wild/CanPass(var/atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (prob(75) && density)
			visible_message("<span class = 'warning'>The [mover.name] hits \the [src]!</span>")
			return FALSE
		else
			return TRUE
	else
		return ..()

/obj/structure/wild/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if (istype(W,/obj/item/weapon/material/hatchet) ||istype(W,/obj/item/weapon/material/boarding_axe) || istype(W,/obj/item/weapon/material/machete) || istype(W,/obj/item/weapon/material/machete1) || istype(W,/obj/item/weapon/material/twohanded/fireaxe) || istype(W,/obj/item/weapon/material/sword/kukri) || istype(W,/obj/item/weapon/material/sword/bolo) || istype(W,/obj/item/weapon/material/thrown/tomahawk) || istype(W,/obj/item/weapon/material/thrown/throwing_axe))
		var/obj/item/weapon/material/HT = W
		visible_message("<span class='danger'>[user] begins to chop down \the [src]!</span>")
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		if (do_after(user, 30*HT.chopping_speed, user.loc))
			health = 0
			try_destroy()
			HT.health = HT.health - 0.25
			if (HT.health <=0)
				HT.shatter()
			if (istype(user, /mob/living/human))
				var/mob/living/human/H = user
				H.adaptStat("strength", 1)
			return
	else
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				if (istype (W, /obj/item/projectile))
					health -= W.force * 0.2
				else
					health -= W.force * 0.20
	playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/wild/proc/try_destroy()
	if (health <= 0)
		if (stored_unit)
			release_stored()
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		qdel(src)
		return

/obj/structure/wild/bullet_act(var/obj/item/projectile/proj)
	if (proj.damage > 200 && prob(33)) // makes shrapnel unable to take down trees
		visible_message("<span class = 'danger'>[src] collapses!</span>")
		qdel(src)
	else if (istype(proj, /obj/item/projectile/shell))
		visible_message("<span class = 'danger'>[src] is blown up!</span>")
		qdel(src)

///////////////////////Trees////////////////////////////

/obj/structure/wild/tree
	name = "small tree"
	icon_state = "tree"
	deadicon = "icons/obj/flora/wild.dmi"
	deadicon_state = "deadtree"
	opacity = TRUE
	density = TRUE
	sways = TRUE
	amount = 5
	layer = 5.11

/obj/structure/wild/tree/anchored

/obj/structure/wild/tree/New()
	..()
	if (!istype(src, /obj/structure/wild/tree/anchored))
		pixel_x = rand(-24,-8)
		pixel_y = rand(0,16)

/obj/structure/wild/tree/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		health -= 10
		visible_message("<span class='danger'>[user] tries to chop down \the [src]!</span>")
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
	else
		..()

/obj/structure/wild/tree/cactus
	name = "cactus"
	icon = 'icons/obj/flora/bigtrees.dmi'
	icon_state = "cactus"
	deadicon = 'icons/obj/flora/bigtrees.dmi'
	deadicon_state = "none"
	sways = TRUE
	amount = 0
	health = 50
	maxhealth = 50
	pixel_x = -16

/obj/structure/wild/tree/dead_tree
	name = "dead tree"
	icon = 'icons/obj/flora/deadtrees.dmi'
	icon_state = "tree_1"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "tree_1"
	sways = FALSE
	amount = 5
	branches = 3
	max_branches = 3
	leaves = 0
	pixel_x = -16

/obj/structure/wild/tree/dead_tree/destroyed/New()
	..()
	icon_state = "tree_[rand(1,5)]"

/obj/structure/wild/tree/dead_tree/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = rand(4,7)
		qdel(src)
		return

/obj/structure/wild/tree/dead_tree/destroyed
	name = "destroyed tree"
	icon = 'icons/obj/flora/destroyedtrees.dmi'
	icon_state = "1"
	deadicon = 'icons/obj/flora/destroyedtrees.dmi'
	deadicon_state = "1"
	opacity = FALSE
	sways = FALSE
	amount = 2
	branches = 0
	max_branches = 3
	leaves = 0

/obj/structure/wild/tree/dead_tree/destroyed/New()
	..()
	icon_state = "[rand(1,7)]"

/obj/structure/wild/tree/live_tree
	name = "tree"
	icon = 'icons/obj/flora/bigtrees.dmi'
	icon_state = "tree_1"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "tree_1"
	sways = FALSE
	edible = TRUE
	leaves = 2
	max_leaves = 2
	branches = 3
	max_branches = 3
	pixel_x = -16
	var/current_icon = 'icons/obj/flora/deadtrees.dmi'

/obj/structure/wild/tree/live_tree/New()
	..()
	icon_state = "tree_[rand(1,5)]"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = icon_state

/obj/structure/wild/tree/live_tree/update_icon()
	..()
	if (radiation >= 15)
		icon = deadicon
		icon_state = deadicon_state
		return
	else
		icon = current_icon

/obj/structure/wild/tree/live_tree/proc/change_season()
	..()
	if (radiation >= 15)
		icon = deadicon
		icon_state = deadicon_state
		return
	else
		if (season == "WINTER")
			current_icon = 'icons/obj/flora/bigtrees_winter.dmi'
		else if (season in list("SUMMER","Wet Season"))
			current_icon = 'icons/obj/flora/bigtrees.dmi'
		else if (season in list("FALL","SPRING","Dry Season"))
			if (prob(50))
				current_icon = 'icons/obj/flora/deadtrees.dmi'
			else
				current_icon = 'icons/obj/flora/bigtrees.dmi'
		update_icon()

/obj/structure/wild/tree/live_tree/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = 7
		if (leaves>0)
			new/obj/item/stack/material/leaf(get_turf(src))
			new/obj/item/stack/material/leaf(get_turf(src))
			new/obj/item/stack/material/leaf(get_turf(src))
		qdel(src)
		return

/obj/structure/wild/tree/live_tree/snow
	name = "tree"
	icon = 'icons/obj/flora/bigtrees_winter.dmi'
	icon_state = "tree_1"
	deadicon = 'icons/obj/flora/deadtrees_winter.dmi'
	deadicon_state = "tree_1"
	sways = FALSE
	amount = 5
	edible = FALSE
	leaves = 0
	max_leaves = 0
	branches = 3
	max_branches = 3
	current_icon = 'icons/obj/flora/bigtrees_winter.dmi'

/obj/structure/wild/tree/live_tree/snow/update_icon()
	..()
	icon_state = "tree_[rand(1,6)]"
	deadicon = 'icons/obj/flora/bigtrees_winter.dmi'

/obj/structure/wild/tree/live_tree/pine
	name = "pinetree"
	icon = 'icons/obj/flora/pinetrees.dmi'
	icon_state = "pine_1"
	deadicon = 'icons/obj/flora/pinetrees_dead.dmi'
	deadicon_state = "pine_1"
	sways = FALSE
	amount = 5
	edible = TRUE
	leaves = 2
	max_leaves = 2
	branches = 3
	max_branches = 3
	current_icon = 'icons/obj/flora/pinetrees.dmi'

/obj/structure/wild/tree/live_tree/pine/New()
	..()
	icon_state = "pine_[rand(1,3)]"
	deadicon = 'icons/obj/flora/pinetrees_dead.dmi'
	if (map.ID == MAP_HUNGERGAMES)
		spawn(6000)
			if(prob(75))
				qdel(src)
			else
				return

/obj/structure/wild/tree/live_tree/pine/update_icon()
	..()
	if (radiation >= 15)
		icon = deadicon
		return
	else
		icon = current_icon


/obj/structure/wild/tree/live_tree/pine/change_season()
	..()
	if (radiation >= 15)
		icon = deadicon
		return
	else
		if (season == "WINTER")
			current_icon = 'icons/obj/flora/pinetrees_snow.dmi'
		else if (season in list("SUMMER","Wet Season"))
			current_icon = 'icons/obj/flora/pinetrees.dmi'
		else if (season in list("FALL","SPRING","Dry Season"))
			current_icon = 'icons/obj/flora/pinetrees.dmi'
		update_icon()


/obj/structure/wild/tree/live_tree/pine/snow
	name = "pinetree"
	icon = 'icons/obj/flora/pinetrees_snow.dmi'
	icon_state = "pine_1"
	sways = FALSE
	amount = 5
	edible = FALSE
	leaves = 0
	max_leaves = 0
	branches = 3
	max_branches = 3
	current_icon = 'icons/obj/flora/pinetrees_snow.dmi'

/obj/structure/wild/tree/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

///////////////////////Palm Tree////////////////////////////

/obj/structure/wild/palm
	name = "palm tree"
	icon = 'icons/misc/beach2.dmi'
	icon_state = "palm1"
	deadicon = 'icons/misc/beach2.dmi'
	deadicon_state = "dead_palm1"
	sways = FALSE
	amount = 4
	var/cooldown_sap = FALSE
	layer = 5.11
	edible = FALSE
	leaves = 0
	max_leaves = 0
	branches = 0
	max_branches = 0

/obj/structure/wild/palm/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W,/obj/item/weapon/material/kitchen/utensil/knife) && user.a_intent == I_HELP)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (!istype(user.l_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot) && !istype(user.r_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot))
			user << "<span class = 'warning'>You need to have a pot in one of your hands in order to extract palm sap.</span>"
			return
		else
			var/done = FALSE
			if (cooldown_sap == TRUE)
				user << "Sap was extracted from this palm recently, you need to wait before collecting it again."
				return
			if (istype(user.l_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot) && cooldown_sap == FALSE)
				user << "You start extracting the palm sap..."
				if (do_after(user, 50, user.loc) && done == FALSE)
					user << "You finish extracting the palm sap."
					qdel(user.l_hand)
					new/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot/palmsap(user.loc)
					cooldown_sap = TRUE
					spawn(3000)
						cooldown_sap = FALSE
				done = TRUE
			else if (istype(user.r_hand, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot) && cooldown_sap == FALSE)
				user << "You start extracting the palm sap..."
				if (do_after(user, 50, user.loc) && done == FALSE)
					user << "You finish extracting the palm sap."
					qdel(user.r_hand)
					new/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/tribalpot/palmsap(user.loc)
					cooldown_sap = TRUE
					spawn(3000)
						cooldown_sap = FALSE
				done = TRUE
	else
		..()

/obj/structure/wild/palm/fire_act(temperature)
	if (prob(45 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

/obj/structure/wild/tree/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = 4
		qdel(src)
		return

/obj/structure/wild/palm/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = 3
		new/obj/item/stack/material/leaf/palm(get_turf(src))
		new/obj/item/stack/material/leaf/palm(get_turf(src))
		new/obj/item/stack/material/leaf/palm(get_turf(src))
		qdel(src)
		return

/obj/structure/wild/palm/New()
	..()
	icon_state = pick("palm1","palm2")
	deadicon = 'icons/misc/beach2.dmi'
	deadicon_state = "dead_[icon_state]"

///////////////////////Bushes////////////////////////////

/obj/structure/wild/bush
	name = "bush"
	icon_state = "small_bush"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "burnedbush1"
	opacity = FALSE
	density = FALSE
	health = 40
	maxhealth = 40

/obj/structure/wild/bush/fire_act(temperature)
	if (prob(55 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		if (prob(18))
			new/obj/structure/wild/burnedbush(src.loc)
		qdel(src)

/obj/structure/wild/bush/big
	name = "large bush"
	icon_state = "big_bush"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "burnedbush2"

/obj/structure/wild/burnedbush
	name = "dead twigs"
	icon_state = "burnedbush1"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "burnedbush1"
	opacity = FALSE
	density = FALSE
	flammable = FALSE
	health = 20
	maxhealth = 20

/obj/structure/wild/junglebush
	name = "small vegetation"
	icon = 'icons/obj/flora/jungleflora.dmi'
	icon_state = "1"
	deadicon = 'icons/obj/flora/dead_jungleflora.dmi'
	deadicon_state = "1"
	opacity = FALSE
	density = FALSE
	health = 60
	maxhealth = 60
	edible = TRUE
	leaves = 2
	max_leaves = 2
	var/healthamount = 1

/obj/structure/wild/junglebush/fire_act(temperature)
	if (prob(55 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

/obj/structure/wild/smallbush
	name = "small bush"
	icon = 'icons/obj/flora/ausflora.dmi'
	icon_state = "smallbush1"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "burnedbush1"
	opacity = FALSE
	density = FALSE
	health = 20
	maxhealth = 20

/obj/structure/wild/smallbush/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if(istype(W,/obj/item/weapon/material/kitchen/utensil/knife) && user.a_intent == I_HELP)
		user.do_attack_animation(src)
		if (seedtimer == 1)
			user << "You harvest some seeds."
			var/obj/item/stack/farming/seeds/NS = pickseed()
			new NS(get_turf(user))
			seedtimer = 0
			seedtimer_proc()
		else
			user << "There are no seeds to collect here."
	else
		..()

/obj/structure/wild/smallbush/fire_act(temperature)
	if (prob(65 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

/obj/structure/wild/smallbush/New()
	..()
	icon_state = "smallbush[rand(1,42)]"

/obj/structure/wild/smallbush/winter
	name = "small bush"
	icon = 'icons/obj/flora/snowflora.dmi'
	icon_state = "snowgrass1"
	opacity = FALSE
	density = FALSE
	health = 20
	maxhealth = 20

/obj/structure/wild/smallbush/winter/fire_act(temperature)
	if (prob(15 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

/obj/structure/wild/smallbush/winter/New()
	..()
	if (prob(65))
		icon_state = "snowgrass[rand(1,9)]"
	else
		icon_state = "snowbush[rand(1,6)]"

/obj/structure/wild/burnedtree
	name = "burned tree"
	icon_state = "burnedtree1"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "burnedtree1"
	opacity = FALSE
	density = FALSE
	flammable = FALSE
	health = 20
	maxhealth = 20

/obj/structure/wild/burnedtree/New()
	..()
	icon_state = "burnedtree[rand(1,5)]"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "burnedtree[rand(1,5)]"

/obj/structure/wild/tree_stump
	name = "tree stump"
	icon_state = "tree_stump"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "tree_stump"
	opacity = FALSE
	density = FALSE
	flammable = FALSE
	health = 50
	maxhealth = 50

/obj/structure/wild/tallgrass
	name = "tall grass"
	icon = 'icons/obj/flora/wild.dmi'
	icon_state = "tall_grass_1"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "dead_tall_grass_1"
	opacity = FALSE
	density = FALSE
	layer = 5.1
	health = 20
	maxhealth = 20

/obj/structure/wild/flowers
	name = "flowers"
	icon = 'icons/obj/flora/ausflora.dmi'
	icon_state = "flower1"
	deadicon = 'icons/obj/flora/ausflora.dmi'
	deadicon_state = "flower1"
	opacity = FALSE
	density = FALSE
	layer = 5.1
	health = 5
	maxhealth = 5
	New()
		..()
		icon_state = "flower[rand(1,14)]"

/obj/structure/wild/tallgrass/fire_act(temperature)
	if (prob(55 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

/obj/structure/wild/tallgrass2
	name = "tall grass"
	icon = 'icons/obj/flora/wild.dmi'
	icon_state = "tall_grass_6"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "tall_grass_6"
	opacity = FALSE
	density = FALSE

/obj/structure/wild/tallgrass2/fire_act(temperature)
	if (prob(55 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

/obj/structure/wild/tallgrass/New()
	..()
	icon_state = "tall_grass_[rand(1,5)]"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "dead_tall_grass_[rand(1,5)]"

/obj/structure/wild/tallgrass2/New()
	..()
	icon_state = "tall_grass_[rand(6,9)]"
	deadicon = 'icons/obj/flora/wild.dmi'
	deadicon_state = "tall_grass_[rand(6,9)]"

/obj/structure/wild/burnedbush/New()
	..()
	icon_state = "burnedbush[rand(1,8)]"
	deadicon_state = "burnedbush[rand(1,8)]"

/obj/structure/wild/junglebush/New()
	..()
	icon_state = "[rand(1,30)]"
	deadicon = 'icons/obj/flora/dead_jungleflora.dmi'
	deadicon_state = "[rand(1,30)]"

/obj/structure/wild/junglebush/attackby(obj/item/W as obj, mob/user as mob)
	var/mob/living/human/H = user
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if(istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		user.do_attack_animation(src)
		if (healthamount == 1)
			if (prob(25) && radiation < 15)
				user << "You harvest some medicinal leaves."
				new /obj/item/stack/medical/advanced/herbs(get_turf(user))
				healthamount = 0
			else
				user << "You couldn't find any good leaves in this plant."
				healthamount = 0
			regrow()
		else
			user << "There are no leaves to harvest here."
			return
	if (user.a_intent == I_GRAB && ishuman(user) && edible && leaves >= 1)
		H << "You start foraging for fern leaves..."
		if (do_after(user, 80, src))
			if (src && leaves >= 1)
				H << "You collect some fern leaves."
				new /obj/item/stack/material/leaf/fern(get_turf(src))
				new /obj/item/stack/material/leaf/fern(get_turf(src))
				leaves--
			else
				user << "You couldn't find any good leaves in this plant."
		else if (H.gorillaman)
			H << "You start foraging for some edible fern leaves..."
			if (do_after(user, 80, src))
				if (src && leaves >= 1)
					H << "You collect some edible fern leaves."
					new /obj/item/stack/material/leaf/fern(get_turf(src))
					new /obj/item/stack/material/leaf/fern(get_turf(src))
					leaves--
				else
					user << "You couldn't find any good leaves in this plant."
		else
			user << "You stop foraging."
	else
		..()

/obj/structure/wild/jungle
	name = "jungle tree"
	icon = 'icons/obj/flora/jungletreesmaller.dmi'
	icon_state = "tree1"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "tree_1"
	opacity = TRUE
	density = TRUE
	sways = FALSE
	bound_height = 64
	bound_width = 32
	amount = 9
	health = 200
	maxhealth = 200
	layer = 5.11
	edible = TRUE
	leaves = 3
	max_leaves = 3
	branches = 3
	max_branches = 3
	pixel_x = -16

/obj/structure/wild/jungle/New()
	..()
	pixel_x = rand(-24,-8)
	pixel_y = rand(0,16)

/obj/structure/wild/jungle/fire_act(temperature)
	if (prob(25 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] collapses.</span>")
		qdel(src)

//these are under the jungle subtype so they dont change sprites during the winter.
/obj/structure/wild/jungle/acacia
	name = "acacia tree"
	icon = 'icons/obj/flora/bigtrees.dmi'
	icon_state = "african_acacia"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "african_acacia_dead"
	edible = TRUE
	leaves = 1
	max_leaves = 1
	branches = 2
	max_branches = 2

/obj/structure/wild/jungle/acacia/dead
	name = "dead acacia tree"
	icon = 'icons/obj/flora/deadtrees.dmi'
	icon_state = "african_acacia_dead"
	deadicon_state = "african_acacia_dead"
	edible = FALSE
	leaves = 0
	max_leaves = 0
	branches = 2
	max_branches = 2

/obj/structure/wild/jungle/acacia/New()
	..()
	icon_state = "african_acacia"
	deadicon_state = "african_acacia_dead"

/obj/structure/wild/jungle/acacia/dead/New()
	..()
	icon_state = "african_acacia_dead"
	deadicon_state = "african_acacia_dead"

/obj/structure/wild/jungle/New()
	..()
	icon_state = "tree[rand(1,7)]"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "tree_[rand(1,5)]"

/obj/structure/wild/jungle/medpine
	name = "mediterranean pine tree"
	icon = 'icons/obj/flora/bigtrees.dmi'
	icon_state = "med_pine"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "med_pine_dead"
	edible = FALSE
	leaves = 0
	max_leaves = 0
	branches = 2
	max_branches = 2

/obj/structure/wild/jungle/medpine/dead
	name = "dead mediterranean pine tree"
	icon = 'icons/obj/flora/deadtrees.dmi'
	icon_state = "med_pine_dead"
	deadicon = 'icons/obj/flora/deadtrees.dmi'
	deadicon_state = "med_pine_dead"
	edible = FALSE
	leaves = 0
	max_leaves = 0
	branches = 2
	max_branches = 2

/obj/structure/wild/jungle/medpine/New()
	..()
	icon_state = "med_pine"
	deadicon_state = "med_pine_dead"

/obj/structure/wild/jungle/medpine/dead/New()
	..()
	icon_state = "med_pine_dead"
	deadicon_state = "med_pine_dead"

/obj/structure/wild/jungle/try_destroy()
	if (health <= 0)
		if (stored_unit)
			release_stored()
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/wood(get_turf(src))
		dropwood.amount = 7
		if (leaves>0)
			new/obj/item/stack/material/leaf(get_turf(src))
			new/obj/item/stack/material/leaf(get_turf(src))
		if (leaves>=3) //give extra leaves
			new/obj/item/stack/material/leaf(get_turf(src))
			new/obj/item/stack/material/leaf(get_turf(src))
			new/obj/item/stack/material/leaf(get_turf(src))
			new/obj/item/stack/material/leaf(get_turf(src))
		qdel(src)

/obj/structure/wild/jungle/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		health -= 10
		visible_message("<span class='danger'>[user] tries to chop down \the [src]!</span>")
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
	else
		..()

/obj/structure/wild/largejungle
	name = "large jungle bush"
	icon = 'icons/obj/flora/largejungleflora.dmi'
	icon_state = "bush1"
	deadicon = "none"
	deadicon_state = "none"
	opacity = FALSE
	density = FALSE
	edible = TRUE
	leaves = 4
	max_leaves = 4

/obj/structure/wild/largejungle/attackby(obj/item/W as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (user.a_intent == I_GRAB && ishuman(user) && edible && leaves >= 1)
		H << "You start foraging for fern leaves..."
		if (do_after(user, 80, src))
			if (src && leaves >= 1)
				H << "You collect some fern leaves."
				new /obj/item/stack/material/leaf/fern(get_turf(src))
				new /obj/item/stack/material/leaf/fern(get_turf(src))
				leaves--
			else
				user << "You couldn't find any good leaves in this plant."
		else if (H.gorillaman)
			H << "You start foraging for some edible fern leaves..."
			if (do_after(user, 80, src))
				if (src && leaves >= 1)
					H << "You collect some edible fern leaves."
					new /obj/item/stack/material/leaf/fern(get_turf(src))
					new /obj/item/stack/material/leaf/fern(get_turf(src))
					leaves--
				else
					user << "You couldn't find any good leaves in this plant."
		else
			user << "You stop foraging."
	else
		..()

/obj/structure/wild/largejungle/New()
	..()
	if (prob(75))
		icon_state = "bush[rand(1,3)]"
	else
		icon_state = "rocks[rand(1,3)]"

/obj/structure/wild/junglebush/chinchona
	name = "chinchona"
	desc = "you can extract quinine from it."
	icon = 'icons/obj/flora/plants.dmi'
	icon_state = "chinchona1"
	opacity = FALSE
	density = FALSE
	healthamount = 1

/obj/structure/wild/junglebush/chinchona/New()
	..()
	icon_state = "chinchona1"

/obj/structure/wild/junglebush/chinchona/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if(istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		user.do_attack_animation(src)
		if (healthamount == 1)
			user << "You harvest some of the chinchona."
			new /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona(get_turf(user))
			healthamount = 0
			regrow()
			update_icon()
			return
		else
			user << "There are no good parts to harvest. Wait for it to regrow."
			return
	..()

/obj/structure/wild/junglebush/proc/regrow()
	spawn(3000)
		healthamount = 1
		update_icon()
		return

/obj/structure/wild/junglebush/chinchona/update_icon()
	..()
	icon_state = "chinchona[healthamount]"

/obj/structure/wild/attack_hand(mob/user as mob)
	if (user.a_intent == I_GRAB && ishuman(user) && edible && leaves >= 1)
		var/mob/living/human/H = user
		if (H.gorillaman)
			H << "You start foraging for some edible leaves..."
			if (do_after(user, 80, src))
				if (src && leaves >= 1)
					H << "You collect some edible leaves."
					new /obj/item/stack/material/leaf(get_turf(src))
					new /obj/item/stack/material/leaf(get_turf(src))
					leaves--
					if (leaves <= 0 && istype(src,/obj/structure/wild/tree/live_tree))
						icon = 'icons/obj/flora/deadtrees.dmi'
					return
				else
					user << "There are no leaves to harvest here."
			else
				user << "You stop foraging."
	else if (user.a_intent == I_HARM && branches >= 1)
		user << "You start breaking a branch from \the [src]..."
		if (do_after(user, 80, src))
			if (src && branches >= 1)
				user << "You take a branch from the tree."
				if (icon == 'icons/obj/flora/deadtrees.dmi' || icon == 'icons/obj/flora/deadtrees_winter.dmi' || icon == 'icons/obj/flora/pinetrees_dead.dmi' || findtext(icon_state, "dead"))
					new /obj/structure/branch/cleared(get_turf(src))
				else
					new /obj/structure/branch(get_turf(src))
				branches--
				grow_branch()
				return
			else
				user << "There are no useful branches in this tree."
				return
		return
	else
		..()

/obj/structure/wild/jungle/MouseDrop_T(var/mob/living/human/user as mob)
	if (istype(user, /mob/living/human))
		if (stored_unit)
			return
		if (user.restrained() || user.stat || user.weakened || user.stunned || user.paralysis)
			return
		if (!isturf(user.loc)) // are you in a container/closet/pod/etc?
			return
		var/mob/living/human/H = user
		if (H.faction_text == "VIETNAMESE")
			user << "You start hiding in \the [src]..."
			if (do_after(user,100,src))
				user << "You finish hiding in \the [src]."
				stored_unit = user
				if (user.client)
					user.client.perspective = EYE_PERSPECTIVE
					user.client.eye = src
				user.forceMove(src)
	else
		..()

/obj/structure/wild/attack_hand(mob/user as mob)
	if (stored_unit)
		if (user == stored_unit)
			release_stored()
	else
		..()

/obj/structure/wild/proc/release_stored()
	if (stored_unit)
		if (stored_unit.client)
			stored_unit.client.eye = stored_unit.client.mob
			stored_unit.client.perspective = MOB_PERSPECTIVE
			stored_unit.forceMove(get_turf(src))
			stored_unit = null
			return

/obj/structure/wild/bamboo
	name = "bamboo"
	icon = 'icons/obj/flora/bamboo.dmi'
	icon_state = "bamboowall1"
	deadicon = "none"
	deadicon_state = "none"
	opacity = FALSE
	density = FALSE
	edible = TRUE
	leaves = 1
	max_leaves = 1

/obj/structure/wild/bamboo/New()
	..()
	if (prob(50))
		icon_state = "bamboowall[rand(1,3)]"
	else
		icon_state = "bamboowall_single[rand(1,3)]"

/obj/structure/wild/bamboo/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		var/obj/item/stack/material/wood/dropwood = new /obj/item/stack/material/bamboo(get_turf(src))
		dropwood.amount = 5
		qdel(src)
