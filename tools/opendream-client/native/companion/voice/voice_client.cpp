// Phase 3 region voice client (issue #5122, docs/launcher-voice-plan.md).
//
// The launcher starts this beside Dream Seeker:
//   civ13-voice.exe --host <address> --port <port> [--watch-pid <pid>]
// and writes the per-connection voice key on stdin (one line). The same key
// went to the game in the join link. After that the key never crosses the
// network: the game is polled with sha1, the bot is asked with sha256 and
// its answer is opened locally (voice/win_crypto.hpp).
//
// The game decides everything (voice/region_voice.hpp): who is in sight and
// how loud, and whether the talk or team-radio keybinding is held. This
// program reads no keyboard state at all. It joins two Discord lobby calls
// the bot set up (this region, this team), keeps both in push-to-talk mode,
// and follows the game ten times a second. Without a fresh answer for three
// seconds both microphones close and the region call goes quiet.
//
// Nothing is recorded or logged beyond status lines; the access token, voice
// key and audio never reach a log.
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <winhttp.h>

#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"

#include "region_voice.hpp"
#include "win_crypto.hpp"

#include <atomic>
#include <chrono>
#include <cstdio>
#include <iostream>
#include <map>
#include <mutex>
#include <optional>
#include <string>
#include <thread>

#ifdef _MSC_VER
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "winhttp.lib")
#endif

using namespace civ13::voice;
using namespace civ13::voice::region;

namespace {

enum class Exit : int { closed = 0, arguments = 2, token_failed = 4, game_gone = 7 };

int64_t now_ms() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}

std::atomic<bool> quit_requested{false};
BOOL WINAPI on_console_control(DWORD) {
  quit_requested = true;
  return TRUE;
}

struct Arguments {
  std::string host;
  uint16_t port = 0;
  DWORD watch_pid = 0;
};

std::optional<Arguments> parse_arguments(int argc, char **argv) {
  Arguments out;
  for (int i = 1; i + 1 < argc; i += 2) {
    const std::string name = argv[i], value = argv[i + 1];
    if (name == "--host" && value.size() <= 253) out.host = value;
    else if (name == "--port") {
      const unsigned long port = std::strtoul(value.c_str(), nullptr, 10);
      if (port == 0 || port > 65535) return std::nullopt;
      out.port = static_cast<uint16_t>(port);
    } else if (name == "--watch-pid") {
      out.watch_pid = static_cast<DWORD>(std::strtoul(value.c_str(), nullptr, 10));
    } else return std::nullopt;
  }
  if (argc % 2 != 1 || out.host.empty() || !out.port) return std::nullopt;
  return out;
}

// ---------------------------------------------------------------- game topic
// One world/Topic call over TCP with short timeouts. Null on any failure or
// on the game's empty "too soon" answer.
std::optional<std::string> topic_call(const std::string &host, uint16_t port,
                                      const std::string &query) {
  addrinfo hints{};
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;
  addrinfo *found = nullptr;
  if (getaddrinfo(host.c_str(), std::to_string(port).c_str(), &hints, &found) != 0 || !found)
    return std::nullopt;
  std::optional<std::string> answer;
  for (addrinfo *a = found; a && !answer; a = a->ai_next) {
    SOCKET s = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
    if (s == INVALID_SOCKET) continue;
    DWORD timeout = 1500;
    setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<const char *>(&timeout), sizeof(timeout));
    setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, reinterpret_cast<const char *>(&timeout), sizeof(timeout));
    if (connect(s, a->ai_addr, static_cast<int>(a->ai_addrlen)) == 0) {
      const std::string request = topic_request(query);
      if (send(s, request.data(), static_cast<int>(request.size()), 0) == static_cast<int>(request.size())) {
        std::string bytes;
        char buffer[4096];
        while (bytes.size() < max_answer_bytes + 8) {
          const std::size_t needed = topic_response_needed(bytes);
          if (needed == 0) break;
          const int got = recv(s, buffer, static_cast<int>(sizeof(buffer)), 0);
          if (got <= 0) break;
          bytes.append(buffer, static_cast<std::size_t>(got));
        }
        answer = topic_response_text(bytes);
      }
    }
    closesocket(s);
  }
  freeaddrinfo(found);
  return answer;
}

class GamePoller {
public:
  GamePoller(std::string host, uint16_t port, std::string poll_id)
      : host_(std::move(host)), port_(port), query_("civ13_voice_state=" + std::move(poll_id)) {
    thread_ = std::thread([this] { run(); });
  }
  ~GamePoller() {
    stop_ = true;
    if (thread_.joinable()) thread_.join();
  }
  // The newest good answer and when it arrived.
  std::pair<std::optional<GameState>, int64_t> latest() {
    std::lock_guard<std::mutex> lock(mutex_);
    return {state_, at_};
  }
  int64_t last_reply() const { return last_reply_; }

private:
  void run() {
    while (!stop_) {
      const int64_t started = now_ms();
      if (auto text = topic_call(host_, port_, query_)) {
        last_reply_ = now_ms();
        if (auto parsed = parse_state(*text)) {
          std::lock_guard<std::mutex> lock(mutex_);
          state_ = parsed;
          at_ = now_ms();
        }
      }
      const int64_t spent = now_ms() - started;
      if (spent < poll_interval_ms)
        std::this_thread::sleep_for(std::chrono::milliseconds(poll_interval_ms - spent));
    }
  }
  std::string host_;
  uint16_t port_;
  std::string query_;
  std::thread thread_;
  std::atomic<bool> stop_{false};
  std::atomic<int64_t> last_reply_{0};
  std::mutex mutex_;
  std::optional<GameState> state_;
  int64_t at_ = 0;
};

// ---------------------------------------------------------------- bot token
// POST {"id": token id} to the bot. Returns the body of a 200 or 202.
std::optional<std::string> http_post(const HttpUrl &url, const std::string &body) {
  std::optional<std::string> out;
  HINTERNET session = WinHttpOpen(L"Civ13-Voice/1", WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                                  WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
  if (!session) return out;
  WinHttpSetTimeouts(session, 5000, 5000, 5000, 5000);
  const std::wstring host(url.host.begin(), url.host.end());
  const std::wstring path(url.path.begin(), url.path.end());
  HINTERNET connection = WinHttpConnect(session, host.c_str(), url.port, 0);
  HINTERNET request = connection
                          ? WinHttpOpenRequest(connection, L"POST", path.c_str(), nullptr,
                                               WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                               url.https ? WINHTTP_FLAG_SECURE : 0)
                          : nullptr;
  const wchar_t headers[] = L"Content-Type: application/json\r\n";
  if (request &&
      WinHttpSendRequest(request, headers, static_cast<DWORD>(-1L),
                         const_cast<char *>(body.data()), static_cast<DWORD>(body.size()),
                         static_cast<DWORD>(body.size()), 0) &&
      WinHttpReceiveResponse(request, nullptr)) {
    DWORD status = 0, size = sizeof(status);
    WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX, &status, &size, WINHTTP_NO_HEADER_INDEX);
    std::string text;
    DWORD available = 0;
    while (WinHttpQueryDataAvailable(request, &available) && available > 0 &&
           text.size() < max_answer_bytes) {
      std::string chunk(available, '\0');
      DWORD read = 0;
      if (!WinHttpReadData(request, chunk.data(), available, &read) || read == 0) break;
      text.append(chunk.data(), read);
    }
    if (status == 200 || status == 202) out = text;
  }
  if (request) WinHttpCloseHandle(request);
  if (connection) WinHttpCloseHandle(connection);
  WinHttpCloseHandle(session);
  return out;
}

class TokenFetch {
public:
  // Starts one request in the background.
  TokenFetch(HttpUrl url, std::string key, std::string id)
      : thread_([this, url = std::move(url), key = std::move(key), id = std::move(id)] {
          auto body = http_post(url, "{\"id\":\"" + id + "\"}");
          auto answer = body ? parse_token_answer(*body) : std::nullopt;
          if (answer && answer->ready) {
            auto raw = base64_decode(answer->sealed);
            auto plain = raw ? crypto::open_sealed(key, id, *raw) : std::nullopt;
            result_ = plain ? parse_token(*plain) : std::nullopt;
          }
          done_ = true;
        }) {}
  ~TokenFetch() {
    if (thread_.joinable()) thread_.join();
  }
  bool done() const { return done_; }
  std::optional<Token> result() {
    if (thread_.joinable()) thread_.join();
    return result_;
  }

private:
  std::optional<Token> result_;
  std::atomic<bool> done_{false};
  std::thread thread_;
};

// ---------------------------------------------------------------- Discord
struct Voice {
  std::shared_ptr<discordpp::Client> client;
  bool ready = false;
  bool connecting = false;
  std::string server;
  uint64_t me = 0;
  std::map<uint64_t, discordpp::Call> calls; // lobby -> call
  std::map<uint64_t, LobbyKind> kinds;       // lobby -> what it is for us
  std::map<uint64_t, std::optional<float>> applied; // region volumes already set
  bool region_ptt = false, team_ptt = false, team_audible = true;

  void connect(const Token &token) {
    server = token.server;
    me = token.user;
    client->SetApplicationId(token.application);
    connecting = true;
    client->UpdateToken(discordpp::AuthorizationTokenType::Bearer, token.access_token,
                        [this](discordpp::ClientResult result) {
                          if (result.Successful()) client->Connect();
                          else {
                            connecting = false;
                            std::cout << "Voice sign-in failed: " << result.Error() << "\n";
                          }
                        });
  }

  void start_call(uint64_t lobby, LobbyKind kind) {
    auto call = client->StartCall(lobby);
    if (!call) call = client->GetCall(lobby);
    if (!call) return;
    call.SetAudioMode(discordpp::AudioModeType::MODE_PTT);
    call.SetPTTReleaseDelay(20);
    call.SetPTTActive(false);
    calls.emplace(lobby, std::move(call));
    kinds[lobby] = kind;
    applied.clear();
    std::cout << (kind == LobbyKind::region ? "Joined region voice.\n" : "Joined team radio.\n");
  }

  void end_call(uint64_t lobby) {
    auto found = calls.find(lobby);
    if (found == calls.end()) return;
    found->second.SetPTTActive(false);
    client->EndCall(lobby, [] {});
    calls.erase(found);
    kinds.erase(lobby);
    applied.clear();
  }

  // Joins the bot's lobbies for this world and team; leaves any that no
  // longer apply (team change, world change, removed by the bot).
  void reconcile(const std::string &team) {
    if (!ready) return;
    std::map<uint64_t, LobbyKind> wanted;
    for (uint64_t lobby : client->GetLobbyIds()) {
      auto handle = client->GetLobbyHandle(lobby);
      if (!handle) continue;
      const auto metadata = handle->Metadata();
      const std::map<std::string, std::string> fields(metadata.begin(), metadata.end());
      const LobbyKind kind = lobby_kind(fields, server, team);
      if (kind != LobbyKind::none) wanted[lobby] = kind;
    }
    for (auto it = kinds.begin(); it != kinds.end();) {
      const uint64_t lobby = it->first;
      ++it;
      auto keep = wanted.find(lobby);
      if (keep == wanted.end() || keep->second != kinds[lobby]) end_call(lobby);
    }
    for (const auto &[lobby, kind] : wanted)
      if (!calls.count(lobby)) start_call(lobby, kind);
  }

  void apply(const std::optional<GameState> &state, int64_t at, int64_t now) {
    for (auto &[lobby, call] : calls) {
      const LobbyKind kind = kinds[lobby];
      if (kind == LobbyKind::region) {
        const Mix m = mix(state, at, now, call.GetParticipants());
        if (m.region_ptt != region_ptt) call.SetPTTActive(m.region_ptt);
        region_ptt = m.region_ptt;
        for (const auto &[who, volume] : m.region) {
          auto before = applied.find(who);
          if (before != applied.end() && before->second == volume) continue;
          if (volume) {
            call.SetLocalMute(who, false);
            // The game's 0-100 is a share of normal playback; Discord's 100 is normal.
            call.SetParticipantVolume(who, *volume);
          } else {
            call.SetLocalMute(who, true);
          }
          applied[who] = volume;
        }
      } else if (kind == LobbyKind::team) {
        const Mix m = mix(state, at, now, {});
        if (m.team_ptt != team_ptt) call.SetPTTActive(m.team_ptt);
        team_ptt = m.team_ptt;
        if (m.team_audible != team_audible) call.SetSelfDeaf(!m.team_audible);
        team_audible = m.team_audible;
      }
    }
  }

  void close_microphones() {
    for (auto &[lobby, call] : calls) call.SetPTTActive(false);
    region_ptt = team_ptt = false;
  }
};

std::optional<std::string> read_key() {
  std::string line;
  if (!std::getline(std::cin, line)) return std::nullopt;
  while (!line.empty() && (line.back() == '\r' || line.back() == '\n' || line.back() == ' '))
    line.pop_back();
  if (!valid_voice_key(line)) return std::nullopt;
  return line;
}

} // namespace

int main(int argc, char **argv) {
  auto args = parse_arguments(argc, argv);
  if (!args) {
    std::cerr << "usage: civ13-voice --host <address> --port <port> [--watch-pid <pid>]"
                 " (voice key on stdin)\n";
    return static_cast<int>(Exit::arguments);
  }
  const auto key = read_key();
  if (!key) {
    std::cerr << "No voice key on stdin.\n";
    return static_cast<int>(Exit::arguments);
  }
  const auto poll = crypto::poll_id(*key);
  const auto token_id = crypto::token_id(*key);
  if (!poll || !token_id) return static_cast<int>(Exit::arguments);

  WSADATA wsa;
  if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) return static_cast<int>(Exit::arguments);
  SetConsoleCtrlHandler(on_console_control, TRUE);
  HANDLE watched = args->watch_pid ? OpenProcess(SYNCHRONIZE, FALSE, args->watch_pid) : nullptr;

  Voice voice;
  voice.client = std::make_shared<discordpp::Client>();
  voice.client->AddLogCallback(
      [](std::string message, discordpp::LoggingSeverity) { std::cerr << "[discord] " << message << "\n"; },
      discordpp::LoggingSeverity::Warning);
  voice.client->SetStatusChangedCallback(
      [&voice](discordpp::Client::Status status, discordpp::Client::Error error, int32_t) {
        voice.ready = status == discordpp::Client::Status::Ready;
        if (status == discordpp::Client::Status::Ready) {
          voice.connecting = false;
          std::cout << "Voice connected.\n";
        } else if (status == discordpp::Client::Status::Disconnected) {
          voice.connecting = false;
          voice.calls.clear();
          voice.kinds.clear();
          voice.applied.clear();
          if (error != discordpp::Client::Error::None)
            std::cout << "Voice disconnected: " << discordpp::Client::ErrorToString(error) << "\n";
        }
      });
  bool token_wanted = true;
  voice.client->SetTokenExpirationCallback([&token_wanted]() { token_wanted = true; });

  GamePoller game(args->host, args->port, *poll);
  std::unique_ptr<TokenFetch> fetch;
  int64_t next_fetch = 0, next_reconcile = 0, refresh_at = 0;
  int64_t fetch_delay = 2000;
  bool signed_in = false;
  const int64_t started = now_ms();
  int exit_code = static_cast<int>(Exit::closed);

  while (!quit_requested) {
    discordpp::RunCallbacks();
    const int64_t now = now_ms();
    if (watched && WaitForSingleObject(watched, 0) == WAIT_OBJECT_0) break; // the game closed
    auto [state, at] = game.latest();
    // The game stopped knowing this key (disconnected), or never answered.
    if (state && state->ready == -1 && now - at < 1000 && now - started > 30000) {
      exit_code = static_cast<int>(Exit::game_gone);
      break;
    }
    if (!state && now - started > 120000) {
      exit_code = static_cast<int>(Exit::game_gone);
      break;
    }
    // Token: once the game has a token address, ask the bot until it is ready.
    if (refresh_at && now >= refresh_at) token_wanted = true;
    if (token_wanted && !fetch && now >= next_fetch && state && state->ready >= 0 &&
        !state->token_url.empty()) {
      if (auto url = parse_url(state->token_url))
        fetch = std::make_unique<TokenFetch>(*url, *key, *token_id);
    }
    if (fetch && fetch->done()) {
      auto token = fetch->result();
      fetch.reset();
      if (token) {
        token_wanted = false;
        fetch_delay = 2000;
        // Tokens cannot be refreshed; ask for a fresh one halfway through.
        refresh_at = now + std::min<int64_t>(token->expires_in, 7 * 24 * 3600) * 500;
        if (!signed_in || token->server != voice.server) {
          signed_in = true;
          voice.connect(*token);
        } else {
          voice.client->UpdateToken(discordpp::AuthorizationTokenType::Bearer, token->access_token,
                                    [](discordpp::ClientResult) {});
        }
      } else {
        next_fetch = now + fetch_delay;
        fetch_delay = std::min<int64_t>(fetch_delay * 2, 15000);
      }
    }
    if (now >= next_reconcile) {
      next_reconcile = now + 500;
      voice.reconcile(state && now - at <= stale_ms ? state->team : std::string{});
    }
    voice.apply(state, at, now);
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }

  voice.close_microphones();
  voice.client->Disconnect();
  for (int i = 0; i < 30; ++i) {
    discordpp::RunCallbacks();
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  voice.calls.clear();
  voice.client.reset();
  if (watched) CloseHandle(watched);
  WSACleanup();
  std::cout << "Voice closed.\n";
  return exit_code;
}
