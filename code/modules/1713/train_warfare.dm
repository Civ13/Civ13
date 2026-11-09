// Wartime trains (docs/train-platforms.md): the railway gun car and its brace,
// explosion damage and wrecks for platform cars, and the armored locomotive.
// The armored wagon and flak car are layouts in train_platforms.dm; their
// armor plate stops bullets from outside (train_part/edge/stops_projectile).

#define TRAIN_BRACE_SETTLE 20 // deciseconds a car must stand still before bracing
#define TRAIN_WELD_REPAIR 300 // health a welding pass gives back

/////////////////////////////////////////////////////////////////////////////
// Explosion damage. A wrecked car is knocked off the rails: its train cannot
// move until the car is welded back together.

/obj/structure/trains/platform/ex_act(severity)
	var/damage = 0
	switch (severity)
		if (1.0)
			damage = 450
		if (2.0)
			damage = 220
		if (3.0)
			damage = 80
	var/list/L = layout()
	if (L && L["armored"])
		damage = round(damage * 0.4)
	take_train_damage(damage)

/obj/structure/trains/platform/proc/take_train_damage(amount)
	if (amount <= 0)
		return
	health = max(0, health - amount)
	if (health <= 0 && !wrecked)
		wrecked = TRUE
		visible_message(SPAN_DANGER("\The [src] is blown off the rails!"))
		apply_layout()

/obj/structure/trains/platform/proc/weld_repair(mob/user)
	if (!wrecked && health >= initial(health))
		to_chat(user, "\The [src] is in good repair.")
		return FALSE
	user.visible_message("[user] starts welding \the [src]...", "You start welding \the [src]...")
	if (!do_after(user, 100, src))
		return FALSE
	repair_by(TRAIN_WELD_REPAIR)
	user.visible_message("[user] welds \the [src] back together.", "You weld \the [src] back together.")
	return TRUE

/obj/structure/trains/platform/proc/repair_by(amount)
	health = min(initial(health), health + amount)
	if (wrecked && health >= initial(health) / 2)
		wrecked = FALSE
		apply_layout()

/////////////////////////////////////////////////////////////////////////////
// Railway gun

/obj/structure/cannon/modern/railway
	name = "railway gun"
	desc = "A long-range gun on a turntable, built onto a railway car. It fires only while its car is braced."
	icon = 'icons/obj/vehicles/railway_gun.dmi'
	icon_state = "railway_gun"
	pixel_x = -32
	pixel_y = -32
	bound_width = 32
	bound_height = 32
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	layer = MOB_LAYER + 1
	minrange = 30
	maxrange = 250
	distance = 30
	caliber = 75
	firedelay = 1

// The car this gun stands on, if any.
/obj/structure/cannon/modern/railway/proc/gun_car()
	for (var/obj/structure/trains/platform/P in range(1, src))
		if (loc in train_platform_tiles(P.loc, P.dir))
			return P
	return null

/obj/structure/cannon/modern/railway/proc/fire_problem()
	var/obj/structure/trains/platform/P = gun_car()
	if (!P)
		return "\The [src] has to stand on a railway car to fire."
	if (!P.braced)
		return "Brace the car first: the recoil would throw it off the rails."
	if (P.wrecked)
		return "The car is wrecked."
	return null

/obj/structure/cannon/modern/railway/Topic(href, href_list, hsrc)
	if (href_list["fire"])
		var/problem = fire_problem()
		if (problem)
			to_chat(usr, SPAN_WARNING(problem))
			return FALSE
	return ..()

// Lowers or raises the outriggers of the car it stands on.
/obj/structure/railway_gun_brace
	name = "outrigger lever"
	desc = "Lowers the railway gun car's outriggers so the gun can fire, and raises them so the train can move."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "brace_up"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	layer = 3.1

/obj/structure/railway_gun_brace/proc/brace_car()
	for (var/obj/structure/trains/platform/P in range(1, src))
		if (loc in train_platform_tiles(P.loc, P.dir))
			return P
	return null

/obj/structure/railway_gun_brace/proc/set_braced(state)
	var/obj/structure/trains/platform/P = brace_car()
	if (!P)
		return "The lever has to be on a railway car."
	if (state)
		for (var/obj/structure/trains/platform/S in P.car_segments())
			if (world.time - S.last_moved < TRAIN_BRACE_SETTLE)
				return "Wait for the train to stop."
	for (var/obj/structure/trains/platform/S in P.car_segments())
		S.braced = !!state
	icon_state = state ? "brace_down" : "brace_up"
	return null

/obj/structure/railway_gun_brace/attack_hand(mob/user)
	if (!ishuman(user))
		return ..()
	var/obj/structure/trains/platform/P = brace_car()
	var/state = !(P && P.braced)
	var/problem = set_braced(state)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
	user.visible_message("[user] [state ? "lowers" : "raises"] the outriggers.", "You [state ? "lower" : "raise"] the outriggers. [state ? "The gun can fire; the train cannot move." : "The train can move again."]")
	return TRUE

/////////////////////////////////////////////////////////////////////////////
// Armored locomotive: the steam engine with plating. Explosions wear it down
// instead of destroying it; at zero health it stalls until welded.

/obj/structure/trains/locomotive/coal/armored
	name = "armored locomotive"
	desc = "A steam locomotive cased in riveted steel plate. Works with coal, wood, and so on."
	health = 3000
	max_fuel = 150
	max_train_speed = 6
	train_speed = 6
	var/disabled = FALSE

/obj/structure/trains/locomotive/coal/armored/New()
	..()
	overlays += image('icons/obj/vehicles/train_platforms.dmi', "loco_armor")

/obj/structure/trains/locomotive/coal/armored/ex_act(severity)
	var/damage = 0
	switch (severity)
		if (1.0)
			damage = 300
		if (2.0)
			damage = 120
		if (3.0)
			damage = 30
	health = max(0, health - damage)
	if (health <= 0 && !disabled)
		disabled = TRUE
		automovement = FALSE
		on = FALSE
		visible_message(SPAN_DANGER("\The [src]'s boiler is holed and the engine dies!"))

/obj/structure/trains/locomotive/coal/armored/bullet_act(obj/item/projectile/P, def_zone)
	return PROJECTILE_CONTINUE

/obj/structure/trains/locomotive/coal/armored/attack_hand(mob/living/user as mob)
	if (disabled)
		to_chat(user, SPAN_WARNING("The boiler is holed. Weld it before the engine will run."))
		return
	return ..()

/obj/structure/trains/locomotive/coal/armored/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/weldingtool))
		if (!disabled && health >= initial(health))
			to_chat(user, "\The [src] is in good repair.")
			return
		user.visible_message("[user] starts welding \the [src]...", "You start welding \the [src]...")
		if (do_after(user, 100, src))
			health = min(initial(health), health + 600)
			if (disabled && health >= initial(health) / 2)
				disabled = FALSE
			user.visible_message("[user] welds \the [src]'s plating.", "You weld \the [src]'s plating.")
		return
	return ..()

/obj/structure/trains/locomotive/coal/armored/examine(mob/user)
	..()
	if (disabled)
		to_chat(user, SPAN_WARNING("Its boiler is holed. A welding tool will fix it."))
	else if (health < initial(health))
		to_chat(user, "Its plating is damaged ([round(100 * health / initial(health))]%).")

/////////////////////////////////////////////////////////////////////////////
// Kits

/obj/structure/train_car_kit/railgun
	name = "railway gun car kit"
	car_kind = "railgun"
/obj/structure/train_car_kit/armored
	name = "armored wagon kit"
	car_kind = "armored"
/obj/structure/train_car_kit/flak
	name = "flak car kit"
	car_kind = "flak"
