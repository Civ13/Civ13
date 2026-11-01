    // Actual service procedures with only client/output boundaries adapted to mobs.
    var/datum/player_help_service/probe_backend/D = new
    D.root = "spool/"
    D.conversation_supported = TRUE
    var/mob/probe_client/alice = new
    var/mob/probe_client/bob = new
    probe_clients += alice
    probe_clients += bob
    D.remember(alice, "How do I smelt iron?", "Use a bloomery.")
    D.remember(bob, "How do I stay warm?", "Wear dry clothing.")
    check(alice.player_help_turns.len == 1 && bob.player_help_turns.len == 1, "private independent client histories")
    check(!D.valid_action(bob, alice.player_help_action_token), "copied action token cannot select another client")
    check(D.valid_action(alice, alice.player_help_action_token), "own action token accepted")
    check(findtext(D.render_answer("Answer", "plain-v1", alice), "Follow up"), "follow-up action after acknowledged answer")
    D.remember(alice, "Earlier <b>question</b> & one", "Earlier <script>answer</script> & one")
    D.remember(alice, "Another question", "Another answer")
    var/list/prior_pairs = alice.player_help_turns.Copy()
    var/rendered_questions = D.render_answer("Answer", "plain-v1", alice, "Current <script> & question", prior_pairs)
    check(findtext(rendered_questions, "Current &lt;script&gt; &amp; question"), "current question escaped as text")
    check(findtext(rendered_questions, "Earlier &lt;b&gt;question&lt;/b&gt; &amp; one"), "previous question escaped as text")
    check(findtext(rendered_questions, "Earlier &lt;script&gt;answer&lt;/script&gt; &amp; one"), "previous answer escaped as text")
    check(findtext(rendered_questions, "Crafting Atlas</a>") < findtext(rendered_questions, "Previous exchanges"), "exchange history below reference links")
    check(findtext(rendered_questions, "Previous exchanges") < findtext(rendered_questions, "Another question"), "previous exchanges kept in order")
    check(findtext(rendered_questions, "action=followup;token=[alice.player_help_action_token];turn=2"), "retained exchange has targeted follow-up")
    check(!findtext(rendered_questions, "How do I stay warm?"), "other client's history not shown")
    var/legacy_rendered = D.render_answer("Legacy reply", "plain-v1", null, "Legacy question", list())
    check(findtext(legacy_rendered, "Legacy question") && !findtext(legacy_rendered, "Previous exchanges"), "legacy worker current question shown without prior context")
    var/list/selected_pair = alice.player_help_turns[1]
    check(findtext(D.enqueue(md5("conversation alice"), "Wrong owner", alice, bob.player_help_turns[1]), "no longer available"), "other client pair rejected before reservation")
    check(!D.pending.len, "wrong-owner pair does not reserve queue")
    check(D.enqueue(md5("conversation alice"), "What fuel does it need?", alice, selected_pair) == TRUE, "targeted follow-up enqueued")
    var/list/target_request = D.read_json("spool/1.request.json", 16384)
    var/list/target_contract = target_request["conversation"]
    var/list/target_turns = target_contract["turns"]
    check(target_turns.len == 1 && target_turns[1]["question"] == "How do I smelt iron?" && alice.player_help_turns.len == 3, "target sends selected pair and retains other exchanges")
    D.clear_slot(1)
    D.accounts = list()
    D.global_times = list()
    check(D.enqueue(md5("conversation alice"), "What fuel does it need?", alice) == TRUE, "actual follow-up enqueued")
    var/list/followup = D.read_json("spool/1.request.json", 16384)
    var/list/contract = followup["conversation"]
    var/list/pairs = contract["turns"]
    var/list/first_pair = pairs[1]
    check(contract["version"] == 1 && pairs.len == 3 && first_pair["question"] == "How do I smelt iron?", "server snapshot contains only asking session turns")
    check(findtext(D.enqueue(md5("conversation alice"), "Duplicate", alice), "pending"), "one pending follow-up per account")
    var/generation = alice.player_help_generation
    D.reset_conversation(alice)
    check(!alice.player_help_turns.len && alice.player_help_generation > generation && !alice.player_help_action_token, "reset clears turns token and advances generation")
    check(D.pending.len == 1 && findtext(D.reserve(md5("conversation alice")), "pending"), "reset preserves pending admission lock")
    text2file(json_encode(list("id" = followup["id"], "status" = "ok", "answer" = "Stale answer", "conversation_protocol" = 1)), "spool/1.response.json")
    D.poll()
    check(!D.pending.len && !alice.player_help_turns.len, "reset invalidates stale completion and releases slot")
    D.accounts = list()
    D.global_times = list()
    check(D.enqueue(md5("conversation alice"), "Fresh question", alice) == TRUE, "new conversation can start after pending completion")
    var/list/fresh = D.read_json("spool/1.request.json", 16384)
    text2file(json_encode(list("id" = "wrong-id", "status" = "ok", "answer" = "Wrong answer", "conversation_protocol" = 1)), "spool/1.response.json")
    D.poll()
    check(D.pending.len == 1 && !alice.player_help_turns.len, "wrong correlation never appends history")
    fdel("spool/1.response.json")
    text2file(json_encode(list("id" = fresh["id"], "status" = "ok", "answer" = "Accepted", "conversation_protocol" = 1)), "spool/1.response.json")
    D.poll()
    check(alice.player_help_turns.len == 1 && !D.pending.len, "only accepted correlated response enters history")
    D.poll()
    check(alice.player_help_turns.len == 1, "poll cannot append duplicate response")
    D.accounts = list()
    D.global_times = list()
    D.enqueue(md5("conversation alice"), "Will this fail?", alice)
    var/list/failed = D.read_json("spool/1.request.json", 16384)
    text2file(json_encode(list("id" = failed["id"], "status" = "unavailable", "conversation_protocol" = 1)), "spool/1.response.json")
    D.poll()
    check(alice.player_help_turns.len == 1 && !D.pending.len, "failure does not enter history")
    D.accounts = list()
    D.global_times = list()
    D.enqueue(md5("conversation alice"), "Timeout", alice)
    var/list/timed = D.pending["1"]
    timed["deadline"] = 0
    D.poll()
    check(!D.pending.len && alice.player_help_turns.len == 1, "timeout releases slot without appending history")
    D.accounts = list()
    D.global_times = list()
    D.enqueue(md5("conversation alice"), "Rollback follow-up", alice)
    var/list/rollback = D.read_json("spool/1.request.json", 16384)
    text2file(json_encode(list("id" = rollback["id"], "status" = "ok", "answer" = "Standalone answer without context")), "spool/1.response.json")
    D.poll()
    check(!alice.player_help_turns.len && !alice.player_help_acknowledged, "worker rollback cannot present standalone answer as contextual reply")
    for (var/i = 1, i <= 5, i++)
        D.remember(alice, "Question [i]", "Answer [i]")
    check(alice.player_help_turns.len == 3, "history retains at most three completed pairs")
    var/large_answer = ""
    for (var/i = 1, i <= 1200, i++)
        large_answer += "中"
    D.remember(alice, "Unicode", large_answer)
    var/list/latest = alice.player_help_turns[alice.player_help_turns.len]
    check(length(latest["answer"]) <= 3000 && length_char(latest["answer"]) == 1000, "answer clipping preserves UTF-8 boundaries")
    var/history_bytes = 0
    for (var/list/pair in alice.player_help_turns)
        history_bytes += length(pair["question"]) + length(pair["answer"])
    check(history_bytes <= 4096, "retained history respects total UTF-8 byte budget")
    check(D.request_size(list("x" = "中😀\n")) >= 28, "serialized budget counts escaped Unicode and controls")
    alice.player_help_touched = D.limit_time() - 9000
    D.expire_conversations()
    check(!alice.player_help_turns.len && !alice.player_help_acknowledged, "idle expiry erases context")
    D.remember(alice, "Private", "Session only")
    probe_clients -= alice
    D.expire_conversations()
    var/mob/probe_client/rejoined = new
    probe_clients += rejoined
    check(!alice.player_help_turns.len && !rejoined.player_help_turns.len && !(alice in D.conversation_clients), "disconnect releases old session and reconnect starts empty")
    D.accounts = list()
    D.global_times = list()
    D.conversation_supported = FALSE
    D.enqueue(md5("old worker"), "Standalone", rejoined)
    var/list/legacy = D.read_json("spool/1.request.json", 16384)
    check(!("conversation" in legacy), "old worker standalone request omits new fields")
    D.clear_slot(1)
    check(D.persistence_runtime_var("conversation_clients") && D.persistence_runtime_var("pending"), "transcripts and pending questions excluded from datum saves")
    D.reset_conversation(bob)
    probe_clients = list()
