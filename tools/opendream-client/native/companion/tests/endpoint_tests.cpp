#include "../endpoint.hpp"
#include <algorithm>
#include <deque>
#include <functional>
#include <iostream>
#include <source_location>
#include <stdexcept>
#include <string>
#include <vector>
using namespace civ13::social;
namespace {
int assertions = 0;
void check(bool value,
           std::source_location where = std::source_location::current()) {
  ++assertions;
  if (!value)
    throw std::runtime_error("endpoint assertion " +
                             std::to_string(assertions) + " line " +
                             std::to_string(where.line()));
}
struct FakeBackend final : Backend {
  int starts = 0, publishes = 0, stops = 0;
  bool live = false, refuse = false;
  std::optional<Result> result;
  bool start(uint64_t app) override {
    check(app == 42);
    ++starts;
    if (refuse)
      return false;
    live = true;
    return true;
  }
  bool publish(const Activity &) override {
    ++publishes;
    result = Result::accepted;
    return true;
  }
  std::optional<Result> pump() override {
    auto r = result;
    result.reset();
    return r;
  }
  void clear() noexcept override {}
  void stop() noexcept override {
    if (live) {
      live = false;
      ++stops;
    }
  }
};
struct FakeIo final : PrivatePipeIo {
  std::deque<uint8_t> incoming;
  std::vector<std::vector<uint8_t>> outgoing;
  int reads = 0, closes = 0;
  size_t chunk = 276;
  bool eof = false, fail = false;
  ReadResult read(std::span<uint8_t> b) override {
    ++reads;
    if (fail)
      return {ReadState::failed, 0};
    if (incoming.empty())
      return {eof ? ReadState::eof : ReadState::idle, 0};
    const auto count = std::min({b.size(), chunk, incoming.size()});
    for (size_t i = 0; i < count; ++i) {
      b[i] = incoming.front();
      incoming.pop_front();
    }
    return {ReadState::data, count};
  }
  bool begin_write(std::span<const uint8_t> b) override {
    outgoing.emplace_back(b.begin(), b.end());
    return true;
  }
  WriteState write_state() override { return WriteState::written; }
  void close() noexcept override { ++closes; }
  void send(Frame f) {
    const auto b = encode(f);
    incoming.insert(incoming.end(), b.begin(), b.end());
  }
};
// Advances by exactly the requested idle; a hook observes each idle.
struct FakeClock final : EndpointClock {
  int64_t time = 0;
  int idles = 0;
  bool throw_now = false;
  std::function<void(FakeClock &)> hook;
  int64_t now() override {
    if (throw_now)
      throw std::runtime_error("injected clock");
    return time;
  }
  void idle(int64_t ms) override {
    if (ms != idle_milliseconds || ++idles >= 100000) // Termination bound.
      throw std::runtime_error("unbounded endpoint idle");
    time += ms;
    if (hook)
      hook(*this);
  }
};
Profile profile() { return {"Civ13.com", "42", 1714}; }
Frame hello() { return {Op::hello, 1, profile_bytes(profile())}; }
std::optional<Profile> parse(std::vector<const char *> args) {
  return parse_arguments(int(args.size()), args.data());
}
void arguments() {
  auto ok = parse({"c.exe", "--social-peer-v1", "Civ13.com", "1714", "42"});
  check(ok && ok->provider == "Civ13.com" && ok->port == 1714 &&
        ok->application == "42");
  ok = parse({"c.exe", "--social-peer-v1", "ValZarGaming", "1715",
              "18446744073709551615"});
  check(ok && ok->port == 1715);
  const std::vector<std::vector<const char *>> bad = {
      {},
      {"c.exe"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714", "42", "extra"},
      {"c.exe", "--social-peer-v2", "Civ13.com", "1714", "42"},
      {"c.exe", "--SOCIAL-PEER-V1", "Civ13.com", "1714", "42"},
      {"c.exe", "--social-peer-v1", "civ13.com", "1714", "42"},
      {"c.exe", "--social-peer-v1", "Other", "1714", "42"},
      {"c.exe", "--social-peer-v1", "", "1714", "42"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1716", "42"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "01714", "42"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "+1714", "42"},
      {"c.exe", "--social-peer-v1", "Civ13.com", " 1714", "42"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714", "0"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714", "042"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714", "-42"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714", "4 2"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714",
       "18446744073709551616"},
      {"c.exe", "--social-peer-v1", "Civ13.com", "1714",
       "1111111111111111111111111111111111111"},
      {"c.exe", nullptr, "Civ13.com", "1714", "42"},
      {"c.exe", "--social-peer-v1", "Civ13.com", nullptr, "42"},
  };
  for (const auto &args : bad)
    check(!parse(args));
  check(!parse_arguments(5, nullptr));
}
void full_session() {
  FakeBackend sdk;
  FakeIo io;
  FakeClock clock;
  io.send(hello());
  int stage = 0;
  clock.hook = [&](FakeClock &c) {
    if (stage == 0 && io.outgoing.size() == 1) {
      check(io.outgoing[0] == encode({Op::ready, 1, hello().payload}));
      io.send({Op::publish, 2, {1, 1, 'D', 'S'}});
      stage = 1;
    } else if (stage == 1 && io.outgoing.size() == 2) {
      check(io.outgoing[1] == encode({Op::result, 2, {0}}));
      stage = 2;
    } else if (stage == 2 && c.time >= 4000) {
      io.send({Op::pulse, 3, {}}); // Keeps the lease past five seconds.
      stage = 3;
    } else if (stage == 3 && c.time >= 8000) {
      io.send({Op::stop, 4, {}});
      stage = 4;
    }
  };
  check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
        Exit::closed);
  check(stage == 4 && clock.time >= 8000 && clock.time < 9000);
  check(sdk.starts == 1 && sdk.publishes == 1 && sdk.stops == 1);
  check(io.closes == 1);
}
void lease_expiry() {
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::closed);
    check(clock.time == 3000 && sdk.starts == 0 && io.closes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    io.send(hello());
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::closed);
    check(clock.time == 5000 && sdk.starts == 1 && sdk.stops == 1);
    check(io.outgoing.size() == 1 && io.closes == 1);
  }
}
void endings() {
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    io.send(hello());
    io.eof = true;
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::closed);
    check(clock.time < 100 && sdk.stops == 1 && io.closes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    io.fail = true;
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::closed);
    check(clock.time == 0 && io.closes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    std::atomic<bool> cancelled{false};
    io.send(hello());
    clock.hook = [&](FakeClock &c) {
      if (c.time == 500)
        cancelled.store(true);
    };
    check(run_endpoint(profile(), sdk, io, clock, cancelled) == Exit::closed);
    check(clock.time == 500 && sdk.stops == 1 && io.closes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    io.chunk = 1; // Fragmented input still negotiates within the budget.
    io.send(hello());
    clock.hook = [&](FakeClock &c) {
      if (io.outgoing.size() == 1 && c.time < 1000)
        io.send({Op::stop, 2, {}});
    };
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::closed);
    check(sdk.starts == 1 && io.outgoing.size() == 1 && clock.time < 1000);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    io.send(hello());
    clock.hook = [&](FakeClock &c) {
      if (c.time == 100)
        c.time = 50; // Clock reversal terminates instead of extending a lease.
    };
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::closed);
    check(clock.time == 50 && sdk.stops == 1 && io.closes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    clock.throw_now = true;
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::fault);
    check(io.closes == 1 && sdk.starts == 0);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    io.send(hello());
    clock.hook = [&](FakeClock &c) { c.throw_now = c.time >= 30; };
    check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
          Exit::fault);
    check(io.closes == 1 && sdk.stops == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    FakeClock clock;
    check(run_endpoint({"Other", "42", 1714}, sdk, io, clock,
                       std::atomic<bool>{false}) == Exit::fault);
    check(io.closes == 1 && clock.idles == 0);
  }
}
void production_backend_is_off() {
  UnavailableBackend sdk;
  FakeIo io;
  FakeClock clock;
  io.send(hello());
  check(run_endpoint(profile(), sdk, io, clock, std::atomic<bool>{false}) ==
        Exit::closed);
  check(io.outgoing.empty() && io.closes == 1 && clock.time == 0);
  FakeBackend refusing;
  refusing.refuse = true;
  FakeIo second;
  FakeClock other;
  second.send(hello());
  check(run_endpoint(profile(), refusing, second, other,
                     std::atomic<bool>{false}) == Exit::closed);
  check(second.outgoing.empty() && refusing.starts == 1);
}
void steady_clock() {
  SteadyClock clock;
  const auto first = clock.now();
  clock.idle(1);
  check(first >= 0 && clock.now() >= first);
}
} // namespace
int main() {
  try {
    arguments();
    full_session();
    lease_expiry();
    endings();
    production_backend_is_off();
    steady_clock();
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
  std::cout << "endpoint tests passed: " << assertions << " assertions\n";
  return 0;
}
