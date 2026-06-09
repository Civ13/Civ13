/obj/item/clothing/under/football
	name = "Unga Bunga jersey"
	desc = "A football jersey of the Unga Bunga United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"
	force = 0.0
	throwforce = 0.0
	var/player_number = 0

/obj/item/clothing/under/football/flamengo
	name = "flamengo shirt with yellow shorts"
	desc = "A C.R. Flamengo football shirt, with yellow swimming trunks."
	icon_state = "flamengo"
	item_state = "flamengo"
	worn_state = "flamengo"
	player_number = 10

/obj/item/clothing/under/football/red
	name = "Unga Bunga jersey"
	desc = "A football jersey of the Unga Bunga United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"

/obj/item/clothing/under/football/red/goalkeeper
	name = "Unga Bunga goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Unga Bunga United, U.B.U."
	icon_state = "football_red_gk"
	item_state = "football_red_gk"
	worn_state = "football_red_gk"

/obj/item/clothing/under/football/blue
	name = "Chad Town jersey"
	desc = "A football jersey of the Chad Town Football Club, C.T.F.C."
	icon_state = "football_blue"
	item_state = "football_blue"
	worn_state = "football_blue"

/obj/item/clothing/under/football/blue/goalkeeper
	name = "Chad Town goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Chad Town Football Club, C.T.F.C."
	icon_state = "football_blue_gk"
	item_state = "football_blue_gk"
	worn_state = "football_blue_gk"

// Campaign

/obj/item/clothing/under/football/red_campaign
	name = "Redmenia jersey"
	desc = "A football jersey of the Redmenia United, U.B.U."
	icon_state = "football_red"
	item_state = "football_red"
	worn_state = "football_red"

/obj/item/clothing/under/football/red_campaign/goalkeeper
	name = "Redmenia goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Redmenia United, U.B.U."
	icon_state = "football_red_gk"
	item_state = "football_red_gk"
	worn_state = "football_red_gk"

/obj/item/clothing/under/football/blue_campaign
	name = "Blugoslavia jersey"
	desc = "A football jersey of the Blugoslavia Football Club, C.T.F.C."
	icon_state = "football_blue"
	item_state = "football_blue"
	worn_state = "football_blue"

/obj/item/clothing/under/football/blue_campaign/goalkeeper
	name = "Blugoslavia goalkeeper jersey"
	desc = "A football jersey of the goalkeeper of Blugoslavia Football Club, C.T.F.C."
	icon_state = "football_blue_gk"
	item_state = "football_blue_gk"
	worn_state = "football_blue_gk"

///////////CUSTOM JERSEY//////////////
/obj/item/clothing/under/football/custom
	name = "football jersey"
	desc = "A football team's official jersey."
	var/uncolored = FALSE
	var/shirt_color = 0
	var/shorts_color = 0
	var/shorts_sides_color = 0
	var/shirt_sides_color = 0
	var/shirt_sleeves_color = 0
	var/shirt_hstripes_color = 0
	var/shirt_vstripes_color = 0
	item_state = "football_custom"
	icon_state = "football_custom"
	worn_state = "football_custom"
	heat_protection = LOWER_TORSO|UPPER_TORSO
	color = "#FFFFFF"
	New()
		..()
		spawn(5)
			uncolored = TRUE


/obj/item/clothing/under/football/custom/attack_self(mob/user as mob)
	if (uncolored)
		show_jersey_ui(user)
	else
		..()

/obj/item/clothing/under/football/custom/proc/show_jersey_ui(mob/user)
	var/dat = "<html><head>"
	dat += "[common_browser_style]"
	dat += "<script>"
	dat += "function sf(){"
	dat += "a=document.getElementById('shorts_color').value;"
	dat += "b=document.getElementById('ssck').checked?document.getElementById('ssc').value:'';"
	dat += "c=document.getElementById('shirt_color').value;"
	dat += "d=document.getElementById('slck').checked?document.getElementById('slc').value:'';"
	dat += "h='n';"
	dat += "if(document.getElementById('st_h').checked)h='h';"
	dat += "else if(document.getElementById('st_v').checked)h='v';"
	dat += "f='';g='';"
	dat += "if(h=='h'){f=document.getElementById('hc').value;}"
	dat += "else if(h=='v'){g=document.getElementById('vc').value;}"
	dat += "i=document.getElementById('cck').checked?document.getElementById('cc').value:'';"
	dat += "j=document.getElementById('num').value;"
	dat += "q='sc='+encodeURIComponent(a)+'&ssc='+encodeURIComponent(b)+'&shc='+encodeURIComponent(c)+'&shsc='+encodeURIComponent(d)+'&svc='+encodeURIComponent(g)+'&shhc='+encodeURIComponent(f)+'&sic='+encodeURIComponent(i)+'&num='+encodeURIComponent(j)+'&st='+encodeURIComponent(h);"
	dat += "window.location='byond://?src=\ref[src];'+q;"
	dat += "}"
	dat += "function tc(id,chk){document.getElementById(id).disabled=!document.getElementById(chk).checked;}"
	dat += "function ts(){"
	dat += "h='n';"
	dat += "if(document.getElementById('st_h').checked)h='h';"
	dat += "else if(document.getElementById('st_v').checked)h='v';"
	dat += "document.getElementById('hd').style.display='none';"
	dat += "document.getElementById('vd').style.display='none';"
	dat += "if(h=='h')document.getElementById('hd').style.display='';"
	dat += "if(h=='v')document.getElementById('vd').style.display='';"
	dat += "}"
	dat += "</script>"
	dat += "</head><body>"
	dat += "<h2>Custom Jersey</h2>"
	dat += "<form onsubmit='sf();return false;'>"
	dat += "<table>"
	dat += "<tr><td colspan=2><b>Shorts</b></td></tr>"
	dat += "<tr><td>Shorts Color:</td><td><input type=color id='shorts_color' value='#FFFFFF'></td></tr>"
	dat += "<tr><td>Side Stripes:</td><td><input type=checkbox id='ssck' onchange=\"tc('ssc','ssck')\"><input type=color id='ssc' value='#FFFFFF' disabled></td></tr>"
	dat += "<tr><td colspan=2><b>Shirt</b></td></tr>"
	dat += "<tr><td>Shirt Color:</td><td><input type=color id='shirt_color' value='#FFFFFF'></td></tr>"
	dat += "<tr><td>Sleeves:</td><td><input type=checkbox id='slck' onchange=\"tc('slc','slck')\"><input type=color id='slc' value='#FFFFFF' disabled></td></tr>"
	dat += "<tr><td>Stripes:</td><td>"
	dat += "<input type=radio name=st id=st_n value=n checked onchange='ts()'> None"
	dat += "<input type=radio name=st id=st_h value=h onchange='ts()'> Horizontal"
	dat += "<input type=radio name=st id=st_v value=v onchange='ts()'> Vertical"
	dat += "</td></tr>"
	dat += "<tr id='hd' style='display:none'><td>H.Stripes:</td><td><input type=color id='hc' value='#FFFFFF'></td></tr>"
	dat += "<tr id='vd' style='display:none'><td>V.Stripes:</td><td><input type=color id='vc' value='#FFFFFF'></td></tr>"
	dat += "<tr><td>Collar/Tips:</td><td><input type=checkbox id='cck' onchange=\"tc('cc','cck')\"><input type=color id='cc' value='#FFFFFF' disabled></td></tr>"
	dat += "<tr><td>Shirt Number:</td><td><select id='num'><option value=0>None</option>"
	dat += "<option value=1>1</option><option value=2>2</option><option value=3>3</option><option value=4>4</option>"
	dat += "<option value=5>5</option><option value=6>6</option><option value=7>7</option><option value=8>8</option>"
	dat += "<option value=9>9</option><option value=10>10</option><option value=11>11</option>"
	dat += "</select></td></tr>"
	dat += "<tr><td colspan=2 style='text-align:center;padding-top:10px;'>"
	dat += "<input type=submit value='Apply' style='font-size:16px;padding:6px 24px;'>"
	dat += "</td></tr>"
	dat += "</table>"
	dat += "</form>"
	dat += "</body></html>"
	user << browse(dat, "window=football_jersey;size=420x550")

/obj/item/clothing/under/football/custom/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/user = usr
	if (!istype(user) || user.stat || get_dist(src, user) > 1)
		return
	if (!uncolored)
		return
	var/sc = href_list["sc"]
	var/ssc = href_list["ssc"]
	var/shc = href_list["shc"]
	var/shsc = href_list["shsc"]
	var/svc = href_list["svc"]
	var/shhc = href_list["shhc"]
	var/sic = href_list["sic"]
	var/num = text2num(href_list["num"])
	var/st = href_list["st"]
	if (sc && sc != "")
		shorts_color = sc
	if (ssc && ssc != "")
		shorts_sides_color = ssc
	if (shc && shc != "")
		shirt_color = shc
	if (shsc && shsc != "")
		shirt_sleeves_color = shsc
	if (st == "v" && svc && svc != "")
		shirt_vstripes_color = svc
	if (st == "h" && shhc && shhc != "")
		shirt_hstripes_color = shhc
	if (sic && sic != "")
		shirt_sides_color = sic
	if (num > 0 && num <= 11)
		player_number = num
	if (shirt_color && shorts_color)
		uncolored = FALSE
		var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt")
		shirt.color = shirt_color
		var/image/shorts = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts")
		shorts.color = shorts_color
		var/image/shorts_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts_sides")
		shorts_sides.color = shorts_sides_color
		var/image/shirt_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sides")
		shirt_sides.color = shirt_sides_color
		var/image/shirt_sleeves = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sleeves")
		shirt_sleeves.color = shirt_sleeves_color
		var/image/shirt_vstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_vertical")
		shirt_vstripes.color = shirt_vstripes_color
		var/image/shirt_hstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_horizontal")
		shirt_hstripes.color = shirt_hstripes_color
		overlays += shirt
		overlays += shorts
		if (shorts_sides_color)
			overlays += shorts_sides
		if (shirt_sides_color)
			overlays += shirt_sides
		if (shirt_sleeves_color)
			overlays += shirt_sleeves
		if (shirt_vstripes_color)
			overlays += shirt_vstripes
		if (shirt_hstripes_color)
			overlays += shirt_hstripes
		var/image/symbols = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_symbols")
		overlays += symbols
		user << browse(null, "window=football_jersey")
	else
		to_chat(user, "<span class='notice'>You must set at least the shirt and shorts colors.</span>")
		show_jersey_ui(user)
//for automatic assignement of colors, ie, roundstart
/obj/item/clothing/under/football/custom/proc/assign_style(tname,tshorts_color,tshirt_color,tshorts_sides_color=null,tshirt_sleeves_color=null,tshirt_sides_color=null,tshirt_vstripes_color=null,tshirt_hstripes_color=null,c_player_number=0)
	uncolored = FALSE
	if (tshorts_color != "null" && tshorts_color != "" && tshorts_color != "0")
		src.shorts_color = tshorts_color
	if (tshirt_color != "null" && tshirt_color != "" && tshirt_color != "0")
		src.shirt_color = tshirt_color
	if (tshorts_sides_color != "null" && tshorts_sides_color != "" && tshorts_sides_color != "0")
		src.shorts_sides_color = tshorts_sides_color
	if (tshirt_sleeves_color != "null" && tshirt_sleeves_color != "" && tshirt_sleeves_color != "0")
		src.shirt_sleeves_color = tshirt_sleeves_color
	if (tshirt_sides_color != "null" && tshirt_sides_color != "" && tshirt_sides_color != "0")
		src.shirt_sides_color = tshirt_sides_color
	if (tshirt_vstripes_color != "null" && tshirt_vstripes_color != "" && tshirt_vstripes_color != "0")
		src.shirt_vstripes_color = tshirt_vstripes_color
	if (tshirt_hstripes_color != "null" && tshirt_hstripes_color != "" && tshirt_hstripes_color != "0")
		src.shirt_hstripes_color = tshirt_hstripes_color
	if (tshirt_color && tshorts_color)
		var/image/shirt = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt")
		shirt.color = shirt_color
		var/image/shorts = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts")
		shorts.color = shorts_color
		var/image/shorts_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shorts_sides")
		shorts_sides.color = shorts_sides_color
		var/image/shirt_sides = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sides")
		shirt_sides.color = shirt_sides_color
		var/image/shirt_sleeves = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_sleeves")
		shirt_sleeves.color = shirt_sleeves_color
		var/image/shirt_vstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_vertical")
		shirt_vstripes.color = shirt_vstripes_color
		var/image/shirt_hstripes = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_shirt_stripes_horizontal")
		shirt_hstripes.color = shirt_hstripes_color
		overlays += shirt
		overlays += shorts
		if (shorts_sides_color)
			overlays += shorts_sides
		if (shirt_sides_color)
			overlays += shirt_sides
		if (shirt_sleeves_color)
			overlays += shirt_sleeves
		if (shirt_vstripes_color)
			overlays += shirt_vstripes
		if (shirt_hstripes_color)
			overlays += shirt_hstripes
		var/image/symbols = image("icon" = 'icons/obj/clothing/uniforms.dmi', "icon_state" = "football_custom_symbols")
		overlays += symbols
		if (c_player_number != 0)
			src.player_number = c_player_number
		spawn(10)
			uncolored = FALSE
		return
/////////SHOES////////////////////////
/obj/item/clothing/shoes/football
	name = "football trainers"
	desc = "A pair of football trainers."
	icon_state = "football"
	item_state = "football"
	worn_state = "football"
	armor = list(melee = 60, arrow = 5, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = FALSE)
	siemens_coefficient = 0.6
	force = 0.0
	throwforce = 0.0

////////////GLOVES/////////////////
/obj/item/clothing/gloves/goalkeeper/red
	name = "goalkeeper gloves"
	icon_state = "latex"
	item_state = "latex"
	color = "#ffffff"

/obj/item/clothing/gloves/goalkeeper/blue
	name = "goalkeeper gloves"
	icon_state = "latex"
	item_state = "latex"
	color = "#ffffff"

/mob/living/human/var/obj/item/football/football = null

/obj/item/football
	name = "ball"
	desc = "A classic black and white football."
	icon = 'icons/obj/football.dmi'
	icon_state = "football"
	force = 0.0
	throwforce = 0.0
	throw_speed = 0.5
	throw_range = 9
	item_state = "football"
	w_class = ITEM_SIZE_LARGE
	layer = 6
	opacity = FALSE
	density = FALSE
	allow_spin = FALSE

	var/mob/living/human/owner = null
	var/mob/living/human/last_owner = null
/obj/item/football/proc/update_movement()
	if (owner)
		src.dir = owner.dir
		src.forceMove(owner.loc)
	return

/obj/item/football/Crossed(mob/living/human/user)
	if (ishuman(user))
		if (!owner && !user.football)
			owner = user
			user.football = src
			return
		else
			..()
	else
		..()

/obj/item/football/attack_hand(mob/user as mob)
	var/area/A = get_area(src)
	if (ishuman(user))
		var/mob/living/human/H = user
		if (!istype(A, /area/caribbean/football/blue/goalkeeper) && !istype(A, /area/caribbean/football/red/goalkeeper))
			return
		else if (!(findtext(H.original_job_title, "goalkeeper")))
			return
		else
			if (owner)
				owner.football = null
				owner = null
	..()
//goal posts
/obj/effect/step_trigger/goal
	name = "goalpost"
	var/team = null

	New()
		..()
		spawn(10)
			assign()
/obj/effect/step_trigger/goal/proc/assign()
	return

/obj/effect/step_trigger/goal/Trigger(var/atom/movable/A)
	if (istype(A, /obj/item/football) && team)
		if (istype(map, /obj/map_metadata/football))
			var/obj/map_metadata/football/MF = map
			MF.reset_ball()
			MF.teams[team][2] += 1
			var/obj/item/football/FB = A
			to_chat(world, "<font size=4 color='orange'>GOAL! <b>[FB.last_owner ? FB.last_owner : "Unknown"] [FB.last_owner ? "([FB.last_owner.ckey])" : ""]</b> scores for <b>[team]</b>!</font>")
			var/scorer = " [FB.last_owner.name] ([FB.last_owner.ckey]) <b>([FB.last_owner.team])</b>"
			FB.last_owner = null
			FB.owner = null
			if (MF.scorers[scorer])
				MF.scorers[scorer] += 1
			else
				MF.scorers += list("[scorer]" = 1)
			return

/obj/effect/step_trigger/goal/red
	name = "team 1 goalpost"
	team = "red"

	assign()
		if (map && istype(map, /obj/map_metadata/football))
			var/obj/map_metadata/football/FBM = map
			team = FBM.teams[FBM.team1][1]

/obj/effect/step_trigger/goal/blue
	name = "team 2 goalpost"
	team = "blue"

	assign()
		if (map && istype(map, /obj/map_metadata/football))
			var/obj/map_metadata/football/FBM = map
			team = FBM.teams[FBM.team2][1]
/////////////////TEAM CREATOR/////////////////////

/obj/structure/submitter
	name = "Team Registration Terminal"
	desc = "Register your team here!"
	icon = 'icons/obj/computers.dmi'
	icon_state = "1980_computer_on"
	var/active = FALSE
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/mob/living/user = null
	var/list/pending = list()
/obj/structure/submitter/attack_hand(mob/living/human/mob as mob)
	if (!ishuman(mob))
		return
	if (!active)
		return
	mob.setClickCooldown(40)
	to_chat(mob, "You take a blank kit from the Terminal. You can now customise it.")
	new/obj/item/clothing/under/football/custom(loc)
	return

/obj/structure/submitter/attackby(obj/item/clothing/W as obj, mob/living/mob as mob)
	if (!istype(W, /obj/item/clothing/under/football/custom))
		return
	var/obj/item/clothing/under/football/custom/CU = W
	show_team_ui(mob, CU)

/obj/structure/submitter/proc/show_team_ui(mob/user, var/obj/item/clothing/under/football/custom/CU)
	var/dat = {"<html><head>
[common_browser_style]
<script language="javascript">
function submitAction(action) {
	window.location='byond://?src=\ref[src];action='+action;
}
function startTeam() {
	var name = document.getElementById('team_name').value;
	if (name.trim() == '') { alert('Enter a team name!'); return; }
	window.location='byond://?src=\ref[src];action=start&name='+encodeURIComponent(name.trim());
}
</script>
</head><body>"}
	if (user.ckey in pending)
		var/list/T = pending[user.ckey]
		dat += "<h2>Team Creator</h2>"
		dat += "<p>Creating team: <b>[T["name"]]</b></p>"
		dat += "<p>Select which uniform this kit will be:</p>"
		if (!T["main_uniform"])
			dat += "<button class='btn' onclick='submitAction(\"main\")' style='display:block;width:100%;margin:4px 0;'>Main Uniform</button>"
		if (!T["secondary_uniform"])
			dat += "<button class='btn' onclick='submitAction(\"secondary\")' style='display:block;width:100%;margin:4px 0;'>Secondary Uniform</button>"
		if (!T["goalkeeper_uniform"])
			dat += "<button class='btn' onclick='submitAction(\"goalkeeper\")' style='display:block;width:100%;margin:4px 0;'>Goalkeeper Uniform</button>"
		dat += "<button class='btn' onclick='submitAction(\"cancel\")' style='display:block;width:100%;margin:8px 0;'>Cancel</button>"
	else
		dat += {"<h2>Team Creator</h2>
<p>Welcome! You will need to submit 3 kits: main, alternative, goalkeeper.</p>
<p>Enter a team name and choose the type for this kit:</p>
<input type="text" id="team_name" placeholder="Team Name (max 20 chars)" maxlength="20" style="width:100%;box-sizing:border-box;padding:4px;margin:4px 0;">
<button class="btn" onclick="startTeam()" style="display:block;width:100%;margin:4px 0;">Start with Main</button>
<button class="btn" onclick="document.getElementById('team_name').value=prompt('Enter team name:');startTeam()" style="display:block;width:100%;margin:4px 0;">Start with Secondary</button>
<button class="btn" onclick="document.getElementById('team_name').value=prompt('Enter team name:');startTeam()" style="display:block;width:100%;margin:4px 0;">Start with Goalkeeper</button>
<button class="btn" onclick='submitAction("cancel")' style="display:block;width:100%;margin:8px 0;">Cancel</button>"}
	dat += "</body></html>"
	user << browse(dat, "window=team_creator;size=400x400")

/obj/structure/submitter/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/mob = usr
	if (!istype(mob) || mob.stat || get_dist(src, mob) > 2)
		return
	if (!mob.ckey)
		return
	var/obj/item/clothing/under/football/custom/CU = null
	if (mob.l_hand && istype(mob.l_hand, /obj/item/clothing/under/football/custom))
		CU = mob.l_hand
	else if (mob.r_hand && istype(mob.r_hand, /obj/item/clothing/under/football/custom))
		CU = mob.r_hand
	if (!CU)
		to_chat(mob, "<span class='notice'>You need to hold a customized jersey to submit it.</span>")
		return
	var/action = href_list["action"]
	if (!action)
		return
	if (action == "cancel")
		mob << browse(null, "window=team_creator")
		return
	if (action == "start")
		var/name = href_list["name"]
		if (!name || name == "")
			return
		name = copytext(name, 1, 21)
		var/list/T = list()
		T["name"] = name
		pending[mob.ckey] = T
		mob << browse(null, "window=team_creator")
		show_team_ui(mob, CU)
		return
	if (mob.ckey in pending)
		var/list/T = pending[mob.ckey]
		if (action == "main" && !T["main_uniform"])
			T["main_uniform"] = list()
			T["main_uniform"]["shorts_color"] = CU.shorts_color
			T["main_uniform"]["shirt_color"] = CU.shirt_color
			T["main_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
			T["main_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
			T["main_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
			T["main_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
			T["main_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
		else if (action == "secondary" && !T["secondary_uniform"])
			T["secondary_uniform"] = list()
			T["secondary_uniform"]["shorts_color"] = CU.shorts_color
			T["secondary_uniform"]["shirt_color"] = CU.shirt_color
			T["secondary_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
			T["secondary_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
			T["secondary_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
			T["secondary_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
			T["secondary_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
		else if (action == "goalkeeper" && !T["goalkeeper_uniform"])
			T["goalkeeper_uniform"] = list()
			T["goalkeeper_uniform"]["shorts_color"] = CU.shorts_color
			T["goalkeeper_uniform"]["shirt_color"] = CU.shirt_color
			T["goalkeeper_uniform"]["shorts_sides_color"] = CU.shorts_sides_color
			T["goalkeeper_uniform"]["shirt_sleeves_color"] = CU.shirt_sleeves_color
			T["goalkeeper_uniform"]["shirt_sides_color"] = CU.shirt_sides_color
			T["goalkeeper_uniform"]["shirt_vstripes_color"] = CU.shirt_vstripes_color
			T["goalkeeper_uniform"]["shirt_hstripes_color"] = CU.shirt_hstripes_color
		else
			show_team_ui(mob, CU)
			return
		if (T["goalkeeper_uniform"] && T["secondary_uniform"] && T["main_uniform"])
			var/obj/map_metadata/football/FM = map
			FM.teams += list("[T["name"]]" = T)
			var/dat2 = {"<html><head>[common_browser_style]</head><body><h2>Success!</h2><p>You successfully added the team <b>[T["name"]]</b>! It is now selectable.</p><button class='btn' onclick=\"window.location='byond://?src=\ref[src];action=close_success'\">OK</button></body></html>"}
			mob << browse(dat2, "window=team_creator;size=400x200")
			FM.save_teams()
			pending -= pending[mob.ckey]
			return
		else
			var/dat2 = {"<html><head>[common_browser_style]</head><body><h2>Kit Submitted</h2><p>You can now continue editing this team by submitting the remaining kits.</p><button class='btn' onclick=\"window.location='byond://?src=\ref[src];action=continue_edit'\">OK</button></body></html>"}
			mob << browse(dat2, "window=team_creator;size=400x200")
			return
	if (action == "close_success" || action == "continue_edit")
		mob << browse(null, "window=team_creator")

/////////////////GOALPOSTS/////////////////

/obj/structure/goalpost
	name = "goalpost"
	desc = "A goalpost"
	icon = 'icons/obj/fence.dmi'
	icon_state = "goalpostX"
	flammable = FALSE
	opacity = FALSE
	density = TRUE
	layer = 8
	anchored = TRUE

/obj/structure/goalpost/attackby(obj/O as obj, mob/user as mob)
	return
/obj/structure/goalpost/attack_hand(mob/user as mob)
	return

/obj/structure/goalpost/inner
	icon_state = "goalpost_i"
	density = FALSE

///////////////////////////////////BASKETBALL///////////////////////////////////////

/obj/structure/basketball_hoop
	name = "basketball hoop"
	desc = "A basketball hoop."
	icon = 'icons/obj/basketball.dmi'
	icon_state = "hoop"
	flammable = FALSE
	opacity = FALSE
	density = TRUE
	anchored = TRUE
	throwpass = TRUE

/obj/item/weapon/basketball
	icon = 'icons/obj/basketball.dmi'
	icon_state = "basketball"
	name = "basketball"
	desc = "Here's your chance, time to sign up for the NBA."
	force = 0
	throwforce = 0
	throw_speed = 1.5
	throw_range = 7
	item_state = "basketball"
	w_class = ITEM_SIZE_LARGE //Stops people from hiding it in their backpack.
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand.dmi',
		)
	item_state_slots = list(
		slot_l_hand_str = "basketball",
		slot_r_hand_str = "basketball",
		)


/obj/structure/basketball_hoop/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/grab) && get_dist(src,user)<2)
		var/obj/item/weapon/grab/G = W
		if(G.state<2)
			to_chat(user, "<span class='warning'>You need a better grip to do that!</span>")
			return
		G.affecting.loc = src.loc
		G.affecting.Weaken(5)
		visible_message("<span class='warning'>[G.assailant] dunks [G.affecting] into the [src]!</span>", 3)
		qdel(W)
		return
	else if (istype(W, /obj/item) && get_dist(src,user)<2)
		user.drop_item(src.loc)
		visible_message("<span class='notice'>[user] dunks [W] into the [src]!</span>", 3)
		return

/obj/structure/basketball_hoop/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover,/obj/item) && mover.throwing)
		var/obj/item/I = mover
		if(istype(I, /obj/item/projectile))
			return
		if(prob(50))
			I.dropInto(loc)
			visible_message(SPAN_NOTICE("Swish! \the [I] lands in \the [src]."))
		else
			visible_message(SPAN_WARNING("\The [I] bounces off of \the [src]'s rim!"))
		return 0
	else
		return ..(mover, target, height, air_group)
