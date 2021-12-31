#define STATE_EMPTY "empty"
#define STATE_WATER "water"
#define STATE_BOILING "boiling"
#define STATE_STEWING "stew"
// what turns into what when we boil it?
#define BOIL_MAP list(/obj/item/weapon/reagent_containers/food/snacks/spaghetti = /obj/item/weapon/reagent_containers/food/snacks/boiledspagetti, /obj/item/weapon/reagent_containers/food/snacks/rice = /obj/item/weapon/reagent_containers/food/snacks/boiledrice, /obj/item/weapon/reagent_containers/food/snacks/rawlobster = /obj/item/weapon/reagent_containers/food/snacks/rawlobster/boiled, /obj/item/weapon/reagent_containers/food/snacks/noodles = /obj/item/weapon/reagent_containers/food/snacks/ramen)


/obj/structure/pot
	name = "Pot"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "empty_pot"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	var/base_state = "_pot"
	var/state = STATE_EMPTY
	var/fullness = 0 // 0 to 100
	var/bowls = 0
	var/initial_bowls = 0
	var/stew_desc = ""
	var/stew_nutriment = 0
	var/stew_protein = 0
	var/water = 0
	var/stew_ticks = 0
	var/list/stew_nutriment_desc = list()
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/pot/New()
	..()
	processing_objects += src
	reagents = new /datum/reagents(100, src)

/obj/structure/pot/Del()
	processing_objects -= src
	..()

/obj/structure/pot/update_icon()
	icon_state = "[state][base_state]"

/obj/structure/pot/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!istype(H))
		return
	if (istype(I, /obj/item/weapon/wrench))
		visible_message("<span class='warning'>[H] starts to [anchored ? "unsecure" : "secure"] the pot [anchored ? "from" : "to"] the ground.</span>")
		playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
		if (do_after(H,50,src))
			visible_message("<span class='warning'>[H] [anchored ? "unsecures" : "secures"] the pot [anchored ? "from" : "to"] the ground.</span>")
			anchored = !anchored
		return
	else if ((istype(I, /obj/item/weapon/reagent_containers/food/drinks) || istype(I, /obj/item/weapon/reagent_containers/glass)) && state == STATE_EMPTY)
		if (!I.reagents)
			return
		var/datum/reagent/R = I.reagents.get_master_reagent()
		if (!R || !I.reagents.reagent_list.len)
			H << "<span class = 'warning'>There's nothing in \the [I].</span>"
			return
		if (!istype(R, /datum/reagent/water))
			if (I.reagents.total_volume >= reagents.maximum_volume)
				H << "<span class = 'notice'>The pot can't hold any more reagents.</span>"
			else
				for (var/datum/reagent/RR in I.reagents.reagent_list)
					reagents.add_reagent(RR.id, RR.volume)
				I.reagents.clear_reagents()
				visible_message("<span class = 'notice'>[H] pours the contents of [I] into the pot.</span>")
		else
			var/rem = min(R.volume, 100)
			I.reagents.remove_reagent(R.id, rem)
			fullness += rem
			fullness = min(fullness, 100)
			if (fullness == 100)
				state = STATE_WATER
				update_icon()
			H << "<span class = 'notice'>[H] fills the pot with some water. It's about [fullness]% full.</span>"
			return
	else if (!istype(I, /obj/item/kitchen/snack_bowl) || !istype(I, /obj/item/kitchen/wood_bowl))
		if (istype(I, /obj/item/weapon/reagent_containers/food))
			if (!list(STATE_WATER, STATE_BOILING).Find(state))
				return

			if (istype(I, /obj/item/weapon/reagent_containers/food/drinks))
				if (I.reagents && I.reagents.reagent_list.len)
					if (I.reagents.total_volume >= reagents.maximum_volume)
						H << "<span class = 'notice'>The pot can't hold any more reagents.</span>"
					else
						for (var/datum/reagent/R in I.reagents.reagent_list)
							reagents.add_reagent(R.id, R.volume)
						I.reagents.clear_reagents()
						visible_message("<span class = 'notice'>[H] pours the contents of [I] into the pot.</span>")
			else if (istype(I, /obj/item/weapon/reagent_containers/food/condiment))
				var/obj/item/weapon/reagent_containers/food/condiment/C = I
				C.standard_pour_into(H, src)
			else
				if (contents.len >= 15)
					H << "<span class = 'warning'>There's too much in the pot already.</span>"
					return
				if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/stew))
					H << "<span class = 'warning'>This won't fit in the pot.</span>"
					return
				H.remove_from_mob(I)
				I.loc = src
				visible_message("<span class = 'notice'>[H] puts [I] in the pot.</span>")
				stew_ticks = max(stew_ticks - 5, 0)
				if (state == STATE_WATER)
					state = STATE_BOILING
					update_icon()
	else
		return
	if (state != STATE_STEWING)
		return
	if (istype(I, /obj/item/kitchen/snack_bowl) || istype(I, /obj/item/kitchen/wood_bowl))
		var/obj/item/weapon/reagent_containers/food/snacks/stew_wood/w_stew = new
		if (stew_desc)
			w_stew.name = stew_desc
			w_stew.nutriment_desc.Cut()

			for (var/desc in stew_nutriment_desc)
				w_stew.nutriment_desc[desc] = 1

		if (stew_nutriment)
			w_stew.reagents.remove_reagent("nutriment", 500)
			w_stew.reagents.add_reagent("nutriment", stew_nutriment)

		if (stew_protein)
			w_stew.reagents.remove_reagent("protein", 500)
			w_stew.reagents.add_reagent("protein", stew_protein)

		for (var/datum/reagent/R in reagents.reagent_list)
			var/amt = ceil(R.volume/initial_bowls)
			w_stew.reagents.maximum_volume += amt
			w_stew.reagents.add_reagent(R.id, amt)

		if (H.l_hand == I)
			H.remove_from_mob(I)
			H.equip_to_slot(w_stew, slot_l_hand)

		else if (H.r_hand == I)
			H.remove_from_mob(I)
			H.equip_to_slot(w_stew, slot_r_hand)

		qdel(I)
		--bowls

		if (bowls <= 0)
			state = STATE_EMPTY
			stew_desc = ""
			stew_nutriment_desc.Cut()
			stew_nutriment = 0
			stew_protein = 0
			fullness = 0
			update_icon()

/obj/structure/pot/attack_hand(var/mob/living/human/H)
	if (!istype(H))
		return
	if (state != STATE_BOILING)
		return
	for (var/obj/item/I in contents)
		H.put_in_any_hand_if_possible(I, prioritize_active_hand = TRUE)
		visible_message("<span class = 'notice'>[H] takes [I.name] from the pot of boiling water.</span>")
		break

/obj/structure/pot/process()

	if (state == STATE_BOILING)
		if (contents.len)
			var/boiling = 0
			for (var/obj/item/weapon/reagent_containers/food/F in contents)
				if (!F.boiled && prob(10))
					visible_message("<span class = 'notice'>[F] finishes boiling.</span>")
					if (BOIL_MAP[F.type])
						var/newtype = BOIL_MAP[F.type]
						new newtype (src)
						contents -= F
						qdel(F)

					else
						F.name = replacetext(F.name, "raw ", "")
						F.desc = replacetext(F.desc, "raw", "boiled")
						F.name = "boiled [F.name]"
						F.color = "#f0f0f0"
						if (F.reagents)
							F.reagents.multiply_reagent("nutriment", 4)
							F.reagents.multiply_reagent("protein", 2)
							F.reagents.del_reagent("food_poisoning")
							F.reagents.del_reagent("cholera")
						F.boiled = TRUE
						F.raw = FALSE
				else
					++boiling
			if (boiling > 0)
				if (stew_ticks >= rand(20,25))
					state = STATE_STEWING
					bowls = min(round(contents.len/3) + 3,10) // 1 object = 3 bowls. 10 objects = 6 bowls
					initial_bowls = bowls
					visible_message("<span class = 'notice'>The liquid in the pot turns into a stew.</span>")
					stew_desc = "stew with "
					stew_nutriment_desc.Cut()
					for (var/obj/item/I in contents)
						stew_desc += I.name
						if (I != contents[contents.len])
							if (contents.len > 1)
								if (I == contents[contents.len-1])
									stew_desc += " and "
								else
									stew_desc += ", "
						if(length(stew_desc) > 50)
							stew_desc = "stew "
						if (istype(I, /obj/item/weapon/reagent_containers/food))
							var/obj/item/weapon/reagent_containers/food/F = I
							if (F.reagents)
								F.reagents.del_reagent("food_poisoning")
								F.reagents.del_reagent("cholera")
								stew_nutriment += round(F.reagents.get_reagent_amount("nutriment")/bowls)
								stew_protein += round(F.reagents.get_reagent_amount("protein")/bowls)
								stew_nutriment_desc |= F.name
					for (var/datum/reagent/R in reagents.reagent_list)
						R.volume /= bowls
					reagents.update_total()

					name = "pot of stew"
					stew_ticks = 0
					contents.Cut()
				else
					++stew_ticks
		else
			state = STATE_WATER

	update_icon()

/obj/structure/pot/examine(mob/user)
	..(user)
	if (state == STATE_STEWING && stew_desc)
		user << "<span class = 'notice'>You can see a [lowertext(stew_desc)].</span>"
	else if (state == STATE_EMPTY)
		user << "<span class = 'notice'>It's an empty pot.</span>"
	else if (state == STATE_WATER)
		user << "<span class = 'notice'>It's a pot full of water.</span>"
	else if (state == STATE_BOILING)
		user << "<span class = 'notice'>It's a pot with some things boiling inside.</span>"
		var/message = "You can see "
		for (var/obj/item/I in contents)
			message += I.name
			if (I != contents[contents.len])
				if (contents.len > 1 && I == contents[contents.len-1])
					if (contents.len > 2)
						message += ", and"
					else
						message += " and "
				else
					message += ", "
		message += " in the water."
		user << "<span class = 'notice'>[message]</span>"

/obj/structure/pot/verb/empty()
	set src in range(1, usr)
	set name = "Empty"
	set category = null
	if (state == STATE_EMPTY)
		return
	visible_message("<span class = 'warning'>[usr] starts to empty the pot...</span>")
	if (do_after(usr, 100, src))
		visible_message("<span class = 'warning'>[usr] finishes emptying the pot.</span>")
		state = STATE_EMPTY