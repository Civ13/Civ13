#pragma once
// Portable decisions for the Phase 2 push-to-talk prototype. No SDK types:
// tests/voice_tests.cpp exercises every rule here in CI without Discord.
#include <cstdint>
#include <optional>
#include <string_view>

namespace civ13::voice {

// Process exit codes, so a tester can report the outcome as one number.
enum class Exit : int {
  closed = 0,           // Q, Ctrl+C or console close after a clean leave
  arguments = 2,        // bad application id or lobby secret
  consent_refused = 3,  // the player declined or closed the Discord prompt
  token_failed = 4,     // code exchange or refresh failed
  lobby_failed = 5,     // lobby join or call start failed
  connection_lost = 6,  // Discord disconnected with an error and gave up
};

struct Arguments {
  uint64_t application = 0;
  std::string_view secret;
};

// argv: program application-id lobby-secret. The id is decimal, nonzero and
// fits uint64. The secret is 8 to 64 letters, digits, '-' or '_' so it can be
// read aloud or pasted between two testers without quoting.
inline std::optional<Arguments> parse_arguments(int argc,
                                                const char *const *argv) {
  if (argc != 3 || !argv || !argv[1] || !argv[2])
    return std::nullopt;
  std::string_view id{argv[1]}, secret{argv[2]};
  if (id.empty() || id.size() > 20 || id.front() == '0')
    return std::nullopt;
  uint64_t value = 0;
  for (char c : id) {
    if (c < '0' || c > '9')
      return std::nullopt;
    const uint64_t digit = static_cast<uint64_t>(c - '0');
    if (value > (UINT64_MAX - digit) / 10)
      return std::nullopt;
    value = value * 10 + digit;
  }
  if (secret.size() < 8 || secret.size() > 64)
    return std::nullopt;
  for (char c : secret) {
    const bool ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                    (c >= '0' && c <= '9') || c == '-' || c == '_';
    if (!ok)
      return std::nullopt;
  }
  return Arguments{value, secret};
}

// Push-to-talk key tracking. A key press only counts when the console window
// delivered it (so typing in another program never opens the microphone), and
// it stops counting when the console loses focus or the physical key is up.
class PushToTalk {
public:
  void key(bool down) noexcept { console_down_ = down && focused_; }
  void focus(bool focused) noexcept {
    focused_ = focused;
    if (!focused)
      console_down_ = false;
  }
  // physical_down: the key's real state right now (GetAsyncKeyState), which
  // catches a release the console never saw.
  bool held(bool physical_down) noexcept {
    if (!physical_down)
      console_down_ = false;
    return focused_ && console_down_;
  }

private:
  bool console_down_ = false;
  bool focused_ = true;
};

struct Mic {
  bool ptt_held = false;
  bool in_call = false;
  bool self_muted = false;
  bool deafened = false;
  bool leaving = false;
};

// The microphone transmits only while every condition allows it.
constexpr bool transmit(const Mic &m) noexcept {
  return m.ptt_held && m.in_call && !m.self_muted && !m.deafened &&
         !m.leaving;
}

enum class Phase {
  authorizing,
  exchanging,
  connecting,
  joining,
  in_call,
  leaving,
  closed,
};

enum class Event {
  consent_granted,
  consent_refused,
  token_ready,
  token_failed,
  client_ready,
  lobby_joined,
  lobby_failed,
  call_started,
  call_failed,
  disconnected_error,
  quit,
  left,
};

struct Transition {
  Phase next;
  std::optional<Exit> exit; // set once the process should finish
};

// The prototype's session flow. Unknown or late events leave the phase alone,
// so a callback that arrives after Q cannot rejoin a call.
constexpr Transition advance(Phase phase, Event event) noexcept {
  if (phase == Phase::closed)
    return {Phase::closed, std::nullopt};
  if (event == Event::quit) {
    if (phase == Phase::leaving)
      return {phase, std::nullopt};
    // Before the lobby exists there is nothing to leave.
    if (phase == Phase::joining || phase == Phase::in_call)
      return {Phase::leaving, std::nullopt};
    return {Phase::closed, Exit::closed};
  }
  if (event == Event::left)
    return phase == Phase::leaving ? Transition{Phase::closed, Exit::closed}
                                   : Transition{phase, std::nullopt};
  if (phase == Phase::leaving)
    return {phase, std::nullopt};
  if (event == Event::disconnected_error)
    return {Phase::closed, Exit::connection_lost};
  switch (phase) {
  case Phase::authorizing:
    if (event == Event::consent_granted)
      return {Phase::exchanging, std::nullopt};
    if (event == Event::consent_refused)
      return {Phase::closed, Exit::consent_refused};
    break;
  case Phase::exchanging:
    if (event == Event::token_ready)
      return {Phase::connecting, std::nullopt};
    if (event == Event::token_failed)
      return {Phase::closed, Exit::token_failed};
    break;
  case Phase::connecting:
    if (event == Event::client_ready)
      return {Phase::joining, std::nullopt};
    if (event == Event::token_failed)
      return {Phase::closed, Exit::token_failed};
    break;
  case Phase::joining:
    if (event == Event::lobby_joined || event == Event::call_started)
      return {event == Event::call_started ? Phase::in_call : Phase::joining,
              std::nullopt};
    if (event == Event::lobby_failed || event == Event::call_failed)
      return {Phase::closed, Exit::lobby_failed};
    break;
  case Phase::in_call:
    // A refreshed token keeps the call; a failed refresh does not end it, the
    // SDK keeps an active call until the connection itself drops.
    break;
  default:
    break;
  }
  return {phase, std::nullopt};
}

// Seconds before expiry at which the prototype refreshes on its own, in case
// the SDK's expiration callback does not fire (for example, a sleeping PC).
constexpr int32_t refresh_margin_seconds = 300;
constexpr int64_t refresh_at_ms(int64_t now_ms, int32_t expires_in) noexcept {
  if (expires_in <= 0)
    return now_ms;
  const int64_t lead =
      expires_in > 2 * refresh_margin_seconds ? refresh_margin_seconds
                                              : expires_in / 2;
  return now_ms + (static_cast<int64_t>(expires_in) - lead) * 1000;
}

} // namespace civ13::voice
