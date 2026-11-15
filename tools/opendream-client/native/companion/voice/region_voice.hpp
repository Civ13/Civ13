#pragma once
// Portable decisions for Phase 3 region voice (issue #5122,
// docs/launcher-voice-plan.md). No SDK or Windows types, so
// tests/region_voice_tests.cpp checks every rule here in CI.
//
// The game decides who hears whom. The voice app only follows its answer:
// - talk / team_talk: the game's held keybindings (OOC > Keybindings), so
//   the voice app never reads the keyboard.
// - hear: Discord user ID -> volume for players this character can see.
//   Everyone else in the region call is muted locally.
// - An answer older than stale_ms closes both microphones and mutes the
//   region call, so a stalled game connection never leaves anyone open.
#include <cstdint>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace civ13::voice::region {

constexpr int64_t stale_ms = 3000;
constexpr int64_t poll_interval_ms = 100;
constexpr std::size_t max_answer_bytes = 65536;

// ---------------------------------------------------------------- JSON
// Just enough JSON for the game's and the bot's answers: objects, arrays,
// strings (with \u escapes for ASCII), numbers, true/false/null. Depth and
// size are bounded; anything else is rejected rather than guessed.
struct Json {
  enum class Kind { null, boolean, number, string, array, object } kind = Kind::null;
  bool boolean = false;
  double number = 0;
  std::string text;
  std::vector<Json> items;
  std::map<std::string, Json> fields;

  const Json *get(const std::string &name) const {
    if (kind != Kind::object) return nullptr;
    auto found = fields.find(name);
    return found == fields.end() ? nullptr : &found->second;
  }
  std::optional<std::string> string_at(const std::string &name) const {
    const Json *v = get(name);
    if (!v || v->kind != Kind::string) return std::nullopt;
    return v->text;
  }
  std::optional<int64_t> int_at(const std::string &name) const {
    const Json *v = get(name);
    if (!v || v->kind != Kind::number) return std::nullopt;
    if (v->number < -9.0e15 || v->number > 9.0e15) return std::nullopt;
    const auto whole = static_cast<int64_t>(v->number);
    if (static_cast<double>(whole) != v->number) return std::nullopt;
    return whole;
  }
};

class JsonParser {
public:
  static std::optional<Json> parse(std::string_view input) {
    if (input.size() > max_answer_bytes) return std::nullopt;
    JsonParser p{input};
    Json out;
    if (!p.value(out, 0)) return std::nullopt;
    p.space();
    if (p.at != input.size()) return std::nullopt;
    return out;
  }

private:
  explicit JsonParser(std::string_view s) : in(s) {}
  std::string_view in;
  std::size_t at = 0;

  void space() {
    while (at < in.size() && (in[at] == ' ' || in[at] == '\n' || in[at] == '\r' || in[at] == '\t')) ++at;
  }
  bool literal(std::string_view word) {
    if (in.substr(at, word.size()) != word) return false;
    at += word.size();
    return true;
  }
  bool string(std::string &out) {
    if (at >= in.size() || in[at] != '"') return false;
    ++at;
    while (at < in.size()) {
      const char c = in[at++];
      if (c == '"') return true;
      if (static_cast<unsigned char>(c) < 0x20) return false;
      if (c != '\\') { out.push_back(c); continue; }
      if (at >= in.size()) return false;
      const char e = in[at++];
      switch (e) {
      case '"': case '\\': case '/': out.push_back(e); break;
      case 'b': out.push_back('\b'); break;
      case 'f': out.push_back('\f'); break;
      case 'n': out.push_back('\n'); break;
      case 'r': out.push_back('\r'); break;
      case 't': out.push_back('\t'); break;
      case 'u': {
        if (at + 4 > in.size()) return false;
        unsigned code = 0;
        for (int i = 0; i < 4; ++i) {
          const char h = in[at++];
          code <<= 4;
          if (h >= '0' && h <= '9') code |= static_cast<unsigned>(h - '0');
          else if (h >= 'a' && h <= 'f') code |= static_cast<unsigned>(h - 'a' + 10);
          else if (h >= 'A' && h <= 'F') code |= static_cast<unsigned>(h - 'A' + 10);
          else return false;
        }
        // Nothing we read needs more than ASCII; keep others as '?'.
        out.push_back(code < 0x80 ? static_cast<char>(code) : '?');
        break;
      }
      default: return false;
      }
    }
    return false;
  }
  bool number(double &out) {
    const std::size_t start = at;
    if (at < in.size() && in[at] == '-') ++at;
    bool digits = false;
    while (at < in.size() && in[at] >= '0' && in[at] <= '9') { ++at; digits = true; }
    if (at < in.size() && in[at] == '.') {
      ++at;
      while (at < in.size() && in[at] >= '0' && in[at] <= '9') ++at;
    }
    if (at < in.size() && (in[at] == 'e' || in[at] == 'E')) {
      ++at;
      if (at < in.size() && (in[at] == '+' || in[at] == '-')) ++at;
      while (at < in.size() && in[at] >= '0' && in[at] <= '9') ++at;
    }
    if (!digits || at - start > 32) return false;
    try {
      out = std::stod(std::string(in.substr(start, at - start)));
    } catch (...) {
      return false;
    }
    return true;
  }
  bool value(Json &out, int depth) {
    if (depth > 8) return false;
    space();
    if (at >= in.size()) return false;
    const char c = in[at];
    if (c == '{') {
      ++at;
      out.kind = Json::Kind::object;
      space();
      if (at < in.size() && in[at] == '}') { ++at; return true; }
      while (true) {
        space();
        std::string name;
        if (!string(name)) return false;
        space();
        if (at >= in.size() || in[at] != ':') return false;
        ++at;
        Json item;
        if (!value(item, depth + 1)) return false;
        out.fields[name] = std::move(item);
        if (out.fields.size() > 4096) return false;
        space();
        if (at < in.size() && in[at] == ',') { ++at; continue; }
        if (at < in.size() && in[at] == '}') { ++at; return true; }
        return false;
      }
    }
    if (c == '[') {
      ++at;
      out.kind = Json::Kind::array;
      space();
      if (at < in.size() && in[at] == ']') { ++at; return true; }
      while (true) {
        Json item;
        if (!value(item, depth + 1)) return false;
        out.items.push_back(std::move(item));
        if (out.items.size() > 4096) return false;
        space();
        if (at < in.size() && in[at] == ',') { ++at; continue; }
        if (at < in.size() && in[at] == ']') { ++at; return true; }
        return false;
      }
    }
    if (c == '"') { out.kind = Json::Kind::string; return string(out.text); }
    if (literal("true")) { out.kind = Json::Kind::boolean; out.boolean = true; return true; }
    if (literal("false")) { out.kind = Json::Kind::boolean; return true; }
    if (literal("null")) { out.kind = Json::Kind::null; return true; }
    out.kind = Json::Kind::number;
    return number(out.number);
  }
};

// ---------------------------------------------------------------- IDs
inline std::optional<uint64_t> parse_id(std::string_view s) {
  if (s.size() < 17 || s.size() > 20) return std::nullopt;
  uint64_t value = 0;
  for (char c : s) {
    if (c < '0' || c > '9') return std::nullopt;
    const uint64_t digit = static_cast<uint64_t>(c - '0');
    if (value > (UINT64_MAX - digit) / 10) return std::nullopt;
    value = value * 10 + digit;
  }
  return value;
}

// The launcher's voice key: 32-64 URL-safe characters, as the game accepts.
inline bool valid_voice_key(std::string_view key) {
  if (key.size() < 32 || key.size() > 64) return false;
  for (char c : key) {
    const bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                    (c >= '0' && c <= '9') || c == '-' || c == '_';
    if (!ok) return false;
  }
  return true;
}

// ---------------------------------------------------------------- game state
struct GameState {
  int64_t gen = 0;
  int ready = 0;         // 1 once the game knows this player's Discord ID
  uint64_t me = 0;
  std::map<uint64_t, int> hear; // Discord ID -> 0-100
  bool speak = false;
  bool talk = false;
  std::string team;
  bool team_talk = false;
  std::string token_url;
};

// The game's civ13_voice_state answer. Null for anything malformed or for a
// version this app does not know.
inline std::optional<GameState> parse_state(std::string_view text) {
  auto json = JsonParser::parse(text);
  if (!json || json->kind != Json::Kind::object || json->int_at("v") != 1)
    return std::nullopt;
  GameState s;
  s.gen = json->int_at("gen").value_or(0);
  if (auto token_url = json->string_at("token_url")) {
    if (token_url->size() <= 512) s.token_url = *token_url;
  }
  if (auto ready = json->int_at("ready")) {
    s.ready = static_cast<int>(*ready);
    if (s.ready != 0 && s.ready != -1) return std::nullopt;
    return s;
  }
  auto me = json->string_at("me");
  auto id = me ? parse_id(*me) : std::nullopt;
  if (!id) return std::nullopt;
  s.ready = 1;
  s.me = *id;
  if (const Json *hear = json->get("hear")) {
    if (hear->kind == Json::Kind::object) {
      for (const auto &[who, volume] : hear->fields) {
        auto heard = parse_id(who);
        if (!heard || volume.kind != Json::Kind::number) continue;
        const double v = volume.number;
        if (v > 0 && v <= 100) s.hear[*heard] = static_cast<int>(v);
      }
    } else if (hear->kind != Json::Kind::array) {
      return std::nullopt; // BYOND writes an empty list as []
    }
  }
  s.speak = json->int_at("speak") == 1;
  s.talk = s.speak && json->int_at("talk") == 1;
  if (auto team = json->string_at("team")) {
    if (!team->empty() && team->size() <= 64) {
      s.team = *team;
      s.team_talk = s.speak && json->int_at("team_talk") == 1;
    }
  }
  return s;
}

// ---------------------------------------------------------------- BYOND topic
// world/Topic over the BYOND wire format: 0x00 0x83, a big-endian length,
// five zero bytes, "?query", a terminating zero.
inline std::string topic_request(std::string_view query) {
  std::string packet;
  const std::size_t length = 5 + 1 + query.size() + 1;
  packet.push_back('\x00');
  packet.push_back('\x83');
  packet.push_back(static_cast<char>((length >> 8) & 0xff));
  packet.push_back(static_cast<char>(length & 0xff));
  packet.append(5, '\x00');
  packet.push_back('?');
  packet.append(query);
  packet.push_back('\x00');
  return packet;
}

// Bytes still needed for a complete response, or 0 when complete.
inline std::size_t topic_response_needed(std::string_view bytes) {
  if (bytes.size() < 4) return 4 - bytes.size();
  const std::size_t length = (static_cast<unsigned char>(bytes[2]) << 8) |
                             static_cast<unsigned char>(bytes[3]);
  return bytes.size() >= 4 + length ? 0 : 4 + length - bytes.size();
}

// The text answer of a complete response; null for a number, an empty answer
// (the game's limiter) or anything malformed.
inline std::optional<std::string> topic_response_text(std::string_view bytes) {
  if (bytes.size() < 5 || bytes[0] != '\x00' || bytes[1] != '\x83' ||
      topic_response_needed(bytes) != 0)
    return std::nullopt;
  const std::size_t length = (static_cast<unsigned char>(bytes[2]) << 8) |
                             static_cast<unsigned char>(bytes[3]);
  if (length < 1 || bytes[4] != '\x06') return std::nullopt;
  std::string_view body = bytes.substr(5, length - 1);
  while (!body.empty() && body.back() == '\x00') body.remove_suffix(1);
  if (body.empty()) return std::nullopt;
  return std::string(body);
}

// ---------------------------------------------------------------- bot token
struct TokenAnswer {
  bool ready = false;
  std::string sealed; // base64(nonce|ciphertext|tag)
};

inline std::optional<TokenAnswer> parse_token_answer(std::string_view text) {
  auto json = JsonParser::parse(text);
  if (!json || json->kind != Json::Kind::object || json->int_at("v") != 1)
    return std::nullopt;
  if (auto sealed = json->string_at("sealed")) {
    if (sealed->size() < 40 || sealed->size() > 8192) return std::nullopt;
    return TokenAnswer{true, *sealed};
  }
  const Json *ready = json->get("ready");
  if (ready && ready->kind == Json::Kind::boolean && !ready->boolean)
    return TokenAnswer{false, {}};
  return std::nullopt;
}

struct Token {
  uint64_t application = 0;
  std::string server;
  uint64_t user = 0;
  std::string access_token;
  int64_t expires_in = 0;
};

inline std::optional<Token> parse_token(std::string_view plaintext) {
  auto json = JsonParser::parse(plaintext);
  if (!json || json->kind != Json::Kind::object || json->int_at("v") != 1)
    return std::nullopt;
  Token t;
  auto app = json->string_at("application_id");
  auto user = json->string_at("user_id");
  auto access = json->string_at("access_token");
  auto server = json->string_at("server");
  auto expires = json->int_at("expires_in");
  if (!app || !user || !access || !server || !expires) return std::nullopt;
  auto app_id = parse_id(*app);
  auto user_id = parse_id(*user);
  if (!app_id || !user_id || access->empty() || access->size() > 4096 ||
      server->empty() || server->size() > 64 || *expires <= 0)
    return std::nullopt;
  t.application = *app_id;
  t.user = *user_id;
  t.access_token = *access;
  t.server = *server;
  t.expires_in = *expires;
  return t;
}

// ---------------------------------------------------------------- URLs
struct HttpUrl {
  bool https = false;
  std::string host;
  uint16_t port = 0;
  std::string path;
};

// http(s)://host[:port][/path], the same shape the game accepts for
// VOICE_TOKEN_URL. No user info, query or fragment.
inline std::optional<HttpUrl> parse_url(std::string_view url) {
  HttpUrl out;
  if (url.substr(0, 7) == "http://") { url.remove_prefix(7); out.port = 80; }
  else if (url.substr(0, 8) == "https://") { url.remove_prefix(8); out.https = true; out.port = 443; }
  else return std::nullopt;
  const std::size_t slash = url.find('/');
  std::string_view authority = url.substr(0, slash);
  out.path = slash == std::string_view::npos ? "/" : std::string(url.substr(slash));
  if (authority.empty() || authority.find_first_of("@?#") != std::string_view::npos ||
      out.path.find_first_of("?# ") != std::string::npos)
    return std::nullopt;
  const std::size_t colon = authority.rfind(':');
  if (colon != std::string_view::npos) {
    std::string_view port = authority.substr(colon + 1);
    if (port.empty() || port.size() > 5) return std::nullopt;
    unsigned value = 0;
    for (char c : port) {
      if (c < '0' || c > '9') return std::nullopt;
      value = value * 10 + static_cast<unsigned>(c - '0');
    }
    if (value == 0 || value > 65535) return std::nullopt;
    out.port = static_cast<uint16_t>(value);
    authority = authority.substr(0, colon);
  }
  for (char c : authority) {
    const bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                    (c >= '0' && c <= '9') || c == '-' || c == '.';
    if (!ok) return std::nullopt;
  }
  if (authority.empty()) return std::nullopt;
  out.host = std::string(authority);
  return out;
}

// ---------------------------------------------------------------- base64
inline std::optional<std::string> base64_decode(std::string_view in) {
  if (in.size() % 4 != 0) return std::nullopt;
  std::string out;
  out.reserve(in.size() / 4 * 3);
  auto digit = [](char c) -> int {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
  };
  for (std::size_t i = 0; i < in.size(); i += 4) {
    int v[4];
    int pad = 0;
    for (std::size_t j = 0; j < 4; ++j) {
      const char c = in[i + j];
      if (c == '=') {
        if (i + 4 != in.size() || j < 2) return std::nullopt;
        v[j] = 0;
        ++pad;
      } else {
        if (pad) return std::nullopt;
        v[j] = digit(c);
        if (v[j] < 0) return std::nullopt;
      }
    }
    const uint32_t n = (static_cast<uint32_t>(v[0]) << 18) | (static_cast<uint32_t>(v[1]) << 12) |
                       (static_cast<uint32_t>(v[2]) << 6) | static_cast<uint32_t>(v[3]);
    out.push_back(static_cast<char>((n >> 16) & 0xff));
    if (pad < 2) out.push_back(static_cast<char>((n >> 8) & 0xff));
    if (pad < 1) out.push_back(static_cast<char>(n & 0xff));
  }
  return out;
}

// ---------------------------------------------------------------- lobbies
enum class LobbyKind { none, region, team };

// Which of the bot's lobbies this is for this player. The bot names the
// world in civ13_server and the kind in civ13_kind; a team lobby also names
// its team in civ13_team.
inline LobbyKind lobby_kind(const std::map<std::string, std::string> &metadata,
                            const std::string &server, const std::string &team) {
  auto field = [&](const char *name) -> std::string {
    auto found = metadata.find(name);
    return found == metadata.end() ? std::string{} : found->second;
  };
  if (server.empty() || field("civ13_server") != server) return LobbyKind::none;
  const std::string kind = field("civ13_kind");
  if (kind == "region") return LobbyKind::region;
  if (kind == "team" && !team.empty() && field("civ13_team") == team) return LobbyKind::team;
  return LobbyKind::none;
}

// ---------------------------------------------------------------- the mix
struct Mix {
  bool region_ptt = false;
  bool team_ptt = false;
  bool team_audible = false;
  // Region call participants: volume 0-200 (Discord's scale), or muted.
  std::map<uint64_t, std::optional<float>> region; // nullopt = muted
};

// What to set on the two calls right now. last_ok_ms is when the last good
// answer arrived; now_ms is the same clock. Anyone not in sight is muted;
// the player's own ID is skipped.
inline Mix mix(const std::optional<GameState> &state, int64_t last_ok_ms,
               int64_t now_ms, const std::vector<uint64_t> &region_participants) {
  Mix out;
  const bool fresh = state && state->ready == 1 && now_ms >= last_ok_ms &&
                     now_ms - last_ok_ms <= stale_ms;
  for (uint64_t who : region_participants) {
    if (state && who == state->me) continue;
    std::optional<float> volume;
    if (fresh) {
      auto heard = state->hear.find(who);
      if (heard != state->hear.end() && heard->second > 0)
        volume = static_cast<float>(heard->second);
    }
    out.region[who] = volume;
  }
  if (fresh) {
    out.region_ptt = state->talk;
    out.team_ptt = state->team_talk;
    out.team_audible = !state->team.empty();
  }
  return out;
}

} // namespace civ13::voice::region
