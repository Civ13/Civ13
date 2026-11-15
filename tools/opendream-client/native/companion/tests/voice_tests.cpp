// Portable checks for the Phase 2 push-to-talk prototype's decisions.
#include "../voice/voice_control.hpp"
#include <iostream>
#include <source_location>
#include <stdexcept>
#include <string>
using namespace civ13::voice;
namespace {
int assertions = 0;
void check(bool value,
           std::source_location at = std::source_location::current()) {
  ++assertions;
  if (!value)
    throw std::runtime_error("voice assertion " + std::to_string(assertions) +
                             " at line " + std::to_string(at.line()));
}
std::optional<Arguments> parse(const char *id, const char *secret) {
  const char *argv[] = {"civ13-voice-proto", id, secret};
  return parse_arguments(3, argv);
}
void arguments() {
  auto ok = parse("1562126764849897544", "civ13-test_01");
  check(ok && ok->application == 1562126764849897544ull);
  check(ok && ok->secret == "civ13-test_01");
  check(parse("18446744073709551615", "abcdefgh").has_value());
  check(!parse("18446744073709551616", "abcdefgh")); // overflow
  check(!parse("0", "abcdefgh"));
  check(!parse("0123", "abcdefgh"));
  check(!parse("", "abcdefgh"));
  check(!parse("12a", "abcdefgh"));
  check(!parse("-1", "abcdefgh"));
  check(!parse("123", "short"));
  check(!parse("123", std::string(65, 'a').c_str()));
  check(parse("123", std::string(64, 'a').c_str()).has_value());
  check(!parse("123", "has space"));
  check(!parse("123", "quote\"inside"));
  const char *two[] = {"p", "123"};
  check(!parse_arguments(2, two));
  const char *four[] = {"p", "123", "abcdefgh", "x"};
  check(!parse_arguments(4, four));
  check(!parse_arguments(3, nullptr));
}
void push_to_talk() {
  PushToTalk ptt;
  check(!ptt.held(0)); // nothing pressed
  ptt.key(true, 100);
  check(ptt.held(100));
  check(ptt.held(100 + PushToTalk::stale_ms)); // still inside the window
  ptt.key(true, 1000); // a repeat event keeps it open
  check(ptt.held(1000 + PushToTalk::stale_ms));
  check(!ptt.held(1001 + PushToTalk::stale_ms)); // missed key-up closes it
  check(!ptt.held(1002 + PushToTalk::stale_ms));
  ptt.key(true, 5000);
  check(ptt.held(5000));
  check(!ptt.held(4999)); // clock going backwards closes it
  ptt.key(true, 6000);
  ptt.focus(false);
  check(!ptt.held(6000));
  ptt.key(true, 6010); // a stray event while unfocused does not transmit
  check(!ptt.held(6010));
  ptt.focus(true);
  check(!ptt.held(6020)); // focus back alone does not reopen it
  ptt.key(true, 6030);
  check(ptt.held(6030));
  ptt.key(false, 6040);
  check(!ptt.held(6040));
}
void microphone() {
  Mic m{true, true, false, false, false};
  check(transmit(m));
  m.ptt_held = false;
  check(!transmit(m));
  m = {true, false, false, false, false};
  check(!transmit(m));
  m = {true, true, true, false, false};
  check(!transmit(m));
  m = {true, true, false, true, false};
  check(!transmit(m));
  m = {true, true, false, false, true};
  check(!transmit(m));
  check(!transmit(Mic{}));
}
void flow() {
  auto t = advance(Phase::authorizing, Event::consent_refused);
  check(t.next == Phase::closed && t.exit == Exit::consent_refused);
  t = advance(Phase::authorizing, Event::consent_granted);
  check(t.next == Phase::exchanging && !t.exit);
  t = advance(Phase::exchanging, Event::token_failed);
  check(t.next == Phase::closed && t.exit == Exit::token_failed);
  t = advance(Phase::exchanging, Event::token_ready);
  check(t.next == Phase::connecting && !t.exit);
  t = advance(Phase::connecting, Event::token_failed);
  check(t.exit == Exit::token_failed);
  t = advance(Phase::connecting, Event::client_ready);
  check(t.next == Phase::joining);
  t = advance(Phase::joining, Event::lobby_joined);
  check(t.next == Phase::joining && !t.exit);
  t = advance(Phase::joining, Event::lobby_failed);
  check(t.exit == Exit::lobby_failed);
  t = advance(Phase::joining, Event::call_failed);
  check(t.exit == Exit::lobby_failed);
  t = advance(Phase::joining, Event::call_started);
  check(t.next == Phase::in_call && !t.exit);
  // Token refresh failure mid-call keeps the call.
  t = advance(Phase::in_call, Event::token_failed);
  check(t.next == Phase::in_call && !t.exit);
  t = advance(Phase::in_call, Event::disconnected_error);
  check(t.next == Phase::closed && t.exit == Exit::connection_lost);
  // Quit before a lobby closes at once; quit with a lobby leaves first.
  t = advance(Phase::authorizing, Event::quit);
  check(t.next == Phase::closed && t.exit == Exit::closed);
  t = advance(Phase::connecting, Event::quit);
  check(t.exit == Exit::closed);
  t = advance(Phase::in_call, Event::quit);
  check(t.next == Phase::leaving && !t.exit);
  t = advance(Phase::joining, Event::quit);
  check(t.next == Phase::leaving);
  // While leaving, late callbacks cannot rejoin or change the exit.
  check(advance(Phase::leaving, Event::call_started).next == Phase::leaving);
  check(advance(Phase::leaving, Event::lobby_joined).next == Phase::leaving);
  check(advance(Phase::leaving, Event::disconnected_error).next ==
        Phase::leaving);
  check(!advance(Phase::leaving, Event::quit).exit);
  t = advance(Phase::leaving, Event::left);
  check(t.next == Phase::closed && t.exit == Exit::closed);
  // Closed is final.
  t = advance(Phase::closed, Event::call_started);
  check(t.next == Phase::closed && !t.exit);
  check(!advance(Phase::closed, Event::quit).exit);
  // Out-of-order events are ignored.
  check(advance(Phase::authorizing, Event::client_ready).next ==
        Phase::authorizing);
  check(advance(Phase::in_call, Event::left).next == Phase::in_call);
}
void refresh() {
  check(refresh_at_ms(1000, 604800) == 1000 + (604800 - 300) * 1000ll);
  check(refresh_at_ms(0, 600) == 300 * 1000);
  check(refresh_at_ms(0, 100) == 50 * 1000);
  check(refresh_at_ms(42, 0) == 42);
  check(refresh_at_ms(42, -5) == 42);
}
} // namespace
int main() {
  try {
    arguments();
    push_to_talk();
    microphone();
    flow();
    refresh();
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
  std::cout << "voice tests passed: " << assertions << " assertions\n";
  return 0;
}
