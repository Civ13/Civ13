#pragma once
#include "host.hpp"
#include <atomic>
#include <chrono>
#include <cstdint>
#include <optional>

namespace civ13::social {
// Process exit codes for the private child endpoint. The parent treats every
// nonzero code as "social features unavailable"; none of them gates joining.
enum class Exit : int { closed = 0, arguments = 2, startup = 3, fault = 4 };

// Exact launcher contract: `<exe> --social-peer-v1 provider port application`.
// Every value must already satisfy valid_profile. Nothing is defaulted.
std::optional<Profile> parse_arguments(int argc, const char *const *argv);

// Monotonic milliseconds plus a bounded idle between host steps.
class EndpointClock {
public:
  virtual ~EndpointClock() = default;
  virtual int64_t now() = 0;
  virtual void idle(int64_t milliseconds) = 0;
};
class SteadyClock final : public EndpointClock {
public:
  int64_t now() override;
  void idle(int64_t milliseconds) override;

private:
  const std::chrono::steady_clock::time_point start_ =
      std::chrono::steady_clock::now();
};

// Idle between steps while the session is open. Short enough that the 250ms
// write budget and the Pulse lease are observed promptly, long enough that an
// idle companion costs nothing measurable.
inline constexpr int64_t idle_milliseconds = 10;

// Owns one Host for the whole process lifetime on the calling thread. Returns
// once the peer closed (Stop, EOF, lease expiry, malformed input, cancellation,
// I/O failure). The lease guarantees termination while the clock advances.
Exit run_endpoint(const Profile &profile, Backend &backend, PrivatePipeIo &io,
                  EndpointClock &clock, const std::atomic<bool> &cancelled);

// Pipe-end policy for the Windows adapter, kept portable so it is tested
// deterministically. `queried` is whether GetNamedPipeInfo succeeded; when it
// did, `server_end`/`message_mode` come from its flags. Only a write-only
// handle may be accepted when the query was access-denied.
constexpr bool pipe_info_acceptable(bool queried, bool server_end,
                                    bool message_mode, bool access_denied,
                                    bool write_only) noexcept {
  if (queried)
    return !server_end && !message_mode;
  return write_only && access_denied;
}

// Answers start with false: production activation stays off until a reviewed
// SDK-linked build replaces it. Hello is refused and the child exits.
class UnavailableBackend final : public Backend {
public:
  bool start(uint64_t) override { return false; }
  bool publish(const Activity &) override { return false; }
  std::optional<Result> pump() override { return std::nullopt; }
  void clear() noexcept override {}
  void stop() noexcept override {}
};
} // namespace civ13::social
