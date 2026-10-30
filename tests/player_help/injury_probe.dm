    // Actual service procedures with client ownership injected at the fixture boundary.
    var/mob/probe_client/injury_client = new
    var/mob/living/human/injury_first = new
    var/mob/living/human/injury_second = new
    injury_client.mob = injury_first
    injury_first.probe_client = injury_client
    injury_second.probe_client = injury_client
    probe_clients += injury_client
    D.bind_body(injury_client, injury_first)
    D.record_observed_injury(injury_client, injury_first, "self_weapon_hit")
    check(D.injury_context(injury_client, injury_first).len == 1, "conscious self injury is observed")
    D.record_observed_injury(injury_client, injury_first, "witnessed_attack")
    D.record_observed_injury(injury_client, injury_first, "unseen_attack")
    D.record_observed_injury(injury_client, injury_first, "environmental_damage")
    D.record_observed_injury(injury_client, injury_first, "self_weapon_hit<script>secret</script>")
    check(D.injury_context(injury_client, injury_first).len == 1, "unreviewed attack categories and injected labels are rejected")
    injury_client.chat = new
    injury_client.chat.client = injury_client
    injury_client.chat.is_ready = FALSE
    D.record_observed_injury(injury_client, injury_first, "reported_projectile_hit")
    check(D.injury_context(injury_client, injury_first).len == 1, "queued chat is not recorded as a received message")
    injury_client.chat.is_ready = TRUE
    injury_client.chat.client = null
    D.record_observed_injury(injury_client, injury_first, "reported_projectile_hit")
    check(D.injury_context(injury_client, injury_first).len == 1, "unbound chat cannot establish delivery")
    injury_client.chat.client = injury_client
    D.record_observed_injury(injury_client, injury_second, "reported_projectile_hit")
    check(D.injury_context(injury_client, injury_first).len == 1, "wrong body cannot record a message")
    D.record_observed_injury(injury_client, injury_first, "reported_projectile_hit")
    D.record_observed_injury(injury_client, injury_first, "reported_shrapnel_hit")
    D.record_observed_injury(injury_client, injury_first, "reported_hot_ground")
    D.record_observed_injury(injury_client, injury_first, "reported_freezing_feet")
    check(D.injury_context(injury_client, injury_first).len == 5, "four ready-chat reported observations are accepted")
    injury_client.player_help_injuries.Cut(2)
    injury_first.stat = 1
    D.record_observed_injury(injury_client, injury_first, "self_weapon_hit")
    D.record_observed_injury(injury_client, injury_first, "reported_projectile_hit")
    injury_first.stat = 0
    injury_first.sleeping = 1
    D.record_observed_injury(injury_client, injury_first, "self_weapon_hit")
    injury_first.sleeping = 0
    check(D.injury_context(injury_client, injury_first).len == 1, "unconscious and sleeping observations are rejected")
    for (var/i = 1, i <= 8, i++)
        D.record_observed_injury(injury_client, injury_first, "self_weapon_hit")
    check(injury_client.player_help_injuries.len == 6, "injury observations are capped")
    var/list/injury_old = injury_client.player_help_injuries[1]
    injury_old["time"] = D.limit_time() - 6000
    check(D.injury_context(injury_client, injury_first).len == 5, "old injury expires")
    D.remember(injury_client, "Old body question", "Old body answer")
    injury_client.player_help_touched = D.limit_time() - 30
    D.record_observed_injury(injury_client, injury_first, "self_weapon_hit")
    check(injury_client.player_help_touched == D.limit_time() - 30, "injury does not extend conversation idle lifetime")
    D.accounts = list()
    D.global_times = list()
    D.conversation_supported = TRUE
    D.enqueue(md5("injury body swap"), "Pending old body", injury_client)
    var/list/injury_pending = D.read_json("spool/1.request.json", 16384)
    var/injury_generation = injury_client.player_help_generation
    injury_client.mob = injury_second
    D.bind_body(injury_client, injury_second)
    injury_client.mob = injury_first
    D.bind_body(injury_client, injury_first)
    check(injury_client.player_help_generation > injury_generation && !injury_client.player_help_turns.len && !injury_client.player_help_injuries.len, "body swap and return clear history and observations")
    text2file(json_encode(list("id" = injury_pending["id"], "status" = "ok", "answer" = "Old body late reply", "conversation_protocol" = 1)), "spool/1.response.json")
    D.poll()
    check(!D.pending.len && !injury_client.player_help_turns.len, "old body response is not delivered after body swap and return")
    D.record_observed_injury(injury_client, injury_first, "self_weapon_hit")
    D.remember(injury_client, "Prior body", "Prior answer")
    D.accounts = list()
    D.global_times = list()
    D.enqueue(md5("injury poll swap"), "Old body request", injury_client)
    var/list/injury_poll_pending = D.read_json("spool/1.request.json", 16384)
    injury_client.mob = injury_second
    text2file(json_encode(list("id" = injury_poll_pending["id"], "status" = "ok", "answer" = "Old body reply", "conversation_protocol" = 1)), "spool/1.response.json")
    D.poll()
    check(injury_client.player_help_body == injury_second && !injury_client.player_help_turns.len && !injury_client.player_help_injuries.len && !D.pending.len, "poll binds replacement body before reading or delivering response")
    D.record_observed_injury(injury_client, injury_second, "self_weapon_hit")
    probe_clients -= injury_client
    D.expire_conversations()
    check(!injury_client.player_help_injuries.len && !injury_client.player_help_turns.len, "disconnect clears injury and conversation state")

    // Production retention/projection with fixture-owned client and external organs.
    probe_clients += injury_client
    injury_client.mob = injury_second
    D.bind_body(injury_client, injury_second)
    var/mob/living/simple_animal/hostile/alligator/injury_animal = new
    injury_animal.name = "SECRET RENAMED ANIMAL"
    D.record_animal_injury(injury_client, injury_second, injury_animal, "l_hand", TRUE)
    var/list/animal_rows = D.injury_context(injury_client, injury_second)
    var/list/animal_row = animal_rows[1]
    check(animal_row["kind"] == "animal_limb_loss" && animal_row["source"] == "alligator" && animal_row["body_part"] == "l_hand", "confirmed limb-loss source has fixed public labels")
    check(!findtext(json_encode(animal_rows), "SECRET"), "renamed animal identity is never retained")
    D.record_animal_injury(injury_client, injury_first, injury_animal, "l_hand", TRUE)
    D.record_animal_injury(injury_client, injury_second, injury_animal, "SECRET PART", TRUE)
    check(D.injury_context(injury_client, injury_second).len == 1, "wrong body and unknown body part are rejected")
    D.record_animal_injury(injury_client, injury_second, injury_animal, null, FALSE)
    animal_rows = D.injury_context(injury_client, injury_second)
    animal_row = animal_rows[2]
    check(animal_rows.len == 2 && animal_row["kind"] == "animal_damage" && !("body_part" in animal_row), "rerolled damage retains source without guessing body part")
    D.record_animal_injury(injury_client, injury_second, injury_animal, null, TRUE)
    check(D.injury_context(injury_client, injury_second).len == 2, "limb loss requires a known detached limb")
    var/obj/item/organ/external/injury_hand = new
    injury_hand.owner = injury_second
    injury_hand.brute_dam = 20
    injury_hand.burn_dam = 2000
    injury_second.probe_organs["l_hand"] = injury_hand
    var/list/body_rows = D.body_damage_context(injury_second)
    check(body_rows.len == 11, "body projection has fixed bounded parts")
    for (var/list/body_row in body_rows)
        if (body_row["body_part"] == "l_hand")
            check(!body_row["missing"] && body_row["brute"] == 20 && body_row["burn"] == 1000, "own external damage is bounded")
    injury_hand.owner = null
    body_rows = D.body_damage_context(injury_second)
    for (var/list/body_row in body_rows)
        if (body_row["body_part"] == "l_hand")
            check(body_row["missing"] && !body_row["brute"] && !body_row["burn"], "detached limb is missing not another object disclosure")
    D.reset_conversation(injury_client)
    probe_clients -= injury_client
