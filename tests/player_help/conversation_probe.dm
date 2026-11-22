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
    check(findtext(D.render_window(alice), ">Follow up</button>") && !findtext(D.render_window(alice), "data-turn='"), "follow-up box after an acknowledged answer, nothing to choose between with one exchange")
    D.remember(alice, "Earlier <b>question</b> & one", "Earlier <script>answer</script> & one")
    D.remember(alice, "Another question", "Another answer")
    var/rendered_questions = D.render_window(alice)
    check(findtext(rendered_questions, "Earlier &lt;b&gt;question&lt;/b&gt; &amp; one"), "previous question escaped as text")
    check(findtext(rendered_questions, "Earlier &lt;script&gt;answer&lt;/script&gt; &amp; one") && !findtext(rendered_questions, "<script>answer"), "previous answer escaped as text")
    check(findtext(rendered_questions, "How do I smelt iron?") < findtext(rendered_questions, "Earlier &lt;b&gt;") && findtext(rendered_questions, "Earlier &lt;b&gt;") < findtext(rendered_questions, "Another question"), "conversation shown oldest first")
    check(findtext(rendered_questions, "Another answer") < findtext(rendered_questions, "name='question'") && findtext(rendered_questions, "name='question'") < findtext(rendered_questions, "Crafting Atlas</a>"), "question box below the conversation, reference links last")
    check(findtext(rendered_questions, "data-turn='2'") && findtext(rendered_questions, "name='token' value='[alice.player_help_action_token]'"), "each remembered answer can be asked about and the box carries the token")
    check(!findtext(rendered_questions, "How do I stay warm?"), "other client's history not shown")
    alice.player_help_pending = "Waiting <i>question</i>"
    alice.player_help_notice = "Notice <b>text</b>"
    alice.player_help_draft = "Draft \"quoted\" <u>text</u> & 'more'"
    var/rendered_state = D.render_window(alice)
    check(findtext(rendered_state, "Waiting &lt;i&gt;question&lt;/i&gt;") && findtext(rendered_state, "Notice &lt;b&gt;text&lt;/b&gt;"), "waiting question and notice escaped as text")
    check(!findtext(rendered_state, "value=\"Draft \"") && findtext(rendered_state, "&lt;u&gt;text&lt;/u&gt; &amp; ") && !findtext(rendered_state, "<u>text"), "refused question returns to the box escaped")
    check(findtext(rendered_state, " disabled>Waiting</button>") && !findtext(rendered_state, "data-turn='"), "box locked and no exchange choice while a question waits")
    alice.player_help_pending = null
    alice.player_help_notice = null
    alice.player_help_draft = null
    var/mob/probe_client/legacy_client = new
    legacy_client.player_help_standalone = list(list("question" = "Legacy question", "answer" = "Legacy **reply**"))
    legacy_client.player_help_plain = legacy_client.player_help_standalone.Copy()
    var/legacy_rendered = D.render_window(legacy_client)
    check(findtext(legacy_rendered, "Legacy question") && findtext(legacy_rendered, "<pre>Legacy **reply**</pre>") && findtext(legacy_rendered, ">Ask</button>") && !findtext(legacy_rendered, "data-turn='"), "old worker exchange shown as plain text without follow-up context")
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
    // Actual serializer pressure: bounded carried names and multibyte history.
    var/mob/probe_client/pressure = new
    var/mob/living/human/pressure_body = new
    pressure.mob = pressure_body
    pressure_body.probe_client = pressure
    probe_clients += pressure
    D.bind_body(pressure, pressure_body)
    var/long_name = ""
    for (var/i = 1, i <= 30, i++)
        long_name += "😀"
    pressure_body.back = new /obj/item/weapon/storage(pressure_body)
    pressure_body.back.name = long_name
    for (var/i = 1, i <= 23, i++)
        var/obj/item/carried = new(pressure_body.back)
        carried.name = long_name
    var/big_question = ""
    for (var/i = 1, i <= 500, i++)
        big_question += "q"
    var/big_answer = ""
    for (var/i = 1, i <= 750, i++)
        big_answer += "😀"
    D.remember(pressure, big_question, big_answer)
    var/list/big_pair = pressure.player_help_turns[1]
    var/list/pressure_request = list("id"="fixture-id", "account"=md5("pressure"), "question"=big_question, "game_context"=D.game_context(pressure_body), "render_contract"=list("version"=1, "capabilities"=list("markdown-basic-v1")), "conversation"=list("version"=1, "turns"=list(big_pair)))
    check(D.request_size(pressure_request) > 16384, "multibyte targeted request exceeds actual serialized budget")
    var/write_count = D.write_calls
    var/pressure_result = D.enqueue(md5("pressure"), big_question, pressure, big_pair)
    check(istext(pressure_result) && findtext(pressure_result, "selected exchange") && findtext(pressure_result, "too large"), "oversize selected exchange fails with specific feedback")
    check(D.write_calls == write_count && !D.pending.len && !fexists("spool/1.ready") && !fexists("spool/1.request.json"), "oversize target writes no request and releases slot")
    check(pressure.player_help_turns.len == 1 && pressure.player_help_turns[1] == big_pair, "oversize target leaves retained history intact")
    D.accounts = list()
    D.global_times = list()
    var/small_answer = ""
    for (var/i = 1, i <= 100, i++)
        small_answer += "😀"
    D.remember(pressure, "short earlier", small_answer)
    var/list/small_pair = pressure.player_help_turns[2]
    pressure_request["conversation"]["turns"] = list(small_pair)
    check(D.request_size(pressure_request) > 10000 && D.request_size(pressure_request) < 16000, "bounded selected request approaches but fits budget")
    check(D.enqueue(md5("pressure"), big_question, pressure, small_pair) == TRUE, "bounded selected exchange is sent")
    var/list/pressure_sent = D.read_json("spool/1.request.json", 16384)
    var/list/pressure_turns = pressure_sent["conversation"]["turns"]
    check(pressure_turns.len == 1 && pressure_turns[1]["question"] == "short earlier", "bounded selected exchange reaches request intact")
    D.clear_slot(1)
    D.accounts = list()
    D.global_times = list()
    check(D.enqueue(md5("pressure"), big_question, pressure) == TRUE, "ordinary follow-up may trim oldest pair")
    var/list/ordinary_sent = D.read_json("spool/1.request.json", 16384)
    var/list/ordinary_turns = ordinary_sent["conversation"]["turns"]
    check(ordinary_turns.len == 1 && ordinary_turns[1]["question"] == "short earlier" && pressure.player_help_turns.len == 2, "ordinary trimming keeps newest pair and retained session")
    D.clear_slot(1)
    D.reset_conversation(pressure)
    probe_clients -= pressure
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
    // The answer window's own question box submits through the real action handler.
    D.accounts = list()
    D.global_times = list()
    D.conversation_supported = TRUE
    var/mob/probe_client/clicker = new
    D.probe_account = md5("clicker account")
    probe_clients += clicker
    D.remember(clicker, "How do I make a fire?", "Use a fire starter.")
    D.remember(clicker, "Where is flint?", "Near rivers.")
    var/clicker_html = D.render_window(clicker)
    check(findtext(clicker_html, "name='question'") && findtext(clicker_html, "name='token' value='[clicker.player_help_action_token]'") && findtext(clicker_html, "data-turn='1'"), "window carries the follow-up question box and exchange choices")
    var/clicker_token = clicker.player_help_action_token
    D.handle_action(clicker, list("action" = "ask", "token" = clicker_token, "question" = "   "))
    check(!D.pending.len && findtext(clicker.probe_window, "Type your question in the box first"), "empty follow-up box sends nothing and says why")
    D.handle_action(clicker, list("action" = "ask", "token" = "stale", "question" = "Stale window"))
    check(!D.pending.len && clicker.player_help_turns.len == 2, "stale window token sends nothing and keeps the conversation")
    check(findtext(clicker.probe_window, "out of date") && findtext(clicker.probe_window, "value=\"Stale window\"") && findtext(clicker.probe_window, "Where is flint?"), "stale window is replaced by the current conversation with the question kept")
    D.handle_action(clicker, list("action" = "ask", "token" = clicker_token, "question" = "What about tinder?"))
    var/list/box_request = D.read_json("spool/1.request.json", 16384)
    var/list/box_all = box_request["conversation"]["turns"]
    check(D.pending.len == 1 && box_request["question"] == "What about tinder?" && box_all.len == 2, "follow-up box submits with the whole conversation")
    check(clicker.player_help_pending == "What about tinder?" && findtext(clicker.probe_window, "What about tinder?") && findtext(clicker.probe_window, "Looking through the guides") && findtext(clicker.probe_window, "Where is flint?") < findtext(clicker.probe_window, "What about tinder?"), "follow-up shows at once below the conversation while it waits")
    // The answer joins the conversation in the same window.
    text2file(json_encode(list("id" = box_request["id"], "status" = "ok", "answer" = "Dry **grass** works.", "conversation_protocol" = 1, "render_protocol" = 1, "answer_format" = "markdown-basic-v1")), "spool/1.response.json")
    D.poll()
    check(!D.pending.len && !clicker.player_help_pending && clicker.player_help_turns.len == 3, "follow-up answer joins the remembered conversation")
    check(findtext(clicker.probe_window, "Dry <b>grass</b> works.") && findtext(clicker.probe_window, "What about tinder?") < findtext(clicker.probe_window, "Dry <b>grass</b>") && findtext(clicker.probe_window, ">Follow up</button>") && !findtext(clicker.probe_window, "Looking through the guides"), "window shows the follow-up answer under its question, ready for another")
    check(clicker.player_help_action_token != clicker_token && !D.valid_action(clicker, clicker_token), "each answer replaces the window token")
    clicker_token = clicker.player_help_action_token
    // Asking again inside the cooldown is refused in the window, with the question kept.
    D.handle_action(clicker, list("action" = "ask", "token" = clicker_token, "question" = "Too soon?"))
    check(!D.pending.len && !clicker.player_help_pending && findtext(clicker.probe_window, "asking faster than the helper allows") && findtext(clicker.probe_window, "value=\"Too soon?\""), "cooldown refusal is shown in the window with the question kept")
    // A failed answer puts the question back in the box.
    D.accounts = list()
    D.global_times = list()
    D.handle_action(clicker, list("action" = "ask", "token" = clicker_token, "question" = "Will this fail?"))
    var/list/failing = D.read_json("spool/1.request.json", 16384)
    text2file(json_encode(list("id" = failing["id"], "status" = "unavailable")), "spool/1.response.json")
    D.poll()
    check(!D.pending.len && !clicker.player_help_pending && clicker.player_help_turns.len == 3 && findtext(clicker.probe_window, "could not answer that") && findtext(clicker.probe_window, "value=\"Will this fail?\""), "failed answer is reported in the window and the question returns to the box")
    D.accounts = list()
    D.global_times = list()
    D.handle_action(clicker, list("action" = "ask", "token" = clicker_token, "turn" = "1", "question" = "And kindling?"))
    var/list/box_target = D.read_json("spool/1.request.json", 16384)
    var/list/box_turns = box_target["conversation"]["turns"]
    check(D.pending.len == 1 && box_turns.len == 1 && box_turns[1]["question"] == "How do I make a fire?", "targeted follow-up box sends only the selected exchange")
    D.clear_slot(1)
    D.accounts = list()
    D.global_times = list()
    D.handle_action(clicker, list("action" = "ask", "token" = clicker_token, "turn" = "01", "question" = "Bad turn"))
    check(!D.pending.len && findtext(clicker.probe_window, "no longer available"), "malformed turn sends nothing and says why")
    D.handle_action(clicker, list("action" = "open", "token" = clicker_token, "url" = "https://civ13.github.io/civ13-wiki/guides/Guide_to_Survival.html"))
    D.handle_action(clicker, list("action" = "open", "token" = clicker_token, "url" = "https://example.org/"))
    check(!D.pending.len && clicker.player_help_turns.len == 3, "opening a guide link leaves the conversation alone")
    D.handle_action(clicker, list("action" = "reset", "token" = clicker_token))
    check(!clicker.player_help_turns.len && clicker.player_help_action_token && clicker.player_help_action_token != clicker_token, "new conversation clears through the action handler and issues a new token")
    check(findtext(clicker.probe_window, "What do you need help with?") && !findtext(clicker.probe_window, "Where is flint?") && findtext(clicker.probe_window, ">Ask</button>"), "new conversation shows the empty window")
    D.handle_action(clicker, list("action" = "ask", "token" = clicker_token, "question" = "After reset"))
    check(!D.pending.len, "window from a cleared conversation sends nothing")
    D.probe_account = null
    probe_clients -= clicker
    D.reset_conversation(bob)
    probe_clients = list()
