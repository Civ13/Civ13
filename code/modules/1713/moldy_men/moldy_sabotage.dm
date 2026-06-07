/datum/moldy_sabotage
	var/sabotage_points = 0
	var/max_threshold = 100
	var/ritual_unlocked = FALSE
	var/list/member_ckeys = list()
	var/obj/map_metadata/wizard_boy/owner

/datum/moldy_sabotage/New(var/obj/map_metadata/wizard_boy/W)
	..()
	if (W)
		owner = W

/datum/moldy_sabotage/proc/add_member(ckey)
	member_ckeys |= ckey

/datum/moldy_sabotage/proc/remove_member(ckey)
	member_ckeys -= ckey
	for (var/mob/living/human/H in player_list)
		if (H.client && H.client.ckey == ckey)
			H.hud_list[BASE_FACTION].icon_state = ""
			H.hud_list[FACTION_TO_ENEMIES].icon_state = ""

/datum/moldy_sabotage/proc/award_points(amount, source_name)
	if (amount <= 0)
		return
	sabotage_points += amount
	var/progress = round(100 * sabotage_points / max_threshold)

	for (var/mob/living/human/H in player_list)
		if (H.client && (H.client.ckey in member_ckeys))
			to_chat(H, "<span class='danger'>[source_name] — +[amount] Sabotage Point\s.</span>")
			to_chat(H, "<span class='notice'>Total: [sabotage_points]/[max_threshold] ([progress]% toward Grand Ritual).</span>")

	check_threshold()

/datum/moldy_sabotage/proc/check_threshold()
	if (sabotage_points >= max_threshold && !ritual_unlocked)
		ritual_unlocked = TRUE
		unlock_ritual()

/datum/moldy_sabotage/proc/unlock_ritual()
	for (var/mob/living/human/H in player_list)
		if (H.client && (H.client.ckey in member_ckeys))
			var/obj/item/weapon/moldy_ritual/R = new(H)
			H.put_in_hands(R)
			to_chat(H, "<span class='danger'>The threshold has been reached! The Grand Ritual scroll is now in your possession. Use it to summon Lord Moldywart!</span>")
			H << sound('sound/effects/siren_once.ogg')

/datum/moldy_sabotage/proc/complete_ritual(mob/living/user)
	if (!user || !isturf(user.loc))
		return

	var/turf/T = get_turf(user)
	var/mob/living/simple_animal/hostile/wizard/moldywart/B = new(T)
	B.name = "Lord Moldywart"

	to_chat(world, "<span class='danger'><font size=4>\"Lord Moldywart has been summoned at [get_area(T)]!\"</font></span>")
	world << sound('sound/effects/explosionfar.ogg')

	reveal_all()

/datum/moldy_sabotage/proc/reveal_all()
	for (var/mob/living/human/H in player_list)
		if (H.client && (H.client.ckey in member_ckeys) && H.stat != DEAD)
			H.hud_list[BASE_FACTION].icon_state = "moldymen"
			H.hud_list[BASE_FACTION].icon = 'icons/mob/hud_1713.dmi'
			H.hud_list[FACTION_TO_ENEMIES].icon_state = "moldymen"
			H.hud_list[FACTION_TO_ENEMIES].icon = 'icons/mob/hud_1713.dmi'
