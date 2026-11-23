// ============================================================
// The rocket designer (docs/rocket-plans.md)
// ------------------------------------------------------------
// Hold a blank ship's draught (or a rocket sheet) and a pen or pencil and
// choose to draw a rocket: a window shows the rocket standing on its launch
// stand, one cell to a piece from the pad up. A piece is picked from the
// palette and clicked (or dragged) onto the stack, where a dashed line shows
// the joint it will go in at; a piece on the stack can be dragged to another
// joint. The eraser (or a right-click) takes a piece out. Fittings take no
// section and are drawn as thin bands; decouplers split the stack into the
// stages bracketed beside it, and the strap-on boosters stand beside the
// first stage. A ruler counts the storeys the launch stand is built in.
//
// Like the station designer (station_designer.dm), every change goes to the
// server, which reads it as a design code and answers with the plan's own
// legs, burns, figures and checks, so the window never disagrees with the
// sheet. Save keeps the drawing on the sheet. The Launch planner says which
// legs of a mission the rocket supports and what each missing one wants; the
// Part panel says what the picked (or pointed at) piece is, what it is for
// and how to get it (DATA.HELP); the Checks panel lists the findings and
// rings their pieces.
//
// The pieces are drawn by the page itself as inline SVG: there are no
// pictures to send.
//
// The page is rocket_designer_page() with one block of data at @@DATA@@:
//   REF       this designer's ref, for the window's links
//   MAXP      the most pieces a plan may hold
//   MAXS      the most sections (pieces with height) a launch stand takes
//   STOREY    the sections in one storey of the launch stand
//   PIECES    list(key, name, height) - height 0 is a fitting
//   FRAMES    list(key, name)
//   BOOSTERS  the booster counts a plan may have
//   START     the plan: list(name, frame, boosters, stack text bottom first)
//   EXAMPLES  ready-made plans in the same form
//   HELP      the part book: key -> list(what, use, how)
// The window sends ?src=REF;rocket=preview|save|export|import;code=<C13ROCKET code>;name=<name>
// and the server answers with rocketPlan(json of rocket_designer_answer())
// and rocketStatus(text).
// ============================================================

#define ROCKET_DESIGNER_WINDOW "rocket_designer"
#define ROCKET_DESIGNER_PREVIEW_GAP 3 // deciseconds between answers per drawer

// mob -> /datum/rocket_designer. A proc with a static list, not a global:
// the world's global init proc has no room for more.
/proc/rocket_designers()
	var/static/list/open
	if (!open)
		open = list()
	return open

/datum/rocket_designer
	var/mob/living/human/drawer = null
	var/obj/item/ship_draught/sheet = null
	var/last_preview = null

/datum/rocket_designer/Destroy()
	var/list/open = rocket_designers()
	if (drawer && open[drawer] == src)
		open -= drawer
	drawer = null
	sheet = null
	return ..()

/obj/item/ship_draught/proc/open_rocket_designer(mob/living/human/H)
	if (!ship_designer_can_draw(H, src))
		to_chat(H, SPAN_WARNING("Hold the sheet and a pen or pencil to draw on it."))
		return
	if (draught_code && !rocket_plan_kind())
		to_chat(H, SPAN_WARNING("The sheet already holds another drawing."))
		return
	var/list/open = rocket_designers()
	var/datum/rocket_designer/old = open[H]
	if (old)
		qdel(old)
	var/datum/rocket_designer/A = new
	A.drawer = H
	A.sheet = src
	open[H] = A
	var/datum/rocket_plan/D = rocket_plan()
	if (!D)
		var/list/examples = rocket_plan_examples()
		D = examples[1]
		examples -= D
		for (var/datum/E in examples)
			qdel(E)
		D.name = "rocket"
	show_browse(H, rocket_designer_html(A, D), "window=[ROCKET_DESIGNER_WINDOW];size=1180x760")
	onclose(H, ROCKET_DESIGNER_WINDOW, A)
	rocket_designer_stats(H, D)
	qdel(D)

// A plan for the window: list(name, frame, boosters, stack text bottom first).
/proc/rocket_designer_sheet(datum/rocket_plan/D)
	return list(D.name, D.frame, D.boosters, jointext(D.stack, ""))

/proc/rocket_designer_data(datum/rocket_designer/A, datum/rocket_plan/D)
	var/list/pieces = list()
	var/list/piece_table = rocket_plan_pieces()
	for (var/key in piece_table)
		var/list/P = piece_table[key]
		pieces += list(list(key, P["name"], P["height"] ? 1 : 0))
	var/list/frames = list()
	var/list/frame_table = rocket_plan_frames()
	for (var/key in frame_table)
		var/list/F = frame_table[key]
		frames += list(list(key, F["name"]))
	var/list/examples = list()
	for (var/datum/rocket_plan/E in rocket_plan_examples())
		examples += list(rocket_designer_sheet(E))
		qdel(E)
	return list(
		"REF" = A ? "\ref[A]" : "",
		"MAXP" = ROCKET_PLAN_MAX_PIECES,
		"MAXS" = ROCKET_PLAN_MAX_SECTIONS,
		"STOREY" = ROCKET_STOREY_SECTIONS,
		"PIECES" = pieces,
		"FRAMES" = frames,
		"BOOSTERS" = list(0, 2, 4, 6),
		"START" = rocket_designer_sheet(D),
		"EXAMPLES" = examples,
		"HELP" = design_part_help_for("rocket_plan"),
	)

/proc/rocket_designer_html(datum/rocket_designer/A, datum/rocket_plan/D)
	var/list/halves = splittext(rocket_designer_page(), "@@DATA@@")
	return halves[1] + json_encode(rocket_designer_data(A, D)) + halves[2]

// What the window calls each segment of the stack, bottom first, one label
// to a segment of D.segments(). A segment that burns (an engine and a tank,
// as burns() counts them) is the next stage; whatever rides above the last
// decoupler is the payload.
/proc/rocket_designer_stages(datum/rocket_plan/D)
	. = list()
	var/list/segs = D.segments()
	var/n = 0
	for (var/s = 1, s <= segs.len, s++)
		var/list/seg = segs[s]
		var/engine = FALSE
		var/tank = FALSE
		for (var/i in seg)
			var/key = D.stack[i]
			if (key == "E" || key == "V")
				engine = TRUE
			else if (key == "T")
				tank = TRUE
		var/payload = s == segs.len && D.stack[seg[seg.len]] != "D"
		if (engine && tank)
			n++
			. += payload ? "Stage [n] + payload" : "Stage [n]"
		else
			. += payload ? "Payload" : "No burn"

// What the window is told of a plan: its legs, burns, figures and findings.
// Every figure is worded here, by the procs chat uses, not by the window.
/proc/rocket_designer_answer(datum/rocket_plan/D)
	var/list/legs = list()
	var/list/L = D.legs()
	for (var/id in L)
		var/list/leg = L[id]
		legs += list(list(
			"id" = id,
			"name" = leg["name"],
			"ok" = leg["ok"] ? 1 : 0,
			"need" = leg["need"],
			"have" = leg["have"],
			"needs" = rocket_dv_text(leg["need"]),
			"spare" = rocket_dv_text(leg["have"] - leg["need"]),
			"why" = leg["why"],
		))
	var/list/burns = list()
	var/dv = 0
	for (var/list/B in D.burns())
		dv += B["dv"]
		burns += list(list(
			"name" = B["name"],
			"dv" = rocket_dv_text(B["dv"]),
			"twr" = num2text(round(B["twr"], 0.01)),
			"thrust" = round(B["thrust"]),
			"service" = B["service"] ? 1 : 0,
		))
	var/sections = D.section_count()
	var/datum/design_report/R = D.check_design()
	. = list(
		"pieces" = D.stack.len,
		"max_pieces" = ROCKET_PLAN_MAX_PIECES,
		"sections" = sections,
		"max_sections" = ROCKET_PLAN_MAX_SECTIONS,
		"storeys" = -round(-sections / ROCKET_STOREY_SECTIONS),
		"mass" = num2text(round(D.total_mass(), 0.1)),
		"units" = D.propellant_units(),
		"dv" = dv,
		"dv_text" = rocket_dv_text(dv),
		"cost" = D.costs_text(),
		"legs" = legs,
		"hint" = D.next_leg_hint(),
		"burns" = burns,
		"stages" = rocket_designer_stages(D),
		"checks" = R.data(),
	)
	qdel(R)

/proc/rocket_designer_status(mob/user, text)
	user << output(list2params(list(text)), "[ROCKET_DESIGNER_WINDOW].browser:rocketStatus")

/proc/rocket_designer_stats(mob/user, datum/rocket_plan/D)
	user << output(list2params(list(json_encode(rocket_designer_answer(D)))), "[ROCKET_DESIGNER_WINDOW].browser:rocketPlan")

/datum/rocket_designer/Topic(href, list/href_list)
	var/mob/living/human/H = usr
	if (href_list["close"])
		if (H == drawer)
			qdel(src)
		return
	if (!href_list["rocket"] || H != drawer || rocket_designers()[H] != src)
		return
	if (!ship_designer_can_draw(H, sheet))
		rocket_designer_status(H, "Hold the sheet and a pen or pencil to draw on it.")
		return
	// Import and Export work the same in every designer (naval/draught_kinds.dm).
	if (href_list["rocket"] == "import")
		sheet.draught_import_in_window(H, ROCKET_DESIGNER_WINDOW)
		return
	if (sheet.draught_code && !sheet.rocket_plan_kind())
		rocket_designer_status(H, "The sheet already holds another drawing.")
		return
	var/export = href_list["rocket"] == "export"
	var/save = export || href_list["rocket"] == "save"
	if (!save)
		if (!isnull(last_preview) && world.time < last_preview + ROCKET_DESIGNER_PREVIEW_GAP)
			return
		last_preview = world.time
	// rocket_plan_from_code() refuses a frame or a booster count that is not
	// in the tables, a key that is no piece and more pieces than a plan holds.
	var/code = href_list["code"]
	if (!istext(code) || length(code) > DESIGN_CODE_ROCKET_MAX)
		rocket_designer_status(H, "The drawing could not be read.")
		return
	var/datum/rocket_plan/D = rocket_plan_from_code(code)
	if (!D)
		rocket_designer_status(H, "The drawing could not be read.")
		return
	D.name = rocket_plan_clean_name(href_list["name"])
	rocket_designer_stats(H, D)
	if (save)
		sheet.take_rocket(D)
		rocket_designer_status(H, "Saved on the sheet.")
		if (export)
			sheet.draught_export(H, D.name)
	qdel(D)

// Raw string: no DM interpolation inside, and never a double quote followed
// by a closing brace. Plain ES5 for the embedded browser. One @@DATA@@.
/proc/rocket_designer_page()
	return @{"<!DOCTYPE html>
<html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Rocket sheet</title><style>
html,body{height:100%}
body{background:#211c16;color:#e9dfc8;font-family:Verdana,sans-serif;font-size:12px;margin:0;overflow:hidden}
#wrap{display:flex;align-items:flex-start;padding:6px 8px 0 8px}
#plan{flex:0 0 384px;width:384px;margin-right:10px}
#side{flex:0 0 290px;width:290px;margin-right:10px}
#info{flex:1 1 0;min-width:0;overflow-y:auto}
.sec{border:1px solid #66513b;background:#30271e;margin-bottom:8px}
.sec h2{font-size:13px;margin:0;padding:5px 8px;border-bottom:2px solid #b48c4d}
.sec h2 span{float:right;font-size:11px;font-weight:normal;color:#bfae96;margin-top:1px}
.sec .in{padding:6px 8px}
button{background:#4a3a2a;color:#e9dfc8;border:1px solid #806040;margin:0;padding:3px 7px;cursor:pointer;font-family:Verdana,sans-serif;font-size:11px}
button:hover{border-color:#ffd985}
button.on{background:#b48c4d;color:#211c16;border-color:#ffd985}
button.go{flex:none;white-space:nowrap;background:#6b4d1f;border-color:#b48c4d;font-weight:bold;font-size:12px;padding:5px 14px}
input,select{background:#1d1916;color:#e9dfc8;border:1px solid #806040;font-family:Verdana,sans-serif;font-size:11px;height:22px;box-sizing:border-box;padding:1px 3px}
button.cd{flex:none;white-space:nowrap;margin-right:4px}
.row{display:flex;align-items:center;margin-bottom:5px}
.row label{flex:0 0 58px;color:#bfae96;font-size:11px}
.row .seg{display:flex;flex:1 1 auto}
.row .seg button{flex:1 1 0;margin-right:3px}
.row .seg button:last-child{margin-right:0}
.hint{color:#b0a080;font-size:11px;line-height:1.35}
.chip{display:inline-block;background:#211c16;border:1px solid #b48c4d;border-radius:3px;min-width:16px;text-align:center;font-size:12px;line-height:18px;height:18px;color:#ffd985;font-weight:bold}

/* The stack */
#plan .in{padding:6px 5px}
#g{position:relative;background:#0b1018;border:2px solid #0f0c09;overflow:hidden;cursor:pointer;-webkit-user-select:none;-ms-user-select:none;user-select:none}
#g svg{display:block;overflow:visible}
.t{position:absolute;cursor:pointer}
.t svg{position:absolute;left:0;top:0}
.t .k{position:absolute;left:2px;top:2px;font-size:9px;font-weight:bold;color:#ffd985;background:#211c16;border:1px solid #806040;border-radius:2px;line-height:10px;padding:0 2px;z-index:1}
.t.f .k{top:0;font-size:8px;line-height:9px}
.t .ring{position:absolute;left:0;top:0;right:0;bottom:0;pointer-events:none;z-index:2}
.t:hover .ring{box-shadow:inset 0 0 0 1px #ffd985}
.bo{position:absolute}
.pad{position:absolute;pointer-events:none}
.pad i{position:absolute;left:0;right:0;bottom:1px;text-align:center;font-style:normal;font-size:9px;letter-spacing:1px;text-transform:uppercase;color:#b0a080}
#ins{position:absolute;height:0;border-top:2px dashed #ffd985;pointer-events:none;display:none;z-index:4}
#ins b{position:absolute;right:100%;top:-9px;margin-right:3px;font-size:10px;line-height:14px;white-space:nowrap;color:#211c16;background:#ffd985;border-radius:2px;padding:0 4px}
.sy{position:absolute;left:3px;width:63px;box-sizing:border-box;border-right:2px solid #b48c4d;border-top:1px solid #b48c4d;border-bottom:1px solid #b48c4d;color:#e9dfc8;font-size:11px;line-height:12px;text-align:right;padding-right:5px;pointer-events:none;overflow:hidden}
.sy span{position:absolute;right:5px;top:50%;margin-top:-12px}
.sy u{display:block;text-decoration:none;font-size:9px;color:#b48c4d;white-space:nowrap}
.sy.cr{border-color:#7fb0d0}
.sy.cr u{color:#7fb0d0}
.tk{position:absolute;left:66px;width:5px;height:0;border-top:1px solid #8a7a60;pointer-events:none}
.sl{position:absolute;left:66px;height:0;border-top:1px dashed #7fb0d0;opacity:0.55;pointer-events:none}
.sg{position:absolute;width:74px;box-sizing:border-box;border-left:2px solid #bfae96;border-top:1px solid #bfae96;border-bottom:1px solid #bfae96;color:#e9dfc8;font-size:11px;line-height:12px;padding-left:6px;pointer-events:none;overflow:hidden}
.sg span{position:absolute;left:6px;top:50%;margin-top:-6px}
.sg.two span{margin-top:-12px}
.sg.pl{border-color:#ffd985}
.sg.pl span{color:#ffd985}
.sg.nb{border-color:#c77a39}
.sg.nb span{color:#f3a26a}
#none{position:absolute;left:76px;right:76px;top:38%;text-align:center}

/* Palette */
.ph{color:#bfae96;font-size:11px;margin:5px 0 3px 0}
.pal{display:flex;flex-wrap:wrap}
.pal button{display:flex;align-items:center;text-align:left;width:142px;height:32px;line-height:12px;padding:1px 4px 1px 3px;margin:0 3px 3px 0;overflow:hidden;box-sizing:border-box}
.pal button .ic{flex:none;width:44px;height:26px;margin-right:6px;background:#0b1018;border:1px solid #14100c;box-sizing:border-box;position:relative;overflow:hidden}
.pal button .ic svg,.pn .ic svg{position:absolute;left:50%;top:50%;overflow:visible}
.pal button .ic .chip,.pn .ic .chip{position:absolute;left:50%;top:50%;margin:-10px 0 0 -9px}
.pal button .nm{flex:1 1 auto;min-width:0}
.pal button .nm u{display:block;text-decoration:none;font-size:10px;color:#bfae96;white-space:nowrap}
.pal button.on .nm u{color:#3a2a14}
#st{flex:1 1 auto;min-width:0;color:#ffd985;margin-left:9px;font-size:11px;line-height:1.25}

/* Launch planner */
#bar{position:relative;height:12px;background:#1d1916;border:1px solid #54432f;margin:2px 0 0 0}
#bar .fill{position:absolute;left:0;top:0;bottom:0;background:#b48c4d}
#bar .tick{position:absolute;top:-3px;bottom:-3px;width:0;border-left:2px solid #e9dfc8}
#bar .tick.ok{border-color:#8fd08a}
#barl{position:relative;height:14px;font-size:10px;color:#bfae96;margin-bottom:5px}
#barl span{position:absolute;top:2px;white-space:nowrap}
.lg{display:flex;align-items:flex-start;margin-top:3px;padding:3px 7px 4px 6px;border:1px solid #54432f;border-left:3px solid #8a7a60;border-radius:3px;background:#262019;line-height:1.3}
.lg .mk{flex:0 0 16px;font-weight:bold;color:#8a7a60}
.lg .tx{flex:1 1 auto;min-width:0;color:#bfae96}
.lg .tx b{color:#e9dfc8}
.lg .tx .why{display:block;font-size:11px;margin-top:1px}
.lg .sp{flex:none;margin-left:8px;font-size:11px;color:#bfae96;white-space:nowrap}
.lg.ok{border-color:#3f6a3d;border-left-color:#6caa68;background:#253b25}
.lg.ok .mk{color:#8fd08a}
.lg.ok .tx b{color:#c4e8c0}
.lg.ok .sp{color:#c4e8c0}
.lg.must{border-left-color:#c77a39;background:#3a2a1a}
.lg.must .mk{color:#f3a26a}
.lg.must .tx{color:#f3c79a}
#lhint{margin-top:5px;padding:4px 7px;border:1px dashed #b48c4d;border-radius:3px;color:#f2dc8f;line-height:1.3}
table.bt{width:100%;border-collapse:collapse;margin-top:7px;font-size:11px}
table.bt th{font-weight:normal;color:#bfae96;text-align:right;padding:1px 4px;border-bottom:1px solid #54432f}
table.bt td{text-align:right;padding:2px 4px;border-bottom:1px solid #3a2f24}
table.bt th:first-child,table.bt td:first-child{text-align:left;padding-left:0}
table.bt tr.tot td{border-bottom:0;color:#ffd985;font-weight:bold}
.fg{display:flex;margin:7px 0 5px 0}
.fg div{flex:1 1 0;background:#262019;border:1px solid #54432f;padding:3px 0;text-align:center;margin-right:4px}
.fg div:last-child{margin-right:0}
.fg b{display:block;font-size:15px;color:#ffd985}
.fg b.bad{color:#f3a26a}
.fg span{font-size:10px;color:#bfae96}

/* Part and Checks */
#part{overflow:auto;line-height:1.35;box-sizing:border-box}
.pn{font-size:13px;font-weight:bold;margin-bottom:4px;display:flex;align-items:center}
.pn .ic{flex:none;width:52px;height:32px;margin-right:7px;background:#0b1018;border:1px solid #14100c;position:relative;overflow:hidden}
.pn .w{flex:1 1 auto}
.pn span.s{display:block;font-size:11px;font-weight:normal;color:#bfae96}
.pr{display:flex;margin-top:2px}
.pr i{flex:0 0 38px;font-style:normal;color:#b48c4d;font-size:11px;padding-top:1px}
.pr span{flex:1 1 auto;min-width:0}
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
</style></head><body><div id='wrap'>

<div id='plan'>
<div class='sec' style='margin-bottom:0'><h2>Rocket<span id='dims'></span></h2><div class='in'>
<div id='g'></div>
</div></div>
</div>

<div id='side'>
<div class='row'><label for='nm'>Name</label><input id='nm' maxlength='40' style='flex:1 1 auto;min-width:0' onchange='changed()' onkeyup='changed()'></div>
<div class='row'><label>Frame</label><div class='seg' id='fr'></div></div>
<div class='row'><label>Boosters</label><div class='seg' id='bs'></div></div>
<div class='ph'>Sections <span class='hint'>- one cell of the stack each</span></div><div class='pal' id='pm'></div>
<div class='ph'>Fittings <span class='hint'>- thin bands; they take no section</span></div><div class='pal' id='pf'></div>
<div class='row' style='margin-top:4px'><button onclick='undo()' style='margin-right:3px'>Undo</button><button onclick='redo()' style='margin-right:8px'>Redo</button><span class='hint' style='white-space:nowrap'>Start from&nbsp;</span><select id='ex' style='flex:1 1 auto;min-width:0;margin-right:4px'><option value=''>-</option></select><button onclick='loadExample()'>Load</button></div>
<div class='row'><button class='go' onclick='send(1)'>Save to the sheet</button><span id='st'></span></div>
<div class='row'><button class='cd' onclick='exportCode()' title='Save the drawing on the sheet and show its design code to copy'>Export code</button><button class='cd' onclick='importCode()' title='Paste a design code; it replaces what is drawn on this sheet'>Import code</button></div>
<div class='hint' style='margin-bottom:7px'>Pick a piece, then click the stack: it goes in at the dashed line. Drag a piece on the stack to move it. Right-click takes one out.</div>
<div class='sec' style='margin-bottom:0'><h2>Part</h2><div class='in' id='part'></div></div>
</div>

<div id='info'>
<div class='sec'><h2>Launch planner<span id='dvk'></span></h2><div class='in' id='planner'><span class='hint'>Reckoning...</span></div></div>
<div class='sec' style='margin-bottom:0'><h2>Checks<span id='chkn'></span></h2><div class='in' id='checks'><span class='hint'>Reckoning...</span></div></div>
</div>

</div><script>
var DATA=@@DATA@@;
var REF=DATA.REF,MAXP=DATA.MAXP,MAXS=DATA.MAXS,STOREY=DATA.STOREY||4,PIECES=DATA.PIECES,FRAMES=DATA.FRAMES||[],BOOST=DATA.BOOSTERS||[0],EXAMPLES=DATA.EXAMPLES||[],HELP=DATA.HELP||{};
var stack=[],frame='a',boost=0,cur='E',hist=[],fut=[],timer=null,lastSent=0;
var STAGES=[],CHK=[],lit=-1,pin=-1,peek=null;
var GH=640,SH=40,BND=[],armed=false,dragFrom=0,dragY=0,moved=false;
// Where things stand across the drawing, in pixels.
var XB=142,BW=76,FH=12,PADH=30,TOPGAP=12,BOW=16,SGX=286;
var LEVEL={error:['Fix','#ff6f3c'],warning:['Warning','#ffd23f'],note:['Note','#fff6dc']};
// What tells each piece apart, for the palette.
var HAS={E:'lifts off the pad',V:'for upper stages',T:'feeds its stage',D:'ends a stage',M:'burns last',C:'three seats',K:'hold items',Q:'uncrewed',X:'under the capsule',Y:'for a Moon return',R:'over the capsule',L:'under the shield',G:'to land on the Moon'};
function $(i){return document.getElementById(i);}
function esc(s){return (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;');}
function row(list,k){for(var i=0;i<list.length;i++)if(list[i][0]==k)return list[i];return null;}
function several(n,one){return n+' '+one+(n==1?'':'s');}
function cap(s){s=s+'';return s.charAt(0).toUpperCase()+s.substring(1);}
function tall(k){var r=row(PIECES,k);return r&&r[2]?1:0;}
function nameOf(k){if(k=='x')return 'eraser';if(k=='B')return 'strap-on boosters';var r=row(PIECES,k);return r?r[1]:k;}
function sections(){var n=0,i;for(i=0;i<stack.length;i++)if(tall(stack[i]))n++;return n;}

// ---- Pictures: every piece is drawn here, 72 wide and 40 (a section) or 12 (a fitting) tall ----
var FR={s:['#878f98','#aab2ba','#596069'],a:['#c3c9cf','#e9edf0','#8b9299']};
var INK=' stroke="#14100c" stroke-width="1"';
function R(x,y,w,h,f,o){return '<rect x="'+x+'" y="'+y+'" width="'+w+'" height="'+h+'" fill="'+f+'"'+(o||'')+'/>';}
function P(d,f,o){return '<path d="'+d+'" fill="'+f+'"'+(o||'')+'/>';}
function cyl(x,y,w,h,c){return R(x,y,w,h,c[0])+R(x+w*0.12,y,w*0.14,h,c[1])+R(x+w*0.8,y,w*0.2,h,c[2])+R(x,y,w,h,'none',INK);}
function hazard(x,y,w,h){var s=R(x,y,w,h,'#e0b83a'),i;for(i=x+2;i<x+w-6;i+=10)s+=P('M'+(i+4)+','+y+' L'+(i+8)+','+y+' L'+(i+4)+','+(y+h)+' L'+i+','+(y+h)+' Z','#2a2420');return s+R(x,y,w,h,'none',INK);}
function art(k){var F=FR[frame]||FR.s,D=['#474c53','#6a7078','#2c3035'],W=['#d9d3c3','#f2eee2','#a39c8a'],s,i;
switch(k){
case 'T':return cyl(2,0,68,40,F)+R(2,5,68,1.5,F[2])+R(2,33.5,68,1.5,F[2])+R(33,11,2,18,F[2])+R(30,11,8,2,F[2]);
case 'E':return cyl(12,0,48,9,D)+P('M27,9 L45,9 L61,37 L11,37 Z','#34383d',INK)+P('M30,9 L35,9 L29,37 L19,37 Z','#5a6068')+R(10,36,52,4,'#b4753f',INK)+R(18,3,6,3,'#b4753f')+R(48,3,6,3,'#b4753f');
case 'V':return cyl(22,0,28,6,D)+P('M32,6 L40,6 Q44,26 63,37 L9,37 Q28,26 32,6 Z','#6b5645',INK)+P('M33,6 L36,6 Q33,26 22,37 L16,37 Q30,26 33,6 Z','#8d7460')+R(8,36,56,3,'#d08a45',INK);
case 'D':return R(3,8,66,28,'#05080c',' opacity="0.6"')+P('M4,8 L20,36 L36,8 L52,36 L68,8','none',' stroke="'+F[2]+'" stroke-width="2.5"')+P('M4,36 L20,8 L36,36 L52,8 L68,36','none',' stroke="'+F[0]+'" stroke-width="2.5"')+hazard(2,0,68,8)+cyl(2,35,68,5,F);
case 'M':return cyl(6,0,60,27,W)+R(14,5,10,16,'#2b3036',INK)+R(48,5,10,16,'#2b3036',INK)+R(31,9,10,3,'#b4753f')+P('M30,27 L42,27 L48,38 L24,38 Z','#34383d',INK)+R(23,37,26,3,'#b4753f',INK);
case 'C':return P('M24,2 L48,2 L68,36 L4,36 Z',W[0],INK)+P('M27,3 L33,3 L22,35 L11,35 Z',W[1])+P('M47,10 L52,10 L67,35.5 L58,35.5 Z',W[2],' opacity="0.6"')+'<rect x="32" y="13" width="9" height="8" rx="2" fill="#16283a" stroke="#14100c"/>'+R(34,14.5,3,2,'#6fa3c7')+R(4,36,64,4,'#7d7667',INK);
case 'K':return cyl(2,0,68,40,F)+R(14,5,44,30,'none',' stroke="'+F[2]+'" stroke-width="1.5"')+R(35.2,5,1.6,30,F[2])+R(11,10,3,5,D[0])+R(11,25,3,5,D[0])+R(58,10,3,5,D[0])+R(58,25,3,5,D[0]);
case 'Q':s=R(-4,17,26,11,'#24406a',INK)+R(50,17,26,11,'#24406a',INK);for(i=0;i<3;i++)s+=R(2+i*6,17,1,11,'#5f86b8')+R(56+i*6,17,1,11,'#5f86b8');
return s+R(22,12,28,22,'#b9953f',INK)+R(25,15,8,6,'#8a6c24')+R(39,24,8,6,'#8a6c24')+R(35,8,2,4,'#14100c')+'<ellipse cx="36" cy="6" rx="12" ry="4.5" fill="#e6e1d3" stroke="#14100c"/>'+R(27,34,18,6,D[0],INK);
case 'X':return P('M5,1 L67,1 Q62,11 36,11 Q10,11 5,1 Z','#9a6234',INK)+P('M13,3.5 L59,3.5','none',' stroke="#c98a52" stroke-width="1"');
case 'Y':return P('M3,0 L69,0 L67,4 Q60,12 36,12 Q12,12 5,4 Z','#3d2a1f',INK)+R(3,0,66,3,'#b4753f',INK)+P('M14,7 Q36,11 58,7','none',' stroke="#7a5238" stroke-width="1"');
case 'R':return '<rect x="23" y="1" width="26" height="10" rx="3" fill="#d9792b" stroke="#14100c"/>'+R(30,1.5,4,9,'#f2eee2')+R(38,1.5,4,9,'#f2eee2');
case 'L':s=R(8,2,56,6,D[0],INK)+R(8,2,56,2,D[1]);for(i=0;i<4;i++)s+=P('M'+(12+i*14)+',8 L'+(18+i*14)+',8 L'+(20+i*14)+',12 L'+(10+i*14)+',12 Z','#b4753f',INK);return s;
case 'G':return P('M9,5 L-11,12','none',' stroke="'+F[2]+'" stroke-width="3"')+P('M63,5 L83,12','none',' stroke="'+F[2]+'" stroke-width="3"')+R(-17,10.5,12,2.5,'#14100c')+R(77,10.5,12,2.5,'#14100c')+R(6,2,60,6,F[0],INK);
}
return '';}
function svg(k,w,h,st){return '<svg width="'+w+'" height="'+h+'" viewBox="0 0 72 '+(tall(k)?40:12)+'" preserveAspectRatio="none"'+(st?' style="'+st+'"':'')+'>'+art(k)+'</svg>';}
function boosterSvg(w,h,st){return '<svg width="'+w+'" height="'+h+'" viewBox="0 0 16 100" preserveAspectRatio="none"'+(st?' style="'+st+'"':'')+'>'+P('M8,0 L15,13 L1,13 Z','#c9502e',INK)+cyl(1,13,14,77,['#e2ddcf','#fbf9f2','#a9a391'])+R(1,38,14,3,'#2a2420')+R(1,72,14,3,'#2a2420')+P('M4,90 L12,90 L15,100 L1,100 Z','#34383d',INK)+'</svg>';}
function padSvg(w){return '<svg width="'+w+'" height="'+PADH+'" viewBox="0 0 220 30" preserveAspectRatio="none">'+P('M84,10 L136,10 L148,30 L72,30 Z','#05080c')+R(18,10,14,20,'#3e4246',INK)+R(188,10,14,20,'#3e4246',INK)+R(52,10,10,20,'#3e4246',INK)+R(158,10,10,20,'#3e4246',INK)+R(0,0,220,6,'#6a6f74',INK)+hazard(0,6,220,4)+'</svg>';}
// A piece's picture for the palette and the Part panel, in a box w by h.
function pic(k,w,h){var pw,ph;
if(k=='x')return '<span class="ic" style="width:'+w+'px;height:'+h+'px"><span class="chip">&#215;</span></span>';
if(k=='B')return '<span class="ic" style="width:'+w+'px;height:'+h+'px">'+boosterSvg(6,h-6,'margin:'+(-(h-6)/2)+'px 0 0 -8px')+boosterSvg(6,h-6,'margin:'+(-(h-6)/2)+'px 0 0 2px')+'</span>';
if(!row(PIECES,k)||!art(k))return '<span class="ic" style="width:'+w+'px;height:'+h+'px"><span class="chip">'+esc(k)+'</span></span>';
pw=Math.round((h-6)*1.5);ph=tall(k)?h-6:Math.round(pw/6);
return '<span class="ic" style="width:'+w+'px;height:'+h+'px">'+svg(k,pw,ph,'margin:'+(-ph/2)+'px 0 0 '+(-pw/2)+'px')+'</span>';}

// ---- The plan ----
function load(sheet){var i,t=(sheet[3]||'')+'',k;$('nm').value=sheet[0];frame=row(FRAMES,sheet[1])?sheet[1]:(FRAMES.length?FRAMES[0][0]:'s');boost=+sheet[2]||0;stack=[];
for(i=0;i<t.length&&stack.length<MAXP;i++){k=t.charAt(i);if(row(PIECES,k))stack.push(k);}}
function snap(){return {s:stack.slice(0),f:frame,b:boost};}
function back(o){stack=o.s;frame=o.f;boost=o.b;}
function push(s){hist.push(s||snap());if(hist.length>60)hist.shift();fut=[];}
function after(){status('');draw();marks();part();changed();}
function undo(){if(!hist.length){status('Nothing to undo.');return;}fut.push(snap());back(hist.pop());after();}
function redo(){if(!fut.length){status('Nothing to redo.');return;}hist.push(snap());back(fut.pop());after();}
function tool(t){cur=t;marks();part();}
function setFrame(f){if(f==frame)return;push();frame=f;after();palette();}
function setBoost(n){if(n==boost)return;push();boost=n;after();}
// p pieces stay below the new one: 0 is on the pad.
function insert(k,p){if(!row(PIECES,k))return;
if(stack.length>=MAXP){status('A sheet holds '+MAXP+' pieces at most.');return;}
if(tall(k)&&sections()>=MAXS){status('A launch stand takes '+MAXS+' sections at most.');return;}
push();stack.splice(p,0,k);after();}
function remove(i){if(i<1||i>stack.length)return;push();stack.splice(i-1,1);after();}
function move(i,p){var k;if(p==i||p==i-1){draw();return;}push();k=stack.splice(i-1,1)[0];if(p>i-1)p--;stack.splice(p,0,k);after();}
function loadExample(){var i=$('ex').value;if(i==='')return;push();load(EXAMPLES[+i]);after();palette();}

// ---- Drawing ----
// BND[p] is the height of the joint with p pieces below it; BND[0] is the pad.
function layout(){var n=stack.length,i,s=0,f=0,y;
for(i=0;i<n;i++){if(tall(stack[i]))s++;else f++;}
SH=Math.floor((GH-PADH-TOPGAP-Math.max(f,3)*FH)/Math.max(s,MAXS));if(SH>40)SH=40;if(SH<14)SH=14;
y=GH-PADH;BND=[y];for(i=0;i<n;i++){y-=tall(stack[i])?SH:FH;BND.push(y);}}
function segments(){var o=[],from=1,i;for(i=1;i<=stack.length;i++)if(stack[i-1]=='D'){o.push([from,i]);from=i+1;}if(from<=stack.length)o.push([from,stack.length]);return o;}
// The storeys of the launch stand: the first is fitted from the stand's own
// level, the ones above are lowered on by crane from the level over them.
function ruler(){var h='',i,sc=0,st=[],c,n,top;
for(i=0;i<stack.length;i++){if(!tall(stack[i]))continue;if(sc%STOREY==0)st.push([BND[i],BND[i+1]]);else st[st.length-1][1]=BND[i+1];sc++;
h+='<div class="tk" style="top:'+BND[i+1]+'px"></div>';}
for(i=0;i<st.length;i++){c=i>0;n=st[i][0]-st[i][1];top=st[i][1];
h+='<div class="sy'+(c?' cr':'')+'" style="top:'+top+'px;height:'+n+'px"><span>Storey '+(i+1)+'<u>'+(c?'by crane':'at the stand')+'</u></span></div>';
if(i<st.length-1)h+='<div class="sl" style="top:'+top+'px;width:'+(SGX-66)+'px" title="Above this line the pieces are lowered on by crane from the level above"></div>';}
return h;}
function brackets(){var h='',S=segments(),j,y0,y1,lab,cls,two;
for(j=0;j<S.length;j++){y0=BND[S[j][0]-1];y1=BND[S[j][1]];lab=STAGES.length==S.length?STAGES[j]:'';
cls=lab=='No burn'?' nb':(lab.indexOf('ayload')>=0?' pl':'');two=lab.indexOf(' + ')>=0;
if(two)lab=esc(lab).replace(' + ','<br>+ ');else lab=esc(lab);
h+='<div class="sg'+cls+(two?' two':'')+'" style="left:'+SGX+'px;top:'+(y1+2)+'px;height:'+Math.max(4,y0-y1-4)+'px"><span>'+(y0-y1>=(two?26:14)?lab:'')+'</span></div>';}
return h;}
function boosters(){var h='',S=segments(),n=boost/2,i,top,hh,x;if(!boost||!S.length)return '';
hh=Math.max(54,Math.min(BND[0]-BND[S[0][1]]-4,5*SH));top=BND[0]-hh;
for(i=0;i<n;i++){x=XB-(i+1)*(BOW+2);h+='<div class="bo" id="B_d'+i+'" style="left:'+x+'px;top:'+top+'px" title="Strap-on booster">'+boosterSvg(BOW,hh)+'</div>';
x=XB+BW+2+i*(BOW+2);h+='<div class="bo" id="B_e'+i+'" style="left:'+x+'px;top:'+top+'px" title="Strap-on booster">'+boosterSvg(BOW,hh)+'</div>';}
return h;}
function draw(){var g=$('g'),h='',i,k,hh;layout();
g.style.height=GH+'px';
h+='<div class="pad" style="left:74px;top:'+BND[0]+'px;width:212px;height:'+PADH+'px">'+padSvg(212)+'<i>launch stand</i></div>';
h+=ruler()+boosters();
for(i=0;i<stack.length;i++){k=stack[i];hh=BND[i]-BND[i+1];
h+='<div class="t'+(tall(k)?'':' f')+'" id="c_'+(i+1)+'" style="left:'+XB+'px;top:'+BND[i+1]+'px;width:'+BW+'px;height:'+hh+'px" title="'+esc(cap(nameOf(k)))+'" onmousedown="cdown('+(i+1)+',event)" oncontextmenu="remove('+(i+1)+');return false;">'+svg(k,BW,hh)+'<span class="k">'+esc(k)+'</span><span class="ring"></span></div>';}
h+=brackets();
if(!stack.length)h+='<div id="none" class="hint">Nothing on the stand yet. Pick a sea-level engine and click here.</div>';
h+='<div id="ins" style="left:'+(XB-8)+'px;width:'+(BW+16)+'px"><b id="insl"></b></div>';
g.innerHTML=h;
$('dims').innerHTML=several(sections(),'section')+' of '+MAXS+' &middot; '+several(stack.length,'piece')+' of '+MAXP;light();}
function pbtn(k){var n=k=='x'?'eraser':nameOf(k),u=k=='x'?'takes a piece out':(HAS[k]||'');if(n.length>16)u='';return '<button id="t_'+k+'" onmousedown="pdown(\''+k+'\',event)">'+pic(k,44,26)+'<span class="nm">'+esc(cap(n))+(u?'<u>'+esc(u)+'</u>':'')+'</span></button>';}
function palette(){var a='',b='',i;for(i=0;i<PIECES.length;i++){if(PIECES[i][2])a+=pbtn(PIECES[i][0]);else b+=pbtn(PIECES[i][0]);}
$('pm').innerHTML=a;$('pf').innerHTML=b+pbtn('x');
a='';for(i=0;i<FRAMES.length;i++)a+='<button id="F_'+FRAMES[i][0]+'" onclick="setFrame(\''+FRAMES[i][0]+'\')">'+esc(cap(FRAMES[i][1]))+'</button>';$('fr').innerHTML=a;
a='';for(i=0;i<BOOST.length;i++)a+='<button id="B_s'+(+BOOST[i])+'" onclick="setBoost('+(+BOOST[i])+')">'+(+BOOST[i]?+BOOST[i]:'None')+'</button>';$('bs').innerHTML=a;
marks();}
function marks(){var b=document.getElementsByTagName('button'),i,d;for(i=0;i<b.length;i++){d=b[i].id;
if(d.indexOf('t_')==0)b[i].className=d=='t_'+cur?'on':'';
else if(d.indexOf('F_')==0)b[i].className=d=='F_'+frame?'on':'';
else if(d.indexOf('B_s')==0)b[i].className=d=='B_s'+boost?'on':'';}}

// ---- The mouse on the stack ----
// The joint nearest the pointer is where a piece goes in.
function joint(e){var y=e.clientY-$('g').getBoundingClientRect().top,i,best=0,d=1e9;for(i=0;i<BND.length;i++)if(Math.abs(BND[i]-y)<d){d=Math.abs(BND[i]-y);best=i;}return best;}
function showJoint(e){var m=$('ins'),p;if(!m)return;
if(cur=='x'&&!moved){m.style.display='none';return;}
p=joint(e);m.style.top=(BND[p]-1)+'px';m.style.display='block';$('insl').innerHTML=esc(moved?nameOf(stack[dragFrom-1]):nameOf(cur));}
function pdown(k,e){e=e||window.event;tool(k);armed=true;if(e&&e.preventDefault)e.preventDefault();}
function cdown(i,e){e=e||window.event;if(e.button==2)return;dragFrom=i;dragY=e.clientY;moved=false;}
function gdown(e){e=e||window.event;if(e.button==2)return;armed=true;if(e.preventDefault)e.preventDefault();}
function gmove(e){e=e||window.event;var c;
if(dragFrom&&!moved&&Math.abs(e.clientY-dragY)>5){if(e.buttons!==undefined&&!(e.buttons&1)){dragFrom=0;}else{moved=true;c=$('c_'+dragFrom);if(c)c.style.opacity=0.4;}}
showJoint(e);}
function gup(e){e=e||window.event;var p,from=dragFrom,mv=moved,was=armed;if(e.button==2)return;
armed=false;dragFrom=0;moved=false;if(!was)return;p=joint(e);
if(from&&mv)move(from,p);else if(cur=='x'){if(from)remove(from);}else insert(cur,p);
showJoint(e);}
function gout(e){e=e||window.event;var to=e.relatedTarget||e.toElement,g=$('g'),m=$('ins');while(to){if(to==g)return;to=to.parentNode;}if(m)m.style.display='none';}
document.onmouseup=function(){var was=moved;armed=false;dragFrom=0;moved=false;if(was)draw();};

// ---- Talking to the server ----
function code(){var nm=$('nm').value.replace(/[\/;,]/g,' ').replace(/^\s+|\s+$/g,'').replace(/ /g,'_');if(!nm)nm='rocket';
return 'C13ROCKET/1/'+nm+'/'+frame+'/'+boost+'/'+stack.join('');}
// Export saves like Save and then shows the code; Import asks for one.
function exportCode(){send('export');}
function importCode(){if(timer){clearTimeout(timer);timer=null;}location.href='byond://?src='+REF+';rocket=import';}
function send(save){if(timer){clearTimeout(timer);timer=null;}lastSent=new Date().getTime();if(save)status('Saving...');
location.href='byond://?src='+REF+';rocket='+(save=='export'?'export':save?'save':'preview')+';code='+encodeURIComponent(code())+';name='+encodeURIComponent($('nm').value);}
// The server answers once per 0.3 s: wait out the gap, so the last change
// is never the one it skips.
function changed(){if(timer)clearTimeout(timer);var wait=Math.max(300,450-(new Date().getTime()-lastSent));timer=setTimeout(function(){timer=null;send(0);},wait);}
function status(t){$('st').innerHTML=t;}
function rocketStatus(t){status(esc(t));}
function parse(s){var A=null;try{A=JSON.parse(s);}catch(e){A=null;}
if(!A){s=(s+'').replace(/\+/g,' ');try{s=decodeURIComponent(s);}catch(e2){}try{A=JSON.parse(s);}catch(e3){A=null;}}
return A;}
// The delta-v the rocket has, against what each leg needs from the pad.
function budget(A){var L=A.legs||[],i,top=+A.dv||0,h,l='',x,last=-99,seen={},n;
for(i=0;i<L.length;i++)if(+L[i].need>top)top=+L[i].need;
if(top<=0)return '';top*=1.06;
h='<div id="bar" title="Delta-v: what the rocket has against what each leg needs"><div class="fill" style="width:'+Math.min(100,(+A.dv||0)/top*100)+'%"></div>';
for(i=0;i<L.length;i++){n=+L[i].need;if(!(n>0)||seen[L[i].needs])continue;seen[L[i].needs]=1;x=n/top*100;
h+='<div class="tick'+((+A.dv||0)>=n?' ok':'')+'" style="left:'+x+'%" title="'+esc(L[i].name)+' needs '+esc(L[i].needs)+'"></div>';
if(x-last>=7){l+='<span style="left:'+x+'%;margin-left:-8px">'+esc(L[i].needs)+'</span>';last=x;}}
return h+'</div><div id="barl">'+l+'</div>';}
function planner(A){var L=A.legs||[],B=A.burns||[],i,g,o=budget(A),must,bad;
for(i=0;i<L.length;i++){g=L[i];must=!+g.ok&&(g.id=='liftoff'||g.id=='orbit');
o+='<div class="lg'+(+g.ok?' ok':(must?' must':''))+'"><span class="mk">'+(+g.ok?'&#10003;':(must?'&#10007;':'&#9675;'))+'</span><span class="tx"><b>'+esc(g.name)+'</b>'+(+g.ok||!g.why?'':'<span class="why">Missing: '+esc(g.why)+'.</span>')+'</span><span class="sp">'+(+g.ok?(+g.need>0?esc(g.spare)+' to spare':'yes'):(+g.need>0?'needs '+esc(g.needs):'no'))+'</span></div>';}
if(A.hint)o+='<div id="lhint"><b>Next:</b> '+esc(A.hint)+'</div>';
o+='<table class="bt"><tr><th>Burn</th><th>Delta-v</th><th>Thrust / weight</th><th>Thrust, kN</th></tr>';
for(i=0;i<B.length;i++)o+='<tr><td>'+esc(B[i].name)+'</td><td>'+esc(B[i].dv)+'</td><td>'+esc(B[i].twr)+'</td><td>'+(+B[i].thrust)+'</td></tr>';
if(!B.length)o+='<tr><td colspan="4" class="hint" style="text-align:left">No stage burns yet: a stage needs an engine and a tank.</td></tr>';
o+='<tr class="tot"><td>All burns</td><td>'+esc(A.dv_text)+'</td><td></td><td></td></tr></table>';
bad=+A.sections>+A.max_sections;
o+='<div class="fg"><div><b>'+esc(A.mass)+'</b><span>tonnes on the pad</span></div><div><b>'+(+A.units)+'</b><span>units of propellant</span></div><div><b'+(bad?' class="bad"':'')+'>'+(+A.sections)+'</b><span>sections of '+(+A.max_sections)+'</span></div><div><b>'+(+A.storeys)+'</b><span>'+(+A.storeys==1?'storey':'storeys')+'</span></div></div>';
o+='<div><span class="hint">Cost</span> &nbsp;'+(A.cost?'The rocket works builds her for <b>'+esc(A.cost)+'</b>.':'Nothing to build yet.')+'</div>';
$('planner').innerHTML=o;$('dvk').innerHTML='delta-v '+esc(A.dv_text);}
// The server's answer: the legs, the burns, the figures and the findings.
function rocketPlan(s){var A=parse(s);if(!A)return;
STAGES=A.stages||[];planner(A);if(!moved)draw();checks(A.checks||[]);}

// ---- The Part and Checks panels ----
function finding(){var i=lit>=0?lit:pin;return i>=0&&CHK[i]?CHK[i]:null;}
function part(){var f=finding(),k,H,R2=[['what','What'],['use','Use'],['how','How']],i,why,h;
if(f&&f.part){k=f.part;why='named by the check';}
else if(peek){k=peek.substring(1);why=peek.charAt(0)=='t'?(k==cur?'picked to put on the stack':'click to pick it'):(peek.charAt(0)=='b'?(boost?boost+' beside the first stage':'none strapped on'):'on the stack');}
else{k=cur;why=k=='x'?'click a piece to take it out':'picked to put on the stack';}
H=HELP[k];
h='<div class="pn">'+pic(k,52,32)+'<span class="w">'+esc(cap(nameOf(k)))+'<span class="s">'+why+'</span></span></div>';
if(H)for(i=0;i<R2.length;i++)if(H[R2[i][0]])h+='<div class="pr"><i>'+R2[i][1]+'</i><span>'+esc(H[R2[i][0]])+'</span></div>';
$('part').innerHTML=h;}
function light(){var f=finding(),i,td,col,s;
for(i=1;i<=stack.length;i++){td=$('c_'+i);s=td&&td.lastChild;if(s&&s.className=='ring'){s.style.outline='';s.style.boxShadow='';}}
if(!f)return;col=LEVEL[f.level][1];
for(i=0;i<f.cells.length;i++){td=$('c_'+(+f.cells[i]));if(!td||!td.lastChild)continue;s=td.lastChild;
s.style.outline='3px solid '+col;s.style.outlineOffset='-1px';s.style.boxShadow='inset 0 0 0 2px rgba(20,12,6,0.75)';}}
function where(i){return i==pin?'&#9679; ringed on the stack':'&#9675; '+several(CHK[i].cells.length,'piece')+' on the stack';}
function mark(){var i,b,f,w;for(i=0;i<CHK.length;i++){b=$('ck_'+i);if(!b)continue;f=CHK[i];
b.className='ck '+f.level+(f.cells.length||f.part?' has':'')+(i==pin?' pin':'')+(i==lit?' lit':'');w=$('wh_'+i);if(w)w.innerHTML=where(i);}}
function show(i){lit=i;mark();part();light();}
function keep(i){pin=pin==i?-1:i;mark();part();light();}
function hook(i){var b=$('ck_'+i);b.onmouseenter=b.onfocus=function(){show(i);};b.onmouseleave=b.onblur=function(){if(lit==i)show(-1);};b.onclick=function(){keep(i);};}
function checks(A){var i,f,was=CHK[pin]?CHK[pin].text:null,n=[0,0,0],h='',p=[];
if(!A||!A.length)A=[];
CHK=[];lit=-1;pin=-1;for(i=0;i<A.length;i++){f={level:LEVEL[A[i].level]?A[i].level:'note',text:A[i].text||'',cells:A[i].cells||[],part:A[i].part||''};CHK.push(f);if(was!==null&&f.text==was)pin=i;n[f.level=='error'?0:(f.level=='warning'?1:2)]++;}
if(n[0])h+='<div class="vd bad"><b>Not ready to build.</b> '+several(n[0],'thing')+' to fix first.</div>';
else h+='<div class="vd"><b>Ready to build.</b> As drawn she lifts off and reaches orbit; the launch planner says how much farther she goes.'+(n[1]?'<div class="also">'+several(n[1],'warning')+' below will not stop the build, but read '+(n[1]==1?'it':'them')+' first.</div>':'')+'</div>';
for(i=0;i<CHK.length;i++){f=CHK[i];h+='<div tabindex="0" id="ck_'+i+'" class="ck"'+(f.cells.length?' title="Click to keep it ringed on the stack; click again to let go"':'')+'><span class="tag">'+LEVEL[f.level][0]+'</span><span class="tx">'+esc(f.text)+(f.cells.length?'<span class="wh" id="wh_'+i+'"></span>':'')+'</span></div>';}
$('checks').innerHTML=h;if(n[0])p.push(n[0]+' to fix');if(n[1])p.push(several(n[1],'warning'));if(n[2])p.push(several(n[2],'note'));$('chkn').innerHTML=p.join(' &middot; ');
for(i=0;i<CHK.length;i++)hook(i);
mark();part();light();}
// Pointing at a piece in the palette or on the stack shows what it is.
document.onmouseover=function(e){e=e||window.event;var b=e.target||e.srcElement,k=null,v;if(moved)return;
while(b&&b!=document.body){if(b.id){
if(b.id.indexOf('t_')==0){k='t'+b.id.substring(2);break;}
if(b.id.indexOf('B_')==0){k='bB';break;}
if(b.id.indexOf('c_')==0){v=stack[+b.id.substring(2)-1];k=v?'c'+v:null;break;}}
b=b.parentNode;}
if(k!=peek){peek=k;part();}};
// The drawing and the panels fill the window's height, whatever it is.
function fit(){var h=(window.innerHeight||document.documentElement.clientHeight||760),g=$('g'),p=$('part'),n=$('info'),was=GH;
GH=Math.max(360,Math.round(h-g.getBoundingClientRect().top-13));if(GH!=was||!g.firstChild)draw();
p.style.height=Math.max(90,h-p.getBoundingClientRect().top-9)+'px';
n.style.height=Math.max(200,h-n.getBoundingClientRect().top-6)+'px';}
window.onresize=fit;
(function(){var e=$('ex'),g=$('g'),j,o;for(j=0;j<EXAMPLES.length;j++){o=document.createElement('option');o.value=j;o.innerHTML=esc(EXAMPLES[j][0]);e.appendChild(o);}
g.onmousedown=gdown;g.onmousemove=gmove;g.onmouseup=gup;g.onmouseout=gout;
load(DATA.START);cur=PIECES.length?PIECES[0][0]:'x';palette();fit();part();changed();})();
</script></body></html>"}

#undef ROCKET_DESIGNER_WINDOW
#undef ROCKET_DESIGNER_PREVIEW_GAP
