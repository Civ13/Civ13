/obj/item/weapon/reagent_containers
	name = "Container"
	desc = "..."
	icon = 'icons/obj/chemical.dmi'
	icon_state = null
	w_class = 2
	var/amount_per_transfer_from_this = 5
	var/possible_transfer_amounts = list(5,10,15,25,30)
	var/volume = 30
	secondary_action = TRUE

/obj/item/weapon/reagent_containers/verb/smell() //set amount_per_transfer_from_this
	set name = "Smell"
	set category = null
	set src in range(0)
	var/list/tastes = list() //descriptor = strength
	var/list/out = list()
	var/total_taste = FALSE
	for (var/datum/reagent/R in reagents.reagent_list)
		var/desc
		if (!R.taste_mult)
			continue
		if (R.id == "nutriment")
			var/list/t = R.get_data()
			for (var/i in TRUE to t.len)
				var/A = t[i]
				if (!(A in tastes))
					tastes.Add(A)
					tastes[A] = FALSE
				tastes[A] += t[A]
				total_taste += t[A]
			continue
		else
			desc = R.taste_description
		if (!(desc in tastes))
			tastes.Add(desc)
			tastes[desc] = FALSE
		tastes[desc] += reagents.get_reagent_amount(R.id) * R.taste_mult
		total_taste += reagents.get_reagent_amount(R.id) * R.taste_mult
	if (tastes.len)
		for (var/i in TRUE to tastes.len)
			var/size = "a hint of "
			var/percent = tastes[tastes[i]]/total_taste * 100
			if (percent > 15)
				size = ""
			else if (percent <= 15)
				continue
			out.Add("[size][tastes[i]]")
	usr << "<span class='notice'>You can smell [english_list(out,"something indescribable")].</span>" //no taste means there are too many tastes and not enough flavor.
/obj/item/weapon/reagent_containers/secondary_attack_self(mob/living/carbon/human/user)
	smell()

/obj/item/weapon/reagent_containers/verb/set_APTFT() //set amount_per_transfer_from_this
	set name = "Set transfer amount"
	set category = null
	set src in range(0)
	var/N = input("Amount per transfer from this:","[src]") as null|anything in possible_transfer_amounts
	if (N)
		amount_per_transfer_from_this = N

/obj/item/weapon/reagent_containers/New()
	..()
	if (!possible_transfer_amounts)
		verbs -= /obj/item/weapon/reagent_containers/verb/set_APTFT
	create_reagents(volume)

/obj/item/weapon/reagent_containers/attack_self(mob/user as mob)
	return

/obj/item/weapon/reagent_containers/afterattack(obj/target, mob/user, flag)
	return

/obj/item/weapon/reagent_containers/proc/reagentlist() // For attack logs
	if (reagents)
		return reagents.get_reagents()
	return "No reagent holder"

/obj/item/weapon/reagent_containers/proc/standard_dispenser_refill(var/mob/user, var/obj/structure/reagent_dispensers/target) // This goes into afterattack
	if (!istype(target))
		return FALSE

	if (!target.reagents || !target.reagents.total_volume)
		user << "<span class='notice'>[target] is empty.</span>"
		return TRUE

	if (reagents && !reagents.get_free_space())
		user << "<span class='notice'>[src] is full.</span>"
		return TRUE

	var/trans = target.reagents.trans_to_obj(src, target:amount_per_transfer_from_this)
	user << "<span class='notice'>You fill [src] with [trans] units of the contents of [target].</span>"
	playsound(loc, 'sound/effects/watersplash.ogg', 100, TRUE)
	return TRUE

/obj/item/weapon/reagent_containers/proc/standard_splash_mob(var/mob/user, var/mob/target) // This goes into afterattack
	if (!istype(target))
		return

	if (!reagents || !reagents.total_volume)
		user << "<span class='notice'>[src] is empty.</span>"
		return TRUE

	if (target.reagents && !target.reagents.get_free_space())
		user << "<span class='notice'>[target] is full.</span>"
		return TRUE

	var/contained = reagentlist()
	target.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been splashed with [name] by [user.name] ([user.ckey]). Reagents: [contained]</font>")
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>Used the [name] to splash [target.name] ([target.key]). Reagents: [contained]</font>")
	msg_admin_attack("[user.name] ([user.ckey]) splashed [target.name] ([target.key]) with [name]. Reagents: [contained] (INTENT: [uppertext(user.a_intent)]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
	var/washed = FALSE
	if (ishuman(target))
		var/mob/living/carbon/human/HT = target
		if (HT.is_nude())
			if (reagents.has_reagent("water", 30) && reagents.total_volume == reagents.get_reagent_amount("water"))
				HT.hygiene = min(HT.hygiene+(reagents.get_reagent_amount("water")),HYGIENE_LEVEL_CLEAN)
				washed = TRUE
			else
				var/dirtyness = (reagents.total_volume - reagents.get_reagent_amount("water")) / reagents.total_volume
				HT.hygiene = max(0, HT.hygiene-(dirtyness*100))
	if (washed)
		if (target == user)
			user.visible_message("<span class='notice'>[user] washes himself with \the [src]</span>", "<span class = 'notice'>You wash yourself with \the [src].</span>")
		else
			user.visible_message("<span class='notice'>[user] washes [target] with \the [src]</span>", "<span class = 'notice'>You wash [target] with \the [src].</span>")

	else
		user.visible_message("<span class='danger'>[target] has been splashed with something by [user]!</span>", "<span class = 'notice'>You splash the solution onto [target].</span>")

	reagents.splash(target, reagents.total_volume)
	return TRUE

/obj/item/weapon/reagent_containers/proc/self_feed_message(var/mob/user)
	user << "<span class='notice'>You eat \the [src]</span>"

/obj/item/weapon/reagent_containers/proc/other_feed_message_start(var/mob/user, var/mob/target)
	user.visible_message("<span class='warning'>[user] is trying to feed [target] \the [src]!</span>")

/obj/item/weapon/reagent_containers/proc/other_feed_message_finish(var/mob/user, var/mob/target)
	user.visible_message("<span class='warning'>[user] has fed [target] \the [src]!</span>")

/obj/item/weapon/reagent_containers/proc/feed_sound(var/mob/user)
	return

/obj/item/weapon/reagent_containers/proc/standard_feed_mob(var/mob/user, var/mob/target) // This goes into attack
	if (!istype(target))
		return FALSE

	if (!reagents || !reagents.total_volume)
		user << "<span class='notice'>\The [src] is empty.</span>"
		return TRUE

	if (target == user)
		if (istype(user, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = user
			if (!H.check_has_mouth())
				user << "Where do you intend to put \the [src]? You don't have a mouth!"
				return
			var/obj/item/blocked = H.check_mouth_coverage()
			if (blocked)
				user << "<span class='warning'>\The [blocked] is in the way!</span>"
				return

		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN) //puts a limit on how fast people can eat/drink things
		self_feed_message(user)
		if (reagents.has_reagent("cholera") && istype(user, /mob/living/carbon/human))
			var/mob/living/carbon/human/HH = user
			var/probcholera = reagents.get_reagent_amount("cholera")
			if (prob(min(probcholera*25,100)) && !HH.orc && !HH.crab)
				if (HH.disease == 0)
					HH.disease_progression = 0
					HH.disease_type ="cholera"
					HH.disease = 1
		reagents.trans_to_mob(user, issmall(user) ? ceil(amount_per_transfer_from_this/2) : amount_per_transfer_from_this, CHEM_INGEST)
		user.bladder += amount_per_transfer_from_this
		feed_sound(user)
		return TRUE
	else
		if (istype(target, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = target
			if (!H.check_has_mouth())
				user << "Where do you intend to put \the [src]? \The [H] doesn't have a mouth!"
				return
			var/obj/item/blocked = H.check_mouth_coverage()
			if (blocked)
				user << "<span class='warning'>\The [blocked] is in the way!</span>"
				return
			 //For pissing


		other_feed_message_start(user, target)

		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (!do_after(user, 30, target, check_for_repeats = FALSE))
			return

		other_feed_message_finish(user, target)

		var/contained = reagentlist()
		target.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been fed [name] by [user.name] ([user.ckey]). Reagents: [contained]</font>")
		user.attack_log += text("\[[time_stamp()]\] <font color='red'>Fed [name] by [target.name] ([target.ckey]). Reagents: [contained]</font>")
		msg_admin_attack("[key_name(user)] fed [key_name(target)] with [name]. Reagents: [contained] (INTENT: [uppertext(user.a_intent)]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
		if (reagents.has_reagent("cholera") && istype(target, /mob/living/carbon/human))
			var/mob/living/carbon/human/HH = target
			var/probcholera = reagents.get_reagent_amount("cholera")
			if (prob(min(probcholera*25,100)))
				if (HH.disease == 0)
					HH.disease_progression = 0
					HH.disease_type ="cholera"
					HH.disease = 1
		reagents.trans_to_mob(target, amount_per_transfer_from_this, CHEM_INGEST)
		target.bladder += amount_per_transfer_from_this
		feed_sound(user)

		return TRUE

/obj/item/weapon/reagent_containers/proc/standard_pour_into(var/mob/user, var/atom/target) // This goes into afterattack and yes, it's atom-level
	if (!target.reagents)
		return FALSE

	// Ensure we don't splash beakers and similar containers.
	if (!target.is_open_container() && istype(target, /obj/item/weapon/reagent_containers))
		user << "<span class='notice'>\The [target] is closed.</span>"
		return TRUE
	// Otherwise don't care about splashing.
	else if (!target.is_open_container())
		return FALSE

	if (!reagents || !reagents.total_volume)
		user << "<span class='notice'>[src] is empty.</span>"
		return TRUE

	if (!target.reagents.get_free_space())
		user << "<span class='notice'>[target] is full.</span>"
		return TRUE

	var/trans = reagents.trans_to(target, amount_per_transfer_from_this)
	playsound(src,'sound/effects/Liquid_transfer_mono.ogg',50,1)
	user << "<span class='notice'>You transfer [trans] units of the solution to [target].</span>"

	// fixes rags not updating names after being wet - Kachnov
	if (istype(target, /obj/item/weapon/reagent_containers/glass/rag))
		var/obj/item/weapon/reagent_containers/glass/rag/R = target
		R.update_name()

	return TRUE

