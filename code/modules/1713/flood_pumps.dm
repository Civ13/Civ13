// Pumps for cellars and low ground (docs/river-flood.md, "Pumps").
//
// Cellar pumps keep the cellar tiles within their reach dry while they work
// (flood_cellars.dm): a hand lever pump while someone works it, a steam mine
// pump while it has fuel, an electric sump pump on mains power, with a float
// switch so it only runs when water comes in and a battery for when the
// power fails. A windmill pump on the edge of a hollow lifts its water out
// whenever the wind blows.
//
// Pumps that run by themselves are stepped once a minute with the hollows.

#define LEVER_STROKE_TIME 30
// Deciseconds of dry cellar each stroke buys, and the most it can bank.
#define LEVER_STROKE_DRY 300
#define LEVER_MAX_DRY 3000
#define SUMP_BATTERY_MAX 60
#define SUMP_CHARGE_PER_MINUTE 5
// Tile-levels a minute a windmill lifts per point of wind (0 to 4).
#define WINDMILL_LIFT_PER_WIND 0.4

var/global/list/windmill_pumps = list()

// ---- cellar pumps ---------------------------------------------------------------

/obj/structure/cellar_pump
	icon = 'icons/obj/flood_defences.dmi'
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	layer = 3.1
	not_movable = TRUE
	not_disassemblable = FALSE
	cellar_reach = 3
	var/state_prefix = "lever_pump"
	var/on_suffix = "_on"
	// Set once a minute (and when switched) so the depth lookups stay cheap.
	var/tmp/running = FALSE

/obj/structure/cellar_pump/persistence_runtime_var(key)
	return key == "running" || ..()

/obj/structure/cellar_pump/New()
	..()
	cellar_pumps |= src
	update_icon()

/obj/structure/cellar_pump/on_runtime_spawn()
	..()
	cellar_pumps |= src

/obj/structure/cellar_pump/Destroy()
	cellar_pumps -= src
	flood_draw_revision++
	return ..()

/obj/structure/cellar_pump/cellar_pumping()
	return running

/obj/structure/cellar_pump/update_icon()
	icon_state = "[state_prefix][cellar_pumping() ? on_suffix : ""]"

/obj/structure/cellar_pump/proc/set_running(state)
	if (running == state)
		return
	running = state
	flood_draw_revision++
	update_icon()

// Once a minute with the hollows, for pumps on the cellar level.
/obj/structure/cellar_pump/proc/cellar_minute()
	return

/obj/structure/cellar_pump/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE("While it works it keeps the floor within [cellar_reach] tiles of it dry. It is [cellar_pumping() ? "pumping" : "idle"]."))

// A hand lever pump: each stroke keeps the cellar dry a while longer.
/obj/structure/cellar_pump/lever
	name = "hand bilge and cellar pump"
	desc = "A cast-iron hand pump for a cellar or mine ashore, or a ship's bilge when mounted on deck. Work the lever by hand."
	icon_state = "lever_pump"
	state_prefix = "lever_pump"
	on_suffix = "_use"
	cellar_reach = 3
	var/tmp/pumped_until = 0
	var/tmp/busy = FALSE

/obj/structure/cellar_pump/lever/persistence_runtime_var(key)
	return key == "pumped_until" || key == "busy" || ..()

/obj/structure/cellar_pump/lever/cellar_pumping()
	return world.time < pumped_until

/obj/structure/cellar_pump/lever/proc/stroke()
	pumped_until = min(max(pumped_until, world.time) + LEVER_STROKE_DRY, world.time + LEVER_MAX_DRY)
	flood_draw_revision++

/obj/structure/cellar_pump/lever/attack_hand(mob/living/user)
	if (!istype(user))
		return ..()
	if (busy)
		to_chat(user, SPAN_WARNING("Someone is already working \the [src]."))
		return
	busy = TRUE
	icon_state = "lever_pump_use"
	to_chat(user, SPAN_NOTICE("You start working the handle of \the [src]."))
	var/strokes = 0
	while (do_after(user, LEVER_STROKE_TIME, src))
		stroke()
		strokes++
		if (pumped_until >= world.time + LEVER_MAX_DRY)
			to_chat(user, SPAN_NOTICE("The pump sucks air: the cellar is as dry as it will get for now."))
			break
	busy = FALSE
	update_icon()
	if (strokes)
		to_chat(user, SPAN_NOTICE("You stop pumping. The floor around it should stay dry for about [round((pumped_until - world.time) / 600, 1)] minute\s."))

/obj/structure/cellar_pump/lever/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE("Work the lever ashore to drain a cellar or mine, or on a ship's deck to pump its bilge."))

/obj/structure/cellar_pump/lever/update_icon()
	icon_state = busy ? "lever_pump_use" : "lever_pump"

// A steam mine pump: fuel in, the whole working stays dry.
/obj/structure/cellar_pump/steam
	name = "steam bilge and mine pump"
	desc = "A steam pump that drains a mine or cellar ashore, or a ship's bilge when mounted on deck. Feed it coal, charcoal or wood and start it by hand."
	icon_state = "mine_pump"
	state_prefix = "mine_pump"
	cellar_reach = 7
	var/on = FALSE
	var/fuel = 0
	var/max_fuel = 240

/obj/structure/cellar_pump/steam/New()
	..()
	set_running(on && fuel > 0)

/obj/structure/cellar_pump/steam/on_runtime_spawn()
	..()
	set_running(on && fuel > 0)

/obj/structure/cellar_pump/steam/cellar_minute()
	if (on)
		fuel = max(0, fuel - 1)
		if (fuel <= 0)
			on = FALSE
			visible_message(SPAN_WARNING("\The [src]'s fire burns out and the beam stops."))
	set_running(on && fuel > 0)

/obj/structure/cellar_pump/steam/attackby(obj/item/I, mob/living/user)
	var/per = solid_fuel_unit_value(I, sewer_pump_fuel_rates)
	if (!per || !istype(I, /obj/item/stack))
		return ..()
	var/obj/item/stack/S = I
	var/take = min(S.amount, round((max_fuel - fuel) / per))
	if (take <= 0)
		to_chat(user, SPAN_WARNING("\The [src]'s firebox is full."))
		return
	S.use(take)
	fuel += take * per
	to_chat(user, SPAN_NOTICE("You stoke \the [src]. It has fuel for [fuel] minute\s of pumping."))

/obj/structure/cellar_pump/steam/attack_hand(mob/living/user)
	if (!istype(user))
		return ..()
	if (!on && fuel <= 0)
		to_chat(user, SPAN_WARNING("Its firebox is empty. Feed it coal, charcoal or wood."))
		return
	on = !on
	set_running(on && fuel > 0)
	user.visible_message(SPAN_NOTICE("[user] [on ? "starts" : "stops"] \the [src]."), SPAN_NOTICE("You [on ? "start" : "stop"] \the [src]."))

/obj/structure/cellar_pump/steam/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE("On land, it drains cellars and mines. On a ship's deck, it pumps the bilge. It has fuel for [fuel] minute\s of pumping."))

// An electric sump pump: a float switch runs it only when water comes in,
// and a battery keeps it going for an hour when the power fails.
/obj/structure/cellar_pump/sump
	name = "sump pump"
	desc = "An electric pump in a pit in the cellar floor. A float switch starts it when water comes in, and a battery runs it for an hour if the power fails in the storm. Lay a powered cable under it or run it from an outlet."
	icon_state = "sump_pump"
	state_prefix = "sump_pump"
	cellar_reach = 3
	density = FALSE
	layer = 2.05
	powerneeded = 15
	var/on = TRUE
	var/battery = SUMP_BATTERY_MAX

// Water would stand here now if nothing pumped it.
/obj/structure/cellar_pump/sump/proc/water_coming_in()
	var/datum/river_flood/F = map ? map.river_flood() : null
	return F && z == F.cellar_z() && F.seep_depth_at(loc, TRUE) > 0

/obj/structure/cellar_pump/sump/proc/release_power()
	var/need = powerneeded
	powerneeded = 0
	draw_cable_power()
	powerneeded = need

/obj/structure/cellar_pump/sump/cellar_minute()
	if (!on || !isturf(loc))
		release_power()
		set_running(FALSE)
		return
	var/wet = water_coming_in()
	if (!wet)
		// Idle on the float switch: draws only to keep the battery up.
		if (battery < SUMP_BATTERY_MAX && draw_cable_power())
			battery = min(SUMP_BATTERY_MAX, battery + SUMP_CHARGE_PER_MINUTE)
		else
			release_power()
		set_running(FALSE)
		return
	if (draw_cable_power())
		battery = min(SUMP_BATTERY_MAX, battery + SUMP_CHARGE_PER_MINUTE)
		set_running(TRUE)
		return
	if (battery > 0)
		battery--
		set_running(TRUE)
		return
	set_running(FALSE)

/obj/structure/cellar_pump/sump/attack_hand(mob/living/user)
	if (!istype(user))
		return ..()
	on = !on
	if (!on)
		release_power()
		set_running(FALSE)
	else
		cellar_minute()
	user.visible_message(SPAN_NOTICE("[user] switches \the [src] [on ? "on" : "off"]."), SPAN_NOTICE("You switch \the [src] [on ? "on" : "off"]."))

/obj/structure/cellar_pump/sump/examine(mob/user, distance = -1)
	. = ..()
	if (. && get_dist(src, user) <= 2)
		to_chat(user, SPAN_NOTICE("It is switched [on ? "on" : "off"]. Its battery holds [battery] minute\s of pumping."))

// ---- windmill pump --------------------------------------------------------------

/obj/structure/water_lift/windmill
	name = "windmill pump"
	desc = "A small drainage mill whose sails turn a scoop wheel, set on the edge of low ground that floods. Whenever the wind blows it lifts the pooled water out over the rim, with nobody at it. Use it to set or release the brake."
	icon_state = "windmill_pump"
	use_state = "windmill_pump_on"
	lift = 0
	var/braked = FALSE
	var/tmp/turning = FALSE

/obj/structure/water_lift/windmill/persistence_runtime_var(key)
	return key == "turning" || ..()

/obj/structure/water_lift/windmill/New()
	..()
	windmill_pumps |= src

/obj/structure/water_lift/windmill/on_runtime_spawn()
	..()
	windmill_pumps |= src

/obj/structure/water_lift/windmill/Destroy()
	windmill_pumps -= src
	return ..()

// Once a minute with the hollows: lifts what the wind gives.
/obj/structure/water_lift/windmill/proc/windmill_minute()
	var/wind = braked ? 0 : weather_wind_at(src)
	lift = wind * WINDMILL_LIFT_PER_WIND
	var/taken = lift > 0 ? lift_once() : 0
	turning = wind > 0
	icon_state = turning ? "windmill_pump_on" : "windmill_pump"
	return taken

/obj/structure/water_lift/windmill/attack_hand(mob/living/user)
	if (!istype(user))
		return ..()
	braked = !braked
	if (braked)
		turning = FALSE
		icon_state = "windmill_pump"
	user.visible_message(SPAN_NOTICE("[user] [braked ? "sets" : "releases"] the brake on \the [src]."), SPAN_NOTICE("You [braked ? "set" : "release"] the brake on \the [src]."))

/obj/structure/water_lift/windmill/examine(mob/user, distance = -1)
	. = ..()
	if (!. || get_dist(src, user) > 2)
		return
	if (braked)
		to_chat(user, SPAN_NOTICE("Its brake is set."))
	else if (!lift_hollow())
		to_chat(user, SPAN_WARNING("There is no low ground here for it to drain. Set it on the edge of a hollow that floods, beside the ground outside it."))
	else
		to_chat(user, SPAN_NOTICE(turning ? "Its sails are turning." : "Its sails wait for the wind."))

#undef LEVER_STROKE_TIME
#undef LEVER_STROKE_DRY
#undef LEVER_MAX_DRY
#undef SUMP_BATTERY_MAX
#undef SUMP_CHARGE_PER_MINUTE
#undef WINDMILL_LIFT_PER_WIND
