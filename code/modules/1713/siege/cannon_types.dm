/obj/structure/cannon/modern
	name = "field cannon"
	icon = 'icons/obj/cannon.dmi'
	icon_state = "modern_cannon"
	ammotype = /obj/item/cannon_ball/shell
	spritemod = FALSE
	maxsway = 10
	firedelay = 30
	maxrange = 80
	w_class = 35

/obj/structure/cannon/modern/naval
	name = "naval cannon"
	desc = "A giant artillery cannon usually mounted on a ship."
	icon = 'icons/obj/ship_cannon.dmi'
	icon_state = "naval_cannon"
	ammotype = /obj/item/cannon_ball/shell/tank
	spritemod = FALSE
	maxsway = 40
	firedelay = 30
	maxrange = 180
	anchored = TRUE
	density = TRUE
	bound_height = 96
	bound_width = 64
	caliber = 204
	can_assemble = FALSE

/obj/structure/cannon/modern/naval/attack_hand(var/mob/attacker)
	if (ishuman(attacker) && map.ID == MAP_CAMPAIGN)
		var/mob/living/human/H = attacker
		if(findtext(H.original_job_title,"Marine"))
			attacker << "<span class = 'warning'>You do not know how to operate this gun!</span>"
			return
	else
		interact(attacker)

/obj/structure/cannon/modern/naval/n380
	name = "380mm naval cannon"
	ammotype = /obj/item/cannon_ball/shell/tank
	maxsway = 40
	firedelay = 80
	maxrange = 100
	caliber = 380
	density = FALSE

/obj/structure/cannon/modern/naval/n150
	name = "150mm naval cannon"
	ammotype = /obj/item/cannon_ball/shell/tank
	maxsway = 40
	firedelay = 50
	maxrange = 60
	caliber = 150
	density = FALSE

/obj/structure/cannon/modern/tank
	name = "tank cannon"
	desc = "a barebones cannon made to be carried by vehicles."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "tank_cannon"
	ammotype = /obj/item/cannon_ball/shell/tank
	layer = MOB_LAYER + 1 //just above mobs
	spritemod = FALSE
	maxsway = 12
	firedelay = 3
	maxrange = 25
	anchored = TRUE
	bound_height = 32
	bound_width = 32
	density = TRUE
	caliber = 75
	New()
		..()
		w_class = caliber/2

/obj/structure/cannon/modern/tank/autoloader
	name = "tank cannon with autoloader"
	desc = "a barebones cannon made to be carried by vehicles."

/obj/structure/cannon/modern/tank/voyage
	spritemod = TRUE
	w_class = ITEM_SIZE_HUGE
	maxrange = 35
	angle = 20
	caliber = 75
	name = "cannon"
	icon = 'icons/obj/cannon_v.dmi'
	density = TRUE
	icon_state = "cannon"
	bound_height = 64
	bound_width = 32
	anchored = TRUE
	ammotype = /obj/item/cannon_ball

/obj/structure/cannon/modern/tank/voyage/autofire //npc cannon
	var/stopfiring = FALSE
	attack_hand(mob/user)
		return

	New()
		..()
		do_autofire_proc()

	proc/do_autofire_proc()
		spawn(120+rand(-12,26))
			do_autofire()
			if (!stopfiring)
				do_autofire_proc()

	proc/do_autofire()
		var/found = FALSE
		for(var/mob/living/simple_animal/hostile/human/HH in range(2,src))
			if(HH.stat != DEAD && HH.fire_cannons == TRUE)
				found = TRUE
				break
		if (!found)
			return
		if (!loaded)
			var/obj/item/cannon_ball/W
			if (src.z == world.maxz)
				if (prob(25))
					W = new/obj/item/cannon_ball/chainshot(src)
				else
					if (prob(50))
						W = new/obj/item/cannon_ball/grapeshot(src)
					else
						W = new/obj/item/cannon_ball(src)
			else
				W = new/obj/item/cannon_ball(src)
			loaded = W
			angle = 13+rand(-5,5)
			sway = rand(-maxsway,maxsway)
			var/turf/TF
			switch(dir)
				if (NORTH)
					TF = locate(src.x+sway,src.y+angle,z)
				if (SOUTH)
					TF = locate(src.x-sway,src.y-angle,z)
				if (EAST)
					TF = locate(src.x+angle,src.y-sway,z)
				if (WEST)
					TF = locate(src.x-angle,src.y+sway,z)
			if (!TF)
				return FALSE

			var/obj/item/projectile/shell/S = new loaded.subtype(loc)
			S.damage = loaded.damage
			S.atype = loaded.atype
			S.caliber = loaded.caliber
			S.heavy_armor_penetration = loaded.heavy_armor_penetration
			S.name = loaded.name
			S.starting = get_turf(src)
			loaded = null
			if (S.atype == "grapeshot")
				var/tot = pick(3,4)
				for(var/i = 1, i<= tot,i++)
					var/obj/item/projectile/shell/S1 = new S.type(loc)
					S1.damage = S.damage
					S1.atype = S.atype
					S1.caliber = S.caliber
					S1.heavy_armor_penetration = S.heavy_armor_penetration
					S1.name = S.name
					S1.starting = get_turf(src)
					S1.launch(TF, null, src, rand(-2,2), 0)
			else
				S.launch(TF, null, src, 0, 0)
			// screen shake
			for (var/mob/m in player_list)
				if (m.client)
					var/abs_dist = abs(m.x - x) + abs(m.y - y)
					if (abs_dist <= 15)
						shake_camera(m, 3, (5 - (abs_dist/10)))
			// smoke
			spawn (rand(3,4))
				new/obj/effect/effect/smoke/chem(get_step(src, dir))
			spawn (rand(5,6))
				new/obj/effect/effect/smoke/chem(get_step(src, dir))
			// sound
			spawn (rand(1,2))
				var/turf/t1 = get_turf(src)
				playsound(t1, "artillery_out", 100, TRUE)
				playsound(t1, "artillery_out_distant", 100, TRUE)

/obj/structure/cannon/modern/tank/german75
	name = "7.5 cm KwK 40"
	desc = "a 75 mm german tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 12
	maxrange = 25
	caliber = 75

/obj/structure/cannon/modern/tank/american75
	name = "75 mm M3 gun"
	desc = "a 75 mm american tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 12
	maxrange = 25
	caliber = 75

/obj/structure/cannon/modern/tank/russian76/americanfield
	name = "76.2 mm M5 gun"
	desc = "a 76.2mm american Anti-tank cannon."
	icon_state = "feldkanone18"
	icon = 'icons/obj/cannon.dmi'
	maxsway = 13
	maxrange = 27
	assembled = FALSE
	can_assemble = TRUE
	New()
		..()
		loader_chair = new /obj/structure/bed/chair/loader(src)
		gunner_chair = new /obj/structure/bed/chair/gunner(src)

/obj/structure/cannon/modern/tank/japanese57
	name = "Type 90 Cannon"
	desc = "a 57 mm japanese tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 12
	maxrange = 25
	caliber = 57

/obj/structure/cannon/modern/tank/german88
	name = "8.8 cm KwK 36"
	desc = "an 88 mm german tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 14
	maxrange = 35
	caliber = 88

/obj/structure/cannon/modern/tank/omwtc10
	name = "OMW-TC 10 cm"
	desc = "a 100 mm Redmenian tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 14
	maxrange = 35
	caliber = 100

/obj/structure/cannon/modern/tank/autoloader/omwtc10
	name = "OMW-TC 10 cm"
	desc = "a 100 mm Redmenian tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 14
	maxrange = 35
	caliber = 100

/obj/structure/cannon/modern/tank/autoloader/t90a
	name = "125 mm 2A46"
	desc = "a 125 mm Russian tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 14
	maxrange = 35
	caliber = 100

/obj/structure/cannon/modern/tank/leopard
	name = "Rheinmetall 120 mm"
	desc = "a 20 mm German tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 14
	maxrange = 35
	caliber = 100

/obj/structure/cannon/modern/tank/baftkn75
	name = "BAF TKN 75mm"
	desc = "a 75 mm Blugoslavian tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 16
	maxrange = 30
	caliber = 75

/obj/structure/cannon/modern/tank/german88/field
	name = "8.8 cm Pak 43 cannon"
	desc = "a 88 mm German anti-tank cannon."
	icon_state = "feldkanone18"
	icon = 'icons/obj/cannon.dmi'
	maxsway = 18
	maxrange = 38
	assembled = FALSE
	can_assemble = TRUE
	New()
		..()
		loader_chair = new /obj/structure/bed/chair/loader(src)
		gunner_chair = new /obj/structure/bed/chair/gunner(src)

/obj/structure/cannon/modern/tank/russian122
	name = "122 mm M1943 D-25T"
	desc = "a 122 mm Russian tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 12
	maxrange = 27
	caliber = 122

/obj/structure/cannon/modern/tank/russian76
	name = "76 mm M1940 F-34"
	desc = "a 76.2 mm Russian tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 12
	maxrange = 27
	caliber = 76.2

/obj/structure/cannon/modern/tank/russian45 //low cal but fires fast
	name = "45 mm M1932 20-K"
	desc = "a 45 mm Russian tank-based fast firing cannon."
	icon_state = "tank_cannon"
	maxsway = 12
	maxrange = 25
	caliber = 45
	anchored = TRUE
	firedelay = 20

/obj/structure/cannon/modern/tank/russian45/field
	name = "45 mm anti-tank gun model 1932"
	desc = "A 45mm fast firing anti-tank cannon."
	icon_state = "feldkanone18"
	icon = 'icons/obj/cannon.dmi'
	maxsway = 18
	maxrange = 31
	firedelay = 20
	assembled = FALSE
	can_assemble = TRUE
	New()
		..()
		loader_chair = new /obj/structure/bed/chair/loader(src)
		gunner_chair = new /obj/structure/bed/chair/gunner(src)

/obj/structure/cannon/modern/tank/russian85
	name = "85 mm M1939 D5-T"
	desc = "a 85 mm Russian tank-based cannon."
	icon_state = "tank_cannon"
	maxsway = 14
	maxrange = 33
	caliber = 85
	anchored = TRUE

/obj/structure/cannon/modern/tank/russian85/su85
	desc = "a 85 mm SU-85 russian tank-based cannon."
	icon_state = "tank_cannon"
	firedelay = 35
	maxsway = 16
	maxrange = 35
	caliber = 85
	anchored = TRUE

/obj/structure/cannon/modern/tank/russian85/kv1

/obj/structure/cannon/modern/tank/russian85/field
	name = "85 mm M1939 52-K cannon"
	desc = "a 85 mm russian anti-air cannon converted for anti-tank use."
	icon_state = "feldkanone18"
	icon = 'icons/obj/cannon.dmi'
	maxsway = 18
	maxrange = 38
	assembled = FALSE
	can_assemble = TRUE
	New()
		..()
		loader_chair = new /obj/structure/bed/chair/loader(src)
		gunner_chair = new /obj/structure/bed/chair/gunner(src)

/obj/structure/cannon/mortar
	name = "mortar"
	icon = 'icons/obj/cannon_ball.dmi'
	layer = MOB_LAYER + 1 //just above mobs
	density = TRUE
	icon_state = "mortar"
	bound_height = 32
	bound_width = 32
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	ammotype = /obj/item/cannon_ball/mortar_shell
	spritemod = FALSE //if true, uses 32x64
	explosion = TRUE
	reagent_payload = "none"
	maxrange = 40
	maxsway = 7
	firedelay = 12
	w_class = 8

/obj/structure/cannon/mortar/foldable
	anchored = TRUE
	var/path

/obj/structure/cannon/mortar/foldable/type89
	name = "Type 89 Mortar"
	icon_state = "type89"
	anchored = TRUE
	ammotype = /obj/item/cannon_ball/mortar_shell/type89 || /obj/item/weapon/grenade/ww2/type91
	explosion = TRUE
	maxrange = 30
	maxsway = 10
	firedelay = 8
	w_class = ITEM_SIZE_GARGANTUAN
	path = /obj/item/weapon/foldable/type89_mortar

/obj/structure/cannon/mortar/foldable/generic
	name = "foldable mortar"
	icon_state = "mortar"
	anchored = TRUE
	ammotype = /obj/item/cannon_ball/mortar_shell
	explosion = TRUE
	maxrange = 35
	maxsway = 7
	firedelay = 12
	w_class = ITEM_SIZE_GARGANTUAN
	path = /obj/item/weapon/foldable/generic

/obj/structure/cannon/mortar/foldable/verb/Retrieve()
	set category = null
	set name = "Retrieve"
	set src in range(1, usr)
	if (usr.l_hand && usr.r_hand)
		usr << "<span class = 'warning'>You need to have a hand free to do this.</span>"
		return
	usr.face_atom(src)
	visible_message("<span class = 'warning'>[usr] starts to get the [src] from the ground.</span>")
	if (loaded)
		loaded.loc = get_turf(src)
		loaded = null
		visible_message("<span class = 'warning'>[usr] unloads the [src].</span>")
	if (do_after(usr, 25, get_turf(usr)))
		qdel(src)
		usr.put_in_any_hand_if_possible(new path, prioritize_active_hand = TRUE)
		visible_message("<span class = 'warning'>[usr] retrieves the [src] from the ground.</span>")

/obj/structure/cannon/mortar/foldable/attackby(obj/item/W as obj, mob/M as mob)
	if (istype(W, ammotype))
		if (loaded)
			M << "<span class = 'warning'>There's already a [loaded] loaded.</span>"
			return
		// load first and only slot
		if (do_after(M, 45, src, can_move = TRUE))
			if (M && (locate(M) in range(1,src)))
				M.remove_from_mob(W)
				W.loc = src
				loaded = W

/obj/structure/cannon/davycrockett
	name = "M29 Davy Crockett"
	icon = 'icons/obj/cannon.dmi'
	layer = MOB_LAYER + 1 //just above mobs
	density = TRUE
	icon_state = "m29_davy_crockett_empty"
	var/icon_state_unloaded = "m29_davy_crockett_empty"
	var/icon_state_loaded = "m29_davy_crockett_loaded"
	bound_height = 32
	bound_width = 32
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	ammotype = /obj/item/cannon_ball/rocket/nuclear
	spritemod = TRUE //if true, uses 32x64
	explosion = TRUE
	nuclear = TRUE
	reagent_payload = "none"
	maxrange = 40
	maxsway = 8
	firedelay = 24
	w_class = 8

/obj/structure/cannon/davycrockett/attackby(obj/item/W as obj, mob/M as mob)
	if (loaded)
		icon_state = "m29_davy_crockett_loaded"
	else
		icon_state = "m29_davy_crockett_empty"
