/obj/item/stack/ammopart/casing/grenade/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
	
	if (istype(W, /obj/item/stack/material/iron))	//If the grenade casing is hit with iron, continue
		if (!(gunpowder >= gunpowder_max*amount))
			user << "<span class = 'notice'>You need to fill the casings with gunpowder before filling the charge.</span>"
			return
		else if (W.amount < amount)
			user << "<span class = 'notice'>Not enough iron. Add more iron to the stack.</span>"
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

				if (resultpath != null && gunpowder >= gunpowder_max && W.amount >= amount && spam_check <= 1)
					W.amount -= amount
					new resultpath(get_turf(src))
					if (W.amount <= 0)
						qdel(W)
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
			user << "You craft a chemical grenade."
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
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the booster.</span>"
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				user << "You fill the booster with gunpowder."
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the booster.</span>"
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				user << "You fill the booster with gunpowder."
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/warhead))
		if (!(gunpowder >= gunpowder_max*amount))
			user << "<span class = 'notice'>You need to fill the booster with gunpowder before attaching the charge.</span>"
			return
		else if (W.amount < amount)
			user << "<span class = 'notice'>Not enough warheads. Add more warheads to the stack.</span>"
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

			if (resultpath != null && gunpowder >= gunpowder_max)
				W.amount -= amount
				new resultpath(get_turf(src))
				if (W.amount <= 0)
					qdel(W)
				qdel(src)
				return
			else
				return

/obj/item/stack/ammopart/casing/artillery/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			user << "<span class = 'notice'>You need to fill the casing(s) with gunpowder before putting the bullet on the casing.</span>"
			return
		else if (W.amount < amount)
			user << "<span class = 'notice'>Not enough bullets. Reduce the casings stack or add more bullets.</span>"
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
			user << "<span class='notice'>You attach wires into the shell.</span>"
			new/obj/item/stack/ammopart/casing/artillery/wired(get_turf(src))
			qdel(src)
			qdel(W)
		else
			user << "<span class='notice'>You need more wires to do this.</span>"
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder >= gunpowder_max)
		make_chemical(W,user)
		return

/obj/item/stack/ammopart/casing/artillery/proc/make_chemical(var/obj/item/weapon/reagent_containers/CH, var/mob/living/user)
	for (var/reg in list("xylyl_bromide","mustard_gas","white_phosphorus_gas","chlorine","phosgene_gas","zyklon_b","napalm"))
		if (CH.reagents.has_reagent(reg, 20))
			CH.reagents.remove_reagent(reg, 20)
			user << "You craft a chemical warhead."
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
			user << "<span class='notice'>You attach electronics to the wires.</span>"
			new/obj/item/stack/ammopart/casing/artillery/wired/advanced(get_turf(src))
			qdel(src)
			qdel(W)
		else
			user << "<span class='notice'>You need at least 20 electronics to do this.</span>"

/obj/item/stack/ammopart/casing/artillery/wired/advanced/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/stack/ore/uranium))
		if (W.amount >= 10)
			playsound(loc, 'sound/machines/click.ogg', 75, TRUE)
			user << "<span class='notice'>You attach uranium to the electronics and stuff it in the casing.</span>"
			new/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled(get_turf(src))
			qdel(src)
			qdel(W)
		else
			user << "<span class='notice'>You need at least 10 uranium to do this.</span>"

/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			user << "<span class = 'notice'>You need to fill the casing(s) with gunpowder before putting the bullet on the casing.</span>"
			return
		else if (W.amount < amount)
			user << "<span class = 'notice'>Not enough bullets. Reduce the casings stack or add more bullets.</span>"
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
		user << "<span class = 'notice'>You cannot do this yet.</span>"
		return

/obj/item/stack/ammopart/casing/artillery/wired/advanced/attack_self(mob/user)
		user << "<span class = 'notice'>You cannot do this yet.</span>"
		return

/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled/attack_self(mob/user)
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		for(var/i=1;i<=amount;i++)
			new/obj/item/cannon_ball/shell/nuclear/nomads(get_turf(src))
		qdel(src)
		return
	else
		user << "<span class = 'notice'>The casing is not complete yet.</span>"
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
/obj/item/stack/ammopart/casing/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			user << "<span class = 'notice'>You need to fill the casing(s) with gunpowder before putting the bullet on the casing.</span>"
			return
		else if (W.amount < amount)
			user << "<span class = 'notice'>Not enough bullets. Reduce the casings stack or add more bullets.</span>"
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
/obj/item/stack/ammopart/casing/artillery/attack_self(mob/user)
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		for(var/i=1;i<=amount;i++)
			new/obj/item/cannon_ball/shell(get_turf(src))
		user << "You produce HE artillery shells."
		qdel(src)
		return
	else
		user << "<span class = 'notice'>The casing is not complete yet.</span>"
		return

/obj/item/stack/ammopart/casing/pistol/attack_self(mob/user)
	switch (map.ID)
		if (MAP_OCCUPATION)
			if (gunpowder >= gunpowder_max && bulletn >= amount)
				var/list/listing = list("Cancel")
				if (map.ordinal_age == 4)
					listing += list(".45 Colt", ".44-40 Winchester", ".41 Short")
				else if (map.ordinal_age == 5)
					listing += list("9x19 Parabellum", "9x18 Makarov", ".45 Colt")
				else if (map.ordinal_age == 6)
					listing += list("9x19 Parabellum", "9x18 Makarov", "7.62x25mm", "7.62x38mmR")
				else if (map.ordinal_age >= 7)
					listing += list("9x19 Parabellum", "9x18 Makarov", "7.62x25mm", "7.62x38mmR")
				var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
				switch (input)
					if ("Cancel")
						return
					if (".41 Short")
						resultpath = /obj/item/ammo_casing/a41
					if (".45 Colt")
						resultpath = /obj/item/ammo_casing/a45
					if (".44-40 Winchester")
						resultpath = /obj/item/ammo_casing/a44
					if ("9x19 Parabellum")
						resultpath = /obj/item/ammo_casing/a9x19
					if ("9x18 Makarov")
						resultpath = /obj/item/ammo_casing/a9x18
					if ("7.62x25mm")
						resultpath = /obj/item/ammo_casing/a762x25
					if ("7.62x38mmR")
						resultpath = /obj/item/ammo_casing/a762x38

				if (resultpath != null)
					for(var/i=1;i<=amount;i++)
						new resultpath(get_turf(src))
					qdel(src)
					return
				else
					return
			else
				user << "<span class = 'notice'>The casing is not complete yet.</span>"
				return
		if (MAP_NOMADS_KARAFUTO)
			if (gunpowder >= gunpowder_max && bulletn >= amount)
				var/list/listing = list("Cancel")
				if (map.ordinal_age == 4)
					listing += list(".45 Colt", ".44-40 Winchester", ".41 Short")
				else if (map.ordinal_age == 5)
					listing += list("9x19 Parabellum", "9x18 Makarov", ".45 Colt")
				else if (map.ordinal_age == 6)
					listing += list("9x19 Parabellum", "9x18 Makarov", "8x22mmB nambu", "9x22mm nambu", "7.62x38mmR", ".45 Colt")
				else if (map.ordinal_age >= 7)
					listing += list("9x19 Parabellum", "9x18 Makarov", ".45 Colt", "8x22mmB nambu", "9x22mm nambu", "7.62x38mmR")
				var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
				switch (input)
					if ("Cancel")
						return
					if (".41 Short")
						resultpath = /obj/item/ammo_casing/a41
					if (".45 Colt")
						resultpath = /obj/item/ammo_casing/a45
					if (".44-40 Winchester")
						resultpath = /obj/item/ammo_casing/a44
					if ("9x19 Parabellum")
						resultpath = /obj/item/ammo_casing/a9x19
					if ("9x18 Makarov")
						resultpath = /obj/item/ammo_casing/a9x18
					if ("8x22mmB nambu")
						resultpath = /obj/item/ammo_casing/c8mmnambu
					if ("9x22mm nambu")
						resultpath = /obj/item/ammo_casing/c9mm_jap_revolver
					if ("7.62x38mmR")
						resultpath = /obj/item/ammo_casing/a762x38

				if (resultpath != null)
					for(var/i=1;i<=amount;i++)
						new resultpath(get_turf(src))
					qdel(src)
					return
				else
					return
			else
				user << "<span class = 'notice'>The casing is not complete yet.</span>"
				return
		else
			if (gunpowder >= gunpowder_max && bulletn >= amount)
				var/list/listing = list("Cancel")
				if (map.ordinal_age == 4)
					listing += list(".45 Colt", ".44-40 Winchester", ".41 Short")
				else if (map.ordinal_age == 5)
					listing += list("9x19 Parabellum", "9x18 Makarov", ".45 Colt")
				else if (map.ordinal_age == 6)
					listing += list("9x19 Parabellum", "9x18 Makarov", ".45 Colt")
				else if (map.ordinal_age >= 7)
					listing += list("9x19 Parabellum", "9x18 Makarov", ".45 Colt")
				var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
				switch (input)
					if ("Cancel")
						return
					if (".41 Short")
						resultpath = /obj/item/ammo_casing/a41
					if (".45 Colt")
						resultpath = /obj/item/ammo_casing/a45
					if (".44-40 Winchester")
						resultpath = /obj/item/ammo_casing/a44
					if ("9x19 Parabellum")
						resultpath = /obj/item/ammo_casing/a9x19
					if ("9x18 Makarov")
						resultpath = /obj/item/ammo_casing/a9x18

				if (resultpath != null)
					for(var/i=1;i<=amount;i++)
						new resultpath(get_turf(src))
					qdel(src)
					return
				else
					return
			else
				user << "<span class = 'notice'>The casing is not complete yet.</span>"
				return

/obj/item/stack/ammopart/casing/rifle/attack_self(mob/user)
	if (map.ID == MAP_OCCUPATION)
		if (gunpowder >= gunpowder_max && bulletn >= amount)
			var/list/listing = list("Cancel")
			if (map.ordinal_age >= 6)
				listing += list("7.92x57mm Mauser", "7.62x54mmR", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)", "12 Gauge (Beanbag)", "12 Gauge (Rubbershot)")

			var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
			switch (input)
				if ("Cancel")
					return
				if ("12 Gauge (Buckshot)")
					resultpath = /obj/item/ammo_casing/shotgun/buckshot
				if ("12 Gauge (Slugshot)")
					resultpath = /obj/item/ammo_casing/shotgun/slug
				if ("12 Gauge (Beanbag)")
					resultpath = /obj/item/ammo_casing/shotgun/beanbag
				if ("12 Gauge (Rubbershot)")
					resultpath = /obj/item/ammo_casing/shotgun/rubber
				if ("7.92x57mm Mauser")
					resultpath = /obj/item/ammo_casing/a792x57
				if ("7.62x54mmR")
					resultpath = /obj/item/ammo_casing/a762x54

			if (resultpath != null && gunpowder >= gunpowder_max && bulletn >= amount)
				for(var/i=1;i<=amount;i++)
					var/obj/item/ammo_casing/NC = new resultpath(get_turf(src))
					NC.btype = inputbtype
					NC.checktype()
				qdel(src)
				return
			else
				return
		else
			user << "<span class = 'notice'>The casing is not complete yet.</span>"
			return
	else if (map.ID == MAP_NOMADS_KARAFUTO)
		if (gunpowder >= gunpowder_max && bulletn >= amount)
			var/list/listing = list("Cancel")
			if (map.ordinal_age == 4)
				listing += list("8x53mm murata", "7.62x54mmR", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)", "12 Gauge (Beanbag)")
			if (map.ordinal_age == 5)
				listing += list("8x53mm murata", "7.62x54mmR","6.5x50mm arisaka", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)", "12 Gauge (Beanbag)", "12 Gauge (Rubbershot)")
			if (map.ordinal_age >= 6)
				listing += list("7.7x58mm arisaka","7.62x54mmR","6.5x50mm arisaka", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)", "12 Gauge (Beanbag)", "12 Gauge (Rubbershot)")

			var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
			switch (input)
				if ("Cancel")
					return
				if ("12 Gauge (Buckshot)")
					resultpath = /obj/item/ammo_casing/shotgun/buckshot
				if ("12 Gauge (Slugshot)")
					resultpath = /obj/item/ammo_casing/shotgun/slug
				if ("12 Gauge (Beanbag)")
					resultpath = /obj/item/ammo_casing/shotgun/beanbag
				if ("12 Gauge (Rubbershot)")
					resultpath = /obj/item/ammo_casing/shotgun/rubber
				if ("8x53mm murata")
					resultpath = /obj/item/ammo_casing/a8x53
				if ("7.62x54mmR")
					resultpath = /obj/item/ammo_casing/a762x54
				if ("6.5x50mm arisaka")
					resultpath = /obj/item/ammo_casing/a65x50
				if ("7.7x58mm arisaka")
					resultpath = /obj/item/ammo_casing/a77x58
				
			if (resultpath != null && gunpowder >= gunpowder_max && bulletn >= amount)
				for(var/i=1;i<=amount;i++)
					var/obj/item/ammo_casing/NC = new resultpath(get_turf(src))
					NC.btype = inputbtype
					NC.checktype()
				qdel(src)
				return
			else
				return
		else
			user << "<span class = 'notice'>The casing is not complete yet.</span>"
			return
	else
		if (gunpowder >= gunpowder_max && bulletn >= amount)
			var/list/listing = list("Cancel")
			if (map.ordinal_age == 4)
				listing += list(".44-70 Government", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)",".577/450 Martini-Henry","7.65x53 Mauser")
			else if (map.ordinal_age == 5)
				listing += list("7.92x57mm Mauser","6.5x50mm small rifle","7.62x39mm intermediate rifle","5.56x45mm intermediate rifle", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)", "12 Gauge (Beanbag)", "12 Gauge (Rubbershot)")
			else if (map.ordinal_age >= 6)
				listing += list("7.92x57mm Mauser","6.5x50mm small rifle","7.62x39mm intermediate rifle","5.56x45mm intermediate rifle", "12 Gauge (Buckshot)", "12 Gauge (Slugshot)", "12 Gauge (Beanbag)", "12 Gauge (Rubbershot)")

			var/input = WWinput(user, "What caliber do you want to make?", "Bullet Making", "Cancel", listing)
			switch (input)
				if ("Cancel")
					return
				if (".44-70 Government")
					resultpath = /obj/item/ammo_casing/a4570
				if (".577/450 Martini-Henry")
					resultpath = /obj/item/ammo_casing/a577
				if ("12 Gauge (Buckshot)")
					resultpath = /obj/item/ammo_casing/shotgun/buckshot
				if ("12 Gauge (Slugshot)")
					resultpath = /obj/item/ammo_casing/shotgun/slug
				if ("12 Gauge (Beanbag)")
					resultpath = /obj/item/ammo_casing/shotgun/beanbag
				if ("12 Gauge (Rubbershot)")
					resultpath = /obj/item/ammo_casing/shotgun/rubber
				if ("7.65x53 Mauser")
					resultpath = /obj/item/ammo_casing/a765x53
					inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
				if ("7.92x57mm Mauser")
					resultpath = /obj/item/ammo_casing/a792x57
					inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
				if ("6.5x50mm small rifle")
					resultpath = /obj/item/ammo_casing/a65x50
					inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
				if ("7.62x39mm intermediate rifle")
					resultpath = /obj/item/ammo_casing/a762x39
					inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))
				if ("5.56x45mm intermediate rifle")
					resultpath = /obj/item/ammo_casing/a556x45
					inputbtype = WWinput(user, "Normal, Hollow Point or Armor Piercing?", "Bullet Making", "Normal", list("normal","AP","HP"))

			if (resultpath != null && gunpowder >= gunpowder_max && bulletn >= amount)
				for(var/i=1;i<=amount;i++)
					var/obj/item/ammo_casing/NC = new resultpath(get_turf(src))
					NC.btype = inputbtype
					NC.checktype()
				qdel(src)
				return
			else
				return
		else
			user << "<span class = 'notice'>The casing is not complete yet.</span>"
			return

/obj/item/stack/ammopart/attack_self(mob/user)
	if (istype(src, /obj/item/stack/ammopart/bullet) || istype(src, /obj/item/stack/ammopart/casing/pistol) || istype(src, /obj/item/stack/ammopart/casing/rifle))
		return
	if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
		if (!user.l_hand.reagents.has_reagent("gunpowder",1))
			user << "<span class = 'warning'>You need enough gunpowder in the container to make a cartridge.</span>"
			return
		else if (user.l_hand.reagents.has_reagent("gunpowder",1))
			user.l_hand.reagents.remove_reagent("gunpowder",1)
			user << "You make a cartridge with the gunpowder and projectile."
			new resultpath(get_turf(src))
			if (user.r_hand.amount>1)
				user.r_hand.amount -= 1
			else
				qdel(user.r_hand)
			return

	else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
		if (!user.r_hand.reagents.has_reagent("gunpowder",1))
			user << "<span class = 'warning'>You need enough gunpowder in the container to make a cartridge.</span>"
			return
		else if (user.r_hand.reagents.has_reagent("gunpowder",1))
			user.r_hand.reagents.remove_reagent("gunpowder",1)
			user << "You make a cartridge with the gunpowder and projectile."
			new resultpath(get_turf(src))
			if (user.l_hand.amount>1)
				user.l_hand.amount -= 1
			else
				qdel(user.l_hand)
			return

	else
		user << "<span class = 'warning'>You need enough gunpowder in the container to make a cartridge.</span>"
		return

/obj/item/stack/ammopart/casing/tank/attackby(obj/item/W as obj, mob/user as mob)
	if (!istype(W)) return
	if (istype(W, /obj/item/weapon/reagent_containers) && gunpowder < gunpowder_max*amount)
		if (istype(user.l_hand, /obj/item/weapon/reagent_containers))
			if (!user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.l_hand.reagents.has_reagent("gunpowder",gunpowder_max*amount))
				user.l_hand.reagents.remove_reagent("gunpowder",gunpowder_max*amount)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
		else if (istype(user.r_hand, /obj/item/weapon/reagent_containers))
			if (!user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user << "<span class = 'notice'>You need enough gunpowder in the container to fill the casing(s).</span>"
				return
			else if (user.r_hand.reagents.has_reagent("gunpowder",gunpowder_max))
				user.r_hand.reagents.remove_reagent("gunpowder",gunpowder_max)
				user << "You fill the casings with gunpowder."
				gunpowder = gunpowder_max*amount
				return
	if (istype(W, /obj/item/stack/ammopart/bullet))
		if (!(gunpowder >= gunpowder_max*amount))
			user << "<span class = 'notice'>You need to fill the casing(s) with gunpowder before putting the bullet on the casing.</span>"
			return
		else if (W.amount < amount)
			user << "<span class = 'notice'>Not enough bullets. Reduce the casings stack or add more bullets.</span>"
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
	if (gunpowder >= gunpowder_max && bulletn >= amount)
		for(var/i=1;i<=amount;i++)
			var/calibt = WWinput(user, "Which type of shell do you want to craft?", "Shell Crafting", "HE", list("HE", "AP", "APCR"))
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

		user << "You produce [caliber]mm shells."
		qdel(src)
		return
	else
		user << "<span class = 'notice'>The casing is not complete yet.</span>"
		return