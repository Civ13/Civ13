// Native probe for bite_target_zone(). Organs are a fake boundary: the probe
// subtype answers get_organ() from a list, so no full human startup is needed.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/bite/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/bite_probe
	var/list/probe_organs = list("chest", "groin", "head", "l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg", "l_foot", "r_foot")
/mob/living/human/bite_probe/New()
	return
/mob/living/human/bite_probe/update_icons()
	return
/mob/living/human/bite_probe/get_organ(var/zone)
	return (zone in probe_organs) ? zone : null
var/bite_failures = 0
var/bite_runtime_error = FALSE
/proc/bite_check(condition, label)
	if (!condition)
		bite_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bite_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		bite_zone_checks()
	catch(var/exception/e)
		bite_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bite_failures, "runtime_error" = bite_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/bite_zones(mob/living/human/bite_probe/target, mob/living/human/bite_probe/user, aim)
	user.targeted_organ = aim
	var/list/seen = list()
	for (var/i = 1, i <= 60, i++)
		seen |= target.bite_target_zone(user)
	return seen

/proc/bite_same(list/a, list/b)
	return a.len == b.len && !length(a - b)

/proc/bite_zone_checks()
	var/mob/living/human/bite_probe/user = new(locate(1, 1, 1))
	var/mob/living/human/bite_probe/target = new(locate(2, 1, 1))
	var/list/arms = list("l_arm", "r_arm", "l_hand", "r_hand")
	// The default chest aim used to refuse with "too far away".
	bite_check(bite_same(bite_zones(target, user, "chest"), arms), "default chest aim bites an arm or hand")
	bite_check(bite_same(bite_zones(target, user, "head"), arms), "head aim bites an arm or hand")
	bite_check(bite_same(bite_zones(target, user, "random"), arms), "random aim bites an arm or hand")
	for (var/limb in arms)
		bite_check(bite_same(bite_zones(target, user, limb), list(limb)), "aimed [limb] is bitten as aimed")
	bite_check(bite_same(bite_zones(target, user, "l_leg"), list("l_hand", "l_arm")), "left leg aim bites the left arm or hand")
	bite_check(bite_same(bite_zones(target, user, "r_foot"), list("r_hand", "r_arm")), "right foot aim bites the right arm or hand")
	target.probe_organs = list("chest", "groin", "head", "r_arm", "r_hand", "l_leg", "r_leg")
	bite_check(bite_same(bite_zones(target, user, "l_leg"), list("r_arm", "r_hand")), "missing left arm falls back to the other side")
	bite_check(bite_same(bite_zones(target, user, "chest"), list("r_arm", "r_hand")), "missing limbs are never picked")
	target.probe_organs = list("chest", "groin", "head", "l_leg", "r_leg")
	bite_check(bite_zones(target, user, "chest") ~= list(null), "no arms or hands left refuses the bite")
	target.probe_organs = list("chest", "groin", "head", "l_arm", "r_arm", "l_hand", "r_hand")
	user.werewolf = TRUE
	bite_check(bite_same(bite_zones(target, user, "head"), list("head")), "werewolves bite where they aim")
