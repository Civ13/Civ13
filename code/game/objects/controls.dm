/obj/structure/gatecontrol
	name = "gate control"
	desc = "Controls nearby gates."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gate_control"
	anchored = TRUE
	var/cooldown = 0
	var/distance = 3
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = 3.01

/obj/structure/gatecontrol/blastcontrol
	name = "blast door control"
	desc = "Controls nearby blastdoors."
	icon = 'icons/obj/structures.dmi'
	icon_state = "blast_control"
	anchored = TRUE
	cooldown = 3
	distance = 5
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/gatecontrol/blastcontrol/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		for (var/obj/structure/gate/blast/G in range(distance,src.loc))
			if (G.open)
				visible_message("[user] closes the blast doors!")
				G.open = FALSE
				cooldown = world.time + 3 SECONDS
				playsound(G.loc, 'sound/effects/rollermove.ogg', 100)
				flick("blast_closing",G)
				spawn(10)
					playsound(G.loc, 'sound/effects/lever.ogg', 100)
					G.icon_state = "blast0"
					G.density = TRUE
					G.opacity = TRUE
			else
				visible_message("[user] opens the blast doors!")
				G.open = TRUE
				cooldown = world.time + 3 SECONDS
				playsound(G.loc, 'sound/effects/lever.ogg', 100)
				flick("blast_opening",G)
				spawn(10)
					playsound(G.loc, 'sound/effects/rollermove.ogg', 100)
					G.icon_state = "blast1"
					G.density = FALSE
					G.opacity = FALSE

/obj/structure/gatecontrol/blastcontrol/garage
	name = "garage shutter control"
	desc = "Controls nearby garage shutters"

/obj/structure/gatecontrol/blastcontrol/garage/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		for (var/obj/structure/gate/blast/G in range(distance,src.loc))
			if (G.open)
				visible_message("[user] closes the shutters!")
				G.open = FALSE
				cooldown = world.time + 6 SECONDS
				flick("garage_closing",G)
				playsound(G.loc, 'sound/effects/garage.ogg', 100)
				spawn(13)
					G.icon_state = "garage_closed"
					G.density = TRUE
					G.opacity = TRUE
			else
				visible_message("[user] opens the shutters!")
				G.open = TRUE
				cooldown = world.time + 6 SECONDS
				flick("garage_opening",G)
				playsound(G.loc, 'sound/effects/garage.ogg', 100)
				spawn(13)
					G.icon_state = "garage_open"
					G.density = FALSE
					G.opacity = FALSE

/obj/structure/gatecontrol/sandstone
	name = "gate control"

/obj/structure/gatecontrol/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		for (var/obj/structure/gate/G in range(distance,src.loc))
			if (G.open)
				visible_message("[user] closes the gates!")
				G.open = FALSE
				cooldown = world.time + 6 SECONDS
				if (G.name == "gate")
					playsound(G.loc, 'sound/effects/castle_gate.ogg', 100)
					G.icon_state = "gate_closing"
					spawn(30)
						G.icon_state = "gate0"
						G.density = TRUE
			else
				visible_message("[user] opens the gates!")
				G.open = TRUE
				cooldown = world.time + 6 SECONDS
				if (G.name == "gate")
					playsound(G.loc, 'sound/effects/castle_gate.ogg', 100)
					G.icon_state = "gate_opening"
					spawn(30)
						G.icon_state = "gate1"
						G.density = FALSE

/obj/structure/gatecontrol/sandstone/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		for (var/obj/structure/gate/sandstone/G in range(distance,src.loc))
			if (G.open)
				visible_message("[user] closes the gates!")
				G.open = FALSE
				cooldown = world.time + 6 SECONDS
				playsound(G.loc, 'sound/effects/castle_gate.ogg', 100)
				flick("s_gate_closing",G)
				spawn(30)
					G.icon_state = "s_gate0"
					G.density = TRUE
			else
				visible_message("[user] opens the gates!")
				G.open = TRUE
				cooldown = world.time + 6 SECONDS
				playsound(G.loc, 'sound/effects/castle_gate.ogg', 100)
				flick("s_gate_opening",G)
				spawn(30)
					G.icon_state = "s_gate1"
					G.density = FALSE

/obj/structure/gate
	name = "gate"
	desc = "An iron gate."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "gate0"
	anchored = TRUE
	density = TRUE
	var/open = FALSE
	var/health = 600
	var/maxhealth = 600
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/gate/open
	name = "gate"
	desc = "An iron gate."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "gate1"
	anchored = TRUE
	density = FALSE
	open = TRUE

/obj/structure/gate/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench) && !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	else
		..()

/obj/structure/gate/blast
	name = "blast door"
	desc = "An thick steel blast door."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "blast0"
	anchored = TRUE
	opacity = TRUE
	density = TRUE
	health = 1200
	maxhealth = 1200
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/gate/blast/open
	name = "blast door"
	desc = "An thick steel blast door."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "blast1"
	opacity = FALSE
	anchored = TRUE
	density = FALSE
	health = 1200
	maxhealth = 1200
	not_movable = TRUE
	not_disassemblable = TRUE
	open = TRUE

/obj/structure/gate/blast/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench) && !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"
		..()

/obj/structure/gate/blast/garage
	name = "garage shutter"
	desc = "A steel garage shutter."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "garage_closed"
	anchored = TRUE
	opacity = TRUE
	density = TRUE
	health = 800
	maxhealth = 800
	not_movable = TRUE

/obj/structure/gate/blast/garage/open
	name = "garage shutter"
	desc = "A steel garage shutter."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "garage_open"
	opacity = FALSE
	anchored = TRUE
	density = FALSE
	health = 800
	maxhealth = 800
	not_movable = TRUE
	open = TRUE

/obj/structure/gate/blast/garage/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/weldingtool)) //No weapons can harm me!
		user << "You hit the [src] uselessly!"
	else if (istype(W,/obj/item/weapon/weldingtool)) //ARGH! MY ONLY WEAKNESS... WELDINGTOOLS!
		user << "<span class='notice'>You start cutting through the [src]...</span>"
		playsound(loc, 'sound/effects/extinguish.ogg', 50, TRUE)
		if (do_after(user, 50, target = src))
			qdel(src)
			return

/obj/structure/gate/sandstone
	name = "sandstone gate"
	icon_state = "s_gate0"
	anchored = TRUE
	density = TRUE

/obj/structure/gate/sandstone/open
	icon_state = "s_gate1"
	anchored = TRUE
	density = FALSE
	open = TRUE

/obj/structure/gate/sandstone/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench) && !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	else
		..()

/obj/structure/gate/whiterun
	name = "Whiterun gate"
	desc = "A large wooden double door"
	icon = 'icons/obj/doors/gates_64x96.dmi'
	icon_state = "whiterun1"
	anchored = TRUE
	density = TRUE
	health = 1000
	maxhealth = 1000
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = MOB_LAYER + 0.01
	bound_width = 64
	bound_height = 64

/obj/structure/gate/whiterun/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon) && !istype(W,/obj/item/weapon/wrench) && !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the doors uselessly!"//sucker
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	else
		..()

/obj/structure/gate/whiterun/r
	name = "Whiterun gate"
	icon_state = "whiterun2"

/obj/structure/gate/whiterun/l
	name = "Whiterun gate"
	icon_state = "whiterun1"

/obj/structure/gate/ex_act(severity)
	switch(severity)
		if (1)
			health -= 150
		if (2)
			health -= 100
		if (3)
			health -= 50
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is blown apart!</span>")
		qdel(src)
		return

/obj/structure/gatecontrol/whiterun
	name = "gate control"
	desc = "Controls nearby gates."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gate_control"
	anchored = TRUE
	cooldown = 0
	distance = 6
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/gatecontrol/whiterun/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		for (var/obj/structure/gate/whiterun/r/G in range(distance,src.loc))
			if (G.open)
				visible_message("[user] closes the gates!")
				G.open = FALSE
				cooldown = world.time + 6 SECONDS
				if (G.name == "Whiterun gate")
					playsound(loc, 'sound/effects/castle_gate.ogg', 100)
					flick("whiterun2_closing",G)
					spawn(30)
						G.icon_state = "whiterun2"
						G.density = TRUE
			else
				visible_message("[user] opens the gates!")
				G.open = TRUE
				cooldown = world.time + 6 SECONDS
				if (G.name == "Whiterun gate")
					playsound(loc, 'sound/effects/castle_gate.ogg', 100)
					flick("whiterun2_opening",G)
					spawn(30)
						G.icon_state = "whiterun2_open"
						G.density = FALSE

		for (var/obj/structure/gate/whiterun/l/G in range(distance,src.loc))
			if (G.open)
				visible_message("[user] closes the gates!")
				G.open = FALSE
				cooldown = world.time + 6 SECONDS
				if (G.name == "Whiterun gate")
					playsound(loc, 'sound/effects/castle_gate.ogg', 100)
					flick("whiterun1_closing",G)
					spawn(30)
						G.icon_state = "whiterun1"
						G.density = TRUE
			else
				visible_message("[user] opens the gates!")
				G.open = TRUE
				cooldown = world.time + 6 SECONDS
				if (G.name == "Whiterun gate")
					playsound(loc, 'sound/effects/castle_gate.ogg', 100)
					flick("whiterun1_opening",G)
					spawn(30)
						G.icon_state = "whiterun1_open"
						G.density = FALSE

/////////////////////////////////////////////////////////////////////////////////
/obj/structure/gate/barrier
	name = "barrier gate"
	desc = "A long barrier gate."
	icon = 'icons/obj/doors/gates_64x64.dmi'
	icon_state = "barriergate"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	health = 100
	maxhealth = 100
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = MOB_LAYER + 0.01
	climbable = TRUE
	open = FALSE
	var/cooldown = 0
	bound_width = 64

/obj/structure/gate/barrier/vertical
	name = "barrier gate"
	desc = "A long barrier gate."
	icon = 'icons/obj/doors/gates_64x64.dmi'
	icon_state = "barriergate_vertical_left"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	health = 100
	maxhealth = 100
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = MOB_LAYER + 0.01
	climbable = TRUE
	open = FALSE
	cooldown = 0
	bound_width = 32
	bound_height = 64 // Only left facing version present because the rest of those variables, a solution would be to separate the open states from the closed states by making two separate .dmi files, where one's icon sizes are 64x32px, while the other one is 32x64px (not tested though)

/obj/structure/gate/barrier/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		if (open)
			visible_message("[user] closes the barrier gate!")
			open = FALSE
			cooldown = world.time + 2 SECONDS
			playsound(loc, 'sound/effects/lever.ogg', 100)
			icon_state = "barriergate"
			density = TRUE
			return
		else
			visible_message("[user] opens the barrier gate!")
			open = TRUE
			cooldown = world.time + 2 SECONDS
			playsound(loc, 'sound/effects/lever.ogg', 100)
			icon_state = "barriergate_open"
			density = FALSE
			return

/obj/structure/gate/barrier/vertical/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		if (open)
			visible_message("[user] closes the barrier gate!")
			open = FALSE
			cooldown = world.time + 2 SECONDS
			playsound(loc, 'sound/effects/lever.ogg', 100)
			icon_state = "barriergate_vertical_left"
			density = TRUE
			return
		else
			visible_message("[user] opens the barrier gate!")
			open = TRUE
			cooldown = world.time + 2 SECONDS
			playsound(loc, 'sound/effects/lever.ogg', 100)
			icon_state = "barriergate_vertical_left_open"
			density = FALSE
			return

//Make it destroyable as it takes basis from the usual gates which can't be broken, using a weapon simply says "You hit the gate uselessly."

/////Pseudo-Elavators///// Currently designed for a 2x2 enclosed space, code needs to be overhauled in case we want bigger, more complex elevators (see about porting Baystation's turbolifts)

/obj/structure/gate/elevator_door
	name = "elevator door"
	desc = "An elevator."
	icon = 'icons/obj/doors/doors_64x32.dmi'
	icon_state = "elevator_door"
	anchored = TRUE
	density = TRUE
	opacity = TRUE
	health = 200
	maxhealth = 200
	not_movable = TRUE
	not_disassemblable = TRUE
	layer = MOB_LAYER + 0.01
	open = FALSE
	bound_width = 64
	var/list/opacity_objects = list()

/obj/structure/gate/elevator_door/New()
	..()
	var/atom/movable/S = new (locate(x+1,y,z))
	S.set_opacity(opacity)
	S.anchored = 1
	S.icon = null
	S.verbs.Cut()
	opacity_objects += S
	autoclose()

/obj/structure/gate/elevator_door/Destroy()
	for(var/atom/movable/S in opacity_objects)
		qdel(S)
	..()

/obj/structure/gate/elevator_door/proc/toggle()
	playsound(src.loc, 'sound/effects/elevatordoor.ogg', 100)
	if (open)
		visible_message("The elevator door closes.")
		open = FALSE
		flick("elevator_doorclosing",src)
		spawn(10)
			icon_state = "elevator_door"
			density = TRUE
			opacity = TRUE
			for(var/atom/movable/S in opacity_objects)
				S.set_opacity(TRUE)
	else
		visible_message("The elevator door opens.")
		open = TRUE
		flick("elevator_dooropening",src)
		spawn(10)
			icon_state = "elevator_dooropen"
			density = FALSE
			opacity = FALSE
			for(var/atom/movable/S in opacity_objects)
				S.set_opacity(FALSE)

/obj/structure/gate/elevator_door/proc/autoclose()
	if (src.open)
		spawn(80)
			src.toggle()
			return
	autoclose()

/obj/structure/gatecontrol/elevator_door
	name = "elevator door button"
	desc = "Calls for an elevator."
	icon = 'icons/obj/structures.dmi'
	icon_state = "lift_panel2"
	anchored = TRUE
	cooldown = 5
	distance = 5
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/gatecontrol/elevator_door/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time)
		for (var/obj/structure/gate/elevator_door/D in range(distance,src.loc))
			D.toggle()
		cooldown = world.time + 6 SECONDS

/obj/structure/elevator_button
	name = "elevator control button"
	icon = 'icons/obj/structures.dmi'
	icon_state = "lift_panel"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/next_activation = -1

/obj/structure/elevator_button/attack_hand(var/mob/user as mob)
	if (world.time < next_activation)
		next_activation = world.time + 5 SECONDS
	else
		next_activation = world.time + 15 SECONDS
		for (var/obj/structure/gate/elevator_door/D in range(4,src.loc))
			if (D.open)
				D.toggle()
		spawn(5)
			visible_message("The elevator is departing!")
			spawn(10)
				for (var/mob/M in range(1, src))
					if (M.z == 1)
						M.z = 2
					else if (M.z == 2)
						M.z = 1
					M << "The elevator has arrived!"
				for (var/obj/O in range(1, src))
					if (!istype(O, /obj/structure/elevator_button/) && !istype (O, /obj/covers/))
						if (O.z == 1)
							O.z = 2
						else if (O.z == 2)
							O.z = 1
				spawn(5)
					var/destination_upper = locate(src.x, src.y, src.z+1)
					var/destination_lower = locate(src.x, src.y, src.z-1)
					if (src.z == 1)
						for (var/obj/structure/gate/elevator_door/D in range(4,destination_upper))
							D.toggle()
							playsound(destination_upper, 'sound/effects/elevatording.ogg', 100)
					else
						for (var/obj/structure/gate/elevator_door/D in range(4,destination_lower))
							D.toggle()
							playsound(destination_lower, 'sound/effects/elevatording.ogg', 100)
//////////////////////////////////////////////////////////////////////////////////////////////////
