var/list/obj/effect/bump_teleporter/BUMP_TELEPORTERS = list()

/obj/effect/bump_teleporter
	name = "bump-teleporter"
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "x2"
	var/id = null			//id of this bump_teleporter.
	var/id_target = null	//id of bump_teleporter which this moves you to.
	invisibility = 101 		//nope, can't see this
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/active = TRUE
	var/timer = 0			//immediate by default

/obj/effect/bump_teleporter/New()
	..()
	BUMP_TELEPORTERS += src

/obj/effect/bump_teleporter/Destroy()
	BUMP_TELEPORTERS -= src
	return ..()

/obj/effect/bump_teleporter/Bumped(atom/user)
	if (!ismob(user))
		//user.loc = loc	//Stop at teleporter location
		return

	if (!id_target)
		//user.loc = loc	//Stop at teleporter location, there is nowhere to teleport to.
		return

	for (var/obj/effect/bump_teleporter/BT in BUMP_TELEPORTERS)
		if (BT.id == id_target)
			if (active)
				spawn(timer)
					usr.loc = BT.loc	//Teleport to location with correct id.
			return

/obj/effect/step_trigger/Crossed(H as mob|obj)
	Bumped(H)

/obj/effect/step_trigger/attack_hand(mob/living/human/H)
	if (!ishuman(H))
		return
	Bumped(H)