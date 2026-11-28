// Lathes (docs/material-roles.md, "Lathes"): where machine parts are cut true.
//
// A part carved by hand, forged or cast is rough. A lathe turns a precise
// gear set, shaft or bearing from stock, or trues a rough one, in the
// materials that lathe can cut. Both lathes are built from rough parts, so
// the first one can always be made.

// What a lathe turns from stock: label -> list(part type, units of material, deciseconds).
var/global/list/lathe_parts = list(
	"gear set" = list(/obj/item/machine_part/gear, 4, 160),
	"shaft" = list(/obj/item/machine_part/shaft, 2, 80),
	"bearing" = list(/obj/item/machine_part/bearing, 2, 100),
)
// Soft enough for a hand tool against work turned by a cord.
var/global/list/pole_lathe_materials = list("wood", "bone", "brass")
// Anything a hardened tool in a slide rest can cut.
var/global/list/engine_lathe_materials = list("copper", "bronze", "brass", "iron", "steel")

/obj/structure/workshop_machine/lathe
	name = "lathe"
	icon = 'icons/obj/lathes.dmi'
	icon_state = "pole_lathe"
	// A pole lathe is worked with a hand chisel; an engine lathe carries its own tool.
	var/needs_chisel = TRUE
	// Work time against the times in lathe_parts.
	var/turn_speed = 1

/obj/structure/workshop_machine/lathe/proc/lathe_materials()
	return pole_lathe_materials

// Why this lathe cannot make this part type of this material, or null.
/obj/structure/workshop_machine/lathe/proc/turn_refusal(part_type, material_name)
	if (!(material_name in lathe_materials()))
		return "\the [src] cannot cut [material_name]"
	var/found = FALSE
	for (var/label in lathe_parts)
		var/list/row = lathe_parts[label]
		if (row[1] == part_type)
			found = TRUE
	if (!found)
		return "that is not turned on a lathe"
	return machine_part_refusal(part_type, material_name)

/obj/structure/workshop_machine/lathe/proc/tool_refusal(mob/living/human/H)
	if (needs_chisel && !craft_need_tool(H, "chisel", craft_need_candidates(H)))
		return "You need a chisel (held, worn or at your feet) to work \the [src]."
	return null

/obj/structure/workshop_machine/lathe/proc/turn_choices(mob/living/human/H, material_name)
	var/list/choices = list()
	for (var/label in lathe_parts)
		var/list/row = lathe_parts[label]
		if (turn_refusal(row[1], material_name) || !crafting_recipe_allowed(H, "[row[1]]"))
			continue
		choices["[label] - [row[2]] [material_name]"] = label
	return choices

// The worker still stands at the fastened lathe and can still use it.
/obj/structure/workshop_machine/lathe/proc/turner_ready(mob/living/human/H, obj/item/I)
	return !QDELETED(src) && anchored && istype(H) && !QDELETED(I) && I.loc == H && get_dist(src, H) <= 1 && !H.incapacitated() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && crafting_recipe_allowed(H, "[type]")

/obj/structure/workshop_machine/lathe/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	var/obj/item/stack/material/S = I
	var/obj/item/machine_part/P = I
	if (!istype(S) && !istype(P))
		return ..()
	if (!can_start_material_work(H))
		return
	if (!crafting_recipe_allowed(H, "[type]"))
		return
	var/refused = tool_refusal(H)
	if (refused)
		to_chat(H, SPAN_WARNING(refused))
		return
	if (istype(P))
		true_part(H, P)
		return
	var/list/choices = turn_choices(H, S.default_type)
	if (!choices.len)
		to_chat(H, SPAN_WARNING("Nothing you know how to make can be turned from [S.default_type] on \the [src]."))
		return
	var/picked = WWinput(H, "What do you want to turn?", capitalize(name), choices[1], choices + "Cancel")
	if (!picked || picked == "Cancel" || !(picked in choices))
		return
	turn_part(H, S, choices[picked])

// Turn one precise part from stock. Returns the part, or null.
/obj/structure/workshop_machine/lathe/proc/turn_part(mob/living/human/H, obj/item/stack/material/S, label)
	var/list/row = lathe_parts[label]
	if (busy || !row || !turner_ready(H, S))
		return null
	var/material_name = S.default_type
	if (turn_refusal(row[1], material_name) || tool_refusal(H))
		return null
	if (S.amount < row[2])
		to_chat(H, SPAN_WARNING("You need [row[2]] [material_name] for a [label]."))
		return null
	busy = TRUE
	icon_state = "[initial(icon_state)]_on"
	visible_message(SPAN_NOTICE("[H] sets a piece of [material_name] turning on \the [src]."))
	var/obj/item/machine_part/made = null
	if (do_after(H, reference_build_time(H, "[row[1]]", max(10, round(row[3] / turn_speed))), src) && turner_ready(H, S) && S.amount >= row[2] && !tool_refusal(H) && crafting_recipe_allowed(H, "[row[1]]"))
		S.use(row[2])
		var/part_type = row[1]
		if (!trial_craft_ruined(H, "[part_type]"))
			made = new part_type(get_turf(src), material_name)
			made.precise = TRUE
			made.apply_part_material()
			note_craft_practice(H, "[part_type]")
			to_chat(H, SPAN_NOTICE("You turn \a [made]."))
	busy = FALSE
	if (!QDELETED(src))
		icon_state = initial(icon_state)
	return made

// Cut a rough part true. Returns TRUE when it became precise.
/obj/structure/workshop_machine/lathe/proc/true_part(mob/living/human/H, obj/item/machine_part/P)
	if (busy || !turner_ready(H, P))
		return FALSE
	if (P.precise)
		to_chat(H, SPAN_NOTICE("\The [P] is already true."))
		return FALSE
	var/refused = turn_refusal(P.type, P.part_material)
	if (refused)
		to_chat(H, SPAN_WARNING("You cannot true \the [P] here: [refused]."))
		return FALSE
	if (P.wear >= MACHINE_PART_WORN_OUT)
		to_chat(H, SPAN_WARNING("\The [P] is worn out; there is nothing left to cut true."))
		return FALSE
	busy = TRUE
	icon_state = "[initial(icon_state)]_on"
	visible_message(SPAN_NOTICE("[H] mounts \the [P] on \the [src] and takes a light cut."))
	var/done = FALSE
	if (do_after(H, max(10, round(60 / turn_speed)), src) && turner_ready(H, P) && !P.precise && !tool_refusal(H))
		P.precise = TRUE
		P.apply_part_material()
		to_chat(H, SPAN_NOTICE("\The [P] now runs true."))
		done = TRUE
	busy = FALSE
	if (!QDELETED(src))
		icon_state = initial(icon_state)
	return done

/obj/structure/workshop_machine/lathe/examine(mob/user, distance)
	..()
	to_chat(user, "It cuts [english_list(lathe_materials())]. Use stock on it to turn a precise gear set, shaft or bearing, or a rough part to cut it true.")

/obj/structure/workshop_machine/lathe/pole
	name = "pole lathe"
	desc = "A springy pole, a cord wrapped round the work and a treadle. The work spins back and forth while a chisel on the rest cuts it round."
	icon_state = "pole_lathe"

/obj/structure/workshop_machine/lathe/engine
	name = "engine lathe"
	desc = "An iron lathe with a slide rest and a lead screw. The tool is held by the machine, so it cuts metal true every time."
	icon_state = "engine_lathe"
	needs_chisel = FALSE
	turn_speed = 2

/obj/structure/workshop_machine/lathe/engine/lathe_materials()
	return engine_lathe_materials
