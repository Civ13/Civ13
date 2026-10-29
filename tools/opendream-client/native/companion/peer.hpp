#pragma once
#include <array>
#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <thread>
#include <vector>

namespace civ13::social {
enum class Op : uint8_t {
  hello = 1,
  ready,
  publish,
  result,
  clear,
  pulse,
  stop
};
enum class Result : uint8_t { accepted, unavailable, failed };
struct Profile {
  std::string provider, application;
  uint16_t port{};
};
struct Activity {
  std::string details, state;
};
struct Frame {
  Op op;
  uint64_t id;
  std::vector<uint8_t> payload;
};
std::vector<uint8_t> encode(const Frame &frame);
std::vector<uint8_t> profile_bytes(const Profile &profile);
bool valid_profile(const Profile &profile) noexcept;
bool valid_activity(const Activity &activity) noexcept;
uint64_t application_id(const Profile &profile);

// One SDK instance and its global callback pump belong to one companion owner.
// The host supplies monotonic milliseconds and bounded private-channel I/O.
class Backend {
public:
  virtual ~Backend() = default;
  virtual bool start(uint64_t application) = 0;
  virtual bool publish(const Activity &) = 0;
  virtual std::optional<Result> pump() = 0;
  virtual void clear() noexcept = 0;
  virtual void stop() noexcept = 0;
};
class Peer final {
public:
  Peer(Profile expected, Backend &backend, int64_t now);
  ~Peer();
  Peer(const Peer &) = delete;
  Peer &operator=(const Peer &) = delete;
  void feed(std::span<const uint8_t> bytes, int64_t now);
  void tick(int64_t now);
  void close() noexcept;
  bool closed() const noexcept { return closed_; }
  const std::optional<Frame> &output() const;
  void acknowledge_output();

private:
  void owner() const;
  bool time(int64_t now);
  void accept(Frame frame, int64_t now);
  void queue(Frame frame);
  Profile expected_;
  Backend &backend_;
  const std::thread::id owner_ = std::this_thread::get_id();
  std::array<uint8_t, 276> buffer_{};
  size_t used_ = 0, needed_ = 20;
  int64_t previous_, lease_;
  uint64_t sequence_ = 0, publication_ = 0;
  bool started_ = false, ready_ = false, pending_ = false, closed_ = false;
  std::optional<Frame> output_;
};
} // namespace civ13::social
