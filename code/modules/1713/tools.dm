/*****************************Shovel********************************/
/obj/item/weapon/plough
	name = "plough"
	desc = "A simple wood plough. Use it on dirt to plough farming areas."
	icon = 'icons/obj/items.dmi'
	icon_state = "plough"
	flags = CONDUCT
	force = 4.0
	throwforce = 3.0
	item_state = "plough"
	w_class = ITEM_SIZE_NORMAL
	flags = FALSE

	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	slot_flags = SLOT_BELT
	flammable = TRUE
	var/usespeed = 1.5

/obj/item/weapon/plough/attack_self(var/mob/living/L)
	var/turf/T = get_turf(L)
	T.attackby(src,L)
	return

/obj/item/weapon/plough/iron
	name = "iron plough"
	desc = "A sturdy iron plough. Use it on dirt to plough the land."
	icon = 'icons/obj/items.dmi'
	icon_state = "iplough"
	item_state = "iplough"
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = TRUE
	usespeed = 2.1
	flags = CONDUCT

/obj/item/weapon/foldable
	force = 12
	nothrow = TRUE
	w_class = ITEM_SIZE_GARGANTUAN
	sharp = FALSE
	edge = FALSE
	slot_flags = null
	attack_verb = list("bashed", "bludgeoned")
	var/path

/obj/item/weapon/foldable/attack_self(var/mob/user as mob)
	var/target = get_step(user, user.dir)
	if (target)
		user.visible_message("<span class='warning'>[user] starts to deploy the [src].</span>", "<span class='notice'>You start to deploy the [src].</span>", "<span class='warning'>You feel something being deployed nearby.</span>")
		if (do_after(user, 25, get_turf(user)))
			user.visible_message("<span class='warning'>[user] deploys the [src].</span>", "<span class='notice'>You deploy the [src].</span>", "<span class='warning'>You hear the sound of something being deployed nearby.</span>")
			var/atom/A = new path(get_turf(src))
			A.dir = user.dir
			user.remove_from_mob(src)
			qdel(src)

/obj/item/weapon/foldable/generic
	name = "Foldable Mortar"
	desc = "A light-weight portable mortar."
	icon_state = "mortar"
	item_state = "type89"
	path = /obj/structure/cannon/mortar/foldable/generic

/obj/item/weapon/foldable/type89_mortar
	name = "Type 89 Mortar"
	desc = "A light-weight portable mortar."
	icon_state = "type89"
	item_state = "type89"
	path = /obj/structure/cannon/mortar/foldable/type89

/obj/item/weapon/foldable/atgm
	name = "Anti-Tank Guided Missile system"
	desc = "A light-weight portable ATGM."
	icon_state = "atgm"
	item_state = "atgm"
	path = /obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable

/obj/item/weapon/foldable/atgm/kornet
	name = "Foldable 9K135 Kornet"
	desc = "A highly accurate, Russian laser-guided anti-tank missile system with long-range capabilities and advanced armor penetration, designed for modern battlefield engagements."
	icon_state = "kornet_atgm"
	item_state = "kornet_atgm"
	path = /obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable/kornet

/obj/item/weapon/foldable/atgm/bgm_tow
	name = "Foldable BGM-71 TOW"
	desc = "A wire-guided anti-tank missile, known for its effectiveness against armored vehicles at long distances."
	icon_state = "bgm71_tow_atgm"
	item_state = "bgm71_tow_atgm"
	path = /obj/item/weapon/gun/projectile/automatic/stationary/atgm/foldable/bgm_tow

/obj/item/weapon/foldable/pkm
	name = "Foldable PKM machine gun"
	desc = "A soviet machinegun chambered in 7.62x54mmR rounds."
	icon_state = "foldable_pkm"
	item_state = "foldable_pkm"
	force = 20
	throwforce = 30
	weight = 9.5
	w_class = ITEM_SIZE_HUGE
	slowdown = 0.3
	slot_flags = SLOT_SHOULDER|SLOT_BACK
	path = /obj/item/weapon/gun/projectile/automatic/stationary/foldable/pkm

/obj/item/weapon/foldable/hescokit
	name = "HESCO bastion kit"
	desc = "A collapsible wire mesh container filled with locally sourced materials. Very sturdy, also can't be removed after being deployed."
	icon_state = "bastionkit"
	item_state = "ammo_can"
	force = 20
	throwforce = 30
	weight = 9.5
	w_class = ITEM_SIZE_HUGE
	slowdown = 0.1
	slot_flags = SLOT_BACK
	path = /obj/structure/barricade/hescobastion
	value = 55

/obj/item/weapon/material/shovel
	name = "shovel"
	desc = "A long tool for digging and moving dirt."
	icon = 'icons/obj/items.dmi'
	icon_state = "shovel"
	flags = CONDUCT
	force = 8.0
	throwforce = 4.0
	item_state = "shovel"
	w_class = ITEM_SIZE_NORMAL
	attack_verb = list("bashed", "bludgeoned", "thrashed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK|SLOT_BELT
	var/dig_speed = 7
	var/usespeed = 1.5
	default_material = "iron"
	force_divisor = 0.25
	thrown_force_divisor = 0.15
	health = 25
	maxhealth = 25

/obj/item/weapon/material/shovel/steel
	material = "steel"
	usespeed = 2
	default_material = "steel"
	health = 50
	maxhealth = 50
	dig_speed = 7

/obj/item/weapon/material/shovel/bone
	icon_state = "shovel_bone"
	desc = "A shovel made out of some bone."
	usespeed = 0.6
	default_material = "bone"
	health = 7.5
	maxhealth = 7.5
	dig_speed = 7

// Foldable shovels
/obj/item/weapon/material/shovel/spade/foldable
	name = "foldable shovel"
	icon_state = "trench_shovel"
	item_state = "lopata"
	usespeed = 0.9
	dig_speed = 7
	var/path = /obj/item/weapon/foldable_shovel
	secondary_action = TRUE

/obj/item/weapon/material/shovel/spade/foldable/secondary_attack_self(mob/living/human/user)
	if (secondary_action)
		if (do_after(user, 10, src))
			user.visible_message("<span class='warning'>[user] folds their [src] closed.</span>", "<span class='notice'>You fold your [src] closed.</span>", "<span class='warning'>You hear something being folded nearby.</span>")
			qdel(src)
			usr.put_in_any_hand_if_possible(new path, prioritize_active_hand = TRUE)

/obj/item/weapon/material/shovel/trench
	name = "entrenching tool"
	desc = "A compact shovel used specifically for digging and moving dirt."
	icon_state = "trench_shovel"
	dig_speed = 7
	force = 35
	usespeed = 0.8

/obj/item/weapon/material/shovel/trench/foldable
	name = "foldable entrenching tool"
	desc = "A foldable shovel used specifically for digging and moving dirt."
	icon_state = "trench_shovel"
	usespeed = 0.8
	var/path = /obj/item/weapon/foldable_shovel/trench
	secondary_action = TRUE

/obj/item/weapon/material/shovel/trench/foldable/etool
	name = "foldable entrenching tool"
	desc = "A foldable shovel used specifically for digging and moving dirt."
	icon_state = "etool"
	usespeed = 0.8
	path = /obj/item/weapon/foldable_shovel/trench/etool

/obj/item/weapon/material/shovel/trench/foldable/secondary_attack_self(mob/living/human/user)
	if (secondary_action)
		if (do_after(user, 10, src))
			to_chat(usr, SPAN_NOTICE("You fold your [src] closed."))
			qdel(src)
			usr.put_in_any_hand_if_possible(new path, prioritize_active_hand = TRUE)

/obj/item/weapon/material/shovel/trench/foldable/etool/german
	name = "german entrenching tool"
	desc = "A foldable shovel used specifically for digging and moving dirt."
	icon_state = "etool"
	usespeed = 0.8
	path = /obj/item/weapon/foldable_shovel/trench/german

/obj/item/weapon/material/shovel/spade
	name = "spade"
	desc = "A small tool for digging and moving dirt."
	icon_state = "spade"
	item_state = "spade"
	force = 15.0
	throwforce = 20.0
	w_class = ITEM_SIZE_SMALL
	weight = 1.18
	usespeed = 0.8
	dig_speed = 7

/obj/item/weapon/material/shovel/spade/wood
	usespeed = 0.4
	dig_speed = 7
	default_material = "wood"
	material = "wood"
	icon_state = "spadem"

// Foldable shovel items
/obj/item/weapon/foldable_shovel
	name = "foldable shovel"
	icon = 'icons/obj/items.dmi'
	desc = "A foldable shovel which is currently, folded."
	icon_state = "trench_shovel_folded"
	item_state = "lopata"
	edge = FALSE
	sharp = FALSE
	force = 1.0
	var/path = /obj/item/weapon/material/shovel/spade/foldable
	secondary_action = TRUE
	w_class = ITEM_SIZE_SMALL

/obj/item/weapon/foldable_shovel/trench
	name = "foldable entrenching tool"
	desc = "A foldable entrenching tool which is currently, folded."
	icon_state = "trench_shovel_folded"
	item_state = "lopata"
	path = /obj/item/weapon/material/shovel/trench/foldable

/obj/item/weapon/foldable_shovel/trench/etool
	name = "foldable entrenching tool"
	desc = "A foldable entrenching tool which is currently, folded."
	icon_state = "etool_folded"
	item_state = "lopata"
	path = /obj/item/weapon/material/shovel/trench/foldable/etool

/obj/item/weapon/foldable_shovel/trench/german
	name = "german entrenching tool"
	desc = "A foldable entrenching tool which is currently, folded."
	icon_state = "german_shovel_folded"
	item_state = "lopata"
	path = /obj/item/weapon/material/shovel/trench/foldable/etool/german

/obj/item/weapon/foldable_shovel/secondary_attack_self(mob/living/human/user)
	if (secondary_action)
		if (do_after(user, 5, src))
			to_chat(usr, SPAN_NOTICE("You quickly snap your [src] open."))
			qdel(src)
			usr.put_in_any_hand_if_possible(new path, prioritize_active_hand = TRUE)

/obj/item/weapon/material/shovel/spade/small
	name = "small shovel"
	icon_state = "lopata"
	item_state = "lopata"
	dig_speed = 7
	usespeed = 0.9

/obj/item/weapon/material/pickaxe
	name = "pickaxe"
	desc = "Miner's favorite."
	icon = 'icons/obj/items.dmi'
	icon_state = "pickaxe"
	flags = CONDUCT
	w_class = ITEM_SIZE_NORMAL
	item_state = "pickaxe"
	attack_verb = list("bashed", "bludgeoned", "thrashed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK|SLOT_BELT
	default_material = "iron"
	var/usespeed = 2
	force_divisor = 0.35
	thrown_force_divisor = 0.25
	health = 25
	maxhealth = 25

/obj/item/weapon/material/pickaxe/steel
	material = "steel"
	usespeed = 3
	default_material = "steel"
	health = 50
	maxhealth = 50

/obj/item/weapon/material/pickaxe/bone
	icon_state = "pickaxe_bone"
	usespeed = 1
	default_material = "bone"
	health = 7.50
	maxhealth = 7.50


/obj/item/weapon/material/pickaxe/stone
	usespeed = 1.5
	icon_state = "spickaxe"
	default_material = "stone"
	health = 15
	maxhealth = 15

/obj/item/weapon/material/pickaxe/jackhammer
	name = "jackhammer"
	desc = "An effecient mining tool."
	icon = 'icons/obj/items.dmi'
	icon_state = "jackhammer"
	force = 12.0
	flags = CONDUCT
	throwforce = 1.0
	w_class = ITEM_SIZE_GARGANTUAN
	item_state = "jackhammer"
	attack_verb = list("drilled", "bludgeoned", "stabbed", "whacked")
	sharp = FALSE
	edge = TRUE
	slot_flags = SLOT_BACK
	usespeed = 5
	health = 350
	maxhealth = 350

//Needs two hands to use.
/obj/item/weapon/material/pickaxe/jackhammer/proc/special_check(mob/user)
	if (!(user.has_empty_hand(both = FALSE)))
		user << "<span class='warning'>You need both hands to use the [src]!</span>"
		return FALSE

/obj/item/weapon/wirecutters/boltcutters
	name = "boltcutters"
	desc = "This cuts bolts and other things."
	icon_state = "boltcutters"

/obj/item/weapon/crowbar/prybar
	name = "prybar"
	icon_state = "prybar"

/obj/item/weapon/berriesgatherer
	name = "berries gatherer"
	desc = "A basic berry gatherer tool. Utilize it on berry bushes for efficient berry harvesting."
	icon = 'icons/obj/flora/berries.dmi'
	icon_state = "berriesgatherer"
	force = 2.0
	throwforce = 1.0
	item_state = "berriesgatherer"
	w_class = ITEM_SIZE_TINY
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	flammable = TRUE
	flags = FALSE

/obj/item/weapon/chisel
	name = "stone chisel"
	desc = "A stone chisel, for carving stone walls."
	icon = 'icons/obj/items.dmi'
	icon_state = "chisel"
	force = 2.0
	throwforce = 1.0
	w_class = ITEM_SIZE_TINY
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	flammable = FALSE
	//Designs possible are "smooth", "cave", "brick", "cobbled", "tiled"
	var/design = "smooth"

/obj/item/weapon/chisel/attack_self(mob/user)
	var/display = list("Smooth", "Cave", "Brick", "Cobbled", "Tiled", "Cancel")
	var/input =  WWinput(user, "What design do you want to carve?", "Carving", "Cancel", display)
	if (input == "Cancel")
		return
	else if (input == "Smooth")
		to_chat(user, SPAN_NOTICE("You will now carve the smooth design!"))
		design = "smooth"
	else if (input == "Cave")
		to_chat(user, SPAN_NOTICE("You will now carve the cave design!"))
		design = "cave"
	else if (input == "Brick")
		to_chat(user, SPAN_NOTICE("You will now carve the brick design!"))
		design = "brick"
	else if (input == "Cobbled")
		to_chat(user, SPAN_NOTICE("You will now carve the cobbled design!"))
		design = "cobbled"
	else if (input == "Tiled")
		to_chat(user, SPAN_NOTICE("You will now carve the tiled design!"))
		design = "tiled"

/obj/item/weapon/chisel/metal
	name = "iron chisel"
	desc = "A iron chisel, for carving stone walls."
	icon = 'icons/obj/items.dmi'
	icon_state = "chisel_metal"
	force = 2.25
	throwforce = 1.25
	w_class = ITEM_SIZE_TINY
	attack_verb = list("bashed", "bludgeoned", "whacked")
	sharp = FALSE
	edge = FALSE
	flammable = FALSE
	//Designs possible are "smooth", "cave", "brick", "cobbled", "tiled"
	design = "smooth"

/obj/item/weapon/material/shovel/attack_self(mob/user)
	var/turf/floor/TB = get_turf(user)
	if (istype(TB, /turf/floor/beach/water))
		return
	var/display = list("Tunnel", "Grave", "Irrigation Channel", "Pit Latrine","Cancel")
	var/input =  WWinput(user, "What do you want to dig?", "Digging", "Cancel", display)
	if (input == "Cancel")
		return
	else if (input == "Tunnel")
		/*if (!(locate(/obj/roof/, (user.x,user.y,user.z-1)))
			user << "<span class='notice'>You try to dig, but something hard is underneath!</span>"
			return*/ //Stop people from digging into bunkers, please fix
		if (!(locate(/obj/structure/multiz/) in user.loc) && user.z == 1)
			TB = locate(user.x,user.y,user.z+1)
			for (var/obj/OB in TB)
				if (istype(OB, /obj/covers) || OB.density == TRUE || istype(OB, /obj/structure/multiz) || istype(OB, /obj/structure/rails))
					to_chat(user, SPAN_NOTICE("You can't dig up here, there is something blocking the way!"))
					return
			if ((istype(TB, /turf/floor/beach) && !istype(TB, /turf/floor/beach/sand)) || istype(TB, /turf/floor/plating) || istype(TB, /turf/floor/broken_floor) ||istype(TB, /turf/floor/mining) ||istype(TB, /turf/floor/ship) ||istype(TB, /turf/floor/wood) ||istype(TB, /turf/floor/wood_broken) ||!istype(TB, /turf/floor))
				to_chat(user, SPAN_NOTICE("You can't dig up on that type of floor!"))
				return
			var/digging_tunnel_time = 400
			if (ishuman(user))
				var/mob/living/human/H = user
				digging_tunnel_time /= H.getStatCoeff("strength")
				digging_tunnel_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
			user.visible_message("<span class='danger'>[user] starts digging up!</span>", "<span class='notice'>You start digging up.</span>")
			if (do_after(user, digging_tunnel_time, user.loc))
				if (!TB.is_diggable)
					return
				new/obj/structure/multiz/ladder/ww2/tunneltop(locate(user.x, user.y, user.z+1))
				new/obj/structure/multiz/ladder/ww2/tunnelbottom(user.loc)
				user.visible_message("<span class='danger'>[user] finishes digging up!</span>", "<span class='notice'>You finish digging up.</span>")
				if (ishuman(user))
					var/mob/living/human/H = user
					H.adaptStat("crafting", 1)
					H.adaptStat("strength", 1)
			return
		if ((TB.is_diggable) && !(locate(/obj/structure/multiz/) in user.loc))
			if (user.z <= 1)
				to_chat(user, SPAN_NOTICE("You can't dig a tunnel here, the bedrock is right below."))
				return
			else
				var/digging_tunnel_time = 200
				if (ishuman(user))
					var/mob/living/human/H = user
					digging_tunnel_time /= H.getStatCoeff("strength")
					digging_tunnel_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
				user.visible_message("<span class='danger'>[user] starts digging a tunnel entrance!</span>", "<span class='danger'>You start digging a tunnel entrance.</span>")
				if (do_after(user, digging_tunnel_time, user.loc))
					if (!TB.is_diggable)
						return
					new/obj/structure/multiz/ladder/ww2/tunneltop(user.loc)
					new/obj/structure/multiz/ladder/ww2/tunnelbottom(locate(user.x, user.y, user.z-1))
					var/turf/BL = get_turf(locate(user.x, user.y, user.z-1))
					if (istype(BL, /turf/floor/dirt/underground))
						BL.ChangeTurf(/turf/floor/dirt)
					user.visible_message("<span class='danger'>[user] finishes digging the tunnel entrance.</span>", "<span class='danger'>You finish digging the tunnel entrance.</span>")
					if (ishuman(user))
						var/mob/living/human/H = user
						H.adaptStat("crafting", 1)
						H.adaptStat("strength", 1)
				return
		else if (locate(/obj/structure/multiz/) in user.loc)
			to_chat(user, SPAN_WARNING("There already is something here."))
			return
		else if (!TB.is_diggable)
			to_chat(user, SPAN_WARNING("You cannot dig a hole here!"))
			return
	else if (input == "Irrigation Channel")
		user.visible_message("<span class='notice'>[user] starts to dig an irrigation channel.</span>", "<span class='notice'>You start to dig an irrigation channel.</span>", "<span class='notice'>You hear the ground being dug nearby.</span>")
		if (do_after(user, 25, src))
			user.visible_message("<span class='notice'>[user] makes an irrigation channel.</span>", "<span class='notice'>You make an irrigation channel.</span>", "<span class='notice'>You finish and the sounds cease.</span>")
			TB.irrigate("empty")
			return
		return
	else if  (input == "Grave")
		if (istype(TB, /turf/floor/broken_floor) || istype(TB, /turf/wall) || istype(TB, /turf/floor/wood) || istype(TB, /turf/floor/wood_broken) || istype(TB, /turf/floor/ship) || istype(TB, /turf/floor/carpet) || istype(TB, /turf/floor/plating/cobblestone) || istype(TB, /turf/floor/plating/concrete) || istype(TB, /turf/floor/plating/stone_old))
			return
		else
			if (locate(/obj/structure/multiz) in user.loc)
				user << "<span class='notice'>There is a tunnel entrance here!</span>"
				return
			user.visible_message("[user] starts digging up a grave...", "<span class='notice'>You start digging up a grave...</span>", "<span class='notice'>You hear the ground being dug nearby.</span>")
			playsound(src,'sound/effects/shovelling.ogg',100,1)
			if (do_after(user, 100, src))
				to_chat(user, SPAN_NOTICE("You finish digging the grave."))
				new/obj/structure/religious/grave(user.loc)
				return
			else
				return
	else if  (input == "Pit Latrine")
		if (istype(TB, /turf/wall) || istype(TB, /turf/floor/wood) || istype(TB, /turf/floor/wood_broken) || istype(TB, /turf/floor/ship) || istype(TB, /turf/floor/carpet) || istype(TB, /turf/floor/broken_floor) || istype(TB, /turf/floor/plating/cobblestone) || istype(TB, /turf/floor/plating/concrete) || istype(TB, /turf/floor/plating/stone_old))
			return
		else
			if (locate(/obj/structure/multiz) in user.loc)
				to_chat(user, SPAN_NOTICE("There is a tunnel entrance here!"))
				return
			user.visible_message("[user] starts digging up a pit latrine...", "<span class='notice'>You start digging up a pit latrine...</span>", "<span class='notice'>You hear the sound of dirt being excavated nearby.</span>")
			playsound(src,'sound/effects/shovelling.ogg',100,1)
			if (do_after(user, 150, src))
				to_chat(user, SPAN_NOTICE("You finish digging the pit latrine."))
				new/obj/structure/toilet/pit_latrine(user.loc)
				return
			else
				return


/obj/structure/grapplehook
	name = "grappling hook"
	icon = 'icons/obj/objects.dmi'
	desc = "A grappling hook attached to a long hemp rope."
	icon_state = "grapplehook"
	opacity = FALSE
	density = FALSE
	var/deployed = FALSE
	var/owner = null

/obj/structure/grapplehook/auto
	dir = SOUTH
	anchored = TRUE
	New()
		..()
		spawn(rand(200,350))
		if (!deployed)
			deployed = TRUE
			deploy()
			update_icon()
			return
/obj/structure/grapplehook/attack_hand(mob/living/human/user)
	if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
		to_chat(user, SPAN_DANGER("You can't use this yet."))
		return
	if (!deployed)
		var/turf/nT = get_step(loc,user.dir)
		var/turf/nTT = get_step(nT,user.dir)
		if (!istype(nTT, /turf/floor/beach/water) && !istype(nTT, /turf/floor/broken_floor))
			to_chat(user, SPAN_WARNING("You cannot deploy in this direction!"))
			return
		to_chat(user, SPAN_NOTICE("You start deploying the [src]..."))
		if (do_after(user, 80, target = src))
			dir = user.dir
			if (dir == SOUTHWEST || dir == SOUTHEAST)
				dir = SOUTH
			if (dir == NORTHWEST || dir == NORTHEAST)
				dir = NORTH
			deployed = TRUE
			deploy()
			update_icon()
			to_chat(user, SPAN_NOTICE("You deployed the [src]."))
			return
	else
		to_chat(user, SPAN_NOTICE("You start packing the [src]..."))
		if (do_after(user, 80, target = src))
			dir = user.dir
			deployed = FALSE
			undeploy()
			update_icon()
			to_chat(user, SPAN_NOTICE("You packed the [src]."))
			return

/obj/structure/grapplehook/update_icon()
	if (deployed)
		icon_state = "grapplehook_bridge_deployed"
	else
		icon_state = "grapplehook"

/obj/structure/grapplehook/attackby(obj/item/I, mob/living/human/H)
	if (deployed && istype(I, /obj/item/weapon/wrench))
		return
	..()

/obj/structure/grapplehook/proc/deploy()
	anchored = TRUE
	var/turf/last_turf = loc
	for(var/i = 1, i <= 21, i++)
		var/turf/nT = get_step(last_turf,dir)
		last_turf = nT
		if (i>=2)
			for (var/obj/structure/barricade/ship/Ship in nT)
				var/obj/covers/repairedfloor/rope/end/endpart = new/obj/covers/repairedfloor/rope/end(nT)
				endpart.develop(src)
				return
			for (var/obj/structure/window/barrier/Ship in nT)
				var/obj/covers/repairedfloor/rope/end/endpart = new/obj/covers/repairedfloor/rope/end(nT)
				endpart.develop(src)
				return
			if (istype(nT, /turf/floor/beach/sand) || istype(nT, /turf/floor/dirt) || istype(nT, /turf/floor/grass))
				var/obj/covers/repairedfloor/rope/end/endpart = new/obj/covers/repairedfloor/rope/end(nT)
				endpart.develop(src)
				return
			if((map.ID == MAP_CAMPAIGN || map.ID == MAP_BATTLE_SHIPS) && istype(nT, /turf/floor/broken_floor))
				var/obj/covers/repairedfloor/rope/end/endpart = new/obj/covers/repairedfloor/rope/end(nT)
				endpart.develop(src)
				return
		var/obj/covers/repairedfloor/rope/part = new/obj/covers/repairedfloor/rope(nT)
		part.develop(src)
	visible_message("<span class='warning'>The [src] failed to attach to anything!</span>")
	src.undeploy()
	deployed = FALSE
	update_icon()
	return
/obj/structure/grapplehook/proc/undeploy()
	for(var/obj/covers/repairedfloor/rope/R in world)
		if (R.origin == src)
			R.Destroy()
	deployed = FALSE
	update_icon()
	return
