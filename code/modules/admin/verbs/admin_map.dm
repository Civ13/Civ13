// Admin map.
//
// Staff open one live map of any level. It draws the players (coloured by
// side) and the weather (every system's oval, strength, heading and the wind)
// over the same terrain, each as a layer that can be switched off. Clicking a
// marker or a name picks a player: jump to them, follow them as a ghost, share
// their camera, or open their player panel or variables. Clicking a storm
// picks it; clicking open ground picks a spot to send weather to. The side
// panel says what weather a picked player stands under and who is under a
// picked storm. An air layer shades the air grid (weather_air.dm) by
// temperature, humidity, pressure, cloud or fog, and a picked player or spot shows
// the air there.
//
// It reuses the tactical map's terrain sampling and canvas drawing
// (code/modules/1713/tactical_map.dm), so every map works without new art.
// It replaced the separate Player Map and Weather Map windows. A new layer adds
// a key to update_json(), a control to page_html() and a drawing function to
// the script.

#define AMAP_REFRESH 20 // deciseconds between live updates
#define AMAP_WINDOW "adminmap"

var/global/datum/admin_map_controller/admin_maps = new

/datum/admin_map_controller
	var/list/viewers = list() // client = level they are watching
	var/refresh_timer // looping refresh while anyone is watching

// Who may open the map at all.
/proc/admin_map_allowed(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_MOD|R_DEBUG))

// Who sees names and keys and may jump to, follow or watch a player. Others
// see unnamed dots, as the weather map showed them.
/proc/admin_map_sees_players(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_MOD))

// Who may send, end or clear weather.
/proc/admin_map_changes_weather(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_DEBUG))

/client/proc/admin_map()
	set category = "Admin"
	set name = "Admin Map"
	set desc = "Open a live map of a level: every player, the weather systems and the wind."
	if (!check_rights(R_ADMIN|R_MOD|R_DEBUG))
		return
	var/turf/T = get_turf(mob)
	admin_maps.open(src, T ? T.z : 1)

// Everyone of interest on level z, as list(x, y, state, side, name, ckey, ref).
// States: y = the viewer, a = alive player, d = down, x = dead body with a
// player, s = disconnected body, g = ghost, n = NPC human, m = other mob a
// player controls. Without named, only where players are: state p, no side,
// name, key or ref.
/datum/admin_map_controller/proc/blips_for(z, client/viewer, named = TRUE)
	var/list/blips = list()
	if (!named)
		for (var/mob/M in player_list)
			if (isnewplayer(M) || isghost(M))
				continue
			var/turf/T = get_turf(M)
			if (T && T.z == z)
				blips[++blips.len] = list(T.x, T.y, "p", "", "", "", "")
		return blips
	var/list/seen = list()
	for (var/mob/living/human/H in human_mob_list)
		var/turf/T = get_turf(H)
		if (!T || T.z != z)
			continue
		seen[H] = TRUE
		var/state
		if (!H.ckey)
			if (H.stat == DEAD)
				continue
			state = "n"
		else if (H.stat == DEAD)
			state = "x"
		else if (!H.client)
			state = "s"
		else if (H.stat != CONSCIOUS)
			state = "d"
		else
			state = "a"
		if (viewer && H == viewer.mob)
			state = "y"
		blips[++blips.len] = list(T.x, T.y, state, admin_player_side(H), H.real_name, H.ckey || "", "\ref[H]")
	for (var/mob/M in player_list)
		if (seen[M] || isnewplayer(M))
			continue
		var/turf/T = get_turf(M)
		if (!T || T.z != z)
			continue
		var/state = isghost(M) ? "g" : "m"
		if (viewer && M == viewer.mob)
			state = "y"
		blips[++blips.len] = list(T.x, T.y, state, admin_player_side(M), M.real_name || M.name, M.ckey || "", "\ref[M]")
	return blips

// Players (not NPCs or ghosts) on each level, for the level picker.
/datum/admin_map_controller/proc/level_counts()
	var/list/counts = list()
	for (var/z in 1 to world.maxz)
		counts += 0
	for (var/mob/M in player_list)
		if (isnewplayer(M) || isghost(M))
			continue
		var/turf/T = get_turf(M)
		if (T && T.z >= 1 && T.z <= counts.len)
			counts[T.z]++
	return counts

// Weather systems as list(id, kind, severe, x, y, radius x, radius y,
// strength %, heading x, heading y, minutes left). The sky is the same over
// every level.
/datum/admin_map_controller/proc/systems()
	var/list/systems = list()
	for (var/datum/weather_system/S in weather_systems)
		systems[++systems.len] = list(S.id, S.kind, S.severe ? 1 : 0, round(S.centre_x()), round(S.centre_y()), round(S.radius_x), round(S.radius_y), round(S.power() * 100), S.vel_x, S.vel_y, max(0, round((S.lifetime - (world.time - S.born)) / 600)))
	return systems

// select: the ref of a mob to open the page with already picked.
/datum/admin_map_controller/proc/open(client/C, z, select = null)
	if (!admin_map_allowed(C))
		return
	z = clamp(round(text2num("[z]")) || 1, 1, world.maxz)
	var/list/base = tactical_maps.terrain_for(z)
	var/scale = clamp(round(760 / max(base[2], base[3])), 2, 8)
	var/width = base[2] * scale
	var/height = base[3] * scale
	viewers[C] = z
	show_browse(C, page_html(C, z, base, scale, select), "window=[AMAP_WINDOW];size=[min(1240, max(width, 600) + 340)]x[min(1000, max(height, 560) + 150)]")
	if (C.mob)
		onclose(C.mob, AMAP_WINDOW, src)
	start()

/datum/admin_map_controller/proc/start()
	if (refresh_timer)
		return
	refresh_timer = addtimer(CALLBACK(src, PROC_REF(tick)), AMAP_REFRESH, TIMER_LOOP | TIMER_STOPPABLE)

/datum/admin_map_controller/proc/tick()
	refresh()
	if (!viewers.len && refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null

// Pushes fresh positions and weather to every viewer.
/datum/admin_map_controller/proc/refresh()
	for (var/client/C in viewers.Copy())
		if (!admin_map_allowed(C))
			viewers -= C
			if (C)
				show_browse(C, null, "window=[AMAP_WINDOW]")
			continue
		send_update(C, viewers[C])
		CHECK_TICK
	for (var/key in viewers.Copy())
		if (!key)
			viewers -= key

// b = markers, c = players per level, s = weather systems, w = the map's wind,
// a = the air grid with each cell's wind (weather_wind.dm), pc = pressure centres (weather_fronts.dm), who = the viewer sees names, edit = the viewer may change the weather.
/datum/admin_map_controller/proc/update_json(client/C, z)
	var/named = C ? admin_map_sees_players(C) : TRUE
	var/list/wind = weather_wind_vector()
	var/zone = "none"
	switch (weather)
		if (WEATHER_WET)
			zone = "wet, strength [weather_intensity]"
		if (WEATHER_EXTREME)
			zone = "extreme, strength [weather_intensity]"
		if (WEATHER_SMOG)
			zone = "smog"
	return json_encode(list("b" = blips_for(z, C, named), "c" = level_counts(), "s" = systems(),
		"w" = list(wind[1], wind[2], map ? map.windspeedvar : 1, map ? map.winddesc : ""),
		"zone" = zone, "season" = season ? "[season]" : "none", "cap" = weather_system_capacity(), "a" = weather_air_map_data(), "pc" = weather_centres_map_data(),
		"who" = named ? 1 : 0, "edit" = admin_map_changes_weather(C) ? 1 : 0))

/datum/admin_map_controller/proc/send_update(client/C, z)
	C << output(list2params(list(update_json(C, z))), "[AMAP_WINDOW].browser:upd")

// Ghosts the admin if needed and returns their ghost, or null.
/datum/admin_map_controller/proc/admin_ghost_of(client/C)
	if (!C || !C.mob)
		return null
	if (!isghost(C.mob))
		C.admin_ghost()
		sleep(2)
	return isghost(C.mob) ? C.mob : null

/datum/admin_map_controller/proc/jump_to(client/C, mob/M)
	if (!istype(M) || !get_turf(M))
		to_chat(C, SPAN_WARNING("That mob is not in the game world any more."))
		return FALSE
	if (!config.allow_admin_jump)
		WWalert(C, "Admin jumping is disabled", "Admin Jump")
		return FALSE
	var/mob/observer/ghost/G = admin_ghost_of(C)
	if (!G)
		return FALSE
	var/turf/T = get_turf(M)
	if (!T)
		return FALSE
	log_admin("[key_name(C)] jumped to [key_name(M)] from the admin map")
	message_admins("[key_name_admin(C)] jumped to [key_name_admin(M)]", key_name_admin(C))
	G.on_mob_jump()
	G.loc = T
	return TRUE

/datum/admin_map_controller/proc/follow(client/C, mob/M)
	if (!istype(M) || !get_turf(M))
		to_chat(C, SPAN_WARNING("That mob is not in the game world any more."))
		return FALSE
	if (!config.allow_admin_jump)
		WWalert(C, "Admin jumping is disabled", "Admin Jump")
		return FALSE
	var/mob/observer/ghost/G = admin_ghost_of(C)
	if (!G)
		return FALSE
	log_admin("[key_name(C)] followed [key_name(M)] from the admin map")
	G.ManualFollow(M)
	return TRUE

/datum/admin_map_controller/proc/send_weather(client/C, kind, x, y)
	x = clamp(round(text2num("[x]")) || 1, 1, world.maxx)
	y = clamp(round(text2num("[y]")) || 1, 1, world.maxy)
	var/datum/weather_system/S
	if (kind == "heat")
		S = weather_system_spawn(WEATHER_SYSTEM_HEAT, FALSE, x, y, 600)
	else
		S = weather_system_spawn(WEATHER_SYSTEM_STORM, kind == "severe", x, y, 600)
	if (!S)
		to_chat(C, SPAN_WARNING("The sky already holds [WEATHER_SYSTEM_MAX] weather systems. End one first."))
		return FALSE
	var/label = kind == "heat" ? "heat wave" : (kind == "severe" ? "severe storm" : "storm")
	log_admin("[key_name(C)] sent a [label] toward [x],[y] from the admin map")
	message_admins("[key_name_admin(C)] sent a [label] toward [x],[y].", key_name_admin(C))
	return TRUE

/datum/admin_map_controller/proc/end_weather(client/C, id)
	for (var/datum/weather_system/S in weather_systems)
		if (S.id == id)
			weather_system_end(S)
			log_admin("[key_name(C)] ended weather system #[id] from the admin map")
			message_admins("[key_name_admin(C)] ended weather system #[id].", key_name_admin(C))
			return TRUE
	return FALSE

/datum/admin_map_controller/proc/clear_weather(client/C)
	weather_systems_clear()
	change_weather(WEATHER_NONE)
	log_admin("[key_name(C)] cleared the sky from the admin map")
	message_admins("[key_name_admin(C)] cleared all weather.", key_name_admin(C))

/datum/admin_map_controller/Topic(href, href_list)
	var/client/C = usr ? usr.client : null
	if (!C)
		return
	if (href_list["close"])
		viewers -= C
		return
	if (!admin_map_allowed(C))
		return
	var/action = href_list["am"]
	if (action == "z")
		open(C, href_list["z"])
		return
	if (action in list("show", "jump", "follow", "view"))
		if (!admin_map_sees_players(C))
			return
		var/mob/M = locate(href_list["m"])
		if (!istype(M))
			return
		switch (action)
			if ("show")
				var/turf/T = get_turf(M)
				if (T)
					open(C, T.z, "\ref[M]")
				else
					to_chat(C, SPAN_WARNING("[M] is not on the map."))
			if ("jump")
				jump_to(C, M)
			if ("follow")
				follow(C, M)
			if ("view")
				C.admin_start_player_view(M)
		return
	if (action in list("spawn", "end", "clear"))
		if (!admin_map_changes_weather(C))
			return
		switch (action)
			if ("spawn")
				send_weather(C, href_list["k"], href_list["x"], href_list["y"])
			if ("end")
				end_weather(C, text2num(href_list["id"]))
			if ("clear")
				clear_weather(C)
		refresh()

/datum/admin_map_controller/proc/level_labels()
	var/list/labels = list()
	for (var/z in 1 to world.maxz)
		var/turf/T = locate(1, 1, z)
		labels += T ? cartography_land_label(T) : ""
	return labels

/datum/admin_map_controller/proc/page_html(client/C, z, list/base, scale, select = null)
	var/list/html = list("<html><head><meta charset='utf-8'><title>Admin map</title>[admin_panel_css()]<style>")
	html += "canvas{border:2px solid #4c5f4a;image-rendering:pixelated;display:block;cursor:crosshair}"
	html += "button,select{background:#33402f;color:#d8e2d0;border:1px solid #5d7358;border-radius:3px;margin:2px 2px 2px 0;padding:3px 8px;cursor:pointer;font-family:inherit;font-size:12px}"
	html += "button:hover{background:#465a41;color:#fff}"
	html += "label{white-space:nowrap;margin-right:8px;cursor:pointer}"
	html += "#top{display:flex;flex-wrap:wrap;align-items:center;gap:4px 12px;margin-bottom:6px}"
	html += "#wrap{display:flex;gap:10px;align-items:flex-start}#side{width:300px;max-height:[max(560, base[3] * scale)]px;overflow-y:auto}"
	html += "#sel{min-height:64px}"
	html += ".rows div{padding:2px 4px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rows div:hover,.rows div.on{background:#33402f}"
	html += "input.q{width:100%;box-sizing:border-box;margin-bottom:4px}"
	html += ".k{display:inline-block;width:10px;height:10px;margin:0 3px 0 8px;border:1px solid #000;vertical-align:middle}"
	html += "</style></head><body>"
	html += "<div id='top'><h1>Admin map</h1><span>Level <select id='z' onchange='lvl(this.value)'></select></span><span>"
	html += "<label><input type='checkbox' id='lp' checked onclick='draw()'>Players</label>"
	html += "<label><input type='checkbox' id='og' onclick='draw()'>Ghosts</label>"
	html += "<label><input type='checkbox' id='on' onclick='draw()'>NPCs</label>"
	html += "<label><input type='checkbox' id='lw' checked onclick='draw()'>Weather</label>"
	html += "<label><input type='checkbox' id='lg' checked onclick='draw()'>Grid</label>"
	html += "<label><input type='checkbox' id='lwf' onclick='draw()'>Wind</label>"
	html += "</span><span>Air <select id='lay' onchange='LAY=this.value;draw()'><option value=''>off</option><option value='t'>temperature</option><option value='h'>humidity</option><option value='p'>pressure</option><option value='c'>cloud</option><option value='f'>fog</option></select></span>"
	html += "<span class='dim'>North is up. Refreshes every [AMAP_REFRESH / 10] seconds.</span></div>"
	html += "<div id='wrap'><div><canvas id='m' width='[base[2] * scale]' height='[base[3] * scale]'></canvas>"
	html += "<div id='legend' style='margin:6px 0 2px'></div><div id='s' class='dim'></div></div>"
	html += "<div id='side'><div class='card' id='sel'></div><div class='card' id='sky'></div>"
	html += "<div class='card'><h2 id='wh'>Weather</h2><div class='rows' id='wl'></div></div>"
	html += "<div class='card' id='pc'><h2 id='ph'>Players</h2><input class='q' id='q' type='text' placeholder='Search name or key'><div class='rows' id='list'></div></div>"
	html += "</div></div><script>"
	html += "var REF='\ref[src]',Z=[z],CELL=[base[1]],W=[base[2]],H=[base[3]],K=[scale],PICK=[admin_map_json(select)],"
	html += "T=[json_encode(base[4])],COL=[json_encode(cartography_colors())],LV=[admin_map_json(level_labels())],D=[admin_map_json(update_json(C, z), TRUE)];"
	html += admin_map_script()
	html += "</script></body></html>"
	return jointext(html, "")

// JSON safe to place inside a <script> block: a name holding "</script>"
// cannot end the block early.
/proc/admin_map_json(value, encoded = FALSE)
	return replacetext(encoded ? value : json_encode(value), "</", "<\\/")

// Client-side drawing. Raw string: no DM interpolation inside. Names and keys
// are set with textContent only, never as HTML.
/proc/admin_map_script()
	return @{"
var cv=document.getElementById('m'),g=cv.getContext('2d'),bg=document.createElement('canvas'),SEL=PICK||null,SYS=null,AT=null,LAY='',SIDES={},
PAL=['#e0302a','#3d7fe0','#3fbf4f','#f0d81c','#c050e0','#f08a1c','#30d0c8','#ff7fb0','#a0e060','#b08060'],
SN={y:'you',a:'alive',d:'down',x:'dead',s:'disconnected',g:'ghost',n:'NPC',m:'player mob',p:'player'};
bg.width=cv.width;bg.height=cv.height;
(function(){var b=bg.getContext('2d');for(var y=0;y<H;y++){for(var x=0;x<W;x++){b.fillStyle=COL[T.charAt(y*W+x)]||COL['0'];b.fillRect(x*K,(H-1-y)*K,K,K);}}})();
function px(tx){return (tx-0.5)/CELL*K;}
function py(ty){return (H-(ty-0.5)/CELL)*K;}
function el(t,txt){var e=document.createElement(t);if(txt!==undefined)e.textContent=txt;return e;}
function clear(n){while(n.firstChild)n.removeChild(n.firstChild);}
function line(p,txt){p.appendChild(document.createTextNode(txt));p.appendChild(el('br'));}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function link(q){window.location='byond://?'+q;}
function btn(t,f){var b=el('button',t);b.onclick=f;return b;}
function on(id){return !!document.getElementById(id).checked;}
function sideCol(s){if(!s)return '#d8e2d0';if(!SIDES[s]){var n=0;for(var k in SIDES)n++;SIDES[s]=PAL[n%PAL.length];}return SIDES[s];}
function shown(b){if(!on('lp'))return false;if(b[2]=='g')return on('og');if(b[2]=='n')return on('on');return true;}
function vis(){var r=[];for(var i=0;i<D.b.length;i++)if(shown(D.b[i]))r.push(D.b[i]);return r;}
function levels(){var s=document.getElementById('z');clear(s);
for(var i=0;i<LV.length;i++){var n=(D.c&&D.c[i])||0,o=el('option',(i+1)+': '+LV[i]+' ('+n+(n==1?' player)':' players)'));o.value=i+1;if(i+1==Z)o.selected=true;s.appendChild(o);}}
function kind(s){return s[1]=='heat'?'heat wave':(s[2]?'severe storm':'storm');}
function tint(s,a){return s[1]=='heat'?'rgba(240,120,30,'+a+')':(s[2]?'rgba(150,60,200,'+a+')':'rgba(40,90,220,'+a+')');}
function under(s,x,y){var dx=(x-s[3])/s[5],dy=(y-s[4])/s[6];return dx*dx+dy*dy<=1;}
function wx(x,y){var r=[];for(var i=0;i<D.s.length;i++)if(under(D.s[i],x,y))r.push('under #'+D.s[i][0]+' '+kind(D.s[i])+' ('+D.s[i][7]+'%)');return r.length?r.join(', '):'clear sky';}
function sys(){for(var i=0;i<D.s.length;i++)if(D.s[i][0]==SYS)return D.s[i];return null;}
function oval(x,y,rx,ry){g.save();g.translate(x,y);g.scale(1,ry/rx);g.beginPath();g.arc(0,0,rx,0,7);g.restore();}
function arrow(x,y,dx,dy,len,c){var n=Math.sqrt(dx*dx+dy*dy);if(!n)return;dx/=n;dy/=n;var ex=x+dx*len,ey=y-dy*len;
g.strokeStyle=c;g.fillStyle=c;g.lineWidth=2;g.beginPath();g.moveTo(x,y);g.lineTo(ex,ey);g.stroke();
g.beginPath();g.moveTo(ex,ey);g.lineTo(ex-dx*7+dy*4,ey+dy*7+dx*4);g.lineTo(ex-dx*7-dy*4,ey+dy*7-dx*4);g.closePath();g.fill();}
function grid(){g.strokeStyle='rgba(0,0,0,0.18)';g.lineWidth=1;var step=Math.max(1,Math.round(20/CELL));
for(var i=0;i<=W;i+=step){g.beginPath();g.moveTo(i*K+0.5,0);g.lineTo(i*K+0.5,H*K);g.stroke();}
for(var j=0;j<=H;j+=step){g.beginPath();g.moveTo(0,(H-j)*K+0.5);g.lineTo(W*K,(H-j)*K+0.5);g.stroke();}}
function weather(){var i;for(i=0;i<D.s.length;i++){var s=D.s[i],x=px(s[3]),y=py(s[4]),rx=s[5]/CELL*K,ry=s[6]/CELL*K,p=s[7]/100;
oval(x,y,rx,ry);g.fillStyle=tint(s,0.10+0.25*p);g.fill();
if(s[1]!='heat'){oval(x,y,rx*0.72,ry*0.72);g.fillStyle=tint(s,0.12+0.2*p);g.fill();oval(x,y,rx*0.4,ry*0.4);g.fillStyle=tint(s,0.15+0.25*p);g.fill();}
oval(x,y,rx,ry);g.strokeStyle=SYS==s[0]?'#fff':tint(s,0.9);g.lineWidth=SYS==s[0]?3:2;g.stroke();
arrow(x,y,s[8],s[9],Math.max(18,rx*0.6),'#fff');
g.fillStyle='#fff';g.font='bold 12px Verdana';g.fillText('#'+s[0],x+4,y-4);}
if(D.pc){for(i=0;i<D.pc.length;i++){var c=D.pc[i],cx=px(c[2]),cy=py(c[3]),lo=c[1]=='low';
oval(cx,cy,c[4]/CELL*K,c[4]/CELL*K);g.strokeStyle=lo?'rgba(220,60,60,0.8)':'rgba(60,120,240,0.8)';g.lineWidth=1;g.setLineDash([6,4]);g.stroke();g.setLineDash([]);
g.font='bold 22px Verdana';g.fillStyle=lo?'#e04040':'#4080f0';g.fillText(lo?'L':'H',cx-8,cy+8);g.font='11px Verdana';g.fillStyle='#fff';g.fillText((lo?'-':'+')+c[5]+' hPa',cx-18,cy+22);}}
arrow(30,cv.height-16,D.w[0],D.w[1],22,'#ffe680');}
function airfill(v){if(LAY=='t'){var f=Math.max(0,Math.min(1,(v+30)/75));return 'rgba('+Math.round(255*f)+','+Math.round(90+60*(1-Math.abs(f-0.5)*2))+','+Math.round(255*(1-f))+',0.45)';}
if(LAY=='h'){return 'rgba(30,140,230,'+(0.08+0.5*v/100)+')';}
if(LAY=='p'){var d=Math.max(-1,Math.min(1,(v-1013)/25));return d<0?'rgba(170,60,220,'+(0.1-0.45*d)+')':'rgba(240,170,40,'+(0.1+0.45*d)+')';}
if(LAY=='f'){return 'rgba(150,200,215,'+(0.03+0.7*v/100)+')';}
return 'rgba(235,235,235,'+(0.05+0.55*v/100)+')';}
function air(){if(!LAY||!D.a)return;var A=D.a,cols=A[0],rows=A[1],cs=A[2],f={t:3,h:4,p:5,c:6,f:9}[LAY],vals=A[f];if(!vals)return;
for(var r=0;r<rows;r++)for(var c=0;c<cols;c++){var v=vals[r*cols+c];g.fillStyle=airfill(v);var x0=px(c*cs+1),x1=px(c*cs+cs+1),y0=py(r*cs+cs+1),y1=py(r*cs+1);g.fillRect(x0,y0,x1-x0,y1-y0);}}
function airtip(tx,ty){if(!D.a)return null;var A=D.a,c=Math.max(0,Math.min(A[0]-1,Math.floor((tx-1)/A[2]))),r=Math.max(0,Math.min(A[1]-1,Math.floor((ty-1)/A[2]))),i=r*A[0]+c;
var t='Air here: '+A[3][i]+' C, '+A[4][i]+'% humidity, '+A[5][i]+' hPa, '+A[6][i]+'% cloud';
if(A[7])t+=', wind '+Math.round(Math.sqrt(A[7][i]*A[7][i]+A[8][i]*A[8][i]))+' m/s';if(A[9]&&A[9][i])t+=', '+A[9][i]+'% fog';return t;}
function winds(){if(!D.a||!D.a[7])return;var A=D.a,cols=A[0],rows=A[1],cs=A[2];
for(var r=0;r<rows;r++)for(var c=0;c<cols;c++){var i=r*cols+c,e=A[7][i],n=A[8][i],s=Math.sqrt(e*e+n*n);if(s<0.5)continue;
arrow(px(c*cs+cs/2+1),py(r*cs+cs/2+1),e,n,Math.min(cs*K*0.45,6+s*1.5),s>=14?'#ff7060':(s>=8?'#ffd060':'#e8f4ff'));}}
function tip(p,x,y){var t=airtip(x,y);if(t)line(p,t);}
function mark(b){var x=px(b[0]),y=py(b[1]),r=Math.max(3,Math.round(K*0.9)),c=sideCol(b[3]),st=b[2];
if(st=='p'){g.fillStyle='#000';g.fillRect(x-3,y-3,6,6);g.fillStyle='#f0d81c';g.fillRect(x-2,y-2,4,4);return;}
if(st=='g'){g.strokeStyle='#fff';g.lineWidth=2;g.beginPath();g.arc(x,y,r,0,7);g.stroke();return;}
if(st=='x'){g.strokeStyle='#000';g.lineWidth=4;g.beginPath();g.moveTo(x-r,y-r);g.lineTo(x+r,y+r);g.moveTo(x+r,y-r);g.lineTo(x-r,y+r);g.stroke();
g.strokeStyle=c;g.lineWidth=2;g.beginPath();g.moveTo(x-r,y-r);g.lineTo(x+r,y+r);g.moveTo(x+r,y-r);g.lineTo(x-r,y+r);g.stroke();return;}
if(st=='n')r=Math.max(2,r-1);if(st=='y')r+=1;
g.fillStyle='#000';g.fillRect(x-r-1,y-r-1,r*2+2,r*2+2);g.fillStyle=st=='d'?'#8a8a8a':(st=='y'?'#ffffff':c);g.fillRect(x-r,y-r,r*2,r*2);
if(st=='s'){g.fillStyle='#000';g.fillRect(x-r/2,y-r/2,r,r);}
if(st=='n'){g.fillStyle='rgba(0,0,0,0.45)';g.fillRect(x-r,y-r,r*2,r*2);}}
function draw(){g.drawImage(bg,0,0);air();if(on('lg'))grid();if(on('lw'))weather();if(on('lwf'))winds();
var v=vis(),i,sel=null;for(i=0;i<v.length;i++){mark(v[i]);if(SEL&&v[i][6]==SEL)sel=v[i];}
if(sel){var r=Math.max(9,K*2.5);g.strokeStyle='#fff';g.lineWidth=2;g.beginPath();g.arc(px(sel[0]),py(sel[1]),r,0,7);g.stroke();}
if(AT){g.strokeStyle='#fff';g.lineWidth=1;g.beginPath();g.moveTo(px(AT[0])-8,py(AT[1]));g.lineTo(px(AT[0])+8,py(AT[1]));g.moveTo(px(AT[0]),py(AT[1])-8);g.lineTo(px(AT[0]),py(AT[1])+8);g.stroke();}
legend();sky();panel(sel);wlist();list(v);
var n=0;for(i=0;i<D.b.length;i++)if('adxsyp'.indexOf(D.b[i][2])>=0)n++;
document.getElementById('s').textContent=n+' players on this level, '+v.length+' markers shown.';}
function key(l,c,t){var sw=el('span');sw.className='k';sw.style.background=c;l.appendChild(sw);l.appendChild(document.createTextNode(t));}
function legend(){var l=document.getElementById('legend'),c={},k;clear(l);
for(var i=0;i<D.b.length;i++){var s=D.b[i][3];if(s&&D.b[i][2]!='n'){sideCol(s);c[s]=(c[s]||0)+1;}}
for(k in c)key(l,SIDES[k],k+' ('+c[k]+')');
if(D.who){key(l,'#8a8a8a','down');l.appendChild(document.createTextNode('   X dead, dark centre disconnected, ring ghost, dim NPC'));}else key(l,'#f0d81c','player');
l.appendChild(el('br'));key(l,'rgb(40,90,220)','storm');key(l,'rgb(150,60,200)','severe storm');key(l,'rgb(240,120,30)','heat wave');key(l,'#ffe680','wind (arrow, bottom left)');
var AL={t:'Air: temperature, blue cold to red hot',h:'Air: humidity, bluer is wetter',p:'Air: pressure, purple low to amber high',c:'Air: cloud, whiter is thicker',f:'Air: fog, bluer-grey is thicker'};
if(LAY&&D.a){l.appendChild(el('br'));l.appendChild(document.createTextNode(AL[LAY]));}}
function sky(){var k=document.getElementById('sky');clear(k);k.appendChild(el('h2','Sky'));
line(k,'Season: '+D.season);line(k,'Wind: '+(D.w[3]||'none'));
line(k,'Systems: '+D.s.length+' (storms roll up to '+D.cap+' at once)');line(k,'Pinned zone weather: '+D.zone);line(k,'Pressure centres: '+(D.pc?D.pc.length:0)+' (red L low, blue H high)');
k.appendChild(el('span','The same sky is over every level.')).className='dim';
if(D.edit){k.appendChild(el('br'));k.appendChild(btn('Clear the sky',function(){go('am=clear');}));}}
function label(b){return b[4]+(b[5]?' ('+b[5]+')':'');}
function panel(b){var p=document.getElementById('sel'),s=sys(),i;clear(p);
if(b){p.appendChild(el('h2','Player'));p.appendChild(el('b',label(b)));p.appendChild(el('br'));
line(p,(b[3]?b[3]+', ':'')+SN[b[2]]+' at '+b[0]+', '+b[1]);line(p,'Weather here: '+wx(b[0],b[1]));tip(p,b[0],b[1]);
p.appendChild(btn('Jump',function(){go('am=jump&m='+encodeURIComponent(b[6]));}));
p.appendChild(btn('Follow',function(){go('am=follow&m='+encodeURIComponent(b[6]));}));
p.appendChild(btn('View',function(){go('am=view&m='+encodeURIComponent(b[6]));}));
p.appendChild(btn('PP',function(){link('_src_=holder&adminplayeropts='+encodeURIComponent(b[6]));}));
p.appendChild(btn('VV',function(){link('_src_=vars&Vars='+encodeURIComponent(b[6]));}));return;}
if(SEL){p.appendChild(el('h2','Player'));p.appendChild(document.createTextNode('Selected mob is not on this level now, or its layer is hidden.'));return;}
if(s){var u=[];for(i=0;i<D.b.length;i++)if('adxsyp'.indexOf(D.b[i][2])>=0&&under(s,D.b[i][0],D.b[i][1]))u.push(D.b[i][4]||'a player');
p.appendChild(el('h2','Weather system'));p.appendChild(el('b','#'+s[0]+' '+kind(s)));p.appendChild(el('br'));
line(p,'Centre '+s[3]+', '+s[4]+'; '+(s[5]*2)+' by '+(s[6]*2)+' tiles');line(p,'Strength '+s[7]+'%; '+s[10]+' min left');
line(p,u.length?(u.length+(u.length==1?' player':' players')+' under it on this level'+(D.who?': '+u.slice(0,6).join(', ')+(u.length>6?' and more':''):'')):'Nobody is under it on this level');
if(D.edit)p.appendChild(btn('End this system',function(){go('am=end&id='+s[0]);}));return;}
if(AT){p.appendChild(el('h2','Spot'));p.appendChild(el('b',AT[0]+', '+AT[1]));p.appendChild(el('br'));line(p,'Weather here: '+wx(AT[0],AT[1]));tip(p,AT[0],AT[1]);
if(D.edit){line(p,'Send here, arriving from upwind in about a minute:');
p.appendChild(btn('Storm',function(){go('am=spawn&k=storm&x='+AT[0]+'&y='+AT[1]);}));
p.appendChild(btn('Severe storm',function(){go('am=spawn&k=severe&x='+AT[0]+'&y='+AT[1]);}));
p.appendChild(btn('Heat wave',function(){go('am=spawn&k=heat&x='+AT[0]+'&y='+AT[1]);}));}return;}
p.appendChild(el('h2','Nothing picked'));
p.appendChild(document.createTextNode('Click a marker or a name to pick a player, a storm to pick it, or open ground to pick a spot'+(D.edit?' and send weather there.':'.')));}
function wlist(){var L=document.getElementById('wl');clear(L);document.getElementById('wh').textContent='Weather systems ('+D.s.length+')';
if(!D.s.length)L.appendChild(el('span','The sky is clear.')).className='dim';
for(var i=0;i<D.s.length;i++){(function(s){var d=el('div','#'+s[0]+' '+kind(s)+' at '+s[3]+', '+s[4]+' - '+s[7]+'%, '+s[10]+' min');d.style.borderLeft='6px solid '+tint(s,1);
if(s[0]==SYS)d.className='on';d.onclick=function(){pickSys(s[0]);};L.appendChild(d);})(D.s[i]);}}
function list(v){var L=document.getElementById('list'),q=(document.getElementById('q').value||'').toLowerCase();clear(L);
document.getElementById('pc').style.display=D.who?'':'none';if(!D.who)return;
var s=v.slice().sort(function(a,b){return a[4]<b[4]?-1:a[4]>b[4]?1:0;}),n=0;
for(var i=0;i<s.length;i++){if(q&&label(s[i]).toLowerCase().indexOf(q)<0)continue;n++;(function(b){var d=el('div',label(b)+' - '+SN[b[2]]);d.style.borderLeft='6px solid '+(b[2]=='g'?'#fff':sideCol(b[3]));
if(b[6]==SEL)d.className='on';d.onclick=function(){pick(b[6]);};L.appendChild(d);})(s[i]);}
document.getElementById('ph').textContent='Players and markers ('+n+')';}
function pick(r){SEL=r;SYS=null;AT=null;draw();}
function pickSys(id){SYS=id;SEL=null;AT=null;draw();}
function lvl(z){go('am=z&z='+z);}
function upd(s){try{D=JSON.parse(s);}catch(e){return;}levels();draw();}
cv.onclick=function(e){var rc=cv.getBoundingClientRect(),cx=e.clientX-rc.left,cy=e.clientY-rc.top,v=D.who?vis():[],best=null,bd=Math.max(12,K*2)*Math.max(12,K*2),i;
for(i=0;i<v.length;i++){var dx=px(v[i][0])-cx,dy=py(v[i][1])-cy,d=dx*dx+dy*dy;if(d<=bd){bd=d;best=v[i];}}
if(best){pick(best[6]);return;}
var tx=Math.max(1,Math.round(cx/K*CELL+0.5)),ty=Math.max(1,Math.round((H-cy/K)*CELL+0.5)),hit=null;
if(on('lw'))for(i=0;i<D.s.length;i++){var s=D.s[i],ex=(tx-s[3])/(s[5]*0.4),ey=(ty-s[4])/(s[6]*0.4);if(ex*ex+ey*ey<=1)hit=s[0];}
if(hit!==null){pickSys(hit);return;}
SEL=null;SYS=null;AT=[tx,ty];draw();};
document.getElementById('q').onkeyup=draw;
levels();draw();
"}

#undef AMAP_REFRESH
#undef AMAP_WINDOW
