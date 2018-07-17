//ARTILLERY

#define kanonier_msg " A Kanonier can now fire within <b>15 square meters</b> of this position."

var/global/list/valid_coordinates = list()
/mob/living/carbon/human/var/checking_coords[4]
/mob/living/carbon/human/var/can_check_distant_coordinates = FALSE

/mob/living/carbon/human/proc/make_artillery_officer()
	verbs += /mob/living/carbon/human/proc/Check_Coordinates
	verbs += /mob/living/carbon/human/proc/Reset_Coordinates
	can_check_distant_coordinates = TRUE

/mob/living/carbon/human/proc/make_artillery_scout()
	verbs += /mob/living/carbon/human/proc/Check_Coordinates_Chump
	verbs += /mob/living/carbon/human/proc/Reset_Coordinates_Chump
	can_check_distant_coordinates = TRUE

///mob/living/carbon/human/proc/make_senior_mp()
//	verbs += /mob/living/carbon/human/proc/add_to_penal
//	verbs += /mob/living/carbon/human/proc/remove_from_penal


// all officer jobs not listed in one of these lists are considered tier 3 officers
// ie kanoniers, squad leaders, quartermasters, MPs

var/list/tier_1_officer_jobtypes = list(
	/datum/job/german/commander,
	/datum/job/soviet/commander,
	/datum/job/german/XO,
	/datum/job/soviet/XO)

var/list/tier_2_officer_jobtypes = list(
	/datum/job/german/staff_officer,
	/datum/job/soviet/staff_officer)

// if this returns 1, j1's rank > j2's rank
// if this returns 0, its not. Its not necessary less important either.
/proc/rankcmp(var/datum/job/j1, var/datum/job/j2)

	// non-SS may not execute SS and vice versa. Different chain of command.
	if (j1.is_SS != j2.is_SS)
		return 0

	// different factions
	if (j1.base_type_flag() != j2.base_type_flag())
		return 0

	if (j1.is_commander && !j2.is_commander)
		return 1

	if (j1.is_officer && !j2.is_officer)
		return 1

	if (j1.is_officer && j2.is_officer)
		if (tier_1_officer_jobtypes.Find(j1.type))
			if (!tier_1_officer_jobtypes.Find(j2.type))
				return 1
		else if (tier_2_officer_jobtypes.Find(j1.type))
			if (!tier_1_officer_jobtypes.Find(j2.type) && !tier_2_officer_jobtypes.Find(j2.type))
				return 1

	return 0

/mob/living/carbon/human/var/next_execute = -1
/mob/living/carbon/human/proc/Execute()
	set category = "Officer"

	var/obj/item/weapon/gun/projectile/G = null

	if (istype(l_hand, /obj/item/weapon/gun/projectile) && !istype(l_hand, /obj/item/weapon/gun/projectile/pistol/luger/flaregun))
		G = l_hand
	else if (istype(r_hand, /obj/item/weapon/gun/projectile) && !istype(r_hand, /obj/item/weapon/gun/projectile/pistol/luger/flaregun))
		G = r_hand

	if (!G)
		return

	var/turf/T = get_turf(src)
	var/steps = 0

	while (TRUE)
		T = get_step(T, dir)
		++steps
		if (steps >= 7 || T.density || locate_bullet_blocking_structure(T) || locate_type(T.contents, /mob/living/carbon/human))
			break

	for (var/mob/living/carbon/human/H in T)
		if (H != src && H.stat != DEAD && original_job && H.original_job)
			var/enemy = (original_job.base_type_flag() != H.original_job.base_type_flag())
			if (enemy)
				visible_message("<span class = 'danger'>[src] lifts their gun, preparing to execute [H]...</span>")
			else
				if (next_execute > world.realtime)
					src << "<span class = 'warning'>You can't execute anybody for a while.</span>"
					return

			if (rankcmp(original_job, H.original_job) || (enemy && do_after(src, 50, H)))

				var/obj/item/projectile/in_chamber = G.consume_next_projectile()
				if (!in_chamber || !istype(in_chamber))
					return

				var/datum/gender/GD = gender_datums[gender]
				var/old_targeted_organ = targeted_organ
				targeted_organ = "head"
				visible_message("<span class = 'userdanger'>[src] lifts [GD.his] [G] and executes [H].</span>")

				attack_log += text("\[[time_stamp()]\] <font color='red'>Officer-executed [H] ([H.key])</font>")
				H.attack_log += text("\[[time_stamp()]\] <font color='orange'>Was officer-executed by [src] ([key])</font>")
				msg_admin_attack("[name] ([ckey]) has officer executed [H] ([H.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>)")

				G.executing = TRUE
				G.Fire(H, src, forceburst = 1)
				G.executing = FALSE
				targeted_organ = old_targeted_organ
				if (!enemy)
					next_execute = world.realtime + 600
				break

/proc/check_coords_check()
	return (!map || (map.germans_can_cross_blocks() && map.soviets_can_cross_blocks()))

/mob/living/carbon/human/proc/Check_Coordinates()
	set category = "Officer"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		checking_coords[3] = x
		checking_coords[4] = y
		valid_coordinates["[x],[y]"] = TRUE
		var/dist = "[checking_coords[3] - checking_coords[1]],[checking_coords[4] - checking_coords[2]]"
		usr << "<span class = 'notice'>You finished tracking coordinates at <b>[x],[y]</b>. You moved an offset of <b>[dist]</b>.[kanonier_msg]</span>"
		checking_coords[3] = null
		checking_coords[4] = null // continue to track from the same starting location
	else
		checking_coords[1] = x
		checking_coords[2] = y
		usr << "<span class = 'notice'>You've started checking coordinates at <b>[x], [y]</b>.</span>"

/mob/living/carbon/human/proc/Reset_Coordinates()
	set category = "Officer"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		var/x = checking_coords[1]
		var/y = checking_coords[2]
		checking_coords[1] = null
		checking_coords[2] = null
		usr << "<span class = 'notice'>You are no longer tracking from <b>[x],[y]</b>.</span>"
		checking_coords[3] = null
		checking_coords[4] = null

// the only thing different about these verbs is the category

/mob/living/carbon/human/proc/Check_Coordinates_Chump()
	set category = "Scout"
	set name = "Check Coordinates"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		checking_coords[3] = x
		checking_coords[4] = y
		valid_coordinates["[x],[y]"] = TRUE
		var/dist = "[checking_coords[3] - checking_coords[1]],[checking_coords[4] - checking_coords[2]]"
		usr << "<span class = 'notice'>You finished tracking coordinates at <b>[x],[y]</b>. You moved an offset of <b>[dist]</b>.[kanonier_msg]</span>"
		checking_coords[3] = null
		checking_coords[4] = null // continue to track from the same starting location
	else
		checking_coords[1] = x
		checking_coords[2] = y
		usr << "<span class = 'notice'>You've started checking coordinates at <b>[x],[y]</b>.</span>"

/mob/living/carbon/human/proc/Reset_Coordinates_Chump()
	set category = "Scout"
	set name = "Reset Coordinates"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		var/x = checking_coords[1]
		var/y = checking_coords[2]
		checking_coords[1] = null
		checking_coords[2] = null
		usr << "<span class = 'warning'>You are no longer tracking from <b>[x],[y]</b>.</span>"
		checking_coords[3] = null
		checking_coords[4] = null

// artyman/officer/scout getting coordinates
/mob/living/carbon/human/RangedAttack(var/turf/t)
	if (checking_coords[1] && istype(t))
		if (can_check_distant_coordinates && get_turf(src) != t)
			var/offset_x = t.x - x
			var/offset_y = t.y - y
			src << "<span class = 'notice'>This turf has an offset of <b>[offset_x],[offset_y]</b> and coordinates of <b>[t.x],[t.y]</b>.[kanonier_msg]</span>"
			valid_coordinates["[t.x],[t.y]"] = TRUE
	else
		return ..()

//OTHER

//WIP - I need sounds - Kachnov
/mob/living/carbon/human/proc/officer_command_attack()
	var/job_type = null
	if (istype(mind.assigned_job, /datum/job/soviet))
		job_type = /datum/job/soviet
	else if (istype(mind.assigned_job, /datum/job/german))
		job_type = /datum/job/german
	if (!job_type)
		return
	for (var/mob/m in range(10, src))
		if (m.client && ishuman(m))
			var/mob/living/carbon/human/H = m
			if (istype(H.mind.assigned_job, job_type))
				return

///////////////////////////////NKVD/FJK//////////////////////////
///mob/living/carbon/human/proc/add_to_penal()
//	set name = "Send to Penal Battalion"
//	set category = "Officer"
//	var/_ckey = input("What ckey?") as text
//	_ckey = sanitizeSQL(_ckey, max_length = 50)
//	if (!_ckey)
//		return

///mob/living/carbon/human/proc/remove_from_penal()
//	set name = "Remove From Penal Battalion"
//	set category = "Officer"
//	var/_ckey = input("What ckey?") as text
//	_ckey = sanitizeSQL(_ckey, max_length = 50)
//	if (!_ckey)
//		return