/obj/structure/functions
	icon = 'icons/obj/decals.dmi'
	icon_state = "woodsign"
	anchored = TRUE
	density = TRUE

/obj/structure/skeleton_activator
	name = "Activate Skeletons"
	desc = "Activate the skeletons."
	icon = 'icons/obj/decals.dmi'
	icon_state = "woodsign"
	anchored = TRUE
	density = TRUE

/obj/structure/skeleton_activator/attack_hand(mob/living/user)
	for (var/obj/effect/spawner/mobspawner/skeletons/SK)
		SK.activated = 1
	for (var/obj/effect/spawner/mobspawner/attacker/SKA)
		SKA.activated = 1
	user << "Skeleton spawners are now ENABLED."
	return

/obj/structure/skeleton_deactivator
	name = "Deactivate Skeletons"
	desc = "Deactivate the skeletons."
	icon = 'icons/obj/decals.dmi'
	icon_state = "woodsign"
	anchored = TRUE
	density = TRUE

/obj/structure/skeleton_deactivator/attack_hand(mob/living/user)
	for (var/obj/effect/spawner/mobspawner/skeletons/SK)
		SK.activated = 0
	for (var/obj/effect/spawner/mobspawner/attacker/SKA)
		SKA.activated = 0
	user << "Skeleton spawners are now DISABLED."
	return

/obj/structure/skeleton_configurator
	name = "Configure Skeletons"
	desc = "Configure the spawn points for skeletons."
	icon = 'icons/obj/decals.dmi'
	icon_state = "woodsign"
	anchored = TRUE
	density = TRUE

/obj/structure/skeleton_configurator/attack_hand(mob/living/user)
	var/maxamount = input(user, "What is the maximum ammount of Skeletons that can be alive, per spawn point? 1 to 50. Default 5.") as num
	maxamount = Clamp(maxamount, 1, 50)
	var/timer = input(user, "What is the delay between spawnings, in seconds? The real value will vary between 100% and 150% of the value you put here. 5 to 300. Default 40.") as num
	timer = Clamp(timer, 5, 300)
	timer *= 10
	for (var/obj/effect/spawner/mobspawner/skeletons/SK)
		SK.max_number = maxamount
		SK.timer = timer
	for (var/obj/effect/spawner/mobspawner/attacker/SKA)
		SKA.max_number = maxamount
		SKA.timer = timer
	user << "Skeleton spawners have been configured to [timer/10] seconds, [maxamount] maximum number."
	return

//BRITISH

/obj/structure/townmilitia_activator
	name = "Activate town militias"
	desc = "Activate the town militias."
	icon = 'icons/obj/decals.dmi'
	icon_state = "woodsign"
	anchored = TRUE
	density = TRUE

/obj/structure/townmilitia_activator/attack_hand(mob/living/user)
	for (var/obj/effect/spawner/mobspawner/townmilitia/RC)
		RC.activated = 1
	user << "Town militia spawners are now ENABLED."
	return

/obj/structure/townmilitia_deactivator
	name = "Deactivate town militias"
	desc = "Deactivate the town militias."
	icon = 'icons/obj/decals.dmi'
	icon_state = "woodsign"
	anchored = TRUE
	density = TRUE

/obj/structure/townmilitia_deactivator/attack_hand(mob/living/user)
	for (var/obj/effect/spawner/mobspawner/townmilitia/RC)
		RC.activated = 0
	user << "Town militia spawners are now DISABLED."
	return

/obj/structure/townmilitia_configurator
	name = "Configure town militias"
	desc = "Configure the spawn points for town militias."
	icon = 'icons/obj/decals.dmi'
	icon_state = "woodsign"
	anchored = TRUE
	density = TRUE

/obj/structure/townmilitia_configurator/attack_hand(mob/living/user)
	var/maxamount = input(user, "What is the maximum ammount of town militias that can be alive, per spawn point? 1 to 50. Default 5.") as num
	maxamount = Clamp(maxamount, 1, 50)
	var/timer = input(user, "What is the delay between spawnings, in seconds? The real value will vary between 100% and 150% of the value you put here. 5 to 300. Default 75.") as num
	timer = Clamp(timer, 5, 300)
	timer *= 10
	for (var/obj/effect/spawner/mobspawner/townmilitia/RC)
		RC.max_number = maxamount
		RC.timer = timer
	user << "Town militia spawners have been configured to [timer/10] seconds, [maxamount] maximum number."
	return