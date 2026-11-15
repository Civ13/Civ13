// Phase 3 region voice rules (voice/region_voice.hpp) and, on Windows, the
// CNG crypto that must match Civilizationbot's VoiceLobbies::seal(). The
// sealed vector below was made by that PHP code; it holds no real token.
#include "../voice/region_voice.hpp"
#ifdef _WIN32
#include "../voice/win_crypto.hpp"
#endif

#include <cstdio>
#include <string>

using namespace civ13::voice::region;

static int failures = 0;
static int checks = 0;
static void check(bool ok, const char *what) {
  ++checks;
  if (!ok) {
    ++failures;
    std::printf("FAIL: %s\n", what);
  }
}

static const char *const key = "abcdefghijklmnopqrstuvwxyzABCDEF0123456789_-";

static void state_tests() {
  auto s = parse_state(R"({"v":1,"gen":3,"me":"100000000000000008","hear":{"100000000000000001":100,"100000000000000002":30,"bad":50,"100000000000000003":0},"speak":1,"talk":1,"team":"GERMAN","team_talk":0,"token_url":"http://bot.example:8080/voice/token"})");
  check(s.has_value(), "a full answer parses");
  check(s && s->ready == 1 && s->me == 100000000000000008ULL && s->gen == 3, "me and gen");
  check(s && s->hear.size() == 2 && s->hear.at(100000000000000001ULL) == 100 && s->hear.at(100000000000000002ULL) == 30, "in sight, malformed and silent entries dropped");
  check(s && s->talk && !s->team_talk && s->team == "GERMAN", "talk and team keys");
  check(s && s->token_url == "http://bot.example:8080/voice/token", "token address");
  auto quiet = parse_state(R"({"v":1,"gen":1,"me":"100000000000000008","hear":[],"speak":0,"talk":1,"team":"GERMAN","team_talk":1})");
  check(quiet && quiet->hear.empty() && !quiet->talk && !quiet->team_talk, "a player who cannot speak never transmits, and [] is an empty list");
  auto waiting = parse_state(R"({"v":1,"gen":0,"ready":0,"token_url":"http://bot.example/voice/token"})");
  check(waiting && waiting->ready == 0 && waiting->me == 0, "waiting for the bot");
  auto gone = parse_state(R"({"v":1,"gen":0,"ready":-1})");
  check(gone && gone->ready == -1, "an unknown key");
  check(!parse_state(R"({"v":2,"me":"100000000000000008"})"), "unknown version rejected");
  check(!parse_state(R"({"v":1,"me":"12"})"), "malformed id rejected");
  check(!parse_state("not json"), "garbage rejected");
  check(!parse_state(R"({"v":1,"me":"100000000000000008","hear":5})"), "hear must be a list");
  check(!parse_state(std::string(70000, ' ')), "oversized answer rejected");
  std::string deep(20, '[');
  check(!JsonParser::parse(deep + std::string(20, ']')), "deep nesting rejected");
}

static void topic_tests() {
  const std::string request = topic_request("civ13_voice_state=abc");
  check(request.size() == 4 + 5 + 1 + 21 + 1, "request size");
  check(request[0] == '\x00' && request[1] == '\x83' && request[2] == 0 && request[3] == 28, "request header");
  check(request.substr(9, 22) == "?civ13_voice_state=abc" && request.back() == '\x00', "request body");
  std::string response("\x00\x83\x00\x06\x06{\"a\"}", 10);
  check(topic_response_needed(response.substr(0, 3)) == 1, "needs a header");
  check(topic_response_needed(response.substr(0, 6)) == 4, "needs the rest");
  check(topic_response_needed(response) == 0, "complete");
  auto text = topic_response_text(response);
  check(text && *text == "{\"a\"}", "a text answer");
  std::string nul("\x00\x83\x00\x07\x06{\"a\"}\x00", 11);
  check(topic_response_text(nul) == std::optional<std::string>("{\"a\"}"), "a trailing zero is dropped");
  std::string empty("\x00\x83\x00\x02\x06\x00", 6);
  check(!topic_response_text(empty), "the limiter's empty answer is not an answer");
  std::string number("\x00\x83\x00\x05\x2a\x00\x00\x80\x3f", 9);
  check(!topic_response_text(number), "a number is not an answer");
}

static void token_tests() {
  auto waiting = parse_token_answer(R"({"v":1,"ready":false})");
  check(waiting && !waiting->ready, "token not ready yet");
  auto sealed = parse_token_answer(R"({"v":1,"sealed":"jmHz6xnvTqcwS0OQVPzGPmpG77Rl/bx5Yuexmw4gZWnJWmTWBS8R5VfdMc8dxtqr"})");
  check(sealed && sealed->ready && sealed->sealed.size() > 40, "a sealed answer");
  check(!parse_token_answer(R"({"v":1,"sealed":"short"})"), "a short seal is rejected");
  auto token = parse_token(R"({"v":1,"application_id":"123456789012345678","server":"tdm","user_id":"223456789012345678","access_token":"provisional-test-token","expires_in":600000})");
  check(token && token->application == 123456789012345678ULL && token->user == 223456789012345678ULL, "token ids");
  check(token && token->server == "tdm" && token->access_token == "provisional-test-token" && token->expires_in == 600000, "token fields");
  check(!parse_token(R"({"v":1,"application_id":"1","server":"tdm","user_id":"223456789012345678","access_token":"x","expires_in":1})"), "bad application id");
  check(!parse_token(R"({"v":1,"application_id":"123456789012345678","server":"","user_id":"223456789012345678","access_token":"x","expires_in":1})"), "no server");
  auto raw = base64_decode("aGVsbG8=");
  check(raw && *raw == "hello", "base64");
  check(!base64_decode("aGVsbG8") && !base64_decode("aGV=bG8=") && !base64_decode("aGVs*G8="), "malformed base64");
}

static void url_tests() {
  auto url = parse_url("http://valzargaming.com:8080/voice/token");
  check(url && !url->https && url->host == "valzargaming.com" && url->port == 8080 && url->path == "/voice/token", "plain http with a port");
  auto secure = parse_url("https://bot.example");
  check(secure && secure->https && secure->port == 443 && secure->path == "/", "https default port and path");
  check(!parse_url("ftp://x/y") && !parse_url("http://user@host/x") && !parse_url("http://host/x?y") && !parse_url("http://host:99999/") && !parse_url("http:///x"), "anything else is refused");
  check(valid_voice_key(key) && !valid_voice_key("short") && !valid_voice_key(std::string(32, '+')), "voice keys");
}

static void lobby_tests() {
  std::map<std::string, std::string> region{{"civ13_server", "tdm"}, {"civ13_kind", "region"}};
  std::map<std::string, std::string> team{{"civ13_server", "tdm"}, {"civ13_kind", "team"}, {"civ13_team", "GERMAN"}};
  std::map<std::string, std::string> other{{"civ13_server", "nomads"}, {"civ13_kind", "region"}};
  check(lobby_kind(region, "tdm", "GERMAN") == LobbyKind::region, "region lobby");
  check(lobby_kind(team, "tdm", "GERMAN") == LobbyKind::team, "own team lobby");
  check(lobby_kind(team, "tdm", "SOVIET") == LobbyKind::none, "another team's lobby is ignored");
  check(lobby_kind(team, "tdm", "") == LobbyKind::none, "no team, no team lobby");
  check(lobby_kind(other, "tdm", "GERMAN") == LobbyKind::none, "another world's lobby is ignored");
  check(lobby_kind({}, "tdm", "GERMAN") == LobbyKind::none, "a lobby without metadata is ignored");
}

static void mix_tests() {
  auto s = parse_state(R"({"v":1,"gen":1,"me":"100000000000000008","hear":{"100000000000000001":75},"speak":1,"talk":1,"team":"GERMAN","team_talk":1})");
  const std::vector<uint64_t> people{100000000000000001ULL, 100000000000000002ULL, 100000000000000008ULL};
  Mix m = mix(s, 1000, 1500, people);
  check(m.region_ptt && m.team_ptt && m.team_audible, "fresh answer: both keys follow the game");
  check(m.region.size() == 2 && m.region.count(100000000000000008ULL) == 0, "the player's own ID is skipped");
  check(m.region[100000000000000001ULL] == std::optional<float>(75.0f), "in sight at its volume");
  check(!m.region[100000000000000002ULL], "out of sight is muted");
  Mix stale = mix(s, 1000, 1000 + stale_ms + 1, people);
  check(!stale.region_ptt && !stale.team_ptt && !stale.team_audible, "a stale answer closes both microphones");
  check(!stale.region[100000000000000001ULL] && !stale.region[100000000000000002ULL], "a stale answer mutes everyone");
  Mix backwards = mix(s, 2000, 1000, people);
  check(!backwards.region_ptt, "a clock going backwards counts as stale");
  Mix none = mix(std::nullopt, 0, 0, people);
  check(!none.region_ptt && none.region.size() == 3 && !none.region[100000000000000008ULL], "no answer yet: everyone muted");
  auto waiting = parse_state(R"({"v":1,"gen":0,"ready":0})");
  check(!mix(waiting, 1000, 1000, people).region_ptt, "waiting for the bot never transmits");
  auto loner = parse_state(R"({"v":1,"gen":1,"me":"100000000000000008","hear":[],"speak":1,"talk":0})");
  check(!mix(loner, 0, 0, people).team_audible, "no team, team call silent");
}

#ifdef _WIN32
static void crypto_tests() {
  using namespace civ13::voice::crypto;
  check(poll_id(key) == std::optional<std::string>("20421d6f878985f3ed0f2b488141bb3661c90399"), "poll id matches the game's sha1");
  const std::string id = "2e4970c2d7b35c2edd64c1023eb0c5f1cf732d88e27a30360afb7787a8f23b48";
  check(token_id(key) == std::optional<std::string>(id), "token id matches the bot");
  auto derived = hkdf_sha256(key, "civ13-voice-seal", 32);
  check(derived && hex(*derived) == "d7cd34377971af2343e6355184dd6f5419b3dcc42c7f71efcb4ddadc074aef0c", "HKDF matches PHP hash_hkdf");
  const char *sealed = "jmHz6xnvTqcwS0OQVPzGPmpG77Rl/bx5Yuexmw4gZWnJWmTWBS8R5VfdMc8dxtqrfxOgy8CIoGgmEXf97q29EWsz+KQceP5LlW6dFLUsWg8FVKDDXcxVPHIPT7G4JN6wfBbFTJg+e5rX9RzxmLGZ/Sp4DSSJJhW1ExOhzWVY75yTkbDEn68walVxV5/ZHaHdrkyZrzgYan0iCjKIY9Fk/qAHSbyARgGfl0p/PDcKk+snAuU=";
  auto raw = base64_decode(sealed);
  check(raw.has_value(), "sealed vector decodes");
  auto plain = raw ? open_sealed(key, id, *raw) : std::nullopt;
  auto token = plain ? parse_token(*plain) : std::nullopt;
  check(token && token->access_token == "provisional-test-token" && token->server == "tdm", "the bot's seal opens");
  check(raw && !open_sealed("ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210_-abcdef", id, *raw), "another key cannot open it");
  check(raw && !open_sealed(key, id.substr(0, 63) + "0", *raw), "another token id cannot open it");
  if (raw) {
    std::string tampered = *raw;
    tampered[20] = static_cast<char>(tampered[20] ^ 1);
    check(!open_sealed(key, id, tampered), "a tampered seal does not open");
  }
  auto bytes = random_bytes(32);
  check(bytes && bytes->size() == 32, "random bytes");
}
#endif

int main() {
  state_tests();
  topic_tests();
  token_tests();
  url_tests();
  lobby_tests();
  mix_tests();
#ifdef _WIN32
  crypto_tests();
#endif
  std::printf("region-voice-tests: %d checks, %d failures\n", checks, failures);
  return failures == 0 ? 0 : 1;
}
