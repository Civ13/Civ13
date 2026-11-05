// Cooldowns and "last time" stamps store a world.time value, and world.time
// starts again at zero after a reboot. If a save restored such a value, it
// would be in the future and a check like "world.time < next_push" or
// "world.time - last_bumped <= 60" could block an action for hours. (A door
// on Gaia stayed shut until the player's last_bumped was cleared by hand.)
//
// The saver writes every changed var on mobs and most objects, including tmp
// vars. Name each world.time stamp here, with the types that own it, so it is
// neither saved nor imported from an older save, and keeps its type default.
// A default of 0 or -1 means "ready" for a cooldown, and "since round start"
// for an age stamp. tests/world_time_stamps fails when a new stamp on a saved
// type appears without an entry here or a reviewed exception there.
var/global/list/persistence_world_time_stamps = list(
	"last_bumped" = list(/atom),
	"next_attack_hand" = list(/obj/structure/simple_door),
	"l_move_time" = list(/atom/movable),
	"last_movement" = list(/mob),
	"lastgib" = list(/mob),
	"next_push" = list(/mob),
	"next_load" = list(/mob),
	"next_cannotmove_message" = list(/mob),
	"next_gracewall_message" = list(/mob),
	"next_language_learn" = list(/mob),
	"next_mud_message" = list(/mob),
	"next_pain_time" = list(/mob),
	"next_snow_message" = list(/mob),
	"next_stamina_message" = list(/mob),
	"timeofdeath" = list(/mob),
	"last_special" = list(/mob/living),
	"next_weather_scan" = list(/mob/living),
	"next_weather_sound" = list(/mob/living),
	"announcement_cooldown" = list(/mob/living/human),
	"soap_cooldown" = list(/mob/living/human),
	"frostbitten" = list(/mob/living/human),
	"next_calculate_run_delay" = list(/mob/living/human),
	"next_calculate_tally" = list(/mob/living/human),
	"next_emote" = list(/mob/living/human),
	"next_look_at" = list(/mob/living/human),
	"last_revive_notification" = list(/mob/observer/ghost),
	"last_fire" = list(/mob/living/simple_animal/hostile/human, /obj/item/weapon/gun/projectile/automatic, /obj/item/weapon/gun/projectile/boltaction, /obj/item/weapon/gun/projectile/custom, /obj/item/weapon/gun/projectile/flintlock, /obj/item/weapon/gun/projectile/semiautomatic, /obj/item/weapon/gun/projectile/special, /obj/item/weapon/gun/projectile/submachinegun),
	"last_retreat" = list(/mob/living/simple_animal/hostile/human),
	"next_bork" = list(/mob/living/simple_animal/complex_animal/dog),
	"next_shred" = list(/mob/living/simple_animal/complex_animal/dog),
	"heat_message_cooldown" = list(/mob/living/simple_animal/npc_vendor/cartel),
	"cooldown_shop" = list(/mob/living/simple_animal/npc_vendor, /mob/living/simple_animal/pepelsibirsk_trader, /mob/living/simple_animal/wizard/big_brenda),
	"biker_cooldown" = list(/mob/living/simple_animal/npc_vendor/biker),
	"heat_cooldown" = list(/mob/living/simple_animal/npc_vendor/fed),
	"intel_cooldown" = list(/mob/living/simple_animal/npc_vendor/fed),
	"smuggler_cooldown" = list(/mob/living/simple_animal/npc_vendor/smuggler),
	"walter_cooldown" = list(/mob/living/simple_animal/npc_vendor/walter),
	"spell_cooldown" = list(/mob/living/simple_animal/wizard, /mob/living/simple_animal/hostile/wizard/moldy_man, /mob/living/simple_animal/hostile/wizard/training_dummy),
	"response_timer" = list(/mob/living/simple_animal/wizard),
	"cleaning_cooldown" = list(/mob/living/simple_animal/wizard/goblin_cleaner),
	"heal_cooldown" = list(/mob/living/simple_animal/wizard/goblin_healer),
	"retaliation_cooldown" = list(/mob/living/simple_animal/wizard/professor_snip, /mob/living/simple_animal/wizard/tumbledoor),
	"submission_cooldown" = list(/mob/living/simple_animal/wizard/professor_snip),
	"cooldown_blockum" = list(/mob/living/simple_animal/hostile/wizard/moldy_man, /mob/living/simple_animal/hostile/wizard/moldywart),
	"retch_cooldown" = list(/mob/living/simple_animal/hostile/wizard/sludge_monster),
	"shriek_cooldown" = list(/mob/living/simple_animal/hostile/wizard/shrieking_shrub),
	"extraction_started" = list(/mob/living/simple_animal/hostile/human/extraction),
	"next_decision" = list(/mob/living/simple_animal/hostile/human/extraction),
	"next_extraction_decision" = list(/mob/living/simple_animal/hostile/human/extraction),
	"next_scavenge" = list(/mob/living/simple_animal/hostile/human/extraction),
	"next_shot" = list(/mob/living/simple_animal/hostile/human/extraction),
	"next_step" = list(/mob/living/simple_animal/hostile/human/extraction),
	"next_city_decision" = list(/mob/living/simple_animal/hostile/human/zombie/extraction_city),
	"next_city_wander" = list(/mob/living/simple_animal/hostile/human/zombie/extraction_city),
	"jammed_until" = list(/obj/item/weapon/gun/projectile/automatic, /obj/item/weapon/gun/projectile/boltaction, /obj/item/weapon/gun/projectile/custom, /obj/item/weapon/gun/projectile/flintlock, /obj/item/weapon/gun/projectile/semiautomatic, /obj/item/weapon/gun/projectile/special, /obj/item/weapon/gun/projectile/submachinegun),
	"recentpump" = list(/obj/item/weapon/gun/launcher/flaregun, /obj/item/weapon/gun/projectile/custom, /obj/item/weapon/gun/projectile/leveraction, /obj/item/weapon/gun/projectile/revolver/derringer, /obj/item/weapon/gun/projectile/shotgun/coachgun, /obj/item/weapon/gun/projectile/shotgun/mts225, /obj/item/weapon/gun/projectile/shotgun/pump),
	"last_shot_time" = list(/obj/item/weapon/gun),
	"next_fire_time" = list(/obj/item/weapon/gun),
	"lock_time" = list(/obj/item/weapon/gun),
	"lastfire" = list(/obj/item/weapon/flamethrower, /obj/item/weapon/reagent_containers/glass/fire_extinguisher),
	"nextCanExplode" = list(/obj/item/mine),
	"next_blood_squirt" = list(/obj/item/organ/heart),
	"external_pump" = list(/obj/item/organ/heart),
	"cooloff" = list(/obj/item/flashlight, /obj/item/weapon/material/sword/magic),
	"cooldown_time" = list(/obj/item/weapon/dead_zone_battery),
	"stand_still_time" = list(/obj/item/clothing/suit/chameleon_mac),
	"fermenting_timer" = list(/obj/item/weapon/starterjar),
	"lastdirchange" = list(/obj/item/vehicleparts/wheel/modular, /obj/structure/vehicleparts/shipwheel),
	"spamtimer" = list(/obj/item/vehicleparts/wheel/rudder_sails, /obj/structure/vehicleparts/shipwheel),
	"cooldown" = list(/obj/item/weapon/tray, /obj/item/weapon/shield, /obj/structure/gatecontrol, /obj/structure/gate/barrier, /obj/structure/gem_lever, /obj/structure/moldymen_lever),
	"cooldown_timer" = list(/obj/structure/gladiator_control),
	"timer" = list(/obj/structure/gladiator_ledger),
	"cooldown_bell_stand" = list(/obj/structure/voyage/shipbell, /obj/structure/bell_stand),
	"debounce" = list(/obj/structure/naval_cannon_control),
	"heated_until" = list(/obj/structure/reaction_bench),
	"last_drain_time" = list(/obj/structure/machinery/sub_control/misc_systems),
	"last_rad_message_time" = list(/obj/structure/machinery/sub_physical/reactor_core),
	"last_slogan" = list(/obj/structure/vending),
	"lastmove" = list(/obj/structure/vehicle),
	"lastmovementloop" = list(/obj/structure/vehicleparts/axis),
	"lastproc" = list(/obj/structure/cell_tower, /obj/structure/phoneline),
	"next_activation" = list(/obj/structure/elevator_button),
	"next_sound" = list(/obj/structure/bed/chair/wheelchair, /obj/structure/bed/roller),
	"stopped_rotation_time" = list(/obj/structure/turret),
	"season_change_started" = list(/obj/map_metadata),
	"season_change_due" = list(/obj/map_metadata),
	"round_started" = list(/obj/map_metadata/train_raid),
	"round_deadline" = list(/obj/map_metadata/train_raid),
	"created" = list(/datum/wound),
	"last_recharge" = list(/obj/structure/survey_console)
)

/proc/persistence_world_time_stamp(datum/D, key)
	var/list/owners = persistence_world_time_stamps[key]
	if (!owners)
		return FALSE
	for (var/owner in owners)
		if (istype(D, owner))
			return TRUE
	return FALSE

/atom/persistence_runtime_var(key)
	return persistence_world_time_stamp(src, key) || ..()

/datum/wound/persistence_runtime_var(key)
	return persistence_world_time_stamp(src, key) || ..()
