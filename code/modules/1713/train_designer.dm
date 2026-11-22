// ============================================================
// The train designer (docs/train-sheets.md)
// ------------------------------------------------------------
// Hold a blank ship's draught (or a train sheet) and a pen or pencil and
// choose "Draw a train on the sheet": a window shows the train as a line of
// cars from the front. Stock cars and locomotives are picked from a list and
// added, moved or taken off; a drawn car is laid out on a plan of its own
// three tiles wide and four or eight long, with its floor, roof, sides, ends
// and fittings picked from palettes and clicked onto it.
//
// Like the airship designer (naval/air_designer.dm), every change goes to
// the server, which reads it as a design code and answers with the sheet's
// own summary and checks, so the window never disagrees with the sheet. Save
// keeps the drawing on the sheet. The Part panel says what the picked (or
// pointed at) thing is, what it is for and how to use it (DATA.HELP); the
// Checks panel lists the findings and lights their cars.
//
// The page is train_designer_page() with one block of data at @@DATA@@:
//   REF       this designer's ref, for the window's links
//   STOCK     list(kind, name, length, group, cost text): the stock cars
//             and locomotives; group is engine, passenger, goods or war
//   FLOORS    list(key, name, centre deck state, side deck state)
//   ROOFS     list(key, name, roof state)
//   EDGES     list(key, name, edge state)
//   FITTINGS  list(key, name)
//   LENGTHS   the lengths a drawn car may be (4 and 8)
//   MAX_CARS, MAX_TILES  the most cars and tiles a train may have
//   START     the sheet: list(name, list(car kind, ...)) from the front. A
//             drawn car's kind is its string (train_draught.dm):
//             c:<length>:<floor>:<roof>:<front>:<back>:<section>,...:<name>
//   EXAMPLES  ready-made sheets in the same form
//   PICS      the pictures the server sends (train_designer_sprites())
//   LOOK      what a stock kind is drawn with: kind -> list(body, centre
//             deck state, side deck state, roof state), "" for none; a kind
//             with a body is a locomotive or tender drawn as "body_<body>"
//   HELP      the part book: key -> list(what, use, how); stock kinds by
//             kind, "custom", "x", and "floor_<key>", "roof_<key>",
//             "edge_<key>", "fit_<key>"
// The window sends ?src=REF;train=preview|save;code=<C13TRAIN code>
// and the server answers with trainStats(summary html), trainChecks(json
// of the report's data(); cells are car numbers from the front) and
// trainStatus(text).
// ============================================================

#define TRAIN_DESIGNER_WINDOW "train_designer"
#define TRAIN_DESIGNER_PREVIEW_GAP 3 // deciseconds between summaries per drawer

/proc/train_designers()
	var/static/list/open
	if (!open)
		open = list()
	return open

// Picture name -> picture, sent to the window as "traind_<name>.png". Cut
// from the game's DMIs by scripts/build_train_designer_icons.py, every one a
// car heading up the page. The pieces of one thing share a picture and the
// window shows the piece it wants:
//   deck_<centre>_<side>  the left, rail and right tiles of a deck, side by side
//   roof_<state>          a roof's front, middle and back rows, three tiles each
//   edge_<style>          a side on the left, right, front and back edge
//   body_<body>           a whole locomotive or tender body, three tiles wide
//   fit_<key>             a fitting
// No two names differ only by case: Windows serves the browser's cache
// without it.
/proc/train_designer_sprites()
	var/static/list/table
	if (!table)
		table = list(
		"deck_boards_boards" = 'icons/train_designer/deck_boards_boards.png',
		"deck_carpet_carpet" = 'icons/train_designer/deck_carpet_carpet.png',
		"deck_carpet_floor" = 'icons/train_designer/deck_carpet_floor.png',
		"deck_floor_floor" = 'icons/train_designer/deck_floor_floor.png',
		"deck_hopper_hopper" = 'icons/train_designer/deck_hopper_hopper.png',
		"deck_steel_boards" = 'icons/train_designer/deck_steel_boards.png',
		"deck_steel_steel" = 'icons/train_designer/deck_steel_steel.png',
		"deck_straw_straw" = 'icons/train_designer/deck_straw_straw.png',
		"deck_wood_wood" = 'icons/train_designer/deck_wood_wood.png',
		"roof_armor" = 'icons/train_designer/roof_armor.png',
		"roof_boxcar" = 'icons/train_designer/roof_boxcar.png',
		"roof_coach" = 'icons/train_designer/roof_coach.png',
		"roof_reefer" = 'icons/train_designer/roof_reefer.png',
		"roof_steel" = 'icons/train_designer/roof_steel.png',
		"roof_stock" = 'icons/train_designer/roof_stock.png',
		"edge_armor" = 'icons/train_designer/edge_armor.png',
		"edge_armor_door" = 'icons/train_designer/edge_armor_door.png',
		"edge_cold" = 'icons/train_designer/edge_cold.png',
		"edge_cold_door" = 'icons/train_designer/edge_cold_door.png',
		"edge_door" = 'icons/train_designer/edge_door.png',
		"edge_drop_door" = 'icons/train_designer/edge_drop_door.png',
		"edge_freight_door" = 'icons/train_designer/edge_freight_door.png',
		"edge_partition" = 'icons/train_designer/edge_partition.png',
		"edge_plank" = 'icons/train_designer/edge_plank.png',
		"edge_rail" = 'icons/train_designer/edge_rail.png',
		"edge_side" = 'icons/train_designer/edge_side.png',
		"edge_slat" = 'icons/train_designer/edge_slat.png',
		"edge_slat_door" = 'icons/train_designer/edge_slat_door.png',
		"edge_wall" = 'icons/train_designer/edge_wall.png',
		"edge_window" = 'icons/train_designer/edge_window.png',
		"body_armored" = 'icons/train_designer/body_armored.png',
		"body_diesel" = 'icons/train_designer/body_diesel.png',
		"body_dieselmain" = 'icons/train_designer/body_dieselmain.png',
		"body_electric" = 'icons/train_designer/body_electric.png',
		"body_mainline" = 'icons/train_designer/body_mainline.png',
		"body_steam" = 'icons/train_designer/body_steam.png',
		"body_tender" = 'icons/train_designer/body_tender.png',
		"body_tram" = 'icons/train_designer/body_tram.png',
		"fit_B" = 'icons/train_designer/fit_B.png',
		"fit_C" = 'icons/train_designer/fit_C.png',
		"fit_D" = 'icons/train_designer/fit_D.png',
		"fit_F" = 'icons/train_designer/fit_F.png',
		"fit_H" = 'icons/train_designer/fit_H.png',
		"fit_I" = 'icons/train_designer/fit_I.png',
		"fit_K" = 'icons/train_designer/fit_K.png',
		"fit_L" = 'icons/train_designer/fit_L.png',
		"fit_O" = 'icons/train_designer/fit_O.png',
		"fit_R" = 'icons/train_designer/fit_R.png',
		"fit_S" = 'icons/train_designer/fit_S.png',
		"fit_T" = 'icons/train_designer/fit_T.png',
		"fit_W" = 'icons/train_designer/fit_W.png',
		"fit_X" = 'icons/train_designer/fit_X.png',
		)
	return table

/datum/train_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/last_preview = null

/datum/train_designer/Destroy()
	var/list/open = train_designers()
	if (drawer && open[drawer] == src)
		open -= drawer
	drawer = null
	sheet = null
	return ..()

/obj/item/ship_draught/proc/open_train_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	var/list/open = train_designers()
	var/datum/train_designer/old = open[H]
	if (old)
		qdel(old)
	var/datum/train_designer/A = new
	A.drawer = H
	A.sheet = src
	open[H] = A
	var/datum/train_draught/D = train_draught()
	if (!D)
		var/list/examples = train_draught_examples()
		D = examples[1]
		examples -= D
		for (var/datum/E in examples)
			qdel(E)
		D.name = "train"
	var/list/sprites = train_designer_sprites()
	for (var/key in sprites)
		H << browse_rsc(sprites[key], "traind_[key].png")
	show_browse(H, train_designer_html(A, D), "window=[TRAIN_DESIGNER_WINDOW];size=1120x720")
	onclose(H, TRAIN_DESIGNER_WINDOW, A)
	train_designer_stats(H, D)
	qdel(D)

/proc/train_designer_sheet(datum/train_draught/D)
	return list(D.name, D.cars.Copy())

/proc/train_designer_group(kind)
	var/list/L = train_car_layout(kind)
	if (!L)
		return "goods"
	if (L["engine"] || kind == "tender")
		return "engine"
	if (kind in list("railgun", "armored", "flak"))
		return "war"
	if (kind in list("coach", "sleeper", "dining", "bogie_coach", "bogie_sleeper", "bogie_dining", "mail_van", "brake_van"))
		return "passenger"
	return "goods"

/proc/train_designer_data(datum/train_designer/A, datum/train_draught/D)
	var/list/stock = list()
	var/list/look = list()
	var/list/stock_table = train_draught_stock()
	for (var/kind in stock_table)
		var/list/L = train_car_layout(kind)
		if (!L)
			continue
		stock += list(list(kind, L["name"], train_car_length(kind), train_designer_group(kind), train_draught_costs_text(stock_table[kind]["cost"])))
		look[kind] = list(L["body"] || "", L["center"] || "", L["side"] || "", L["roof"] || "")
	var/list/floors = list()
	var/list/floor_table = train_draught_floors()
	for (var/key in floor_table)
		floors += list(list(key, floor_table[key]["name"], floor_table[key]["center"], floor_table[key]["side"]))
	var/list/roofs = list()
	var/list/roof_table = train_draught_roofs()
	for (var/key in roof_table)
		roofs += list(list(key, roof_table[key]["name"], roof_table[key]["state"]))
	var/list/edges = list()
	var/list/edge_table = train_draught_edges()
	for (var/key in edge_table)
		edges += list(list(key, edge_table[key]["name"], edge_table[key]["style"]))
	var/list/fittings = list()
	var/list/fit_table = train_draught_fittings()
	for (var/key in fit_table)
		fittings += list(list(key, fit_table[key]["name"]))
	var/list/examples = list()
	for (var/datum/train_draught/E in train_draught_examples())
		examples += list(train_designer_sheet(E))
		qdel(E)
	var/list/pics = list()
	for (var/key in train_designer_sprites())
		pics += key
	return list(
		"REF" = A ? "\ref[A]" : "",
		"STOCK" = stock,
		"FLOORS" = floors,
		"ROOFS" = roofs,
		"EDGES" = edges,
		"FITTINGS" = fittings,
		"LENGTHS" = list(TRAIN_CAR_LENGTH, TRAIN_LONG_CAR_LENGTH),
		"MAX_CARS" = TRAIN_DRAUGHT_MAX_CARS,
		"MAX_TILES" = TRAIN_DRAUGHT_MAX_TILES,
		"START" = train_designer_sheet(D),
		"EXAMPLES" = examples,
		"PICS" = pics,
		"LOOK" = look,
		"HELP" = design_part_help_for("train_sheet"),
	)

/proc/train_designer_html(datum/train_designer/A, datum/train_draught/D)
	var/list/halves = splittext(train_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(train_designer_data(A, D)) + halves[2]

/proc/train_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[TRAIN_DESIGNER_WINDOW].browser:trainStatus")

/proc/train_designer_stats(mob/user, datum/train_draught/D)
	user << output(list2params(list(D.summary_text())), "[TRAIN_DESIGNER_WINDOW].browser:trainStats")
	var/datum/design_report/R = D.check_design()
	user << output(list2params(list(json_encode(R.data()))), "[TRAIN_DESIGNER_WINDOW].browser:trainChecks")
	qdel(R)

/datum/train_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["train"] || H != drawer || train_designers()[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		train_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	var/save = href_list["train"] == "save"
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + TRAIN_DESIGNER_PREVIEW_GAP)
			return
		last_preview = world.time
	var/code = href_list["code"]
	if (!istext(code) || length(code) > DESIGN_CODE_TRAIN_MAX)
		train_designer_status(H, "The drawing could not be read.")
		return
	var/datum/train_draught/D = train_draught_from_code(code)
	if (!D)
		train_designer_status(H, "The drawing could not be read.")
		return
	train_designer_stats(H, D)
	if (save)
		sheet.take_train(D)
		train_designer_status(H, "Saved on the sheet.")
	qdel(D)

// Raw string: no DM interpolation inside, and never a double quote followed
// by a closing brace. Plain ES5 for the embedded browser. One @@DATA@@.
/proc/train_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Train sheet</title><style>
html,body{height:100%}
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:0;overflow:hidden}
.sec{border:1px solid #66513b;background:#30271e;margin-bottom:8px}
.sec h2{font-size:13px;margin:0;padding:5px 8px;border-bottom:2px solid #b48c4d}
.sec h2 span{float:right;font-size:11px;font-weight:normal;color:#bfae96;margin-top:1px}
.sec .in{padding:6px 8px}
button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;margin:0;padding:3px 7px;cursor:pointer;font-family:Verdana,sans-serif;font-size:11px}
button:hover{border-color:#ffd985}
button.on{background:#b48c4d;color:#211c16;border-color:#ffd985}
button.go{flex:none;white-space:nowrap;background:#6b4d1f;border-color:#b48c4d;font-weight:bold;font-size:12px;padding:4px 14px}
input,select{background:#1d1916;color:#e9dfc8;border:1px solid #806040;font-family:Verdana,sans-serif;font-size:11px;height:22px;box-sizing:border-box;padding:1px 3px}
.row{display:flex;align-items:center;margin-bottom:5px}
.row label{flex:none;color:#bfae96;font-size:11px;margin-right:6px}
.hint{color:#b0a080;font-size:11px;line-height:1.35}
.lbl{color:#b0a080;font-size:10px;text-align:center;letter-spacing:1px;text-transform:uppercase}
img.pic,.bx,.q,.t{image-rendering:pixelated;-ms-interpolation-mode:nearest-neighbor}
img.pic{vertical-align:middle}
.bx{display:inline-block;vertical-align:middle;background-repeat:no-repeat}
.chip{display:inline-block;background:#211c16;border:1px solid #b48c4d;border-radius:3px;min-width:16px;text-align:center;font-size:12px;line-height:18px;height:18px;color:#ffd985;font-weight:bold}
#topbar{margin:6px 8px 0 8px}
#wrap{display:flex;align-items:flex-start;padding:0 8px}
#addcol{flex:0 0 262px;width:262px;margin-right:10px}
#carcol{flex:0 0 420px;width:420px;margin-right:10px}
#info{flex:1 1 0;min-width:0}

/* The train */
#strip{display:flex;align-items:flex-start;justify-content:center;height:72px;overflow:hidden;background:#1a2530;border:2px solid #0f0c09;padding:5px 4px 0 4px;margin-bottom:5px;-webkit-user-select:none;-ms-user-select:none;user-select:none}
#strip .none{color:#4f6880;align-self:center;margin-top:-5px}
.car{flex:none;margin:0 2px;cursor:pointer}
.cv{position:relative;overflow:hidden;background:#3a342c}
.rot{position:absolute;left:0;-webkit-transform-origin:0 0;-ms-transform-origin:0 0;transform-origin:0 0;-webkit-transform:rotate(-90deg);-ms-transform:rotate(-90deg);transform:rotate(-90deg)}
.q{position:absolute;display:block;background-repeat:no-repeat}
.car .no{text-align:center;font-size:10px;color:#bfae96;line-height:13px;white-space:nowrap;overflow:hidden}
.car.sel .cv{box-shadow:0 0 0 2px #ffd985}
.car.sel .no{color:#ffd985;font-weight:bold}
.car:hover .cv{box-shadow:0 0 0 1px #ffd985}
.car.sel:hover .cv{box-shadow:0 0 0 2px #ffd985}
.ring{position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none}
#st{flex:1 1 auto;min-width:0;color:#ffd985;margin-left:9px;font-size:11px;line-height:1.25}
#selname{flex:1 1 auto;min-width:0;margin-left:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}

/* The stock list */
#stock{overflow-y:auto;box-sizing:border-box;padding:4px 6px 6px 8px}
.ph{color:#bfae96;font-size:11px;margin:5px 0 2px 0}
.ph:first-child{margin-top:0}
#stock button{display:flex;align-items:center;width:100%;box-sizing:border-box;text-align:left;padding:2px 5px;margin-bottom:2px;height:22px}
#stock button .nm{flex:1 1 auto;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#stock button .ln{flex:0 0 18px;text-align:right;color:#ffd985}
#stock button .co{flex:0 0 62px;text-align:right;color:#bfae96;font-size:10px;white-space:nowrap}

/* The car's plan */
#carin{display:flex;align-items:flex-start}
#planw{flex:0 0 152px;width:152px;margin-right:12px}
#g{position:relative;margin:2px 0;-webkit-user-select:none;-ms-user-select:none;user-select:none}
#gi{position:absolute;background:#1a2530}
.t{position:absolute;box-sizing:border-box;border:1px solid #14100c;cursor:pointer;overflow:hidden;background-repeat:no-repeat}
.t:hover{border-color:#ffd985}
.t .p{position:absolute;left:0;top:0;width:100%;height:100%}
.t .pl{position:absolute;left:50%;top:50%;width:18px;height:18px;margin:-10px 0 0 -10px;line-height:18px;font-size:12px}
.q .p{position:absolute;left:0;top:0;width:100%;height:100%}
.gs{position:absolute;box-sizing:border-box;border:1px dashed #5d4a36;color:#ffd985;font-size:10px;font-weight:bold;text-align:center;cursor:pointer;overflow:hidden}
.gs.set{border:1px solid #b48c4d;background:#4a3a2a}
.gs:hover{border-color:#ffd985}
#pals{flex:1 1 0;min-width:0}
#pals.off{opacity:0.4}
.pal{display:flex;flex-wrap:wrap}
.pal button{width:30px;height:30px;padding:0;margin:0 3px 3px 0;text-align:center;overflow:hidden;box-sizing:border-box}
.pal.wide button{display:flex;align-items:center;text-align:left;width:113px;height:22px;margin-bottom:2px;font-size:10px;line-height:10px;padding:1px 3px 1px 2px}
.pal.wide button .ic{flex:none;width:18px;height:18px;line-height:16px;margin-right:4px;text-align:center}
.pal.wide button .nm{flex:1 1 auto;min-width:0}
#stockcar{line-height:1.35}
#bigw{position:relative;margin:4px auto 0 auto;background:#3a342c;border:2px solid #0f0c09}

/* Figures */
.fg{display:flex;margin:0 0 5px 0}
.fg div{flex:1 1 0;background:#262019;border:1px solid #54432f;padding:3px 0;text-align:center;margin-right:4px}
.fg div:last-child{margin-right:0}
.fg b{display:block;font-size:15px;color:#ffd985}
.fg b.bad{color:#f3a26a}
.fg span{font-size:10px;color:#bfae96}

/* Part and Checks */
#part{height:128px;overflow:auto;line-height:1.35;box-sizing:border-box}
.pn{font-size:13px;font-weight:bold;margin-bottom:4px;display:flex;align-items:center}
.pn .ic{flex:none;margin-right:7px}
.pn .ic:empty{display:none}
.pn .w{flex:1 1 auto}
.pn span.s{font-size:11px;font-weight:normal;color:#bfae96;margin-left:8px}
.pr{display:flex;margin-top:2px}
.pr i{flex:0 0 38px;font-style:normal;color:#b48c4d;font-size:11px;padding-top:1px}
.pr span{flex:1 1 auto;min-width:0}
#checks{overflow-y:auto;box-sizing:border-box}
.vd{padding:5px 7px;border:1px solid #6caa68;border-radius:3px;background:#253b25;color:#c4e8c0}
.vd.bad{border-color:#c77a39;background:#3a2a1a;color:#f3c79a}
.vd .also{color:#f2dc8f;margin-top:3px}
.ck{display:flex;align-items:flex-start;margin-top:4px;padding:5px 7px 5px 6px;border:1px solid #54432f;border-left:3px solid #bfae96;border-radius:3px;background:#262019;line-height:1.3;cursor:default}
.ck.has{cursor:pointer}
.ck .tag{flex:0 0 52px;margin-right:7px;text-align:center;font-size:10px;font-weight:bold;letter-spacing:0.5px;text-transform:uppercase;border-radius:2px;padding:1px 0;margin-top:1px;border:1px solid #bfae96;color:#bfae96}
.ck .tx{flex:1 1 auto;min-width:0}
.ck .wh{display:block;color:#bfae96;font-size:11px;margin-top:1px}
.ck.error{border-left-color:#c77a39;background:#3a2a1a}
.ck.error .tag{background:#c77a39;border-color:#c77a39;color:#241405}
.ck.warning{border-left-color:#c9a52e;background:#373016}
.ck.warning .tag{border-color:#c9a52e;color:#f2dc8f}
.ck.note{color:#bfae96}
.ck.has:hover,.ck.lit{border-color:#ffd985}
.ck.pin{box-shadow:inset 0 0 0 1px #ffd985}
.ck.pin .wh{color:#ffd985}
.ck:focus{outline:2px solid #ffd985;outline-offset:-1px}
</style></head><body>

<div id='topbar'><div class='sec'><h2>Train<span id='tot'></span></h2><div class='in'>
<div class='row'><label for='nm'>Name</label><input id='nm' maxlength='40' style='flex:0 0 200px;width:200px;margin-right:12px' onchange='changed()' onkeyup='changed()'><button onclick='undo()' style='margin-right:3px'>Undo</button><button onclick='redo()' style='margin-right:12px'>Redo</button><span class='hint' style='white-space:nowrap'>Start from&nbsp;</span><select id='ex' style='flex:0 0 190px;width:190px;margin-right:4px'><option value=''>-</option></select><button onclick='loadExample()' style='margin-right:12px'>Load</button><button class='go' onclick='send(1)'>Save to the sheet</button><span id='st'></span></div>
<div id='strip'></div>
<div class='row' style='margin-bottom:0'><span class='hint' style='margin-right:6px'>front</span><button id='bf' onclick='move(-1)' title='Move the picked car one place towards the front' style='margin-right:3px'>&lt; Forward</button><button id='bb' onclick='move(1)' title='Move the picked car one place towards the back' style='margin-right:3px'>Back &gt;</button><button id='bd' onclick='dup()' title='Add a copy of the picked car behind it' style='margin-right:3px'>Duplicate</button><button id='br' onclick='takeOff()' title='Take the picked car off the train'>Remove</button><span id='selname'></span><span class='hint'>back</span></div>
</div></div></div>

<div id='wrap'>

<div id='addcol'><div class='sec' style='margin-bottom:0'><h2>Add a car<span>goes behind the picked car</span></h2><div id='stock'></div></div></div>

<div id='carcol'><div class='sec' style='margin-bottom:0'><h2 id='carh'>Car</h2><div class='in' id='carbody'>
<div class='row' id='carrow'><label for='cn'>Name</label><input id='cn' maxlength='30' style='flex:1 1 auto;min-width:0;margin-right:8px' onchange='carName()' onkeyup='carName()'><select id='cl' onchange='setLen(+this.value)'></select></div>
<div id='carin'>
<div id='planw'><div id='planbox'><div class='lbl'>front</div><div id='g'></div><div class='lbl'>back</div></div><div id='stockcar'></div></div>
<div id='pals'>
<div class='ph'>Floor <span class='hint'>- of the whole car</span></div><div class='pal' id='pf'></div>
<div class='ph'>Roof <span class='hint'>- over the whole car</span></div><div class='pal' id='pr'></div>
<div class='ph'>Sides and ends <span class='hint'>- click an edge</span></div><div class='pal wide' id='pe'></div>
<div class='ph'>Fittings <span class='hint'>- one stands on a tile</span></div><div class='pal' id='pt'></div>
<div class='hint' id='carhint' style='margin-top:3px'></div>
</div>
</div>
</div></div></div>

<div id='info'>
<div class='sec'><h2>Part</h2><div class='in' id='part'></div></div>
<div class='sec'><h2>Figures</h2><div class='in' id='stats'><span class='hint'>Reckoning...</span></div></div>
<div class='sec' style='margin-bottom:0'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div>
</div>

</div><script>
var DATA=@@DATA@@;
var REF=DATA.REF,STOCK=DATA.STOCK||[],FLOORS=DATA.FLOORS||[],ROOFS=DATA.ROOFS||[],EDGES=DATA.EDGES||[],FITTINGS=DATA.FITTINGS||[],LENGTHS=DATA.LENGTHS||[4,8],MAX_CARS=DATA.MAX_CARS,MAX_TILES=DATA.MAX_TILES,EXAMPLES=DATA.EXAMPLES||[],PICS=DATA.PICS||[],HELP=DATA.HELP||{},LOOK=DATA.LOOK||{};
var DECKCOL={wood:'#7a5230',boards:'#6b5138',floor:'#b9ad8c',carpet:'#7c2630',steel:'#7b848c',straw:'#a8904a',hopper:'#4e555c'};
var GROUPS=[['engine','Engines and tenders'],['passenger','Passenger stock'],['goods','Goods stock'],['war','Wartime stock']];
var FRAME={4:'12 iron +',8:'22 iron +'};
var cars=[],sel=-1,cur='e:w',hist=[],fut=[],timer=null,lastSent=0,T=40,G=16;
var CHK=[],lit=-1,pin=-1,peek=null,stroke=false,stroked=false;
var LEVEL={error:['Fix','#ff6f3c'],warning:['Warning','#ffd23f'],note:['Note','#fff6dc']};
function $(i){return document.getElementById(i);}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/\x22/g,'&quot;');}
function row(list,k){for(var i=0;i<list.length;i++)if(list[i][0]==k)return list[i];return null;}
function several(n,one){return n+' '+one+(n==1?'':'s');}
function cap(s){s=s+'';return s.charAt(0).toUpperCase()+s.substring(1);}

// ---- The sheet ----
// A car is a stock kind (text) or a drawn car: its length n, floor fl, roof
// rf ('.' for none), front and back ends fr and bk (three edges each), its
// sections s (left edge, right edge, then the three tiles' fittings) and
// its name nm.
function drawn(c){return typeof c!='string';}
function len(c){var r;if(drawn(c))return c.n;r=row(STOCK,c);return r?+r[2]:4;}
function cleanName(s,none){s=(s+'').replace(/[\/;,:_<>&'\x22\\]/g,' ').replace(/\s+/g,' ').replace(/^\s+|\s+$/g,'');return s||none;}
function blankCar(n){var c={n:n,fl:FLOORS.length?FLOORS[0][0]:'w',rf:'.',fr:['.','.','.'],bk:['.','.','.'],s:[],nm:'rail car'},i;for(i=0;i<n;i++)c.s.push(['.','.','.','.','.']);return c;}
function parseCar(k){var f,c,i,s;k=k+'';if(k.substring(0,2)!='c:')return k;f=k.substring(2).split(':');if(f.length!=7)return null;
c={n:+f[0],fl:f[1],rf:f[2],fr:f[3].split(''),bk:f[4].split(''),s:[],nm:f[6].replace(/_/g,' ')};s=f[5].split(',');
if(s.length!=c.n||c.fr.length!=3||c.bk.length!=3)return null;
for(i=0;i<s.length;i++){if(s[i].length!=5)return null;c.s.push(s[i].split(''));}return c;}
function kindOf(c){var s=[],i;if(!drawn(c))return c;for(i=0;i<c.s.length;i++)s.push(c.s[i].join(''));
return 'c:'+c.n+':'+c.fl+':'+c.rf+':'+c.fr.join('')+':'+c.bk.join('')+':'+s.join(',')+':'+cleanName(c.nm,'rail car').replace(/ /g,'_');}
function carName_(c){var r;if(drawn(c))return cleanName(c.nm,'rail car');r=row(STOCK,c);return r?r[1]:c;}
function tiles(){var n=0,i;for(i=0;i<cars.length;i++)n+=len(cars[i]);return n;}
function load(sheet){var i,c;$('nm').value=sheet[0];cars=[];for(i=0;i<sheet[1].length;i++){c=parseCar(sheet[1][i]);if(c)cars.push(c);}sel=-1;for(i=0;i<cars.length;i++)if(drawn(cars[i])){sel=i;break;}if(sel<0&&cars.length)sel=0;}
function snap(){var k=[],i;for(i=0;i<cars.length;i++)k.push(kindOf(cars[i]));return [k,sel];}
function put(h){var i;cars=[];for(i=0;i<h[0].length;i++)cars.push(parseCar(h[0][i]));sel=Math.min(h[1],cars.length-1);}
function push(s){hist.push(s||snap());if(hist.length>60)hist.shift();fut=[];}
function undo(){if(!hist.length){status('Nothing to undo.');return;}fut.push(snap());put(hist.pop());status('');refresh();changed();}
function redo(){if(!fut.length){status('Nothing to redo.');return;}hist.push(snap());put(fut.pop());status('');refresh();changed();}
function room(n){if(cars.length>=MAX_CARS){status('A sheet holds '+MAX_CARS+' cars at most.');return false;}
if(tiles()+n>MAX_TILES){status('A train can be '+MAX_TILES+' tiles long at most.');return false;}return true;}
function addCar(c){if(!c||!room(len(c)))return;push();var at=sel>=0?sel+1:cars.length;cars.splice(at,0,c);sel=at;status('');refresh();changed();}
function addStock(k){if(row(STOCK,k))addCar(k);}
function addDrawn(n){addCar(blankCar(n));}
function pick(i){if(i<0||i>=cars.length)return;sel=i;status('');refresh();}
function move(d){var j=sel+d,c;if(sel<0||j<0||j>=cars.length)return;push();c=cars[sel];cars[sel]=cars[j];cars[j]=c;sel=j;status('');refresh();changed();}
function dup(){if(sel<0)return;addCar(parseCar(kindOf(cars[sel])));}
function takeOff(){if(sel<0)return;push();cars.splice(sel,1);if(sel>=cars.length)sel=cars.length-1;status('');refresh();changed();}
function loadExample(){var i=$('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);status('');refresh();changed();}
function car(){return sel>=0&&drawn(cars[sel])?cars[sel]:null;}
function carName(){var c=car();if(!c||c.nm==$('cn').value)return;c.nm=$('cn').value;strip();head();changed();}
function setLen(n){var c=car(),i;if(!c||n==c.n){controls();return;}if(n>c.n&&tiles()+n-c.n>MAX_TILES){status('A train can be '+MAX_TILES+' tiles long at most.');controls();return;}
push();while(c.s.length>n)c.s.pop();while(c.s.length<n)c.s.push(['.','.','.','.','.']);c.n=n;status('');refresh();changed();}
function setFloor(k){var c=car();if(!c){status('Pick a drawn car first.');return;}if(c.fl==k)return;push();c.fl=k;status('');refresh();changed();}
function setRoof(k){var c=car();if(!c){status('Pick a drawn car first.');return;}if(c.rf==k)return;push();c.rf=k;status('');refresh();changed();}
function tool(t){cur=t;marks();part();}
// One place on a drawn car: the left (L) or right (R) edge of a section, a
// third of the front (F) or back (B) end, or a tile (T) and its fitting.
function slot(c,w,i,j,v){var a=w=='L'||w=='R'||w=='T'?c.s[i]:(w=='F'?c.fr:c.bk),at=w=='L'?0:(w=='R'?1:(w=='T'?j+2:i));if(v!==undefined)a[at]=v;return a[at];}
// Draws on one place. A drag is one stroke: Undo takes all of it back.
function apply(w,i,j,right,drag){var c=car(),kind=cur.charAt(0),k=cur.substring(2),was,before;if(!c)return;
if(!right&&kind=='e'&&w=='T'){if(j==1){if(!drag)status('A side goes along the outer edge of the car: click a side tile, or a slot round the plan.');return;}w=j==0?'L':'R';}
if(!right&&kind=='t'&&w!='T'){if(!drag)status('A fitting stands on a tile: click a tile of the plan.');return;}
was=slot(c,w,i,j);before=snap();if(!drag)status('');
slot(c,w,i,j,right||kind=='x'?'.':k);
if(slot(c,w,i,j)==was)return;
if(!(drag&&stroked))push(before);stroked=true;
plan();strip();changed();}
function pd(w,i,j,e){e=e||window.event;if(e.button==2)return;stroke=true;stroked=false;apply(w,i,j,0,0);if(e.preventDefault)e.preventDefault();}
function po(w,i,j,e){e=e||window.event;if(!stroke)return;if(e.buttons!==undefined&&!(e.buttons&1)){stroke=false;return;}apply(w,i,j,0,1);}
document.onmouseup=function(){stroke=false;};

// ---- Pictures ----
// A thing is 'kind:key': s a stock car, c a drawn car, f floor, r roof,
// e edge, t fitting, x the eraser. One picture holds all the pieces of a
// deck (three across), a roof (three by three) or an edge (four across).
function hasPic(n){for(var i=0;i<PICS.length;i++)if(PICS[i]==n)return true;return false;}
function url(n){return 'background-image:url(traind_'+n+'.png);';}
function deckBg(ce,si,col){var n='deck_'+ce+'_'+si;return hasPic(n)?url(n)+'background-size:300% 100%;background-position:'+(col*50)+'% 0;':'background-color:'+(DECKCOL[col==1?ce:si]||'#56616b')+';';}
function roofBg(st,r,col){return url('roof_'+st)+'background-size:300% 300%;background-position:'+(col*50)+'% '+(r*50)+'%;';}
function edgeBg(st,w){return url('edge_'+st)+'background-size:400% 100%;background-position:'+(w*100/3)+'% 0;';}
function noPic(i){var s=document.createElement('span');s.className=i.getAttribute('data-c')||'chip';s.innerHTML=i.alt;i.parentNode.replaceChild(s,i);}
function chip(k,cls){return '<span class="chip'+(cls?' '+cls:'')+'">'+k+'</span>';}
function pic(kind,k,n){var r;
if(kind=='x')return chip('&#215;');
if(kind=='t')return hasPic('fit_'+k)?'<img class="pic" width="'+n+'" height="'+n+'" src="traind_fit_'+k+'.png" alt="'+esc(k)+'" onerror="noPic(this)">':chip(esc(k));
if(kind=='e'){r=row(EDGES,k);return r&&hasPic('edge_'+r[2])?'<span class="bx" style="width:'+n+'px;height:'+n+'px;'+edgeBg(r[2],2)+'"></span>':chip(esc(k));}
if(kind=='f'){r=row(FLOORS,k);return r?'<span class="bx" style="width:'+n+'px;height:'+n+'px;'+deckBg(r[2],r[3],1)+'"></span>':chip(esc(k));}
if(kind=='r'){r=row(ROOFS,k);if(!r)return chip('-');return hasPic('roof_'+r[2])?'<span class="bx" style="width:'+n+'px;height:'+n+'px;'+roofBg(r[2],1,1)+'"></span>':chip(esc(k));}
return '';}
function nameOf(kind,k){var r;
if(kind=='x')return 'eraser';
if(kind=='c')return 'drawn car';
if(kind=='s'){r=row(STOCK,k);return r?r[1]:k;}
if(kind=='r'&&k=='.')return 'no roof';
r=row(kind=='f'?FLOORS:(kind=='r'?ROOFS:(kind=='e'?EDGES:FITTINGS)),k);return r?r[1]:k;}
function helpKey(kind,k){return kind=='s'?k:(kind=='c'?'custom':(kind=='x'?'x':({f:'floor_',r:'roof_',e:'edge_',t:'fit_'})[kind]+k));}
// The thing a check names by its part book key.
function fromHelp(p){var m=/^(floor|roof|edge|fit)_(.*)$/.exec(p);if(p=='x')return 'x:x';if(p=='custom')return 'c:';if(m)return ({floor:'f',roof:'r',edge:'e',fit:'t'})[m[1]]+':'+m[2];return 's:'+p;}
// What a car is drawn with: its body, centre and side deck and roof states.
function look(c){var f,r;if(!drawn(c))return LOOK[c]||['','','',''];f=row(FLOORS,c.fl);r=c.rf=='.'?null:row(ROOFS,c.rf);return ['',f?f[2]:'wood',f?f[3]:'wood',r?r[2]:''];}
// A car heading up the page, t pixels a tile. On the plan every tile can
// be clicked and the roof is left off; elsewhere a roofed car shows its roof.
function carHtml(c,t,onPlan){var L=look(c),n=len(c),d=drawn(c),h='',r,col,st,e,k,i,inside,roofed=!onPlan&&L[3]&&hasPic('roof_'+L[3]);
if(L[0])return '<i class="q" style="left:0;top:0;width:'+(3*t)+'px;height:'+(n*t)+'px;'+(hasPic('body_'+L[0])?url('body_'+L[0])+'background-size:100% 100%':'background-color:#3d4a3a')+'"></i>';
for(r=0;r<n;r++)for(col=0;col<3;col++){
st='left:'+(col*t)+'px;top:'+(r*t)+'px;width:'+t+'px;height:'+t+'px;';inside='';
if(roofed)st+=roofBg(L[3],r==0?0:(r==n-1?2:1),col);
else{st+=deckBg(L[1]||'wood',L[2]||'wood',col);
if(d){k=c.s[r][col+2];
if(k!='.'&&(onPlan||t>=12))inside+=hasPic('fit_'+k)?'<img class="pic p" src="traind_fit_'+k+'.png" alt="'+esc(k)+'" data-c="chip pl" onerror="noPic(this)">':(onPlan?chip(esc(k),'pl'):'');
e=[];if(col==0)e.push([c.s[r][0],0]);if(col==2)e.push([c.s[r][1],1]);if(r==0)e.push([c.fr[col],2]);if(r==n-1)e.push([c.bk[col],3]);
for(i=0;i<e.length;i++){k=row(EDGES,e[i][0]);if(k&&hasPic('edge_'+k[2]))inside+='<i class="q" style="left:0;top:0;width:100%;height:100%;pointer-events:none;'+edgeBg(k[2],e[i][1])+'"></i>';}}}
if(onPlan)h+='<div class="t" id="p_'+r+'_'+col+'" style="'+st+'" onmousedown="pd(\'T\','+r+','+col+',event)" onmouseover="po(\'T\','+r+','+col+',event)" oncontextmenu="apply(\'T\','+r+','+col+',1,0);return false;">'+inside+'</div>';
else h+='<i class="q" style="'+st+'">'+inside+'</i>';}
return h;}

// ---- Drawing ----
function strip(){var s=$('strip'),h='',n=tiles(),W=(s.clientWidth||1080)-10,t,i,c,w,k;
t=Math.max(4,Math.min(18,Math.floor((W-cars.length*4)/Math.max(n,1))));
for(i=0;i<cars.length;i++){c=cars[i];w=len(c)*t;k=(i+1)+'. '+carName_(c);
h+='<div class="car'+(i==sel?' sel':'')+'" id="k_'+i+'" style="width:'+w+'px" title="'+esc(cap(k))+'" onclick="pick('+i+')"><div class="cv" style="width:'+w+'px;height:'+(3*t)+'px"><div class="rot" style="top:'+(3*t)+'px;width:'+(3*t)+'px;height:'+w+'px">'+carHtml(c,t,0)+'</div><span class="ring"></span></div><div class="no">'+(i+1)+'</div></div>';}
s.innerHTML=h||'<span class="none">No cars yet: add a locomotive from the list below.</span>';
$('tot').innerHTML=several(cars.length,'car')+' of '+MAX_CARS+' &middot; '+several(n,'tile')+' of '+MAX_TILES;light();}
function gs(w,i,k,x,y,wd,ht){var r=row(EDGES,k);return '<div class="gs'+(k!='.'?' set':'')+'" id="g_'+w+'_'+i+'" style="left:'+x+'px;top:'+y+'px;width:'+wd+'px;height:'+ht+'px;line-height:'+(ht-2)+'px" title="'+esc(cap(r?r[1]:'nothing here'))+'" onmousedown="pd(\''+w+'\','+i+',0,event)" onmouseover="po(\''+w+'\','+i+',0,event)" oncontextmenu="apply(\''+w+'\','+i+',0,1,0);return false;">'+(k!='.'?esc(k):'')+'</div>';}
function plan(){var c=car(),g=$('g'),h,i;if(!c)return;
g.style.width=(3*T+2*G)+'px';g.style.height=(c.n*T+2*G)+'px';
h='<div id="gi" style="left:'+G+'px;top:'+G+'px;width:'+(3*T)+'px;height:'+(c.n*T)+'px">'+carHtml(c,T,1)+'</div>';
for(i=0;i<3;i++){h+=gs('F',i,c.fr[i],G+i*T+1,0,T-2,G-2);h+=gs('B',i,c.bk[i],G+i*T+1,G+c.n*T+2,T-2,G-2);}
for(i=0;i<c.n;i++){h+=gs('L',i,c.s[i][0],0,G+i*T+1,G-2,T-2);h+=gs('R',i,c.s[i][1],G+3*T+2,G+i*T+1,G-2,T-2);}
g.innerHTML=h;}
function head(){var c=sel>=0?cars[sel]:null,r,t='';
if(c){r=drawn(c)?null:row(STOCK,c);t='<b>'+(sel+1)+'. '+esc(cap(carName_(c)))+'</b> <span class="hint">&nbsp;'+(drawn(c)?'drawn on the sheet, ':'')+len(c)+' tiles long'+(r?', '+esc(r[4]):'')+'</span>';}
$('selname').innerHTML=t;$('carh').innerHTML=c?(drawn(c)?'Drawn car':'Stock car')+'<span>car '+(sel+1)+' of '+cars.length+'</span>':'Car';}
function controls(){var c=car(),s=sel>=0?cars[sel]:null,h='',i,r;
head();
$('carrow').style.display=c?'':'none';$('planbox').style.display=c?'':'none';$('stockcar').style.display=c?'none':'';$('pals').className=c?'':'off';
if(c){if(document.activeElement!=$('cn'))$('cn').value=c.nm;for(i=0;i<LENGTHS.length;i++)h+='<option value="'+LENGTHS[i]+'"'+(LENGTHS[i]==c.n?' selected':'')+'>'+LENGTHS[i]+' tiles long</option>';$('cl').innerHTML=h;$('cl').value=c.n;
$('carhint').innerHTML='Click or drag to draw with the picked side or fitting. The slots round the plan are its sides and ends. Right-click clears.';}
else if(s){r=row(STOCK,s);i=len(s);
$('stockcar').innerHTML='<div class="lbl">front</div><div id="bigw" style="width:'+(3*24)+'px;height:'+(i*24)+'px">'+carHtml(s,24,0)+'</div><div class="lbl" style="margin-bottom:5px">back</div>';
$('carhint').innerHTML='The '+esc(r?r[1]:s)+' is built as its kit builds it. Add a drawn car from the list to lay one out yourself.';}
else{$('stockcar').innerHTML='';$('carhint').innerHTML='Add a car from the list, then pick it on the train.';}
$('bf').disabled=sel<=0;$('bb').disabled=sel<0||sel>=cars.length-1;$('bd').disabled=sel<0;$('br').disabled=sel<0;
palette();}
function ibtn(kind,k,call){var id=kind+':'+k;return '<button id="t_'+id+'" title="'+esc(cap(nameOf(kind,k)))+'" onclick="'+call+'">'+pic(kind,k,24)+'</button>';}
function palette(){var h='',i;
for(i=0;i<FLOORS.length;i++)h+=ibtn('f',FLOORS[i][0],'setFloor(\''+FLOORS[i][0]+'\')');$('pf').innerHTML=h;
h='';for(i=0;i<ROOFS.length;i++)h+=ibtn('r',ROOFS[i][0],'setRoof(\''+ROOFS[i][0]+'\')');h+=ibtn('r','.','setRoof(\'.\')');$('pr').innerHTML=h;
h='';for(i=0;i<EDGES.length;i++)h+='<button id="t_e:'+EDGES[i][0]+'" onclick="tool(\'e:'+EDGES[i][0]+'\')"><span class="ic">'+pic('e',EDGES[i][0],18)+'</span><span class="nm">'+esc(cap(EDGES[i][1]))+'</span></button>';
h+='<button id="t_x:x" onclick="tool(\'x:x\')"><span class="ic">'+pic('x','x',18)+'</span><span class="nm">Eraser</span></button>';$('pe').innerHTML=h;
h='';for(i=0;i<FITTINGS.length;i++)h+=ibtn('t',FITTINGS[i][0],'tool(\'t:'+FITTINGS[i][0]+'\')');$('pt').innerHTML=h;marks();}
function marks(){var b=document.getElementsByTagName('button'),c=car(),i,id;for(i=0;i<b.length;i++){id=b[i].id;if(id.indexOf('t_')!=0)continue;id=id.substring(2);
b[i].className=id==cur||(c&&(id=='f:'+c.fl||id=='r:'+c.rf))?'on':'';}}
function stockList(){var h='',g,i,r;
for(g=0;g<GROUPS.length;g++){h+='<div class="ph">'+GROUPS[g][1]+'</div>';
for(i=0;i<STOCK.length;i++){r=STOCK[i];if(r[3]!=GROUPS[g][0])continue;h+='<button id="a_'+esc(r[0])+'" title="Add a '+esc(r[1])+' behind the picked car" onclick="addStock(\''+esc(r[0])+'\')"><span class="nm">'+esc(cap(r[1]))+'</span><span class="ln">'+r[2]+'</span><span class="co">'+esc(r[4])+'</span></button>';}}
h+='<div class="ph">Drawn on the sheet</div>';
for(i=0;i<LENGTHS.length;i++)h+='<button id="n_'+LENGTHS[i]+'" title="Add a car to lay out yourself" onclick="addDrawn('+LENGTHS[i]+')"><span class="nm">Add drawn car'+(LENGTHS[i]>4?', on bogies':'')+'</span><span class="ln">'+LENGTHS[i]+'</span><span class="co">'+(FRAME[LENGTHS[i]]||'')+'</span></button>';
$('stock').innerHTML=h;}
function refresh(){strip();controls();plan();part();figures();}

// ---- Talking to the server ----
function code(){var nm=cleanName($('nm').value.replace(/_/g,' '),'train').replace(/ /g,'_'),k=[],i;for(i=0;i<cars.length;i++)k.push(kindOf(cars[i]));return 'C13TRAIN/1/'+nm+'/'+k.join(';');}
// The link splits at ; and &, so those are escaped; the code's own / : and
// , are left as they are to keep a long train's link short.
function enc(s){return encodeURIComponent(s).replace(/%3A/g,':').replace(/%2C/g,',').replace(/%2F/g,'/');}
function send(save){if(timer){clearTimeout(timer);timer=null;}lastSent=new Date().getTime();if(save)status('Saving...');
location.href='byond://?src='+REF+';train='+(save?'save':'preview')+';code='+enc(code());}
// The server answers one summary per 0.3 s: wait out the gap, so the last
// change is never the one it skips.
function changed(){if(timer)clearTimeout(timer);var wait=Math.max(300,450-(new Date().getTime()-lastSent));timer=setTimeout(function(){timer=null;send(0);},wait);}
function status(t){$('st').innerHTML=t;}
function trainStatus(t){status(esc(t));}
// The summary's cost becomes a figure; its findings are the Checks panel's.
var COST='';
function figures(){var n=tiles(),d=0,e=0,i,r,o;for(i=0;i<cars.length;i++){if(drawn(cars[i]))d++;else{r=row(STOCK,cars[i]);if(r&&r[3]=='engine'&&cars[i]!='tender')e++;}}
o='<div class="fg"><div><b'+(cars.length>MAX_CARS?' class="bad"':'')+'>'+cars.length+'</b><span>cars of '+MAX_CARS+'</span></div><div><b'+(n>MAX_TILES?' class="bad"':'')+'>'+n+'</b><span>tiles of '+MAX_TILES+'</span></div><div><b>'+e+'</b><span>'+(e==1?'engine':'engines')+'</span></div><div><b>'+d+'</b><span>drawn</span></div></div>';
o+='<div><span class="hint">Cost</span> &nbsp;<b>'+(COST||'...')+'</b></div>';$('stats').innerHTML=o;}
function trainStats(t){var k=/Building it takes (.*?)\.(<br>|$)/.exec(t+'');COST=k?k[1]:'';figures();}

// ---- The Part and Checks panels ----
function finding(){var i=lit>=0?lit:pin;return i>=0&&CHK[i]?CHK[i]:null;}
function part(){var f=finding(),id,kind,k,H,R=[['what','What'],['use','Use'],['how','How']],i,why,h,r,more='';
if(f&&f.part){id=fromHelp(f.part);why='named by the check';}
else if(peek){id=peek.charAt(0)+':'+peek.substring(2);why=id==cur?'picked to draw with':(peek.charAt(1)=='!'?'on the train':(peek.charAt(0)=='s'||peek.charAt(0)=='c'?'click to add it':'click to pick it'));}
else if(sel>=0&&!car()){id='s:'+cars[sel];why='picked on the train';}
else{id=cur;why='picked to draw with';}
kind=id.charAt(0);k=id.substring(2);H=HELP[helpKey(kind,k)];
if(kind=='s'){r=row(STOCK,k);if(r)more=r[2]+' tiles, '+r[4]+' - ';}
h='<div class="pn"><span class="ic">'+pic(kind,k,32)+'</span><span class="w">'+esc(cap(nameOf(kind,k)))+'<span class="s">'+esc(more)+why+'</span></span></div>';
if(H)for(i=0;i<R.length;i++)if(H[R[i][0]])h+='<div class="pr"><i>'+R[i][1]+'</i><span>'+esc(H[R[i][0]])+'</span></div>';
$('part').innerHTML=h;}
function light(){var f=finding(),i,b,s,col;
for(i=0;i<cars.length;i++){b=$('k_'+i);if(!b)continue;s=b.firstChild.lastChild;s.style.outline='';s.style.boxShadow='';}
if(!f)return;col=LEVEL[f.level][1];
for(i=0;i<f.cells.length;i++){b=$('k_'+(+f.cells[i]-1));if(!b)continue;s=b.firstChild.lastChild;s.style.outline='3px solid '+col;s.style.outlineOffset='-3px';s.style.boxShadow='inset 0 0 0 4px rgba(20,12,6,0.75)';}}
function where(i){var c=CHK[i].cells;return i==pin?'&#9679; ringed on the train':'&#9675; car'+(c.length==1?' ':'s ')+esc(c.join(', '))+' on the train';}
function mark(){var i,b,f,w;for(i=0;i<CHK.length;i++){b=$('ck_'+i);if(!b)continue;f=CHK[i];
b.className='ck '+f.level+(f.cells.length||f.part?' has':'')+(i==pin?' pin':'')+(i==lit?' lit':'');w=$('wh_'+i);if(w)w.innerHTML=where(i);}}
function show(i){lit=i;mark();part();light();}
function keep(i){pin=pin==i?-1:i;if(pin>=0&&CHK[i].cells.length==1&&+CHK[i].cells[0]>=1&&+CHK[i].cells[0]<=cars.length){sel=+CHK[i].cells[0]-1;strip();controls();plan();}mark();part();light();}
function hook(i){var b=$('ck_'+i);b.onmouseenter=b.onfocus=function(){show(i);};b.onmouseleave=b.onblur=function(){if(lit==i)show(-1);};b.onclick=function(){keep(i);};}
function trainChecks(s){var A=null,i,f,was=CHK[pin]?CHK[pin].text:null,n=[0,0,0],h='',p=[];
try{A=JSON.parse(s);}catch(e){A=null;}
if(!A){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e2){}try{A=JSON.parse(s);}catch(e3){A=[];}}
if(!A||!A.length)A=[];
CHK=[];lit=-1;pin=-1;for(i=0;i<A.length;i++){f={level:LEVEL[A[i].level]?A[i].level:'note',text:A[i].text||'',cells:A[i].cells||[],part:A[i].part||''};CHK.push(f);if(was!==null&&f.text==was)pin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class="vd bad"><b>Not ready to build.</b> '+several(n[0],'thing')+' to fix first.</div>';
else h+='<div class="vd"><b>Ready to build.</b> As drawn it can be built at a rail works.'+(n[1]?'<div class="also">'+several(n[1],'warning')+' below will not stop the build, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<CHK.length;i++){f=CHK[i];h+='<div tabindex="0" id="ck_'+i+'" class="ck"'+(f.cells.length?' title="Click to keep it ringed on the train; click again to let go"':'')+'><span class="tag">'+LEVEL[f.level][0]+'</span><span class="tx">'+esc(f.text)+(f.cells.length?'<span class="wh" id="wh_'+i+'"></span>':'')+'</span></div>';}
$('checks').innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(several(n[1],'warning'));if(n[2])p.push(several(n[2],'note'));$('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<CHK.length;i++)hook(i);
mark();part();light();}
// Pointing at a tool, a car, a tile or an edge shows what it is.
document.onmouseover=function(e){e=e||window.event;var b=e.target||e.srcElement,k=null,p,c,v;if(stroke)return;
while(b&&b!=document.body){if(b.id){
if(b.id.indexOf('t_')==0){k=b.id.substring(2);break;}
if(b.id.indexOf('a_')==0){k='s:'+b.id.substring(2);break;}
if(b.id.indexOf('n_')==0){k='c:'+b.id.substring(2);break;}
if(b.id.indexOf('k_')==0){c=cars[+b.id.substring(2)];if(c!==undefined)k=drawn(c)?'c!'+c.n:'s!'+c;break;}
if(b.id.indexOf('p_')==0){p=b.id.split('_');c=car();if(c){v=c.s[+p[1]][+p[2]+2];k=v!='.'?'t!'+v:'f!'+c.fl;}break;}
if(b.id.indexOf('g_')==0){p=b.id.split('_');c=car();if(c){v=slot(c,p[1],+p[2],0);if(v!='.')k='e!'+v;}break;}}
b=b.parentNode;}
if(k!=peek){peek=k;part();}};
// The panels fill the window's height, whatever it is.
function fit(){var h=(window.innerHeight||document.documentElement.clientHeight||720),c=$('checks'),s=$('stock'),b=$('carbody');
c.style.height=Math.max(100,h-c.getBoundingClientRect().top-9)+'px';s.style.height=Math.max(100,h-s.getBoundingClientRect().top-9)+'px';b.style.height=Math.max(100,h-b.getBoundingClientRect().top-9)+'px';b.style.boxSizing='border-box';b.style.overflow='auto';}
window.onresize=function(){fit();strip();};
(function(){var e=$('ex'),j,o;for(j=0;j<EXAMPLES.length;j++){o=document.createElement('option');o.value=j;o.innerHTML=esc(EXAMPLES[j][0]);e.appendChild(o);}
load(DATA.START);cur='e:'+(row(EDGES,'w')?'w':(EDGES.length?EDGES[0][0]:'w'));stockList();refresh();fit();changed();})();
</script></body></html>"}
