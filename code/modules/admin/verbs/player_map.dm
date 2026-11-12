// Admin player map.
//
// Staff open a live map of any level with every player on it marked, coloured
// by side. It reuses the tactical map's terrain sampling and canvas drawing
// (code/modules/1713/tactical_map.dm), so every map works without new art.
// Clicking a marker or a name selects that mob; the panel can then jump to it,
// follow it as a ghost, share its camera, or open its player panel or variables.

#define APMAP_REFRESH 20 // deciseconds between live updates
#define APMAP_WINDOW "adminpmap"

var/global/datum/admin_player_map_controller/admin_player_maps = new

/datum/admin_player_map_controller
	var/list/viewers = list() // client = level they are watching
	var/refresh_timer // looping refresh while anyone is watching

/proc/admin_player_map_allowed(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_MOD))

/client/proc/admin_player_map()
	set category = "Admin"
	set name = "Player Map"
	set desc = "Open a live map of a level with every player on it marked."
	if (!check_rights(R_ADMIN|R_MOD))
		return
	var/turf/T = get_turf(mob)
	admin_player_maps.open(src, T ? T.z : 1)

// The side label shown for a mob: civilization on maps with civilizations,
// else faction. "" for mobs without one.
/proc/admin_player_map_side(mob/M)
	var/side = tactical_map_side(M)
	if (!side)
		return ""
	return copytext(side, findtext(side, ":") + 1)

// Everyone of interest on level z, as list(x, y, state, side, name, ckey, ref).
// States: y = the viewer, a = alive player, d = down, x = dead body with a
// player, s = disconnected body, g = ghost, n = NPC human, m = other mob a
// player controls.
/datum/admin_player_map_controller/proc/blips_for(z, client/viewer)
	var/list/blips = list()
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
		blips[++blips.len] = list(T.x, T.y, state, admin_player_map_side(H), H.real_name, H.ckey || "", "\ref[H]")
	for (var/mob/M in player_list)
		if (seen[M] || isnewplayer(M))
			continue
		var/turf/T = get_turf(M)
		if (!T || T.z != z)
			continue
		var/state = isghost(M) ? "g" : "m"
		if (viewer && M == viewer.mob)
			state = "y"
		blips[++blips.len] = list(T.x, T.y, state, admin_player_map_side(M), M.real_name || M.name, M.ckey || "", "\ref[M]")
	return blips

// Players (not NPCs or ghosts) on each level, for the level picker.
/datum/admin_player_map_controller/proc/level_counts()
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

/datum/admin_player_map_controller/proc/open(client/C, z)
	if (!admin_player_map_allowed(C))
		return
	z = clamp(round(text2num("[z]")) || 1, 1, world.maxz)
	var/list/base = tactical_maps.terrain_for(z)
	var/scale = clamp(round(760 / max(base[2], base[3])), 2, 8)
	var/width = base[2] * scale
	var/height = base[3] * scale
	viewers[C] = z
	show_browse(C, page_html(C, z, base, scale), "window=[APMAP_WINDOW];size=[min(1180, max(width, 600) + 300)]x[min(1000, height + 170)]")
	if (C.mob)
		onclose(C.mob, APMAP_WINDOW, src)
	start()

/datum/admin_player_map_controller/proc/start()
	if (refresh_timer)
		return
	refresh_timer = addtimer(CALLBACK(src, PROC_REF(tick)), APMAP_REFRESH, TIMER_LOOP | TIMER_STOPPABLE)

/datum/admin_player_map_controller/proc/tick()
	refresh()
	if (!viewers.len && refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null

// Pushes fresh positions to every viewer. Each level is gathered once per tick.
/datum/admin_player_map_controller/proc/refresh()
	for (var/client/C in viewers.Copy())
		if (!admin_player_map_allowed(C))
			viewers -= C
			if (C)
				show_browse(C, null, "window=[APMAP_WINDOW]")
			continue
		send_update(C, viewers[C])
		CHECK_TICK
	for (var/key in viewers.Copy())
		if (!key)
			viewers -= key

/datum/admin_player_map_controller/proc/update_json(client/C, z)
	return json_encode(list("b" = blips_for(z, C), "c" = level_counts()))

/datum/admin_player_map_controller/proc/send_update(client/C, z)
	C << output(list2params(list(update_json(C, z))), "[APMAP_WINDOW].browser:upd")

// Ghosts the admin if needed and returns their ghost, or null.
/datum/admin_player_map_controller/proc/admin_ghost_of(client/C)
	if (!C || !C.mob)
		return null
	if (!isghost(C.mob))
		C.admin_ghost()
		sleep(2)
	return isghost(C.mob) ? C.mob : null

/datum/admin_player_map_controller/proc/jump_to(client/C, mob/M)
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
	log_admin("[key_name(C)] jumped to [key_name(M)] from the player map")
	message_admins("[key_name_admin(C)] jumped to [key_name_admin(M)]", key_name_admin(C))
	G.on_mob_jump()
	G.loc = T
	return TRUE

/datum/admin_player_map_controller/proc/follow(client/C, mob/M)
	if (!istype(M) || !get_turf(M))
		to_chat(C, SPAN_WARNING("That mob is not in the game world any more."))
		return FALSE
	if (!config.allow_admin_jump)
		WWalert(C, "Admin jumping is disabled", "Admin Jump")
		return FALSE
	var/mob/observer/ghost/G = admin_ghost_of(C)
	if (!G)
		return FALSE
	log_admin("[key_name(C)] followed [key_name(M)] from the player map")
	G.ManualFollow(M)
	return TRUE

/datum/admin_player_map_controller/Topic(href, href_list)
	var/client/C = usr ? usr.client : null
	if (!C)
		return
	if (href_list["close"])
		viewers -= C
		return
	if (!admin_player_map_allowed(C))
		return
	switch (href_list["apm"])
		if ("z")
			open(C, href_list["z"])
		if ("jump")
			jump_to(C, locate(href_list["m"]))
		if ("follow")
			follow(C, locate(href_list["m"]))
		if ("view")
			var/mob/M = locate(href_list["m"])
			if (istype(M))
				C.admin_start_player_view(M)

/datum/admin_player_map_controller/proc/level_labels()
	var/list/labels = list()
	for (var/z in 1 to world.maxz)
		var/turf/T = locate(1, 1, z)
		labels += T ? cartography_land_label(T) : ""
	return labels

/datum/admin_player_map_controller/proc/page_html(client/C, z, list/base, scale)
	var/list/html = list("<html><head><meta charset='utf-8'><title>Player map</title><style>")
	html += "body{background:#1d2420;color:#d8e2d0;font-family:Verdana,sans-serif;font-size:12px;margin:10px}"
	html += "canvas{border:2px solid #4c5f4a;image-rendering:pixelated;display:block;cursor:pointer}"
	html += "button,select{background:#33402f;color:#d8e2d0;border:1px solid #5d7358;margin:2px;padding:3px 7px;cursor:pointer}"
	html += "#wrap{display:flex;gap:10px;align-items:flex-start}#side{width:270px;max-height:[max(300, base[3] * scale)]px;overflow-y:auto}"
	html += "#sel{border:1px solid #4c5f4a;padding:6px;margin-bottom:6px;min-height:52px}"
	html += "#list div{padding:2px 3px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}#list div:hover,#list div.on{background:#33402f}"
	html += ".k{display:inline-block;width:10px;height:10px;margin:0 3px 0 8px;border:1px solid #000}"
	html += "</style></head><body>"
	html += "<b>Player map</b> - level <select id='z' onchange='lvl(this.value)'></select> "
	html += "<label><input type='checkbox' id='og' onclick='draw()'>ghosts</label> "
	html += "<label><input type='checkbox' id='on' onclick='draw()'>NPCs</label> "
	html += " - North is up. Refreshes every [APMAP_REFRESH / 10] seconds.<br>"
	html += "<div id='legend' style='margin:4px 0'></div>"
	html += "<div id='wrap'><canvas id='m' width='[base[2] * scale]' height='[base[3] * scale]'></canvas>"
	html += "<div id='side'><div id='sel'>Click a marker or a name.</div><div id='list'></div></div></div>"
	html += "<div id='s' style='margin-top:6px;color:#aab8a2'></div><script>"
	html += "var REF='\ref[src]',Z=[z],CELL=[base[1]],W=[base[2]],H=[base[3]],K=[scale],"
	html += "T=[json_encode(base[4])],COL=[json_encode(cartography_colors())],LV=[admin_player_map_json(level_labels())],D=[admin_player_map_json(update_json(C, z), TRUE)];"
	html += admin_player_map_script()
	html += "</script></body></html>"
	return jointext(html, "")

// JSON safe to place inside a <script> block: a name holding "</script>"
// cannot end the block early.
/proc/admin_player_map_json(value, encoded = FALSE)
	return replacetext(encoded ? value : json_encode(value), "</", "<\\/")

// Client-side drawing. Raw string: no DM interpolation inside. Names and keys
// are set with textContent only, never as HTML.
/proc/admin_player_map_script()
	return @{"
var cv=document.getElementById('m'),g=cv.getContext('2d'),bg=document.createElement('canvas'),SEL=null,SIDES={},
PAL=['#e0302a','#3d7fe0','#3fbf4f','#f0d81c','#c050e0','#f08a1c','#30d0c8','#ff7fb0','#a0e060','#b08060'],
SN={y:'you',a:'alive',d:'down',x:'dead',s:'disconnected',g:'ghost',n:'NPC',m:'player mob'};
bg.width=cv.width;bg.height=cv.height;
(function(){var b=bg.getContext('2d');for(var y=0;y<H;y++){for(var x=0;x<W;x++){b.fillStyle=COL[T.charAt(y*W+x)]||COL['0'];b.fillRect(x*K,(H-1-y)*K,K,K);}}
b.strokeStyle='rgba(0,0,0,0.18)';b.lineWidth=1;var step=Math.max(1,Math.round(20/CELL));
for(var i=0;i<=W;i+=step){b.beginPath();b.moveTo(i*K+0.5,0);b.lineTo(i*K+0.5,H*K);b.stroke();}
for(var j=0;j<=H;j+=step){b.beginPath();b.moveTo(0,(H-j)*K+0.5);b.lineTo(W*K,(H-j)*K+0.5);b.stroke();}})();
function px(tx){return (tx-0.5)/CELL*K;}
function py(ty){return (H-(ty-0.5)/CELL)*K;}
function el(t,txt){var e=document.createElement(t);if(txt!==undefined)e.textContent=txt;return e;}
function sideCol(s){if(!s)return '#d8e2d0';if(!SIDES[s]){var n=0;for(var k in SIDES)n++;SIDES[s]=PAL[n%PAL.length];}return SIDES[s];}
function shown(b){if(b[2]=='g')return document.getElementById('og').checked;if(b[2]=='n')return document.getElementById('on').checked;return true;}
function vis(){var r=[];for(var i=0;i<D.b.length;i++)if(shown(D.b[i]))r.push(D.b[i]);return r;}
function levels(){var s=document.getElementById('z');while(s.firstChild)s.removeChild(s.firstChild);
for(var i=0;i<LV.length;i++){var n=(D.c&&D.c[i])||0,o=el('option',(i+1)+': '+LV[i]+' ('+n+(n==1?' player)':' players)'));o.value=i+1;if(i+1==Z)o.selected=true;s.appendChild(o);}}
function mark(b){var x=px(b[0]),y=py(b[1]),r=Math.max(3,Math.round(K*0.9)),c=sideCol(b[3]),st=b[2];
if(st=='g'){g.strokeStyle='#fff';g.lineWidth=2;g.beginPath();g.arc(x,y,r,0,7);g.stroke();return;}
if(st=='x'){g.strokeStyle='#000';g.lineWidth=4;g.beginPath();g.moveTo(x-r,y-r);g.lineTo(x+r,y+r);g.moveTo(x+r,y-r);g.lineTo(x-r,y+r);g.stroke();
g.strokeStyle=c;g.lineWidth=2;g.beginPath();g.moveTo(x-r,y-r);g.lineTo(x+r,y+r);g.moveTo(x+r,y-r);g.lineTo(x-r,y+r);g.stroke();return;}
if(st=='n')r=Math.max(2,r-1);if(st=='y')r+=1;
g.fillStyle='#000';g.fillRect(x-r-1,y-r-1,r*2+2,r*2+2);g.fillStyle=st=='d'?'#8a8a8a':(st=='y'?'#ffffff':c);g.fillRect(x-r,y-r,r*2,r*2);
if(st=='s'){g.fillStyle='#000';g.fillRect(x-r/2,y-r/2,r,r);}
if(st=='n'){g.fillStyle='rgba(0,0,0,0.45)';g.fillRect(x-r,y-r,r*2,r*2);}}
function draw(){g.drawImage(bg,0,0);var v=vis(),i,sel=null;for(i=0;i<v.length;i++){mark(v[i]);if(SEL&&v[i][6]==SEL)sel=v[i];}
if(sel){var r=Math.max(9,K*2.5);g.strokeStyle='#fff';g.lineWidth=2;g.beginPath();g.arc(px(sel[0]),py(sel[1]),r,0,7);g.stroke();}
legend();list(v);panel(sel);
var n=0;for(i=0;i<D.b.length;i++)if('adxsy'.indexOf(D.b[i][2])>=0)n++;
document.getElementById('s').textContent=n+' players on this level, '+v.length+' markers shown.';}
function legend(){var l=document.getElementById('legend'),c={},k;while(l.firstChild)l.removeChild(l.firstChild);
for(var i=0;i<D.b.length;i++){var s=D.b[i][3];if(s&&D.b[i][2]!='n'){sideCol(s);c[s]=(c[s]||0)+1;}}
for(k in c){var sw=el('span');sw.className='k';sw.style.background=SIDES[k];l.appendChild(sw);l.appendChild(document.createTextNode(k+' ('+c[k]+')'));}
var g1=el('span');g1.className='k';g1.style.background='#8a8a8a';l.appendChild(g1);l.appendChild(document.createTextNode('down'));
l.appendChild(document.createTextNode('   X dead, dark centre disconnected, ring ghost, dim NPC'));}
function label(b){return b[4]+(b[5]?' ('+b[5]+')':'');}
function list(v){var L=document.getElementById('list');while(L.firstChild)L.removeChild(L.firstChild);
var s=v.slice().sort(function(a,b){return a[4]<b[4]?-1:a[4]>b[4]?1:0;});
for(var i=0;i<s.length;i++){(function(b){var d=el('div',label(b)+' - '+SN[b[2]]);d.style.borderLeft='6px solid '+(b[2]=='g'?'#fff':sideCol(b[3]));
if(b[6]==SEL)d.className='on';d.onclick=function(){pick(b[6]);};L.appendChild(d);})(s[i]);}}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function link(q){window.location='byond://?'+q;}
function btn(t,f){var b=el('button',t);b.onclick=f;return b;}
function panel(b){var p=document.getElementById('sel');while(p.firstChild)p.removeChild(p.firstChild);
if(!b){p.appendChild(document.createTextNode(SEL?'Selected mob is not on this level now.':'Click a marker or a name.'));return;}
var h=el('b',label(b));p.appendChild(h);p.appendChild(el('br'));
p.appendChild(document.createTextNode((b[3]?b[3]+', ':'')+SN[b[2]]+' at '+b[0]+', '+b[1]));p.appendChild(el('br'));
p.appendChild(btn('Jump',function(){go('apm=jump&m='+encodeURIComponent(b[6]));}));
p.appendChild(btn('Follow',function(){go('apm=follow&m='+encodeURIComponent(b[6]));}));
p.appendChild(btn('View',function(){go('apm=view&m='+encodeURIComponent(b[6]));}));
p.appendChild(btn('PP',function(){link('_src_=holder&adminplayeropts='+encodeURIComponent(b[6]));}));
p.appendChild(btn('VV',function(){link('_src_=vars&Vars='+encodeURIComponent(b[6]));}));}
function pick(r){SEL=r;draw();}
function lvl(z){go('apm=z&z='+z);}
function upd(s){try{D=JSON.parse(s);}catch(e){return;}levels();draw();}
cv.onclick=function(e){var rc=cv.getBoundingClientRect(),cx=e.clientX-rc.left,cy=e.clientY-rc.top,v=vis(),best=null,bd=Math.max(12,K*2)*Math.max(12,K*2);
for(var i=0;i<v.length;i++){var dx=px(v[i][0])-cx,dy=py(v[i][1])-cy,d=dx*dx+dy*dy;if(d<=bd){bd=d;best=v[i];}}
pick(best?best[6]:null);};
levels();draw();
"}

#undef APMAP_REFRESH
#undef APMAP_WINDOW
