/obj/item/stack/ammopart/casing/grenade/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
	
	if (istype(W, /obj/item/stack/material/iron))	//If the grenade casing is hit with iron, continue
		if (!(gunpowder >= gunpowder_max*amount))
			to_chat(user, "<span class = 'notice'>You need to fill the casings with gunpowder before filling the charge.</span>")
			return
		else if (W.amount < amount)
			to_chat(user, "<span class = 'notice'>Not enough iron. Add more iron to the stack.</span>")
			return
		else if (W.amount >= amount)
			var/spam_check = 0
			var/list/listing = list("Cancel")
			listing += list(/*"Explosive"*/, "Anti-Tank", "Shrapnel")

			if (spam_check <= 1)	
				var/input = WWinput(user, "What grenade do you want to make?", "Grenade Making", "Cancel", listing)
				switch (input)
					if ("Cancel")
						spam_check--
						return
					/*
					if ("Explosive")
						resultpath = /obj/item/weapon/grenade/coldwar/nonfrag/custom
					*/
					if ("Anti-Tank")
						resultpath = /obj/item/weapon/grenade/antitank/custom
						spam_check++
					if ("Shrapnel")
						resultpath = /obj/item/weapon/grenade/modern/custom
						spam_check++

				// The menu sleeps: a lagged repeat click must not reuse a casing
				// that the first answer already turned into a grenade.
				if (resultpath != null && gunpowder >= gunpowder_max && spam_check <= 1 && !QDELETED(src) && !QDELETED(W) && W.loc == user && ammo_part_stack_use(W, amount))
					new resultpath(get_turf(src))
					qdel(src)
					spam_check--
					return
				else
					return
			else
				return
	
	if (gunpowder >= gunpowder_max*amount && finished)
		attack_self(user)
		return

	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder >= gunpowder_max)
		make_chemical(W,user)
		return

/obj/item/stack/ammopart/casing/grenade/proc/make_chemical(var/obj/item/weapon/reagent_containers/CH, var/mob/living/user)
	for (var/reg in list("xylyl_bromide","mustard_gas","white_phosphorus_gas","chlorine","phosgene_gas","zyklon_b", "hexachloroetane", "napalm", "magnesium"))
		if (CH.reagents.has_reagent(reg, 10))
			CH.reagents.remove_reagent(reg, 10)
			to_chat(user, "You craft a chemical grenade.")
			reg = replacetext(reg,"_gas","")
			switch (reg)
				if ("hexachloroetane")
					var/resultp = text2path("/obj/item/weapon/grenade/smokebomb")
					new resultp(get_turf(src))
				if ("napalm")
					var/resultp = text2path("/obj/item/weapon/grenade/incendiary")
					new resultp(get_turf(src))
				if ("magnesium")
					var/resultp = text2path("/obj/item/weapon/grenade/flashbang")
					new resultp(get_turf(src))
				else
					var/resultp = text2path("/obj/item/weapon/grenade/chemical/[reg]")
					new resultp(get_turf(src))
			if (amount <= 1)
				qdel(src)
			else
				amount--
			return
	return

//Rockets!
/obj/item/stack/ammopart/casing/booster/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the booster.</span>")
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the booster with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the booster.</span>")
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				to_chat(user, "You fill the booster with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/warhead))
		if (!(gunpowder >= gunpowder_max*amount))
			to_chat(user, "<span class = 'notice'>You need to fill the booster with gunpowder before attaching the charge.</span>")
			return
		else if (W.amount < amount)
			to_chat(user, "<span class = 'notice'>Not enough warheads. Add more warheads to the stack.</span>")
		else if (W.amount >= amount)
			var/list/listing = list("Cancel")
			listing += list("HEAT", "Fragmentation")

			var/input = WWinput(user, "What warhead do you want to make?", "Rocket Propeled Grenade Making", "Cancel", listing)
			switch (input)
				if ("Cancel")
					return
				if ("HEAT")
					resultpath = /obj/item/ammo_casing/rocket/pg7v
				if ("Fragmentation")
					resultpath = /obj/item/ammo_casing/rocket/og7v

			// The menu sleeps: a lagged repeat click must not reuse a booster or
			// warheads that the first answer already spent.
			if (resultpath != null && gunpowder >= gunpowder_max && !QDELETED(src) && !QDELETED(W) && W.loc == user && ammo_part_stack_use(W, amount))
				new resultpath(get_turf(src))
				qdel(src)
				return
			else
				return

/obj/item/stack/ammopart/casing/artillery/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			to_chat(user, "<span class = 'notice'>You need to fill the casing(s) with gunpowder before putting the bullet on the casing.</span>")
			return
		else if (W.amount < amount)
			to_chat(user, "<span class = 'notice'>Not enough bullets. Reduce the casings stack or add more bullets.</span>")
			return
		else if (W.amount >= amount)
			bulletn = amount
			W.amount -= amount
			if (W.amount <= 0)
				qdel(W)
	if (gunpowder >= gunpowder_max*amount && bulletn >= amount)
		attack_self(user)
		return

	if (istype(W, /obj/item/stack/cable_coil/))
		if (W.amount >= 5)
			playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
			to_chat(user, "<span class='notice'>You attach wires into the shell.</span>")
			new/obj/item/stack/ammopart/casing/artillery/wired(get_turf(src))
			qdel(src)
			qdel(W)
		else
			to_chat(user, "<span class='notice'>You need more wires to do this.</span>")
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder >= gunpowder_max)
		make_chemical(W,user)
		return

/obj/item/stack/ammopart/casing/artillery/proc/make_chemical(var/obj/item/weapon/reagent_containers/CH, var/mob/living/user)
	for (var/reg in list("xylyl_bromide","mustard_gas","white_phosphorus_gas","chlorine","phosgene_gas","zyklon_b","napalm"))
		if (CH.reagents.has_reagent(reg, 20))
			CH.reagents.remove_reagent(reg, 20)
			to_chat(user, "You craft a chemical warhead.")
			reg = replacetext(reg,"_gas","")
			switch (reg)
				if ("napalm")
					var/resultp = text2path("/obj/item/cannon_ball/shell/incendiary")
					new resultp(get_turf(src))
				else
					var/resultp = text2path("/obj/item/cannon_ball/shell/gas/[reg]")
					new resultp(get_turf(src))
			if (amount <= 1)
				qdel(src)
			else
				amount--
			return
	return

/obj/item/stack/ammopart/casing/artillery/wired/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/material/electronics))
		if (W.amount >= 20)
			playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
			to_chat(user, "<span class='notice'>You attach electronics to the wires.</span>")
			new/obj/item/stack/ammopart/casing/artillery/wired/advanced(get_turf(src))
			qdel(src)
			qdel(W)
		else
			to_chat(user, "<span class='notice'>You need at least 20 electronics to do this.</span>")

/obj/item/stack/ammopart/casing/artillery/wired/advanced/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/ore/uranium))
		if (W.amount >= 10)
			playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
			to_chat(user, "<span class='notice'>You attach uranium to the electronics and stuff it in the casing.</span>")
			new/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled(get_turf(src))
			qdel(src)
			qdel(W)
		else
			to_chat(user, "<span class='notice'>You need at least 10 uranium to do this.</span>")

/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			to_chat(user, "<span class = 'notice'>You need to fill the casing(s) with gunpowder before putting the bullet on the casing.</span>")
			return
		else if (W.amount < amount)
			to_chat(user, "<span class = 'notice'>Not enough bullets. Reduce the casings stack or add more bullets.</span>")
			return
		else if (W.amount >= amount)
			bulletn = amount
			W.amount -= amount
			if (W.amount <= 0)
				qdel(W)
	if (gunpowder >= gunpowder_max*amount && bulletn >= amount)
		attack_self(user)
		return
	else
		return

/obj/item/stack/ammopart/casing/artillery/wired/attack_self(mob/user)
		to_chat(user, "<span class = 'notice'>You cannot do this yet.</span>")
		return

/obj/item/stack/ammopart/casing/artillery/wired/advanced/attack_self(mob/user)
		to_chat(user, "<span class = 'notice'>You cannot do this yet.</span>")
		return

/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled/attack_self(mob/user)
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		for(var/i=1;i<=amount;i++)
			new/obj/item/cannon_ball/shell/nuclear/nomads(get_turf(src))
		qdel(src)
		return
	else
		to_chat(user, "<span class = 'notice'>The casing is not complete yet.</span>")
		return

/obj/item/stack/ammopart/bullet
	name = "iron bullet"
	desc = "A molded iron bullet, made to fit in a casing."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "ironbullet"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	resultpath = null
	max_amount = 60
	singular_name = "bullet"
	value = 1
	weight = 0.08
/obj/item/stack/ammopart/casing/artillery/attack_self(mob/user)
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		for(var/i=1;i<=amount;i++)
			new/obj/item/cannon_ball/shell(get_turf(src))
		to_chat(user, "You produce HE artillery shells.")
		qdel(src)
		return
	else
		to_chat(user, "<span class = 'notice'>The casing is not complete yet.</span>")
		return

/obj/item/stack/ammopart/attack_self(mob/user)
	if (istype(src, /obj/item/stack/ammopart/bullet) || istype(src, /obj/item/stack/ammopart/casing/pistol) || istype(src, /obj/item/stack/ammopart/casing/rifle))
		return
	if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
		if (!user.l_hand.reagents.has_reagent("gunpowder",1))
			to_chat(user, "<span class = 'warning'>You need enough gunpowder in the container to make a cartridge.</span>")
			return
		else if (user.l_hand.reagents.has_reagent("gunpowder",1))
			user.l_hand.reagents.remove_reagent("gunpowder",1)
			to_chat(user, "You make a cartridge with the gunpowder and projectile.")
			new resultpath(get_turf(src))
			if (user.r_hand.amount>1)
				user.r_hand.amount -= 1
			else
				qdel(user.r_hand)
			return

	else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
		if (!user.r_hand.reagents.has_reagent("gunpowder",1))
			to_chat(user, "<span class = 'warning'>You need enough gunpowder in the container to make a cartridge.</span>")
			return
		else if (user.r_hand.reagents.has_reagent("gunpowder",1))
			user.r_hand.reagents.remove_reagent("gunpowder",1)
			to_chat(user, "You make a cartridge with the gunpowder and projectile.")
			new resultpath(get_turf(src))
			if (user.l_hand.amount>1)
				user.l_hand.amount -= 1
			else
				qdel(user.l_hand)
			return

	else
		to_chat(user, "<span class = 'warning'>You need enough gunpowder in the container to make a cartridge.</span>")
		return

/obj/item/stack/ammopart/casing/tank/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				to_chat(user, "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>")
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				to_chat(user, "You fill the casings with gunpowder.")
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			to_chat(user, "<span class = 'notice'>You need to fill the casing(s) with gunpowder before putting the bullet on the casing.</span>")
			return
		else if (W.amount < amount)
			to_chat(user, "<span class = 'notice'>Not enough bullets. Reduce the casings stack or add more bullets.</span>")
			return
		else if (W.amount >= amount)
			bulletn = amount
			W.amount -= amount
			if (W.amount <= 0)
				qdel(W)
	if (gunpowder >= gunpowder_max*amount && bulletn >= amount)
		attack_self(user)
		return

/obj/item/stack/ammopart/casing/tank/attack_self(mob/user)
	// Each shell asks a question that sleeps; a lagged repeat click must not
	// start a second round of shells from the same casings.
	if (crafting_shells)
		return
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		crafting_shells = TRUE
		for(var/i=1;i<=amount;i++)
			var/calibt = WWinput(user, "Which type of shell do you want to craft?", "Shell Crafting", "HE", list("HE", "AP", "APCR"))
			if (QDELETED(src) || loc != user)
				crafting_shells = FALSE
				return
			switch (calibt)
				if ("HE")
					var/obj/item/cannon_ball/shell/tank/TS = new/obj/item/cannon_ball/shell/tank(get_turf(user))
					TS.atype = "HE"
					TS.caliber = caliber
					TS.heavy_armor_penetration = 15*(caliber/75)
					TS.damage = 250*(caliber/75)
					TS.icon_state = "shellHE"
					TS.name = "[caliber]mm [calibt] shell"
					TS.update_icon()
				if ("AP")
					var/obj/item/cannon_ball/shell/tank/TS = new/obj/item/cannon_ball/shell/tank(get_turf(user))
					TS.atype = "AP"
					TS.caliber = caliber
					TS.heavy_armor_penetration = 52*(caliber/75)
					TS.damage = 100*(caliber/75)
					TS.icon_state = "shellAP"
					TS.name = "[caliber]mm [calibt] shell"
					TS.update_icon()
				if ("APCR")
					var/obj/item/cannon_ball/shell/tank/TS = new/obj/item/cannon_ball/shell/tank(get_turf(user))
					TS.atype = "APCR"
					TS.caliber = caliber
					TS.heavy_armor_penetration = 75*(caliber/75)
					TS.damage = 75*(caliber/75)
					TS.icon_state = "shellAPCR"
					TS.name = "[caliber]mm [calibt] shell"
					TS.update_icon()

		crafting_shells = FALSE
		to_chat(user, "You produce [caliber]mm shells.")
		qdel(src)
		return
	else
		to_chat(user, "<span class = 'notice'>The casing is not complete yet.</span>")
		return
// Spends n items from a stack used on an ammo part; FALSE if it is short now.
/proc/ammo_part_stack_use(obj/item/stack/S, n)
	return istype(S) && S.use(n)

/obj/item/stack/ammopart/casing/tank
	var/tmp/crafting_shells = FALSE
