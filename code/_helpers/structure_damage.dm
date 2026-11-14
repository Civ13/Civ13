// Structure damage in one place: a structure loses `health` and breaks at 0.
//
// A structure that can be broken sets `health` (and `maxhealth` when it can be
// repaired). Damage goes through take_structure_damage() or
// weapon_structure_damage(); both end in try_destroy(), which breaks the
// structure once health reaches 0. A type says how it breaks by overriding:
// - break_message(): what onlookers see (null for no message).
// - on_break(): what happens just before it is deleted (drop loot, explode,
//   tell admins, release what it held).
// Types with their own breaking (vehicle frames, drones, covers) override
// try_destroy() itself.
//
// A structure without health (null) never breaks here: `null <= 0` is true in
// DM, so try_destroy() checks for it first.

/obj/structure
	var/health = null
	var/maxhealth = null

// Take amount of damage. Returns TRUE when the structure broke.
/obj/structure/proc/take_structure_damage(amount)
	if (isnull(health))
		return FALSE
	health -= amount
	return try_destroy()

// Take a weapon blow: fire damage times fire_mult, brute times brute_mult.
// Plays the hit sound and the attack animation. Returns TRUE when it broke.
/obj/structure/proc/weapon_structure_damage(obj/item/W, mob/user, fire_mult = 1, brute_mult = 1, hit_sound = 'sound/weapons/smash.ogg')
	if (!W)
		return FALSE
	if (user)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	var/amount = 0
	switch (W.damtype)
		if ("fire")
			amount = W.force * fire_mult
		if ("brute")
			amount = W.force * brute_mult
	if (hit_sound)
		playsound(get_turf(src), hit_sound, 100)
	if (user)
		user.do_attack_animation(src)
	return take_structure_damage(amount)

// Break the structure if it is worn out. Returns TRUE when it broke.
/obj/structure/proc/try_destroy()
	if (isnull(health) || health > 0)
		return FALSE
	var/message = break_message()
	if (message)
		visible_message(SPAN_DANGER(message))
	on_break()
	qdel(src)
	return TRUE

/obj/structure/proc/break_message()
	return "\The [src] is broken into pieces!"

/obj/structure/proc/on_break()
	return

// Tell admins, with a jump link, that a map objective was destroyed.
/obj/structure/proc/admin_destroyed_notice(label)
	message_admins("[label] at ([x], [y], [z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>) has been destroyed.")
