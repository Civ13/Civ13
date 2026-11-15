// Phase 2 prototype for issue #5122: opt-in two-player push-to-talk through
// the Discord Social SDK. A standalone Windows console tool, not part of the
// launcher or the game, so nothing here can block joining a server.
//
//   civ13-voice-proto.exe <application-id> <lobby-secret>
//
// Both testers run it with the same lobby secret. The microphone is silent
// until SPACE is held in this window. Tokens stay in memory and are never
// printed; no audio is recorded or written anywhere.
//
// Built only by Build-VoiceProto.ps1 against an external SDK directory. The
// SDK header, libraries and DLLs are never committed.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"

#include "voice_control.hpp"

#include <array>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <iostream>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <thread>
#include <vector>

namespace {
using namespace civ13::voice;

std::atomic<bool> quit_requested{false};

BOOL WINAPI on_console_control(DWORD) {
  quit_requested = true;
  return TRUE;
}

int64_t now_ms() { return static_cast<int64_t>(GetTickCount64()); }

constexpr WORD ptt_key = VK_SPACE;
constexpr int64_t leave_timeout_ms = 5000;

struct App {
  uint64_t application = 0;
  std::string secret;
  std::shared_ptr<discordpp::Client> client;
  Phase phase = Phase::authorizing;
  std::optional<Exit> exit;
  // Credentials: memory only, never printed.
  std::string refresh_token;
  int64_t refresh_due = 0;
  bool refreshing = false;
  bool refresh_wanted = false;
  bool lobby_requested = false;
  uint64_t lobby = 0;
  std::optional<discordpp::Call> call;
  PushToTalk ptt;
  Mic mic;
  bool transmitting = false;
  int64_t leave_started = 0;
  std::vector<std::string> input_ids;
  size_t next_input = 0;

  void on(Event event) {
    const auto t = advance(phase, event);
    phase = t.next;
    if (t.exit && !exit)
      exit = t.exit;
    if (phase == Phase::leaving && !leave_started)
      begin_leave();
  }

  std::string name_of(uint64_t user) {
    if (auto handle = client->GetUser(user))
      return handle->DisplayName();
    return "another player";
  }

  void remember(std::string refresh, int32_t expires_in) {
    refresh_token = std::move(refresh);
    refresh_due = refresh_at_ms(now_ms(), expires_in);
  }

  void authorize() {
    auto verifier = client->CreateAuthorizationCodeVerifier();
    discordpp::AuthorizationArgs args{};
    args.SetClientId(application);
    // Communication scopes are required for lobbies and voice; the
    // identify-only login used for account verification is not reused.
    args.SetScopes(discordpp::Client::GetDefaultCommunicationScopes());
    args.SetCodeChallenge(verifier.Challenge());
    std::cout << "Asking Discord for permission. Approve the prompt in "
                 "Discord or your browser, or close it to refuse.\n";
    client->Authorize(args, [this, verifier](discordpp::ClientResult result,
                                             std::string code,
                                             std::string redirect) {
      if (!result.Successful()) {
        std::cout << "Discord permission was not given: " << result.Error()
                  << "\n";
        on(Event::consent_refused);
        return;
      }
      on(Event::consent_granted);
      client->GetToken(
          application, code, verifier.Verifier(), redirect,
          [this](discordpp::ClientResult r, std::string access,
                 std::string refresh, discordpp::AuthorizationTokenType,
                 int32_t expires_in, std::string) {
            if (!r.Successful()) {
              std::cout << "Could not get a Discord token: " << r.Error()
                        << "\n";
              on(Event::token_failed);
              return;
            }
            remember(std::move(refresh), expires_in);
            use_token(access, true);
          });
    });
  }

  void use_token(const std::string &access, bool connect) {
    client->UpdateToken(discordpp::AuthorizationTokenType::Bearer, access,
                        [this, connect](discordpp::ClientResult r) {
                          if (!r.Successful()) {
                            std::cout << "Discord refused the token: "
                                      << r.Error() << "\n";
                            on(Event::token_failed);
                            return;
                          }
                          if (connect) {
                            on(Event::token_ready);
                            std::cout << "Connecting to Discord...\n";
                            client->Connect();
                          } else {
                            std::cout << "Discord token refreshed.\n";
                          }
                        });
  }

  void refresh() {
    if (refreshing || refresh_token.empty() || phase == Phase::leaving ||
        phase == Phase::closed)
      return;
    refreshing = true;
    refresh_wanted = false;
    client->RefreshToken(
        application, refresh_token,
        [this](discordpp::ClientResult r, std::string access,
               std::string next, discordpp::AuthorizationTokenType,
               int32_t expires_in, std::string) {
          refreshing = false;
          if (!r.Successful()) {
            // The call keeps running; only new actions would fail.
            std::cout << "Token refresh failed: " << r.Error()
                      << ". Voice continues; restart the tool if it drops.\n";
            refresh_due = now_ms() + 60000;
            on(Event::token_failed);
            return;
          }
          remember(std::move(next), expires_in);
          use_token(access, false);
        });
  }

  void join() {
    if (lobby_requested)
      return;
    lobby_requested = true;
    std::cout << "Joining the voice lobby...\n";
    client->CreateOrJoinLobby(
        secret, [this](const discordpp::ClientResult &r, uint64_t id) {
          if (phase != Phase::joining) {
            // Quit arrived first: do not stay in a lobby nobody will leave.
            if (r.Successful() && id)
              client->LeaveLobby(id, [](discordpp::ClientResult) {});
            return;
          }
          if (!r.Successful()) {
            std::cout << "Could not join the lobby: " << r.Error() << "\n";
            on(Event::lobby_failed);
            return;
          }
          lobby = id;
          on(Event::lobby_joined);
          start_call();
        });
  }

  void start_call() {
    auto started = client->StartCall(lobby);
    if (!started)
      started = client->GetCall(lobby); // already in this lobby's call
    if (!started) {
      std::cout << "Could not start the voice call.\n";
      on(Event::call_failed);
      return;
    }
    call.emplace(std::move(started));
    call->SetAudioMode(discordpp::AudioModeType::MODE_PTT);
    call->SetPTTReleaseDelay(20);
    call->SetPTTActive(false);
    call->SetStatusChangedCallback(
        [](discordpp::Call::Status status, discordpp::Call::Error error,
           int32_t detail) {
          std::cout << "Call: " << discordpp::Call::StatusToString(status);
          if (error != discordpp::Call::Error::None)
            std::cout << " (" << discordpp::Call::ErrorToString(error) << ", "
                      << detail << ")";
          std::cout << "\n";
        });
    call->SetParticipantChangedCallback([this](uint64_t user, bool added) {
      std::cout << name_of(user) << (added ? " joined" : " left")
                << " the call.\n";
      list_participants();
    });
    call->SetSpeakingStatusChangedCallback(
        [this](uint64_t user, bool speaking) {
          std::cout << "  " << name_of(user)
                    << (speaking ? " is talking" : " stopped") << "\n";
        });
    mic.in_call = true;
    on(Event::call_started);
    std::cout << "In the call. Hold SPACE to talk.\n";
    list_participants();
  }

  void list_participants() {
    if (!call)
      return;
    auto people = call->GetParticipants();
    std::cout << "Participants (" << people.size()
              << "). Press a number to mute or unmute that person for you:\n";
    for (size_t i = 0; i < people.size() && i < 9; ++i)
      std::cout << "  " << (i + 1) << ". " << name_of(people[i]) << "\n";
  }

  std::set<uint64_t> local_muted;
  void toggle_local_mute(size_t index) {
    if (!call)
      return;
    auto people = call->GetParticipants();
    if (index >= people.size())
      return;
    const uint64_t user = people[index];
    const bool mute = local_muted.insert(user).second;
    if (!mute)
      local_muted.erase(user);
    call->SetLocalMute(user, mute);
    std::cout << (mute ? "Muted " : "Unmuted ") << name_of(user)
              << " for you only.\n";
  }

  void cycle_input_device() {
    client->GetInputDevices([this](std::vector<discordpp::AudioDevice> list) {
      if (list.empty()) {
        std::cout << "No microphones found.\n";
        return;
      }
      std::cout << "Microphones:\n";
      for (size_t i = 0; i < list.size(); ++i)
        std::cout << "  " << (i + 1) << ". " << list[i].Name()
                  << (list[i].IsDefault() ? " (default)" : "") << "\n";
      const size_t pick = next_input % list.size();
      next_input = pick + 1;
      const std::string chosen = list[pick].Name();
      client->SetInputDevice(list[pick].Id(),
                             [chosen](discordpp::ClientResult r) {
                               if (r.Successful())
                                 std::cout << "Using microphone: " << chosen
                                           << "\n";
                               else
                                 std::cout << "Could not switch microphone: "
                                           << r.Error() << "\n";
                             });
    });
  }

  void begin_leave() {
    leave_started = now_ms();
    mic.leaving = true;
    apply_microphone();
    std::cout << "Leaving the call...\n";
    client->EndCalls([this]() {
      call.reset();
      mic.in_call = false;
      if (!lobby) {
        on(Event::left);
        return;
      }
      client->LeaveLobby(lobby, [this](discordpp::ClientResult) {
        on(Event::left);
      });
    });
  }

  void apply_microphone() {
    const bool next = transmit(mic);
    if (call && next != transmitting)
      call->SetPTTActive(next);
    if (next != transmitting)
      std::cout << (next ? "[mic ON]\n" : "[mic off]\n");
    transmitting = next && call.has_value();
  }

  std::array<bool, 256> down{};
  void read_console(HANDLE input) {
    DWORD pending = 0;
    while (GetNumberOfConsoleInputEvents(input, &pending) && pending) {
      INPUT_RECORD record{};
      DWORD read = 0;
      if (!ReadConsoleInputW(input, &record, 1, &read) || !read)
        return;
      if (record.EventType == FOCUS_EVENT) {
        ptt.focus(record.Event.FocusEvent.bSetFocus != FALSE);
        continue;
      }
      if (record.EventType != KEY_EVENT)
        continue;
      const auto &key = record.Event.KeyEvent;
      const WORD vk = key.wVirtualKeyCode;
      const bool pressed = key.bKeyDown != FALSE;
      if (vk == ptt_key) {
        ptt.key(pressed);
        continue;
      }
      if (vk >= down.size())
        continue;
      const bool fresh = pressed && !down[vk];
      down[vk] = pressed;
      if (!fresh)
        continue;
      if (vk == 'Q') {
        quit_requested = true;
      } else if (vk == 'M') {
        mic.self_muted = !mic.self_muted;
        client->SetSelfMuteAll(mic.self_muted);
        std::cout << (mic.self_muted ? "You are muted.\n"
                                     : "You are unmuted.\n");
      } else if (vk == 'D') {
        mic.deafened = !mic.deafened;
        client->SetSelfDeafAll(mic.deafened);
        std::cout << (mic.deafened ? "You are deafened.\n"
                                   : "You can hear again.\n");
      } else if (vk == 'I') {
        cycle_input_device();
      } else if (vk == 'P') {
        list_participants();
      } else if (vk >= '1' && vk <= '9') {
        toggle_local_mute(static_cast<size_t>(vk - '1'));
      }
    }
  }
};

void print_help() {
  std::cout << "Civ13 voice prototype (issue #5122, Phase 2)\n"
               "  Hold SPACE  talk (only while this window is focused)\n"
               "  M           mute or unmute yourself\n"
               "  D           deafen or undeafen yourself\n"
               "  I           list microphones and switch to the next one\n"
               "  P           list participants\n"
               "  1-9         mute or unmute a participant for you only\n"
               "  Q           leave the call and quit\n";
}
} // namespace

int main(int argc, char **argv) {
  const auto parsed = parse_arguments(argc, argv);
  if (!parsed) {
    std::cerr << "usage: civ13-voice-proto <application-id> <lobby-secret>\n"
                 "  lobby-secret: 8-64 letters, digits, '-' or '_'; both "
                 "testers use the same one\n";
    return static_cast<int>(Exit::arguments);
  }
  SetConsoleCtrlHandler(on_console_control, TRUE);
  HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
  DWORD original_mode = 0;
  const bool have_console =
      input != INVALID_HANDLE_VALUE && GetConsoleMode(input, &original_mode);
  if (have_console)
    SetConsoleMode(input, ENABLE_PROCESSED_INPUT | ENABLE_EXTENDED_FLAGS);
  print_help();

  App app;
  app.application = parsed->application;
  app.secret = std::string(parsed->secret);
  app.client = std::make_shared<discordpp::Client>();
  app.client->SetApplicationId(app.application);
  app.client->AddLogCallback(
      [](std::string message, discordpp::LoggingSeverity) {
        std::cerr << "[discord] " << message << "\n";
      },
      discordpp::LoggingSeverity::Warning);
  app.client->SetStatusChangedCallback(
      [&app](discordpp::Client::Status status, discordpp::Client::Error error,
             int32_t detail) {
        std::cout << "Discord: " << discordpp::Client::StatusToString(status);
        if (error != discordpp::Client::Error::None)
          std::cout << " (" << discordpp::Client::ErrorToString(error) << ", "
                    << detail << ")";
        std::cout << "\n";
        if (status == discordpp::Client::Status::Ready) {
          if (app.phase == Phase::connecting)
            app.on(Event::client_ready);
          if (app.phase == Phase::joining)
            app.join();
        } else if (status == discordpp::Client::Status::Disconnected &&
                   error != discordpp::Client::Error::None) {
          app.mic.in_call = false;
          app.on(Event::disconnected_error);
        }
      });
  app.client->SetTokenExpirationCallback(
      [&app](discordpp::AuthorizationTokenType) { app.refresh_wanted = true; });
  app.client->SetDeviceChangeCallback(
      [](std::vector<discordpp::AudioDevice> inputs,
         std::vector<discordpp::AudioDevice> outputs) {
        std::cout << "Audio devices changed: " << inputs.size()
                  << " microphones, " << outputs.size()
                  << " outputs. Press I to pick a microphone.\n";
      });
  app.authorize();

  while (!app.exit) {
    discordpp::RunCallbacks();
    if (quit_requested.exchange(false))
      app.on(Event::quit);
    if (have_console)
      app.read_console(input);
    const bool physical = (GetAsyncKeyState(ptt_key) & 0x8000) != 0;
    app.mic.ptt_held = app.ptt.held(physical);
    app.apply_microphone();
    if (app.phase == Phase::in_call &&
        (app.refresh_wanted ||
         (app.refresh_due && now_ms() >= app.refresh_due)))
      app.refresh();
    if (app.phase == Phase::leaving &&
        now_ms() - app.leave_started > leave_timeout_ms) {
      std::cout << "Leave timed out; closing anyway.\n";
      app.exit = Exit::closed;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  if (app.call)
    app.call->SetPTTActive(false);
  app.client->Disconnect();
  for (int i = 0; i < 20; ++i) {
    discordpp::RunCallbacks();
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  app.call.reset();
  app.client.reset();
  if (have_console)
    SetConsoleMode(input, original_mode);
  std::cout << "Exit " << static_cast<int>(*app.exit) << "\n";
  return static_cast<int>(*app.exit);
}
