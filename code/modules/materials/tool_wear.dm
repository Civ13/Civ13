// Soft tools and tool wear (docs/material-roles.md, "Soft tools").
//
// One rule in place of per-recipe "needs an iron tool" checks: a tool softer
// than what it works on still works, slowly, and wears out doing it.
//   A.work_material_name(I) -> the material tool I would be cutting, or null
//   tool_is_soft(I, name)   -> the tool's material is less firm than that
// The thing worked on says what it is made of and which tools cut it; the
// tool says nothing. Asked once before attackby(), so no attackby() changes.
//
// Wear is item health (code/_helpers/item_wear.dm). A plain tool has no
// health until it first takes wear, so tools that never meet this rule store
// nothing new.

// Extra wait before a soft tool bites, in deciseconds.
#define SOFT_TOOL_DELAY 40
// Health a plain tool starts with the first time it wears.
#define TOOL_WEAR_LIFE 60
// Wear for one job on something the tool cuts cleanly, and on something harder.
#define TOOL_WEAR_JOB 0.5
#define TOOL_WEAR_SOFT 3

// The material tool I would cut on this, or null when the rule does not apply.
/atom/proc/work_material_name(obj/item/I)
	return null

/proc/tool_is_soft(obj/item/I, work_material)
	var/material/tool = get_material_by_name(tool_material_name(I))
	var/material/work = get_material_by_name(work_material)
	return (tool && work) ? tool.firmness < work.firmness : FALSE

// Wear a plain tool by one job. A tool in its usual material only wears on
// work harder than itself; another material also wears by how much shorter it
// lasts in that role. Returns TRUE when the tool broke.
/proc/tool_job_wear(obj/item/I, soft = FALSE)
	if (!isitem(I) || !I.tool_noun)
		return FALSE
	var/amount = soft ? TOOL_WEAR_SOFT : 0
	if (I.tool_role && I.tool_material != initial(I.tool_material))
		var/list/usual = part_rating(I.tool_role, initial(I.tool_material))
		var/list/now = part_rating(I.tool_role, I.tool_material)
		if (usual && now && now[2] > 0 && now[2] < usual[2])
			amount += TOOL_WEAR_JOB * usual[2] / now[2]
	if (amount <= 0)
		return FALSE
	if (isnull(I.health))
		I.health = TOOL_WEAR_LIFE
		I.maxhealth = TOOL_WEAR_LIFE
	return I.apply_wear(amount, WEAR_WORK)

// A worn-out plain tool breaks. Material items, shields and clothing break
// their own way and never reach this.
/obj/item/check_health(consumed)
	. = ..()
	if (. || !tool_noun || isnull(health) || health > 0)
		return
	visible_message(SPAN_WARNING("\The [src] breaks!"))
	playsound(get_turf(src), 'sound/effects/hit_on_shattered_glass.ogg', 60, TRUE)
	qdel(src)
	return TRUE

/obj/item/examine(mob/user, distance)
	. = ..()
	if (!tool_noun || isnull(health) || !maxhealth || health >= maxhealth)
		return
	if (health <= maxhealth * 0.25)
		to_chat(user, SPAN_WARNING("It is nearly worn out."))
	else if (health <= maxhealth * 0.6)
		to_chat(user, "It is worn.")
	else
		to_chat(user, "It shows some wear.")

// Asked before attackby(). TRUE means the user gave up and nothing more
// happens; FALSE lets the work go ahead as usual.
/proc/tool_meets_work(obj/item/I, atom/A, mob/living/user)
	if (!isitem(I) || !I.tool_flags || !A || !isliving(user) || user.a_intent == I_HARM)
		return FALSE
	var/work = A.work_material_name(I)
	if (!work)
		return FALSE
	var/soft = tool_is_soft(I, work)
	if (soft)
		var/material/M = get_material_by_name(work)
		to_chat(user, SPAN_WARNING("\The [I] is softer than the [M.display_name] and barely bites. A harder tool would be quicker."))
		if (!do_after(user, SOFT_TOOL_DELAY, A) || QDELETED(I) || QDELETED(A))
			return TRUE
	return tool_job_wear(I, soft)

// What cuts what.
/turf/wall/rockwall/work_material_name(obj/item/I)
	return is_tool(I, TOOL_CHISEL) ? "stone" : null

/turf/floor/dirt/underground/work_material_name(obj/item/I)
	return is_tool(I, TOOL_CHISEL) ? "stone" : null

/turf/floor/dirt/underground/sandy/work_material_name(obj/item/I)
	return null

/turf/floor/dirt/underground/icy/work_material_name(obj/item/I)
	return null

/obj/covers/stone_wall/work_material_name(obj/item/I)
	return is_tool(I, TOOL_CHISEL) ? "stone" : null

/obj/covers/marble_wall/work_material_name(obj/item/I)
	return is_tool(I, TOOL_CHISEL) ? "marble" : null

/obj/covers/sandstone_smooth_wall/work_material_name(obj/item/I)
	return is_tool(I, TOOL_CHISEL) ? "sandstone" : null

/obj/structure/cable/work_material_name(obj/item/I)
	return is_tool(I, TOOL_WIRECUTTER) ? (cable_wire_materials[cable_color] || "copper") : null

/obj/structure/barbwire/work_material_name(obj/item/I)
	return is_tool(I, TOOL_WIRECUTTER) ? "iron" : null

/obj/structure/grille/chainlinkfence/work_material_name(obj/item/I)
	return is_tool(I, TOOL_WIRECUTTER) ? "iron" : null

#undef SOFT_TOOL_DELAY
#undef TOOL_WEAR_LIFE
#undef TOOL_WEAR_JOB
#undef TOOL_WEAR_SOFT
