// PREPARED ONLY. Actual PR3365 lease code is inherited, never reimplemented here.
// Run pre-roll contracts on the already staged actors, then the two ordinary
// movement-loop legs. Observer camera only; no connected-driver acceptance.
var/list/intro_lease_ticks = list()
var/list/intro_retired_leases = list()
var/list/intro_pre_drive_glide = list()
var/intro_lease_assertions = 0

/proc/intro_lease_check(ok, label)
	intro_check(ok, label)
	intro_lease_assertions++
	text2file(json_encode(list("probe" = "production_lease_v1", "check" = label, "pass" = TRUE, "tick" = world.time)), "intro-checks.txt")

/proc/intro_lease_empty(datum/carriage_glide_lease/L)
	if (!L || L.carriage || L.members.len || (L in GLOB.event_listen_count) || (L in GLOB.global_listen_count))
		return FALSE
	for (var/decl/observ/E in list(GLOB.moved_event, GLOB.destroyed_event))
		for (var/source in E.event_sources)
			var/list/listeners = E.event_sources[source]
			if (L in listeners)
				return FALSE
	return TRUE

/proc/intro_lease_preroll()
	var/obj/structure/vehicle/carriage/C = intro_carriage
	intro_lease_check(!C.carriage_glide && !C.movement_processes && !C.moving, "idle has no lease")
	carriage_glide_contract_probe(C, intro_driver, intro_crate)
	intro_lease_check(!intro_driver.carriage_glide_owner && !intro_crate.carriage_glide_owner, "production handoff and reboard contracts completed")
	var/turf/origin = get_turf(C)
	var/turf/destination = get_step(C, SOUTH)
	// Deletion fixture is disposable, not the original authored crate.
	var/obj/structure/disposable = new(origin)
	var/datum/carriage_glide_lease/L = new
	L.carriage = C
	C.carriage_glide = L
	L.claim(disposable, 21, SOUTH, destination)
	intro_lease_check(disposable.carriage_glide_owner == L, "deletion fixture owns real lease")
	qdel(disposable)
	intro_lease_check(!L.members.len && !(L in GLOB.event_listen_count), "real qdel removes member registrations")
	L.release()
	intro_lease_check(intro_lease_empty(L), "deletion lease fully retired")
	// Causal omission control: suppress only this fixture member's moved listener.
	// Its real forceMove must then FAIL the exact release oracle. No source patch.
	disposable = new(origin)
	L = new
	L.carriage = C
	C.carriage_glide = L
	L.claim(disposable, 21, SOUTH, destination)
	disposable.carriage_glide_step = null
	GLOB.moved_event.unregister(disposable, L, /datum/carriage_glide_lease/proc/moved)
	disposable.forceMove(destination)
	intro_lease_check(disposable.loc == destination && disposable.carriage_glide_owner == L, "omission control detects absent removal listener")
	L.release()
	intro_lease_check(intro_lease_empty(L), "omission control fully cleaned")
	qdel(disposable)
	intro_lease_check(C.x == 8 && C.y == 9 && intro_driver.loc == C.loc && intro_crate.loc == C.loc, "preroll preserves original route and actors")

// Subtype wrapper, not same-path proc layering: call the PR implementation once.
/obj/structure/vehicle/carriage/lease_acceptance/do_move(m_dir, interval)
	intro_lease_check(src == intro_carriage && m_dir == SOUTH && interval == 21, "native captured movement interval")
	intro_lease_check(intro_lease_ticks.len < 2, "exact two native legs")
	if (!intro_lease_ticks.len)
		for (var/atom/movable/A in list(src, intro_driver, intro_horse, intro_crate))
			intro_pre_drive_glide[A] = A.glide_size
	intro_lease_ticks += world.time
	if (intro_retired_leases.len)
		intro_lease_check(intro_lease_empty(intro_retired_leases[intro_retired_leases.len]), "previous leg retired before next step")
	. = ..()
	var/datum/carriage_glide_lease/L = carriage_glide
	intro_lease_check(L && L.carriage == src && L.members.len == 4, "production step owns all four atoms")
	for (var/atom/movable/A in list(src, intro_driver, intro_horse, intro_crate))
		intro_lease_check(A.carriage_glide_owner == L && abs(A.glide_size - 16/21) < 0.00001, "production aligned member glide")
	intro_retired_leases += L

/proc/intro_lease_stopping()
	intro_lease_check(intro_lease_ticks.len == 2 && intro_lease_ticks[2] - intro_lease_ticks[1] == 21, "actual consecutive leg cadence")
	intro_lease_check(!intro_carriage.moving && intro_carriage.movement_processes && intro_carriage.carriage_glide, "stop retains unfinished native leg")

/proc/intro_lease_settled()
	intro_lease_check(!intro_carriage.carriage_glide && !intro_carriage.movement_processes, "scheduled wake retires final stopped leg")
	for (var/datum/carriage_glide_lease/L in intro_retired_leases)
		intro_lease_check(intro_lease_empty(L), "completed leg has no registry references")
	for (var/atom/movable/A in list(intro_carriage, intro_driver, intro_horse, intro_crate))
		intro_lease_check(!A.carriage_glide_owner && !A.carriage_glide_step && (A in intro_pre_drive_glide) && A.glide_size == intro_pre_drive_glide[A], "stopped member restored and unowned")
	text2file(json_encode(list("probe" = "production_lease_v1", "complete" = TRUE, "assertions" = intro_lease_assertions, "legs" = intro_lease_ticks, "source" = "5260b60f0efef2c0af70fae204b1180106ef50b3")), "intro-lease-result.json")
