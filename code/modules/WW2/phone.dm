#define RAID "Order katyusha strike"
#define REQUEST_BATTLE_REPORT "Request Battle Status Report"

var/list/next_raid = list(SOVIET = -1, GERMAN = -1)
var/list/german_traitors = list()
var/list/soviet_traitors = list()

/obj/item/weapon/phone
	name = "red phone"
	desc = "Should anything ever go wrong..."
	icon = 'icons/obj/items.dmi'
	icon_state = "red_phone"
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = TRUE
	throw_range = 4
	w_class = 2
	attack_verb = list("called", "rang")
	hitsound = 'sound/weapons/ring.ogg'

/obj/item/weapon/phone/tohighcommand
	name = "phone"
	desc = "A private line that goes directly to High Command."
	attack_verb = list()
	var/list/options = list(REQUEST_BATTLE_REPORT)
	var/faction = null

/obj/item/weapon/phone/tohighcommand/german
	faction = GERMAN

/obj/item/weapon/phone/tohighcommand/soviet
	faction = SOVIET


// these new values assume an average round length of 70 minutes - Kachnov
/obj/item/weapon/phone/tohighcommand/proc/may_bombard_base_outside()
	return processes.ticker.playtime_elapsed >= 21000 // 35 minutes: about half an average round's length

/obj/item/weapon/phone/tohighcommand/proc/may_bombard_base_inside()
	return processes.ticker.playtime_elapsed >= 31800 // 53 minutes: about 3/4 an average round's length

/obj/item/weapon/phone/tohighcommand/proc/may_bombard_base_message()
	if (may_bombard_base_outside())
		if (may_bombard_base_inside())
			return "Our Katyushas can now hit all parts of the enemy base."
		return "Our Katyushas can now reach the enemy base, but not the inside areas."
	return "Our Katyushas have not reached the front yet. Bombs will only reach inside the town, not the enemy base."

/obj/item/weapon/phone/tohighcommand/attack_hand(var/mob/living/carbon/human/H)

	if (faction)
		var/passcheck = input(H, "Enter the password.") as num
		playsound(get_turf(src), "keyboard", 100, 1)
		if (passcheck != processes.supply.codes[faction])
			H << "<span class = 'warning'>Nothing happens. Perhaps the password was incorrect.</span>"
			return

	if (map && !map.katyushas)
		options -= RAID

	if (istype(H))
		var/dowhat = input(H, "What would you like to do?") in options + "Cancel"
		if (dowhat != "Cancel")
			switch (dowhat)
				if (RAID)
					if (next_raid[faction] != -1 && world.time < next_raid[faction])
						H << "<span class = 'danger'>You can't call in another Katyusha attack yet. You can call in another Katyusha attack in ~[max(round((next_raid[faction]-world.time)/600),0)] minutes.</span>"
						return
					if (map && !map.soviets_can_cross_blocks() && faction == SOVIET)
						H << "<span class = 'warning'>You can't use this yet.</span>"
						return
					if (map && !map.germans_can_cross_blocks() && faction == GERMAN)
						H << "<span class = 'warning'>You can't use this yet.</span>"
						return
					if (!H.original_job || H.original_job.base_type_flag() != faction)
						return

					var/list/targets = (faction == SOVIET ? alive_germans : faction == GERMAN ? alive_russians : list())
					// it takes 5 minutes for soviets to generate 300 points, not counting rewards
					var/cost = (targets.len * 5) + processes.battle_report.current_extra_cost_for_air_raid + 200
					var/yesno = input(H, "A Katyusha attack will cost [cost] supply points right now. You have [processes.supply.points[faction]] supply points. [may_bombard_base_message()]. Would you like to call it in?") in list("Yes", "No")
					if (yesno == "Yes")
						if (processes.supply.points[faction] < cost)
							H << "<span class = 'warning'>You can't afford this right now.</span>"
							return
						// set next_raid[faction] here in case of runtimes that would have stopped it, may fix spam bug - Kachnov
						next_raid[faction] = world.time + rand(1500, 2100)
						processes.supply.points[faction] -= cost
						radio2faction("[faction == GERMAN ? "A Luftwaffe" : "A Katyusha"] attack has been called in by [H.real_name]. Stand by.", faction)
						air_raid(faction, src, cost)

				if (REQUEST_BATTLE_REPORT)
					if (!H.original_job || H.original_job.base_type_flag() != faction)
						return

					battlereport2faction(faction)

/proc/air_raid(faction, var/obj/item/weapon/phone/tohighcommand/caller, var/cost)

	spawn (rand(40,60))

		var/list/raiding = list()
		if (faction == GERMAN)
			raiding += SOVIET
		else if (faction == SOVIET)
			raiding += GERMAN
			raiding += ITALIAN
		else
			raiding += 1 // somehow we got here, bomb everyone ayylmao

		var/list/traitors = list()

		if (faction == GERMAN)
			traitors = german_traitors
		else if (faction == SOVIET)
			traitors = soviet_traitors

		var/list/targets = (raiding.Find(SOVIET) ? alive_russians : raiding.Find(GERMAN) ? alive_germans : player_list)

		var/maximum_targets = max(1, ceil(targets.len/5))
		var/targeted = 0

		var/shuffled_human_mobs = shuffle(human_mob_list)
		var/list/used_areas = list()

		for (var/mob/living/carbon/human/H in shuffled_human_mobs)
			if (H.loc && (H.stat == CONSCIOUS || H.debugmob))
				var/area/H_area = get_area(H)

				// don't use any 'else's here because it breaks multi-level if conditionals
				// before katyushas couldn't hit inside the german base because else ifs - Kachnov

				if (used_areas.Find(H_area))
					continue
				if (istype(H_area, /area/prishtina/admin))
					continue
				if (istype(H_area, /area/prishtina/german))
					if (!caller)
						continue
					if (!caller.may_bombard_base_outside())
						continue
					if (H_area.location == AREA_INSIDE)
						if (!caller.may_bombard_base_inside())
							continue
				if (istype(H_area, /area/prishtina/soviet))
					if (!caller)
						continue
					if (!caller.may_bombard_base_outside())
						continue
					if (H_area.location == AREA_INSIDE)
						if (!caller.may_bombard_base_inside())
							continue
				if (istype(H_area, /area/prishtina/italian_base))
					if (!caller)
						continue
					if (!caller.may_bombard_base_outside())
						continue
					if (H_area.location == AREA_INSIDE)
						if (!caller.may_bombard_base_inside())
							continue
				if (H_area.is_void_area)
					continue

				if ((H.original_job && raiding.Find(H.original_job.base_type_flag())) || raiding.Find(TRUE) || (traitors.Find(H.real_name) && H_area.location == AREA_OUTSIDE))
					if (targeted < maximum_targets)

						++targeted

						var/H_x = H.x
						var/H_y = H.y
						var/H_z = H.z

						var/turf/target = locate(H_x, H_y, H_z)
						var/area/target_area = get_area(target)

						used_areas += target_area

						playsound(target, "artillery_in_distant", 100, TRUE, 100)
						target.visible_message("<span class = 'userdanger'>You see a barrage of rockets in the sky!</span>")
						playsound(target, "artillery_in", 100, TRUE)

						// 6 bombs in a 3x3 radius means you will almost always be hit if you don't run
						for (var/v in 1 to 6)
							var/spawndelay = 40
							switch (v)
								if (1)
									spawndelay = 40
								if (2)
									spawndelay = 45
								if (3)
									spawndelay = 50
								if (4)
									spawndelay = 55
								if (5)
									spawndelay = 60
								if (6)
									spawndelay = 65
							spawn (spawndelay)

								var/target_x = H_x + rand(-3,3)
								var/target_y = H_y + rand(-3,3)
								var/target_z = H_z

								target = locate(target_x, target_y, target_z)

								// two strikes to take down a ceiling, faster than artillery
								// no more partial chances however - Kachnov
								if (target_area.artillery_integrity)
									target_area.artillery_integrity -= 50

								if (target_area.artillery_integrity <= 0 && (!target_area.parent_area || target_area.parent_area.artillery_integrity <= 0))
									explosion(target, 1, 3, 4, 5)
								else
									target.visible_message("<span class = 'userdanger'>The rocket smashes into the ceiling!</span>")
									playsound(target, "explosion", 100, TRUE, 100)
					else
						break
		if (!targeted)
			processes.supply.points[faction] += cost
			radio2faction("Due to a lack of targets, the Katyusha strike was cancelled and refunded.", faction)
			next_raid[faction] = -1