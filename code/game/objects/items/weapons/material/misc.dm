/obj/item/weapon/material
	var/chopping_speed = 5
/obj/item/weapon/material/harpoon
	name = "harpoon"
	sharp = TRUE
	edge = TRUE
	desc = "Good for whale hunting."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "harpoon"
	item_state = "harpoon"
	worn_state = "spear"
	throw_speed = 3
	throw_range = 7
	allow_spin = FALSE
	default_material = "wood"
	force_divisor = 0.4 // 24 with hardness 60 (steel)
	thrown_force_divisor = 1.1 // 22 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 8
	block_chance = 12
	cooldownw = 7

/obj/item/weapon/material/harpoon/iron
	name = "iron harpoon"
	default_material = "iron"

/obj/item/weapon/material/handle
	name = "handle"
	sharp = FALSE
	edge = FALSE
	desc = "A basic stick with a slot on top to attach something. Can be made into a veriety of weapons and tools."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "handle"
	item_state = "spear"
	default_material = "wood"
	throw_speed = 7
	throw_range = 7
	allow_spin = FALSE
	force_divisor = 0.2 // 12 with hardness 60 (steel)
	thrown_force_divisor = 0.4 // 8 with weight 20 (steel)
	attack_verb = list("jabbed","hit","bashed")
	value = 3
	block_chance = 10
	cooldownw = 7

/obj/item/weapon/material/trowel
	name = "planting trowel"
	sharp = FALSE
	edge = FALSE
	desc = "A short spade used for gardening activities like emptying or filling plant-pots."
	icon_state = "trowel"
	item_state = "trowel"
	default_material = "iron"
	throw_speed = 4
	throw_range = 4
	allow_spin = FALSE
	force_divisor = 0.2 // 12 with hardness 60 (steel)
	thrown_force_divisor = 0.2 // 8 with weight 20 (steel)
	attack_verb = list("jabbed","hit","bashed")
	cooldownw = 7


/obj/item/weapon/material/bust
	name = "stone bust"
	sharp = FALSE
	edge = FALSE
	desc = "A stone bust of a person"
	icon_state = "bust"
	item_state = "bust"
	default_material = "stone"
	throw_speed = 3
	throw_range = 3
	allow_spin = FALSE
	force_divisor = 0.35
	thrown_force_divisor = 0.35
	attack_verb = list("bludgeoned","hit","bashed")
	value = 15
	block_chance = 10
	cooldownw = 7

/obj/item/weapon/material/hippocratic
	name = "stone bust of hippocrates"
	sharp = FALSE
	edge = FALSE
	desc = "A stone bust of hippocrates"
	icon_state = "hippocratic"
	item_state = "hippocratic"
	default_material = "stone"
	throw_speed = 3
	throw_range = 3
	allow_spin = FALSE
	force_divisor = 0.35
	thrown_force_divisor = 0.35
	attack_verb = list("bludgeoned","hit","bashed")
	value = 15
	block_chance = 10
	cooldownw = 7

/obj/item/weapon/material/marx
	name = "bronze bust of karl marx"
	sharp = FALSE
	edge = FALSE
	desc = "A bronze bust of karl marx"
	icon_state = "marx"
	item_state = "marx"
	default_material = "bronze"
	throw_speed = 3
	throw_range = 3
	allow_spin = FALSE
	force_divisor = 0.35
	thrown_force_divisor = 0.35
	attack_verb = list("bludgeoned","hit","bashed")
	value = 50
	block_chance = 10
	cooldownw = 7


/obj/item/weapon/material/pitchfork
	name = "pitchfork"
	sharp = TRUE
	edge = FALSE
	desc = "It's used for removing weeds or scratching your back."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "rake"
	item_state = "rake"
	worn_state = "rake"
	default_material = "iron"
	force_divisor = 0.35 // 5 with weight 20 (steel)
	thrown_force_divisor = 0.35 // as above
	w_class = ITEM_SIZE_NORMAL
	attack_verb = list("slashed", "clawed", "forked")
	cooldownw = 9

/turf/floor/grass/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/material/pitchfork))
		visible_message("<span class = 'notice'>[user] starts to remove grass layer.</span>")
		if (!do_after(user, (C.cooldownw * C.force)))
			return
		visible_message("<span class = 'notice'>[user] removes grass layer.</span>")
		var/area/AREA = get_area(src)
		if(map.ID == MAP_NOMADS_DESERT)
			ChangeTurf(/turf/floor/dirt/dust)
		else if (AREA.climate == "jungle" || AREA.climate == "savanna")
			ChangeTurf(/turf/floor/dirt/jungledirt)
		else
			ChangeTurf(/turf/floor/dirt)
	..()
/obj/structure/wild/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(src, /obj/structure/wild/junglebush) || istype(src, /obj/structure/wild/smallbush/) || istype(src, /obj/structure/wild/burnedbush/) || istype(src, /obj/structure/wild/tallgrass2) || istype(src, /obj/structure/wild/tallgrass) || istype(src, /obj/structure/wild/flowers) || istype(src, /obj/structure/wild/bush/big) || istype(src, /obj/structure/wild/bush))
		if (istype(C, /obj/item/weapon/material/pitchfork))
			visible_message("<span class = 'notice'>[user] starts to uproot [src].</span>")
			if (!do_after(user, (C.cooldownw * C.force)))
				return
			visible_message("<span class = 'notice'>[user] uproots [src].</span>")
			qdel(src)
	..()
/obj/item/weapon/material/spear
	name = "spear"
	sharp = TRUE
	edge = TRUE
	desc = "A crude, yet effective weapon."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "spear"
	item_state = "spear"
	worn_state = "spear"
	default_material = "wood"
	throw_speed = 6
	throw_range = 11
	allow_spin = FALSE
	force_divisor = 0.7 // 42 with hardness 60 (steel)
	thrown_force_divisor = 2 // 40 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 6
	block_chance = 15
	cooldownw = 9

/obj/item/weapon/material/spear/iron
	name = "iron spear"
	default_material = "iron"
/obj/item/weapon/material/spear/attack(atom/A, mob/living/user, def_zone)
	..()
	if (isliving(A) && prob(33))
		var/mob/living/TARGETMOB = A
		visible_message("<span class = 'danger'>[TARGETMOB] is pushed back!")
		for (var/obj/structure/noose/N in get_turf(TARGETMOB))
			if (N.hanging == TARGETMOB)
				return

		for (var/obj/structure/bed/B in get_turf(TARGETMOB))
			if (B.buckled_mob == TARGETMOB)
				return
		var/turf/behind = get_turf(get_step(TARGETMOB, user.dir))
		if (behind)
			if (behind.density || locate(/obj/structure) in behind)
				var/turf/slammed_into = behind
				if (!slammed_into.density)
					for (var/obj/structure/S in slammed_into.contents)
						if (S.density)
							slammed_into = S
							break
				if (slammed_into.density)
					visible_message("<span class = 'danger'>[TARGETMOB] is pushed back into \the [slammed_into]!</span>")
					TARGETMOB.adjustBruteLoss(rand(3,6))
					for (var/obj/structure/window/W in get_turf(slammed_into))
						W.shatter()
			else
				if (!map || !map.check_caribbean_block(TARGETMOB, behind))
					TARGETMOB.forceMove(behind)
		for (var/obj/structure/ST in get_step(loc, user.dir))
			if (ST.density == TRUE)
				return
		for (var/obj/covers/CV in get_step(loc, user.dir))
			if (CV.density == TRUE)
				return
		for (var/turf/wall/TS in get_step(loc, user.dir))
			if (TS.density == TRUE)
				return
		for (var/obj/structure/noose/N in get_turf(TARGETMOB))
			if (N.hanging == TARGETMOB)
				return
		for (var/obj/structure/bed/B in get_turf(TARGETMOB))
			if (B.buckled_mob == TARGETMOB)
				return

/obj/item/weapon/material/spear/assagai
	name = "assagai spear"
	desc = "A long hafted wood spear with a finely sharpened iron point; rewnown for being the weapon of choice of zulu warriors."
	icon_state = "assagai"
	item_state = "assagai"
	worn_state = "assagai"
	force_divisor = 0.8 // 32 with hardness 40 (wood)
	thrown_force_divisor = 1.6 // 29 with weight 18 (wood)

//New batons
/obj/item/weapon/material/classic_baton
	name = "baton"
	desc = "A wooden truncheon for beating criminal scum."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "baton"
	item_state = "classic_baton"
	block_chance = 27
	force_divisor = 1
	thrown_force_divisor = 3
	force = 1
	slot_flags = SLOT_BELT | SLOT_BACK
	value = 0
	cooldownw = 8
	flammable = TRUE
	attack_verb = list("thwacked", "hit", "clonked", "batted", "slammed", "smacked", "poked", "slapped")
	hitsound = 'sound/weapons/pierce.ogg'
	drawsound = 'sound/weapons/hiddenblade_deploy.ogg'
	sharp = FALSE
	edge = FALSE
	default_material = "softwood"



/obj/item/weapon/material/classic_baton/guard
	desc = "A Heavy wooden truncheon for beating criminal scum this one is made of harder wood material."
	default_material = "hardwood"
	force_divisor = 1
	block_chance = 27
	cooldownw = 8

/obj/item/weapon/material/classic_baton/nightstick
	name = "Nightstick"
	desc = "A police officers nightstick used to keep the streets clean."
	default_material = "hardwood"
	icon_state = "nightbaton"
	item_state = "nightbaton"
	force_divisor = 1
	block_chance = 27
	cooldownw = 8

/obj/item/weapon/material/classic_baton/guard/metal
	desc = "A Heavy metal truncheon for beating criminal scum this one is made of iron and likely to injure someone quckily aim anywhere but the head!."
	default_material = "iron"
	force_divisor = 1
	block_chance = 27
	cooldownw = 10

/obj/item/weapon/material/classic_baton/blackjack
	name = "Blackjack"
	desc = "A Heavy leather wrapped truncheon with a hefty lead weight in the tip for makeing scum comply."
	icon_state = "blackjack"
	item_state = "blackjack"
	default_material = "leather"
	force_divisor = 3
	block_chance = 19
	cooldownw = 10
	applies_material_colour = FALSE


/obj/item/weapon/material/quarterstaff
	name = "quarterstaff"
	sharp = FALSE
	edge = FALSE
	desc = "A simple wood staff, doesn't do too much damage but its fast at blocking and hitting"
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "quarterstaff"
	item_state = "quarterstaff"
	default_material = "wood"
	throw_speed = 6
	throw_range = 10
	allow_spin = TRUE
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 16 with weight 20 (steel)
	attack_verb = list("bashed","poked","beaten")
	value = 6
	block_chance = 20
	cooldownw = 6

/obj/item/weapon/material/fancycane
	name = "black cane"
	sharp = FALSE
	edge = FALSE
	desc = "A fancy cane used to walk with. This one looks quite expensive."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "fancycane"
	item_state = "woodcane1"
	throw_speed = 6
	throw_range = 10
	allow_spin = TRUE
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 16 with weight 20 (steel)
	attack_verb = list("bashed","poked","beaten")
	value = 6
	block_chance = 27
	cooldownw = 6
	applies_material_colour = FALSE

/obj/item/weapon/material/naginata
	name = "naginata"
	sharp = TRUE
	edge = TRUE
	desc = "A wood staff with a blade on the end, good for impaling those who insult your lord."
	slot_flags = SLOT_SHOULDER
	icon_state = "naginata"
	item_state = "naginata"
	default_material = "iron"
	throw_speed = 7
	throw_range = 11
	allow_spin = FALSE
	force_divisor = 0.85 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.95 // 16 with weight 20 (steel)
	attack_verb = list("bashed","impaled","beaten")
	value = 30
	block_chance = 36
	cooldownw = 6
	color = null

/obj/item/weapon/material/naginata/steel
	default_material = "steel"
	value = 35
	block_chance = 40
	cooldownw = 6

/obj/item/weapon/material/hatchet
	name = "hatchet"
	desc = "A very sharp axe blade upon a short wood handle. It has a long history of chopping things. This one is intended for chopping wood."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "hatchet"
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_SMALL
	sharp = TRUE
	edge = TRUE
	default_material = "iron"
	material = "iron"
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = TRUE
	value = 15
	slot_flags = SLOT_BELT
	block_chance = 15
	cooldownw = 5
	chopping_speed = 1.7
	health = 20
	maxhealth = 20

/obj/item/weapon/material/hatchet/steel
	chopping_speed = 1.55
	health = 40
	maxhealth = 40
	material = "steel"
	default_material = "steel"
	applies_material_colour = FALSE

/obj/item/weapon/material/hatchet/bronze
	chopping_speed = 1.65
	health = 12
	maxhealth = 12
	material = "bronze"
	default_material = "bronze"

/obj/item/weapon/material/machete
	name = "machete"
	desc = "A small sized machete used by wood cutters."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "machete"
	force_divisor = 0.7 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_SMALL
	sharp = TRUE
	edge = TRUE
	material = "iron"
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = FALSE
	value = 15
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 15
	cooldownw = 5
	chopping_speed = 1.6
	health = 15
	maxhealth = 15

/obj/item/weapon/material/machete1
	name = "machete"
	desc = "A small sized machete used by wood cutters."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "machete1"
	force_divisor = 0.6 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_SMALL
	sharp = TRUE
	edge = TRUE
	material = "iron"
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = FALSE
	value = 15
	slot_flags = SLOT_BELT | SLOT_BACK
	block_chance = 15
	cooldownw = 5
	chopping_speed = 1.6

/obj/item/weapon/material/hatchet/tribal
	name = "hatchet"
	desc = "A crude hatchet, made with wood and stone."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "tribalaxe"
	material = "stone"
	default_material = "stone"
	item_state = "stonehatchet"
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 13 with weight 20 (steel)
	value = 12
	block_chance = 15
	cooldownw = 5
	chopping_speed = 3.3
	health = 10
	maxhealth = 10
	applies_material_colour = FALSE

/obj/item/weapon/material/hatchet/tribal/bone
	material = "bone"
	default_material = "stone"
	desc = "A crude hatchet, made with wood and bone."
	icon_state = "bonehatchet"
	item_state = "bonehatchet"
	chopping_speed = 4
	health = 7.5
	maxhealth = 7.5

/obj/item/weapon/material/hatchet/tribal/flint
	material = "flint"
	desc = "A very crude hatchet, made with wood and flint."
	icon = 'icons/obj/old_weapons.dmi'
	icon_state = "flint_axe"
	item_state = "flinthatchet"
	chopping_speed = 3.5

/obj/item/weapon/material/boarding_axe
	name = "boarding axe"
	desc = "A short axe, useful for breaking wood and boarding enemy ships."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "combat_axe"
	default_material = "steel"
	force_divisor = 0.6 // 12 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_SMALL
	sharp = TRUE
	edge = TRUE
	attack_verb = list("chopped", "torn", "cut")
	slot_flags = SLOT_BELT
	applies_material_colour = FALSE
	value = 20
	block_chance = 12
	cooldownw = 6
	chopping_speed = 2.7

/obj/item/weapon/material/minihoe // -- Numbers
	name = "mini hoe"
	desc = "It's used for removing weeds or scratching your back."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "hoe"
	item_state = "hoe"
	force_divisor = 0.25 // 5 with weight 20 (steel)
	thrown_force_divisor = 0.25 // as above
	w_class = ITEM_SIZE_SMALL
	attack_verb = list("slashed", "sliced", "cut", "clawed")
	cooldownw = 5

/obj/item/weapon/material/scythe
	icon_state = "scythe0"
	name = "scythe"
	desc = "A sharp and curved blade on a long fibremetal handle, this tool makes it easy to reap what you sow."
	force_divisor = 0.275 // 16 with hardness 60 (steel)
	thrown_force_divisor = 0.25 // 5 with weight 20 (steel)
	sharp = TRUE
	edge = TRUE
	throw_speed = TRUE
	throw_range = 3
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_SHOULDER
	attack_verb = list("chopped", "sliced", "cut", "reaped")
	cooldownw = 5

/obj/item/weapon/material/scythe/old
	icon_state = "scythe"
	name = "scythe"
	desc = "A sharp and curved blade on a long wooden handle, this tool makes it easy to reap what you sow."
	force_divisor = 0.275 // 16 with hardness 60 (steel)
	thrown_force_divisor = 0.25 // 5 with weight 20 (steel)
	sharp = TRUE
	edge = TRUE
	throw_speed = TRUE
	throw_range = 3
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_SHOULDER
	attack_verb = list("chopped", "sliced", "cut", "reaped")
	cooldownw = 5

/obj/item/weapon/material/pilum
	name = "pilum"
	sharp = TRUE
	edge = TRUE
	desc = "A 2-meter long javelin with an iron tip, used by the Roman Army."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "pilum"
	item_state = "pilum"
	worn_state = "pilum"
	default_material = "wood"
	throw_speed = 6
	throw_range = 14
	allow_spin = FALSE
	force_divisor = 0.7 // 28 with hardness 40 (wood)
	thrown_force_divisor = 2.5 // 45 with weight 18 (wood)
	attack_verb = list("jabbed","impaled","ripped")
	value = 10
	block_chance = 10
	cooldownw = 7

/*/obj/item/weapon/material/javelin
	name = "javelin"
	sharp = TRUE
	edge = TRUE
	desc = "A meter long short spear that can be used as a hand launched missle or for close combat." */

/obj/item/weapon/material/roman_standard
	name = "roman standard"
	sharp = TRUE
	edge = TRUE
	desc = "A standard of a roman legion, with the aquila on top."
	slot_flags = SLOT_SHOULDER
	icon_state = "roman_standard"
	item_state = "roman_standard"
	default_material = "wood"
	throw_speed = 3
	throw_range = 5
	allow_spin = FALSE
	force_divisor = 0.4 // 42 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 0
	block_chance = 15
	cooldownw = 10

/obj/item/weapon/material/roman_standard/New()
	..()
	name = "roman standard"

/obj/item/weapon/material/greek_standard
	name = "greek standard"
	sharp = TRUE
	edge = TRUE
	desc = "A standard of the hellenic armies. It is laquered in red carrying red feathers."
	slot_flags = SLOT_SHOULDER
	icon_state = "greek_standard"
	item_state = "greek_standard"
	default_material = "wood"
	throw_speed = 3
	throw_range = 5
	allow_spin = FALSE
	force_divisor = 0.4 // 42 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 0
	block_chance = 15
	cooldownw = 10

/obj/item/weapon/material/greek_standard/New()
	..()
	name = "greek standard"

/obj/item/weapon/material/egyptian_standard
	name = "egyptian standard"
	sharp = TRUE
	edge = TRUE
	desc = "A standard of the phaoroic armies with a mighty lion in gold attached upon it."
	slot_flags = SLOT_SHOULDER
	icon_state = "egyptian_standard"
	item_state = "egyptian_standard"
	default_material = "wood"
	throw_speed = 3
	throw_range = 5
	allow_spin = FALSE
	force_divisor = 0.4 // 42 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 0
	block_chance = 15
	cooldownw = 10

/obj/item/weapon/material/egyptian_standard/New()
	..()
	name = "egyptian standard"

/obj/item/weapon/material/spear/dory
	name = "dory"
	sharp = TRUE
	edge = TRUE
	desc = "A 2 meter long spear, used by soldiers of the Hellenic culture."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "dory"
	item_state = "dory"
	worn_state = "dory"
	default_material = "wood"
	throw_speed = 4
	throw_range = 8
	allow_spin = FALSE
	force_divisor = 0.85 // 42 with hardness 60 (steel)
	thrown_force_divisor = 1.5 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 10
	block_chance = 15
	cooldownw = 10

/obj/item/weapon/material/spear/dory/bronze
	name = "bronze spear"
	default_material = "bronze"

/obj/item/weapon/material/spear/sarissa
	name = "sarissa"
	sharp = TRUE
	edge = TRUE
	desc = "A 5 meter long spear, used by phalanx soldiers."
	slot_flags = SLOT_SHOULDER
	icon_state = "sarissa"
	item_state = "sarissa"
	worn_state = "sarissa"
	default_material = "wood"
	throw_speed = 1
	throw_range = 1
	nothrow = TRUE
	allow_spin = FALSE
	force_divisor = 0.85
	thrown_force_divisor = 0.1
	attack_verb = list("jabbed","impaled","ripped")
	value = 18
	var/image/standing
	var/ownerdir_x = 0
	var/ownerdir_y = 0
	var/ownerdir_z = 1
	var/ownerdir = NORTH
	var/deployed = FALSE
	var/cooldown = FALSE
	block_chance = 5
	cooldownw = 12

/obj/item/weapon/material/spear/sarissa/attack_self(mob/user)
	if (!cooldown)
		if (deployed)
			deployed = FALSE
			user << "<span class='notice'>You lift your [name] up, falling out of formation.</span>"
			return
		else
			deployed = TRUE
			user << "<span class='notice'>You turn your [name] down, forming a spear wall!</span>"
			update_icon()
			check_dmg()
			return
		spawn(10 SECONDS)
			cooldown = FALSE

/obj/item/weapon/material/spear/sarissa/proc/check_dmg()
	if (deployed)
		spawn(3)
			check_dmg()
		if (ismob(loc))
			var/mob/living/H = loc
			if (H.stat == DEAD || H.stat == UNCONSCIOUS)
				deployed = FALSE
				return
		for (var/mob/living/TARGETMOB in get_step(loc, ownerdir))
			for (var/obj/structure/noose/N in get_turf(TARGETMOB))
				if (N.hanging == TARGETMOB)
					return

			for (var/obj/structure/bed/B in get_turf(TARGETMOB))
				if (B.buckled_mob == TARGETMOB)
					return
			if (prob(60))
				var/turf/behind = get_turf(get_step(TARGETMOB, ownerdir))
				if (behind)
					if (behind.density || locate(/obj/structure) in behind)
						var/turf/slammed_into = behind
						if (!slammed_into.density)
							for (var/obj/structure/S in slammed_into.contents)
								if (S.density)
									slammed_into = S
									break
						if (slammed_into.density)
							visible_message("<span class = 'danger'>[TARGETMOB] is pushed back into \the [slammed_into]!</span>")
							TARGETMOB.adjustBruteLoss(rand(3,6))
							for (var/obj/structure/window/W in get_turf(slammed_into))
								W.shatter()
					else
						if (!map || !map.check_caribbean_block(TARGETMOB, behind))
							TARGETMOB.forceMove(behind)

		for (var/mob/living/TARGETMOB in get_step(get_step(loc, ownerdir),ownerdir))
			for (var/obj/structure/ST in get_step(loc, ownerdir))
				if (ST.density == TRUE)
					return
			for (var/obj/covers/CV in get_step(loc, ownerdir))
				if (CV.density == TRUE)
					return
			for (var/turf/wall/TS in get_step(loc, ownerdir))
				if (TS.density == TRUE)
					return
			for (var/obj/structure/noose/N in get_turf(TARGETMOB))
				if (N.hanging == TARGETMOB)
					return
			for (var/obj/structure/bed/B in get_turf(TARGETMOB))
				if (B.buckled_mob == TARGETMOB)
					return
			if (prob(80))
				var/turf/behind = get_turf(get_step(TARGETMOB, ownerdir))
				if (behind)
					if (behind.density || locate(/obj/structure) in behind)
						var/turf/slammed_into = behind
						if (!slammed_into.density)
							for (var/obj/structure/S in slammed_into.contents)
								if (S.density)
									slammed_into = S
									break
						if (slammed_into.density)
							visible_message("<span class = 'danger'>[TARGETMOB] is pushed back into \the [slammed_into]!</span>")
							TARGETMOB.adjustBruteLoss(rand(3,6))
							for (var/obj/structure/window/W in get_turf(slammed_into))
								W.shatter()
					else
						if (!map || !map.check_caribbean_block(TARGETMOB, behind))
							TARGETMOB.forceMove(behind)
							TARGETMOB.adjustBruteLoss(rand(2,4))

/obj/item/weapon/material/spear/sarissa/update_icon()
// yes, i know this is horrible shitcode. Pls no bully
	if (!istype(loc, /mob/living/human))
		deployed = FALSE
		item_state = "dory"
		worn_state = "dory"
	else
		var/mob/living/human/US = loc
		if (deployed)
			item_state = ""
			worn_state = ""
			var/img_state
			US.overlays -= standing
			if (US.dir == NORTH)
				img_state = 'icons/obj/weapons_2t_v.dmi'
				standing = image(icon = img_state, icon_state = "sarissa")
				standing.pixel_x = 0
				standing.pixel_y = 0
				ownerdir_x = US.x
				ownerdir_y = US.y+32
				ownerdir_z = US.z
				ownerdir = NORTH
			else if (US.dir == SOUTH)
				img_state = 'icons/obj/weapons_2t_v.dmi'
				standing = image(icon = img_state, icon_state = "sarissa")
				standing.pixel_x = 0
				standing.pixel_y = -32
				ownerdir_x = US.x
				ownerdir_y = US.y-32
				ownerdir_z = US.z
				ownerdir = SOUTH
			else if (US.dir == EAST)
				img_state = 'icons/obj/weapons_2t.dmi'
				standing = image(icon = img_state, icon_state = "sarissa")
				standing.pixel_x = 0
				standing.pixel_y = 0
				ownerdir_x = US.x+32
				ownerdir_y = US.y
				ownerdir_z = US.z
				ownerdir = EAST
			else if (US.dir == WEST)
				img_state = 'icons/obj/weapons_2t.dmi'
				standing = image(icon = img_state, icon_state = "sarissa")
				standing.pixel_x = -32
				standing.pixel_y = 0
				ownerdir_x = US.x-32
				ownerdir_y = US.y
				ownerdir_z = US.z
				ownerdir = WEST
			//apply img
			US.overlays += standing
		else if (!deployed)
			US.overlays -= standing
			item_state = "dory"
			worn_state = "dory"
		spawn(1)
			update_icon()

/obj/item/weapon/material/spear/sarissa/bronze
	name = "bronze spear"
	default_material = "bronze"

/obj/item/weapon/material/spear/sarissa/dja
	name = "bronze dja"
	default_material = "bronze"

/obj/item/weapon/material/spear/sarissa/pike
	name = "pike"
	desc = "A long spear."
	slot_flags = SLOT_SHOULDER
//	icon_state = "pike"
//	item_state = "pike"
//	worn_state = "pike"
	default_material = "iron"
	allow_spin = FALSE
	force_divisor = 0.85 // 42 with hardness 60 (steel)
	thrown_force_divisor = 0.1 // 20 with weight 20 (steel)
	value = 18
	cooldownw = 13
	block_chance = 18

/obj/item/weapon/material/spear/sarissa/pike/steel
	default_material = "steel"
	value = 38
	force_divisor = 0.87
	cooldownw = 11
	block_chance = 21

/obj/item/weapon/material/spear/naginata
	name = "naginata"
	sharp = TRUE
	edge = TRUE
	desc = "A wood staff with a blade on the end, good for impaling those who insult your lord."
	slot_flags = SLOT_SHOULDER
	icon_state = "naginata"
	item_state = "naginata"
	default_material = "iron"
	throw_speed = 7
	throw_range = 11
	allow_spin = FALSE
	force_divisor = 0.85 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.95 // 16 with weight 20 (steel)
	attack_verb = list("bashed","impaled","beaten")
	value = 30
	block_chance = 36
	cooldownw = 6
	color = null

/obj/item/weapon/material/spear/naginata/steel
	default_material = "steel"
	value = 35
	block_chance = 40
	cooldownw = 6

/obj/item/weapon/material/halberd
	name = "halberd"
	sharp = TRUE
	edge = TRUE
	desc = "A spear topped by an axe blade."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "halberd"
	item_state = "halberd"
	worn_state = "halberd"
	default_material = "iron"
	throw_speed = 3
	throw_range = 4
	allow_spin = FALSE
	block_chance = 18
	force_divisor = 0.8 // 42 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 15
	cooldownw = 12

/obj/item/weapon/material/halberd/steel
	default_material = "steel"
	value = 20

/obj/item/weapon/material/spear/halberd
	name = "halberd"
	sharp = TRUE
	edge = TRUE
	desc = "A spear topped by an axe blade."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "halberd"
	item_state = "halberd"
	worn_state = "halberd"
	default_material = "iron"
	throw_speed = 3
	throw_range = 4
	allow_spin = FALSE
	block_chance = 18
	force_divisor = 0.8 // 42 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 15
	cooldownw = 12

/obj/item/weapon/material/spear/halberd/steel
	default_material = "steel"
	value = 20

/obj/item/weapon/material/pike
	name = "pike"
	sharp = TRUE
	edge = TRUE
	desc = "A long spear."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "pike"
	item_state = "pike"
	worn_state = "pike"
	default_material = "iron"
	throw_speed = 4
	throw_range = 5
	allow_spin = FALSE
	block_chance = 12
	force_divisor = 0.85 // 42 with hardness 60 (steel)
	thrown_force_divisor = 1 // 20 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 18
	cooldownw = 13


/obj/item/weapon/material/pike/steel
	default_material = "steel"
	value = 23
	health = 30
	maxhealth = 30

/obj/item/weapon/material/hatchet/battleaxe
	name = "battle axe"
	desc = "A very sharp axe blade upon a long wood handle. Great at chopping most things."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "battleaxe"
	item_state = "battleaxe"
	default_material = "iron"
	material = "iron"
	force_divisor = 0.6 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.55 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_NORMAL
	sharp = TRUE
	edge = TRUE
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = TRUE
	value = 20
	slot_flags = SLOT_BELT
	block_chance = 15
	cooldownw = 11
	chopping_speed = 1.4
	health = 25
	maxhealth = 25

/obj/item/weapon/material/hatchet/battleaxe/steel
	default_material = "steel"
	material = "steel"
	chopping_speed = 1.2
	health = 50
	maxhealth = 50
	applies_material_colour = FALSE

/obj/item/weapon/material/hatchet/battleaxe/bronze
	default_material = "bronze"
	material = "bronze"
	chopping_speed = 1.75
	health = 15
	maxhealth = 15
	applies_material_colour = TRUE

/obj/item/weapon/material/hatchet/bone_battleaxe
	name = "battle axe"
	material = "bone"
	desc = "A very sharp bone axe blade upon a long wood handle. Not great at chopping wood but excellent at chopping limbs."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "bone_battleaxe"
	item_state = "bone_battleaxe"
	default_material = "bone"
	material = "bone"
	force_divisor = 0.6 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.55 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_NORMAL
	sharp = TRUE
	edge = TRUE
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = TRUE
	value = 20
	slot_flags = SLOT_BELT
	block_chance = 15
	cooldownw = 11
	health = 15
	maxhealth = 15
	chopping_speed = 2

/obj/item/weapon/material/hatchet/bone_battleaxe/stone
	default_material = "stone"
	material = "stone"
	chopping_speed = 1.9
	health = 25
	maxhealth = 25
	desc = "A very sharp stone axe blade upon a long wood handle. Not great at chopping wood but excellent at chopping limbs."

/obj/item/weapon/material/scepter
	name = "gold scepter"
	sharp = FALSE
	edge = FALSE
	desc = "An old golden staff, doesn't do too much damage but its fast at blocking and hitting"
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "scepter"
	item_state = "scepter"
	default_material = "gold"
	throw_speed = 6
	throw_range = 10
	allow_spin = TRUE
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 16 with weight 20 (steel)
	attack_verb = list("bashed","poked","beaten")
	value = 6
	block_chance = 20
	cooldownw = 5

/obj/item/weapon/lungemine
	name = "lunge mine"
	desc = "A long pole with an anti tank mine at the end, results in the users death."
	slot_flags = SLOT_SHOULDER
	icon_state = "lungemine"
	item_state = "lungemine"
	throw_speed = 7
	throw_range = 11
	allow_spin = FALSE

/obj/structure/vehicleparts/frame/attackby(var/obj/item/I, var/mob/living/human/H)
	if (istype(I, /obj/item/weapon/lungemine))
		visible_message("The lunge mine hits \the [src]!")
		message_admins("[H] used a lunge mine on a vehicle at [x], [y], [z].")
		log_admin("[H] used a lunge mine on a vehicle at [x], [y], [z].")
		explosion(H.loc, 1, 3, 2, 0)
		for (var/mob/M in axis.transporting)
			shake_camera(M, 4, 4)

		w_left[5] -= 55
		w_right[5] -= 55
		w_front[5] -= 55
		w_back[5] -= 55
		try_destroy()
		if (H)
			H.awards["tank"]+=(heavy_armor_penetration/200)
	else
		..()

////////////////////////////////////////SKYRIM//////////////////////////////////////
/obj/item/weapon/material/tes13/mace
	name = "mace"
	sharp = TRUE
	edge = FALSE
	desc = "A steel mace, with 5 large spikes on it."
	slot_flags = SLOT_BELT
	icon_state = "steel_mace"
	item_state = "mace"
	default_material = "steel"
	throw_speed = 7
	throw_range = 11
	allow_spin = FALSE
	force_divisor = 0.85 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.95 // 16 with weight 20 (steel)
	attack_verb = list("bashed","struck","beaten")
	value = 30
	block_chance = 15
	cooldownw = 6

/obj/item/weapon/material/hatchet/battleaxe/tes13
	name = "war axe"
	desc = "A very sharp axe blade upon a steel handle. Not pratical for chopping wood, but pratical for chopping limbs."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "waraxe_tes13"
	item_state = "battleaxe"
	default_material = "steel"
	material = "steel"
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.55 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_NORMAL
	sharp = TRUE
	edge = TRUE
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = FALSE
	value = 20
	slot_flags = SLOT_BELT
	block_chance = 15
	cooldownw = 7
	health = 35
	maxhealth = 35
	chopping_speed = 2.5

/obj/item/weapon/material/hatchet/battleaxe/tes13/battleaxe
	name = "battle axe"
	desc = "A very sharp double axe blade upon a twohanded steel handle. Not pratical for felling trees but perhaps felling people."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "battleaxe_tes13"
	force_divisor = 0.8 // 30 with hardness 60 (steel)
	slot_flags = SLOT_SHOULDER | SLOT_BACK
	block_chance = 15
	cooldownw = 7
	health = 35
	maxhealth = 35
	chopping_speed = 2.3

/obj/item/weapon/material/hatchet/battleaxe/tes13/ulfric
	name = "ulfric's war axe"
	desc = "A very sharp axe blade upon a steel handle. Not pratical for chopping wood, but pratical for chopping limbs. This one belongs to the Jarl of Windhelm, Ulfric Stormcloak."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "waraxe_tes13"
	item_state = "battleaxe"
	default_material = "steel"
	material = "steel"
	force = 100
	force_divisor = 1 // 30 with hardness 60 (steel)
	thrown_force_divisor = 1 // 15 with weight 20 (steel)
	w_class = ITEM_SIZE_NORMAL
	sharp = TRUE
	edge = TRUE
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = FALSE
	value = 200
	slot_flags = SLOT_BELT
	block_chance = 20
	cooldownw = 4
	health = 200
	maxhealth = 200
	chopping_speed = 5