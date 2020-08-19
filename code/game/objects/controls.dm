/obj/structure/gatecontrol
	name = "gate control"
	desc = "Controls nearby gates."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gate_control"
	anchored = TRUE
	var/open = FALSE
	var/cooldown = 0
	var/distance = 3
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/blastcontrol
	name = "blast control"
	desc = "Controls nearby gates."
	icon = 'icons/obj/structures.dmi'
	icon_state = "blast_control"
	anchored = TRUE
	var/open = FALSE
	var/cooldown = 3
	var/distance = 5
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/gatecontrol/sandstone
	name = "gate control"

/obj/structure/gatecontrol/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time - 60)
		if (open)
			visible_message("[user] closes the gates!")
			open = FALSE
			cooldown = world.time
			for (var/obj/structure/gate/G in range(distance,src.loc))
				playsound(loc, 'sound/effects/castle_gate.ogg', 100)
				G.icon_state = "gate_closing"
				spawn(30)
					G.icon_state = "gate0"
					G.density = TRUE
			return
		else
			visible_message("[user] opens the gates!")
			open = TRUE
			cooldown = world.time
			for (var/obj/structure/gate/G in range(distance,src.loc))
				playsound(loc, 'sound/effects/castle_gate.ogg', 100)
				G.icon_state = "gate_opening"
				spawn(30)
					G.icon_state = "gate1"
					G.density = FALSE
			return

/obj/structure/gatecontrol/sandstone/attack_hand(var/mob/user as mob)
	if (cooldown <= world.time - 60)
		if (open)
			visible_message("[user] closes the gates!")
			open = FALSE
			cooldown = world.time
			for (var/obj/structure/gate/sandstone/G in range(distance,src.loc))
				playsound(loc, 'sound/effects/castle_gate.ogg', 100)
				G.icon_state = "s_gate_closing"
				spawn(30)
					G.icon_state = "s_gate0"
					G.density = TRUE
			return
		else
			visible_message("[user] opens the gates!")
			open = TRUE
			cooldown = world.time
			for (var/obj/structure/gate/sandstone/G in range(distance,src.loc))
				playsound(loc, 'sound/effects/castle_gate.ogg', 100)
				G.icon_state = "s_gate_opening"
				spawn(30)
					G.icon_state = "s_gate1"
					G.density = FALSE
			return

/obj/structure/gate
	name = "gate"
	desc = "An iron gate."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "gate0"
	anchored = TRUE
	density = TRUE
	var/health = 600
	var/maxhealth = 600
	not_movable = TRUE
	not_disassemblable = TRUE
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
/obj/structure/blast
	name = "blast door"
	desc = "An thick steel blast door."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "blast0"
	anchored = TRUE
	density = TRUE
	var/health = 1200
	var/maxhealth = 1200
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/gate/open
	name = "gate"
	desc = "An iron gate."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "gate1"
	anchored = TRUE
	density = FALSE
/obj/structure/gate/open/attackby(obj/item/weapon/W as obj, mob/user as mob)
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
/obj/structure/gate/sandstone
	icon_state = "s_gate0"
	anchored = TRUE
	density = TRUE
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

/obj/structure/gate/sandstone/open
	icon_state = "s_gate1"
	anchored = TRUE
	density = FALSE
/obj/structure/gate/sandstone/open/attackby(obj/item/weapon/W as obj, mob/user as mob)
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


/obj/structure/gate/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 150
		if (2.0)
			health -= 100
		if (3.0)
			health -= 50
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is blown apart!</span>")
		qdel(src)
		return
