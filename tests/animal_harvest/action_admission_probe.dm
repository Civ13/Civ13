// Production stick sharpening owns the real do_after while another click runs.
// Client connectivity alone is adapted by the existing grass fixture subtype.
/mob/living/harvest_tester
	var/grass_start_messages = 0
	var/admission_attempt_finished = FALSE

/mob/living/harvest_tester/visible_message(message, self_message, blind_message)
	if (findtext(message, "starts cutting fibres"))
		grass_start_messages++
	return ..()

/proc/harvest_action_admission_regressions(turf/site, mob/living/harvest_tester/U)
	var/obj/item/weapon/flint/sharpened/tool = new(U)
	var/obj/item/weapon/branch/original = new(site)
	var/obj/item/weapon/branch/other = new(site)
	var/obj/item/weapon/branch/sharpened/harvest_tester/axe_stick = new(site)
	var/obj/item/stack/crude_twine/binding = new(U, 2)
	var/obj/item/weapon/material/kitchen/utensil/knife/blade = new(U)
	var/obj/structure/repair/grindstone/bench = new(site)
	var/blade_health = blade.health
	var/blade_maxhealth = blade.maxhealth
	U.l_hand = tool
	U.hand = TRUE
	U.may_do_after = TRUE
	U.admission_attempt_finished = FALSE
	U.grass_start_messages = 0
	spawn(1)
		harvest_assert(!U.may_do_after && !original.sharpened, "Sharpening did not hold the real wait")
		var/cooldown_before = U.next_move
		for (var/path in list(/obj/structure/wild/tallgrass/twine_tester, /obj/structure/wild/tallgrass2/twine_tester))
			var/obj/structure/wild/G = new path(site)
			harvest_assert(!G.attackby(tool, U), "Busy grass click admitted")
			harvest_assert(!QDELETED(G) && !G.cutting_grass && G.vars["test_wait_calls"] == 0 && !harvest_count(site, /obj/item/stack/grass_cuttings), "Busy grass click claimed, waited, retired or produced fibres")
			qdel(G)
		var/turf/floor/grass/twine_tester/floor_grass = locate(4,3,1)
		floor_grass = floor_grass.ChangeTurf(/turf/floor/grass/twine_tester)
		floor_grass.gather_grass_cuttings(U, tool)
		harvest_assert(istype(floor_grass, /turf/floor/grass) && !floor_grass.busy && !harvest_count(site, /obj/item/stack/grass_cuttings), "Busy floor grass attempt changed turf or produced fibres")
		floor_grass.ChangeTurf(/turf/floor/plating)
		other.attackby(tool, U)
		axe_stick.assemble_flint_axe(U, tool)
		tool.attackby(blade, U)
		bench.attackby(blade, U)
		harvest_assert(!other.sharpened && !QDELETED(axe_stick) && !axe_stick.assembling_axe && tool.sharpened && !QDELETED(tool) && binding.amount == 2 && !harvest_count(site, /obj/item/weapon/material/hatchet/tribal/flint), "Busy attempt modified stick, head or binding")
		harvest_assert(blade.health == blade_health && blade.maxhealth == blade_maxhealth && bench.icon_state == bench.idlesprite, "Busy repair changed durability or bench state")
		harvest_assert(!U.grass_start_messages && U.next_move == cooldown_before && !U.may_do_after, "Busy attempts announced, changed cooldown or released original wait")
		U.admission_attempt_finished = TRUE
	original.attackby(tool, U)
	harvest_assert(U.admission_attempt_finished && original.sharpened && U.may_do_after && !other.sharpened, "Rejected click interrupted original sharpening or overlapped waits")
	// Normal grass admission after the original action still announces and yields.
	var/obj/structure/wild/tallgrass/twine_tester/accepted = new(site)
	harvest_assert(accepted.attackby(tool, U) && U.grass_start_messages == 1 && harvest_count(site, /obj/item/stack/grass_cuttings) == 1, "Idle grass action lost its legitimate start or output")
	U.l_hand = null
	qdel(tool)
	qdel(blade)
	qdel(binding)
	harvest_clear(site)
