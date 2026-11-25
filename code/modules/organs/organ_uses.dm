// ============================================================
// Harvested organs (issue 5126, phases 2 to 4)
// ------------------------------------------------------------
// Phase 2: an anatomy table where a whole organ is preserved in a jar of
// spirits or vinegar. The specimen is no longer food or a transplant, and it
// cannot be turned back. A scholar standing near a specimen on an anatomy
// table can record it as a naturalist's find of medicine: each kind of organ
// once per book, inside the existing find cap, and each specimen holds only
// a few records. Animal and human organs of one kind are the same find, so
// human organs give no extra research.
// Phase 3: a removed organ spoils outside a body. A sealed organ box keeps it
// clean, a refrigerator or freezer slows it; nothing repairs it or brings
// dead tissue back. Examining an organ reads its condition and blood type.
// Phase 4: a sausage casing twisted into catgut, a surgical ligature.
// These are simplified game systems, not medical instructions.
// ============================================================

#define SPECIMEN_FLUID 10
#define SPECIMEN_STUDIES 3
#define SPECIMEN_PREP_TIME 100

// Human organs that can become specimens. Brains are left out on purpose.
var/global/list/specimen_human_organs = list("heart", "lungs", "liver", "kidneys", "eyes", "appendix")

var/global/list/specimen_organ_names = list(
	"heart" = "heart",
	"lungs" = "lungs",
	"liver" = "liver",
	"kidneys" = "kidneys",
	"eyes" = "eyes",
	"appendix" = "appendix",
	"brain" = "brain",
	"intestines" = "intestines",
	"stomach" = "stomach")

// The kind of whole organ an item is, or null when it can't be a specimen.
/proc/specimen_organ_kind(obj/item/I)
	if (istype(I, /obj/item/organ))
		if (istype(I, /obj/item/organ/external) || istype(I, /obj/item/organ/brain))
			return null
		var/obj/item/organ/O = I
		return (O.organ_tag in specimen_human_organs) ? O.organ_tag : null
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/heart))
		return "heart"
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/liver))
		return "liver"
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/kidneys))
		return "kidneys"
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/lungs))
		return "lungs"
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/brain))
		return "brain"
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/intestines))
		return "intestines"
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat/offal/stomach) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/pig/stomach) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/cow/stomach))
		return "stomach"
	return null

// Why an organ is unfit to preserve, or null when it is fit.
/proc/specimen_organ_problem(obj/item/I)
	if (istype(I, /obj/item/organ))
		var/obj/item/organ/O = I
		if (O.owner)
			return "It has to be out of the body first."
		if ((O.status & ORGAN_DEAD) || O.germ_level >= INFECTION_LEVEL_THREE)
			return "It has rotted too far to keep."
		return null
	var/obj/item/weapon/reagent_containers/food/snacks/F = I
	if (!istype(F))
		return "That can't be preserved."
	if (F.rotten)
		return "It has rotted too far to keep."
	if (!F.raw || F.roasted || F.boiled || F.bitecount)
		return "Use a whole, raw organ."
	return null

// A pathological specimen shows damage or infection; it is the same find.
/proc/specimen_is_pathological(obj/item/I)
	if (!istype(I, /obj/item/organ))
		return FALSE
	var/obj/item/organ/O = I
	return O.damage >= O.min_bruised_damage || O.germ_level >= INFECTION_LEVEL_ONE

/proc/specimen_fluid_amount(obj/item/weapon/reagent_containers/glass/preserve_jar/J)
	if (!istype(J) || !J.reagents)
		return 0
	return J.reagents.get_reagent_amount("ethanol") + J.reagents.get_reagent_amount("vinegar")

// ---------- The anatomy table ----------

/obj/structure/table/wood/anatomy
	name = "anatomy table"
	desc = "A scrubbed wooden table for studying anatomy. Hold a whole raw organ and a preserve jar holding at least 10 units of spirits or vinegar, and use the organ on the table to preserve it as a specimen. Specimens kept on this table can be recorded as finds of Medicine."

/obj/structure/table/wood/anatomy/attackby(obj/item/I, mob/user, params)
	if (!specimen_organ_kind(I) || !ishuman(user) || user.a_intent == I_HARM)
		return ..()
	var/obj/item/weapon/reagent_containers/glass/preserve_jar/J = user.get_inactive_hand()
	if (!istype(J))
		return ..()
	preserve_specimen(I, J, user)
	return TRUE

/obj/structure/table/wood/anatomy/proc/preserve_specimen(obj/item/organ_item, obj/item/weapon/reagent_containers/glass/preserve_jar/J, mob/living/human/user)
	if (!istype(user) || user.stat != CONSCIOUS || !user.Adjacent(src))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot do that during persistence operations."))
		return FALSE
	var/kind = specimen_organ_kind(organ_item)
	var/problem = specimen_organ_problem(organ_item)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	if (!J.is_open_container())
		to_chat(user, SPAN_WARNING("Take the cover off \the [J] first."))
		return FALSE
	if (specimen_fluid_amount(J) < SPECIMEN_FLUID)
		to_chat(user, SPAN_WARNING("\The [J] needs at least [SPECIMEN_FLUID] units of spirits or vinegar to keep an organ."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts laying \the [organ_item] into \the [J]."), SPAN_NOTICE("You start preserving \the [organ_item] in \the [J]."))
	if (!do_after(user, SPECIMEN_PREP_TIME, src))
		return FALSE
	// Everything is checked again after the wait: either hand may have changed.
	if (QDELETED(src) || QDELETED(organ_item) || QDELETED(J) || user.stat != CONSCIOUS || !user.Adjacent(src))
		return FALSE
	if (user.get_active_hand() != organ_item || user.get_inactive_hand() != J)
		to_chat(user, SPAN_WARNING("You need the organ and the jar in your hands."))
		return FALSE
	if (specimen_organ_kind(organ_item) != kind || specimen_organ_problem(organ_item) || !J.is_open_container() || specimen_fluid_amount(J) < SPECIMEN_FLUID)
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return FALSE
	var/human = istype(organ_item, /obj/item/organ)
	var/pathological = specimen_is_pathological(organ_item)
	var/source = human ? "human [specimen_organ_names[kind]]" : "animal [specimen_organ_names[kind]]"
	var/donor = null
	if (human)
		var/obj/item/organ/O = organ_item
		if (O.dna && O.dna.real_name)
			donor = O.dna.real_name
	if (!user.canUnEquip(organ_item) || !user.canUnEquip(J))
		return FALSE
	user.remove_from_mob(organ_item)
	user.remove_from_mob(J)
	// Pay both inputs before the output exists; nothing can be preserved twice.
	qdel(organ_item)
	qdel(J)
	var/obj/item/organ_specimen/S = new(get_turf(src))
	S.set_specimen(kind, source, pathological, user.real_name)
	user.put_in_hands(S)
	if (human)
		var/where = "([x],[y],[z])"
		log_game("[key_name(user)] preserved a [source] specimen[donor ? " from [donor]" : ""] at [where].")
		user.append_attack_log("\[[time_stamp()]\] preserved a [source] specimen[donor ? " from [donor]" : ""] at [where]")
	user.visible_message(SPAN_NOTICE("[user] seals \a [S.name]."), SPAN_NOTICE("You seal the [source] in the jar. Keep it on an anatomy table and use <b>Record a Find</b> with a book or paper to study it."))
	return TRUE

// ---------- The specimen ----------

// Not food and not an organ: preservation is final.
/obj/item/organ_specimen
	name = "preserved specimen"
	desc = "An organ kept in a jar of preserving fluid."
	icon = 'icons/obj/food/preserves.dmi'
	icon_state = "preserve_jar"
	w_class = ITEM_SIZE_SMALL
	value = 3
	var/organ_kind = null
	var/source_name = null
	var/pathological = FALSE
	var/studies_left = SPECIMEN_STUDIES
	var/prepared_by = null

/obj/item/organ_specimen/proc/set_specimen(kind, source, is_pathological, preparer)
	organ_kind = kind
	source_name = source
	pathological = is_pathological ? TRUE : FALSE
	prepared_by = preparer
	studies_left = SPECIMEN_STUDIES
	update_specimen()

/obj/item/organ_specimen/proc/update_specimen()
	name = "preserved [pathological ? "diseased " : ""][source_name ? source_name : "organ"]"
	update_icon()

/obj/item/organ_specimen/after_load()
	..()
	update_specimen()

/obj/item/organ_specimen/update_icon()
	overlays.Cut()
	var/image/filling = image(icon, src, "jam_jar_fill")
	filling.color = "#E6DDA8"
	overlays += filling

/obj/item/organ_specimen/examine(mob/user)
	..(user)
	if (pathological)
		to_chat(user, SPAN_NOTICE("The tissue shows damage or infection. It still teaches the same lesson as a healthy one."))
	if (prepared_by)
		to_chat(user, SPAN_NOTICE("Prepared by [prepared_by]."))
	if (studies_left > 0)
		to_chat(user, SPAN_NOTICE("It can still be studied [studies_left] more time\s. Keep it on an anatomy table and use <b>Record a Find</b>."))
	else
		to_chat(user, SPAN_NOTICE("It has been studied as much as it can teach."))

// Whether this specimen can be recorded right now.
/obj/item/organ_specimen/proc/studyable()
	if (studies_left <= 0 || !organ_kind || !isturf(loc))
		return FALSE
	return locate(/obj/structure/table/wood/anatomy) in loc

/obj/item/organ_specimen/proc/find_kind()
	return "specimen:[organ_kind]"

// Called once a record of this specimen is written; the specimen is finite.
/obj/item/organ_specimen/proc/use_study()
	studies_left = max(0, studies_left - 1)

// ---------- Sealed transport (phase 3) ----------

/obj/item/weapon/storage/organ_box
	name = "organ box"
	desc = "A small sealed box lined with waxed cloth. An organ inside stays clean; put the box in a refrigerator or freezer and it spoils more slowly too. It never mends what is already spoiled."
	icon_state = "box"
	w_class = ITEM_SIZE_NORMAL
	storage_slots = 1
	max_w_class = ITEM_SIZE_NORMAL
	can_hold = list(/obj/item/organ)
	cant_hold = list(/obj/item/organ/external)

// How fast an organ out of a body spoils here: 1 is open air.
/obj/item/organ/proc/spoil_rate()
	. = 1
	var/atom/A = loc
	// A box can sit in a crate or a fridge; look a few containers up.
	for (var/depth = 1, depth <= 4 && A && !isturf(A), depth++)
		if (istype(A, /obj/structure/closet/fridge))
			var/obj/structure/closet/fridge/F = A
			return F.refrigeration_powered() ? 0.1 : 0.4
		if (istype(A, /obj/structure/closet/crate/freezer))
			return 0.15
		A = A.loc

/obj/item/organ/proc/is_sealed()
	return istype(loc, /obj/item/weapon/storage/organ_box)

// Germs gained per organ tick out of a body. Never negative: cold and sealing
// slow spoiling, they never repair it.
/obj/item/organ/proc/spoil_germs(base)
	return max(0, base * spoil_rate() * (is_sealed() ? 0.25 : 1))

/obj/item/organ/proc/condition_text()
	if (status & ORGAN_DEAD)
		return null
	if (germ_level >= INFECTION_LEVEL_TWO)
		return SPAN_WARNING("It is badly spoiled and close to dead. Transplanted, it would carry a serious infection.")
	if (germ_level >= INFECTION_LEVEL_ONE)
		return SPAN_WARNING("It has started to spoil. Transplanted, it would carry an infection.")
	if (is_broken())
		return SPAN_WARNING("It is badly damaged.")
	if (is_bruised())
		return SPAN_NOTICE("It is bruised.")
	return SPAN_NOTICE("It looks fresh.")

// Phase 3: loose organs keep spoiling after a reload instead of resting.
/obj/item/organ/after_load()
	..()
	// Only loose organs: one inside a body has its owner and spoils no more.
	if (!(status & ORGAN_DEAD) && !owner)
		processing_objects |= src

// ---------- Catgut (phase 4) ----------

/obj/item/stack/sausagecasing/attack_self(mob/user)
	if (QDELETED(src) || QDELETED(user) || loc != user || user.stat != CONSCIOUS || amount < 1)
		return
	if (use(1))
		var/obj/item/stack/catgut/C = new(get_turf(user), 2, FALSE)
		user.put_in_any_hand_if_possible(C)
		to_chat(user, SPAN_NOTICE("You twist and dry the casing into catgut."))

// A ligature for clamping bleeders and mending veins; not a rope.
/obj/item/stack/catgut
	name = "catgut"
	desc = "Thin cord twisted from dried animal gut. A surgeon can tie off bleeders and mend torn veins with it."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	color = "#E8D7B0"
	singular_name = "catgut thread"
	max_amount = 20
	w_class = ITEM_SIZE_TINY

#undef SPECIMEN_FLUID
#undef SPECIMEN_STUDIES
#undef SPECIMEN_PREP_TIME
