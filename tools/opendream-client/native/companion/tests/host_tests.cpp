#include "../host.hpp"
#include <algorithm>
#include <deque>
#include <iostream>
#include <source_location>
#include <stdexcept>
using namespace civ13::social;
namespace {
int assertions = 0;
void check(bool value,
           std::source_location where = std::source_location::current()) {
  ++assertions;
  if (!value)
    throw std::runtime_error("host assertion " + std::to_string(assertions) +
                             " line " + std::to_string(where.line()));
}
struct FakeBackend final : Backend {
  int starts = 0, publishes = 0, stops = 0, clears = 0, pumps = 0;
  bool live = false;
  std::optional<Result> result;
  bool start(uint64_t app) override {
    check(app == 42);
    ++starts;
    live = true;
    return true;
  }
  bool publish(const Activity &) override {
    ++publishes;
    return true;
  }
  std::optional<Result> pump() override {
    ++pumps;
    auto r = result;
    result.reset();
    return r;
  }
  void clear() noexcept override { ++clears; }
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
  int reads = 0, writes = 0, closes = 0, polls = 0;
  size_t chunk = 276;
  bool eof = false, refuse = false, throw_read = false, throw_write = false,
       bad_count = false;
  WriteState state = WriteState::written;
  ReadResult read(std::span<uint8_t> b) override {
    ++reads;
    if (throw_read)
      throw std::runtime_error("injected read");
    if (bad_count)
      return {ReadState::data, b.size() + 1};
    if (eof)
      return {ReadState::eof, 0};
    if (incoming.empty())
      return {ReadState::idle, 0};
    const auto count = std::min({b.size(), chunk, incoming.size()});
    for (size_t i = 0; i < count; ++i) {
      b[i] = incoming.front();
      incoming.pop_front();
    }
    return {ReadState::data, count};
  }
  bool begin_write(std::span<const uint8_t> b) override {
    ++writes;
    if (throw_write)
      throw std::runtime_error("injected write");
    if (refuse)
      return false;
    outgoing.emplace_back(b.begin(), b.end());
    return true;
  }
  WriteState write_state() override {
    ++polls;
    return state;
  }
  void close() noexcept override { ++closes; }
  void send(Frame f) {
    const auto b = encode(f);
    incoming.insert(incoming.end(), b.begin(), b.end());
  }
};
Profile profile() { return {"Civ13.com", "42", 1714}; }
Frame hello() { return {Op::hello, 1, profile_bytes(profile())}; }
Frame publish(uint64_t id = 2) { return {Op::publish, id, {1, 1, 'D', 'S'}}; }
void startup_and_shutdown() {
  FakeBackend sdk;
  FakeIo io;
  Host host(profile(), sdk, io, 0);
  check(sdk.starts == 0 && io.reads == 0 && io.writes == 0);
  io.send(hello());
  host.step(0);
  check(sdk.starts == 1);
  check(io.outgoing.size() == 1);
  check(io.outgoing[0] == encode({Op::ready, 1, hello().payload}));
  io.send(publish());
  host.step(1);
  check(sdk.publishes == 1);
  sdk.result = Result::accepted;
  host.step(2);
  check(io.outgoing.back() == encode({Op::result, 2, {0}}));
  io.send({Op::stop, 3, {}});
  host.step(3);
  check(host.closed());
  check(sdk.stops == 1 && io.closes == 1);
  auto reads = io.reads;
  host.step(4);
  host.close();
  check(io.reads == reads && sdk.stops == 1 && io.closes == 1);
}
void bounded_io() {
  {
    FakeBackend sdk;
    FakeIo io;
    io.chunk = 1;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    check(io.reads == 16 && sdk.starts == 0);
    host.step(1);
    check(io.reads == 32 && sdk.starts == 0);
    host.step(2);
    check(sdk.starts == 1 && io.writes == 1);
  }
  for (bool late_complete : {false, true}) {
    FakeBackend sdk;
    FakeIo io;
    io.state = WriteState::pending;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    check(io.writes == 1);
    io.send({Op::pulse, 2, {}});
    host.step(249);
    check(!host.closed() && io.writes == 1);
    if (late_complete)
      io.state = WriteState::written;
    host.step(250);
    check(host.closed() && io.closes == 1 && sdk.stops == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.state = WriteState::pending;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    io.send(publish());
    host.step(1);
    check(host.closed() && sdk.publishes == 0);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.state = WriteState::pending;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    io.state = WriteState::written;
    host.step(1);
    io.send(publish());
    host.step(2);
    check(!host.closed() && sdk.publishes == 1);
  }
  for (int mode = 0; mode < 4; ++mode) {
    FakeBackend sdk;
    FakeIo io;
    io.send(hello());
    io.refuse = mode == 0;
    io.throw_read = mode == 1;
    io.throw_write = mode == 2;
    io.bad_count = mode == 3;
    Host host(profile(), sdk, io, 0);
    host.step(0);
    check(host.closed() && io.closes == 1);
    auto writes = io.writes;
    host.step(1);
    check(io.writes == writes);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.state = WriteState::failed;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    check(host.closed() && io.closes == 1);
  }
}
void fences_and_identity() {
  for (int mode = 0; mode < 3; ++mode) {
    FakeBackend sdk;
    FakeIo io;
    auto f = hello();
    if (mode == 0)
      f.payload.back() = '3';
    auto b = encode(f);
    if (mode == 1)
      b[4] = 2;
    if (mode == 2)
      b[6] = 1;
    io.incoming.insert(io.incoming.end(), b.begin(), b.end());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    check(host.closed() && sdk.starts == 0 && io.writes == 0 && io.closes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    io.send(publish());
    host.step(1);
    io.send({Op::clear, 3, {}});
    host.step(2);
    sdk.result = Result::accepted;
    host.step(3);
    check(host.closed() && io.writes == 1 && sdk.stops == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    io.send(publish());
    host.step(1);
    sdk.result = Result::accepted;
    io.send({Op::clear, 3, {}});
    host.step(2);
    check(host.closed() && io.writes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    io.send({Op::pulse, 2, {}});
    const auto before = io.reads;
    host.step(5000);
    check(host.closed() && io.reads == before);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    Host host(profile(), sdk, io, 0);
    host.step(3000);
    check(host.closed() && sdk.starts == 0 && io.reads == 0);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    host.step(1, true);
    check(host.closed() && sdk.stops == 1 && io.closes == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    io.send(hello());
    Host host(profile(), sdk, io, 0);
    host.step(0);
    io.eof = true;
    host.step(1);
    check(host.closed() && sdk.stops == 1);
  }
  {
    FakeBackend sdk;
    FakeIo io;
    Host host(profile(), sdk, io, 1);
    host.step(0);
    check(host.closed() && io.reads == 0);
  }
}
} // namespace
int main() {
  try {
    startup_and_shutdown();
    bounded_io();
    fences_and_identity();
    std::cout << "PASS " << assertions
              << " native host assertions; injected I/O, no process/pipe/SDK\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
