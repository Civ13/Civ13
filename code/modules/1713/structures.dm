/obj/structure/barricade/wood_pole
	name = "wood pole"
	desc = "A simple wood pole. You can attach stuff to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wood_pole_good"
	health = 50
	maxhealth = 50
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/attached = "none"
	var/obj/attached_ob = null
	flammable = TRUE
	protection_chance = 30

/obj/structure/barricade/wood_pole/New()
	..()
	name = "wood pole"
	desc = "A simple wood pole. You can attach stuff to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wood_pole_good"

/obj/structure/grille/fence
	name = "fence"
	desc = "An old wooden fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "fence"
	health = 16
	hitsound = 'sound/effects/wooddoorhit.ogg'
	flammable = TRUE

/obj/structure/grille/fence/attackby(obj/O as obj, mob/user as mob)
	if (istype(O, /obj/item/weapon/leash))
		var/obj/item/weapon/leash/L = O
		if (L.onedefined == TRUE && (src in range(3,L.S1)))
			L.S2 = src
			L.S1.following_mob = src
			L.S1.stop_automated_movement = TRUE
			user << "You tie \the [L.S1] to \the [src] with the leash."
			qdel(L)
			return
	else
		..()
	if (health >= initial(health))
		icon_state = "[initial(icon_state)]"
	else if (health >= initial(health)*0.6)
		icon_state = "[initial(icon_state)]2"
	else if (health >= initial(health)*0.3)
		icon_state = "[initial(icon_state)]3"

/obj/structure/grille/fence/picket
	name = "picket fence"
	desc = "A traditional wooden fence."
	icon_state = "picket"
	health = 30

/obj/structure/grille/fence/steel_picket
	name = "picket fence"
	desc = "A traditional metal fence."
	icon_state = "steel_picket"
	health = 60
	flammable = FALSE

/obj/structure/barricade/wood_pole/attackby(obj/O as obj, mob/user as mob)
	if (istype(O, /obj/item/weapon/leash))
		var/obj/item/weapon/leash/L = O
		if (L.onedefined == TRUE && (src in range(3,L.S1)))
			L.S2 = src
			L.S1.following_mob = src
			L.S1.stop_automated_movement = TRUE
			user << "You tie \the [L.S1] to \the [src] with the leash."
			attached = "animal"
			qdel(L)
			return
	else if (istype(O, /obj/item/flashlight/lantern))
		var/obj/item/flashlight/lantern/LT = O
		user << "You tie \the [O] to \the [src]."
		LT.anchored = TRUE
		LT.on = TRUE
		LT.update_icon()
		LT.icon_state = "lantern-on_pole"
		LT.on_state = "lantern-on_pole"
		LT.off_state = "lantern_pole"
		attached_ob = O
		user.drop_from_inventory(O)
		O.forceMove(loc)
	else
		..()
/obj/structure/barricade/wood_pole/attack_hand(mob/living/user as mob)
	if (!isliving(user))
		return
	if (attached_ob && istype(attached_ob, /obj/item/flashlight/lantern))
		user << "You remove \the [attached_ob] from \the [src]."
		var/obj/item/flashlight/lantern/O = attached_ob
		O.anchored = FALSE
		O.forceMove(user.loc)
		user.put_in_hands(O)
		attached_ob = null
		return
/obj/structure/barricade/wood_pole/Destroy()
	if (attached_ob != null)
		if (istype(attached_ob, /obj/item/flashlight/lantern))
			var/obj/item/flashlight/lantern/LT = attached_ob
			LT.anchored = FALSE
			LT.icon_state = "lantern"
			LT.on = FALSE
			LT.on_state = "lantern-on"
			LT.off_state = "lantern"
			LT.update_icon()
			attached_ob = null
	..()
/obj/structure/grille/logfence
	name = "palisade"
	desc = "A wooden palisade."
	icon = 'icons/obj/structures.dmi'
	icon_state = "palisade"
	health = 32
	opacity = TRUE
	hitsound = 'sound/effects/wooddoorhit.ogg'
	flammable = TRUE

/obj/structure/grille/ironfence
	name = "iron fence"
	desc = "A wrought iron fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "iron_fence"
	health = 70
	hitsound = 'sound/weapons/blade_parry1.ogg'

/obj/structure/grille/metalsheetfence
	name = "metal fence"
	desc = "A sheet metal fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "metal_fence1"
	health = 80
	opacity = TRUE
	hitsound = 'sound/weapons/blade_parry1.ogg'
/obj/structure/grille/metalsheetfence/blue
	icon_state = "metal_fence2"
/obj/structure/grille/metalsheetfence/red
	icon_state = "metal_fence3"
/obj/structure/grille/metalsheetfence/green
	icon_state = "metal_fence4"
/obj/structure/grille/metalsheetfence/yellow
	icon_state = "metal_fence5"

/obj/structure/grille/metalsheetfence/corner
	name = "metal-sheet fence"
	desc = "A woven steel fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "metal_fence_corner1"
	health = 120
	opacity = TRUE
	hitsound = 'sound/weapons/blade_parry1.ogg'
/obj/structure/grille/metalsheetfence/corner/blue
	icon_state = "metal_fence_corner2"
/obj/structure/grille/metalsheetfence/corner/red
	icon_state = "metal_fence_corner3"
/obj/structure/grille/metalsheetfence/corner/green
	icon_state = "metal_fence_corner4"
/obj/structure/grille/metalsheetfence/corner/yellow
	icon_state = "metal_fence_corner5"

//////////////CHAIN-LINK FENCES////////////////

/obj/structure/grille/chainlinkfence
	name = "chain-link fence"
	desc = "A woven steel fence."
	icon = 'icons/obj/fence.dmi'
	icon_state = "chainlinkfence"
	health = 50
	hitsound = 'sound/weapons/blade_parry1.ogg'

	var/cuttable = TRUE
	var/hole_size = 0
	var/invulnerable = FALSE

/obj/structure/grille/chainlinkfence/New()
	.=..()
	update_cut_status()

/obj/structure/grille/chainlinkfence/examine(mob/user)
	.=..()
	switch(hole_size)
		if (1)
			user.show_message("There is a small hole in \the [src].")
		if (2)
			user.show_message("There is a large hole in \the [src].")
		if (3)
			user.show_message("\The [src] has been completely cut through.")

/obj/structure/grille/chainlinkfence/attackby(obj/item/W, mob/living/human/user)
	if(istype(W, /obj/item/weapon/wirecutters))
		if(!cuttable)
			to_chat(user, "<span class='notice'>This section of the fence can't be cut.</span>")
			return
		if(invulnerable)
			to_chat(user, "<span class='notice'>This fence is too strong to cut through.</span>")
			return
		var/current_stage = hole_size
		if(current_stage >= 3)
			to_chat(user, "<span class='notice'>This fence has been completely cut already.</span>")
			return

		user.visible_message("<span class='danger'>\The [user] starts cutting through \the [src] with \the [W].</span>",\
		"<span class='danger'>You start cutting through \the [src] with \the [W].</span>")

		if(do_after(user, (120/user.getStatCoeff("crafting")), src))
			if(current_stage == hole_size)
				switch(++hole_size)
					if (1)
						visible_message("<span class='notice'>\The [user] cuts into \the [src] some more.</span>")
						climbable = FALSE
					if (2)
						visible_message("<span class='notice'>\The [user] cuts into \the [src] some more.</span>")
						to_chat(user, "<span class='info'>You could probably fit yourself through that hole now. Although climbing through would be much faster if you made it even bigger.</span>")
						climbable = TRUE
					if (3)
						visible_message("<span class='notice'>\The [user] completely cuts through \the [src].</span>")
						to_chat(user, "<span class='info'>The hole in \the [src] is now big enough to walk through.</span>")
						climbable = FALSE

				update_cut_status()

	return TRUE

/obj/structure/grille/chainlinkfence/proc/update_cut_status()
	if(!cuttable)
		return
	density = TRUE
	switch(hole_size)
		if(0)
			icon_state = initial(icon_state)
		if(1)
			icon_state = "chainlinkfence_cut1"
		if(2)
			icon_state = "chainlinkfence_cut2"
		if(3)
			icon_state = "chainlinkfence_cut3"
			density = FALSE

/obj/structure/grille/chainlinkfence/cut
	icon_state = "chainlinkfence_cut1"
	hole_size = 1
/obj/structure/grille/chainlinkfence/cut/larger
	icon_state = "chainlinkfence_cut2"
	hole_size = 2
/obj/structure/grille/chainlinkfence/cut/larger/complete
	icon_state = "chainlinkfence_cut3"
	hole_size = 3

/obj/structure/grille/chainlinkfence/corner
	icon_state = "chainlinkfence_corner"
	hitsound = 'sound/weapons/blade_parry1.ogg'
	cuttable = FALSE
	density = FALSE

// DOOR

/obj/structure/grille/chainlinkfence/door
	name = "chain-link fence door"
	desc = "A woven steel fence door."
	icon_state = "chainlinkfence_door"
	cuttable = FALSE
	var/open = FALSE

/obj/structure/grille/chainlinkfence/door/New()
	. = ..()
	update_door_status()

/obj/structure/grille/chainlinkfence/door/opened
	icon_state = "chainlinkfence_door_open"
	open = TRUE
	density = TRUE

/obj/structure/grille/chainlinkfence/door/attack_hand(mob/user)
	if(can_open(user))
		toggle(user)
	return TRUE

/obj/structure/grille/chainlinkfence/door/proc/toggle(mob/user)
	switch(open)
		if(FALSE)
			visible_message("<span class='notice'>\The [user] opens \the [src].</span>")
			open = TRUE
		if(TRUE)
			visible_message("<span class='notice'>\The [user] closes \the [src].</span>")
			open = FALSE

	update_door_status()
	playsound(src, 'sound/machines/click.ogg', 100, 1)

/obj/structure/grille/chainlinkfence/door/proc/update_door_status()
	switch(open)
		if(FALSE)
			density = TRUE
			icon_state = "chainlinkfence_door"
		if(TRUE)
			density = FALSE
			icon_state = "chainlinkfence_door_open"

/obj/structure/grille/chainlinkfence/door/proc/can_open(mob/user)
	return TRUE

////////////////////////////////////////////////

/obj/structure/wallclock
	name = "standing clock"
	desc = "A classic standing clock."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_clock"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
/obj/structure/wallclock/examine(mob/user)
	..()
	user << "<big>It is now [clock_time()].</big>"

/obj/structure/props/server
	name = "server hub"
	desc = "A big and scary looking server connecting other servers."
	icon = 'icons/obj/machines/servers.dmi'
	icon_state = "hub"

/obj/structure/props/server/controller
	name = "server controller"
	desc = "A controller for a server... and stuff... You have no clue what this is used for."
	icon_state = "controller"

/obj/structure/props/server/processor
	name = "server processor"
	desc = "A processor to process stuff into stuff, weird IT department with their names..."
	icon_state = "processor"

/obj/structure/props/server/comm
	name = "communication server"
	desc = "A communication server to communicate with other servers and people, do I really need to explain this?"
	icon_state = "comm_server"

/obj/structure/props/junk
	name = "junk"
	desc = "A pile of junk."
	icon = 'icons/obj/junk.dmi'
	icon_state = "Junk_1"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = TRUE
	anchored = TRUE
/obj/structure/props/junk/New()
	..()
	icon_state = "Junk_[rand(1,14)]"

/obj/structure/props/barrel
	name = "barrel"
	desc = "A barrel with god knows what in it."
	icon = 'icons/obj/junk.dmi'
	icon_state = "barrel1"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = TRUE
	anchored = TRUE
/obj/structure/props/barrel/New()
	..()
	icon_state = "barrel[rand(1,5)]"

/obj/structure/props/fueltank
	name = "fueltank"
	desc = "A huge industrial fueltank."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "fueltank"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = TRUE
	anchored = TRUE
	bound_width = 64
	bound_height = 32

/obj/structure/props/stove
	name = "stove"
	desc = "A gas stove."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "stove"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/stove/old
	icon_state = "gasstove"

/obj/structure/props/radiator
	name = "radiator"
	desc = "A heat exchanger."
	icon = 'icons/obj/junk.dmi'
	icon_state = "radiator"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/bathtub
	name = "bathtub"
	desc = "A bathtub."
	icon = 'icons/obj/junk.dmi'
	icon_state = "bathtub"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/djtable
	name = "dj table"
	desc = "A dj table."
	icon = 'icons/obj/junk.dmi'
	icon_state = "djtable"
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/coatrack
	name = "coat rack"
	desc = "A coat rack."
	icon = 'icons/obj/junk.dmi'
	icon_state = "coatrack"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE

/obj/structure/props/sofa
	name = "sofa"
	desc = "A sofa."
	icon = 'icons/obj/junk.dmi'
	icon_state = "sofa_forward_left"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE

/obj/structure/props/sofa/p2
	icon_state = "sofa_forward_right"

/obj/structure/props/sofa/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)//So bullets will fly over and stuff.
	if (istype(mover, /obj/item/projectile))
		return prob(75)
	else
		return FALSE

/obj/structure/props/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)//So bullets will fly over and stuff.
	if (istype(mover, /obj/item/projectile))
		return prob(50)
	else
		return FALSE


/obj/structure/potted_plant
	name = "potted plant"
	desc = "A potted plant."
	icon = 'icons/obj/structures.dmi'
	icon_state = "potted_plant"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/props/hookah
	name = "hookah"
	desc = "A glass pipe used to smoke tobacco or other substances."
	icon = 'icons/obj/items.dmi'
	icon_state = "hookah1"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE

/obj/structure/props/hookah/New()
	..()
	var/pickhookah = pick("hookah1", "hookah2", "hookah3")
	icon_state = pickhookah

/obj/structure/props/bong
	name = "bong"
	desc = "A glass pipe used to smoke cannabis or other substances."
	icon = 'icons/obj/items.dmi'
	icon_state = "bong"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	density = FALSE
	opacity = FALSE

/obj/structure/props/car_wreck
	name = "car wreck"
	desc = "Looks like it has been here for a while."
	icon = 'icons/obj/vehicles/wip_vehicles.dmi'
	icon_state = "car_wreck"
	flammable = FALSE
	not_movable = TRUE
	anchored = TRUE
	not_disassemblable = TRUE
	density = TRUE
	bound_width = 96
	bound_height = 64
/obj/structure/props/car_wreck/alt
	icon_state = "car_wreck2"
/obj/structure/props/car_wreck/vertical
	icon_state = "car_wreck_vert"
	bound_width = 32
	bound_height = 96
/obj/structure/props/car_wreck/van
	icon_state = "van_wreck"
/obj/structure/props/car_wreck/van/alt
	icon_state = "van_wreck2"
/obj/structure/props/car_wreck/truck
	icon_state = "truck_wreck"
	bound_width = 128
	bound_height = 64

/obj/structure/props/watts_tower
	name = "sculpture tower"
	desc = "An achitectural scultpural tower."
	icon = 'icons/obj/decals_widest.dmi'
	icon_state = "watts_tower"
	flammable = FALSE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	bound_width = 64
	bound_height = 64
	layer = MOB_LAYER+1

/obj/structure/props/engineprops
	name = "generic"
	desc = "A generic engine prop."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "gasoline_static"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = TRUE
	anchored = TRUE
	not_movable = TRUE
/obj/structure/props/engineprops/gas
	name = "gasoline engine"
	desc = "A gasoline engine in operation."
	icon_state = "gasoline_on"
/obj/structure/props/engineprops/frunace
	name = "furnace"
	desc = "A furnace in operation."
	icon_state = "furnace_open_on"
/obj/structure/props/engineprops/turbine
	name = "turbine engine"
	desc = "A turbine engine in operation."
	icon_state = "turbine_on"
/obj/structure/props/engineprops/diesel
	name = "diesel engine"
	desc = "A diesel engine in operation."
	icon_state = "biodiesel_on"
/obj/structure/props/engineprops/hotbulb
	name = "hotbulb engine"
	desc = "A hotbulb engine in operation."
	icon_state = "hotbulb_on"
/obj/structure/props/engineprops/dieselgeni
	name = "diesel genertator"
	desc = "A diesel generator in operation."
	icon_state = "diesel_on"
/obj/structure/props/engineprops/hesselman
	name = "hesselman engine"
	desc = "A hesselman engine in operation."
	icon_state = "hesselman_on"
/obj/structure/props/engineprops/steam
	name = "steam engine"
	desc = "A steam engine in operation."
	icon_state = "steam_on"
/obj/structure/props/engineprops/aeolipile
	name = "aeolipile engine"
	desc = "An aeolipile in operation."
	icon_state = "aeolipile_on"
/obj/structure/props/engineprops/reactor
	name = "reactor housing"
	desc = "A reactor housing for nuclear fission/fussion."
	icon_state = "reactor_3"
/obj/structure/props/engineprops/big
	name = "large engine"
	desc = "A running engine. This one seems rather large."
	icon = 'icons/obj/engines64.dmi'
	icon_state = "static_engine_on"
	bound_width = 64
	bound_height = 64
	bound_x = 32

/obj/structure/props/engineprops/waterpump
	name = "large pump"
	desc = "A pump of rather considerable size."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "waterpump"
	bound_width = 96
	bound_height = 96
	bound_x = 32
	anchored = TRUE
	not_movable = TRUE
/obj/structure/props/random/container
	name = "a shipping container"
	desc = "6 metal sides, two of which open. A hard concept to improve."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "container1"
	bound_width = 96
	bound_height = 64
	anchored = TRUE
	not_movable = TRUE
	density = TRUE
/obj/structure/props/random/podlock
	name = "podlock"
	desc = "Sturdy pod lock, should stop anything short of a breaching charge."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "blast0"
	anchored = TRUE
	not_movable = TRUE
	density = TRUE
/obj/structure/props/random/container/two
	icon_state = "container2"
/obj/structure/props/random/container/three
	icon_state = "container3"
/obj/structure/props/random/container/four
	icon_state = "container4"
/obj/structure/props/random/container/five
	icon_state = "container5"

/obj/structure/props/machineprops/refinery
	name = "smoking cylinder"
	desc = "This stack is definitely producing steam or maybe smoke. You are not sure what it is up to."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "refinery1"
	bound_width = 32
	bound_height = 64
	bound_x = 32
/obj/structure/props/computerprops
	name = "access terminal"
	desc = "The screen is on and the buttons all work but you aren't sure you know which ones to push."
	light_range = 2
	icon = 'icons/obj/computers.dmi'
	icon_state = "1980_computer_on"
	anchored = TRUE
/obj/structure/props/computerprops/info_panel
	icon_state = "info_panel"
/obj/structure/props/computerprops/research
	icon_state = "research_on"
/obj/structure/props/computerprops/lab
	icon_state = "lab_on"
/obj/structure/props/computerprops/lunar
	icon_state = "lunar"
/obj/structure/props/computerprops/lunar2
	icon_state = "lunar_on"
/obj/structure/props/computerprops/enclave
	icon_state = "enclave_on"
/obj/structure/props/computerprops/machine
	icon = 'icons/obj/device.dmi'
	icon_state = "machine_on"
/obj/structure/props/computerprops/tracking
	icon = 'icons/obj/device.dmi'
	icon_state = "tracking"
/obj/structure/props/computerprops/modern
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "airfilter2"
/obj/structure/props/computerprops/modern/obj34
	icon_state = "obj34"
/obj/structure/props/computerprops/modern/a9
	icon_state = "a9"
/obj/structure/props/computerprops/modern/a10
	icon_state = "a10"
/obj/structure/props/computerprops/modern/a11
	icon_state = "a11"
/obj/structure/props/computerprops/modern/smes2
	icon_state = "smes2"
/obj/structure/props/computerprops/modern/synth2
	icon_state = "synth2"

/obj/structure/props/computerprops/enclave
	icon_state = "enclave_on"
/obj/structure/props/computerprops/terminal
	icon_state = "terminal_on"
/obj/structure/broken_hind
	name = "Mi-24 remains"
	desc = "The remains of a Soviet helicopter."
	icon = 'icons/obj/decals_huge.dmi'
	icon_state = "brokenhind"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = TRUE
	layer = MOB_LAYER + 0.01
	bound_width = 128
	bound_height = 128
	bound_x = 32
/obj/structure/broken_hind_tail
	name = "helicopter tail"
	desc = "The tail of a helicopter."
	icon = 'icons/obj/decals_huge.dmi'
	icon_state = "brokenhind_tail"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = TRUE
	layer = MOB_LAYER + 0.01
	bound_width = 128
	bound_height = 128
	bound_x = 32

/obj/structure/props/marketstall
	name = "market stall"
	desc = "A market stall."
	icon = 'icons/obj/structures.dmi'
	icon_state = "propstall1"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	density = TRUE
	opacity = TRUE
	anchored = TRUE
	New()
		..()
		icon_state ="propstall[rand(1,4)]"

/obj/structure/props/keyboard
	name = "eletric keyboard"
	desc = "A electric keyboard."
	icon = 'icons/obj/structures.dmi'
	icon_state = "keyboard"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = TRUE
	anchored = TRUE

/obj/structure/props/dj
	name = "dj table"
	desc = "A dj setup for makin sick beats."
	icon = 'icons/obj/junk.dmi'
	icon_state = "djtable"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = TRUE
	anchored = TRUE

/obj/structure/props/micstand
	name = "microphone stand"
	desc = "A mic stand."
	icon = 'icons/obj/structures.dmi'
	icon_state = "microphone_stand"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	density = TRUE
	opacity = TRUE
	anchored = TRUE

/obj/structure/flag
	icon = 'icons/obj/flags.dmi'
	icon_state = "black"
	layer = MOB_LAYER + 0.01
	bound_width = 32
	bound_height = 32
	density = FALSE
	anchored = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/flag/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(66))
				qdel(src)
				return
		if (3.0)
			return

/obj/structure/flag/pirates
	icon_state = "pirates"
	name = "Pirate Flag"
	desc = "A black and white pirate flags with skull and bones."

/obj/structure/flag/black
	icon_state = "black"
	name = "Black Flag"
	desc = "A black flag."

/obj/structure/flag/white
	icon_state = "white"
	name = "White Flag"
	desc = "A white flag."

/obj/structure/flag/french
	icon_state = "french"
	name = "French Flag"
	desc = "The French flag, white with golden fleur-de-lys."

/obj/structure/flag/french_modern
	icon_state = "french2"
	name = "French Flag"
	desc = "The modern french tricoleur."

/obj/structure/flag/french_monarchist
	icon_state = "french3"
	name = "French Flag"
	desc = "The french monarchist flag."


/obj/structure/flag/spanish
	icon_state = "spanish"
	name = "Spanish Flag"
	desc = "The Spanish flag, white with a red cross of burgundy."

/obj/structure/flag/spanish_modern
	icon_state = "spanish2"
	name = "Spanish Flag"
	desc = "The modern yellow and red spanish flag."

/obj/structure/flag/italian
	icon_state = "italian"
	name = "Italian Flag"
	desc = "The modern italian flag."

/obj/structure/flag/british
	icon_state = "british"
	name = "British Flag"
	desc = "The Union Jack."

/obj/structure/flag/portuguese
	icon_state = "portuguese"
	name = "Portuguese Flag"
	desc = "A white flag with the Portuguese Coat of Arms in the middle."

/obj/structure/flag/dutch
	icon_state = "netherlands"
	name = "Dutch Flag"
	desc = "The tricolor Dutch flag."

/obj/structure/flag/dutch_old
	icon_state = "netherlands_old"
	name = "Dutch Flag"
	desc = "The tricolor Dutch flag."

/obj/structure/flag/japanese
	icon_state = "japanese"
	name = "Imperial Japanese Flag"
	desc = "The Imperial Japanese flag."

/obj/structure/flag/russian
	icon_state = "russian"
	name = "Russian Flag"
	desc = "The tricolor Russian flag."

/obj/structure/flag/russian
	icon_state = "russian"
	name = "Russian Flag"
	desc = "The tricolor Russian flag."

/obj/structure/flag/soviet
	icon_state = "soviet"
	name = "Soviet Union Flag"
	desc = "The Soviet flag."

/obj/structure/flag/us
	icon_state = "us"
	name = "USA Flag"
	desc = "The US flag."

/obj/structure/flag/german
	icon_state = "german"
	name = "German Flag"
	desc = "The German flag."

/obj/structure/flag/german_modern
	icon_state = "german2"
	name = "German Flag"
	desc = "The German flag."

/obj/structure/flag/confed
	icon_state = "confed"
	name = "Confederate flag"
	desc = "The Confederate flag"

/obj/structure/flag/reich
	icon_state = "reich"
	name = "Third Reich Flag"
	desc = "The Third Reich war flag."

/obj/structure/flag/chinese
	icon_state = "chinese"
	name = "Republic of China Flag"
	desc = "The Republic of China flag."

/obj/structure/flag/filipino
	icon_state = "filipino"
	name = "Philippines Republic"
	desc = "The Republic of the Philippines flag."

/obj/structure/flag/filipino_war
	icon_state = "filipino_wartime"
	name = "Philippines Republic"
	desc = "The Republic of the Philippines flag. This one flipped for wartime."

/obj/structure/flag/nva
	icon_state = "nva"
	name = "North Vietnam Flag"
	desc = "The flag of North Vietnam."

/obj/structure/flag/vietcong
	icon_state = "vietcong"
	name = "Vietcong Flag"
	desc = "The flag of the National Liberation Front of Vietnam."

/obj/structure/flag/redmenia
	icon_state = "redmenia"
	name = "Redmenia Flag"
	desc = "The flag of Redmenia."

/obj/structure/flag/blugoslavia
	icon_state = "blugoslavia"
	name = "Blugoslavia Flag"
	desc = "The flag of Blugoslavia."

/obj/structure/flag/pole
	icon_state = "flagpole_blank"
	name = "Flagpole"
	desc = "Flagless, apply cloth or a flag."

/obj/structure/flag/bearclan
	icon_state = "bearclan"
	name = "Bearclan Banner"
	desc = "A Bearclan banner."

/obj/structure/flag/ravenclan
	icon_state = "ravenclan"
	name = "Raven Banner"
	desc = "A Ravenclan banner."

/obj/structure/flag/pole/attackby(obj/item/W as obj, var/mob/living/human/H)
	if(istype(W, /obj/item/stack/material/cloth))
		if(W.amount >= 5)
			W.amount -= 5
			new /obj/structure/flag/pole/custom(src.loc)
			if(W.amount <= 0)
				qdel(W)
			qdel(src)
		else
			H << "You need atleast five cloth to do that!"
	else if(istype(W, /obj/item/flagmaker))
		new /obj/structure/flag/pole/custom(src.loc)
		qdel(src)
	else
		..()
	..()
/obj/structure/flag/pole/custom
	icon_state = "cust_flag"
	name = "Flag"
	desc = "A flag."
	var/uncolored = TRUE
	var/flagcolor
	var/symbol
	var/symbolcolor 

/obj/structure/flag/pole/custom/attackby(obj/item/W as obj, var/mob/living/human/H)
	if(istype(W, /obj/item/weapon))
		if(W.sharp)
			H << "You tear down the flag!"
			new/obj/structure/flag/pole(src.loc)
			qdel(src)
			
/obj/structure/flag/pole/custom/attack_hand(var/mob/living/human/H)
	if (uncolored)
		var/input = WWinput(H, "Flag Color - Choose a color:", "Flag Color" , "#FFFFFF", "color")
		if (input == null || input == "")
			return
		else

			flagcolor= input
	if (!symbol)
		var/display = list("Moon", "Cross", "Star", "Sun", "Plus", "Saltire", "None", "Cancel")
		var/input =  WWinput(H, "What symbol would you like?", "Flag Making", "Cancel", display)
		playsound(src.loc,'sound/items/ratchet.ogg',40) //rip_pack.ogg
		if (input == "Cancel")
			return
		else if(input == "Moon")
			symbol = "cust_f_moon"
		else if(input == "Cross")
			symbol = "cust_f_cross"
		else if(input == "Star")
			symbol = "cust_f_star"
		else if(input == "Sun")
			symbol = "cust_f_sun"
		else if(input == "Plus")
			symbol = "cust_f_plus"
		else if(input == "Saltire")
			symbol = "cust_f_saltire"
		else if(input == "None")
			symbol = "cust_f_blank"
		else
			H << "<span class='notice'>That does not exist!</span>"
	if (!symbolcolor)
		var/input = WWinput(H, "Symbol Color - Choose a color:", "Symbol Color" , "#000000", "color")
		if (input == null || input == "")
			return
		else

			symbolcolor= input
	if (flagcolor && symbol && symbolcolor)
		uncolored = FALSE
		var/image/flag = image("icon" = 'icons/obj/flags.dmi', "icon_state" = "cust_flag_cloth")
		flag.color = flagcolor
		var/image/border = image("icon" = 'icons/obj/flags.dmi', "icon_state" = "cust_flag_outline")
		var/image/csymbol = image("icon" = 'icons/obj/flags.dmi', "icon_state" = symbol)
		csymbol.color = symbolcolor
		overlays += flag
		overlays += border
		overlays += csymbol
		return
	else
		..()
	..()

/obj/structure/wallframe
	name = "wall frame"
	desc = "A wooden wall frame, add something like paper, bamboo bundles or wood to it.."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_frame"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = FALSE
	opacity = FALSE

/obj/structure/wallframe/attackby(obj/item/W as obj, var/mob/living/human/H)
	if(istype(W, /obj/item/stack/material/wood))
		var/input
		var/display = list("Medieval Window - 4", "Medieval Wall - 6", "Medieval Crossbraced Wall (X) - 6", "Medieval Braced Wall (\\) - 6", "Medieval Braced Wall (/) - 6", "Cancel")
		input =  WWinput(H, "What wall would you like to make?", "Building", "Cancel", display)
		playsound(src.loc,'sound/items/ratchet.ogg',40) //rip_pack.ogg
		if (input == "Cancel")
			return
		else if(input == "Medieval Window - 4")
			if(W.amount >= 4)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/medieval(src.loc)
					qdel(src)
					W.amount -= 4
		else if(input == "Medieval Wall - 6")
			if(W.amount >= 6)
				if (do_after(H, 41, src))
					new/obj/covers/wood_wall/medieval(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Medieval Crossbraced Wall (X) - 6")
			if(W.amount >= 6)
				if (do_after(H, 43, src))
					new/obj/covers/wood_wall/medieval/x(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Medieval Braced Wall (\\) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/medieval/y/r(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Medieval Braced Wall (/) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/medieval/y/l(src.loc)
					qdel(src)
					W.amount -= 6
		else
			H << "<span class='notice'>That does not exist!</span>"
	else if(istype(W, /obj/item/weapon/paper))
		var/input
		var/display = list("Shoji Door - 1", "Shoji Wall - 1", "Shoji Divider - 1", "Shoji Window - 1", "Cancel")
		input =  WWinput(H, "What wall would you like to make?", "Building", "Cancel", display)
		playsound(src.loc,'sound/effects/rip_pack.ogg',40)
		if (input == "Cancel")
			return
		else if(input == "Shoji Door - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/structure/simple_door/key_door/anyone/shoji(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Wall - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/shoji(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Divider - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/shoji_divider(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Window - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/shoji(src.loc)
					qdel(src)
					qdel(W)
		else
			H << "<span class='notice'>That does not exist!</span>"
	else if(istype(W, /obj/item/stack/material/bamboo))
		var/input = WWinput(H, "What wall would you like to make?", "Building", "Cancel",list ("Bamboo Wall - 3", "Bamboo Doorway - 2", "Bamboo Window - 2", "Cancel"))
		if (input == "Cancel")
			return
		if(input == "Bamboo Wall - 3")
			if(W.amount >= 3)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/bamboo(src.loc)
					qdel(src)
					W.amount -= 3
		else if(input == "Bamboo Doorway - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					var/obj/covers/wood_wall/bamboo/S = new /obj/covers/wood_wall/bamboo(loc)
					S.icon_state = "bamboo-door"
					S.name = "bamboo doorway"
					S.desc = "A doorway made from bamboo."
					S.density = FALSE
					S.opacity = FALSE
					qdel(src)
					W.amount -= 2
		else if(input == "Bamboo Window - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/bamboo(src.loc)
					qdel(src)
					W.amount -= 2
		else
			H << "<span class='notice'>That does not exist!</span>"

/* Bamboo Wall-Frame*/

/obj/structure/wallframe/bamboo
	name = "bamboo wall frame"
	desc = "A bamboo wall frame, add something like paper, bamboo bundles or wood to it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wall_frame_bamboo"

/obj/structure/wallframe/bamboo/attackby(obj/item/W as obj, var/mob/living/human/H)
	if(istype(W, /obj/item/stack/material/wood))
		var/input
		var/display = list("Oriental Window - 4", "Oriental Wall - 6","Oriental Braced Wall (--) - 6", "Oriental Doorway - 6", "Oriental Two Panelled Wall (|) - 6", "Oriental Two Panelled Braced Wall (-|-)", "Oriental Three Panelled Wall (||) - 6",  "Oriental Three Panelled Braced Wall (-|-|-) - 6", "Cancel")
		input =  WWinput(H, "What wall would you like to make?", "Building", "Cancel", display)
		playsound(src.loc,'sound/items/ratchet.ogg',40) //rip_pack.ogg
		if (input == "Cancel")
			return
		else if(input == "Oriental Window - 4")
			if(W.amount >= 4)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/oriental(src.loc)
					qdel(src)
					W.amount -= 4
		else if(input == "Oriental Wall - 6")
			if(W.amount >= 6)
				if (do_after(H, 41, src))
					new/obj/covers/wood_wall/oriental(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Braced Wall (--) - 6")
			if(W.amount >= 6)
				if (do_after(H, 43, src))
					new/obj/covers/wood_wall/oriental/b(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Doorway - 6")
			if(W.amount >= 6)
				if (do_after(H, 40, src))
					var/obj/covers/wood_wall/oriental/S = new /obj/covers/wood_wall/oriental(loc)
					S.icon_state = "oriental-door"
					S.name = "oriental doorway"
					S.desc = "A east-oriental style doorway."
					S.density = FALSE
					S.opacity = FALSE
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Two Panelled Wall (|) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/twop(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Two Panelled Braced Wall (-|-)")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/twop/b(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Three Panelled Wall (||) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/threep(src.loc)
					qdel(src)
					W.amount -= 6
		else if(input == "Oriental Three Panelled Braced Wall (-|-|-) - 6")
			if(W.amount >= 6)
				if (do_after(H, 42, src))
					new/obj/covers/wood_wall/oriental/threep/b(src.loc)
					qdel(src)
					W.amount -= 6
		else
			H << "<span class='notice'>That does not exist!</span>"
	else if(istype(W, /obj/item/weapon/paper))
		var/input
		var/display = list("Shoji Door - 1", "Shoji Wall - 1", "Shoji Divider - 1", "Shoji Window - 1", "Cancel")
		input =  WWinput(H, "What wall would you like to make?", "Building", "Cancel", display)
		playsound(src.loc,'sound/effects/rip_pack.ogg',40)
		if (input == "Cancel")
			return
		else if(input == "Shoji Door - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/structure/simple_door/key_door/anyone/shoji(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Wall - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/shoji(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Divider - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/shoji_divider(src.loc)
					qdel(src)
					qdel(W)
		else if(input == "Shoji Window - 1")
			if(W.amount >= 1)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/shoji(src.loc)
					qdel(src)
					qdel(W)
		else
			H << "<span class='notice'>That does not exist!</span>"
	else if(istype(W, /obj/item/stack/material/bamboo))
		var/input = WWinput(H, "What wall would you like to make?", "Building", "Cancel",list ("Bamboo Wall - 3", "Bamboo Doorway - 2", "Bamboo Window - 2", "Cancel"))
		if (input == "Cancel")
			return
		if(input == "Bamboo Wall - 3")
			if(W.amount >= 3)
				if (do_after(H, 40, src))
					new/obj/covers/wood_wall/bamboo(src.loc)
					qdel(src)
					W.amount -= 3
		else if(input == "Bamboo Doorway - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					var/obj/covers/wood_wall/bamboo/S = new /obj/covers/wood_wall/bamboo(loc)
					S.icon_state = "bamboo-door"
					S.name = "bamboo doorway"
					S.desc = "A doorway made from bamboo."
					S.density = FALSE
					S.opacity = FALSE
					qdel(src)
					W.amount -= 2
		else if(input == "Bamboo Window - 2")
			if(W.amount >= 2)
				if (do_after(H, 40, src))
					new/obj/structure/window_frame/bamboo(src.loc)
					qdel(src)
					W.amount -= 2
		else
			H << "<span class='notice'>That does not exist!</span>"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////SHIP////////////////////////////////////////////////////////////////////////////////////////////////////////
/obj/structure/ship_bow
	name = "bowstir"
	desc = "A large bow mast, for the front of a ship."
	icon = 'icons/obj/vehicles/bow.dmi'
	icon_state = "bowstir"
	layer = 5
	density = FALSE
	anchored = TRUE


//////////////////////////////////////////////////////////////////////////////
//////////////////////TORCH STAND/////////////////////////////////////////////
/obj/structure/torch_stand
	name = "torch mount"
	desc = "A mount to affix torches or lanterns to the wall"
	icon = 'icons/obj/structures.dmi'
	icon_state = "torch_stand"
	item_state = "torch_stand"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/obj/item/weapon/storage/internal/storage
	var/max_storage = 3
	var/brightness_on = 5 //luminosity when on

/obj/structure/torch_stand/update_icon()
	if (dir == 1)
		pixel_y = 32
	else
		pixel_y = 0
	if (storage.contents.len > 0)
		for (var/obj/item/flashlight/torch/TOR in src.storage.contents)
			if (TOR.on == TRUE)
				icon_state = "torch_stand1_on"
				set_light(1)
				light_color = "#FCDA7C"
				light_range = 4
				return
			else
				icon_state = "torch_stand1"
				set_light(0)
				light_color = null
				light_range = 0
				return
		for (var/obj/item/flashlight/lantern/LAN in src.storage.contents)
			if (LAN.on == TRUE)
				icon_state = "torch_stand_lantern_on"
				set_light(1)
				light_color = "#FCDA7C"
				light_range = 6
				return
			else
				icon_state = "torch_stand_lantern"
				set_light(0)
				return

	else
		icon_state = "torch_stand"

/obj/structure/torch_stand/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = 1
	storage.max_w_class = 2
	storage.max_storage_space = max_storage*3
	storage.can_hold = list(/obj/item/flashlight/torch, /obj/item/flashlight/lantern)
	update_icon()

/obj/structure/torch_stand/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/torch_stand/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/human) && user in range(1,src))
		storage.open(user)
		update_icon()
	else
		return

/obj/structure/torch_stand/MouseDrop(obj/over_object as obj)
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/torch_stand/attackby(obj/item/W as obj, mob/user as mob)
	..()
	if (storage)
		storage.attackby(W, user)
	update_icon()

/obj/structure/torch_stand/full

/obj/structure/torch_stand/full/New()
	..()
	new /obj/item/flashlight/torch/on(src.storage)
	update_icon()

//////////////////////////CAMONET/////////////////////////////////

/obj/structure/camonet
	name ="camonet"
	icon = 'icons/obj/structures.dmi'
	icon_state ="camonet"
	layer = MOB_LAYER + 8
	alpha = 175
	density = FALSE
	anchored = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	mouse_opacity = FALSE


///////////////////////CARGO CONTAINERS///////////////////////////

/obj/structure/cargo_container
	name = "cargo container"
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "container1"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	bound_width = 96
	bound_height = 64

/obj/structure/cargo_container/New()
	var/number = rand(1,5)
	icon_state = "container[number]"

/////////////////////CONSTRUCTION PROPS///////////////////////

/obj/structure/machinery/water_pump
	name = "water pump"
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "waterpump"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	bound_width = 96
	bound_height = 96

/obj/structure/machinery/construction_crane
	name = "crane"
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "crane"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	bound_width = 64
	bound_height = 64

/obj/structure/machinery/construction_crane/New()
	if (dir == NORTH || dir == EAST)//Need to find another way to displace bounds than bound_x;bound_y
		bound_width = 64
		bound_height = 64
	else
		bound_width = 64
		bound_height = 64

/obj/structure/machinery/construction_crane/excavator
	name = "excavator"
	icon_state = "excavator"

/obj/structure/machinery/forklift
	name = "forklift"
	desc = "'A lift for forks', this one seems to be out of battery, missing the fuel tank, spark plugs an-- Oh! And the engine is missing too."
	icon = 'icons/obj/vehicles/vehicleparts64x64.dmi'
	icon_state = "forklift"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	bound_width = 64
	bound_height = 64

/obj/structure/machinery/construction_crane/New()
	if (dir == NORTH || dir == EAST)//Need to find another way to displace bounds than bound_x;bound_y
		bound_width = 64
		bound_height = 64
	else
		bound_width = 64
		bound_height = 64

/obj/structure/truck
	name = "transport truck"
	desc = "Doesn't look like this is moving soon."
	icon = 'icons/obj/vehicles/wip_vehicles.dmi'
	icon_state = "truck"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	bound_width = 64
	bound_height = 128

/obj/structure/radome
	name = "radio dome"
	icon = 'icons/obj/decals_widest.dmi'
	icon_state = "radome"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	bound_width = 128
	bound_height = 128

/obj/structure/medical_divider
	name = "medical divider"
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "medical_divider_half"
	density = FALSE
	flammable = TRUE

/obj/structure/medical_divider/full
	icon_state = "medical_divider_full"
	density = TRUE
	flammable = TRUE
