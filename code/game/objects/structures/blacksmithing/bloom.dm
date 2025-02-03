//Bloom
/obj/item/heatable/bloom
	name = "\improper bloom"
	icon = 'icons/obj/resources.dmi'
	icon_state = "bloom"
	var/iron = 1

/obj/item/heatable/bloom/updatesprites()
	icon_state = "[initial(icon_state)]-[iron]"
	..()

/obj/item/heatable/bloom/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/heatable/forged/hammer))
		var/obj/item/heatable/forged/hammer/H = I
		// Use a Handled
		if(!H.handled)
			to_chat(user, "<span class='notice'>A whole lot of good that hammer's gonna do you without a handle...</span>")
			return
		// Forge
		if(do_after(user, 15, target = src))
			//Audio
			playsound(loc, 'sound/effects/clang.ogg', 70, 1)
			//Temperature Check
			if(temperature < 700)
				to_chat(user, "<span class='italics'>You hit the bloom but it is not hot enough to forge.</span>")
				return
			//Form Ingots
			var/obj/item/heatable/ingot/wroughtiron/WI = new /obj/item/heatable/ingot/wroughtiron(loc)
			WI.temperature = temperature
			WI.updatesprites()
			iron--
			to_chat(user, "<span class='italics'>You hammer the bloom into wrought iron.</span>")
			if(iron <= 0)
				qdel(src)
				return
			return attackby(I, user, params)
	..()