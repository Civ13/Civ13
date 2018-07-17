/obj/gasser
	icon = null
	icon_state = null
	anchored = 1.0
	name = ""

/obj/gasser/proc/function(var/first = TRUE)

	var/list/chemsmokes = list()
	var/list/target_turfs = list()
	var/area/target_area = get_area(src)

	if (istype(get_area(src), /area/prishtina/german) && !istype(get_area(src), /area/prishtina/german/ss_prison))
		target_area = locate(/area/prishtina/german/gas_chamber)

	if (target_area)

		for (var/turf/t in target_area.contents)
			target_turfs += t

		for (var/v in 1 to rand(2,3))
			spawn ((v*2) - 2)
				var/obj/effect/effect/smoke/chem/smoke = new/obj/effect/effect/smoke/chem/payload/zyklon_b(get_turf(src), _spread = TRUE, _destination = get_step(src, EAST))
				smoke.dontmove = TRUE
				chemsmokes += smoke

		// make the smoke randomly move around
		for (var/v in 1 to 10)
			spawn (v * 20)
				for (var/obj/effect/effect/smoke/chem/smoke in chemsmokes)
					walk_to(smoke, pick(target_turfs),0,rand(2,3),0)

		for (var/mob/living/L in target_area.contents)
			if (L.wear_mask && istype(L.wear_mask, /obj/item/clothing/mask/gas))
				var/obj/item/clothing/mask/gas/G = L.wear_mask
				if (G.filtered_gases.Find("zyklon_b"))
					continue

			if (first)
				L << "<span class = 'danger'>You're suffocating!</span>"

			for (var/v in 1 to 10)
				spawn ((v-1) * 10)
					if (L.stat == CONSCIOUS)
						L.adjustOxyLoss(rand(5,7))
						if (ishuman(L))
							var/mob/living/carbon/human/H = L
							H.emote("scream")
							H.next_emote["vocal"] = world.time + 100

/obj/gas_lever // same icon as the train lever for now
	anchored = 1.0
	density = TRUE
	icon = 'icons/WW2/train_lever.dmi'
	icon_state = "lever_none"
	var/none_state = "lever_none"
	var/pushed_state = "lever_pushed"
	var/orientation = "NONE"
	name = "gassing lever"
	var/next_use = -1

/obj/gas_lever/New()
	..()
	lever_list += src

/obj/gas_lever/Destroy()
	lever_list -= src
	..()

/obj/gas_lever/attack_hand(var/mob/user as mob)
	if (world.time < next_use && next_use != -1)
		return

	next_use = world.time + 25

	if (user && istype(user, /mob/living/carbon/human))
		if (orientation == "NONE")
			icon_state = pushed_state
			orientation = "PUSHED"
			visible_message("<span class = 'danger'>[user] pushes the lever forwards!</span>", "<span class = 'notice'>You push the lever forwards.</span>")

			var/first = FALSE
			var/gc = 0
			for (var/obj/gasser/gasser in range(10, src))
				++gc
				spawn ((gc-1))
					gasser.function(!first ? TRUE : FALSE)
					first = TRUE

		else if (orientation == "PUSHED")
			icon_state = none_state
			orientation = "NONE"
			visible_message("<span class = 'danger'>[user] pulls the lever back.</span>", "<span class = 'notice'>You pull the lever back.</span>")
	playsound(get_turf(src), 'sound/effects/lever.ogg', 100, TRUE)
