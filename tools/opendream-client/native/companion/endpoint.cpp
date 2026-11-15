#include "endpoint.hpp"
#include <string_view>
#include <thread>

namespace civ13::social {
namespace {
bool bounded(const char *value, size_t limit) {
  if (!value)
    return false;
  for (size_t i = 0; i <= limit; ++i)
    if (value[i] == '\0')
      return i > 0;
  return false;
}
} // namespace
std::optional<Profile> parse_arguments(int argc, const char *const *argv) {
  if (argc != 5 || !argv)
    return std::nullopt;
  for (int i = 1; i < 5; ++i)
    if (!bounded(argv[i], 32))
      return std::nullopt;
  if (std::string_view(argv[1]) != "--social-peer-v1")
    return std::nullopt;
  const std::string_view port(argv[3]);
  uint16_t number = 0;
  if (port == "1714")
    number = 1714;
  else if (port == "1715")
    number = 1715;
  else
    return std::nullopt;
  Profile profile{argv[2], argv[4], number};
  if (!valid_profile(profile))
    return std::nullopt;
  return profile;
}
int64_t SteadyClock::now() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now() - start_)
      .count();
}
void SteadyClock::idle(int64_t milliseconds) {
  std::this_thread::sleep_for(std::chrono::milliseconds(milliseconds));
}
Exit run_endpoint(const Profile &profile, Backend &backend, PrivatePipeIo &io,
                  EndpointClock &clock, const std::atomic<bool> &cancelled) {
  int64_t start = 0;
  try {
    start = clock.now();
  } catch (...) {
    io.close();
    return Exit::fault;
  }
  if (start < 0 || !valid_profile(profile)) {
    io.close();
    return Exit::fault;
  }
  Host host(profile, backend, io, start);
  try {
    while (!host.closed()) {
      host.step(clock.now(), cancelled.load(std::memory_order_relaxed));
      if (!host.closed())
        clock.idle(idle_milliseconds);
    }
  } catch (...) {
    host.close();
    return Exit::fault;
  }
  host.close();
  return Exit::closed;
}
} // namespace civ13::social
