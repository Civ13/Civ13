/**
 * Everything to do with international banking
 * 
 * SPONSORED by the Foreign Nations Alliance (FNA)!
 */

/obj/structure/banking
    name = "banking"
    desc = "debug"
    icon = 'icons/obj/banking.dmi'
    icon_state = ""
    layer = 3
    anchored = TRUE
    density = TRUE
    flammable = FALSE
    not_movable = FALSE
    not_disassemblable = TRUE

/obj/structure/banking/computer
    var/operatingsystem = "FNB OS 42-G7"
    var/display = "FNB OS 1.0.0"
    var/mainbody = ""
	var/mainmenu = ""
	var/mob/user

/obj/structure/banking/computer/atm
    name = "ATM"
    desc = "an Automatic Teller Machine (ATM), owned by the Foreign Nations Bank, founded by the Foreign Nations Alliance. This ATM allows for international banking and overall storing your money in a safe place."
    icon_state = "atm"
    not_movable = TRUE

/datum/banking_program
    var/name = "banking program"
	var/description = "a basic digital international banking program."
	var/list/compatible_os = list("FNB OS 42-G7")
	var/mainbody = "---"
	var/mainmenu = "---"

	var/mob/living/human/user
	var/obj/structure/banking/computer/origin

/datum/banking_program/proc/do_html(mob/living/human/user)
	var/fullpage = {"
			<!DOCTYPE html>
			<html>
			<head>[computer_browser_style]<title>[name]</title></head>
			<body>
			<center>[mainmenu]</center>
			<hr style="height:4px;border-width:0;color:navy;background-color:navy">
			[mainbody]
			</body>
			</html>
			"}
	usr << browse(fullpage,"window=[name];border=1;can_close=1;can_resize=0;can_minimize=0;titlebar=1;size=800x600")

/datum/banking_program/Topic(href, href_list, hsrc)

	if (!origin)
		return

	var/mob/living/human/user = origin.user

	if (!user || user.lying || !ishuman(user))
		return

	user.face_atom(origin)

	if (!locate(user) in range(1,origin))
		user << "<span class = 'danger'>Get next to \the [origin] to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE

/datum/banking_program/atm
    name = "Automatic Teller Machine"
    description = "Connects to the FNB international digital banking service for quick withdrawal and deposit, as well as near-immediate response time."
    var/depositing = FALSE



/datum/banking_program/atm/do_html(mob/living/human/user)
    if (mainmenu == "---")
        mainmenu = "<h2>DIGITAL BANKING TERMINAL</h2><br>"
        mainmenu += "<a href='?src=\ref[src];atm=2'>Deposit Cash</a>&nbsp;<a href='?src=\ref[src];atm=3'>Withdraw Cash</a>&nbsp;"

/datum/banking_program/atm/Topic(href, href_list, hsrc)
    mainbody = ""
    if (href_list["atm"])
        if (href_list["atm"] == 2)
            if (user.bank_hold)
                mainbody = "<font color ='red'><b>ACCESS DENIED</b></font> <br>"
                mainbody += "<font color ='red'><b>DUE TO CERTAIN ISSUES, THIS ACCOUNT HAS BEEN PLACED ON HOLD UNTIL FURTHER NOTICE</b></font>"
                playsound(loc, 'sound/machines/access_denied.ogg')
                depositing = FALSE
                return
            else
                mainbody += "Please insert the cash into the ATM. Only paper banknotes are accepted"
                playsound(loc, 'sound/machines/atm_deposit_open_1.ogg', 100, TRUE)
                depositing = TRUE
                return

        if (href_list["atm"] == 3)
            mainbody += "Please select currency to withdraw, you have $[user.bank_dollar] and [user.bank_rubles] rubles"
            mainbody += " <a href='?src=\ref[src];atm=wdollar'>(Dollar)</a> <a href='?src=\ref[src];atm=wrubles'>(Rubles)</a><br>

        if(findtext(href_list["atm"], "wdollar"))
            if (user.bank_hold)
                mainbody += "<font color ='red'><b>ACCESS DENIED</b></font> <br>"
                mainbody += "<font color ='red'><b>DUE TO CERTAIN ISSUES, THIS ACCOUNT HAS BEEN PLACED ON HOLD UNTIL FURTHER NOTICE</b></font>"
                playsound(loc, 'sound/machines/access_denied.ogg')
                sleep(0.5)
                do_html(user)
                return
            else
                mainbody = "Please input the amount you would like to withdraw <br>"
                var/w_amount = input(usr, "How much in dollar would you like to withdraw?", "Amount", "50") as num|null
                if ((user.bank_dollar - w_amount) < 0)
                    mainbody = "<font color ='red'><b>ERROR: INSUFFICIENT FUNDS</b></font> <br>"
                    sleep(0.5)
                    do_html(user)
                    return
                else
                    playsound(loc, "sound/machines/atm_withdraw.ogg")
                    wait(32)
                    user.bank_dollar -= w_amount
                    new/obj/item/stack/money/dollar(loc, round(w_amount))
                    mainbody = "<font color ='green'><b>SUCCESS! Money withdrawn</b></font> <br>"
                    mainbody += "<b>Have a nice day!</b>"
                    sleep(0.5)
                    do_html(user)
                    return

        if(findtext(href_list["atm"], "wdrubles"))
            if (user.bank_hold)
                mainbody = "<font color ='red'><b>ACCESS DENIED</b></font> <br>"
                mainbody += "<font color ='red'><b>DUE TO CERTAIN ISSUES, THIS ACCOUNT HAS BEEN PLACED ON HOLD UNTIL FURTHER NOTICE</b></font>"
                playsound(loc, 'sound/machines/access_denied.ogg')
                sleep(0.5)
                do_html(user)
                return
            else
                mainbody = "Please input the amount you would like to withdraw <br>"
                var/w_amount = input(usr, "How much in rubles you like to withdraw?", "Amount", "50") as num|null

                if ((user.bank_dollar - w_amount) < 0)
                    mainbody = "<font color ='red'><b>ERROR: INSUFFICIENT FUNDS</b></font> <br>"
                    sleep(0.5)
                    do_html(user)
                    return
                else
                    playsound(loc, "sound/machines/atm_withdraw.ogg")
                    wait(32)
                    user.bank_rubles -= w_amount
                    new/obj/item/stack/money/ruble(loc, round(w_amount))
                    mainbody = "<font color ='green'><b>SUCCESS! Money withdrawn</b></font> <br>"
                    mainbody += "<b>Have a nice day!</b>"
                    sleep(0.5)
                    do_html(user)
                    return
                
        
/obj/structure/banking/computer/atm/attackby(obj/item/O as obj, mob/living/human/user as user, icon_x, icon_y)
    if depositing == FALSE
        return
    else
        if (!istype(user.l_hand, /obj/stack/money) && !istype(user.r_hand, obj/item/stack/money))
            return
        else 
            var/obj/item/stack/money/mstack = null

            if (istype(user.l_hand, /obj/item/stack/money/dollar))
                mstack = user.l_hand
                user.bank_dollar += mstack.value*mstack.amount
                visible_message("[user.name] has deposited money into the ATM")
                playsound(loc, "sound\machines\atm\atm_deposit.ogg")
                qdel(mstack)
                depositing = FALSE
                return
                
            else if (istype(user.r_hand, /obj/item/stack/money/dollar))
                mstack = user.r_hand
                user.bank_dollar += mstack.value*mstack.amount
                visible_message("[user.name] has deposited money into the ATM")
                playsound(loc, "sound\machines\atm\atm_deposit.ogg")
                qdel(mstack)
                depositing = FALSE
                return
            
            else if (istype(user.l_hand, /obj/item/stack/money/rubles))
                mstack = user.l_hand
                user.bank_rubles += mstack.amount
                visible_message("[user.name] has deposited money into the ATM")
                playsound(loc, "sound\machines\atm\atm_deposit.ogg")
                qdel(mstack)
                depositing = FALSE
                return

            else if (istype(user.r_hand, /obj/item/stack/money/rubles))
                mstack = user.r_hand
                user.bank_rubles += mstack.amount
                visible_message("[user.name] has deposited money into the ATM")
                playsound(loc, "sound\machines\atm\atm_deposit.ogg")
                qdel(mstack)
                depositing = FALSE
                return
            return

