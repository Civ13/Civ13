// Stack counts on inventory slots.
//
// A stack of more than one thing that is held, worn or lying in a bag shows
// how many it holds in the top-right corner of its slot: hand and equipment
// slots of every HUD style and the classic bag strip. One thing shows nothing.
// A full stack shows its number in amber.
//
// The number is a shared, non-clickable object placed in the item's
// vis_contents, so an item's own update_icon (many cut their overlays) never
// wipes it and the item's colour never tints it. One badge exists per number
// shown; items showing the same count share it. Its figures are the hand-placed
// glyphs of icons/mob/screen/stack_count.dmi (tests/sprites/create_stack_count.py).
//
// The count follows the item:
// - at once when it is equipped, dropped, put in or taken out of storage, a
//   bag is opened, or a stack is used, merged, split or transferred;
// - within one Life tick for anything else (much code changes `amount`
//   directly), through refresh_slot_counts() on mobs with a client.
// Nothing is shown on the ground.
//
// Anything else that stands for several things can join in by overriding
// slot_count() (and slot_count_full()); handfuls of rounds do.

// How far each further figure sits to the left of the one before it.
#define STACK_COUNT_PITCH 4

var/global/list/stack_count_badges = list()

/atom/movable/stack_count_badge
	name = ""
	icon = 'icons/mob/screen/stack_count.dmi'
	icon_state = ""
	mouse_opacity = 0
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	vis_flags = VIS_INHERIT_ID | VIS_INHERIT_LAYER | VIS_INHERIT_PLANE

// The figures shown for a count: at most four, larger counts written short.
/proc/stack_count_text(count)
	count = round(count)
	if (count >= 1000000)
		return "[min(round(count / 1000000), 999)]m"
	if (count >= 10000)
		return "[round(count / 1000)]k"
	return "[count]"

/proc/stack_count_badge(count, full)
	var/text = stack_count_text(count)
	var/prefix = full ? "f" : "n"
	var/key = "[prefix][text]"
	var/atom/movable/stack_count_badge/B = stack_count_badges[key]
	if (!B)
		B = new
		var/figures = length(text)
		for (var/i in 1 to figures)
			var/image/I = image('icons/mob/screen/stack_count.dmi', "[prefix][copytext(text, figures - i + 1, figures - i + 2)]")
			I.layer = FLOAT_LAYER
			I.plane = FLOAT_PLANE
			I.pixel_x = -STACK_COUNT_PITCH * (i - 1)
			B.overlays += I
		stack_count_badges[key] = B
	return B

/obj/item
	var/tmp/atom/movable/stack_count_badge/slot_count_badge

/obj/item/persistence_runtime_var(key)
	return key == "slot_count_badge" || key == "vis_contents" || ..()

// How many things this one item stands for. 0 or 1 shows no number.
/obj/item/proc/slot_count()
	return 0

/obj/item/proc/slot_count_full()
	return FALSE

/obj/item/stack/slot_count()
	return amount

/obj/item/stack/slot_count_full()
	return max_amount && amount >= max_amount

/obj/item/ammo_handful/slot_count()
	return round_count()

/obj/item/ammo_handful/slot_count_full()
	var/most = capacity()
	return most && round_count() >= most

// Show, change or take away this item's number to match where it is and how
// many it holds. Cheap when nothing changed.
/obj/item/proc/update_slot_count()
	var/atom/movable/stack_count_badge/want = null
	if (loc && !isturf(loc) && !QDELETED(src))
		var/count = slot_count()
		if (count > 1)
			want = stack_count_badge(count, slot_count_full())
	if (want == slot_count_badge)
		return
	if (slot_count_badge)
		vis_contents -= slot_count_badge
	slot_count_badge = want
	if (want)
		vis_contents += want

/obj/item/equipped()
	. = ..()
	update_slot_count()

/obj/item/dropped(mob/user)
	. = ..()
	update_slot_count()

/obj/item/on_enter_storage(obj/item/weapon/storage/S)
	. = ..()
	update_slot_count()

/obj/item/on_exit_storage(obj/item/weapon/storage/S)
	. = ..()
	update_slot_count()

/obj/item/weapon/storage/show_to(mob/user)
	for (var/obj/item/I in contents)
		I.update_slot_count()
	return ..()

/obj/item/stack/use(used, mob/living/human/H = null)
	. = ..()
	update_slot_count()

/obj/item/stack/merge(obj/item/stack/S)
	. = ..()
	update_slot_count()
	if (S)
		S.update_slot_count()

/obj/item/stack/transfer_to(obj/item/stack/S, _amount = null)
	. = ..()
	update_slot_count()
	if (S)
		S.update_slot_count()

/obj/item/stack/split(_amount)
	. = ..()
	update_slot_count()
	var/obj/item/stack/made = .
	if (istype(made))
		made.update_slot_count()

/obj/item/ammo_handful/update_handful()
	. = ..()
	update_slot_count()

// The sweep for everything the hooks above do not see: what this mob carries
// and what lies in the bag it has open, plus anything it showed a number on
// last time that has since gone elsewhere (so a number never lingers on a
// stack that reached the ground some other way).
/mob/living/human
	var/tmp/list/slot_count_tracked

/mob/living/human/persistence_runtime_var(key)
	return key == "slot_count_tracked" || ..()

/mob/living/human/proc/refresh_slot_counts()
	var/list/shown = list()
	for (var/obj/item/I in contents)
		I.update_slot_count()
		if (I.slot_count_badge)
			shown += I
	if (s_active)
		for (var/obj/item/I in s_active.contents)
			I.update_slot_count()
			if (I.slot_count_badge)
				shown += I
	if (slot_count_tracked)
		for (var/obj/item/I in slot_count_tracked)
			if (!QDELETED(I) && !(I in shown))
				I.update_slot_count()
	slot_count_tracked = shown.len ? shown : null

/mob/living/human/handle_regular_hud_updates()
	. = ..()
	if (client)
		refresh_slot_counts()

#undef STACK_COUNT_PITCH
