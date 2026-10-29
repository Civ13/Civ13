#include "discord_backend.hpp"
#include <atomic>
#include <cdiscord.h>
#include <mutex>
#include <stdexcept>

namespace civ13::social {
namespace {
std::atomic_flag runtime_owned = ATOMIC_FLAG_INIT;
struct RuntimeLease {
  ~RuntimeLease() { runtime_owned.clear(); }
};
} // namespace
struct DiscordBackend::State {
  Discord_Client client{};
  const std::thread::id owner = std::this_thread::get_id();
  bool live = false, busy = false, started = false;
  uint64_t epoch = 0;
  std::optional<Result> result;
  std::mutex gate;
  std::shared_ptr<RuntimeLease> runtime;
  void check() const {
    if (owner != std::this_thread::get_id())
      throw std::logic_error("SDK owner");
  }
  struct Context {
    std::weak_ptr<State> state;
    std::shared_ptr<RuntimeLease> runtime;
    uint64_t epoch;
    bool completed = false;
  };
  Context *slot = nullptr; // Non-owning: only the SDK free callback deletes it.
  static void completed(Discord_ClientResult *value, void *data) noexcept {
    auto &c = *static_cast<Context *>(data);
    // The generated official wrapper adopts this result as Owned.
    auto owned = *value;
    const bool ok = Discord_ClientResult_Successful(&owned);
    Discord_ClientResult_Drop(&owned);
    if (auto s = c.state.lock()) {
      std::lock_guard lock(s->gate);
      if (s->live && s->epoch == c.epoch && !c.completed) {
        c.completed = true;
        s->result = ok ? Result::accepted : Result::failed;
      }
    }
  }
  static void freed(void *data) noexcept {
    auto *c = static_cast<Context *>(data);
    if (auto s = c->state.lock()) {
      std::lock_guard lock(s->gate);
      if (s->slot == c) {
        s->busy = false;
        s->slot = nullptr;
        if (s->live && s->epoch == c->epoch && !c->completed)
          s->result = Result::unavailable;
      }
    }
    delete c;
  }
};
DiscordBackend::DiscordBackend() : state_(std::make_shared<State>()) {}
DiscordBackend::~DiscordBackend() { stop(); }
bool DiscordBackend::start(uint64_t application) {
  auto &s = *state_;
  s.check();
  if (!application || s.started)
    return false;
  if (runtime_owned.test_and_set())
    return false;
  try {
    s.runtime = std::make_shared<RuntimeLease>();
  } catch (...) {
    runtime_owned.clear();
    throw;
  }
  Discord_Client_Init(&s.client);
  if (!s.client.opaque) {
    s.runtime.reset();
    return false;
  }
  s.live = true;
  s.started = true;
  Discord_Client_SetApplicationId(&s.client, application);
  return true;
}
bool DiscordBackend::publish(const Activity &value) {
  auto &s = *state_;
  s.check();
  {
    std::lock_guard lock(s.gate);
    if (!s.live || s.busy || s.result || !valid_activity(value))
      return false;
  }
  struct ActivityScope {
    Discord_Activity value{};
    ActivityScope() { Discord_Activity_Init(&value); }
    ~ActivityScope() {
      if (value.opaque)
        Discord_Activity_Drop(&value);
    }
  } activity;
  if (!activity.value.opaque)
    return false;
  auto *context = new State::Context{state_, s.runtime, s.epoch};
  {
    std::lock_guard lock(s.gate);
    s.busy = true;
    s.slot = context;
  }
  Discord_Activity_SetType(&activity.value, Discord_ActivityTypes_Playing);
  Discord_String details{
      reinterpret_cast<uint8_t *>(const_cast<char *>(value.details.data())),
      value.details.size()};
  Discord_String status{
      reinterpret_cast<uint8_t *>(const_cast<char *>(value.state.data())),
      value.state.size()};
  Discord_Activity_SetDetails(&activity.value, &details);
  Discord_Activity_SetState(&activity.value, &status);
  Discord_Client_UpdateRichPresence(&s.client, &activity.value,
                                    State::completed, State::freed, context);
  return true;
}
std::optional<Result> DiscordBackend::pump() {
  auto &s = *state_;
  s.check();
  if (!s.live)
    return std::nullopt;
  Discord_RunCallbacks();
  std::lock_guard lock(s.gate);
  auto result = s.result;
  s.result.reset();
  return result;
}
void DiscordBackend::clear() noexcept {
  auto &s = *state_;
  if (s.owner != std::this_thread::get_id())
    std::terminate();
  if (!s.live)
    return;
  {
    std::lock_guard lock(s.gate);
    ++s.epoch;
    s.result.reset();
  }
  Discord_Client_ClearRichPresence(&s.client);
  // A cancelled callback still owns userdata until its SDK free callback.
  // Keep busy set; a fresh publication cannot allocate another pending slot.
}
void DiscordBackend::stop() noexcept {
  auto &s = *state_;
  if (s.owner != std::this_thread::get_id())
    std::terminate();
  if (!s.live)
    return;
  {
    std::lock_guard lock(s.gate);
    s.live = false;
    ++s.epoch;
    s.result.reset();
  }
  Discord_Client_ClearRichPresence(&s.client);
  Discord_Client_Drop(&s.client);
  // Deferred userdata keeps the global runtime lease until its free callback.
  s.runtime.reset();
}
} // namespace civ13::social
