// ores
/obj/item/stack/ore
	name = "ore"
	icon = 'icons/obj/mining.dmi'
	icon_state = "ore2"
	w_class = ITEM_SIZE_SMALL
	amount = 1
	max_amount = 50
	can_stack = TRUE
	value = 1
	var/radioactive = FALSE
	var/radioactive_amt = 0

/obj/item/stack/ore/New()
	pixel_x = rand(0,16)-8
	pixel_y = rand(0,8)-8
	process_radioactivity()
	..()

/obj/item/stack/ore/proc/process_radioactivity()
	if (!src || !radioactive || radioactive_amt <= 0)
		return
	if (!istype(loc, /obj/structure/closet/crate/lead)) //lead containers block radioactivity
		radiation_pulse(get_turf(src), 3, radioactive_amt, 10, FALSE) // 0.16 rads per second, should take 10 mins to reach 1 gray

	spawn(100)
		process_radioactivity()

/obj/item/stack/ore/iron
	name = "iron ore"
	icon_state = "ore_iron"
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("iron",5)
						ET.update_icon()
						qdel(src)
		else
			..()

/obj/item/stack/ore/iron_sponge //crude refined iron from a bloomery. Use on anvil for wrought iron
	name = "sponge iron"
	desc = "Very crude iron, can be further refined into wrought iron in an anvil."
	icon_state = "ore_sponge_iron"
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("iron",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/iron_pig //slighly better iron from a blast furnace.
	name = "pig iron"
	desc = "A soft iron with a high carbon content. Used to make steel using an anvil."
	icon_state = "ore_pig_iron"
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("iron",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/glass
	name = "sand"
	icon_state = "ore_glass"
	slot_flags = SLOT_HOLSTER

/obj/item/stack/ore/silver
	name = "silver ore"
	icon_state = "ore_silver"
	value = 5
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("silver",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/gold
	name = "gold ore"
	value = 10
	icon_state = "ore_gold"
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("gold",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/copper
	name = "copper ore"
	icon_state = "ore_copper"
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("copper",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/tin
	name = "tin ore"
	icon_state = "ore_tin"
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("tin",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/diamond
	name = "diamonds"
	icon_state = "ore_diamond"
	value = 10
/obj/item/stack/ore/obsidian
	name = "obsidian"
	desc = "A sort of volcanic glass."
	icon_state = "ore_obsidian"
	value = 3
	attackby(var/obj/W as obj, mob/user as mob)
		if (istype(W, /obj/item/weapon/chisel))
			var/mob/living/human/H = user
			if (!istype(H.l_hand, /obj/item/weapon/hammer) && !istype(H.r_hand, /obj/item/weapon/hammer))
				user << "<span class = 'warning'>You need to have a hammer in one of your hands to use a chisel.</span>"
			else
				visible_message("<span class='danger'>[user] starts to cut the obsidian!</span>", "<span class='danger'>You start cutting the obsidian.</span>")
				if (do_after(H, min(src.amount*10, 200), H.loc))
					visible_message("<span class='danger'>[user] finishes cutting the obsidian!</span>", "<span class='danger'>You finish cutting the obsidian.</span>")
					var/obj/item/stack/material/obsidian/cut_obsidian = new/obj/item/stack/material/obsidian(src.loc)
					cut_obsidian.amount = src.amount
					qdel(src)
		else
			..()
			return
/obj/item/stack/ore/uranium
	name = "uranium ore"
	icon_state = "ore_uranium"
	radioactive = TRUE
	radioactive_amt = 7
	flammable = FALSE
	value = 5
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("uranium",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/uranium/random
	New()
		..()
		amount = rand(1,25)
/obj/item/stack/ore/saltpeter
	name = "saltpeter rock"
	desc = "A yellowish cristal, consisting of potassium nitrate. A common precursor to many explosives, including gunpowder."
	icon_state = "ore_saltpeter"
	singular_name = "rock"
	flammable = TRUE
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("potassium",2.5)
						ET.reagents.add_reagent("nitrogen",2.5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/coal
	name = "mineral coal"
	desc = "A bunch of mineral coal. Very dense."
	icon_state = "ore_coal"
	singular_name = "rock"
	flammable = TRUE
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("carbon",5)
						ET.update_icon()
						qdel(src)

		else
			..()
/obj/item/stack/ore/charcoal
	name = "charcoal"
	desc = "Refried Wood."
	icon_state = "ore_charcoal"
	singular_name = "rock"
	flammable = FALSE
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to crumble \the [src] into  \the [W.name]...</span>", "<span class = 'notice'>You start to crumble \the [src] into \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("charcoal",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/sulphur
	name = "sulphur rock"
	desc = "Yellow and smelly."
	icon_state = "ore_sulphur"
	singular_name = "rock"
	flammable = TRUE
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("sulfur",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/lead
	name = "lead ore"
	desc = "A rock of very dense lead ore."
	icon_state = "ore_lead"
	singular_name = "rock"
	flags = CONDUCT
	flammable = FALSE
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("lead",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/mercury
	name = "cinnabar ore"
	desc = "A brownish-red rock of mercury sulfide."
	icon_state = "ore_mercury"
	singular_name = "rock"
	flammable = FALSE
	flags = CONDUCT
	attackby(var/obj/W as obj, var/mob/living/human/H as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/glass/extraction_kit))
			var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = W
			if (ET.reagents.total_volume > 0)
				H << "<span class = 'notice'>Empty \the [ET] first.</span>"
				return
			if (istype(H))
				visible_message("<span class = 'notice'>[H] starts to purify \the [src] with \the [W.name]...</span>", "<span class = 'notice'>You start to purify \the [src] with \the [W.name].</span>")
				playsound(src,'sound/effects/pickaxe.ogg',100,1)
				var/timera = 110/(H.getStatCoeff("dexterity"))
				if (do_after(H, timera))
					if (ET.reagents.total_volume <= 0)
						ET.reagents.add_reagent("mercury",5)
						ET.update_icon()
						qdel(src)
		else
			..()
/obj/item/stack/ore/fossilskull1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_skull1"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilskull2
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_skulll2"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilskull3
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_skull3"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilleaf1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_leaf1"
	singular_name = "fossil"
	flammable = FALSE


/obj/item/stack/ore/fossilleaf2
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_leaf2"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilleaf3
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_leaf3"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilshell1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_shell1"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilshell2
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_shell2"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilshell3
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_shell3"
	singular_name = "fossil"
	flammable = FALSE

/obj/item/stack/ore/fossilbone1
	name = "Fossils"
	desc = "An ancient fossil... must be from ages ago!"
	icon_state = "fossil_bone1"
	singular_name = "fossil"
	flammable = FALSE
