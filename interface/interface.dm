
	#define HOTKEY_MODE_OPTIONS {"<font color='purple'> \
Hotkey-Mode: (hotkey-mode must be on)\n \
\tTAB = toggle hotkey-mode\n \
\tA = Left\n \
\tS = Down\n \
\tD = Right\n \
\tW = Up\n \
\tQ = Drop\n \
\tE = Equip\n \
\tR = Throw\n \
\tT = Say\n \
\tX = Swap-hand\n \
\tZ = Activate held object (or y)\n \
\tJ = Toggle-aiming-mode\n \
\tF = Face direction\n \
\tG = Cycle-intents-right\n \
\tM = Toggle-run\n \
\t, = Rest\n \

\t1 = Help-intent\n \
\t2 = Disarm-intent\n \
\t3 = Grab-intent\n \
\t4 = Harm-intent\n \
\tPgUp = Go up\n \
\tPgDwn = Do down\n \
\tCtrl click= drag\n \
\tShift click = examine\n \
\tSpace = Use-iron-sights/tank gun\n \

\tO = OOC\n \
\tAlt+L = LOOC\n \
\tF1 = Admin Help\n \
\tF2 = Mentor Help\n \
\tF3 = Emote\n \
\tF12 = ChangeHUD\n \

Any-Mode: (hotkey doesn't need to be on)\n  \
\tCtrl+q = Drop\n \
\tCtrl+e = Equip\n \
\tCtrl+r = Throw\n \
\tCtrl+x = Swap-hand\n \
\tCtrl+z = Activate held object (or Ctrl+y)\n \
\tCtrl+f = Cycle-intents-left\n \
\tCtrl+g = Cycle-intents-right\n \
\tCtrl+1 = Help-intent\n \
\tCtrl+2 = Disarm-intent\n \
\tCtrl+3 = Grab-intent\n \
\tCtrl+4 = Harm-intent\n \
\tDEL = Pull\n \
\tINS = Cycle-intents-right\n \
\tHOME = Drop\n \
\tPGUP = Swap-hand\n \
\tPGDN = Activate held object\n \
\tEND = Throw\n \
\tSpace = Use-iron-sights/tank gun\n \
</font>"}

//Please use mob or src (not usr) in these procs. This way they can be called in the same fashion as procs.
/client/verb/website()
	set name = "website"
	set desc = "Visit the website"
	set hidden = TRUE
	if (config.websiteurl)
		if (WWinput(src, "This will open the website in your browser. Are you sure?", "Website", "Yes", list("Yes", "No")) == "No")
			return
		src << link(config.websiteurl)
	else
		src << "<span class='warning'>The website URL is not set in the server configuration.</span>"
	return

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

/client/verb/donate()
	set name = "donate"
	set desc = "Support the server via paypal."
	set hidden = TRUE
	if (config.donationurl)
		if (WWinput(src, "This will open the donation link in your browser. Are you sure?", "Donations", "Yes", list("Yes", "No")) == "No")
			return
		src << link(config.donationurl)
	else
		src << "<span class='warning'>The donation URL is not set in the server configuration.</span>"
	return

/client/verb/github()
	set name = "Github"
	set desc = "Visit the Github"
	set hidden = TRUE
	if (config.githuburl)
		if (WWinput(src, "This will open the Github in your browser. Are you sure?", "Github", "Yes", list("Yes", "No")) == "No")
			return
		src << link(config.githuburl)
	else
		src << "<span class='warning'>The Github URL is not set in the server configuration.</span>"
	return

/client/verb/discord()
	set name = "discord"
	set desc = "Visit the discord"
	set hidden = TRUE
	if (config.discordurl)
		if (WWinput(src, "This will open the Discord in your browser. Are you sure?", "Discord", "Yes", list("Yes", "No")) == "No")
			return
		src << link(config.discordurl)
	else
		src << "<span class='warning'>The Discord URL is not set in the server configuration.</span>"
	return

#define RULES_FILE "config/rules.html"
/client/verb/rules()
	set name = "Rules"
	set desc = "Show Server Rules"
	set hidden = TRUE
	if (config.rulesurl)
		if (WWinput(src, "This will open the rules in your browser. Are you sure?", "Rules", "Yes", list("Yes", "No")) == "No")
			return
		src << link(config.rulesurl)
	else
		src << "<span class='warning'>The rules URL is not set in the server configuration.</span>"
	return
#undef RULES_FILE

/client/verb/hotkeys_help()
	set name = "Hotkeys Help"
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