// ============================================================
// Gun blueprint design codes (docs/gun-blueprint-codes.md)
// ------------------------------------------------------------
//   C13GUN/1/<name>/<stock>/<receiver>/<feeding>/<barrel>/<caliber id>/<look or ->
//
// Spaces in a field are written "_" (design_code_fields drops spaces). Any
// blueprint exports its code. Importing happens at a gunsmithing bench and is
// the bench's own design flow replayed choice by choice (bench_action), so it
// asks exactly what designing by hand asks: the designer's skill, the coins,
// the parts the gunsmith's people know (gunsmith_tech_band), the calibers the
// receiver and feed take on this map, the bench's steel and wood, and the
// 50 silver when the blueprint is drawn.
// ============================================================

#define GUN_CODE_MAX 240
#define GUN_CODE_FIELD_MAX 40

/proc/gun_code_field_out(value)
	return replacetext(replacetext("[value]", "/", "-"), " ", "_")

/proc/gun_code_field_in(value)
	return replacetext("[value]", "_", " ")

// A blueprint's code, or null when it is not a whole design.
/proc/gun_blueprint_code(obj/item/blueprint/gun/B)
	if (!istype(B))
		return null
	var/list/parts = list(B.stock_type, B.receiver_type, B.feeding_type, B.barrel_type, B.caliber)
	for (var/part in parts)
		if (!istext(part) || !length(part) || part == "none" || part == "caliber")
			return null
	var/list/fields = list(B.custom_name ? B.custom_name : "gun") + parts
	fields += B.override_sprite ? B.override_sprite : "-"
	var/list/out = list()
	for (var/field in fields)
		out += gun_code_field_out(field)
	return "C13GUN/1/[jointext(out, "/")]"

// A code -> list("name", "stock", "receiver", "feeding", "barrel", "caliber",
// "look"), or null. Only the shape is checked here; the bench judges the parts.
/proc/gun_design_from_code(code)
	var/list/fields = design_code_fields(code, "GUN", GUN_CODE_MAX)
	if (!fields || fields.len != 7)
		return null
	for (var/field in fields)
		if (!length(field) || length(field) > GUN_CODE_FIELD_MAX)
			return null
	. = list()
	var/list/keys = list("name", "stock", "receiver", "feeding", "barrel", "caliber", "look")
	for (var/i in 1 to keys.len)
		.[keys[i]] = gun_code_field_in(fields[i])
	if (.["look"] == "-")
		.["look"] = null

/obj/item/blueprint/gun/attack_self(mob/user)
	export_code(user)

/obj/item/blueprint/gun/proc/export_code(mob/user)
	var/code = gun_blueprint_code(src)
	if (!code)
		to_chat(user, SPAN_WARNING("This blueprint is not a whole design, so it has no design code."))
		return
	design_code_show(user, "Gun blueprint: [custom_name]", code, "Import it at any gunsmithing bench to design the same gun there.")

// Designs a gun from a pasted code, step by step through the bench's own flow.
/obj/structure/gunbench/proc/import_design(mob/living/human/H)
	if (!istype(H) || H.stat || get_dist(src, H) > 2)
		return
	if (current_gun)
		to_chat(H, SPAN_WARNING("Finish or cancel the gun on the bench first."))
		return
	if (!can_design(H))
		return
	var/typed = design_code_ask(H, "Gunsmithing Bench", "Paste a gun blueprint's design code (it starts with C13GUN/). The bench works through it as if you chose each part, so it needs parts your people know, the steel and wood on the bench and 50 silver in hand.", GUN_CODE_MAX)
	if (!typed || current_gun || H.stat || get_dist(src, H) > 2)
		return
	import_design_code(H, typed)

// The steps of an import once the code is in hand. Returns the new blueprint,
// or null with the reason told to H.
/obj/structure/gunbench/proc/import_design_code(mob/living/human/H, typed)
	var/list/G = gun_design_from_code(typed)
	if (!G)
		to_chat(H, SPAN_WARNING(design_code_refusal(typed, "GUN")))
		return null
	// The bench offers calibers by name; the code keeps the caliber itself.
	var/caliber_name = null
	for (var/option in custom_gun_calibers(G["receiver"], G["feeding"]))
		var/list/cal = custom_gun_caliber(option)
		if (cal && cal[1] == G["caliber"])
			caliber_name = option
			break
	var/list/steps = list(
		list("what" = "stock", "act" = list("step" = "1", "choice" = G["stock"])),
		list("what" = "receiver", "act" = list("step" = "2", "choice" = G["receiver"])),
		list("what" = "feeding system", "act" = list("step" = "3", "choice" = G["feeding"])),
		list("what" = "barrel", "act" = list("step" = "4", "choice" = G["barrel"])),
		list("what" = "caliber", "act" = list("action" = "caliber", "cal" = caliber_name)))
	if (current_gun)
		return null
	importing = TRUE
	. = import_design_steps(H, typed, G, steps)
	importing = FALSE

/obj/structure/gunbench/proc/import_design_steps(mob/living/human/H, typed, list/G, list/steps)
	bench_action(H, list("action" = "start"))
	if (!current_gun)
		return null
	for (var/list/S in steps)
		var/before = design_stage()
		var/list/act = S["act"]
		if (act["cal"] || act["choice"] || act["look"])
			bench_action(H, act.Copy())
		if (!current_gun || design_stage() == before)
			var/value = G[S["what"] == "feeding system" ? "feeding" : S["what"]]
			to_chat(H, SPAN_WARNING("The bench cannot make that design: its [S["what"]] ([value ? value : "unknown"]) is not one your people can make here, or the bench lacks the steel or wood for it."))
			if (current_gun)
				bench_action(H, list("action" = "cancel"))
			return null
	// The look: the bench asks whether to change it, or straight away which
	// one when its receiver has no look of its own.
	for (var/tries in 1 to 2)
		var/stage = design_stage()
		if (stage != "appearance" && stage != "look")
			break
		var/look = stage == "look" ? G["look"] : (G["look"] ? "Change" : "Keep")
		if (look)
			bench_action(H, list("action" = "appearance", "look" = look))
		if (!current_gun || design_stage() == stage)
			to_chat(H, SPAN_WARNING("The bench cannot make that design: its look ([G["look"] ? G["look"] : "none given"]) is not one this receiver comes in."))
			if (current_gun)
				bench_action(H, list("action" = "cancel"))
			return null
	last_blueprint = null
	bench_action(H, list("action" = "name", "name" = G["name"]))
	var/obj/item/blueprint/gun/made = last_blueprint
	last_blueprint = null
	if (!made)
		return null // the name step said why (the coins)
	design_code_log(H, "gun blueprint", made.name, typed)
	return made

#undef GUN_CODE_MAX
#undef GUN_CODE_FIELD_MAX
