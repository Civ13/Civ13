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

/obj/item/weapon/material/handle
	name = "handle"
	sharp = FALSE
	edge = FALSE
	desc = "A basic stick with a hole on top to attach something. Can be made into a veriety of weapons and tools."
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

/obj/item/weapon/material/pitchfork
	name = "pitchfork"
	desc = "It's used for removing weeds or scratching your back."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "rake"
	item_state = "rake"
	worn_state = "rake"
	default_material = "iron"
	force_divisor = 0.35 // 5 with weight 20 (steel)
	thrown_force_divisor = 0.35 // as above
	w_class = 3
	attack_verb = list("slashed", "clawed")
	cooldownw = 9

/obj/item/weapon/material/spear
	name = "spear"
	sharp = TRUE
	edge = TRUE
	desc = "A crude, yet effective weapon."
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	icon_state = "spear_old"
	item_state = "spear"
	worn_state = "spear"
	default_material = "wood"
	throw_speed = 6
	throw_range = 11
	allow_spin = FALSE
	force_divisor = 0.7 // 42 with hardness 60 (steel)
	thrown_force_divisor = 1.2 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 6
	block_chance = 15
	cooldownw = 9


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
	force_divisor = 0.4 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.7 // 16 with weight 20 (steel)
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
	desc = "A very sharp axe blade upon a short wood handle. It has a long history of chopping things, but now it is used for chopping wood."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "hatchet"
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = 2
	sharp = TRUE
	edge = TRUE
	material = "iron"
//	origin_tech = "materials=2;combat=1"
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = FALSE
	value = 15
	slot_flags = SLOT_BELT
	block_chance = 15
	cooldownw = 5

/obj/item/weapon/material/hatchet/tribal
	name = "hatchet"
	desc = "A crude hatchet, made with wood and stone."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "tribalaxe"
	material = "stone"
	force_divisor = 0.5 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 13 with weight 20 (steel)
	value = 12
	block_chance = 15
	cooldownw = 5

/obj/item/weapon/material/boarding_axe
	name = "boarding axe"
	desc = "A short axe, useful for breaking wood and boarding enemy ships."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "combat_axe"
	default_material = "steel"
	force_divisor = 0.6 // 12 with hardness 60 (steel)
	thrown_force_divisor = 0.75 // 15 with weight 20 (steel)
	w_class = 2
	sharp = TRUE
	edge = TRUE
//	origin_tech = "materials=2;combat=1"
	attack_verb = list("chopped", "torn", "cut")
	slot_flags = SLOT_BELT
	applies_material_colour = FALSE
	value = 20
	block_chance = 12
	cooldownw = 6

/obj/item/weapon/material/minihoe // -- Numbers
	name = "mini hoe"
	desc = "It's used for removing weeds or scratching your back."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "hoe"
	item_state = "hoe"
	force_divisor = 0.25 // 5 with weight 20 (steel)
	thrown_force_divisor = 0.25 // as above
	w_class = 2
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
	w_class = 4
	slot_flags = SLOT_SHOULDER
//	origin_tech = "materials=2;combat=2"
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
	thrown_force_divisor = 1.5 // 27 with weight 18 (wood)
	attack_verb = list("jabbed","impaled","ripped")
	value = 10
	block_chance = 10
	cooldownw = 7

/obj/item/weapon/material/roman_standard
	name = "Roman Standard"
	sharp = TRUE
	edge = TRUE
	desc = "A golden standard of a Roman Legion, with the Aquila on top."
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
	name = "Roman Standard"

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
	thrown_force_divisor = 1.1 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 10
	block_chance = 15
	cooldownw = 10

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
	block_chance = 5
	cooldownw = 12

/obj/item/weapon/material/spear/sarissa/attack_self(mob/user)
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
	if (!istype(loc, /mob/living/carbon/human))
		deployed = FALSE
		item_state = "dory"
		worn_state = "dory"
	else
		var/mob/living/carbon/human/US = loc
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
	thrown_force_divisor = 0.7 // 24 with weight 20 (steel)
	attack_verb = list("jabbed","impaled","ripped")
	value = 18
	cooldownw = 13

/obj/item/weapon/material/hatchet/battleaxe
	name = "battle axe"
	desc = "A very sharp axe blade upon a long wood handle. Not pratical for chopping wood, but pratical for chopping limbs."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "battleaxe"
	item_state = "battleaxe"
	default_material = "iron"
	force_divisor = 0.6 // 30 with hardness 60 (steel)
	thrown_force_divisor = 0.55 // 15 with weight 20 (steel)
	w_class = 3
	sharp = TRUE
	edge = TRUE
	material = "iron"
//	origin_tech = "materials=2;combat=1"
	attack_verb = list("chopped", "torn", "cut")
	applies_material_colour = TRUE
	value = 20
	slot_flags = SLOT_BELT
	block_chance = 15
	cooldownw = 11