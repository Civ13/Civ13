/////////////////Roulette//////////////////

/obj/item/weapon/roulette/chip
	name = "black roulette chip"
	icon = 'icons/obj/items.dmi'
	icon_state = "chip_black"
	var/chip_color = "black"
	var/chip_worth = 100

/obj/item/weapon/roulette/chip/red
	name = "red roulette chip"
	icon_state = "chip_red"
	chip_color = "red"
	chip_worth = 5

/obj/item/weapon/roulette/chip/examine(mob/user, distance)
	. = ..()
	user << "Has a value of <b>[chip_worth]</b>."

/obj/structure/roulette
	name = "roulette table"
	desc = "A large green table that has a spinner on it. If you pick a number and it lands on that, you will win chips. Or something."
	icon = 'icons/obj/decals_wide.dmi'
	icon_state = "roulette"
	density = 1
	anchored = 1
	bound_width = 64
	var/highest_number = 36
	var/win_number
	var/win_color
	var/win_3rd
	var/win_half
	var/win_odd_even
	var/spinning = 0
	var/can_bet = 1
	var/win
	var/list/current_bets = list()

/obj/structure/roulette/examine(mob/user, distance)
	. = ..()
	if(win_number && !can_bet)
		user << "The last number was <b>[win_number]</b>."
	if(spinning)
		user << "<b>The roulette is spinning!</b>"
	for(var/list/L in current_bets)
		user << "<b>[L[1]]</b> has placed a <b>[L[3]]</b> bet on <b>[L[2]]</b>."
/obj/structure/roulette/initialize()
	reset_wheel()
	..()

/obj/structure/roulette/proc/reset_wheel()
	spinning = 0

/obj/structure/roulette/proc/process_wins()
	can_bet = FALSE
	var/list/newlist = list()
	for(var/list/L in current_bets)
		if(win_color == L[2] || win_half == L[2] || win_3rd == L[2] || win_odd_even == L[2] || win_color == L[2])
			L[3] = L[3]*2
			L[2] = "won"
			newlist.Add(L)
		else if(win_3rd == L[2])
			L[3] = L[3]*3
			L[2] = "won"
			newlist.Add(L)
		else if(num2text(win_number) == L[2])
			L[3] = L[3]*36
			L[2] = "won"
			newlist.Add(L)
		else
			L[2] = "lost"
	current_bets = newlist
	if (!current_bets.len)
		can_bet = TRUE

/obj/structure/roulette/proc/do_outcome()
	spinning = 0
	win_color = "green"
	win_number = rand(0, highest_number)
	if (win_number == 0)
		win_color = "green"
		win_odd_even = null
		win_3rd = null
		win_half = null
	else if ((win_number % 2) == 0)
		win_color = "red"
		win_odd_even = "even"
	else
		win_color = "black"
		win_odd_even = "odd"
	if(win_number >= 1 && win_number <= 18)
		win_half = "1 to 18"
	else if(win_number >= 19 && win_number <= 36)
		win_half = "19 to 36"
	else
		win_half = null
	if(win_number >= 1 && win_number <= 12)
		win_3rd = "1st 12"
	else if(win_number >= 13 && win_number <= 24)
		win_3rd = "2nd 12"
	else if(win_number >= 25 && win_number <= 36)
		win_3rd = "3rd 12"
	else
		win_3rd = null
	src.visible_message("\The [src]'s ball clatters to a halt on the <font color=[win_color]><span><b>[win_color] [win_number]</b></span></font>.","You hear a rattling that slowly comes to a stop.")
	src.visible_message("<big><b>Please collect your winnings!</b></big>")

	process_wins()
/obj/structure/roulette/update_icon()
	if(spinning)
		icon_state = "[initial(icon_state)]_spin"
	else
		icon_state = initial(icon_state)

/obj/structure/roulette/attack_hand(mob/living/human/H)
	var/list/newlist = list()
	for(var/list/L in current_bets)
		if(L[1] == H && L[2] == "won")
			H << "You remove your bet from the table."
			var/obj/item/weapon/roulette/chip/newchips = new/obj/item/weapon/roulette/chip(loc)
			newchips.value = L[3]
			H.put_in_any_hand_if_possible(newchips,FALSE,TRUE,TRUE,TRUE)
		else
			newlist.Add(L)
	current_bets = newlist
	if (!current_bets.len)
		can_bet = TRUE

/obj/structure/roulette/attackby(obj/item/I,mob/living/human/user)
	if(spinning)
		to_chat(user, "The [src] is still spinning!")
		return
	if(!can_bet)
		to_chat(user, "Remove the previous bets first!")
		return
	if(istype(I, /obj/item/weapon/roulette/chip))
		var/obj/item/weapon/roulette/chip/CHIP = I
		var/betchoice = null
		var/choice = WWinput(user, "Where do you want to place your bet?", "Roulette", "Cancel",list("Cancel","Select Number","Zero","Red","Black",/*"Even","Odd",*/"1 to 18","19 to 36","1st 12","2nd 12","3rd 12"))
		switch(choice)
			if("Cancel")
				return
			if("Select Number")
				var/nr_choice = WWinput(user, "Which number? 1 to 36", "Roulette", "Cancel",list("Cancel","1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","23","24","25","26","27","28","29","30","31","32","33","34","35","36"))
				betchoice = nr_choice
			if("Zero")
				betchoice = "0"
			if("Red")
				betchoice = "red"
			if("Black")
				betchoice = "black"
			if("Even")
				betchoice = "even"
			if("Odd")
				betchoice = "odd"
			if("1 to 18")
				betchoice = "1 to 18"
			if("19 to 36")
				betchoice = "19 to 36"
			if("1st 12")
				betchoice = "1st 12"
			if("2nd 12")
				betchoice = "2nd 12"
			if("3rd 12")
				betchoice = "3rd 12"
		if (betchoice)
			if (I)
				visible_message("<big>[user] has placed a bet of <b>[CHIP.chip_worth]</b> on <b>[betchoice]</b>!</big>")
				current_bets += list(list(user,betchoice,CHIP.chip_worth))
				qdel(I)

/obj/structure/roulette/verb/spin(mob/user as mob)
	set name = "Spin Roulette Table"
	set category = null
	set src in oview(1)

	if (spinning)
		to_chat(user,"The [src] is already spinning!")
		return
	else if (!can_bet)
		to_chat(user, "You need to clear the table first!")
		return
	else
		playsound(src, 'sound/effects/roulettespin.ogg', 50, 1)
		spinning = 1
		can_bet = FALSE
		update_icon()
		sleep(60)
		//Win or lose?
		do_outcome()
		reset_wheel()
		update_icon()

