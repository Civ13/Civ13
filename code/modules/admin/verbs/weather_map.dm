// Admin weather map.
//
// Staff open a live map of a level with every weather system drawn on it: its
// oval, how strong it is, where it is heading, and the wind. Clicking the map
// picks a spot or a system; the buttons send a storm or a heat wave over the
// spot, end the picked system, or clear the sky. It reuses the tactical map's
// terrain sampling, like the player map (player_map.dm).

#define WMAP_REFRESH 30 // deciseconds between live updates
#define WMAP_WINDOW "adminwmap"

var/global/datum/admin_weather_map_controller/admin_weather_maps = new

/datum/admin_weather_map_controller
	var/list/viewers = list() // client = level they are watching
	var/refresh_timer

/proc/admin_weather_map_allowed(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_MOD|R_DEBUG))

/proc/admin_weather_map_can_change(client/C)
	return C && C.holder && (C.holder.rights & (R_ADMIN|R_DEBUG))

/client/proc/admin_weather_map()
	set category = "Admin"
	set name = "Weather Map"
	set desc = "Open a live map of the weather systems over a level, and send or end storms."
	if (!admin_weather_map_allowed(src))
		return
	var/turf/T = get_turf(mob)
	admin_weather_maps.open(src, T ? T.z : 1)

/datum/admin_weather_map_controller/proc/open(client/C, z)
	if (!admin_weather_map_allowed(C))
		return
	z = clamp(round(text2num("[z]")) || 1, 1, world.maxz)
	var/list/base = tactical_maps.terrain_for(z)
	var/scale = clamp(round(760 / max(base[2], base[3])), 2, 8)
	viewers[C] = z
	show_browse(C, page_html(C, z, base, scale), "window=[WMAP_WINDOW];size=[min(1180, max(base[2] * scale, 600) + 300)]x[min(1000, base[3] * scale + 170)]")
	if (C.mob)
		onclose(C.mob, WMAP_WINDOW, src)
	if (!refresh_timer)
		refresh_timer = addtimer(CALLBACK(src, PROC_REF(tick)), WMAP_REFRESH, TIMER_LOOP | TIMER_STOPPABLE)

/datum/admin_weather_map_controller/proc/tick()
	for (var/client/C in viewers.Copy())
		if (!admin_weather_map_allowed(C))
			viewers -= C
			if (C)
				show_browse(C, null, "window=[WMAP_WINDOW]")
			continue
		C << output(list2params(list(update_json(C, viewers[C]))), "[WMAP_WINDOW].browser:upd")
	for (var/key in viewers.Copy())
		if (!key)
			viewers -= key
	if (!viewers.len && refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null

// Systems as list(id, kind, severe, x, y, radius x, radius y, strength %,
// heading x, heading y, minutes left); players on the level as list(x, y).
/datum/admin_weather_map_controller/proc/update_json(client/C, z)
	var/list/systems = list()
	for (var/datum/weather_system/S in weather_systems)
		systems[++systems.len] = list(S.id, S.kind, S.severe ? 1 : 0, round(S.centre_x()), round(S.centre_y()), round(S.radius_x), round(S.radius_y), round(S.power() * 100), S.vel_x, S.vel_y, max(0, round((S.lifetime - (world.time - S.born)) / 600)))
	var/list/players = list()
	for (var/mob/M in player_list)
		if (isnewplayer(M) || isghost(M))
			continue
		var/turf/T = get_turf(M)
		if (T && T.z == z)
			players[++players.len] = list(T.x, T.y)
	var/list/wind = weather_wind_vector()
	var/zone = "none"
	switch (weather)
		if (WEATHER_WET)
			zone = "wet, strength [weather_intensity]"
		if (WEATHER_EXTREME)
			zone = "extreme, strength [weather_intensity]"
		if (WEATHER_SMOG)
			zone = "smog"
	return json_encode(list("s" = systems, "p" = players, "w" = list(wind[1], wind[2], map ? map.windspeedvar : 1, map ? map.winddesc : ""), "zone" = zone, "season" = season ? "[season]" : "none", "cap" = weather_system_capacity(), "edit" = admin_weather_map_can_change(C) ? 1 : 0))

/datum/admin_weather_map_controller/Topic(href, href_list)
	var/client/C = usr ? usr.client : null
	if (!C)
		return
	if (href_list["close"])
		viewers -= C
		return
	if (!admin_weather_map_allowed(C))
		return
	if (href_list["wm"] == "z")
		open(C, href_list["z"])
		return
	if (!admin_weather_map_can_change(C))
		return
	switch (href_list["wm"])
		if ("spawn")
			var/x = clamp(round(text2num(href_list["x"])) || 1, 1, world.maxx)
			var/y = clamp(round(text2num(href_list["y"])) || 1, 1, world.maxy)
			var/kind = href_list["k"]
			var/datum/weather_system/S
			if (kind == "heat")
				S = weather_system_spawn(WEATHER_SYSTEM_HEAT, FALSE, x, y, 600)
			else
				S = weather_system_spawn(WEATHER_SYSTEM_STORM, kind == "severe", x, y, 600)
			if (!S)
				to_chat(C, SPAN_WARNING("The sky already holds [WEATHER_SYSTEM_MAX] weather systems. End one first."))
				return
			log_admin("[key_name(C)] sent a [kind == "heat" ? "heat wave" : (kind == "severe" ? "severe storm" : "storm")] toward [x],[y] from the weather map")
			message_admins("[key_name_admin(C)] sent a [kind == "heat" ? "heat wave" : (kind == "severe" ? "severe storm" : "storm")] toward [x],[y].", key_name_admin(C))
		if ("end")
			var/id = text2num(href_list["id"])
			for (var/datum/weather_system/S in weather_systems)
				if (S.id == id)
					weather_system_end(S)
					log_admin("[key_name(C)] ended weather system #[id] from the weather map")
					message_admins("[key_name_admin(C)] ended weather system #[id].", key_name_admin(C))
					break
		if ("clear")
			weather_systems_clear()
			change_weather(WEATHER_NONE)
			log_admin("[key_name(C)] cleared the sky from the weather map")
			message_admins("[key_name_admin(C)] cleared all weather.", key_name_admin(C))
	tick()

/datum/admin_weather_map_controller/proc/page_html(client/C, z, list/base, scale)
	var/list/html = list("<html><head><meta charset='utf-8'><title>Weather map</title><style>")
	html += "body{background:#1d2420;color:#d8e2d0;font-family:Verdana,sans-serif;font-size:12px;margin:10px}"
	html += "canvas{border:2px solid #4c5f4a;image-rendering:pixelated;display:block;cursor:crosshair}"
	html += "button,select{background:#33402f;color:#d8e2d0;border:1px solid #5d7358;margin:2px;padding:3px 7px;cursor:pointer}"
	html += "#wrap{display:flex;gap:10px;align-items:flex-start}#side{width:270px}"
	html += "#sel,#sky{border:1px solid #4c5f4a;padding:6px;margin-bottom:6px;min-height:40px}"
	html += "#list div{padding:2px 3px;cursor:pointer}#list div:hover,#list div.on{background:#33402f}"
	html += "</style></head><body>"
	html += "<b>Weather map</b> - level <select id='z' onchange='lvl(this.value)'></select>"
	html += " - North is up. Refreshes every [WMAP_REFRESH / 10] seconds. Weather is the same sky over every level.<br>"
	html += "<div id='wrap'><canvas id='m' width='[base[2] * scale]' height='[base[3] * scale]'></canvas>"
	html += "<div id='side'><div id='sky'></div><div id='sel'></div><div id='list'></div></div></div><script>"
	html += "var REF='\ref[src]',Z=[z],ZMAX=[world.maxz],CELL=[base[1]],W=[base[2]],H=[base[3]],K=[scale],"
	html += "T=[json_encode(base[4])],COL=[json_encode(cartography_colors())],D=[admin_player_map_json(update_json(C, z), TRUE)];"
	html += admin_weather_map_script()
	html += "</script></body></html>"
	return jointext(html, "")

// Client-side drawing. Raw string: no DM interpolation inside. Text is set
// with textContent only, never as HTML.
/proc/admin_weather_map_script()
	return @{"
var cv=document.getElementById('m'),g=cv.getContext('2d'),bg=document.createElement('canvas'),SEL=null,AT=null;
bg.width=cv.width;bg.height=cv.height;
(function(){var b=bg.getContext('2d');for(var y=0;y<H;y++){for(var x=0;x<W;x++){b.fillStyle=COL[T.charAt(y*W+x)]||COL['0'];b.fillRect(x*K,(H-1-y)*K,K,K);}}})();
function px(tx){return (tx-0.5)/CELL*K;}
function py(ty){return (H-(ty-0.5)/CELL)*K;}
function el(t,txt){var e=document.createElement(t);if(txt!==undefined)e.textContent=txt;return e;}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function btn(t,f){var b=el('button',t);b.onclick=f;return b;}
function clear(n){while(n.firstChild)n.removeChild(n.firstChild);}
function kind(s){return s[1]=='heat'?'heat wave':(s[2]?'severe storm':'storm');}
function tint(s,a){return s[1]=='heat'?'rgba(240,120,30,'+a+')':(s[2]?'rgba(150,60,200,'+a+')':'rgba(40,90,220,'+a+')');}
function oval(x,y,rx,ry){g.save();g.translate(x,y);g.scale(1,ry/rx);g.beginPath();g.arc(0,0,rx,0,7);g.restore();}
function arrow(x,y,dx,dy,len,c){var n=Math.sqrt(dx*dx+dy*dy);if(!n)return;dx/=n;dy/=n;var ex=x+dx*len,ey=y-dy*len;
g.strokeStyle=c;g.fillStyle=c;g.lineWidth=2;g.beginPath();g.moveTo(x,y);g.lineTo(ex,ey);g.stroke();
g.beginPath();g.moveTo(ex,ey);g.lineTo(ex-dx*7+dy*4,ey+dy*7+dx*4);g.lineTo(ex-dx*7-dy*4,ey+dy*7-dx*4);g.closePath();g.fill();}
function levels(){var s=document.getElementById('z');clear(s);for(var i=1;i<=ZMAX;i++){var o=el('option','level '+i);o.value=i;if(i==Z)o.selected=true;s.appendChild(o);}}
function draw(){g.drawImage(bg,0,0);var i,s;
for(i=0;i<D.s.length;i++){s=D.s[i];var x=px(s[3]),y=py(s[4]),rx=s[5]/CELL*K,ry=s[6]/CELL*K,p=s[7]/100;
oval(x,y,rx,ry);g.fillStyle=tint(s,0.10+0.25*p);g.fill();
if(s[1]!='heat'){oval(x,y,rx*0.72,ry*0.72);g.fillStyle=tint(s,0.12+0.2*p);g.fill();oval(x,y,rx*0.4,ry*0.4);g.fillStyle=tint(s,0.15+0.25*p);g.fill();}
oval(x,y,rx,ry);g.strokeStyle=SEL==s[0]?'#fff':tint(s,0.9);g.lineWidth=SEL==s[0]?3:2;g.stroke();
arrow(x,y,s[8],s[9],Math.max(18,rx*0.6),'#fff');
g.fillStyle='#fff';g.font='bold 12px Verdana';g.fillText('#'+s[0],x+4,y-4);}
for(i=0;i<D.p.length;i++){g.fillStyle='#000';g.fillRect(px(D.p[i][0])-3,py(D.p[i][1])-3,6,6);g.fillStyle='#f0d81c';g.fillRect(px(D.p[i][0])-2,py(D.p[i][1])-2,4,4);}
if(AT){g.strokeStyle='#fff';g.lineWidth=1;g.beginPath();g.moveTo(px(AT[0])-8,py(AT[1]));g.lineTo(px(AT[0])+8,py(AT[1]));g.moveTo(px(AT[0]),py(AT[1])-8);g.lineTo(px(AT[0]),py(AT[1])+8);g.stroke();}
arrow(30,cv.height-16,D.w[0],D.w[1],22,'#ffe680');
sky();panel();list();}
function sky(){var k=document.getElementById('sky');clear(k);
k.appendChild(el('b','Sky'));k.appendChild(el('br'));
k.appendChild(document.createTextNode('Season: '+D.season));k.appendChild(el('br'));
k.appendChild(document.createTextNode('Wind: '+(D.w[3]||'none')+' (yellow arrow)'));k.appendChild(el('br'));
k.appendChild(document.createTextNode('Systems: '+D.s.length+' (storms roll up to '+D.cap+' at once)'));k.appendChild(el('br'));
k.appendChild(document.createTextNode('Pinned zone weather: '+D.zone));k.appendChild(el('br'));
k.appendChild(document.createTextNode('Yellow squares are players. Blue storm, purple severe storm, orange heat wave.'));
if(D.edit){k.appendChild(el('br'));k.appendChild(btn('Clear the sky',function(){go('wm=clear');}));}}
function panel(){var p=document.getElementById('sel');clear(p);var s=null;for(var i=0;i<D.s.length;i++)if(D.s[i][0]==SEL)s=D.s[i];
if(s){p.appendChild(el('b','#'+s[0]+' '+kind(s)));p.appendChild(el('br'));
p.appendChild(document.createTextNode('Centre '+s[3]+', '+s[4]+'; '+(s[5]*2)+' by '+(s[6]*2)+' tiles; strength '+s[7]+'%; '+s[10]+' min left'));p.appendChild(el('br'));
if(D.edit)p.appendChild(btn('End this system',function(){go('wm=end&id='+s[0]);}));return;}
if(AT){p.appendChild(el('b','Spot '+AT[0]+', '+AT[1]));p.appendChild(el('br'));
if(D.edit){p.appendChild(document.createTextNode('Send here, arriving from upwind in about a minute:'));p.appendChild(el('br'));
p.appendChild(btn('Storm',function(){go('wm=spawn&k=storm&x='+AT[0]+'&y='+AT[1]);}));
p.appendChild(btn('Severe storm',function(){go('wm=spawn&k=severe&x='+AT[0]+'&y='+AT[1]);}));
p.appendChild(btn('Heat wave',function(){go('wm=spawn&k=heat&x='+AT[0]+'&y='+AT[1]);}));}return;}
p.appendChild(document.createTextNode('Click a system to pick it, or a spot on the map to send weather there.'));}
function list(){var L=document.getElementById('list');clear(L);for(var i=0;i<D.s.length;i++){(function(s){
var d=el('div','#'+s[0]+' '+kind(s)+' at '+s[3]+', '+s[4]+' - '+s[7]+'%, '+s[10]+' min');d.style.borderLeft='6px solid '+tint(s,1);
if(s[0]==SEL)d.className='on';d.onclick=function(){SEL=s[0];AT=null;draw();};L.appendChild(d);})(D.s[i]);}}
function lvl(z){go('wm=z&z='+z);}
function upd(s){try{D=JSON.parse(s);}catch(e){return;}draw();}
cv.onclick=function(e){var rc=cv.getBoundingClientRect(),cx=e.clientX-rc.left,cy=e.clientY-rc.top,tx=Math.round(cx/K*CELL+0.5),ty=Math.round((H-cy/K)*CELL+0.5),best=null;
for(var i=0;i<D.s.length;i++){var s=D.s[i],dx=(tx-s[3])/(s[5]*0.4),dy=(ty-s[4])/(s[6]*0.4);if(dx*dx+dy*dy<=1)best=s[0];}
SEL=best;AT=best?null:[Math.max(1,tx),Math.max(1,ty)];draw();};
levels();draw();
"}

#undef WMAP_REFRESH
#undef WMAP_WINDOW
