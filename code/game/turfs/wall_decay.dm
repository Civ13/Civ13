/obj/covers
	var/moldy = 0
	var/cracked = 0

/obj/covers/proc/decay()
	if (!src)
		return
	if (!wall)
		return

	health-=rand(0.8,1.1)

	if (health<=0)
		visible_message("\The [name] falls apart!")
		Destroy()
		return
	if (prob(7))
		if (prob(50))
			moldy = min(moldy+1,3)
		else
			cracked = min(moldy+1,3)
		update_icon()

/obj/covers/proc/repair(var/obj/item/I, var/mob/user)
	if (!istype(I, buildstack))
		user << "This is the wrong material for this wall!"
		return
	var/amt = (health/maxhealth)*buildstackamount
	do_repair(user, I, amt)

/obj/covers/proc/do_repair(var/mob/user,var/obj/item/I, var/amt=0)
	if (amt == 0)
		return
	user << "Repairing \the [src]..."
	if (do_after(user,40,src))
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			if (S.amount >= amt)
				S.amount -= amt
				src.health = src.maxhealth
				user << "The wall is fully repaired."
				moldy = 0
				cracked = 0
				if (I.amount <= 0)
					qdel(I)
			else
				src.health += (S.amount/buildstackamount)*src.maxhealth
				qdel(I)
				user << "The wall is repaired."
				moldy = max(0,moldy-=1)
				cracked = max(0, cracked-=1)
		else
			src.health += (1/buildstackamount)*src.maxhealth
			qdel(I)
			user << "The wall is repaired."
			moldy = max(0,moldy-=1)
			cracked = max(0, cracked-=1)
		return
	return
/obj/covers/examine(mob/user)
	..()
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.getStatCoeff("crafting") > 1.8)
			H << get_wall_condition()

/obj/covers/proc/get_wall_condition()
	var/healthp = (health/maxhealth)*100
	switch (healthp)
		if (-100 to 21)
			return "<font color='#7f0000'>Is pratically falling apart!</font>"
		if (22 to 49)
			return "<font color='#a74510'>Seems to be in very bad condition.</font>"
		if (50 to 69)
			return "<font color='#cccc00'>Seems to be in a rough condition.</font>"
		if (70 to 84)
			return "<font color='#4d5319'>Seems to be in a somewhat decent condition.</font>"
		if (85 to 200)
			return "<font color='#245319'>Seems to be in very good condition.</font>"
	return ""