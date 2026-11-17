// Adhesion (docs/trains.md#wheel-slip-and-sand). An engine can only pull as
// hard as its wheels grip. Opening the throttle wide on a heavy train from a
// stand, or on wet rails, spins the wheels: the train gains nothing until the
// driver eases the throttle or sands the rails.

#define TRAIN_ADHESION 0.8 // share of the spare pull the wheels can put down
#define TRAIN_WET_GRIP 0.6 // grip on rails in rain or snow
#define TRAIN_SLIP_SPEED 1.5 // tiles per second: faster than this the wheels hold
#define TRAIN_SAND_TILES 8 // tiles one charge of sand lasts
#define TRAIN_SAND_MAX 20

/obj/structure/trains/locomotive
	var/sand = TRAIN_SAND_MAX // charges left in the sandbox
	var/tmp/sanding = 0 // tiles of sand still falling under the wheels
	var/tmp/slipping = 0 // slips in a row

// 1 on dry rails, less in rain or snow.
/obj/structure/trains/locomotive/proc/rail_grip()
	var/sky = weather_at(src)
	return (sky == WEATHER_WET || sky == WEATHER_EXTREME) ? TRAIN_WET_GRIP : 1

// TRUE when the throttle asks for more than the wheels can put down.
/obj/structure/trains/locomotive/proc/wheels_slip(grip = null)
	if (sanding > 0 || throttle <= 0 || rail_speed > TRAIN_SLIP_SPEED)
		return FALSE
	if (isnull(grip))
		grip = rail_grip()
	return throttle_share() > TRAIN_ADHESION * grip * pull_ratio()

// One spin of the wheels: steam and fuel for nothing.
/obj/structure/trains/locomotive/proc/wheel_slip()
	slipping++
	if (slipping % 4 == 1)
		visible_message(SPAN_WARNING("\The [src]'s wheels slip on the rails! Ease the throttle or sand the rails."))
		if (isturf(loc))
			playsound(loc, 'sound/effects/clang.ogg', 40, TRUE)
	burn_fuel()

// Drops sand under the wheels for the next few tiles.
/obj/structure/trains/locomotive/proc/sand_rails(mob/user)
	if (sand <= 0)
		if (user)
			to_chat(user, SPAN_WARNING("The sandbox is empty. Fill it with sand."))
		return FALSE
	sand--
	sanding = TRAIN_SAND_TILES
	slipping = 0
	if (user)
		to_chat(user, "You open the sanders. Sand runs under the wheels for the next few lengths. [sand] of [TRAIN_SAND_MAX] left in the sandbox.")
	return TRUE

// Fills the sandbox from a pile of sand. TRUE when W was sand.
/obj/structure/trains/locomotive/proc/fill_sand(obj/item/W, mob/user)
	var/obj/item/stack/ore/glass/pile = W
	if (!istype(pile))
		return FALSE
	var/room = TRAIN_SAND_MAX - sand
	if (room <= 0)
		to_chat(user, "\The [src]'s sandbox is full.")
		return TRUE
	var/taken = min(room, pile.amount)
	sand += taken
	pile.use(taken)
	to_chat(user, "You fill \the [src]'s sandbox. It holds [sand] of [TRAIN_SAND_MAX].")
	return TRUE

/obj/structure/trains/locomotive/attackby(obj/item/W as obj, mob/user as mob)
	if (fill_sand(W, user))
		return
	return ..()

/obj/structure/trains/locomotive/proc/sand_text()
	return "Sandbox: [sand] of [TRAIN_SAND_MAX][sanding > 0 ? ", sanders running" : ""]."

#undef TRAIN_ADHESION
#undef TRAIN_WET_GRIP
#undef TRAIN_SLIP_SPEED
#undef TRAIN_SAND_TILES
#undef TRAIN_SAND_MAX
