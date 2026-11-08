// TDM barracks and battle worlds (shard kinds BARRACKS and BATTLE).
//
// The barracks is an always-on world where players wait and practise between
// TDM rounds. The battle world runs the rounds: it reports its state to the
// barracks every few seconds, sends every player's results when a round ends,
// and links everyone back to the barracks before it reboots. Both worlds learn
// each other from config/shard_region.json and share config/tdm-token.txt,
// which scripts/shard-group/shard_group.py setup writes. See docs/tdm-barracks.md.

#define TDM_REPORT_INTERVAL 100
// A battle status older than this means the battle world stopped reporting.
#define TDM_STATUS_STALE 600

var/global/datum/tdm_link/tdm_link = new

/datum/tdm_link
	var/configured = FALSE
	var/token = null
	var/barracks_id = null
	var/battle_id = null

// Reads the pair from the region group once it is configured. Off unless this
// world is a BARRACKS or BATTLE region, the group has both, and the token exists.
/datum/tdm_link/proc/configure()
	configured = TRUE
	token = null
	barracks_id = null
	battle_id = null
	if(!shard_group.enabled || !(shard_group.kind in list("BARRACKS", "BATTLE")))
		return FALSE
	if(shard_group.kind == "BARRACKS")
		barracks_id = shard_group.region
	else
		battle_id = shard_group.region
	for(var/id in shard_group.order)
		var/list/peer = shard_group.peers[id]
		if(peer["kind"] == "BARRACKS" && !barracks_id)
			barracks_id = id
		else if(peer["kind"] == "BATTLE" && !battle_id)
			battle_id = id
	if(!barracks_id || !battle_id)
		world.log << "TDM barracks: the group needs one BARRACKS and one BATTLE region; the link stays off."
		return FALSE
	if(!fexists("config/tdm-token.txt") || length(file("config/tdm-token.txt")) > 128)
		world.log << "TDM barracks: config/tdm-token.txt is missing; the link stays off."
		return FALSE
	var/value = trim(file2text("config/tdm-token.txt"))
	if(length(value) < 16)
		world.log << "TDM barracks: config/tdm-token.txt is too short; the link stays off."
		return FALSE
	token = value
	return TRUE

/datum/tdm_link/proc/ready()
	if(!configured)
		configure()
	return !!token

/proc/tdm_battle_active()
	return tdm_link.ready() && shard_group.kind == "BATTLE"

/proc/tdm_barracks_active()
	return tdm_link.ready() && shard_group.kind == "BARRACKS"

// Sends one report to the barracks over loopback. Blocks for the round trip,
// which is short on one host. TRUE when the barracks accepted it.
/datum/tdm_link/proc/report(kind, list/data)
	if(!ready() || shard_group.kind != "BATTLE")
		return FALSE
	var/list/peer = shard_group.peers[barracks_id]
	if(!peer)
		return FALSE
	// A frozen world holds a connection until it thaws, and world.Export would
	// hold this world with it. The group config keeps both worlds awake
	// (freeze_idle_minutes); this guards a host that does not.
	if(peer["state"] in list("ASLEEP", "COLD", "STOPPED"))
		return FALSE
	var/answer = null
	try
		answer = world.Export("byond://[shard_group.peer_address(peer)]?tdm_report=1&kind=[url_encode(kind)]&token=[url_encode(token)]&data=[url_encode(json_encode(data))]&format=json")
	catch
		answer = null
	if(!istext(answer))
		return FALSE
	var/list/reply = null
	try
		reply = json_decode(answer)
	catch
		reply = null
	return islist(reply) && reply["ok"]

/datum/world_topic/tdm_report
	keyword = "tdm_report"

/datum/world_topic/tdm_report/Run(list/input)
	if(!tdm_barracks_active() || input["token"] != tdm_link.token)
		return list("ok" = 0)
	var/list/data = null
	try
		data = json_decode(input["data"])
	catch
		data = null
	if(!islist(data))
		return list("ok" = 0)
	switch(input["kind"])
		if("status")
			tdm_barracks.receive_status(data)
		if("results")
			tdm_barracks.receive_results(data)
		else
			return list("ok" = 0)
	return list("ok" = 1)

/hook/startup/proc/tdm_link_startup()
	tdm_link.configure()
	if(tdm_battle_active())
		tdm_battle.start()
	else if(tdm_barracks_active())
		tdm_barracks.start()
	return TRUE

// Plain text for a number of seconds: 4:05, 1:02:03.
/proc/tdm_clock(seconds)
	seconds = max(0, round(seconds))
	var/hours = round(seconds / 3600)
	var/minutes = round((seconds % 3600) / 60)
	var/rest = seconds % 60
	var/text = "[minutes < 10 && hours ? "0" : ""][minutes]:[rest < 10 ? "0" : ""][rest]"
	return hours ? "[hours]:[text]" : text
