// Synthetic fresh-process reader only. This is not a production loader path,
// authenticated account flow, or validation of an untrusted savefile.
/proc/sleep_graph_fixture_read(expected_round, expected_account)
    if(!fexists("sleep-payload.txt") || !fexists("sleep-manifest.json")) return FALSE
    var/payload = file2text("sleep-payload.txt")
    var/list/M = json_decode(file2text("sleep-manifest.json"))
    if(!islist(M) || M.len != 11 || M["schema"] != 1 || M["state"] != "unverified" || !istext(expected_round) || !cmptextEx(M["round_id"], expected_round) || M["account"] != expected_account || M["nonce"] != "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" || !isnum(M["root_ref"]) || M["root_ref"] != 1 || !isnum(M["entries"]) || M["entries"] < 1 || M["entries"] > 512 || !isnum(M["lists"]) || M["lists"] > 256 || !istext(payload) || M["payload_length"] != length(payload) || M["payload_md5"] != md5(payload)) return FALSE
    var/savefile/F = new
    F.ImportText("/", payload)
    if(F["/format_version"] != 3 || F["/entries/0/1/type"] != /mob/living/human/sleep_graph_test_human) return FALSE
    var/list/owner_value = F["/entries/0/1/persistence_owner_ckey"]
    if(!islist(owner_value) || owner_value["kind"] != "value" || owner_value["value"] != expected_account) return FALSE
    var/map_storage/S = new
    // Exact extracted production Load_Entry/decode methods; fake game APIs.
    var/mob/living/human/sleep_graph_test_human/H = S.Load_Entry(F, 1)
    if(!istype(H) || H.loc || H.persistence_owner_ckey != expected_account || !H.persistence_restored) return FALSE
    var/obj/item/sleep_graph_test_item/I = H.item_ref
    var/datum/sleep_graph_test_node/N = H.node
    if(!istype(I) || I.loc != H || !istype(N) || I.node != N || N.peer != N || !islist(H.alias) || H.alias != I.alias || H.alias != N.alias || H.alias.len != 2 || H.alias[1] != H.alias || H.alias[2] != I) return FALSE
    var/count = 0
    for(var/mob/living/human/sleep_graph_test_human/B in S.all_loaded)
        if(B.persistence_owner_ckey == expected_account) count++
    return count == 1

/proc/sleep_graph_fixture_reader_case()
    var/before = fixture_constructed
    sleep_graph_fixture_check(!sleep_graph_fixture_read("round-a", "fixtureaccount") && fixture_constructed == before, "cross-round input constructed a graph")
    sleep_graph_fixture_check(!sleep_graph_fixture_read("Round-A", "otheraccount") && fixture_constructed == before, "wrong-account input constructed a graph")
    sleep_graph_fixture_check(sleep_graph_fixture_read("Round-A", "fixtureaccount"), "pinned loader round trip failed")
    return TRUE