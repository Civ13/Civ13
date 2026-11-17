// Native probe of code/game/objects/items/stacks/recipe_skill_needs.dm,
// included by tests/ecology_spawning/run_linux.py, never by the game DME.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/obj/map_metadata/skill_probe/New()
	map = src
/mob/living/human/skill_tester/New()
	return
var/skill_failures = 0
var/skill_runtime_error = FALSE
/proc/skill_check(condition, label)
	if (!condition)
		skill_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	skill_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/skill_need_of(title, type = /obj/item)
	var/datum/stack_recipe/R = new(title, type)
	var/list/need = recipe_skill_need(R)
	return need ? "[need[1]] [need[2]]" : "none"
/world/New()
	OpenPort("none")
	try
		new /obj/map_metadata/skill_probe
		skill_check(skill_need_of("wooden bowl") == "none", "an ordinary recipe needs no skill")
		skill_check(skill_need_of("carriage frame") == "crafting 1.7", "a carriage needs Crafting 170")
		skill_check(skill_need_of("stone wall") == "crafting 1.1", "a wall needs Crafting 110")
		skill_check(skill_need_of("leather wallet") == "none", "a wallet is not a wall")
		var/list/named = recipe_skill_need_named("locomotive frame", null)
		skill_check(named && named[1] == "crafting" && named[2] == 1.9 && isnull(recipe_skill_need_named("wooden bowl", null)) && isnull(recipe_skill_need_named(null, null)), "the Atlas asks the same table by title")
		named = recipe_skill_need_named("stone well", "/obj/structure/sink/well")
		skill_check(named && named[2] == 1.1, "the Atlas names a result path as text")
		skill_check(skill_need_of("stone well", /obj/structure/sink/well) == "crafting 1.1", "a well needs Crafting 110")
		skill_check(skill_need_of("unlocked iron door") == "crafting 1.1", "an unlocked iron door needs 110, not the locked door's 135")
		skill_check(skill_need_of("locked iron door") == "crafting 1.35", "a locked iron door needs 135")
		skill_check(skill_need_of("unlocked wood door") == "none", "an unlocked plain door needs nothing")
		skill_check(skill_need_of("locked wood door") == "crafting 1", "a locked door needs the starting skill")
		skill_check(skill_need_of("locked reinforced large steel double doors") == "crafting 1.55", "the highest matching need applies")
		skill_check(skill_need_of("catapult projectile") == "none", "catapult shot needs no skill")
		skill_check(skill_need_of("catapult") == "crafting 1.8", "a catapult needs 180")
		skill_check(skill_need_of("handcannon") == "crafting 1.8", "a handcannon meets both of its checks at 180, as before")
		skill_check(skill_need_of("language book", /obj/item/weapon/book/language_book) == "philosophy 1.35", "a language book needs Philosophy 135")
		skill_check(skill_need_of("circuits", /obj/item/stack/material/electronics) == "crafting 2.2", "electronics need Crafting 220")
		var/mob/living/human/skill_tester/H = new(locate(1, 1, 1))
		var/datum/stack_recipe/carriage = new("carriage frame", /obj/item)
		H.stats["crafting"] = list(112, 112)
		skill_check(recipe_skill_refusal(H, carriage) == "Needs Crafting 170. Yours is 112.", "the refusal names the skill, the need and the maker's own level")
		skill_check(recipe_skill_short(H, carriage), "a maker short of the skill is refused")
		H.stats["crafting"] = list(170, 170)
		skill_check(!recipe_skill_refusal(H, carriage) && !recipe_skill_short(H, carriage), "a maker with the skill is let through")
		var/datum/stack_recipe/wall = new("stone wall", /obj/item)
		H.stats["crafting"] = list(100, 100)
		skill_check(recipe_skill_short(H, wall), "a beginner cannot build a wall")
		map.ID = MAP_VOYAGE
		skill_check(!recipe_skill_short(H, wall), "the Voyage map lets anyone build walls")
	catch(var/exception/e)
		skill_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = skill_failures, "runtime_error" = skill_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
