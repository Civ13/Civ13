#pragma once
#include "peer.hpp"

namespace civ13::social {
enum class ReadState { idle, data, eof, failed };
enum class WriteState { pending, written, failed };
struct ReadResult {
  ReadState state;
  size_t bytes = 0;
};
class PrivatePipeIo {
public:
  virtual ~PrivatePipeIo() = default;
  // Trusted host adapter: prompt calls, one exclusive channel, bounded buffers.
  virtual ReadResult read(std::span<uint8_t>) = 0;
  // Admit a complete copy or zero bytes. True is admission, not delivery.
  virtual bool begin_write(std::span<const uint8_t>) = 0;
  virtual WriteState write_state() = 0;
  virtual void close() noexcept = 0;
};
// No OS handles, threads, listeners, SDK factory or sleeping loop are created.
// An independent owner calls step with a monotonic clock until closed.
class Host final {
public:
  Host(Profile profile, Backend &backend, PrivatePipeIo &io, int64_t now);
  ~Host();
  Host(const Host &) = delete;
  Host &operator=(const Host &) = delete;
  void step(int64_t now, bool cancelled = false);
  void close() noexcept;
  bool closed() const noexcept { return peer_.closed(); }

private:
  PrivatePipeIo &io_;
  Peer peer_;
  std::array<uint8_t, 276> incoming_{};
  bool io_closed_ = false;
  bool writing_ = false;
  int64_t write_began_ = 0;
};
} // namespace civ13::social
