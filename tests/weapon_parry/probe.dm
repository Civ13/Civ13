var/failures = 0
var/scenarios = 0
var/parry_allowed = 1
/proc/playsound(atom/A, sound, volume, flag)
	return
/proc/default_parry_check(mob/user, mob/attacker, atom/source)
	return parry_allowed
/proc/get_edge_target_turf(atom/A, direction)
	return A.loc
/mob
	var/tactic
	var/obj/item/active
	proc/get_active_hand()
		return active
	proc/visible_message(message)
		return
	proc/drop_from_inventory(obj/item/I)
		return
/mob/living/human
	proc/religion_check()
		return ""
	proc/getStatCoeff(stat)
		return 1
	proc/adaptStat(stat, amount)
		return
/obj/item
	var/health = 20
	var/maxhealth = 20
	var/broken = 0
	var/block_chance = 100
	var/throw_speed = 1
	proc/throw_at(atom/target, distance, speed)
		return
/obj/item/weapon/material
	proc/handle_shield(mob/user, damage, atom/damage_source, mob/attacker, def_zone, attack_text)
		return 0
	proc/shatter(consumed)
		broken++
/obj/item/weapon/sledgehammer
/obj/item/weapon/melee
/obj/item/weapon/material/hatchet
/obj/item/weapon/material/twohanded
	var/wielded = 1
/world
	New()
		..()
		OpenPort("none")
		var/mob/living/human/H = new
		var/list/types = list(/obj/item/weapon/material/sword, /obj/item/weapon/material/twohanded)
		var/list/sources = list(/obj/item/weapon/sledgehammer, /obj/item/weapon/melee, /obj/item/weapon/material/hatchet, /obj/item)
		for(var/type in types)
			for(var/source_type in sources)
				var/obj/item/weapon/material/W = new type
				var/obj/item/source = new source_type
				H.active = W
				var/loss = (source_type == /obj/item) ? 0.5 : 5
				if(type == /obj/item/weapon/material/sword && source_type == /obj/item/weapon/sledgehammer)
					loss = 10
				if(type == /obj/item/weapon/material/twohanded && source_type == /obj/item/weapon/sledgehammer)
					loss = 0.5
				for(var/start in list(loss, loss-0.25, loss+1))
					W.health = start
					W.broken = 0
					var/success = 0
					for(var/attempt = 1, attempt <= 300, attempt++)
						if(W.handle_shield(H, 10, source))
							success = 1
							break
						sleep(-1)
					scenarios++
					if(!success || W.health != start-loss || W.broken != (start<=loss))
						failures++
				parry_allowed = 0
				W.health = 20
				W.broken = 0
				scenarios++
				if(W.handle_shield(H, 10, source) || W.health != 20 || W.broken)
					failures++
				parry_allowed = 1
		fdel("result.json")
		text2file(json_encode(list("failures"=failures,"scenarios"=scenarios)), "result.json")
		shutdown()
