// Obsidian: volcanic glass found at volcanoes in every age and knapped into
// sharp but brittle tools. See docs/obsidian.md.
// Included after flint_mining.dm, gemstones.dm and stone_age_arms.dm: the
// lava, ore, branch, harvest and ammunition overrides below fall back to the
// definitions in those files and the files they build on.

#define OBSIDIAN_ICON 'icons/obj/obsidian.dmi'
#define OBSIDIAN_VOLCANO_RANGE 15 // tiles from lava or dry lava that count as volcanic rock
#define OBSIDIAN_VOLCANO_BUCKET 16 // registry cell size, at least the range
#define OBSIDIAN_MINING_CHANCE 15
#define OBSIDIAN_COOLING_CHANCE 10
#define OBSIDIAN_QUENCH_CHANCE 30
#define OBSIDIAN_OUTCROP_SHARE 4 // one dry lava tile in four shows glass
#define OBSIDIAN_OUTCROP_NODULES 3
#define OBSIDIAN_OUTCROP_REGEN 18000 // same as flint rocks
#define OBSIDIAN_BLADES_PER_CORE 6
#define OBSIDIAN_EDGE_HARVEST 0.75 // butchering and skinning time with an obsidian edge in hand
#define OBSIDIAN_CHIP_CHANCE 10 // chance a hit knocks a blade out of a macuahuitl or tepoztopilli
#define OBSIDIAN_CHIP_CHANCE_ARMOUR 20
#define OBSIDIAN_POLISH_TIME 80
#define OBSIDIAN_POLISH_FLAW_CHANCE 10

// Knapped obsidian. The building stone (/material/obsidian, cut blocks for
// pillars and braziers) keeps its own very high integrity; tools use this
// sharper but far more brittle glass. Flint: hardness 50, integrity 110.
/material/volcanic_glass
	name = "volcanic glass"
	display_name = "obsidian"
	icon_colour = "#1d1c24"
	hardness = 70
	integrity = 60
	weight = 20
	shard_type = SHARD_SHARD
	sheet_singular_name = "piece"
	sheet_plural_name = "pieces"

// ---------------------------------------------------------------- volcanoes
// Lava and dry lava register themselves in coarse cells, so "is this wall near
// a volcano" costs a few distance checks instead of a range scan. Entries are
// re-checked by type, so a tile that later changes simply stops counting.
var/global/list/obsidian_volcano_cells = list()

/proc/obsidian_cell_key(cx, cy, z)
	return "[cx],[cy],[z]"

/proc/is_volcanic_turf(turf/T)
	return istype(T, /turf/floor/lava) || istype(T, /turf/floor/dirt/dry_lava)

/proc/register_volcanic_turf(turf/T)
	if (!T || !T.z)
		return
	var/key = obsidian_cell_key(round(T.x / OBSIDIAN_VOLCANO_BUCKET), round(T.y / OBSIDIAN_VOLCANO_BUCKET), T.z)
	var/list/L = obsidian_volcano_cells[key]
	if (!L)
		L = list()
		obsidian_volcano_cells[key] = L
	L |= T

/proc/near_volcano(turf/T, range = OBSIDIAN_VOLCANO_RANGE)
	if (!T || !T.z)
		return FALSE
	var/cx = round(T.x / OBSIDIAN_VOLCANO_BUCKET)
	var/cy = round(T.y / OBSIDIAN_VOLCANO_BUCKET)
	var/span = round(range / OBSIDIAN_VOLCANO_BUCKET) + 1
	for (var/dx = -span, dx <= span, dx++)
		for (var/dy = -span, dy <= span, dy++)
			var/list/L = obsidian_volcano_cells[obsidian_cell_key(cx + dx, cy + dy, T.z)]
			if (!L)
				continue
			for (var/turf/V in L)
				if (get_dist(T, V) <= range && is_volcanic_turf(V))
					return TRUE
	return FALSE

/turf/floor/lava/New()
	..()
	register_volcanic_turf(src)

// Mined rock near a volcano, on its own level or under it: an independent roll
// like flint nodules and gem pockets, so the ore table is unchanged. Every age.
/turf/proc/mining_obsidian(mob/living/human/H)
	if (!prob(OBSIDIAN_MINING_CHANCE))
		return 0
	var/volcanic = near_volcano(src)
	if (!volcanic)
		var/up_z = multiz_level_above(z)
		if (up_z)
			volcanic = near_volcano(locate(x, y, up_z))
	if (!volcanic)
		return 0
	var/obj/item/stack/ore/obsidian/O = new /obj/item/stack/ore/obsidian(src)
	O.amount = rand(4, 8)
	if (istype(get_area(src), /area/caribbean/void/caves/special))
		O.amount *= 2
	O.update_icon()
	if (H)
		to_chat(H, SPAN_GREEN_BOLD("You found some <font color=#3a3848><b>obsidian</b></font>!"))
	return O.amount

// Lava that hardens leaves glass behind now and then; lava quenched by water
// (how real obsidian forms) leaves it more often.
/turf/floor/lava/proc/obsidian_quenched()
	for (var/turf/T in orange(1, src))
		if (istype(T, /turf/floor/beach/water))
			return TRUE
	return FALSE

/turf/floor/lava/dryproc()
	var/hardening = stage >= 2
	var/quenched = hardening && obsidian_quenched()
	..()
	if (hardening && prob(quenched ? OBSIDIAN_QUENCH_CHANCE : OBSIDIAN_COOLING_CHANCE))
		new /obj/item/weapon/obsidian_nodule(src)

// ---------------------------------------------------------------- outcrops
// About one dry lava tile in four shows black glass. The choice is fixed by
// position, the art is an overlay and the count is runtime state, so nothing
// here adds to a saved world and every boot shows the same outcrops.
/turf/floor/dirt/dry_lava
	var/tmp/obsidian_outcrop = FALSE
	var/tmp/datum/resource_stock/obsidian_stock = null // refills OBSIDIAN_OUTCROP_REGEN after it runs out
	var/tmp/image/obsidian_overlay = null

/turf/floor/dirt/dry_lava/persistence_runtime_var(key)
	return key == "obsidian_outcrop" || key == "obsidian_stock" || key == "obsidian_overlay" || ..()

/turf/floor/dirt/dry_lava/New()
	..()
	register_volcanic_turf(src)
	obsidian_outcrop = ((x * 7 + y * 13 + z * 3) % OBSIDIAN_OUTCROP_SHARE) == 0
	obsidian_show_outcrop()

/turf/floor/dirt/dry_lava/after_load()
	..()
	obsidian_show_outcrop()

/turf/floor/dirt/dry_lava/proc/obsidian_show_outcrop()
	if (obsidian_overlay)
		overlays -= obsidian_overlay
		obsidian_overlay = null
	if (!obsidian_outcrop)
		return
	obsidian_overlay = image(OBSIDIAN_ICON, icon_state = "obsidian_outcrop[1 + ((x + y) % 3)]")
	overlays += obsidian_overlay
	desc = "Cooled lava. Black volcanic glass shows through it; search it with a grab to pry some obsidian loose."

/turf/floor/dirt/dry_lava/attack_hand(mob/user)
	if (!obsidian_outcrop || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	if (H.a_intent != I_GRAB || get_dist(H, src) > 1)
		return ..()
	if (!H.may_do_after)
		return
	if (!obsidian_stock)
		obsidian_stock = new /datum/resource_stock(OBSIDIAN_OUTCROP_NODULES, OBSIDIAN_OUTCROP_REGEN, TRUE)
	if (obsidian_stock.available() <= 0)
		to_chat(H, SPAN_NOTICE("You have already pried loose all the glass you can reach here."))
		return
	to_chat(H, SPAN_NOTICE("You start prying obsidian out of the cooled lava..."))
	if (!do_after(H, 50, src) || get_dist(H, src) > 1 || !obsidian_stock.take())
		return
	var/obj/item/weapon/obsidian_nodule/N = new /obj/item/weapon/obsidian_nodule(src)
	H.put_in_hands(N)
	to_chat(H, SPAN_NOTICE("You pry loose \a [N]."))

// ---------------------------------------------------------------- raw glass
/obj/item/weapon/obsidian_nodule
	name = "obsidian nodule"
	desc = "A lump of black volcanic glass. Knap it with a hammerstone (a stone or an unsharpened flint); it breaks cleanly and predictably."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_nodule"
	item_state = ""
	w_class = ITEM_SIZE_TINY
	force = 5
	throwforce = 5
	throw_speed = 7
	throw_range = 10
	attack_verb = list("hit", "bashed")
	flammable = FALSE
	value = 2

/proc/obsidian_is_hammerstone(obj/item/I)
	if (istype(I, /obj/item/stack/material/stone))
		return TRUE
	if (istype(I, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = I
		return !F.sharpened
	return FALSE

// The worked piece is held or one tile away; the tool is in the active hand.
/proc/obsidian_work_reachable(mob/living/human/H, obj/item/work, obj/item/tool)
	if (!H || QDELETED(work) || QDELETED(tool) || tool.loc != H || H.get_active_hand() != tool || H.stat != CONSCIOUS || H.incapacitated())
		return FALSE
	return work.loc == H || (isturf(work.loc) && get_dist(work, H) <= 1)

/proc/obsidian_shatter(mob/living/human/H, turf/T, in_hand)
	var/obj/item/weapon/material/shard/S = new /obj/item/weapon/material/shard(T, "volcanic glass")
	if (S && !QDELETED(S) && in_hand)
		H.put_in_hands(S)

// Rough obsidian from mining: a hammerstone knocks one nodule off the lump.
// A chisel and hammer still cut it into building blocks (ores.dm).
/obj/item/stack/ore/obsidian/attackby(obj/item/W, mob/user)
	if (!ishuman(user) || !obsidian_is_hammerstone(W))
		return ..()
	var/mob/living/human/H = user
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You start knocking a nodule off \the [src]..."))
	playsound(get_turf(src), 'sound/effects/chop.ogg', 50, TRUE)
	if (!do_after(H, 30, src) || !obsidian_work_reachable(H, src, W) || amount < 1)
		return
	var/turf/T = get_turf(src)
	use(1)
	var/obj/item/weapon/obsidian_nodule/N = new /obj/item/weapon/obsidian_nodule(T)
	H.put_in_hands(N)
	to_chat(H, SPAN_NOTICE("You knock off \a [N]."))

// ---------------------------------------------------------------- knapping
/obj/item/weapon/obsidian_nodule/attackby(obj/item/W, mob/user)
	if (ishuman(user) && obsidian_is_hammerstone(W))
		knap(user, W)
		return
	if (ishuman(user) && is_tool(W, TOOL_CHISEL))
		polish(user, W)
		return
	..()

/obj/item/weapon/obsidian_nodule/proc/knap(mob/living/human/H, obj/item/hammer)
	if (!H.may_do_after || !obsidian_work_reachable(H, src, hammer))
		return
	// The choices, times and products live in processing_recipes.dm.
	var/list/options = processing_recipe_choices("obsidian knapping", H)
	options += "Cancel"
	var/choice = WWinput(H, "What do you want to knap from \the [src]?", "Knapping", "Cancel", options)
	if (!choice || choice == "Cancel" || !obsidian_work_reachable(H, src, hammer))
		return
	var/datum/processing_recipe/R = processing_recipe_choice("obsidian knapping", choice)
	if (!R)
		return
	var/delay = R.delay
	var/fail_chance = R.fail_chance
	H.visible_message(SPAN_NOTICE("[H] starts knapping \the [src] with \the [hammer]."), SPAN_NOTICE("You start knapping \the [src] with \the [hammer]."))
	playsound(get_turf(src), 'sound/effects/chop.ogg', 60, TRUE)
	if (!do_after(H, delay / max(0.5, H.getStatCoeff("dexterity")), src) || !obsidian_work_reachable(H, src, hammer))
		return
	H.adaptStat("crafting", 1)
	var/turf/T = get_turf(src)
	var/in_hand = loc == H
	if (prob(fail_chance / max(0.5, H.getStatCoeff("crafting"))))
		H.visible_message(SPAN_WARNING("\The [src] shatters under [H]'s blow."), SPAN_WARNING("The glass shatters. Only a sharp shard is left."))
		qdel(src)
		obsidian_shatter(H, T, in_hand)
		return
	var/obj/item/result = processing_recipe_make(R, T, H)
	if (!result)
		to_chat(H, SPAN_WARNING("You can't knap that from this nodule."))
		return
	qdel(src)
	if (in_hand)
		H.put_in_hands(result)
	to_chat(H, SPAN_NOTICE("You knap \a [result]."))

// ---------------------------------------------------------------- flake
/obj/item/weapon/obsidian_flake
	name = "obsidian flake"
	desc = "A struck flake of volcanic glass, with an edge sharper than any steel."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_flake"
	item_state = ""
	w_class = ITEM_SIZE_TINY
	force = 12
	sharp = TRUE
	edge = TRUE
	attack_verb = list("cut", "slashed")
	flammable = FALSE
	value = 1

// ---------------------------------------------------------------- points
/obj/item/stack/arrowhead/obsidian
	name = "obsidian arrowhead"
	desc = "A pressure-flaked point of volcanic glass. It cuts deep but shatters on armour. Attach it to an arrow or atlatl dart shaft."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_arrowheads"

/obj/item/ammo_casing/arrow/obsidian
	name = "obsidian arrow"
	desc = "An arrow tipped with volcanic glass."
	icon = OBSIDIAN_ICON
	icon_state = "arrow_obsidian"
	projectile_type = /obj/item/projectile/arrow/arrow/obsidian
	weight = 0.13

// Flint: DAMAGE_MEDIUM, ARMOR_CLASS.
/obj/item/projectile/arrow/arrow/obsidian
	icon = OBSIDIAN_ICON
	damage = DAMAGE_MEDIUM+2
	penetrating = 0
	armor_penetration = ARMOR_CLASS/2
	icon_state = "arrow_obsidian_flight"

/obj/item/ammo_casing/atlatl_dart/obsidian
	name = "obsidian atlatl dart"
	desc = "A long fletched dart tipped with volcanic glass. Throw it with an atlatl."
	projectile_type = /obj/item/projectile/arrow/arrow/atlatl_dart/obsidian

// Flint dart: DAMAGE_MEDIUM+8, ARMOR_CLASS.
/obj/item/projectile/arrow/arrow/atlatl_dart/obsidian
	icon = OBSIDIAN_ICON
	damage = DAMAGE_MEDIUM+10
	armor_penetration = ARMOR_CLASS/2
	icon_state = "arrow_obsidian_flight"

// Arrows and atlatl darts only: glass points were never fitted to crossbow bolts.
/obj/item/ammo_casing/proc/attach_obsidian_arrowhead(obj/item/W, mob/user, shaft_path)
	if (shaft_path != "/obj/item/ammo_casing/arrow" && shaft_path != "/obj/item/ammo_casing/atlatl_dart")
		to_chat(user, SPAN_WARNING("An obsidian point is too brittle for that."))
		return FALSE
	var/result = "[shaft_path]/obsidian"
	if (!crafting_recipe_allowed(user, result))
		return FALSE
	var/obj/item/stack/arrowhead/obsidian/AH = W
	var/result_type = text2path(result)
	new result_type(user.loc)
	AH.use(1)
	playsound(loc, 'sound/machines/click.ogg', 25, TRUE)
	to_chat(user, SPAN_NOTICE("You attach \the [W] to \the [src]."))
	qdel(src)
	return TRUE

/obj/item/ammo_casing/atlatl_dart/attackby(obj/item/W, mob/user)
	if (type == /obj/item/ammo_casing/atlatl_dart && istype(W, /obj/item/stack/arrowhead/obsidian))
		attach_arrowhead(W, user, "/obj/item/ammo_casing/atlatl_dart")
		return
	return ..()

/obj/item/weapon/obsidian_spearhead
	name = "obsidian spearhead"
	desc = "A long leaf-shaped point of volcanic glass. Use it on a branch to make a spear."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_spearhead"
	w_class = ITEM_SIZE_SMALL
	force = 7
	sharp = FALSE
	edge = FALSE
	flammable = FALSE
	value = 2

// Flint spear: force 22, health 11. Obsidian: force 25, health 6.
/obj/item/weapon/material/spear/obsidian
	desc = "A wooden shaft tipped with a point of volcanic glass. Vicious, but the glass chips quickly."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_spear"
	default_material = "volcanic glass"
	applies_material_colour = FALSE
	force_divisor = 0.36

/obj/item/weapon/branch/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!istype(W, /obj/item/weapon/obsidian_spearhead) || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You start lashing \the [W] to \the [src]..."))
	if (!do_after(H, 50, src) || QDELETED(W) || QDELETED(src) || W.loc != H || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
		return
	var/turf/T = get_turf(src)
	qdel(W)
	qdel(src)
	var/obj/item/weapon/material/spear/obsidian/S = new /obj/item/weapon/material/spear/obsidian(T)
	H.put_in_hands(S)
	to_chat(H, SPAN_NOTICE("You make \a [S]."))

// ---------------------------------------------------------------- edged tools
// Flint knife: force 5, health 11. Obsidian: force 7, health 6.
/obj/item/weapon/material/kitchen/utensil/knife/obsidian
	desc = "A blade of volcanic glass with a wrapped grip. Sharper than steel, but it chips with use."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_knife"
	item_state = "knife"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	default_material = "volcanic glass"
	applies_material_colour = FALSE

// Flint scraper: force 7, health 11. Obsidian: force 8, health 6, and the
// edge also speeds up skinning (below).
/obj/item/weapon/material/hide_scraper/obsidian
	name = "obsidian scraper"
	desc = "A small end-scraper of volcanic glass. Keep it in hand while skinning an animal to save more of the hide, and to work faster."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_scraper"
	default_material = "volcanic glass"
	force_divisor = 0.12

/obj/item/weapon/obsidian_core
	name = "obsidian blade core"
	desc = "A prepared core of volcanic glass. Press long blades off it with an antler pick or a piece of bone held in your active hand."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_core"
	item_state = ""
	w_class = ITEM_SIZE_SMALL
	force = 5
	flammable = FALSE
	value = 3

/proc/is_pressure_flaker(obj/item/I)
	return istype(I, /obj/item/weapon/material/pickaxe/antler) || istype(I, /obj/item/stack/material/bone)

/obj/item/weapon/obsidian_core/attackby(obj/item/W, mob/user)
	if (!ishuman(user) || !is_pressure_flaker(W))
		return ..()
	var/mob/living/human/H = user
	if (!H.may_do_after || !obsidian_work_reachable(H, src, W))
		return
	H.visible_message(SPAN_NOTICE("[H] starts pressing blades off \the [src]."), SPAN_NOTICE("You start pressing blades off \the [src] with \the [W]."))
	if (!do_after(H, 80 / max(0.5, H.getStatCoeff("dexterity")), src) || !obsidian_work_reachable(H, src, W))
		return
	H.adaptStat("crafting", 1)
	var/turf/T = get_turf(src)
	var/in_hand = loc == H
	var/count = OBSIDIAN_BLADES_PER_CORE
	if (prob(15 / max(0.5, H.getStatCoeff("crafting"))))
		count = 2
		to_chat(H, SPAN_WARNING("The core snaps partway through. You save only a couple of blades."))
	qdel(src)
	var/obj/item/stack/obsidian_blades/B = new /obj/item/stack/obsidian_blades(T, count)
	if (in_hand)
		H.put_in_hands(B)
	to_chat(H, SPAN_NOTICE("You press [count] prismatic blades off the core."))

// Long parallel pressure blades, as made in Mesoamerica. A blade cuts like a
// small knife; later they edge the macuahuitl.
/obj/item/stack/obsidian_blades
	name = "prismatic blades"
	singular_name = "prismatic blade"
	desc = "Long, thin blades of volcanic glass pressed off a core. Each one is as keen as a razor."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_blades"
	item_state = ""
	w_class = ITEM_SIZE_TINY
	max_amount = 30
	force = 5
	sharp = TRUE
	edge = TRUE
	attack_verb = list("cut", "sliced")
	flammable = FALSE
	value = 1

// Butchering and skinning go faster with an obsidian edge in either hand.
/proc/is_obsidian_edge(obj/item/I)
	return istype(I, /obj/item/weapon/material/kitchen/utensil/knife/obsidian) || istype(I, /obj/item/weapon/material/hide_scraper/obsidian) || istype(I, /obj/item/stack/obsidian_blades) || istype(I, /obj/item/weapon/obsidian_flake)

/proc/holds_obsidian_edge(mob/user)
	return user && (is_obsidian_edge(user.get_active_hand()) || is_obsidian_edge(user.get_inactive_hand()))

/mob/living/simple_animal/harvest_wait(mob/user, delay)
	if (holds_obsidian_edge(user))
		delay = round(delay * OBSIDIAN_EDGE_HARVEST)
	return ..(user, delay)

// ---------------------------------------------------------------- bladed clubs
// The macuahuitl and tepoztopilli carry a row of prismatic blades in grooves
// along their edges. Each hit can knock a blade out (more often against
// armour); with none left they are blunt wooden weapons until re-edged with
// new blades. Weapons placed on maps or spawned by events start fully edged;
// crafted ones start bare (the /unedged subtypes).
/obj/item/weapon/macuahuitl
	var/blades = 8
	var/max_blades = 8
	var/edged_force = WEAPON_FORCE_ROBUST
	var/blunt_force = 14
	var/bare_icon_state = "macuahuitl_bare"

/obj/item/weapon/macuahuitl/New()
	..()
	update_edge()

/obj/item/weapon/macuahuitl/after_load()
	..()
	update_edge()

/obj/item/weapon/macuahuitl/proc/update_edge()
	blades = clamp(blades, 0, max_blades)
	if (blades > 0)
		force = edged_force
		sharp = TRUE
		edge = TRUE
		icon = initial(icon)
		icon_state = initial(icon_state)
		attack_verb = list("slashed", "cut", "hacked")
	else
		force = blunt_force
		sharp = FALSE
		edge = FALSE
		icon = OBSIDIAN_ICON
		icon_state = bare_icon_state
		attack_verb = list("smacked", "hit", "bludgeoned")
	update_icon()

/obj/item/weapon/macuahuitl/examine(mob/user, distance = -1)
	..()
	if (blades <= 0)
		to_chat(user, SPAN_NOTICE("Its grooves are empty. Use prismatic blades on it to edge it."))
	else
		to_chat(user, SPAN_NOTICE("It holds [blades] of [max_blades] obsidian blades."))

/obj/item/weapon/macuahuitl/attack(mob/living/M, mob/living/user, target_zone)
	. = ..()
	if (!. || blades <= 0 || !isliving(M))
		return
	var/chance = OBSIDIAN_CHIP_CHANCE
	if (M.getarmor(target_zone, "melee") > 0)
		chance = OBSIDIAN_CHIP_CHANCE_ARMOUR
	if (!prob(chance))
		return
	blades--
	if (blades <= 0)
		to_chat(user, SPAN_WARNING("The last obsidian blade snaps out of \the [src]. It is only a wooden club now."))
	else
		to_chat(user, SPAN_WARNING("An obsidian blade chips out of \the [src]."))
	update_edge()

/obj/item/weapon/macuahuitl/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/stack/obsidian_blades) || !ishuman(user))
		return ..()
	var/mob/living/human/H = user
	if (blades >= max_blades)
		to_chat(H, SPAN_NOTICE("Every groove of \the [src] already holds a blade."))
		return
	if (!H.may_do_after)
		return
	var/obj/item/stack/obsidian_blades/B = W
	to_chat(H, SPAN_NOTICE("You start setting blades into \the [src] with pitch..."))
	if (!do_after(H, 30, src) || QDELETED(B) || B.loc != H || blades >= max_blades)
		return
	var/fitted = min(B.amount, max_blades - blades)
	if (fitted <= 0 || !B.use(fitted))
		return
	blades += fitted
	update_edge()
	to_chat(H, SPAN_NOTICE("You set [fitted] blade\s into \the [src]. It now holds [blades] of [max_blades]."))

/obj/item/weapon/macuahuitl/unedged
	blades = 0

// Aztec thrusting spear with a blade-edged wooden head.
/obj/item/weapon/macuahuitl/tepoztopilli
	name = "tepoztopilli"
	desc = "A Mesoamerican thrusting spear whose broad wooden head is edged with obsidian blades. It cuts as well as it stabs."
	icon = OBSIDIAN_ICON
	icon_state = "tepoztopilli"
	item_state = "spear"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	slot_flags = SLOT_SHOULDER | SLOT_BACK
	w_class = ITEM_SIZE_LARGE
	blades = 6
	max_blades = 6
	edged_force = 24
	blunt_force = 12
	bare_icon_state = "tepoztopilli_bare"

/obj/item/weapon/macuahuitl/tepoztopilli/unedged
	blades = 0

// ---------------------------------------------------------------- polished stone
// Chisel in the active hand, hammer in the other: grind a nodule into a
// polished bead, set into clothing or necklaces like the cut gemstones.
/obj/item/weapon/obsidian_nodule/proc/polish(mob/living/human/H, obj/item/chisel)
	if (!is_tool(H.l_hand, TOOL_HAMMER) && !is_tool(H.r_hand, TOOL_HAMMER))
		to_chat(H, SPAN_WARNING("You need a hammer in your other hand to use a chisel."))
		return
	if (!H.may_do_after || !obsidian_work_reachable(H, src, chisel))
		return
	H.visible_message(SPAN_NOTICE("[H] starts shaping and polishing \the [src]."), SPAN_NOTICE("You start shaping and polishing \the [src]."))
	if (!do_after(H, OBSIDIAN_POLISH_TIME / max(0.5, H.getStatCoeff("dexterity")), src) || !obsidian_work_reachable(H, src, chisel))
		return
	H.adaptStat("crafting", 1)
	var/turf/T = get_turf(src)
	var/in_hand = loc == H
	qdel(src)
	if (prob(OBSIDIAN_POLISH_FLAW_CHANCE / max(0.5, H.getStatCoeff("crafting"))))
		to_chat(H, SPAN_WARNING("The glass flakes apart under the chisel. Only a sharp shard is left."))
		obsidian_shatter(H, T, in_hand)
		return
	var/obj/item/stack/gemstone/obsidian/G = new /obj/item/stack/gemstone/obsidian(T)
	if (in_hand)
		H.put_in_hands(G)
	to_chat(H, SPAN_NOTICE("You polish \a [G.singular_name]."))

/obj/item/stack/gemstone/obsidian
	name = "polished obsidian"
	singular_name = "polished obsidian stone"
	desc = "A smooth bead of polished volcanic glass. Set it into clothing or jewellery with a chisel held in your other hand."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_polished"
	gem_colour = "#1d1c24"
	value = 5

// ---------------------------------------------------------------- mirrors
// Polished obsidian mirrors, as at Catalhoyuk and in Aztec Mexico. A hand
// mirror is crafted from cut obsidian; fasten it to a wall with a hammer like
// the glass mirror, and unfasten it the same way.
/obj/item/mirror/obsidian
	name = "obsidian mirror"
	desc = "A disc of volcanic glass ground flat and polished until it reflects, set in a plaster rim with a short grip. Fasten it to a wall with a hammer."
	icon = OBSIDIAN_ICON
	icon_state = "obsidian_hand_mirror"
	w_class = ITEM_SIZE_SMALL
	value = 6

/obj/item/mirror/obsidian/attack_self(mob/user)
	to_chat(user, SPAN_NOTICE("You gaze into \the [src]. Your reflection looks back, dark and smoky."))

/obj/item/mirror/obsidian/attackby(obj/item/H as obj, mob/user as mob)
	if (!is_tool(H, TOOL_HAMMER) || !isturf(user.loc))
		return ..()
	var/direction = WWinput(user, "Fasten it to which direction?", "Select a direction.", "North", WWinput_list_or_null(list("North", "East", "South", "West")))
	if (!direction || !can_fasten(user, H))
		return
	var/obj/structure/mirror/obsidian/S = new /obj/structure/mirror/obsidian(user.loc)
	switch (direction)
		if ("North")
			S.pixel_y = 32
		if ("East")
			S.pixel_x = 32
		if ("South")
			S.pixel_y = -32
		if ("West")
			S.pixel_x = -32
	to_chat(user, "You fasten \the [S] with your [H].")
	qdel(src)

/obj/structure/mirror/obsidian/attackby(obj/item/I as obj, mob/user as mob)
	if (is_tool(I, TOOL_HAMMER) && !shattered)
		var/obj/item/mirror/obsidian/M = new /obj/item/mirror/obsidian(loc)
		to_chat(user, "You unfasten \the [M] with your [I].")
		qdel(src)
		return
	return ..()

#undef OBSIDIAN_ICON
#undef OBSIDIAN_VOLCANO_RANGE
#undef OBSIDIAN_VOLCANO_BUCKET
#undef OBSIDIAN_MINING_CHANCE
#undef OBSIDIAN_COOLING_CHANCE
#undef OBSIDIAN_QUENCH_CHANCE
#undef OBSIDIAN_OUTCROP_SHARE
#undef OBSIDIAN_OUTCROP_NODULES
#undef OBSIDIAN_OUTCROP_REGEN
#undef OBSIDIAN_BLADES_PER_CORE
#undef OBSIDIAN_EDGE_HARVEST
#undef OBSIDIAN_CHIP_CHANCE
#undef OBSIDIAN_CHIP_CHANCE_ARMOUR
#undef OBSIDIAN_POLISH_TIME
#undef OBSIDIAN_POLISH_FLAW_CHANCE
