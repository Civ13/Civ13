// Stone Age weapons and tools. See docs/stone-age-arms.md.
// Included after flint_mining.dm, animal_harvest.dm and primitive_woodworking.dm:
// the fish, harvest and woodworking hooks below build on those definitions.

#define STONE_AGE_ICON 'icons/obj/stone_age_arms.dmi'
#define BOLA_BREAKOUT_TIME 60
#define BOLA_TRIP_CHANCE 40
#define HIDE_SCRAPER_BONUS 1
#define NEEDLE_REPAIR_AMOUNT 8
#define SPEAR_FISHING_DELAY 100
#define SPEAR_FISHING_CHANCE 35
#define DIGGING_STICK_SPEED 0.75 // half of the base plough's 1.5

// ---------------------------------------------------------------- atlatl
// A spear-thrower: one hand (a sling subtype, so the bow's two-hand rule is
// skipped), one dart at a time, harder hitting than a flint arrow but slower
// to reload and shorter ranged than a bow.
/obj/item/weapon/gun/projectile/bow/sling/atlatl
	name = "atlatl"
	desc = "A grooved wooden spear-thrower. Lay a dart in it and it hurls the dart far harder than an arm alone."
	icon = STONE_AGE_ICON
	icon_state = "atlatl"
	item_state = "stick"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	icotype = "atlatl"
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT
	flammable = TRUE
	caliber = "atlatl_dart"
	ammo_type = /obj/item/ammo_casing/atlatl_dart/flint
	projtype = "dart"
	force = 5
	throwforce = 5
	stat = "strength"
	move_delay = 5
	fire_delay = 12
	load_delay = 15
	accuracy = 5
	value = 6

/obj/item/weapon/gun/projectile/bow/sling/atlatl/New()
	..()
	// The parent fills bows with age-appropriate arrows on non-civ maps; darts never auto-load.
	for (var/obj/item/ammo_casing/C in loaded)
		if (C.caliber != caliber)
			loaded -= C
			qdel(C)
	update_icon()

/obj/item/weapon/gun/projectile/bow/sling/atlatl/update_icon()
	icon_state = loaded.len ? "atlatl_loaded" : "atlatl"
	item_state = "stick"
	overlays = null

/obj/item/ammo_casing/atlatl_dart
	name = "atlatl dart shaft"
	desc = "A long, light, fletched shaft. Fit a sharpened flint or a flint or stone arrowhead to make an atlatl dart."
	icon = STONE_AGE_ICON
	icon_state = "atlatl_dart"
	spent_icon = null
	projectile_type = /obj/item/projectile/arrow/arrow/atlatl_dart
	caliber = "atlatl_dart"
	weight = 0.3
	slot_flags = SLOT_BELT
	value = 2

/obj/item/ammo_casing/atlatl_dart/flint
	name = "flint atlatl dart"
	desc = "A long fletched dart tipped with knapped flint. Throw it with an atlatl."
	projectile_type = /obj/item/projectile/arrow/arrow/atlatl_dart/flint

/obj/item/ammo_casing/atlatl_dart/stone
	name = "stone atlatl dart"
	desc = "A long fletched dart tipped with a ground stone point. Throw it with an atlatl."
	projectile_type = /obj/item/projectile/arrow/arrow/atlatl_dart/stone

/proc/atlatl_dart_point(obj/item/W)
	if (istype(W, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = W
		return F.sharpened
	return istype(W, /obj/item/stack/arrowhead/flint) || istype(W, /obj/item/stack/arrowhead/stone)

/obj/item/ammo_casing/atlatl_dart/attackby(obj/item/W, mob/user)
	if (type != /obj/item/ammo_casing/atlatl_dart || !atlatl_dart_point(W))
		return ..()
	// Only flint and stone points have dart subtypes; attach_arrowhead builds the path.
	attach_arrowhead(W, user, "/obj/item/ammo_casing/atlatl_dart")

/obj/item/projectile/arrow/arrow/atlatl_dart
	damage = DAMAGE_LOW-20
	penetrating = 0
	armor_penetration = 0
	icon_state = "arrow"
	kill_count = 18

/obj/item/projectile/arrow/arrow/atlatl_dart/flint
	damage = DAMAGE_MEDIUM+8
	armor_penetration = ARMOR_CLASS
	icon_state = "arrow_flint"

/obj/item/projectile/arrow/arrow/atlatl_dart/stone
	damage = DAMAGE_MEDIUM+6
	armor_penetration = ARMOR_CLASS
	icon_state = "arrow_stone"

// ---------------------------------------------------------------- slingstaff
// A sling on a pole: more range and punch than the hand sling, but slow and two-handed.
/obj/item/weapon/gun/projectile/bow/sling/staff
	name = "slingstaff"
	desc = "A sling lashed to the end of a wooden staff. It throws stones further and harder than a hand sling, but needs both hands."
	icon_state = "slingstaff0"
	item_state = "quarterstaff"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	icotype = "slingstaff"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_SHOULDER
	force = 8
	fire_delay = 12
	load_delay = 14
	accuracy = 6
	value = 12

/obj/item/weapon/gun/projectile/bow/sling/staff/update_icon()
	..()
	item_state = "quarterstaff"

/obj/item/weapon/gun/projectile/bow/sling/staff/special_check(mob/user)
	if (!user.has_empty_hand(both = FALSE))
		to_chat(user, SPAN_WARNING("You need both hands to swing \the [src]!"))
		return FALSE
	return ..()

/obj/item/weapon/gun/projectile/bow/sling/staff/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params=null)
	var/obj/item/projectile/P = projectile
	if (istype(P))
		P.damage += 8
	return ..()

// ---------------------------------------------------------------- bola
// Three stones on cords. A hit tangles the legs (no running until freed) and
// may trip the target; animals stumble for a moment. Struggle out with Resist.
/obj/item/weapon/legcuffs/bola
	name = "bola"
	desc = "Three stones tied together on cords. Throw it at legs to tangle them."
	icon = STONE_AGE_ICON
	icon_state = "bola"
	item_state = ""
	flags = 0
	w_class = ITEM_SIZE_SMALL
	throwforce = 4
	throw_speed = 4
	throw_range = 8
	breakouttime = BOLA_BREAKOUT_TIME
	flammable = TRUE
	value = 3

/obj/item/weapon/legcuffs/bola/throw_impact(atom/hit_atom, speed)
	if (ishuman(hit_atom))
		var/mob/living/human/H = hit_atom
		if (!H.legcuffed && H.has_organ("l_leg") && H.has_organ("r_leg"))
			H.visible_message(SPAN_DANGER("\The [src] wraps around [H]'s legs!"), SPAN_DANGER("\The [src] wraps around your legs! Resist to struggle free."))
			throwing = FALSE
			H.equip_to_slot(src, slot_legcuffed)
			if (prob(BOLA_TRIP_CHANCE))
				H.Weaken(2)
			return
	else if (isanimal(hit_atom))
		var/mob/living/simple_animal/A = hit_atom
		if (A.stat != DEAD)
			A.visible_message(SPAN_DANGER("\The [src] tangles [A]'s legs!"))
			A.Weaken(3)
	..()

// ---------------------------------------------------------------- javelin
/obj/item/weapon/material/javelin
	name = "javelin"
	desc = "A light throwing spear with a fire-hardened point. Weaker than a pilum, but anyone can make one."
	icon = STONE_AGE_ICON
	icon_state = "javelin"
	item_state = "spear"
	sharp = TRUE
	edge = FALSE
	slot_flags = SLOT_SHOULDER | SLOT_BELT
	default_material = "wood"
	applies_material_colour = FALSE
	throw_speed = 6
	throw_range = 12
	allow_spin = FALSE
	force_divisor = 0.35 // 14 with hardness 40 (wood)
	thrown_force_divisor = 1.8 // about 32 with weight 18 (wood)
	attack_verb = list("jabbed", "stabbed")
	value = 3
	block_chance = 5
	cooldownw = 7

/obj/item/weapon/material/javelin/set_material(new_material)
	..()
	name = initial(name)

// ---------------------------------------------------------------- stone club
/obj/item/weapon/melee/classic_baton/club/stone
	name = "stone-headed club"
	desc = "A wooden handle with a heavy stone lashed to the end. Hits harder than a plain club, but it is slow to swing."
	icon = STONE_AGE_ICON
	icon_state = "stone_club"
	item_state = "club"
	force = WEAPON_FORCE_PAINFUL
	flammable = FALSE
	weakens = 1
	weaken_chance = 25
	cooldownw = 12
	value = 5

// ---------------------------------------------------------------- bone harpoon
/obj/item/weapon/material/harpoon/bone
	desc = "A barbed bone point on a wooden shaft. Throw it, or use it on a fishing spot to spear fish."
	default_material = "bone"

// Spear fishing: barbed harpoons and flint spears work fishing spots without a line.
/proc/spear_fishing_tool(obj/item/W)
	return istype(W, /obj/item/weapon/material/harpoon) || istype(W, /obj/item/weapon/material/spear/flint)

/obj/structure/fish/proc/land_fish(turf/T)
	counter--
	if (species == "salmon")
		new /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon(T)
	else if (species == "cod")
		new /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod(T)
	else
		new /obj/item/weapon/reagent_containers/food/snacks/rawfish(T)
	if (counter <= 0)
		invisibility = 101
	get_fish()

/obj/structure/fish/attackby(obj/item/W, mob/living/human/H)
	if (!spear_fishing_tool(W) || !ishuman(H))
		return ..()
	if (counter <= 0)
		to_chat(H, SPAN_NOTICE("There are no fish left here for now."))
		return
	H.visible_message("[H] stands ready to spear a fish.")
	if (!do_after(H, SPEAR_FISHING_DELAY, src) || QDELETED(W) || W.loc != H || counter <= 0)
		return
	if (!prob(SPEAR_FISHING_CHANCE))
		to_chat(H, "The fish dart away from your strike.")
		return
	to_chat(H, "You spear a fish!")
	land_fish(H.loc)

// ---------------------------------------------------------------- digging stick
// A fire-hardened, stone-weighted stick: the Neolithic farmer's hoe. It works
// ground like a plough at half speed, so farming can start before Bronze Age
// agriculture.
/obj/item/weapon/plough/digging_stick
	name = "digging stick"
	desc = "A pointed, fire-hardened stick weighted with a bored stone. Use it on grass or dirt to break ground for planting, slowly."
	icon = STONE_AGE_ICON
	icon_state = "digging_stick"
	item_state = "sharpened_stick"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	flags = 0
	force = 6
	usespeed = DIGGING_STICK_SPEED
	flammable = TRUE
	value = 2

// A digging stick is not a plough share: cattle can't be hitched to one (that
// would swap it for a full plough on unhitching).
/mob/living/simple_animal/cattle/attackby(obj/item/O, mob/user)
	if (istype(O, /obj/item/weapon/plough/digging_stick) && user.a_intent == I_HELP)
		to_chat(user, SPAN_WARNING("A digging stick is too light to hitch to \the [src]. You need a plough."))
		return
	return ..()

// ---------------------------------------------------------------- hand axe
// The oldest all-purpose tool: chops (slowly), butchers and cuts.
/obj/item/weapon/material/hatchet/tribal/hand_axe
	name = "hand axe"
	desc = "A teardrop of flint knapped sharp on both faces. It chops, cuts and butchers, all a little worse than a proper tool."
	icon = STONE_AGE_ICON
	icon_state = "hand_axe"
	item_state = "flinthatchet"
	material = "flint"
	default_material = "flint"
	force_divisor = 0.4
	chopping_speed = 4.5
	slot_flags = SLOT_BELT | SLOT_POCKET
	value = 4

/obj/item/weapon/material/hatchet/tribal/hand_axe/set_material(new_material)
	..()
	name = initial(name)

// ---------------------------------------------------------------- hide scraper
// Hold it while skinning (in either hand) and a clean scrape saves an extra
// piece of hide.
/obj/item/weapon/material/hide_scraper
	name = "hide scraper"
	desc = "A small flint end-scraper. Keep it in hand while skinning an animal to save more of the hide."
	icon = STONE_AGE_ICON
	icon_state = "hide_scraper"
	item_state = "knife"
	sharp = TRUE
	edge = TRUE
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_BELT | SLOT_POCKET
	default_material = "flint"
	applies_material_colour = FALSE
	force_divisor = 0.15
	thrown_force_divisor = 0.3
	attack_verb = list("scraped", "cut")
	value = 2

/obj/item/weapon/material/hide_scraper/set_material(new_material)
	..()
	name = initial(name)

/mob/living/simple_animal
	var/tmp/mob/harvest_scraper_user = null

/mob/living/simple_animal/persistence_runtime_var(key)
	if (key == "harvest_scraper_user")
		return TRUE
	return ..()

/proc/holds_hide_scraper(mob/user, obj/item/tool)
	if (!user)
		return FALSE
	return istype(tool, /obj/item/weapon/material/hide_scraper) || istype(user.get_active_hand(), /obj/item/weapon/material/hide_scraper) || istype(user.get_inactive_hand(), /obj/item/weapon/material/hide_scraper)

// Only the harvest that is actually accepted records the scraper user; a
// second click while one is in progress must not touch the first one's state.
/mob/living/simple_animal/harvest_animal(mob/user, obj/item/tool, skin = FALSE)
	var/owns_scraper_state = FALSE
	if (!harvesting)
		owns_scraper_state = TRUE
		harvest_scraper_user = (skin && holds_hide_scraper(user, tool)) ? user : null
	. = ..()
	if (owns_scraper_state && !QDELETED(src))
		harvest_scraper_user = null

/proc/hide_stack_amounts(turf/site)
	var/list/amounts = list()
	if (!site)
		return amounts
	for (var/obj/item/stack/material/S in site)
		if (istype(S, /obj/item/stack/material/pelt) || istype(S, /obj/item/stack/material/rawhide))
			amounts[S] = S.amount
	return amounts

// The bonus goes only to a pelt or rawhide stack this carcass produced (new or
// grown), and only if the user still holds the scraper when skinning finishes.
/mob/living/simple_animal/harvest_products(turf/site, skin)
	var/mob/scraper_user = harvest_scraper_user
	var/list/before = (skin && scraper_user) ? hide_stack_amounts(site) : null
	..()
	if (!before || !holds_hide_scraper(scraper_user, null))
		return
	for (var/obj/item/stack/material/S in site)
		if (!istype(S, /obj/item/stack/material/pelt) && !istype(S, /obj/item/stack/material/rawhide))
			continue
		if ((S in before) && S.amount <= before[S])
			continue
		if (S.amount >= S.max_amount)
			continue
		S.amount = min(S.max_amount, S.amount + HIDE_SCRAPER_BONUS)
		S.update_icon()
		return

// ---------------------------------------------------------------- bone needle
// Mend worn clothing: use the needle on it while holding sinew, leather,
// rawhide or a pelt in the other hand.
/obj/item/weapon/bone_needle
	name = "bone needle and awl"
	desc = "A polished bone needle and a pointed awl. Use it on worn clothing while holding sinew, leather, rawhide or pelt in your other hand to mend it."
	icon = STONE_AGE_ICON
	icon_state = "bone_needle"
	item_state = ""
	flags = 0
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = 2
	sharp = TRUE
	edge = FALSE
	attack_verb = list("pricked", "poked")
	flammable = FALSE
	value = 2

/proc/needle_mending_material(obj/item/I)
	return istype(I, /obj/item/stack/sinew) || istype(I, /obj/item/stack/material/leather) || istype(I, /obj/item/stack/material/rawhide) || istype(I, /obj/item/stack/material/pelt)

/obj/item/weapon/bone_needle/afterattack(atom/target, mob/user, proximity)
	if (!proximity || !istype(target, /obj/item/clothing) || !ishuman(user))
		return ..()
	var/obj/item/clothing/C = target
	var/mob/living/human/H = user
	var/obj/item/stack/thread = H.get_inactive_hand()
	if (!needle_mending_material(thread))
		to_chat(H, SPAN_WARNING("Hold sinew, leather, rawhide or a pelt in your other hand to mend \the [C]."))
		return
	if (C.health >= initial(C.health))
		to_chat(H, SPAN_NOTICE("\The [C] doesn't need mending."))
		return
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You start stitching \the [C]..."))
	if (!do_after(H, 80 / max(0.5, H.getStatCoeff("crafting")), C) || QDELETED(C) || QDELETED(thread) || H.get_inactive_hand() != thread || H.get_active_hand() != src || C.health >= initial(C.health))
		return
	if (!thread.use(1))
		return
	C.health = min(initial(C.health), C.health + NEEDLE_REPAIR_AMOUNT)
	H.adaptStat("crafting", 1)
	to_chat(H, SPAN_NOTICE("You mend \the [C]."))

// ---------------------------------------------------------------- stone adze
// A stone blade hafted crosswise, the dressing tool. A hatchet cuts two logs
// into one plank; hewing with an adze gets two finished planks from the same
// two logs, more slowly. On harm intent it cuts logs like any hatchet.
/obj/item/weapon/material/hatchet/tribal/adze
	name = "stone adze"
	desc = "A ground stone blade lashed crosswise to an elbow haft. Use it on logs to hew them into finished planks: two planks from two logs, where a hatchet gets one."
	icon = STONE_AGE_ICON
	icon_state = "stone_adze"
	item_state = "stonehatchet"
	material = "stone"
	default_material = "stone"
	chopping_speed = 5
	value = 6

/obj/item/weapon/material/hatchet/tribal/adze/set_material(new_material)
	..()
	name = initial(name)

/datum/primitive_woodwork_action/adze_hew

/datum/primitive_woodwork_action/adze_hew/New(obj/item/stack/material/S, mob/living/human/H, obj/item/T, action_mode)
	..(S, H, T, "hew")
	spec = list("cost" = 2, "count" = 2, "delay" = 140, "output" = /obj/item/stack/material/woodplank, "bark" = 2)

/datum/primitive_woodwork_action/adze_hew/valid()
	if (!plank_making_allowed(user))
		return FALSE
	if (committed || !spec || QDELETED(source) || QDELETED(user) || QDELETED(tool))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || save_epoch != persistence_admission_identity)
		return FALSE
	if (!hide_worker_can_reach(user, source) || user.incapacitated() || get_turf(user) != user_site || user.get_active_hand() != tool || tool.loc != user || tool.health != tool_health || tool.health <= 0)
		return FALSE
	if (!istype(tool, /obj/item/weapon/material/hatchet/tribal/adze))
		return FALSE
	if (source.loc != source_loc || get_turf(source) != site || source.amount != source_count || source.amount < spec["cost"] || source.get_material() != workpiece || !workpiece || workpiece.hardness != workpiece_hardness)
		return FALSE
	if (source_count != round(source_count) || source_count > source.max_amount)
		return FALSE
	if (!istype(source, /obj/item/stack/material/wood) || workpiece.name != "wood" || source:onfire || source:splitting_in_progress)
		return FALSE
	if (claimed)
		return source.woodwork_owner == src && user.woodwork_owner == src && tool.woodwork_owner == src
	return !source.woodwork_owner && !user.woodwork_owner && !tool.woodwork_owner

/proc/adze_hew_begin(obj/item/stack/material/source, mob/living/human/user, obj/item/tool)
	if (!istype(user) || QDELETED(source) || QDELETED(tool) || source.woodwork_owner || user.woodwork_owner || tool.woodwork_owner)
		return FALSE
	if (!plank_making_allowed_or_warn(user))
		return FALSE
	var/datum/primitive_woodwork_action/adze_hew/action = new(source, user, tool)
	if (!action.valid())
		qdel(action)
		return FALSE
	return action.perform()

/obj/item/stack/material/wood/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/material/hatchet/tribal/adze) && ishuman(user) && user.a_intent != I_HARM)
		adze_hew_begin(src, user, W)
		return TRUE
	return ..()

// ---------------------------------------------------------------- knapping
// New knapped flint tools offered by /obj/item/weapon/flint/proc/knap.
/proc/stone_age_knap_options(mob/living/human/H)
	. = list()
	if (crafting_recipe_allowed(H, "/obj/item/weapon/material/hatchet/tribal/hand_axe"))
		. += "Hand axe"
	if (crafting_recipe_allowed(H, "/obj/item/weapon/material/hide_scraper"))
		. += "Hide scraper"

/proc/stone_age_knap_result(choice, turf/T, mob/living/human/H)
	var/path
	switch (choice)
		if ("Hand axe")
			path = /obj/item/weapon/material/hatchet/tribal/hand_axe
		if ("Hide scraper")
			path = /obj/item/weapon/material/hide_scraper
	if (!path || !crafting_recipe_allowed(H, "[path]"))
		return null
	note_craft_practice(H, "[path]")
	return new path(T)

#undef BOLA_BREAKOUT_TIME
#undef BOLA_TRIP_CHANCE
#undef HIDE_SCRAPER_BONUS
#undef NEEDLE_REPAIR_AMOUNT
#undef SPEAR_FISHING_DELAY
#undef SPEAR_FISHING_CHANCE
#undef DIGGING_STICK_SPEED
#undef STONE_AGE_ICON
