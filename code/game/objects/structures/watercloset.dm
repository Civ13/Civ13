//todo: toothbrushes, and some sort of "toilet-filthinator" for the hos

/obj/structure/toilet
	name = "latrine"
	desc = "A simple latrine."
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "toilet00"
	density = FALSE
	anchored = TRUE
	var/open = FALSE			//if the lid is up
	var/cistern = FALSE			//if the cistern bit is open
	var/w_items = FALSE			//the combined w_class of all the items in the cistern
	var/mob/living/swirlie = null	//the mob being given a swirlie
	not_movable = TRUE
	not_disassemblable = FALSE
/obj/structure/toilet/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(10))
				qdel(src)
				return
		if (3.0)
			return

/obj/structure/toilet/New()
	open = round(rand(0, TRUE))
	update_icon()

/obj/structure/toilet/attack_hand(mob/living/user as mob)
	if (swirlie)
		usr.visible_message("<span class='danger'>[user] slams the toilet seat onto [swirlie.name]'s head!</span>", "<span class='notice'>You slam the toilet seat onto [swirlie.name]'s head!</span>", "You hear reverberating porcelain.")
		swirlie.adjustBruteLoss(8)
		return

	if (cistern && !open)
		if (!contents.len)
			user << "<span class='notice'>The cistern is empty.</span>"
			return
		else
			var/obj/item/I = pick(contents)
			if (ishuman(user))
				user.put_in_hands(I)
			else
				I.loc = get_turf(src)
			user << "<span class='notice'>You find \an [I] in the cistern.</span>"
			w_items -= I.w_class
			return

	open = !open
	update_icon()

/obj/structure/toilet/update_icon()
	icon_state = "toilet[open][cistern]"

/obj/structure/toilet/attackby(obj/item/I as obj, mob/living/user as mob)
	if (istype(I, /obj/item/weapon/crowbar))
		user << "<span class='notice'>You start to [cistern ? "replace the lid on the cistern" : "lift the lid off the cistern"].</span>"
		playsound(loc, 'sound/effects/stonedoor_openclose.ogg', 50, TRUE)
		if (do_after(user, 30, src))
			user.visible_message("<span class='notice'>[user] [cistern ? "replaces the lid on the cistern" : "lifts the lid off the cistern"]!</span>", "<span class='notice'>You [cistern ? "replace the lid on the cistern" : "lift the lid off the cistern"]!</span>", "You hear grinding porcelain.")
			cistern = !cistern
			update_icon()
			return

	if (istype(I, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = I

		if (isliving(G.affecting))
			var/mob/living/GM = G.affecting

			if (G.state>1)
				if (!GM.loc == get_turf(src))
					user << "<span class='notice'>[GM.name] needs to be on the toilet.</span>"
					return
				if (open && !swirlie)
					user.visible_message("<span class='danger'>[user] starts to give [GM.name] a swirlie!</span>", "<span class='notice'>You start to give [GM.name] a swirlie!</span>")
					swirlie = GM
					if (do_after(user, 30, src))
						user.visible_message("<span class='danger'>[user] gives [GM.name] a swirlie!</span>", "<span class='notice'>You give [GM.name] a swirlie!</span>", "You hear a toilet flushing.")
						GM.adjustOxyLoss(5)
					swirlie = null
				else
					user.visible_message("<span class='danger'>[user] slams [GM.name] into the [src]!</span>", "<span class='notice'>You slam [GM.name] into the [src]!</span>")
					GM.adjustBruteLoss(8)
			else
				user << "<span class='notice'>You need a tighter grip.</span>"

	if (cistern)
		if (I.w_class > 3)
			user << "<span class='notice'>\The [I] does not fit.</span>"
			return
		if (w_items + I.w_class > 5)
			user << "<span class='notice'>The cistern is full.</span>"
			return
		user.drop_item()
		I.loc = src
		w_items += I.w_class
		user << "You carefully place \the [I] into the cistern."
		return

/obj/structure/toilet/AltClick(var/mob/living/user)
	if (!open)
		return
	var/H = user.get_active_hand()
	if (istype(H,/obj/item/weapon/reagent_containers/glass) || istype(H,/obj/item/weapon/reagent_containers/food/drinks))
		var/obj/item/weapon/reagent_containers/O = user.get_active_hand()
		if (O.reagents && O.reagents.total_volume)
			O.reagents.clear_reagents()
			user << "<span class='notice'>You empty the [O] into the [src].</span>"

/obj/structure/toilet/pit_latrine
	name = "pit latrine"
	desc = "A simple pit latrine, a hole dug on the ground to collect waste."
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "pit_latrine3"
	open = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/toilet/pit_latrine/New()
	open = TRUE

/obj/structure/toilet/attackby(obj/item/I as obj, mob/living/user as mob)
	return
/obj/structure/toilet/pit_latrine/attack_hand(mob/living/user as mob)
	return

/obj/structure/toilet/pit_latrine/AltClick(var/mob/living/user)
	return

/obj/structure/shower
	name = "shower"
	desc = "A basic, hot-and-cold shower system."
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "shower"
	density = FALSE
	anchored = TRUE
//	use_power = FALSE
	var/on = FALSE
	var/obj/effect/mist/mymist = null
	var/ismist = FALSE				//needs a var so we can make it linger~
	var/watertemp = "normal"	//freezing, normal, or boiling
	var/is_washing = FALSE
	var/list/temperature_settings = list("normal" = 310, "boiling" = T0C+100, "freezing" = T0C)
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/shower/New()
	..()
	create_reagents(50)
	processing_objects += src

/obj/structure/shower/Del()
	processing_objects -= src
	..()

/obj/structure/shower/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(10))
				qdel(src)
				return
		if (3.0)
			return

//add heat controls? when emagged, you can freeze to death in it?

/obj/effect/mist
	name = "mist"
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "mist"
	layer = MOB_LAYER + 1
	anchored = TRUE
	mouse_opacity = FALSE

/obj/structure/shower/attack_hand(mob/M as mob)
	on = !on
	update_icon()
	if (on)
		if (M.loc == loc)
			wash(M)
			process_heat(M)
		for (var/atom/movable/G in loc)
			G.clean_blood()

/obj/structure/shower/attackby(obj/item/I as obj, mob/user as mob)
//	if (I.type == /obj/item/analyzer)
	//	user << "<span class='notice'>The water temperature seems to be [watertemp].</span>"
	if (istype(I, /obj/item/weapon/wrench))
		var/newtemp = WWinput(user, "What setting would you like to set the temperature valve to?", "Water Temperature Valve", WWinput_first_choice(temperature_settings), WWinput_list_or_null(temperature_settings))
		user << "<span class='notice'>You begin to adjust the temperature valve with \the [I].</span>"
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		if (do_after(user, 50, src))
			watertemp = newtemp
			user.visible_message("<span class='notice'>\The [user] adjusts \the [src] with \the [I].</span>", "<span class='notice'>You adjust the shower with \the [I].</span>")
			add_fingerprint(user)

/obj/structure/shower/update_icon()	//this is terribly unreadable, but basically it makes the shower mist up
	overlays.Cut()					//once it's been on for a while, in addition to handling the water overlay.
	if (mymist)
		qdel(mymist)
		mymist = null

	if (on)
		overlays += image('icons/obj/watercloset.dmi', src, "water", MOB_LAYER + 1, dir)
		if (temperature_settings[watertemp] < T20C)
			return //no mist for cold water
		if (!ismist)
			spawn(50)
				if (src && on)
					ismist = TRUE
					mymist = PoolOrNew(/obj/effect/mist,loc)
		else
			ismist = TRUE
			mymist = PoolOrNew(/obj/effect/mist,loc)
	else if (ismist)
		ismist = TRUE
		mymist = PoolOrNew(/obj/effect/mist,loc)
		spawn(250)
			if (src && !on)
				qdel(mymist)
				mymist = null
				ismist = FALSE

/mob/living/carbon/human/proc/is_nude()
	return (!w_uniform) ? 1 : 0

//Yes, showers are super powerful as far as washing goes.
/obj/structure/shower/proc/wash(atom/movable/O as obj|mob)
	if (!on) return

	if (isliving(O))
		var/mob/living/L = O
		L.ExtinguishMob()
		L.fire_stacks = -20 //Douse ourselves with water to avoid fire more easily

	if (iscarbon(O))
		var/mob/living/carbon/M = O
		if (M.r_hand)
			M.r_hand.clean_blood()
		if (M.l_hand)
			M.l_hand.clean_blood()
		if (M.back)
			if (M.back.clean_blood())
				M.update_inv_back(0)
		if (M.shoulder)
			if (M.shoulder.clean_blood())
				M.update_inv_shoulder(0)
		//flush away reagents on the skin
		if (M.touching)
			var/remove_amount = M.touching.maximum_volume * M.reagent_permeability() //take off your suit first
			M.touching.remove_any(remove_amount)

		if (ishuman(M))
			var/mob/living/carbon/human/H = M
			H.color = initial(H.color)

			var/washgloves = TRUE
			var/washshoes = TRUE
			var/washmask = TRUE
			var/washears = TRUE

			if(H.is_nude())//Don't get clean showering with you clothes on.
				H.set_hygiene(HYGIENE_LEVEL_CLEAN)

			if (H.wear_suit)
				washgloves = !(H.wear_suit.flags_inv & HIDEGLOVES)
				washshoes = !(H.wear_suit.flags_inv & HIDESHOES)

			if (H.head)
				washmask = !(H.head.flags_inv & HIDEMASK)
				washears = !(H.head.flags_inv & HIDEEARS)

			if (H.wear_mask)
				if (washears)
					washears = !(H.wear_mask.flags_inv & HIDEEARS)

			if (H.head)
				if (H.head.clean_blood())
					H.update_inv_head(0)
			if (H.wear_suit)
				if (H.wear_suit.clean_blood())
					H.update_inv_wear_suit(0)
			else if (H.w_uniform)
				if (H.w_uniform.clean_blood())
					H.update_inv_w_uniform(0)
			if (H.gloves && washgloves)
				if (H.gloves.clean_blood())
					H.update_inv_gloves(0)
			if (H.shoes && washshoes)
				if (H.shoes.clean_blood())
					H.update_inv_shoes(0)
			if (H.wear_mask && washmask)
				if (H.wear_mask.clean_blood())
					H.update_inv_wear_mask(0)
			if (H.l_ear && washears)
				if (H.l_ear.clean_blood())
					H.update_inv_ears(0)
			if (H.r_ear && washears)
				if (H.r_ear.clean_blood())
					H.update_inv_ears(0)
			if (H.belt)
				if (H.belt.clean_blood())
					H.update_inv_belt(0)
			H.clean_blood(washshoes)
		else
			if (M.wear_mask)						//if the mob is not human, it cleans the mask without asking for bitflags
				if (M.wear_mask.clean_blood())
					M.update_inv_wear_mask(0)
			M.clean_blood()
	else
		O.clean_blood()

	if (isturf(loc))
		var/turf/tile = loc
		for (var/obj/effect/E in tile)
			if (istype(E,/obj/effect/decal/cleanable) || istype(E,/obj/effect/overlay))
				qdel(E)

	reagents.splash(O, 10)

/obj/structure/shower/process()
	if (!on) return

	for (var/thing in loc)
		var/atom/movable/AM = thing
		var/mob/living/L = thing
		if (istype(AM) && AM.simulated)
			wash(AM)
			if (istype(L))
				process_heat(L)
	wash_floor()
	reagents.add_reagent("water", reagents.get_free_space())

/obj/structure/shower/proc/wash_floor()
	if (!ismist && is_washing)
		return
	is_washing = TRUE
	var/turf/T = get_turf(src)
	reagents.splash(T, reagents.total_volume)
	T.clean(src)
	spawn(100)
		is_washing = FALSE

/obj/structure/shower/proc/process_heat(mob/living/M)
	if (!on || !istype(M)) return

	var/temperature = temperature_settings[watertemp]
	var/temp_adj = between(BODYTEMP_COOLING_MAX, temperature - M.bodytemperature, BODYTEMP_HEATING_MAX)
	M.bodytemperature += temp_adj

	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		if (temperature >= H.species.heat_level_1)
			H << "<span class='danger'>The water is searing hot!</span>"
		else if (temperature <= H.species.cold_level_1)
			H << "<span class='warning'>The water is freezing cold!</span>"


/obj/structure/sink
	name = "sink"
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "sink"
	desc = "A sink used for washing one's hands and face."
	anchored = TRUE
	var/busy = FALSE 	//Something's being washed at the moment
	var/sound = 'sound/effects/sink.ogg'
	var/dry = FALSE
	var/mosquito_count = 0
	var/mosquito_limit = 1
	var/volume = 2000
	var/max_volume = 2000
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/sink/New()
	..()
	refill()

/obj/structure/sink/proc/refill()
	if (volume < max_volume)
		if (volume < max_volume)
			volume += 10
		if (volume > max_volume)
			volume = max_volume
	spawn(60)
		refill()

/obj/structure/sink/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(10))
				qdel(src)
				return
		if (3.0)
			return

/obj/structure/sink/MouseDrop_T(var/obj/item/thing, var/mob/user)
	..()
	if (!istype(thing) || !thing.is_open_container())
		return ..()
	if (!usr.Adjacent(src))
		return ..()
	if (!thing.reagents || thing.reagents.total_volume == FALSE)
		usr << "<span class='warning'>\The [thing] is empty.</span>"
		return
	// Clear the vessel.
	visible_message("<span class='notice'>\The [usr] tips the contents of \the [thing] into \the [src].</span>")
	if (thing && reagents)
		thing.reagents.splash(src, reagents.total_volume)
		thing.reagents.clear_reagents()
		thing.update_icon()

/obj/structure/sink/attack_hand(mob/user as mob)
	if (ishuman(user))
		var/mob/living/carbon/human/H = user
		var/obj/item/organ/external/temp = H.organs_by_name["r_hand"]
		if (user.hand)
			temp = H.organs_by_name["l_hand"]
		if (temp && !temp.is_usable())
			user << "<span class='notice'>You try to move your [temp.name], but cannot!</span>"
			return

	if (!Adjacent(user))
		return

	if (busy && busy != user)
		user << "<span class='warning'>Someone's already washing here.</span>"
		return

	user << "<span class='notice'>You start washing your hands.</span>"
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

	if (sound)
		playsound(loc, sound, 100, TRUE)

	busy = user
	sleep(40)
	busy = FALSE

	if (!Adjacent(user)) return		//Person has moved away from the sink

	user.clean_blood()
	if (ishuman(user))
		user:update_inv_gloves()
	for (var/mob/V in viewers(src, null))
		V.show_message("<span class='notice'>[user] washes their hands using \the [src].</span>")

/obj/structure/sink/attackby(obj/item/O as obj, mob/living/user as mob)
	if (busy && busy != user)
		user << "<span class='warning'>Someone's already washing here.</span>"
		return
	if (dry || volume <= 0)
		user << "<span class='warning'>\The [src] is dry!</span>"
		return
	var/obj/item/weapon/reagent_containers/RG = O
	if (istype(RG) && RG.is_open_container() && do_after(user, 15, src, check_for_repeats = FALSE))
		if  (volume > 0)
			if (min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this) > volume)
				if (istype(src, /obj/structure/sink/puddle))
					if (prob(10))
						RG.reagents.add_reagent("food_poisoning", 1)
						RG.reagents.add_reagent("water", volume-1)
					else
						RG.reagents.add_reagent("water", volume)
				else
					RG.reagents.add_reagent("water", volume)
				volume = 0
				spawn(3)
					update_icon()
				user.visible_message("<span class='notice'>[user] fills \the [RG] using \the [src].</span>","<span class='notice'>You fill \the [RG] using \the [src].</span>")
				playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
				user.setClickCooldown(5)
				return TRUE

			else
				if (istype(src, /obj/structure/sink/puddle))
					if (prob(15))
						RG.reagents.add_reagent("cholera", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.05)
						RG.reagents.add_reagent("water", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.95)
					else
						RG.reagents.add_reagent("water", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this))
				else
					var/dirty = FALSE
					for(var/obj/item/weapon/reagent_containers/food/snacks/poo/PP in range(4,src))
						if (PP)
							dirty = TRUE
					if (dirty)
						RG.reagents.add_reagent("cholera", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.05)
						RG.reagents.add_reagent("water", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.95)
					else
						RG.reagents.add_reagent("water", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this))
				if (RG.reagents)
					volume -= min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)
				spawn(3)
					update_icon()
				user.visible_message("<span class='notice'>[user] fills \the [RG] using \the [src].</span>","<span class='notice'>You fill \the [RG] using \the [src].</span>")
				playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
				user.setClickCooldown(5)
				return TRUE


	else if (istype(O, /obj/item/weapon/mop))
		O.reagents.add_reagent("water", 5)
		user << "<span class='notice'>You wet \the [O] in \the [src].</span>"
		playsound(loc, 'sound/effects/slosh.ogg', 25, TRUE)
		return

	var/turf/location = user.loc
	if (!isturf(location)) return

	var/obj/item/I = O
	if (!I || !istype(I,/obj/item)) return

	usr << "<span class='notice'>You start washing \the [I].</span>"

	busy = TRUE
	sleep(40)
	busy = FALSE

	if (user.loc != location) return				//User has moved
	if (!I) return 								//Item's been destroyed while washing
	if (user.get_active_hand() != I) return		//Person has switched hands or the item in their hands

	O.clean_blood()
	user.visible_message( \
		"<span class='notice'>[user] washes \a [I] using \the [src].</span>", \
		"<span class='notice'>You wash \a [I] using \the [src].</span>")

/obj/structure/sink/AltClick(var/mob/living/user)
	var/H = user.get_active_hand()
	if (istype(H,/obj/item/weapon/reagent_containers/glass) || istype(H,/obj/item/weapon/reagent_containers/food/drinks))
		var/obj/item/weapon/reagent_containers/O = user.get_active_hand()
		if (O.reagents && O.reagents.total_volume)
			O.reagents.clear_reagents()
			user << "<span class='notice'>You empty the [O] into the [src].</span>"


/obj/structure/sink/kitchen
	name = "kitchen sink"
	icon_state = "sink_alt"

/obj/structure/sink/puddle	//splishy splashy ^_^
	name = "puddle"
	icon_state = "puddle"
	sound = 'sound/effects/watersplash.ogg'
	max_volume = 500
	volume = 500

/obj/structure/sink/puddle/nomosquitoes
	mosquito_limit = 0

/obj/structure/sink/well
	name = "well"
	icon_state = "well1"
	sound = 'sound/effects/watersplash.ogg'
	max_volume = 750
	volume = 750

/obj/structure/sink/well/attackby(obj/item/O as obj, mob/user as mob)
	if (istype(O, /obj/item/weapon/hammer) || istype(O, /obj/item/weapon/wrench))
		return
	else
		..()
/obj/structure/sink/puddle/attack_hand(mob/M as mob)
	if (!dry)
		icon_state = "puddle-splash"
	..()
	if (!dry)
		icon_state = "puddle"

/obj/structure/sink/puddle/attackby(obj/item/O as obj, mob/user as mob)
	if (!dry)
		icon_state = "puddle-splash"
	..()
	if (!dry)
		icon_state = "puddle"

/obj/structure/sink/update_icon()
	..()
	if (istype(src, /obj/structure/sink/puddle))
		if (dry || volume <= 0)
			icon_state = "puddle_dry"
		else
			icon_state = "puddle"
	else if  (istype(src, /obj/structure/sink/well))
		if (dry || volume <= 0)
			icon_state = "well_dry"
		else
			icon_state = "well1"

/obj/structure/sink/New()
	..()

	if (map && map.ID == MAP_HUNT)
		mosquito_proc()

	spawn(2000)
		if (map.chad_mode)
			mosquito_proc()

/obj/structure/sink/proc/mosquito_proc()
	if (istype(src, /obj/structure/sink/puddle) || istype(src, /obj/structure/sink/well))
		if (mosquito_count < mosquito_limit && mosquito_limit != 0)
			var/mob/living/simple_animal/mosquito/NM = new/mob/living/simple_animal/mosquito(src.loc)
			NM.origin = src
			mosquito_count++
			spawn(2000)
				mosquito_proc()
		else
			spawn(2000)
				mosquito_proc()
	else
		return