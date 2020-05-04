
	#define HOTKEY_MODE_OPTIONS {"<font color='purple'> \
Hotkey-Mode: (hotkey-mode must be on)\n \
\tTAB = toggle hotkey-mode\n \
\ta = left\n \
\ts = down\n \
\td = right\n \
\tw = up\n \
\tq = drop\n \
\te = equip\n \
\tr = throw\n \
\tt = say\n \
\t5 = emote\n \
\tx = swap-hand\n \
\t, = rest\n \
\tz = activate held object (or y)\n \
\tj = toggle-aiming-mode\n \
\tf = cycle-intents-left\n \
\tg = cycle-intents-right\n \
\t1 = help-intent\n \
\t2 = disarm-intent\n \
\t3 = grab-intent\n \
\t4 = harm-intent\n \
\tPgUp = go up\n \
\tPgDwn = go down\n \
\tCtrl = drag\n \
\tShift = examine\n \
\tSpace = Use-iron-sights/tank gun\n \
Any-Mode: (hotkey doesn't need to be on)\n  \
\tCtrl+q = drop\n \
\tCtrl+e = equip\n \
\tCtrl+r = throw\n \
\tCtrl+x = swap-hand\n \
\tCtrl+z = activate held object (or Ctrl+y)\n \
\tCtrl+f = cycle-intents-left\n \
\tCtrl+g = cycle-intents-right\n \
\tCtrl+1 = help-intent\n \
\tCtrl+2 = disarm-intent\n \
\tCtrl+3 = grab-intent\n \
\tCtrl+4 = harm-intent\n \
\tDEL = pull\n \
\tINS = cycle-intents-right\n \
\tHOME = drop\n \
\tPGUP = swap-hand\n \
\tPGDN = activate held object\n \
\tEND = throw\n \
\tSpace = Use-iron-sights/tank gun\n \
</font>"}

//Please use mob or src (not usr) in these procs. This way they can be called in the same fashion as procs.

/client/verb/wiki()
	set name = "wiki"
	set desc = "Visit the wiki"
	set hidden = TRUE
	if (config.wikiurl)
		if (WWinput(src, "This will open the wiki in your browser. Are you sure?", "Wiki", "Yes", list("Yes", "No")) == "No")
			return
		src << link(config.wikiurl)
	else
		src << "<span class='warning'>The wiki URL is not set in the server configuration.</span>"
	return


/client/verb/hotkeys_help()
	set name = "hotkeys-help"
	set category = "OOC"

	src << HOTKEY_MODE_OPTIONS

/mob/verb/a_intent_change(input as text)
	set name = "a-intent"
	set hidden = TRUE

	if (ishuman(src))
		switch(input)
			if (I_HELP,I_DISARM,I_GRAB,I_HARM)
				a_intent = input
			if ("right")
				a_intent = intent_numeric((intent_numeric(a_intent)+1) % 4)
			if ("left")
				a_intent = intent_numeric((intent_numeric(a_intent)+3) % 4)
//		if (hud_used && hud_used.action_intent)
//			hud_used.action_intent.icon_state = "intent_[a_intent]"

	if (HUDneed.Find("intent"))
		var/obj/screen/intent/I = HUDneed["intent"]
		I.update_icon()

/mob/verb/combatmode_change(input as text)
	set name = "a-combat"
	set hidden = TRUE

	if (ishuman(src))
		switch(input)
			if (I_DODGE,I_PARRY)
				defense_intent = input

	if (HUDneed.Find("mode"))
		var/obj/screen/mode/I = HUDneed["mode"]
		I.update_icon()