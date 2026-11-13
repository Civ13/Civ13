/proc/skill_warned()
	for (var/line in chat_log)
		if (findtext(line, "not skilled enough"))
			return TRUE
	return FALSE

/proc/run_case(name, mob/living/human/patient, mob/living/human/user, obj/item/tool, zone, datum/surgery_step/S, expect_result, expect_begun, expect_warning)
	chat_log = list()
	S.begun = 0
	user.targeted_organ = zone
	surgery_steps = list(S)
	var/result = do_surgery(patient, user, tool) ? TRUE : FALSE
	var/warned = skill_warned()
	if (result != expect_result || (S.begun > 0) != expect_begun || warned != expect_warning)
		text2file("FAIL [name]: result=[result] begun=[S.begun] warned=[warned]\n", "log.txt")
		return 1
	return 0

/world/New()
	var/mob/living/human/me = new
	var/mob/living/human/friend = new
	var/obj/item/weapon/reagent_containers/glass/bucket/bucket = new
	bucket.open = TRUE
	var/obj/item/weapon/reagent_containers/glass/bucket/lidded = new
	var/obj/item/weapon/surgery/scalpel/scalpel = new
	var/datum/surgery_step/weak = new
	weak.tool_type = /obj/item/weapon/reagent_containers/glass/bucket
	weak.quality = 30
	var/datum/surgery_step/good = new
	good.tool_type = /obj/item/weapon/reagent_containers/glass/bucket
	good.quality = 100
	good.applies = TRUE
	var/datum/surgery_step/cut = new
	cut.applies = TRUE
	var/failures = 0
	// A bucket of water on yourself: a low-quality step that does not apply must not block drinking.
	failures += run_case("bucket on self, step not applicable", me, me, bucket, "chest", weak, FALSE, FALSE, FALSE)
	failures += run_case("bucket on friend, step not applicable", friend, me, bucket, "chest", weak, FALSE, FALSE, FALSE)
	// When the low-quality step really applies, the skill warning still claims the click.
	weak.applies = TRUE
	failures += run_case("bucket step applies but unskilled", me, me, bucket, "chest", weak, TRUE, FALSE, TRUE)
	weak.applies = SURGERY_FAILURE
	failures += run_case("step failure already explained", me, me, bucket, "chest", weak, TRUE, FALSE, FALSE)
	// Aiming an open container at your own mouth always drinks.
	failures += run_case("open bucket at own mouth", me, me, bucket, "mouth", good, FALSE, FALSE, FALSE)
	// Surgery still runs for other patients, closed containers and other zones.
	failures += run_case("open bucket at friend's mouth", friend, me, bucket, "mouth", good, TRUE, TRUE, FALSE)
	failures += run_case("closed bucket at own mouth", me, me, lidded, "mouth", good, TRUE, TRUE, FALSE)
	failures += run_case("open bucket on own chest", me, me, bucket, "chest", good, TRUE, TRUE, FALSE)
	failures += run_case("scalpel on own mouth", me, me, scalpel, "mouth", cut, TRUE, TRUE, FALSE)
	me.a_intent = I_HARM
	failures += run_case("harm intent never operates", friend, me, scalpel, "chest", cut, FALSE, FALSE, FALSE)
	text2file("[failures]", "result.txt")
	shutdown()
