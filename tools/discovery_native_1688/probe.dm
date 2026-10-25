// Full-source headless probe. No normal startup, connections or UI acceptance.
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 8
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/client/New()
	del(src)
	return

/obj/map_metadata/discovery_tester/New()
	return

/mob/living/human/discovery_tester/New()
	return

var/mob/discovery_chat_recipient
var/discovery_chat_text
var/discovery_chat_count = 0
var/discovery_prelearn_count = 0
var/mob/discovery_notes_recipient
var/discovery_notes_text
var/discovery_notes_count = 0

// Only the exact production smell to_chat sink is redirected to this recorder.
// The production action, descriptor, escaping and subsequent learn hook remain.
/proc/discovery_capture_chat(mob/recipient, message)
	discovery_chat_recipient = recipient
	discovery_chat_text = message
	discovery_chat_count++
	discovery_prelearn_count = (recipient.mind && islist(recipient.mind.learned_discoveries)) ? recipient.mind.learned_discoveries.len : 0

// Only the production show_memory client-presence check and final browse sink
// are adapted. Ownership guard and HTML construction remain production code.
/proc/discovery_capture_notes(mob/recipient, message)
	discovery_notes_recipient = recipient
	discovery_notes_text = message
	discovery_notes_count++

/proc/discovery_check(condition, message)
	return discovery_record(condition, message)

/proc/discovery_setup()
	world.OpenPort("none")
	discovery_check(!world.port, "fixture has no open port")
	discovery_check(!world.OpenPort(12345) && !world.port, "fixture refuses reopening its port")
	if (config)
		config.webhook_can_fire = FALSE
	if (!chemical_reagents_list)
		initialize_chemical_reagents()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.nanomanager = new /datum/nanomanager
	// Native controller/datum ancestors declare no New hooks; do not call pregame.
	ticker = new /datum/controller/gameticker
	map = new /obj/map_metadata/discovery_tester
	map.ID = MAP_NOMADS_EUROPE
	// Known fixture-only poison data must not become character knowledge merely
	// because it exists. Reagents and their real sensed descriptors remain real.
	map.berryeffects = list(list("tinto", "poisonous", "cyanide"), list("hidden-configuration-marker", "not-a-sensed-effect", "water"))

/proc/discovery_actor(turf/T)
	var/mob/living/human/discovery_tester/H = new(T)
	H.stat = CONSCIOUS
	H.real_name = "Discovery character"
	H.mind_initialize()
	H.mind.active = FALSE
	return H

/proc/discovery_count(datum/mind/M)
	return islist(M.learned_discoveries) ? M.learned_discoveries.len : 0

/proc/discovery_first(datum/mind/M)
	if (!discovery_count(M))
		return null
	return M.learned_discoveries[M.learned_discoveries[1]]

/proc/discovery_repeat(character, amount)
	var/result = ""
	for (var/i = 1, i <= amount, i++)
		result += character
	return result

/proc/discovery_fixture()
	var/mob/living/human/H = discovery_actor(locate(2,2,1))
	var/mob/living/human/other = discovery_actor(locate(3,2,1))
	var/datum/mind/M = H.mind
	M.memory = "private handwritten memory"
	M.add_note("Private", "private role note")
	var/private_notes = json_encode(M.notes)
	discovery_check(!discovery_count(M) && findtext(M.discoveries_html(), "No discoveries recorded."), "fresh character has no learned berry knowledge")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/berries/tinto/B = new(get_turf(H))
	B.name = "<berry&label>"
	var/observed = B.smell_description()
	discovery_check(istext(observed) && length(observed), "real berry has a production reagent smell description")
	B.smell_for(H)
	discovery_check(discovery_chat_recipient == H && discovery_chat_text == "<span class='notice'>You can smell [html_encode(observed)].</span>" && discovery_prelearn_count == 0, "actual smell emits its descriptor before learning")
	discovery_check(discovery_count(M) == 1, "actual smell creates one learned observation")
	H.mind_initialize()
	discovery_check(H.mind == M && M.current == H && discovery_count(M) == 1, "production mind initialization preserves the existing character knowledge")
	var/list/record = discovery_first(M)
	discovery_check(record["observation"] == "I smelled a sample and noticed [observed].", "learned observation exactly matches the real smelled descriptor")
	var/learned_text = json_encode(M.learned_discoveries)
	discovery_check(!findtext(learned_text, "cyanide") && !findtext(learned_text, "poisonous") && !findtext(learned_text, "hidden-configuration-marker"), "hidden berry configuration does not leak into learned text")
	discovery_check(M.memory == "private handwritten memory" && json_encode(M.notes) == private_notes && !discovery_count(other.mind), "learning preserves private notes and isolates another character")
	M.show_memory(H)
	discovery_check(discovery_notes_recipient == H && findtext(discovery_notes_text, html_encode(B.name)) && !findtext(discovery_notes_text, B.name), "production Notes construction escapes the learned berry label")
	discovery_check(findtext(discovery_notes_text, "private handwritten memory") && findtext(discovery_notes_text, "private role note") && findtext(discovery_notes_text, "not proof that these berries are safe"), "production Notes preserves private text and no safety claim")
	var/notes_before = discovery_notes_count
	M.show_memory(other)
	discovery_check(discovery_notes_count == notes_before, "production Notes ownership guard rejects another mind")
	B.name = "renamed berries"
	B.smell_for(H)
	discovery_check(discovery_count(M) == 1 && record["label"] == "<berry&label>", "repeated renamed sample keeps one observation and its first label")
	H.a_intent = I_HELP
	B.secondary_attack_self(H)
	discovery_check(discovery_chat_recipient == H && discovery_count(M) == 1, "production secondary action uses its explicit actor and deduplicates")
	var/chats_before = discovery_chat_count
	B.smell_for(other)
	discovery_check(discovery_chat_count == chats_before && !discovery_count(other.mind), "production smell rejects a different physical turf")
	other.loc = get_turf(H)
	other.stat = UNCONSCIOUS
	B.smell_for(other)
	discovery_check(!discovery_count(other.mind), "unconscious character does not learn a berry observation")
	other.stat = CONSCIOUS
	other.mind.current = H
	B.smell_for(other)
	discovery_check(!discovery_count(other.mind), "wrong current-body owner cannot learn a berry observation")
	other.mind.current = other
	var/obj/item/weapon/reagent_containers/plain = new(get_turf(H))
	plain.smell_for(H)
	discovery_check(discovery_count(M) == 1, "non-berry smell does not populate berry discoveries")
	var/original_context = record["context"]
	map.berryeffects = list(list("tinto", "neutral", "water"))
	discovery_check(findtext(M.discoveries_html(), "Historical observation:"), "changed berry configuration marks learned observations historical")
	map.berryeffects = list(list("tinto", "poisonous", "cyanide"), list("hidden-configuration-marker", "not-a-sensed-effect", "water"))
	discovery_check(berry_discovery_context() == original_context && !findtext(M.discoveries_html(), "Historical observation:"), "equal restored configuration retains semantic context without safety inference")
	var/mob/living/human/new_body = new /mob/living/human/discovery_tester(locate(4,2,1))
	M.transfer_to(new_body)
	discovery_check(!H.mind && new_body.mind == M && M.current == new_body && discovery_count(M) == 1, "production mind transfer preserves learned knowledge on the same character")
	var/mob/living/human/fresh = discovery_actor(locate(5,2,1))
	discovery_check(fresh.mind != M && !discovery_count(fresh.mind), "a fresh mind does not inherit the previous character knowledge")
	discovery_limits()

/proc/discovery_limits()
	var/datum/mind/fields = new
	var/valid_edges = fields.learn_discovery(discovery_repeat("c",64), discovery_repeat("i",256), discovery_repeat("v",128), discovery_repeat("l",96), discovery_repeat("o",256))
	discovery_check(valid_edges && discovery_count(fields) == 1, "all maximum-length fields admit one whole record")
	var/before = json_encode(fields.learned_discoveries)
	var/rejected = !fields.learn_discovery(discovery_repeat("c",65), "i", "v", "l", "o")
	rejected = rejected && !fields.learn_discovery("c", discovery_repeat("i",257), "v", "l", "o")
	rejected = rejected && !fields.learn_discovery("c", "i", discovery_repeat("v",129), "l", "o")
	rejected = rejected && !fields.learn_discovery("c", "i", "v", discovery_repeat("l",97), "o")
	rejected = rejected && !fields.learn_discovery("c", "i", "v", "l", discovery_repeat("o",257))
	discovery_check(rejected && json_encode(fields.learned_discoveries) == before, "oversized fields reject whole records without altering established knowledge")
	var/datum/mind/berries = new
	var/berry_ok = TRUE
	for (var/i = 1, i <= 64, i++)
		if (!berries.learn_discovery("berry_smell", "identity", "context", "label", "sample [i]"))
			berry_ok = FALSE
	discovery_check(berry_ok && discovery_count(berries) == 64, "sixty-four distinct berry observations are admitted")
	before = json_encode(berries.learned_discoveries)
	discovery_check(!berries.learn_discovery("berry_smell", "identity", "context", "label", "extra") && json_encode(berries.learned_discoveries) == before, "berry capacity rejects the next observation without eviction")
	discovery_check(berries.learn_discovery("future_taste", "identity", "context", "label", "taste"), "berry capacity leaves room for a different discovery category")
	var/datum/mind/all_records = new
	var/all_ok = TRUE
	for (var/i = 1, i <= 256, i++)
		if (!all_records.learn_discovery("future_taste", "[i]", "context", "label", "observation"))
			all_ok = FALSE
	discovery_check(all_ok && discovery_count(all_records) == 256, "two hundred fifty-six overall discoveries are admitted")
	before = json_encode(all_records.learned_discoveries)
	discovery_check(!all_records.learn_discovery("future_taste", "extra", "context", "label", "observation") && json_encode(all_records.learned_discoveries) == before, "overall capacity rejects the next observation without eviction")
	var/datum/mind/imported = new
	imported.learned_discoveries = list()
	imported.learned_discoveries["oversized"] = list("category"="berry_smell", "identity"="i", "context"="c", "label"=discovery_repeat("<",97), "observation"="bad")
	imported.learned_discoveries["bad"] = list("missing fields")
	for (var/i = 1, i <= 300, i++)
		imported.learned_discoveries["[i]"] = list("category"="future_taste", "identity"="[i]", "context"="c", "label"="bounded-label-[i]", "observation"="bounded observation")
	before = json_encode(imported.learned_discoveries)
	var/rendered = imported.discoveries_html()
	discovery_check(length(rendered) < 650000 && !findtext(rendered, "bounded-label-300") && findtext(rendered, "Some stored discoveries exceed display limits"), "malformed imported discoveries have bounded rendering and an omission notice")
	discovery_check(json_encode(imported.learned_discoveries) == before, "rendering does not rewrite or evict malformed imported records")
