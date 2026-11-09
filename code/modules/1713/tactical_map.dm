// Live tactical map for commanders.
//
// Officers and commanders open a map of the level they stand on that shows
// where their own side is right now (refreshed every few seconds) and the
// markers their officers have drawn on it. Squad leaders can read the map but
// not draw on it. Nobody sees the other side's positions or markers.
//
// Design reference: CM-SS13's tactical map (code/controllers/subsystem/minimap.dm
// and code/datums/components/tacmap.dm, https://github.com/cmss13-devs/cmss13,
// AGPL-3.0). This is a reimplementation for Civ13: no CM-SS13 code or art is
// copied. Instead of pre-rendered map images, the base layer is sampled from the
// live map with the cartography terrain classes (cartography.dm), so every map
// works without new art. One small text string per level is cached, and the
// client draws everything on a canvas, which keeps server memory low.

#define TACMAP_MAX_CELLS 160 // largest map edge, in cells
#define TACMAP_MIN_CELL 2 // smallest cell edge, in tiles
#define TACMAP_REFRESH 20 // deciseconds between live updates
#define TACMAP_TERRAIN_AGE 6000 // deciseconds before a level's terrain is sampled again
#define TACMAP_MAX_MARKERS 24 // per side and level; the oldest marker goes first
#define TACMAP_ERASE_RANGE 6 // tiles from a click that erasing reaches
#define TACMAP_MARK_COOLDOWN 10 // deciseconds between markers from one officer
#define TACMAP_WINDOW "tacmap"

var/global/datum/tactical_map_controller/tactical_maps = new

/datum/tactical_map_controller
	var/list/terrain = list() // "z" = list(cell, cols, rows, string, sampled_at)
	var/list/markers = list() // "side|z" = list of list(x, y, kind, author)
	var/list/viewers = list() // mob = "side|z" they are watching
	var/list/last_mark = list() // "\ref[mob]" = world.time of their last marker
	var/refresh_timer // looping refresh while anyone is watching

// Marker kinds an officer can draw: key = list(label, letter, colour).
/proc/tactical_map_marker_kinds()
	var/static/list/kinds = list(
		"attack" = list("Attack", "A", "#e0302a"),
		"defend" = list("Defend", "D", "#3d7fe0"),
		"rally" = list("Rally point", "R", "#3fbf4f"),
		"danger" = list("Danger", "!", "#f08a1c"),
		"objective" = list("Objective", "O", "#f0d81c"))
	return kinds

// The side a human fights for on this map: their civilization on maps with
// civilizations, else their faction. Null when they have none.
/proc/tactical_map_side(mob/living/human/H)
	if (!istype(H))
		return null
	if (map && map.civilizations)
		if (!H.civilization || H.civilization == "none")
			return null
		return "civ:[H.civilization]"
	if (!H.faction_text)
		return null
	return "faction:[H.faction_text]"

/proc/tactical_map_can_draw(mob/living/human/H)
	return istype(H) && H.original_job && (H.original_job.is_commander || H.original_job.is_officer)

/proc/tactical_map_can_view(mob/living/human/H)
	return tactical_map_can_draw(H) || (istype(H) && H.original_job && H.original_job.is_squad_leader)

/mob/living/human/proc/make_tactical_map_user()
	if (tactical_map_can_view(src))
		verbs |= /mob/living/human/proc/Tactical_Map

/mob/living/human/proc/Tactical_Map()
	set category = "Officer"
	set name = "Tactical Map"
	set desc = "Open a live map of your side's positions and your officers' markers."
	tactical_maps.open(src)

// Cell edge in tiles for this world.
/datum/tactical_map_controller/proc/cell_size()
	return max(TACMAP_MIN_CELL, CEILING(max(world.maxx, world.maxy) / TACMAP_MAX_CELLS, 1))

// The base layer for level z: one terrain character per cell, sampled at the
// cell's centre. Cached and resampled now and then so new buildings show.
/datum/tactical_map_controller/proc/terrain_for(z)
	var/list/entry = terrain["[z]"]
	if (entry && world.time - entry[5] < TACMAP_TERRAIN_AGE)
		return entry
	var/cell = cell_size()
	var/cols = CEILING(world.maxx / cell, 1)
	var/rows = CEILING(world.maxy / cell, 1)
	var/list/chars = list()
	for (var/row in 1 to rows)
		var/y = min(world.maxy, (row - 1) * cell + round(cell / 2) + 1)
		for (var/col in 1 to cols)
			var/x = min(world.maxx, (col - 1) * cell + round(cell / 2) + 1)
			chars += cartography_terrain(locate(x, y, z))
		CHECK_TICK
	entry = list(cell, cols, rows, jointext(chars, ""), world.time)
	terrain["[z]"] = entry
	return entry

// Living members of side on level z, as list(x, y, kind, label) in tiles.
// Kinds: y = the viewer, c = officer or commander, s = squad leader,
// d = down (unconscious), u = everyone else.
/datum/tactical_map_controller/proc/blips_for(side, z, mob/viewer)
	var/list/blips = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.z != z)
			continue
		if (tactical_map_side(H) != side)
			continue
		var/turf/T = get_turf(H)
		if (!T)
			continue
		var/kind = "u"
		var/label = ""
		if (H == viewer)
			kind = "y"
		else if (H.stat != CONSCIOUS)
			kind = "d"
		else if (tactical_map_can_draw(H))
			kind = "c"
		else if (H.original_job && H.original_job.is_squad_leader)
			kind = "s"
			if (H.squad > 0)
				label = "[H.squad]"
		blips[++blips.len] = list(T.x, T.y, kind, label)
	return blips

/datum/tactical_map_controller/proc/marker_list(key)
	var/list/L = markers[key]
	if (!L)
		L = list()
		markers[key] = L
	return L

// Who may look right now, and the side and level they would see.
/datum/tactical_map_controller/proc/view_key(mob/living/human/H)
	if (!istype(H) || !H.client)
		return null
	return side_key(H)

// The side and level H plans for, whether or not they are connected.
/datum/tactical_map_controller/proc/side_key(mob/living/human/H)
	if (!istype(H) || H.stat == DEAD)
		return null
	if (!tactical_map_can_view(H))
		return null
	var/side = tactical_map_side(H)
	var/turf/T = get_turf(H)
	if (!side || !T)
		return null
	return "[side]|[T.z]"

/datum/tactical_map_controller/proc/open(mob/living/human/H)
	if (!istype(H) || !H.client)
		return
	if (H.stat != CONSCIOUS)
		to_chat(H, SPAN_WARNING("You are in no state to read a map."))
		return
	var/key = view_key(H)
	if (!key)
		to_chat(H, SPAN_WARNING("You have no side to plan for here."))
		return
	var/turf/T = get_turf(H)
	var/list/base = terrain_for(T.z)
	var/scale = clamp(round(640 / max(base[2], base[3])), 2, 8)
	var/width = base[2] * scale
	var/height = base[3] * scale
	viewers[H] = key
	show_browse(H, page_html(H, key, base, scale), "window=[TACMAP_WINDOW];size=[min(980, max(width, 560) + 60)]x[min(980, height + 200)]")
	onclose(H, TACMAP_WINDOW, src)
	start()

/datum/tactical_map_controller/proc/close(mob/H)
	viewers -= H

/datum/tactical_map_controller/proc/start()
	if (refresh_timer)
		return
	refresh_timer = addtimer(CALLBACK(src, PROC_REF(tick)), TACMAP_REFRESH, TIMER_LOOP | TIMER_STOPPABLE)

/datum/tactical_map_controller/proc/tick()
	refresh()
	if (!viewers.len && refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null

// Pushes fresh positions and markers to everyone watching. A viewer who moved
// to another level gets the new level's page; one who can no longer look is
// dropped.
/datum/tactical_map_controller/proc/refresh()
	for (var/mob/living/human/H in viewers.Copy())
		var/key = view_key(H)
		if (!key || H.stat != CONSCIOUS)
			viewers -= H
			if (H && H.client)
				show_browse(H, null, "window=[TACMAP_WINDOW]")
			continue
		if (key != viewers[H])
			open(H)
			continue
		send_update(H, key)
		CHECK_TICK

/datum/tactical_map_controller/proc/update_json(mob/H, key)
	var/sep = findtext(key, "|")
	var/side = copytext(key, 1, sep)
	var/z = text2num(copytext(key, sep + 1))
	return json_encode(list("b" = blips_for(side, z, H), "m" = marker_list(key)))

/datum/tactical_map_controller/proc/send_update(mob/H, key)
	H << output(list2params(list(update_json(H, key))), "[TACMAP_WINDOW].browser:upd")

// Every viewer of key gets the change at once instead of on the next tick.
/datum/tactical_map_controller/proc/push(key)
	for (var/mob/living/human/H in viewers)
		if (viewers[H] == key && H.client)
			send_update(H, key)

/datum/tactical_map_controller/proc/add_marker(mob/living/human/H, x, y, kind)
	var/key = side_key(H)
	if (!key || H.stat != CONSCIOUS || !tactical_map_can_draw(H))
		return FALSE
	var/list/kinds = tactical_map_marker_kinds()
	if (!kinds[kind])
		return FALSE
	x = round(text2num(x))
	y = round(text2num(y))
	if (!isnum(x) || !isnum(y) || x < 1 || y < 1 || x > world.maxx || y > world.maxy)
		return FALSE
	if (world.time < (last_mark["\ref[H]"] || 0) + TACMAP_MARK_COOLDOWN)
		return FALSE
	last_mark["\ref[H]"] = world.time
	var/list/L = marker_list(key)
	L[++L.len] = list(x, y, kind, H.real_name)
	while (L.len > TACMAP_MAX_MARKERS)
		L.Cut(1, 2)
	var/list/info = kinds[kind]
	notify_side(key, H, "[H.real_name] marked <b>[info[1]]</b> on the tactical map at ([x], [y]).")
	push(key)
	return TRUE

// Removes the marker nearest to x, y within reach. Returns TRUE if one went.
/datum/tactical_map_controller/proc/erase_marker(mob/living/human/H, x, y)
	var/key = side_key(H)
	if (!key || H.stat != CONSCIOUS || !tactical_map_can_draw(H))
		return FALSE
	x = text2num(x)
	y = text2num(y)
	if (!isnum(x) || !isnum(y))
		return FALSE
	var/list/L = marker_list(key)
	var/best = 0
	var/best_dist = TACMAP_ERASE_RANGE + 1
	for (var/i in 1 to L.len)
		var/list/M = L[i]
		var/dist = max(abs(M[1] - x), abs(M[2] - y))
		if (dist < best_dist)
			best = i
			best_dist = dist
	if (!best)
		return FALSE
	L.Cut(best, best + 1)
	push(key)
	return TRUE

/datum/tactical_map_controller/proc/clear_markers(mob/living/human/H)
	var/key = side_key(H)
	if (!key || H.stat != CONSCIOUS || !tactical_map_can_draw(H))
		return FALSE
	var/list/L = marker_list(key)
	L.Cut()
	notify_side(key, H, "[H.real_name] cleared the tactical map.")
	push(key)
	return TRUE

// Tells the side's officers and squad leaders on that level about a change.
/datum/tactical_map_controller/proc/notify_side(key, mob/living/human/author, message)
	for (var/mob/living/human/H in human_mob_list)
		if (H == author || !H.client || H.stat == DEAD)
			continue
		if (view_key(H) == key)
			to_chat(H, SPAN_NOTICE(message))

/datum/tactical_map_controller/Topic(href, href_list)
	var/mob/living/human/H = usr
	if (!istype(H))
		return
	if (href_list["close"])
		close(H)
		return
	switch (href_list["tm"])
		if ("mark")
			add_marker(H, href_list["x"], href_list["y"], href_list["k"])
		if ("erase")
			erase_marker(H, href_list["x"], href_list["y"])
		if ("clear")
			clear_markers(H)

/datum/tactical_map_controller/proc/page_html(mob/living/human/H, key, list/base, scale)
	var/turf/T = get_turf(H)
	var/drawer = tactical_map_can_draw(H)
	var/list/kinds = tactical_map_marker_kinds()
	var/list/html = list("<html><head><meta charset='utf-8'><title>Tactical map</title><style>")
	html += "body{background:#1d2420;color:#d8e2d0;font-family:Verdana,sans-serif;font-size:12px;margin:10px}"
	html += "canvas{border:2px solid #4c5f4a;image-rendering:pixelated;display:block;cursor:crosshair}"
	html += "button{background:#33402f;color:#d8e2d0;border:1px solid #5d7358;margin:2px;padding:3px 7px;cursor:pointer}"
	html += "button.on{background:#6d8a5f;color:#fff}.k{display:inline-block;width:10px;height:10px;margin:0 3px 0 9px;border:1px solid #000}"
	html += "</style></head><body>"
	html += "<b>Tactical map</b> - [html_encode(cartography_land_label(T))]. North is up. Positions refresh every [TACMAP_REFRESH / 10] seconds.<br>"
	html += "<span class='k' style='background:#fff'></span>you<span class='k' style='background:#ffd23f'></span>officers"
	html += "<span class='k' style='background:#4fc3ff'></span>squad leaders<span class='k' style='background:#5be35b'></span>troops"
	html += "<span class='k' style='background:#8a8a8a'></span>down<br>"
	if (drawer)
		html += "<div style='margin:4px 0'>Click the map to place: "
		for (var/kind in kinds)
			var/list/info = kinds[kind]
			html += "<button id='b_[kind]' onclick=\"tool('[kind]')\">[info[2]] [info[1]]</button>"
		html += "<button id='b_erase' onclick=\"tool('erase')\">Erase</button>"
		html += "<button onclick=\"go('tm=clear')\">Clear all</button></div>"
	else
		html += "<div style='margin:4px 0'>Only officers can draw on this map.</div>"
	html += "<canvas id='m' width='[base[2] * scale]' height='[base[3] * scale]'></canvas>"
	html += "<div id='s' style='margin-top:6px;color:#aab8a2'></div><script>"
	var/list/js_kinds = list()
	for (var/kind in kinds)
		var/list/info = kinds[kind]
		js_kinds[kind] = list(info[2], info[3])
	html += "var REF='\ref[src]',CELL=[base[1]],W=[base[2]],H=[base[3]],K=[scale],DRAW=[drawer ? 1 : 0],"
	html += "T=[json_encode(base[4])],COL=[json_encode(cartography_colors())],KINDS=[json_encode(js_kinds)],D=[update_json(H, key)];"
	html += tactical_map_script()
	html += "</script></body></html>"
	return jointext(html, "")

// Client-side drawing. Raw string: no DM interpolation inside.
/proc/tactical_map_script()
	return @{"
var cv=document.getElementById('m'),g=cv.getContext('2d'),bg=document.createElement('canvas'),cur='attack';
bg.width=cv.width;bg.height=cv.height;
(function(){var b=bg.getContext('2d');for(var y=0;y<H;y++){for(var x=0;x<W;x++){b.fillStyle=COL[T.charAt(y*W+x)]||COL['0'];b.fillRect(x*K,(H-1-y)*K,K,K);}}
b.strokeStyle='rgba(0,0,0,0.18)';b.lineWidth=1;var step=Math.max(1,Math.round(20/CELL));
for(var i=0;i<=W;i+=step){b.beginPath();b.moveTo(i*K+0.5,0);b.lineTo(i*K+0.5,H*K);b.stroke();}
for(var j=0;j<=H;j+=step){b.beginPath();b.moveTo(0,(H-j)*K+0.5);b.lineTo(W*K,(H-j)*K+0.5);b.stroke();}})();
function px(tx){return (tx-0.5)/CELL*K;}
function py(ty){return (H-(ty-0.5)/CELL)*K;}
var BC={y:'#ffffff',c:'#ffd23f',s:'#4fc3ff',u:'#5be35b',d:'#8a8a8a'};
function draw(){g.drawImage(bg,0,0);var r=Math.max(3,Math.round(K*0.9)),i;
for(i=0;i<D.b.length;i++){var b=D.b[i],bx=px(b[0]),by=py(b[1]),rr=b[2]=='y'?r+1:r;
g.fillStyle='#000';g.fillRect(bx-rr-1,by-rr-1,rr*2+2,rr*2+2);g.fillStyle=BC[b[2]]||'#5be35b';g.fillRect(bx-rr,by-rr,rr*2,rr*2);
if(b[3]){g.fillStyle='#fff';g.font='bold 10px Verdana';g.textAlign='left';g.textBaseline='bottom';g.fillText(b[3],bx+rr+1,by-rr+2);}}
for(i=0;i<D.m.length;i++){var m=D.m[i],k=KINDS[m[2]]||['?','#fff'],x=px(m[0]),y=py(m[1]),s=Math.max(9,K*2.5);
g.fillStyle='rgba(0,0,0,0.35)';g.beginPath();g.arc(x,y,s,0,7);g.fill();g.strokeStyle=k[1];g.lineWidth=2;g.beginPath();g.arc(x,y,s,0,7);g.stroke();
g.fillStyle=k[1];g.font='bold '+Math.round(s*1.2)+'px Verdana';g.textAlign='center';g.textBaseline='middle';g.fillText(k[0],x,y+1);}
document.getElementById('s').innerHTML=D.b.length+' on this level, '+D.m.length+' markers.';}
function upd(s){try{D=JSON.parse(s);}catch(e){return;}draw();}
function go(q){window.location='byond://?src='+REF+'&'+q;}
function tool(t){cur=t;var bs=document.getElementsByTagName('button');for(var i=0;i<bs.length;i++){bs[i].className=bs[i].id=='b_'+t?'on':'';}}
cv.onclick=function(e){if(!DRAW)return;var rc=cv.getBoundingClientRect(),cx=(e.clientX-rc.left)/K,cy=(e.clientY-rc.top)/K;
var tx=Math.max(1,Math.round(cx*CELL)),ty=Math.max(1,Math.round((H-cy)*CELL));
if(cur=='erase')go('tm=erase&x='+tx+'&y='+ty);else go('tm=mark&k='+cur+'&x='+tx+'&y='+ty);};
if(DRAW)tool('attack');draw();
"}

#undef TACMAP_MAX_CELLS
#undef TACMAP_MIN_CELL
#undef TACMAP_REFRESH
#undef TACMAP_TERRAIN_AGE
#undef TACMAP_MAX_MARKERS
#undef TACMAP_ERASE_RANGE
#undef TACMAP_MARK_COOLDOWN
#undef TACMAP_WINDOW
