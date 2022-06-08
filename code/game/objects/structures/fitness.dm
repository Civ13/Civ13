/obj/structure/fitness
	icon = 'icons/obj/objects.dmi'
	anchored = 1
	var/being_used = 0

/obj/structure/fitness/punchingbag
	name = "punching bag"
	desc = "A punching bag."
	icon_state = "pbag"
	color = "#801a08"
	density = 1
	var/list/hit_message = list("hit", "punch", "left hook", "right hook")

/obj/structure/fitness/punchingbag/attack_hand(var/mob/living/human/H)
	if(!istype(H))
		..()
		return
	if(H.nutrition < 20)
		to_chat(H, "<span class='warning'>You need more energy to use the punching bag. Go eat something.</span>")
	else
		if(H.a_intent == I_HARM)
			H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			flick("[icon_state]_hit", src)
			playsound(src.loc, 'sound/effects/woodhit.ogg', 25, 1, -1)
			H.do_attack_animation(src)
			H.nutrition -= (5 * DEFAULT_HUNGER_FACTOR)
			H.water -= (5 * 0.05)
			if (prob(80))
				if (prob(50))
					H.adaptStat("strength", 1)
				else
					H.adaptStat("dexterity", 1)
			to_chat(H, "<span class='warning'>You [pick(hit_message)] \the [src].</span>")

/obj/structure/fitness/weightlifter
	name = "weightlifting machine"
	desc = "A machine used to lift weights."
	icon_state = "weightlifter"
	var/weight = 1
	var/list/qualifiers = list("with ease", "without any trouble", "with great effort")

/obj/structure/fitness/weightlifter/attackby(obj/item/weapon/W as obj, mob/H as mob)
	if(istype(W, /obj/item/weapon/wrench))
		playsound(src.loc, 'sound/items/Deconstruct.ogg', 75, 1)
		weight = ((weight) % qualifiers.len) + 1
		to_chat(H, "You set the machine's weight level to [weight].")

/obj/structure/fitness/weightlifter/attack_hand(var/mob/living/human/H)
	if(!istype(H))
		return
	if(H.loc != src.loc)
		to_chat(H, "<span class='warning'>You must be on the weight machine to use it.</span>")
		return
	if(H.nutrition < 50)
		to_chat(H, "<span class='warning'>You need more energy to lift weights. Go eat something.</span>")
		return
	if(H.water < 50)
		to_chat(H, "<span class='warning'>You're getting dehydrated. Go drink something.</span>")
		return
	if(being_used)
		to_chat(H, "<span class='warning'>The weight machine is already in use by somebody else.</span>")
		return
	else
		being_used = 1
		playsound(src.loc, 'sound/effects/weightlifter.ogg', 50, 1)
		H.set_dir(SOUTH)
		flick("[icon_state]_[weight]", src)
		if(do_after(H, 20 + (weight * 10)))
			playsound(src.loc, 'sound/effects/weightdown.ogg', 25, 1)
			H.nutrition -= (weight * DEFAULT_HUNGER_FACTOR)
			H.water -= (weight * 0.05)
			to_chat(H, "<span class='notice'>You lift the weights [qualifiers[weight]].</span>")
			if (prob(60))
				H.adaptStat("strength", 1)
			being_used = 0
		else
			to_chat(H, "<span class='notice'>Against your previous judgement, perhaps working out is not for you.</span>")
			being_used = 0