#include "../peer.hpp"
#include <iostream>
#include <source_location>
#include <stdexcept>
#include <thread>
using namespace civ13::social;
namespace {
int assertions = 0;
void check(bool value,
           std::source_location at = std::source_location::current()) {
  ++assertions;
  if (!value)
    throw std::runtime_error("native peer assertion " +
                             std::to_string(assertions) + " at line " +
                             std::to_string(at.line()));
}
struct Fake final : Backend {
  int starts = 0, publishes = 0, clears = 0, stops = 0, pumps = 0;
  uint64_t application = 0;
  Activity activity;
  bool available = true, live = false;
  std::optional<Result> result;
  bool start(uint64_t id) override {
    ++starts;
    application = id;
    live = available;
    return available;
  }
  bool publish(const Activity &a) override {
    ++publishes;
    activity = a;
    return available;
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
      ++stops;
      live = false;
    }
  }
};
Profile profile() { return {"ValZarGaming", "18446744073709551615", 1714}; }
Frame hello(uint64_t id = 1) {
  return {Op::hello, id, profile_bytes(profile())};
}
Frame publish(uint64_t id = 2) { return {Op::publish, id, {1, 1, 'D', 'S'}}; }
void send(Peer &p, Frame f, int64_t now = 0) {
  auto b = encode(f);
  p.feed(b, now);
}
void ready(Peer &p) {
  send(p, hello());
  check(p.output().has_value());
  check(p.output()->op == Op::ready);
  check(p.output()->payload == hello().payload);
  p.acknowledge_output();
}
void profiles_and_text() {
  check(application_id(profile()) == UINT64_MAX);
  for (auto s : {"", "0", "00", "01", "+1", "1.0", "1e3", " 1",
                 "18446744073709551616"}) {
    auto v = profile();
    v.application = s;
    check(!valid_profile(v));
  }
  for (auto host : {"Civ13.com", "ValZarGaming"})
    for (uint16_t port : {uint16_t(1714), uint16_t(1715)})
      check(valid_profile({host, "42", port}));
  check(!valid_profile({"other", "42", 1714}));
  check(!valid_profile({"Civ13.com", "42", 1716}));
  check(valid_activity({"Civ13", "playing"}));
  check(valid_activity({"\xc3\xa9", "\xf0\x9f\x8c\x8d"}));
  for (auto s : {std::string(), std::string(97, 'a'), std::string("\xc0\xaf"),
                 std::string("\xed\xa0\x80"), std::string("\xf4\x90\x80\x80"),
                 std::string("\xe2\x82"), std::string("\xc2\x85"),
                 std::string("a\nb"), std::string("a\0b", 3)})
    check(!valid_activity({s, "S"}));
  check(valid_activity({std::string(96, 'a'), std::string(96, 's')}));
}
void framing() {
  auto stop = encode({Op::stop, 1, {}});
  const std::vector<uint8_t> golden{'C', '1', '3', 'S', 1, 7, 0, 0, 1, 0,
                                    0,   0,   0,   0,   0, 0, 0, 0, 0, 0};
  check(stop == golden);
  auto h = encode(hello());
  for (size_t cut = 0; cut <= h.size(); ++cut) {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    p.feed(std::span(h).first(cut), 0);
    p.feed(std::span(h).subspan(cut), 0);
    check(!p.closed());
    check(sdk.starts == 1);
    check(p.output()->payload == hello().payload);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    for (auto b : h)
      p.feed(std::span(&b, 1), 0);
    check(sdk.starts == 1);
    check(p.output()->op == Op::ready);
  }
  for (size_t at : {size_t(0), size_t(4), size_t(5), size_t(6), size_t(7),
                    size_t(8), size_t(16), size_t(17)}) {
    auto bad = h;
    bad[at] = at == 5                 ? uint8_t(9)
              : (at == 8 || at == 16) ? uint8_t(0)
                                      : uint8_t(bad[at] + 1);
    if (at == 17)
      bad[at] = 2;
    Fake sdk;
    Peer p(profile(), sdk, 0);
    p.feed(bad, 0);
    check(p.closed());
    check(sdk.starts == 0);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    std::vector<uint8_t> big(277);
    p.feed(big, 0);
    check(p.closed());
    check(sdk.starts == 0);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    auto f = hello();
    f.payload.back() = '4';
    send(p, f);
    check(p.closed());
    check(sdk.starts == 0);
  }
}
void lifecycle() {
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, publish());
    check(sdk.publishes == 1);
    check(sdk.activity.details == "D");
    sdk.result = Result::accepted;
    p.tick(1);
    check(p.output()->id == 2);
    check(p.output()->payload == std::vector<uint8_t>{0});
    p.acknowledge_output();
    send(p, {Op::clear, 3, {}}, 1);
    check(sdk.clears == 1);
    send(p, publish(4), 1);
    check(sdk.publishes == 2);
    send(p, {Op::stop, 5, {}}, 1);
    check(p.closed());
    check(sdk.stops == 1);
    p.close();
    check(sdk.stops == 1);
  }
  for (auto result : {Result::unavailable, Result::failed}) {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, publish());
    sdk.result = result;
    p.tick(1);
    check(p.output()->payload == std::vector<uint8_t>{uint8_t(result)});
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    send(p, hello());
    send(p, {Op::clear, 2, {}});
    check(sdk.publishes == 0);
    check(sdk.clears == 1);
    p.acknowledge_output();
    send(p, publish(3));
    check(sdk.publishes == 1);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, publish());
    send(p, {Op::clear, 3, {}});
    check(p.closed());
    sdk.result = Result::accepted;
    p.tick(1);
    check(!p.output());
    check(sdk.stops == 1);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, publish());
    sdk.result = Result::accepted;
    p.tick(1);
    send(p, {Op::clear, 3, {}}, 1);
    check(p.closed());
    check(!p.output());
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    send(p, hello());
    send(p, publish());
    check(p.closed());
    check(sdk.publishes == 0);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, publish());
    send(p, publish(3));
    check(p.closed());
    check(sdk.publishes == 1);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, {Op::pulse, 1, {}});
    check(p.closed());
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, hello(2));
    check(p.closed());
    check(sdk.starts == 1);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, {Op::ready, 2, {}});
    check(p.closed());
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, {Op::pulse, 2, {1}});
    check(p.closed());
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    auto f = publish();
    f.payload[0] = 96;
    send(p, f);
    check(p.closed());
    check(sdk.publishes == 0);
  }
  {
    Fake sdk;
    sdk.available = false;
    Peer p(profile(), sdk, 0);
    send(p, hello());
    check(p.closed());
    check(!p.output());
  }
}
void clocks_and_owner() {
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    p.tick(2999);
    check(!p.closed());
    p.tick(3000);
    check(p.closed());
    check(sdk.starts == 0);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    p.tick(4999);
    check(!p.closed());
    p.tick(5000);
    check(p.closed());
    check(sdk.stops == 1);
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    ready(p);
    send(p, {Op::pulse, 2, {}}, 4999);
    p.tick(9998);
    check(!p.closed());
    p.tick(9999);
    check(p.closed());
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 10);
    p.tick(9);
    check(p.closed());
  }
  {
    Fake sdk;
    Peer p(profile(), sdk, 0);
    bool rejected = false;
    std::thread t([&] {
      try {
        p.tick(0);
      } catch (const std::logic_error &) {
        rejected = true;
      }
    });
    t.join();
    check(rejected);
    check(sdk.starts == 0);
  }
}
} // namespace
int main() {
  try {
    profiles_and_text();
    framing();
    lifecycle();
    clocks_and_owner();
    std::cout << "PASS " << assertions
              << " native peer assertions; fake backend, no SDK or I/O\n";
    return 0;
  } catch (const std::exception &e) {
    std::cerr << e.what() << '\n';
    return 1;
  }
}
