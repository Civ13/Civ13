// Building site: the cement mixer, cast concrete and the pile driver.
//
// Concrete is no longer shaped out of raw clay. A hand-cranked mixer turns
// quicklime, sand and stone into concrete blocks, and the concrete floor,
// roof, pillar and bridge span are built from those blocks. Cement bricks
// keep their clay and quicklime route at the brick mould bench.

#define CEMENT_MIXER_LIMIT 20
#define CEMENT_MIXER_TIME 40
#define CEMENT_MIXER_YIELD 4

// One batch: what the drum takes, and the mixer var that counts it.
var/global/list/cement_mixer_charge = list(
	/obj/item/stack/ore/quicklime = list(1, "lime", "quicklime"),
	/obj/item/stack/ore/glass = list(2, "sand", "sand"),
	/obj/item/stack/material/stone = list(2, "stone", "stone"),
)

/material/concrete
	stack_type = /obj/item/stack/material/concrete

/obj/item/stack/material/concrete
	name = "concrete block"
	icon = 'icons/obj/building_site.dmi'
	icon_state = "concrete"
	default_type = "concrete"
	value = 2

/obj/item/stack/material/concrete/New()
	. = ..()
	update_icon()

/obj/item/stack/material/concrete/update_icon()
	icon_state = "concrete[pile_suffix(amount, list(17, 33))]"

//////////////////////////////////////////////////////////////////////////////
// Cement mixer

/obj/structure/workshop_machine/cement_mixer
	name = "cement mixer"
	desc = "An iron drum on a cart, turned by a crank. Load quicklime, sand and stone blocks into it, then crank it with an empty hand: every 1 quicklime, 2 sand and 2 stone turn out 4 concrete blocks."
	icon = 'icons/obj/building_site.dmi'
	icon_state = "cement_mixer"
	var/lime = 0
	var/sand = 0
	var/stone = 0

/obj/structure/workshop_machine/cement_mixer/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("The drum holds [lime] quicklime, [sand] sand and [stone] stone."))

/obj/structure/workshop_machine/cement_mixer/dismantled()
	for (var/kind in cement_mixer_charge)
		var/list/part = cement_mixer_charge[kind]
		var/held = vars[part[2]]
		if (held > 0)
			var/refund_type = kind == /obj/item/stack/material/stone ? /obj/item/stack/material/stone/quarried : kind
			var/obj/item/stack/S = new refund_type(get_turf(src))
			S.amount = held
			S.update_icon()
			vars[part[2]] = 0

// What the drum still lacks for one batch, or null when it can turn.
/obj/structure/workshop_machine/cement_mixer/proc/batch_refusal()
	for (var/kind in cement_mixer_charge)
		var/list/part = cement_mixer_charge[kind]
		if (vars[part[2]] < part[1])
			return "The drum needs [part[1]] [part[3]] for a batch."
	return null

/obj/structure/workshop_machine/cement_mixer/proc/mixer_ready(mob/living/human/H)
	return !QDELETED(src) && anchored && istype(H) && get_dist(src, H) <= 1 && !H.incapacitated() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/obj/structure/workshop_machine/cement_mixer/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	var/list/part = cement_mixer_charge[stone_workshop_feed_type(I)]
	if (!part)
		return ..()
	var/obj/item/stack/S = I
	var/moved = min(S.amount, CEMENT_MIXER_LIMIT - vars[part[2]])
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src] cannot hold any more [part[3]]."))
		return
	vars[part[2]] += moved
	S.use(moved)
	to_chat(H, SPAN_NOTICE("You shovel [moved] [part[3]] into \the [src]."))

/obj/structure/workshop_machine/cement_mixer/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (busy)
		to_chat(H, SPAN_WARNING("Someone is already cranking \the [src]."))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	mix(H)

/obj/structure/workshop_machine/cement_mixer/proc/mix(mob/living/human/H)
	if (busy || !mixer_ready(H))
		return 0
	if (!crafting_recipe_allowed(H, "[type]"))
		to_chat(H, SPAN_WARNING("You do not know how to mix concrete yet."))
		return 0
	var/refusal = batch_refusal()
	if (refusal)
		to_chat(H, SPAN_WARNING(refusal))
		return 0
	busy = TRUE
	icon_state = "cement_mixer_on"
	visible_message(SPAN_NOTICE("[H] starts cranking \the [src]."))
	var/made = 0
	var/obj/item/stack/material/concrete/pile = null
	while (mixer_ready(H) && !batch_refusal())
		if (!do_after(H, driven_time(CEMENT_MIXER_TIME), src))
			break
		if (!mixer_ready(H) || batch_refusal() || !crafting_recipe_allowed(H, "[type]"))
			break
		for (var/kind in cement_mixer_charge)
			var/list/part = cement_mixer_charge[kind]
			vars[part[2]] -= part[1]
		if (QDELETED(pile) || pile.loc != get_turf(src) || pile.amount + CEMENT_MIXER_YIELD > pile.max_amount)
			pile = new(get_turf(src))
			pile.amount = CEMENT_MIXER_YIELD
		else
			pile.amount += CEMENT_MIXER_YIELD
		pile.update_strings()
		pile.update_icon()
		made += CEMENT_MIXER_YIELD
	busy = FALSE
	if (!QDELETED(src))
		icon_state = "cement_mixer"
	if (made)
		to_chat(H, SPAN_NOTICE("You tip out [made] concrete blocks."))
	return made

//////////////////////////////////////////////////////////////////////////////
// Pile driver and timber piers
//
// A timber pier span is laid like the steel and concrete bridge spans in
// bridges.dm, but only over shallow water (Val, 2026-11-14: deep water stays
// for steel and concrete), and its log piles have to be driven: the span
// only goes down within reach of a fastened pile driver.

#define PILE_DRIVER_REACH 2

/obj/structure/workshop_machine/pile_driver
	name = "pile driver"
	desc = "A drop hammer in a tall timber frame. Fasten it on the shore or on the pier built so far; a timber pier span can then be laid on shallow water within two tiles of it. Deep water takes a steel or concrete span."
	icon = 'icons/obj/building_site.dmi'
	icon_state = "pile_driver"

/obj/structure/workshop_machine/pile_driver/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	return ..()

/obj/structure/workshop_machine/pile_driver/attack_hand(mob/living/human/H)
	if (istype(H))
		to_chat(H, SPAN_NOTICE("Lay a timber pier span on shallow water within [PILE_DRIVER_REACH] tiles of \the [src]; the hammer drives its piles."))

// A driver that can drive piles into T: fastened, idle and on firm footing.
/proc/pile_driver_for(turf/T)
	if (!T)
		return null
	for (var/obj/structure/workshop_machine/pile_driver/D in range(PILE_DRIVER_REACH, T))
		var/turf/footing = get_turf(D)
		if (!D.anchored || D.busy || !footing)
			continue
		if (istype(footing, /turf/floor/beach/water/deep) && !footing.iscovered())
			continue
		return D
	return null

/obj/covers/bridge/timber
	name = "timber pier deck"
	desc = "Plank decking on log piles driven into the bed below. Roads and railway track can be laid on it."
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "wood"
	base_icon_state = "wood"
	wood = TRUE
	health = 200
	explosion_resistance = 2
	material = "Wood"
	hardness = 40
	buildstack = /obj/item/stack/material/wood
	span_type = /obj/item/weapon/bridge_span/timber

/obj/item/weapon/bridge_span/timber
	name = "timber pier span"
	desc = "Log piles, beams and planks for one tile of pier or trestle bridge. Use it on shallow water in front of you, within reach of a fastened pile driver. It cannot stand in deep water."
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "wood"
	deck_type = /obj/covers/bridge/timber

/obj/item/weapon/bridge_span/timber/build_span(turf/T, mob/user)
	if (istype(T, /turf/floor/beach/water/deep))
		to_chat(user, SPAN_WARNING("Log piles cannot reach the bed in deep water. A timber pier crosses shallows; deep water takes a steel or concrete span."))
		return FALSE
	var/obj/structure/workshop_machine/pile_driver/D = pile_driver_for(T)
	if (!D)
		to_chat(user, SPAN_WARNING("The piles must be driven. Fasten a pile driver within [PILE_DRIVER_REACH] tiles of that water, on the shore or on the pier built so far."))
		return FALSE
	D.busy = TRUE
	D.icon_state = "pile_driver_on"
	. = ..()
	if (!QDELETED(D))
		D.busy = FALSE
		D.icon_state = "pile_driver"

#undef PILE_DRIVER_REACH

#undef CEMENT_MIXER_LIMIT
#undef CEMENT_MIXER_TIME
#undef CEMENT_MIXER_YIELD
