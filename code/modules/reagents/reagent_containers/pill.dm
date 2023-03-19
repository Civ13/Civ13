////////////////////////////////////////////////////////////////////////////////
/// Pills.
////////////////////////////////////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/pill
	name = "pill"
	desc = "A pill."
	icon = 'icons/obj/chemical.dmi'
	icon_state = null
	item_state = "pill"
	possible_transfer_amounts = null
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_EARS
	volume = 60

	New()
		..()
		if (!icon_state)
			icon_state = "pill[rand(1, 20)]"

	attack(mob/M as mob, mob/user as mob, def_zone)
		//TODO: replace with standard_feed_mob() call.

		if (M == user)
			if (!M.can_eat(src))
				return

			M << "<span class='notice'>You swallow \the [src].</span>"
			M.drop_from_inventory(src) //icon update
			if (reagents.total_volume)
				reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
			qdel(src)
			return TRUE

		else if (istype(M, /mob/living/human))
			if (!M.can_force_feed(user, src))
				return

			user.visible_message("<span class='warning'>[user] attempts to force [M] to swallow \the [src].</span>")

			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			if (!do_mob(user, M))
				return

			user.drop_from_inventory(src) //icon update
			user.visible_message("<span class='warning'>[user] forces [M] to swallow \the [src].</span>")

			var/contained = reagentlist()
			M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been fed [name] by [key_name(user)] Reagents: [contained]</font>")
			user.attack_log += text("\[[time_stamp()]\] <font color='red'>Fed [name] to [key_name(M)] Reagents: [contained]</font>")
			msg_admin_attack("[key_name_admin(user)] fed [key_name_admin(M)] with [name] Reagents: [contained] (INTENT: [uppertext(user.a_intent)]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

			if (reagents.total_volume)
				reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
			qdel(src)

			return TRUE

		return FALSE

	afterattack(obj/target, mob/user, proximity)
		if (!proximity) return

		if (target.is_open_container() && target.reagents)
			if (!target.reagents.total_volume)
				user << "<span class='notice'>[target] is empty. Can't dissolve \the [src].</span>"
				return
			user << "<span class='notice'>You dissolve \the [src] in [target].</span>"

			user.attack_log += text("\[[time_stamp()]\] <font color='red'>Spiked \a [target] with a pill. Reagents: [reagentlist()]</font>")
			msg_admin_attack("[user.name] ([user.ckey]) spiked \a [target] with a pill. Reagents: [reagentlist()] (INTENT: [uppertext(user.a_intent)]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

			reagents.trans_to(target, reagents.total_volume)
			for (var/mob/O in viewers(2, user))
				O.show_message("<span class='warning'>[user] puts something in \the [target].</span>", TRUE)

			qdel(src)

		return

////////////////////////////////////////////////////////////////////////////////
/// Pills. END
////////////////////////////////////////////////////////////////////////////////

//Pills
/obj/item/weapon/reagent_containers/pill/antitox
	name = "Anti-toxins pill"
	desc = "Neutralizes many common toxins."
	icon_state = "pill17"
	New()
		..()
		reagents.add_reagent("anti_toxin", 25)

/obj/item/weapon/reagent_containers/pill/tox
	name = "Toxins pill"
	desc = "Highly toxic."
	icon_state = "pill5"
	New()
		..()
		reagents.add_reagent("toxin", 50)

/obj/item/weapon/reagent_containers/pill/cyanide
	name = "Cyanide pill"
	desc = "Don't swallow this."
	icon_state = "pill5"
	New()
		..()
		reagents.add_reagent("cyanide", 50)


/obj/item/weapon/reagent_containers/pill/paracetamol
	name = "Paracetamol pill"
	desc = "Also known as acetaminophen. Used to treat fever and mild to moderate pain."
	icon_state = "pill8"
	New()
		..()
		reagents.add_reagent("paracetamol", 15)

/obj/item/weapon/reagent_containers/pill/aspirin
	name = "aspirin pill"
	desc = "Also known as acetylsalicylic acid. Used to treat fever and mild to moderate pain."
	icon_state = "pill8"
	New()
		..()
		reagents.add_reagent("aspirin", 10)

/obj/item/weapon/reagent_containers/pill/sal_acid
	name = "Salicyclic Acid pill"
	desc = "Stimulates the healing of severe bruises. Extremely rapidly heals severe bruising and slowly heals minor ones. Overdose will worsen existing bruising."
	icon_state = "pill8"
	New()
		..()
		reagents.add_reagent("sal_acid", 10)

/obj/item/weapon/reagent_containers/pill/tramadol
	name = "Tramadol pill"
	desc = "A moderate painkiller."
	icon_state = "pill8"
	New()
		..()
		reagents.add_reagent("tramadol", 15)

/obj/item/weapon/reagent_containers/pill/opium
	name = "opium ball"
	desc = "A ball of dried opium. A strong painkiller."
	icon = 'icons/obj/materials.dmi'
	icon_state = "opium_extracted"
	value = 17
	New()
		..()
		reagents.add_reagent("opium", 5)

/obj/item/weapon/reagent_containers/pill/cocaine
	name = "pile of cocaine"
	desc = "A pile of very pure cocaine."
	icon = 'icons/obj/drugs.dmi'
	icon_state = "cocaine_pile"
	var/vol = 1
	value = 20
	New()
		..()
		reagents.add_reagent("cocaine", 25)
		desc = "A pile of very pure cocaine. Contains [vol] grams."

/obj/item/weapon/reagent_containers/pill/cocaine/attack_hand(mob/living/user)
	if (src == user.l_hand || src == user.r_hand)
		if (reagents.get_reagent_amount("cocaine") >= 10)
			user << "You split a line from the [src]."
			reagents.remove_reagent("cocaine",5)
			var/obj/item/weapon/reagent_containers/pill/cocaine_line/coca = new/obj/item/weapon/reagent_containers/pill/cocaine_line(user)
			user.put_in_hands(coca)
			vol = reagents.get_reagent_amount("cocaine")/25
			desc = "A pile of very pure cocaine. Contains [vol] grams."
	else
		..()

/obj/item/weapon/reagent_containers/pill/cocaine/attackby(var/obj/item/I, var/mob/user)
	if (istype(I, /obj/item/weapon/reagent_containers/pill/cocaine_line))
		user << "You put \the [I] into \the [src]."
		reagents.add_reagent("cocaine",I.reagents.get_reagent_amount("cocaine"))
		vol = reagents.get_reagent_amount("cocaine")/25
		desc = "A pile of very pure cocaine. Contains [vol] grams."
		qdel(I)
	else
		..()
/obj/item/weapon/reagent_containers/pill/cocaine_line
	name = "line of cocaine"
	desc = "A line of cocaine. Ready to go up your nose."
	icon = 'icons/obj/drugs.dmi'
	icon_state = "cocaine_line"
	value = 4
	New()
		..()
		reagents.add_reagent("cocaine", 5)

/obj/item/weapon/reagent_containers/pill/crack
	name = "crack rock"
	desc = "A rock of crack cocaine. Ready to be smoked."
	icon_state = "crack"
	value = 4
	New()
		..()
		reagents.add_reagent("crack", 5)

/obj/item/weapon/reagent_containers/pill/methylphenidate
	name = "Methylphenidate pill"
	desc = "Improves the ability to concentrate."
	icon_state = "pill8"
	New()
		..()
		reagents.add_reagent("methylphenidate", 15)

/obj/item/weapon/reagent_containers/pill/citalopram
	name = "Citalopram pill"
	desc = "Mild anti-depressant."
	icon_state = "pill8"
	New()
		..()
		reagents.add_reagent("citalopram", 15)


/obj/item/weapon/reagent_containers/pill/adrenaline
	name = "adrenaline pill"
	desc = "Used to stabilize patients."
	icon_state = "pill20"
	New()
		..()
		reagents.add_reagent("adrenaline", 30)


/obj/item/weapon/reagent_containers/pill/potassium_iodide
	name = "potassium iodide pill"
	desc = "Used to help with radiation poisoning."
	icon_state = "pill12"
	New()
		..()
		reagents.add_reagent("potassium_iodide", 10)


/obj/item/weapon/reagent_containers/pill/anti_toxin
	name = "Dylovene pill"
	desc = "A broad-spectrum anti-toxin."
	icon_state = "pill13"
	New()
		..()
		reagents.add_reagent("anti_toxin", 15)


/obj/item/weapon/reagent_containers/pill/happy
	name = "Happy pill"
	desc = "Happy happy joy joy!"
	icon_state = "pill18"
	New()
		..()
		reagents.add_reagent("peyote", 15)
		reagents.add_reagent("sugar", 15)


/obj/item/weapon/reagent_containers/pill/penicillin
	name = "penicillin pill"
	desc = "Contains antimicrobial agents."
	icon_state = "pill19"
	New()
		..()
		reagents.add_reagent("penicillin", 15)
quinine

/obj/item/weapon/reagent_containers/pill/antimalaria
	name = "Anti-Malarial pill"
	desc = "Anti-Malarial agents."
	icon_state = "pill7"
	New()
		..()
		reagents.add_reagent("quinine", 1)


//WW2

/obj/item/weapon/reagent_containers/pill/pervitin
	name = "Pervitine pill"
	desc = "Pill with powerfull stimulant. Don't eat two of these, one will be enough for you."
	icon_state = "pill16"
	New()
		..()
		reagents.add_reagent("methamphetamine", REAGENTS_OVERDOSE*0.45) // slightly less than an OD

/obj/item/weapon/reagent_containers/pill/ketamine
	name = "ketamine pill"
	desc = "You are not sure you should swallow this.. Ah why not."
	icon_state = "pill16"
	New()
		..()
		reagents.add_reagent("ketamine", REAGENTS_OVERDOSE*0.45) // slightly less than an OD

/obj/item/weapon/reagent_containers/pill/dragonpowder
	name = "dragon powder pill"
	desc = "A shiny purple pill."
	icon_state = "dragonpowder"
	New()
		..()
		reagents.add_reagent("dragon_powder", 10)
