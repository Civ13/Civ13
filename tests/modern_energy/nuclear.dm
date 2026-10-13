// Injury adapter counts production local-effect calls without requiring human Life.
/mob/living/human/energy_ci
	var/heat_hits = 0
	New()
		return
	take_overall_damage(brute, burn, used_weapon)
		heat_hits += burn
/area/energy_interior
	location = AREA_INSIDE
/proc/run_nuclear_energy_checks()
	var/radiation_before = global_radiation
	var/obj/structure/civ_generator/nuclear/N = new(locate(2,2,1))
	var/obj/structure/cable/C = new(N.loc)
	N.powersource = C
	C.connections |= N
	var/obj/item/stack/reactor_fuel/F = new(N.loc,2)
	N.attackby(F,null)
	energy_ci_check("one finite cartridge consumed", F.amount, 1)
	energy_ci_check("finite fuel credit", N.fuel_energy, 1800)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(N.loc)
	B.reagents.add_reagent("water",20)
	N.attackby(B,null)
	energy_ci_check("coolant transferred", N.coolant, 20)
	energy_ci_check("coolant actually consumed", B.reagents.get_reagent_amount("water"), 0)
	N.enabled = TRUE
	N.settle_generation()
	energy_ci_check("controlled output", N.available_output(), 20)
	energy_ci_check("fuel prepaid", N.fuel_energy, 1780)
	energy_ci_check("coolant finite", N.coolant, 19)
	N.settle_generation()
	energy_ci_check("same interval nuclear not replayed", N.fuel_energy, 1780)
	N.output_epoch = -999
	N.settle_generation()
	energy_ci_check("scheduler lag consumes single interval", N.fuel_energy, 1760)
	N.wear = 120
	N.output_epoch = -1
	N.settle_generation()
	energy_ci_check("maintenance stop", N.enabled, FALSE)
	energy_ci_check("maintenance stop has no output", N.available_output(), 0)
	var/obj/item/stack/material/steel/S = new(N.loc,2,FALSE)
	N.attackby(S,null)
	energy_ci_check("maintenance material consumed", S.amount, 1)
	energy_ci_check("bounded maintenance", N.wear, 90)
	N.coolant = 0
	N.enabled = TRUE
	N.output_epoch = -1
	N.settle_generation()
	energy_ci_check("no coolant shutdown", N.enabled, FALSE)
	energy_ci_check("no coolant no fuel burn", N.fuel_energy, 1760)
	var/list/nearby = list()
	for (var/i = 1, i <= 9, i++)
		nearby += new /mob/living/human/energy_ci(N.loc)
	var/mob/living/human/energy_ci/far = new(locate(4,4,1))
	var/mob/living/human/energy_ci/other_z = new(locate(2,2,2))
	var/turf/inside = locate(3,2,1)
	ChangeArea(inside, new /area/energy_interior)
	var/mob/living/human/energy_ci/interior = new(inside)
	energy_ci_check("distant heat target rejected", N.local_heat_target(far), FALSE)
	energy_ci_check("other z heat target rejected", N.local_heat_target(other_z), FALSE)
	energy_ci_check("different interior heat target rejected", N.local_heat_target(interior), FALSE)
	N.heat = 90
	N.output_epoch = -1
	N.settle_generation()
	var/hits = 0
	for (var/mob/living/human/energy_ci/H in nearby)
		hits += H.heat_hits
	energy_ci_check("bounded eight local effects", hits, 16)
	energy_ci_check("safe-distance unharmed", far.heat_hits, 0)
	energy_ci_check("other z unharmed", other_z.heat_hits, 0)
	energy_ci_check("other interior unharmed", interior.heat_hits, 0)
	N.settle_generation()
	var/repeated = 0
	for (var/mob/living/human/energy_ci/H in nearby)
		repeated += H.heat_hits
	energy_ci_check("same-interval hazard not replayed", repeated, 16)
	energy_ci_check("reactor never changes global radiation", global_radiation, radiation_before)
	N.after_load()
	energy_ci_check("reactor reload off", N.enabled, FALSE)
	energy_ci_check("reactor fuel retained", N.fuel_energy, 1760)
	var/savefile/save = new("reactor-state.sav")
	save["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(save,N,1)
	energy_ci_check("reactor native export", !!ref, TRUE)
	map_storage.clear_bookkeeping()
	var/obj/structure/civ_generator/nuclear/restored = map_storage.Load_Entry(save,ref,null,locate(1,3,1))
	energy_ci_check("reactor native import", !!restored, TRUE)
	if (restored)
		energy_ci_check("durable native fuel", restored.fuel_energy, N.fuel_energy)
		energy_ci_check("durable native coolant", restored.coolant, N.coolant)
		energy_ci_check("durable native wear", restored.wear, N.wear)
		energy_ci_check("restored reactor output off", restored.available_output(), 0)
		restored.retire_generator()
	N.retire_generator()
