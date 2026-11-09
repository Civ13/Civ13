// Physical dissemination. Knowledge and ceilings remain owned by phase 1.
#define RECIPE_COMPENDIUM_MAX 16
#define RECIPE_COPY_TIME 1200
#define RECIPE_TEACH_TIME 1200
#define RECIPE_CACHE_RESTOCK 36000

/proc/recipe_book_actor_valid(mob/living/human/H)
	return istype(H) && H.client && H.stat == CONSCIOUS && !H.incapacitated() && !H.restrained() && map && map.recipe_knowledge_enabled()

/proc/recipe_blank_paper(obj/item/weapon/paper/P)
	return istype(P) && P.type == /obj/item/weapon/paper && isnull(P.document_record) && !P.gcDestroyed && P.loc && !length(P.info) && !length(P.stamps) && !length(P.stamped) && !length(P.contents)

/proc/recipe_held(mob/living/human/H, obj/item/I)
	return I && !I.gcDestroyed && I.loc == H && (H.get_active_hand() == I || H.get_inactive_hand() == I)

/mob/living/human/verb/write_recipe_manual()
	set name = "Write recipe manual"
	set category = "IC"
	if(!recipe_book_actor_valid(src)) return
	var/list/choices = clean_recipe_node_ids(known_recipe_nodes)
	if(!choices.len) return
	var/id = input(src, "Which known recipe group will you copy?", "Write manual") as null|anything in choices
	if(!id) return
	var/obj/item/weapon/pen/P = locate() in list(l_hand, r_hand)
	var/obj/item/weapon/paper/paper = locate() in list(l_hand, r_hand)
	if(!istype(P) || !recipe_blank_paper(paper))
		to_chat(src, SPAN_WARNING("Hold a pen and a blank sheet of paper."))
		return
	copy_recipe_manual(id, P, paper)

/mob/living/human/proc/copy_recipe_manual(id, obj/item/weapon/pen/P, obj/item/weapon/paper/paper)
	if(!recipe_book_actor_valid(src) || !knows_recipe_node(id) || !can_learn_recipe_node(id) || !recipe_held(src, P) || !recipe_held(src, paper) || !recipe_blank_paper(paper)) return FALSE
	to_chat(src, SPAN_NOTICE("You begin copying a manual. Keep the pen and paper in your hands for two minutes."))
	var/client/session = client
	if(!do_after(src, RECIPE_COPY_TIME, paper)) return FALSE
	if(client != session || !recipe_book_actor_valid(src) || !knows_recipe_node(id) || !can_learn_recipe_node(id) || !recipe_held(src, P) || !recipe_held(src, paper) || !recipe_blank_paper(paper)) return FALSE
	var/obj/item/weapon/book/node_book/B = create_node_book(get_turf(src), id)
	if(!B) return FALSE
	remove_from_mob(paper)
	qdel(paper)
	put_in_hands(B)
	return TRUE

// The source stays in hand, avoiding the legacy press's null-location slots.
/obj/structure/printingpress/proc/print_recipe_manual(obj/item/weapon/book/node_book/B, mob/living/human/H)
	var/obj/item/weapon/paper/paper = H ? H.get_inactive_hand() : null
	if(copying || !recipe_book_actor_valid(H) || !Adjacent(H) || !recipe_held(H, B) || !recipe_held(H, paper) || !recipe_blank_paper(paper) || !valid_recipe_node_id(B.node_id)) return FALSE
	var/id = B.node_id
	var/client/session = H.client
	copying = TRUE
	icon_state = "printingpress1"
	var/completed = do_after(H, 250, src)
	if(!src || gcDestroyed) return FALSE
	copying = FALSE
	icon_state = "printingpress0"
	if(!completed || !H || H.client != session || !recipe_book_actor_valid(H) || !Adjacent(H) || !recipe_held(H, B) || B.node_id != id || !recipe_held(H, paper) || !recipe_blank_paper(paper)) return FALSE
	var/obj/item/weapon/book/node_book/result = create_node_book(get_turf(src), id)
	if(!result) return FALSE
	H.remove_from_mob(paper)
	qdel(paper)
	return TRUE

/mob/living/human/verb/teach_recipe_group(mob/living/human/student in oview(1))
	set name = "Teach recipe group"
	set category = "IC"
	if(!recipe_book_actor_valid(src) || !recipe_book_actor_valid(student)) return
	var/list/choices = clean_recipe_node_ids(known_recipe_nodes)
	var/id = input(src, "Which recipe group?", "Teach") as null|anything in choices
	if(!id || !recipe_teaching_valid(src, student, id)) return
	if(alert(student, "[src] offers a two-minute lesson in [get_research_node(id).name]. Stay together?", "Recipe lesson", "Learn", "Decline") != "Learn") return
	teach_recipe_node(student, id)

/proc/recipe_teaching_valid(mob/living/human/teacher, mob/living/human/student, id)
	return teacher != student && recipe_book_actor_valid(teacher) && recipe_book_actor_valid(student) && teacher.Adjacent(student) && teacher.knows_recipe_node(id) && teacher.can_learn_recipe_node(id) && student.can_learn_recipe_node(id) && !student.knows_recipe_node(id)

/mob/living/human/proc/teach_recipe_node(mob/living/human/student, id)
	if(!recipe_teaching_valid(src, student, id)) return FALSE
	var/client/teacher_session = client
	var/client/student_session = student.client
	var/turf/teacher_place = get_turf(src)
	var/turf/student_place = get_turf(student)
	// Validate both participants throughout, not just the teacher's action.
	for(var/elapsed = 0, elapsed < RECIPE_TEACH_TIME, elapsed += 10)
		if(!do_after(src, 10, student) || client != teacher_session || !student || student.client != student_session || get_turf(src) != teacher_place || get_turf(student) != student_place || !recipe_teaching_valid(src, student, id)) return FALSE
	return student.learn_recipe_node(id)

/obj/item/weapon/book/node_compendium
	name = "recipe compendium"
	desc = "Bound recipe manuals. Holds up to sixteen different recipe groups as chapters."
	icon = 'icons/obj/library.dmi'
	icon_state = "book2"
	unique = TRUE
	flammable = TRUE
	var/list/node_ids = list()

/obj/item/weapon/book/node_compendium/after_load()
	. = ..()
	node_ids = clean_recipe_node_ids(node_ids)
	if(node_ids.len > RECIPE_COMPENDIUM_MAX) node_ids.Cut(RECIPE_COMPENDIUM_MAX + 1)

/obj/item/weapon/book/node_compendium/attack_self(mob/user)
	var/mob/living/human/H = user
	if(!recipe_book_actor_valid(H) || !H.Adjacent(src)) return
	var/id = input(H, "Study which chapter?", "Compendium") as null|anything in node_ids
	if(!id || !(id in node_ids) || !H.can_learn_recipe_node(id) || H.knows_recipe_node(id)) return
	if(do_after(H, 600, src) && src && !gcDestroyed && H.Adjacent(src) && recipe_book_actor_valid(H) && (id in node_ids))
		H.learn_recipe_node(id)

/obj/item/weapon/book/node_book/attackby(obj/item/weapon/W, mob/living/human/H)
	if(istype(W, /obj/item/weapon/book/node_book))
		var/obj/item/weapon/book/node_book/other = W
		if(other == src || node_id == other.node_id || !valid_recipe_node_id(node_id) || !valid_recipe_node_id(other.node_id) || !recipe_book_actor_valid(H) || !H.Adjacent(src) || !recipe_held(H, other)) return
		var/first = node_id
		var/second = other.node_id
		if(!do_after(H, 100, src) || !src || gcDestroyed || !other || other.gcDestroyed || node_id != first || other.node_id != second || !recipe_book_actor_valid(H) || !H.Adjacent(src) || !recipe_held(H, other)) return
		var/obj/item/weapon/book/node_compendium/C = new(get_turf(H))
		C.node_ids = list(first, second)
		H.remove_from_mob(other)
		if(loc == H) H.remove_from_mob(src)
		qdel(other)
		qdel(src)
		H.put_in_hands(C)
		return
	return ..()

/obj/item/weapon/book/node_compendium/attackby(obj/item/weapon/W, mob/living/human/H)
	if(!istype(W, /obj/item/weapon/book/node_book)) return ..()
	var/obj/item/weapon/book/node_book/B = W
	var/id = B.node_id
	if(!valid_recipe_node_id(id) || (id in node_ids) || node_ids.len >= RECIPE_COMPENDIUM_MAX || !recipe_book_actor_valid(H) || !H.Adjacent(src) || !recipe_held(H, B)) return
	if(!do_after(H, 100, src) || !src || gcDestroyed || !B || B.gcDestroyed || B.node_id != id || (id in node_ids) || node_ids.len >= RECIPE_COMPENDIUM_MAX || !recipe_book_actor_valid(H) || !H.Adjacent(src) || !recipe_held(H, B)) return
	node_ids += id
	H.remove_from_mob(B)
	qdel(B)

// No automatic placement. Map authors explicitly place these cache structures.
// One book is generated on demand per cooldown, never in a background loop.
/obj/structure/recipe_book_cache
	name = "recipe book cache"
	desc = "A weathered cache where travellers leave recipe manuals."
	icon = 'icons/obj/library.dmi'
	icon_state = "book2"
	anchored = TRUE
	density = FALSE
	var/starter_only = FALSE
	var/restock_remaining = 0
	var/tmp/restock_checked_at = 0
	map_storage_saved_vars = "density;dir;name;pixel_x;pixel_y;starter_only;restock_remaining"

/obj/structure/recipe_book_cache/starter
	name = "starter recipe cache"
	starter_only = TRUE

/obj/structure/recipe_book_cache/persistence_runtime_var(key)
	return key == "restock_checked_at" || ..()

/obj/structure/recipe_book_cache/after_load()
	. = ..()
	restock_remaining = isnum(restock_remaining) ? clamp(restock_remaining, 0, RECIPE_CACHE_RESTOCK) : RECIPE_CACHE_RESTOCK
	restock_checked_at = world.time

/obj/structure/recipe_book_cache/proc/claim_manual(mob/living/human/H)
	if(!recipe_book_actor_valid(H) || !Adjacent(H)) return null
	var/passed = max(0, world.time - restock_checked_at)
	restock_remaining = max(0, restock_remaining - passed)
	restock_checked_at = world.time
	if(restock_remaining > 0) return null
	var/list/eligible = list()
	for(var/id in research_nodes)
		var/datum/research_node/N = get_research_node(id)
		if(N.tree == "Main" && N.era_tier <= map.ordinal_age && (!starter_only || N.era_tier == 0)) eligible += id
	if(!eligible.len) return null
	var/obj/item/weapon/book/node_book/B = create_node_book(get_turf(src), pick(eligible))
	if(B) restock_remaining = RECIPE_CACHE_RESTOCK
	return B

/obj/structure/recipe_book_cache/attack_hand(mob/living/human/H)
	if(!claim_manual(H)) to_chat(H, SPAN_NOTICE("There is no manual ready in the cache."))

// Travel encodes only bounded chapter IDs, never object/datum references.
/proc/recipe_compendium_wire_ids(kind)
	if(!istext(kind) || copytext(kind, 1, 12) != "compendium:" || length(kind) > 2048) return null
	var/list/ids
	try
		ids = json_decode(copytext(kind, 12))
	catch
		return null
	if(!region_travel_knowledge_valid(ids) || !ids.len || ids.len > RECIPE_COMPENDIUM_MAX) return null
	return ids

#undef RECIPE_COMPENDIUM_MAX
#undef RECIPE_COPY_TIME
#undef RECIPE_TEACH_TIME
#undef RECIPE_CACHE_RESTOCK

// Fixed starter stock reuses the provisioner's paid, shared, bounded catalogue.
/obj/item/weapon/book/node_book/basic_tools
	name = "Basic Toolmaking manual"
	node_id = "basic_tools"

/obj/item/weapon/book/node_book/primitive_construction
	name = "Primitive Construction manual"
	node_id = "primitive_construction"

/obj/item/weapon/book/node_book/pottery_storage
	name = "Pottery and Cookware manual"
	node_id = "pottery_storage"
