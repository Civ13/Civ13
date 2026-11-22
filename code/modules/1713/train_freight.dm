// Bulk freight (docs/trains.md#bulk-freight). Ore, coal and sand travel in
// bulk: tipped into an open wagon or a hopper, the load is a kind and a
// count on the car, not loose items on its deck. That is what keeps a loaded
// ore train cheap to move.
//
// - `bulk_amount` lives on the car's first section; `bulk_path` and
//   `bulk_fill` are copied to every section so each draws its own heap.
// - An open wagon is loaded by hand and emptied with a shovel.
// - A hopper also drops its whole load through its floor: into a drop pit
//   under the track when it stands over one, otherwise on the ground.

#define TRAIN_BULK_PER_WEIGHT 200 // units of bulk that weigh as much as one section of a car
#define TRAIN_BULK_SHOVEL_TIME 20
#define TRAIN_BULK_DROP_TIME 30
#define DROP_PIT_MAX 3000

/obj/structure/trains/platform
	var/bulk_path = null // the type of stack this car is loaded with, as text
	var/bulk_amount = 0 // units, on the car's first section
	var/bulk_fill = 0 // 0 empty, 1 part loaded, 2 full: what each section shows

// What travels in bulk: ore, coal and sand by the stack.
/proc/train_bulk_item(obj/item/stack/ore/S)
	return istype(S) && !S.radioactive && S.amount > 0

/proc/train_bulk_name(path)
	var/obj/item/stack/S = text2path("[path]")
	return S ? initial(S.name) : "bulk"

// How a load looks from above: "coal", "sand" or "ore".
/proc/train_bulk_tone(path)
	var/kind = text2path("[path]")
	if (ispath(kind, /obj/item/stack/ore/coal) || ispath(kind, /obj/item/stack/ore/charcoal))
		return "coal"
	if (ispath(kind, /obj/item/stack/ore/glass) || ispath(kind, /obj/item/stack/ore/saltpeter) || ispath(kind, /obj/item/stack/ore/sulphur))
		return "sand"
	return "ore"

// Puts `units` of a bulk kind on the ground at where, in stacks.
/proc/train_bulk_spill(path, units, list/where)
	var/kind = text2path("[path]")
	if (!ispath(kind, /obj/item/stack) || units <= 0 || !where || !where.len)
		return 0
	var/i = 0
	. = 0
	while (units > 0)
		i++
		var/turf/T = where[(i - 1) % where.len + 1]
		var/obj/item/stack/S = new kind(T)
		var/n = min(units, S.max_amount || 50)
		S.amount = n
		S.update_icon()
		units -= n
		. += n

// Units of bulk this kind of car carries; 0 for a car that carries none.
/obj/structure/trains/platform/proc/bulk_max()
	var/list/L = layout()
	return (L && L["bulk"]) ? L["bulk"] : 0

/obj/structure/trains/platform/proc/is_hopper()
	var/list/L = layout()
	return L && L["hopper"]

// The section that holds the car's load, or null when it carries none.
/obj/structure/trains/platform/proc/bulk_store()
	if (!bulk_max())
		return null
	if (seg_index == 1)
		return src
	for (var/obj/structure/trains/platform/P in car_segments())
		if (P.seg_index == 1)
			return P
	return null

// The load's weight, counted once for the car.
/obj/structure/trains/platform/proc/bulk_weight()
	return (seg_index == 1 && bulk_amount > 0) ? bulk_amount / TRAIN_BULK_PER_WEIGHT : 0

// Every section shows the load; the train is added up again.
/obj/structure/trains/platform/proc/update_bulk()
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S)
		return
	if (S.bulk_amount <= 0)
		S.bulk_amount = 0
		S.bulk_path = null
	var/top = bulk_max()
	var/fill = S.bulk_amount <= 0 ? 0 : (S.bulk_amount * 2 >= top ? 2 : 1)
	for (var/obj/structure/trains/platform/P in car_segments())
		P.bulk_path = S.bulk_path
		P.bulk_fill = fill
		P.update_car_overlays()
	train_weights_changed()

// The heap a section shows (update_car_overlays()).
/obj/structure/trains/platform/proc/bulk_overlay()
	if (bulk_fill <= 0 || !bulk_path)
		return null
	var/image/heap = image('icons/obj/vehicles/train_loads.dmi', "heap_[train_bulk_tone(bulk_path)]_[bulk_fill]", layer = layer + 0.02)
	heap.pixel_x = -world.icon_size
	heap.pixel_y = -world.icon_size
	return heap

// Tips a stack in. Returns the units the car took.
/obj/structure/trains/platform/proc/bulk_load(obj/item/stack/ore/W)
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S || !train_bulk_item(W))
		return 0
	if (S.bulk_amount > 0 && S.bulk_path != "[W.type]")
		return 0
	var/take = min(W.amount, bulk_max() - S.bulk_amount)
	if (take <= 0)
		return 0
	S.bulk_path = "[W.type]"
	S.bulk_amount += take
	W.use(take)
	update_bulk()
	return take

// Takes up to `want` units off the car without making anything of them.
/obj/structure/trains/platform/proc/bulk_remove(want)
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S || S.bulk_amount <= 0 || want <= 0)
		return 0
	. = min(want, S.bulk_amount)
	S.bulk_amount -= .
	update_bulk()

// Shovels up to `want` units out onto where. Returns the units that came out.
/obj/structure/trains/platform/proc/bulk_take(want, turf/where)
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S || S.bulk_amount <= 0 || !where)
		return 0
	var/path = S.bulk_path
	return train_bulk_spill(path, bulk_remove(want), list(where))

/obj/structure/trains/platform/proc/bulk_text()
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S)
		return null
	var/how = is_hopper() ? "Tip ore, coal or sand in. Its door lever drops the load through the floor, into a drop pit if it stands over one." : "Tip ore, coal or sand in, and shovel it out."
	if (S.bulk_amount <= 0)
		return "It carries up to [bulk_max()] units of one kind of bulk and is empty. [how]"
	return "It carries [S.bulk_amount] of [bulk_max()] units of [train_bulk_name(S.bulk_path)]. [how]"

// By hand: a stack to tip in, a shovel to dig out. TRUE when W was used.
/obj/structure/trains/platform/proc/bulk_use(obj/item/W, mob/living/user)
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S || !istype(user))
		return FALSE
	if (istype(W, /obj/item/stack/ore))
		if (!train_bulk_item(W))
			to_chat(user, SPAN_WARNING("That does not travel in bulk."))
			return TRUE
		if (S.bulk_amount > 0 && S.bulk_path != "[W.type]")
			to_chat(user, SPAN_WARNING("\The [src] is loaded with [train_bulk_name(S.bulk_path)]. A car carries one kind at a time."))
			return TRUE
		var/took = bulk_load(W)
		if (!took)
			to_chat(user, "<span class = 'notice'>\The [src] is full.</span>")
			return TRUE
		playsound(loc, 'sound/effects/shovelling.ogg', 60, TRUE)
		to_chat(user, "You tip [took] into \the [src]. It carries [S.bulk_amount] of [bulk_max()] units of [train_bulk_name(S.bulk_path)].")
		return TRUE
	if (is_tool(W, TOOL_SHOVEL))
		if (S.bulk_amount <= 0)
			to_chat(user, "\The [src] is empty.")
			return TRUE
		user.visible_message("[user] starts shovelling out of \the [src]...", "You start shovelling out of \the [src]...")
		if (!do_after(user, TRAIN_BULK_SHOVEL_TIME, src) || S.bulk_amount <= 0)
			return TRUE
		var/out = bulk_take(50, get_turf(user))
		playsound(loc, 'sound/effects/shovelling.ogg', 60, TRUE)
		to_chat(user, "You shovel [out] out of \the [src]. [S.bulk_amount] left.")
		return TRUE
	return FALSE

/////////////////////////////////////////////////////////////////////////////
// The hopper

// The drop pit under the car, if it stands over one.
/obj/structure/trains/platform/proc/drop_pit()
	for (var/obj/structure/trains/platform/P in car_segments())
		var/obj/structure/rail_drop_pit/pit = locate() in P.loc
		if (pit)
			return pit
	return null

// Opens the doors in the hopper's floor. Returns the units that dropped.
/obj/structure/trains/platform/proc/drop_load()
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S || !is_hopper() || S.bulk_amount <= 0)
		return 0
	var/path = S.bulk_path
	var/obj/structure/rail_drop_pit/pit = drop_pit()
	if (pit)
		// What the pit has no room for stays in the car.
		return bulk_remove(pit.take_in(path, S.bulk_amount))
	var/list/under = list()
	for (var/obj/structure/trains/platform/P in car_segments())
		under += P.loc
	return train_bulk_spill(path, bulk_remove(S.bulk_amount), under)

/obj/structure/trains/platform/proc/drop_load_by(mob/living/user)
	var/obj/structure/trains/platform/S = bulk_store()
	if (!S || !is_hopper())
		return FALSE
	if (train_rolling())
		to_chat(user, SPAN_WARNING("The train is moving."))
		return FALSE
	if (S.bulk_amount <= 0)
		to_chat(user, "\The [src] is empty.")
		return FALSE
	var/obj/structure/rail_drop_pit/pit = drop_pit()
	if (pit && !pit.room_for(S.bulk_path))
		to_chat(user, SPAN_WARNING("\The [pit] under the car is full, or holds something else. Empty it first."))
		return FALSE
	user.visible_message("[user] starts winding open the hopper doors of \the [src]...", "You start winding the hopper doors open...")
	if (!do_after(user, TRAIN_BULK_DROP_TIME, src) || train_rolling() || S.bulk_amount <= 0)
		return FALSE
	var/out = drop_load()
	playsound(loc, 'sound/effects/shovelling.ogg', 100, TRUE)
	user.visible_message("[user] drops the load of \the [src].", "[out] units rumble out through the floor[pit ? " into \the [pit]" : " onto the track"]. [S.bulk_amount ? "[S.bulk_amount] stay in the car." : "The car is empty."]")
	return TRUE

// The lever that works a hopper's doors. A hopper is built with one.
/obj/structure/train_hopper_lever
	name = "hopper door lever"
	desc = "A lever and ratchet that open the doors in a hopper wagon's floor. Stop the wagon where the load should fall and pull it."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "brace_up"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	layer = 3.1

// The hopper this lever is bolted to, if any.
/obj/structure/train_hopper_lever/proc/hopper()
	if (!anchored || !isturf(loc))
		return null
	for (var/obj/structure/trains/platform/P in range(1, src))
		if (P.is_hopper() && (loc in train_platform_tiles(P.loc, P.dir)))
			return P
	return null

/obj/structure/train_hopper_lever/attack_hand(mob/living/user)
	if (!istype(user, /mob/living/human) || user.incapacitated() || get_dist(user, src) > 1)
		return
	var/obj/structure/trains/platform/P = hopper()
	if (!P)
		to_chat(user, "\The [src] has to stand on a hopper wagon to work.")
		return
	P.drop_load_by(user)

/obj/structure/train_hopper_lever/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		timed_toggle_anchor(user, 30)
		return
	return ..()

/obj/structure/train_hopper_lever/examine(mob/user)
	..()
	if (!anchored)
		to_chat(user, "It is unbolted. Stand it on the deck of a hopper wagon and use a wrench.")
	var/obj/structure/trains/platform/P = hopper()
	var/text = P ? P.bulk_text() : null
	if (text)
		to_chat(user, text)

/////////////////////////////////////////////////////////////////////////////
// The drop pit: a bin under the track that a hopper empties into.

/obj/structure/rail_drop_pit
	name = "drop pit"
	desc = "A timber-lined bin under the rails with a grating over it. A hopper wagon standing over it drops its load in; a shovel digs it out from beside the track."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "drop_pit"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	layer = 2.6
	var/bulk_path = null
	var/bulk_amount = 0

/obj/structure/rail_drop_pit/on_runtime_spawn()
	..()
	update_icon()

/obj/structure/rail_drop_pit/after_load()
	..()
	update_icon()

// It lies along the track it is dug under.
/obj/structure/rail_drop_pit/update_icon()
	var/along = isturf(loc) ? rail_dir_at(loc) : null
	if (along)
		dir = along
	icon_state = bulk_amount > 0 ? "drop_pit_[train_bulk_tone(bulk_path)]" : "drop_pit"

/obj/structure/rail_drop_pit/proc/room_for(path)
	return bulk_amount <= 0 || (bulk_path == "[path]" && bulk_amount < DROP_PIT_MAX)

// Takes up to `units` of a kind. Returns what it took.
/obj/structure/rail_drop_pit/proc/take_in(path, units)
	if (!room_for(path) || units <= 0)
		return 0
	. = min(units, DROP_PIT_MAX - bulk_amount)
	bulk_path = "[path]"
	bulk_amount += .
	update_icon()

// Digs up to `want` units out onto where. Returns the units that came out.
/obj/structure/rail_drop_pit/proc/dig_out(want, turf/where)
	if (bulk_amount <= 0 || want <= 0 || !where)
		return 0
	var/path = bulk_path
	var/out = min(want, bulk_amount)
	bulk_amount -= out
	if (bulk_amount <= 0)
		bulk_path = null
	update_icon()
	return train_bulk_spill(path, out, list(where))

/obj/structure/rail_drop_pit/examine(mob/user)
	..()
	if (bulk_amount > 0)
		to_chat(user, "It holds [bulk_amount] of [DROP_PIT_MAX] units of [train_bulk_name(bulk_path)]. A shovel digs it out.")
	else
		to_chat(user, "It is empty and takes [DROP_PIT_MAX] units of one kind.")

/obj/structure/rail_drop_pit/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_SHOVEL))
		if (bulk_amount <= 0)
			to_chat(user, "\The [src] is empty.")
			return
		user.visible_message("[user] starts digging out \the [src]...", "You start digging out of \the [src]...")
		if (!do_after(user, TRAIN_BULK_SHOVEL_TIME, src) || bulk_amount <= 0)
			return
		var/out = dig_out(50, get_turf(user))
		playsound(loc, 'sound/effects/shovelling.ogg', 60, TRUE)
		to_chat(user, "You dig [out] out of \the [src]. [bulk_amount] left.")
		return
	return ..()

/obj/structure/train_car_kit/hopper
	name = "hopper wagon kit"
	car_kind = "hopper"

#undef TRAIN_BULK_PER_WEIGHT
#undef TRAIN_BULK_SHOVEL_TIME
#undef TRAIN_BULK_DROP_TIME
#undef DROP_PIT_MAX
