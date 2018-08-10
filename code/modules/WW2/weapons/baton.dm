// the parent for this is in swords_axes_etc.dm

/obj/item/weapon/melee/classic_baton/MP
	name = "police baton"
	desc = ""
	var/weakens = 2

/obj/item/weapon/melee/classic_baton/MP/attack(mob/M as mob, mob/living/user as mob)

	switch (user.a_intent) // harm intent lets us murder people, others not so much - Kachnov
		if (I_HURT)
			force*=2
		if (I_HELP, I_GRAB, I_DISARM)
			force/=2

	var/user_last_intent = user.a_intent
	user.a_intent = I_HURT // so we actually hit people right

	..(M, user)

	M.Weaken(weakens) // decent

	user.a_intent = user_last_intent

	force = initial(force)
