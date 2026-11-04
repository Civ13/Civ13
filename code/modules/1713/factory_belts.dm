// Factory belts (phases 1 and 2 of docs/factory-automation-design.md).
//
// Cargo stays an ordinary item on the belt's turf, so picking it up, examining
// it, hover names, saving and rendering all behave as they do for any floor
// item. A belt tracks up to FACTORY_BELT_SLOTS items in fixed positions along
// its travel direction and moves them with raw location writes, so no turf
// Entered hooks run per step. Belts only run while they hold cargo and a
// powered belt drive is in range; idle or unpowered belts leave the process and
// blocked belts poll slowly. Routing belts (factory_routing.dm) only change
// where the exit item goes.

#define FACTORY_BELT_SLOTS 4
#define FACTORY_BELT_TICK 10 // deciseconds between belt steps
#define FACTORY_BELT_SPEED 8 // slots an item may advance per step (two tiles a second)
#define FACTORY_BELT_BLOCKED_POLL 2 // steps between retries of a blocked exit

var/global/list/factory_active_belts = list()
var/global/factory_belt_tick = 0
// Items that crossed onto another belt this step, so they move once per step.
var/global/list/factory_belt_moved = list()

/proc/factory_belts_begin_step()
	factory_belt_tick++
	factory_belt_moved.Cut()
	// Drives settle first, so belts see this step's power.
	factory_drives_step()

// One whole step outside the scheduler, for fixtures and admin tools.
/proc/factory_belts_step()
	factory_belts_begin_step()
	for (var/obj/structure/factory_belt/B in factory_active_belts.Copy())
		if (QDELETED(B))
			factory_active_belts -= B
			continue
		B.belt_step()
	factory_fast_belts_step()

/obj/structure/factory_belt
	name = "factory belt"
	desc = "A roller belt. It carries loose items toward the arrow and hands them to the next belt, a machine or a crate in front of it. It needs a powered belt drive nearby. Use a wrench to turn it."
	icon = 'icons/obj/recycling.dmi'
	icon_state = "conveyor1"
	layer = 2.9
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/tmp/list/cargo = null
	var/tmp/belt_active = FALSE
	var/tmp/next_poll = 0
	var/tmp/obj/structure/factory_drive/drive = null // the powered drive that last ran this belt
	var/assembly_type = /obj/item/factory_belt_assembly
	var/belt_passes = 1 // belt steps per process tick; fast belts take two

/obj/structure/factory_belt/New()
	..()
	cargo = new /list(FACTORY_BELT_SLOTS)
	belt_wake()

/obj/structure/factory_belt/Destroy()
	belt_sleep()
	for (var/obj/item/I in cargo)
		factory_reset_cargo_offset(I)
	cargo = null
	return ..()

/obj/structure/factory_belt/persistence_runtime_var(key)
	if (key == "cargo" || key == "belt_active" || key == "next_poll" || key == "drive")
		return TRUE
	return ..()

/obj/structure/factory_belt/after_load()
	. = ..()
	cargo = new /list(FACTORY_BELT_SLOTS)
	belt_wake()

/obj/structure/factory_belt/examine(mob/user, distance)
	..(user, distance)
	var/count = 0
	for (var/obj/item/I in cargo)
		count++
	to_chat(user, SPAN_NOTICE("It runs [dir2text(dir)] and carries [count] of [FACTORY_BELT_SLOTS] items."))
	if (!belt_powered())
		to_chat(user, SPAN_WARNING("No powered belt drive is in range, so it is stopped."))

/obj/structure/factory_belt/Crossed(atom/movable/AM)
	..()
	if (istype(AM, /obj/item))
		belt_wake()

/obj/structure/factory_belt/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		set_dir(turn(dir, -90))
		for (var/obj/item/I in cargo)
			factory_reset_cargo_offset(I)
		cargo = new /list(FACTORY_BELT_SLOTS)
		playsound(src, 'sound/items/Ratchet.ogg', 50, TRUE)
		to_chat(user, SPAN_NOTICE("You turn \the [src] to run [dir2text(dir)]."))
		belt_wake()
		return
	if (istype(W, /obj/item/weapon/crowbar))
		playsound(src, 'sound/items/Crowbar.ogg', 50, TRUE)
		to_chat(user, SPAN_NOTICE("You pry up \the [src]."))
		new assembly_type(get_turf(src))
		qdel(src)
		return
	// Anything else is dropped onto the belt like onto the floor.
	if (W.loc == user && user.unEquip(W, FALSE, get_turf(src)))
		belt_wake()
		return
	return ..()

/obj/structure/factory_belt/proc/belt_wake()
	next_poll = 0
	if (!belt_active && !QDELETED(src))
		belt_active = TRUE
		factory_active_belts |= src
		if (belt_passes > 1)
			factory_active_fast_belts |= src

/obj/structure/factory_belt/proc/belt_sleep()
	belt_active = FALSE
	factory_active_belts -= src
	factory_active_fast_belts -= src

// A belt runs while a powered drive on its level is within the drive's range.
// The last drive is cached; only a lost drive searches the powered drives.
/obj/structure/factory_belt/proc/belt_powered()
	if (drive && drive.drive_covers(src))
		return TRUE
	drive = null
	for (var/obj/structure/factory_drive/D in factory_powered_drives)
		if (D.drive_covers(src))
			drive = D
			return TRUE
	return FALSE

// Pixel offset of a slot along the travel direction: entry -12, exit +12.
/proc/factory_slot_offset(slot)
	return (slot - (FACTORY_BELT_SLOTS + 1) / 2) * (world.icon_size / FACTORY_BELT_SLOTS)

/proc/factory_reset_cargo_offset(obj/item/I)
	if (I && !QDELETED(I))
		animate(I)
		I.pixel_x = 0
		I.pixel_y = 0

/obj/structure/factory_belt/proc/slot_pixels(slot)
	var/offset = factory_slot_offset(slot)
	var/dx = (dir & EAST) ? 1 : ((dir & WEST) ? -1 : 0)
	var/dy = (dir & NORTH) ? 1 : ((dir & SOUTH) ? -1 : 0)
	return list(dx * offset, dy * offset)

/obj/structure/factory_belt/proc/show_in_slot(obj/item/I, slot, glide = TRUE)
	var/list/P = slot_pixels(slot)
	if (glide)
		animate(I, pixel_x = P[1], pixel_y = P[2], time = FACTORY_BELT_TICK / belt_passes)
	else
		animate(I)
		I.pixel_x = P[1]
		I.pixel_y = P[2]

/proc/factory_belt_cargo_item(obj/item/I)
	return istype(I) && !QDELETED(I) && !I.anchored && !I.abstract && !I.throwing && isturf(I.loc)

// Drop entries that left the tile and adopt loose items that arrived.
/obj/structure/factory_belt/proc/belt_scan()
	var/turf/T = loc
	if (!isturf(T))
		return
	for (var/i in 1 to FACTORY_BELT_SLOTS)
		var/obj/item/I = cargo[i]
		if (I && (QDELETED(I) || I.loc != T || I.anchored))
			cargo[i] = null
	for (var/obj/item/I in T)
		if ((I in cargo) || !factory_belt_cargo_item(I))
			continue
		var/slot = free_slot_near(I)
		if (!slot)
			break
		cargo[slot] = I
		show_in_slot(I, slot, FALSE)

// The free slot closest to where the item already sits along the belt.
/obj/structure/factory_belt/proc/free_slot_near(obj/item/I)
	var/along = 0
	if (dir & (EAST|WEST))
		along = (dir & EAST) ? I.pixel_x : -I.pixel_x
	else
		along = (dir & NORTH) ? I.pixel_y : -I.pixel_y
	var/best = 0
	var/best_distance = 1e9
	for (var/i in 1 to FACTORY_BELT_SLOTS)
		if (cargo[i])
			continue
		var/distance = abs(factory_slot_offset(i) - along)
		if (distance < best_distance)
			best = i
			best_distance = distance
	return best

// A slot is free when empty or when its item has left the tile.
/obj/structure/factory_belt/proc/slot_free(slot)
	var/obj/item/I = cargo[slot]
	if (I && (QDELETED(I) || I.loc != loc || I.anchored))
		cargo[slot] = null
		I = null
	return !I

// Slot an item arriving from from_dir enters: from behind at the start, from
// a side partway along.
/obj/structure/factory_belt/proc/entry_slot(from_dir)
	if (!from_dir || from_dir == turn(dir, 180))
		return 1
	return 2

// Accept an item handed on by another belt. Returns TRUE when it moved here.
/obj/structure/factory_belt/proc/belt_receive(obj/item/I, from_dir)
	var/turf/T = loc
	if (!isturf(T) || !factory_movable_item(I))
		return FALSE
	var/slot = entry_slot(from_dir)
	if (!slot_free(slot))
		return FALSE
	var/list/before = list(I.pixel_x, I.pixel_y)
	if (!factory_place_on_turf(I, T))
		return FALSE
	cargo[slot] = I
	factory_belt_moved[I] = TRUE
	// Continue the glide from where the item was on the previous tile.
	var/step_x = (from_dir & EAST) ? -world.icon_size : ((from_dir & WEST) ? world.icon_size : 0)
	var/step_y = (from_dir & NORTH) ? -world.icon_size : ((from_dir & SOUTH) ? world.icon_size : 0)
	I.pixel_x = before[1] + step_x
	I.pixel_y = before[2] + step_y
	show_in_slot(I, slot)
	belt_wake()
	return TRUE

// Raw location write without turf hooks; light sources use forceMove so their
// light follows them. Movement is refused while a save captures the level.
/proc/factory_place_on_turf(obj/item/I, turf/T)
	if (I.light_range)
		return I.forceMove(T)
	return I.persistence_set_loc(T)

// Directions to try for the exit item, in order. Routing belts override this.
/obj/structure/factory_belt/proc/export_dirs(obj/item/I)
	return list(dir)

// Called after the exit item left toward d.
/obj/structure/factory_belt/proc/exported(obj/item/I, d)
	return

// Hand the exit item to the first output that takes it.
/obj/structure/factory_belt/proc/export_front()
	var/obj/item/I = cargo[FACTORY_BELT_SLOTS]
	if (!I || factory_belt_moved[I])
		return FALSE
	for (var/d in export_dirs(I))
		if (export_to(I, d))
			exported(I, d)
			return TRUE
	return FALSE

// Hand I to whatever is on the tile toward d: a belt, or a factory port.
/obj/structure/factory_belt/proc/export_to(obj/item/I, d)
	var/turf/T = get_step(src, d)
	if (!T)
		return FALSE
	var/obj/structure/factory_belt/next = locate() in T
	if (next)
		return hand_to_belt(I, next, turn(d, 180))
	for (var/obj/O in T)
		if (istype(O, /obj/item) || O.factory_accepts(I, turn(d, 180)) <= 0)
			continue
		if (O.factory_insert(I, turn(d, 180)) <= 0)
			continue
		if (QDELETED(I) || I.loc != loc)
			cargo[FACTORY_BELT_SLOTS] = null
			factory_reset_cargo_offset(I)
		return TRUE
	return FALSE

// Pass the exit item to next, which it enters from from_dir. A belt facing
// back toward that side never takes it.
/obj/structure/factory_belt/proc/hand_to_belt(obj/item/I, obj/structure/factory_belt/next, from_dir)
	if (next.dir == from_dir)
		return FALSE
	if (next.belt_receive(I, from_dir))
		cargo[FACTORY_BELT_SLOTS] = null
		return TRUE
	return FALSE

/obj/structure/factory_belt/proc/belt_step()
	if (!isturf(loc))
		belt_sleep()
		return
	if (next_poll > factory_belt_tick)
		return
	if (!belt_powered())
		// A drive that gains power wakes the belts in its range.
		belt_sleep()
		return
	belt_scan()
	var/moved = FALSE
	var/exit_blocked = FALSE
	var/list/shifted = null
	for (var/pass in 1 to FACTORY_BELT_SPEED)
		var/changed = FALSE
		// Whatever is in front does not change during this belt's step, so a
		// refused hand-off is not retried until the next step.
		if (cargo[FACTORY_BELT_SLOTS] && !exit_blocked)
			if (export_front())
				changed = TRUE
			else
				exit_blocked = TRUE
		for (var/slot = FACTORY_BELT_SLOTS - 1, slot >= 1, slot--)
			var/obj/item/I = cargo[slot]
			if (!I || cargo[slot + 1] || factory_belt_moved[I])
				continue
			cargo[slot + 1] = I
			cargo[slot] = null
			if (!shifted)
				shifted = list()
			shifted[I] = TRUE
			changed = TRUE
		if (!changed)
			break
		moved = TRUE
	// One glide per item per step, to wherever it ended up on this belt.
	for (var/obj/item/I in shifted)
		var/slot = cargo.Find(I)
		if (slot)
			show_in_slot(I, slot)
	if (moved)
		wake_upstream()
		// Loose items left waiting for a free slot board now.
		belt_scan()
	var/occupied = FALSE
	for (var/obj/item/I in cargo)
		occupied = TRUE
		break
	if (!occupied)
		belt_sleep()
	else if (!moved && exit_blocked)
		next_poll = factory_belt_tick + FACTORY_BELT_BLOCKED_POLL
	else
		next_poll = 0

// Belts feeding this one may have been waiting for space.
/obj/structure/factory_belt/proc/wake_upstream()
	for (var/d in cardinal)
		if (d == dir)
			continue
		var/obj/structure/factory_belt/B = locate() in get_step(src, d)
		if (B && B.dir == turn(d, 180) && B.belt_active)
			B.next_poll = 0

// Offered cargo for transfer arms: the item at the exit end.
/obj/structure/factory_belt/factory_offer(to_dir = 0, filter_type = null)
	belt_scan()
	for (var/slot = FACTORY_BELT_SLOTS, slot >= 1, slot--)
		var/obj/item/I = cargo[slot]
		if (I && (!filter_type || istype(I, filter_type)) && factory_movable_item(I))
			return I
	return null

/obj/structure/factory_belt/factory_take(obj/item/I, atom/destination)
	var/slot = cargo.Find(I)
	if (!slot || !destination || !factory_movable_item(I))
		return FALSE
	cargo[slot] = null
	factory_reset_cargo_offset(I)
	I.forceMove(destination)
	belt_wake()
	return I.loc == destination

// Arms place items onto a belt at its entry end.
/obj/structure/factory_belt/factory_accepts(obj/item/I, from_dir = 0)
	if (!factory_movable_item(I) || !isturf(loc))
		return 0
	belt_scan()
	return cargo[entry_slot(from_dir)] ? 0 : factory_item_amount(I)

/obj/structure/factory_belt/factory_insert(obj/item/I, from_dir = 0)
	if (factory_accepts(I, from_dir) <= 0)
		return 0
	var/slot = entry_slot(from_dir)
	var/amount = factory_item_amount(I)
	if (!factory_place_on_turf(I, loc))
		return 0
	cargo[slot] = I
	show_in_slot(I, slot, FALSE)
	belt_wake()
	return amount

/obj/item/factory_belt_assembly
	name = "factory belt assembly"
	desc = "A folded roller belt section. Use it on an adjacent floor tile to lay a belt that runs away from you."
	icon = 'icons/obj/recycling.dmi'
	icon_state = "conveyor0"
	w_class = ITEM_SIZE_LARGE
	var/belt_type = /obj/structure/factory_belt

/obj/item/factory_belt_assembly/afterattack(atom/A, mob/user, proximity)
	if (!proximity || user.incapacitated())
		return
	var/turf/T = get_turf(A)
	if (!T || T == user.loc || T.density)
		return
	var/travel = get_dir(user, T)
	if (!(travel in cardinal))
		to_chat(user, SPAN_WARNING("Lay the belt straight ahead of you, not diagonally."))
		return
	if (locate(/obj/structure/factory_belt) in T)
		to_chat(user, SPAN_WARNING("There is already a belt there."))
		return
	var/obj/structure/factory_belt/B = new belt_type(T)
	B.set_dir(travel)
	B.add_fingerprint(user)
	qdel(src)

#undef FACTORY_BELT_SLOTS
#undef FACTORY_BELT_TICK
#undef FACTORY_BELT_SPEED
#undef FACTORY_BELT_BLOCKED_POLL
