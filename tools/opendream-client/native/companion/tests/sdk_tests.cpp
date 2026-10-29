// Original in-memory C ABI stand-in. Compile with an external official
// cdiscord.h; no vendor implementation or DLL is linked, loaded or
// redistributed.
#include "../discord_backend.hpp"
#include <cdiscord.h>
#include <iostream>
#include <stdexcept>
using namespace civ13::social;
namespace {
int assertions = 0, clients = 0, activities = 0, results = 0, clears = 0,
    pumps = 0, frees = 0;
uint64_t app = 0;
std::string details, state;
bool successful = true, deliver = false, release = false;
bool fail_client = false, fail_activity = false;
Discord_Client_UpdateRichPresenceCallback callback = nullptr;
Discord_FreeFn free_data = nullptr;
void *data = nullptr;
void check(bool value) {
  ++assertions;
  if (!value)
    throw std::runtime_error("SDK ABI assertion " + std::to_string(assertions));
}
void complete() {
  Discord_ClientResult result{new bool(successful)};
  ++results;
  callback(&result, data);
}
void free_context() {
  auto f = free_data;
  auto d = data;
  data = nullptr;
  callback = nullptr;
  free_data = nullptr;
  f(d);
  ++frees;
}
} // namespace
extern "C" {
void Discord_Client_Init(Discord_Client *self) {
  if (fail_client) {
    self->opaque = nullptr;
    return;
  }
  self->opaque = new int(1);
  ++clients;
}
void Discord_Client_Drop(Discord_Client *self) {
  delete static_cast<int *>(self->opaque);
  self->opaque = nullptr;
  --clients;
}
void Discord_Client_SetApplicationId(Discord_Client *, uint64_t id) {
  app = id;
}
void Discord_Client_ClearRichPresence(Discord_Client *) { ++clears; }
void Discord_Activity_Init(Discord_Activity *self) {
  if (fail_activity) {
    self->opaque = nullptr;
    return;
  }
  self->opaque = new int(1);
  ++activities;
}
void Discord_Activity_Drop(Discord_Activity *self) {
  delete static_cast<int *>(self->opaque);
  --activities;
}
void Discord_Activity_SetType(Discord_Activity *, Discord_ActivityTypes type) {
  check(type == Discord_ActivityTypes_Playing);
}
void Discord_Activity_SetDetails(Discord_Activity *, Discord_String *value) {
  details.assign(reinterpret_cast<char *>(value->ptr), value->size);
}
void Discord_Activity_SetState(Discord_Activity *, Discord_String *value) {
  state.assign(reinterpret_cast<char *>(value->ptr), value->size);
}
bool Discord_ClientResult_Successful(Discord_ClientResult *self) {
  return *static_cast<bool *>(self->opaque);
}
void Discord_ClientResult_Drop(Discord_ClientResult *self) {
  delete static_cast<bool *>(self->opaque);
  self->opaque = nullptr;
  --results;
}
void Discord_Client_UpdateRichPresence(
    Discord_Client *, Discord_Activity *,
    Discord_Client_UpdateRichPresenceCallback cb, Discord_FreeFn f, void *d) {
  check(data == nullptr);
  callback = cb;
  free_data = f;
  data = d;
}
void Discord_RunCallbacks() {
  ++pumps;
  if (deliver && data) {
    deliver = false;
    complete();
  }
  if (release && data) {
    release = false;
    free_context();
  }
}
}
int main() {
  try {
    {
      DiscordBackend sdk;
      check(clients == 0);
      check(!sdk.start(0));
      check(sdk.start(UINT64_MAX));
      check(app == UINT64_MAX);
      DiscordBackend other;
      check(!other.start(42));
      check(sdk.publish({"\xc3\xa9", "playing"}));
      check(activities == 0);
      check(details == "\xc3\xa9");
      check(state == "playing");
      check(!sdk.publish({"another", "pending"}));
      deliver = true;
      check(sdk.pump() == Result::accepted);
      check(results == 0);
      check(!sdk.publish({"held", "free callback"}));
      complete();
      check(!sdk.pump());
      check(results == 0);
      release = true;
      check(!sdk.pump());
      check(frees == 1);
      check(sdk.publish({"new", "S"}));
      successful = false;
      deliver = release = true;
      check(sdk.pump() == Result::failed);
      sdk.clear();
      check(clears == 1);
      sdk.stop();
      check(clients == 0);
      sdk.stop();
      check(clears == 2);
    }
    {
      DiscordBackend sdk;
      check(sdk.start(42));
      check(sdk.publish({"late", "result"}));
      sdk.stop();
      DiscordBackend next;
      check(!next.start(43));
      complete();
      check(!sdk.pump());
      free_context();
      check(results == 0);
      check(next.start(43));
    }
    {
      auto sdk = std::make_unique<DiscordBackend>();
      check(sdk->start(42));
      check(sdk->publish({"destroyed", "owner"}));
      sdk.reset();
      complete();
      free_context();
      check(clients == 0);
      check(results == 0);
      check(activities == 0);
      check(data == nullptr);
    }
    {
      DiscordBackend sdk;
      check(sdk.start(42));
      check(!sdk.publish({"bad\ntext", "S"}));
      bool rejected = false;
      std::thread t([&] {
        try {
          sdk.pump();
        } catch (const std::logic_error &) {
          rejected = true;
        }
      });
      t.join();
      check(rejected);
    }
    {
      DiscordBackend sdk;
      check(sdk.start(42));
      check(sdk.publish({"cancelled", "first"}));
      sdk.clear();
      complete();
      check(!sdk.pump());
      check(!sdk.publish({"held", "userdata"}));
      free_context();
      check(sdk.publish({"fresh", "second"}));
      deliver = release = true;
      check(sdk.pump() == Result::failed);
      sdk.stop();
      check(!sdk.start(42));
      check(data == nullptr);
    }
    {
      DiscordBackend sdk;
      fail_client = true;
      check(!sdk.start(42));
      check(clients == 0);
      fail_client = false;
      check(sdk.start(42));
      fail_activity = true;
      check(!sdk.publish({"missing", "activity"}));
      check(data == nullptr);
      fail_activity = false;
      check(sdk.publish({"cancelled", "without result"}));
      release = true;
      check(sdk.pump() == Result::unavailable);
      check(data == nullptr);
      check(sdk.publish({"background", "callback"}));
      std::thread callback_thread([] { complete(); });
      callback_thread.join();
      sdk.clear();
      check(!sdk.pump());
      std::thread free_thread([] { free_context(); });
      free_thread.join();
      check(sdk.publish({"fresh", "after cleanup"}));
      deliver = release = true;
      check(sdk.pump() == Result::failed);
    }
    check(clients == 0);
    check(activities == 0);
    check(results == 0);
    check(data == nullptr);
    {
      DiscordBackend sdk;
      Profile profile{"Civ13.com", "42", 1714};
      Peer peer(profile, sdk, 0);
      auto wrong = profile_bytes(profile);
      wrong.back() = '3';
      auto bytes = encode({Op::hello, 1, wrong});
      peer.feed(bytes, 0);
      check(peer.closed());
      check(clients == 0);
    }
    {
      DiscordBackend sdk;
      Profile profile{"Civ13.com", "42", 1714};
      Peer peer(profile, sdk, 0);
      auto bytes = encode({Op::hello, 1, profile_bytes(profile)});
      peer.feed(bytes, 0);
      check(clients == 1);
      check(app == 42);
      check(peer.output()->op == Op::ready);
      peer.acknowledge_output();
      bytes = encode({Op::publish, 2, {1, 1, 'D', 'S'}});
      peer.feed(bytes, 0);
      check(details == "D");
      check(state == "S");
      successful = true;
      deliver = release = true;
      peer.tick(1);
      check(peer.output()->op == Op::result);
      check(peer.output()->id == 2);
      check(peer.output()->payload == std::vector<uint8_t>{0});
      peer.acknowledge_output();
      bytes = encode({Op::publish, 3, {1, 1, 'N', 'S'}});
      peer.feed(bytes, 1);
      bytes = encode({Op::clear, 4, {}});
      peer.feed(bytes, 1);
      check(peer.closed());
      check(clients == 0);
      complete();
      free_context();
      check(!peer.output());
      check(results == 0);
      check(data == nullptr);
    }
    std::cout
        << "PASS " << assertions
        << " real-adapter/fake-C-ABI assertions; no vendor DLL or network\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
