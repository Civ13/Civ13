////////////////////////////////////////
/* Superclass of All Heatable Objects */
////////////////////////////////////////
// Blacksmithing by Fulminating Gold. //

/obj/item/heatable
	name = "Parent Object (Debug)"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "wrought_iron"
	item_state = "sheet-metal"
	var/temperature = 20

/obj/item/heatable/New()
	updatesprites()
	processing_objects |= src
	..()

/obj/item/heatable/afterattack(atom/target, mob/user, proximity_flag)
	if(!proximity_flag)
		return ..()
	if(istype(target, /obj/item/weapon/reagent_containers) && temperature > 100)
		var/obj/item/weapon/reagent_containers/B = target
		var/check = FALSE
		for(var/reagent in B.reagents.reagent_list)
			var/datum/reagent/R = reagent
			if(R.id == "bwater" || R.id == "water" || R.id == "dwater")
				check = TRUE
				break
		if(check)
			if(temperature > 500 && istype(src, /obj/item/heatable/forged))
				var/obj/item/heatable/forged/F = src
				F.quenched = TRUE
				F.updatestats()
			to_chat(user, "<span class='italics'>You cool the [src].</span>")
			temperature = 100
			playsound(loc, 'sound/machines/hiss.ogg', 70, 1)
			updatesprites()
			return
	..()

/obj/item/heatable/attack_hand(mob/living/user)
	if(temperature > 100)
		to_chat(user, "<span class='warning italics'>You burn your hands on \the [src].</span>")
		playsound(loc, 'sound/machines/hiss.ogg', 70, 1)
		user.apply_damage(rand(1, 8), BURN, (user.hand ? "l_hand" : "r_hand"))
	else
		..()

/obj/item/heatable/proc/updatesprites()
	icon = initial(icon)
	if(temperature > 460)
		var/p = min((temperature - 460) / 840, 1) //460C -> red hot | 1300 -> white hot
		icon += rgb(400*p, 250*p*p, 150*p*p)

/obj/item/heatable/process()
	if(temperature <= 20)
		processing_objects -= src
		return
	temperature -= round(temperature * 0.025)
	updatesprites()

/obj/item/heatable/examine(mob/user)
	..()
	if(temperature > 100)
		to_chat(user, "<span class='warning'>Looks hot!</span>")