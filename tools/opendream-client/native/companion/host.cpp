#include "host.hpp"

namespace civ13::social {
Host::Host(Profile profile, Backend &backend, PrivatePipeIo &io, int64_t now)
    : io_(io), peer_(std::move(profile), backend, now) {}
Host::~Host() { close(); }
void Host::close() noexcept {
  peer_.close();
  if (!io_closed_) {
    io_closed_ = true;
    io_.close();
  }
}
void Host::step(int64_t now, bool cancelled) {
  if (closed())
    return;
  if (cancelled) {
    close();
    return;
  }
  try {
    // Tick before accepting new bytes: no input can revive an expired lease.
    peer_.tick(now);
    if (closed()) {
      close();
      return;
    }
    if (writing_ && now - write_began_ >= 250) {
      close();
      return;
    }
    for (int reads = 0; reads < 16 && !closed(); ++reads) {
      const auto result = io_.read(incoming_);
      if (result.bytes > incoming_.size() ||
          (result.state == ReadState::data && result.bytes == 0) ||
          (result.state != ReadState::data && result.bytes != 0)) {
        close();
        return;
      }
      if (result.state == ReadState::idle)
        break;
      if (result.state != ReadState::data) {
        close();
        return;
      }
      peer_.feed(std::span(incoming_).first(result.bytes), now);
    }
    if (!closed() && peer_.output() && !writing_) {
      const auto frame = encode(*peer_.output());
      if (!io_.begin_write(frame)) {
        close();
        return;
      }
      writing_ = true;
      write_began_ = now;
    }
    if (!closed() && writing_) {
      const auto state = io_.write_state();
      if (state == WriteState::written) {
        peer_.acknowledge_output();
        writing_ = false;
      } else if (state != WriteState::pending) {
        close();
        return;
      }
    }
  } catch (...) {
    close();
  }
  if (closed())
    close();
}
} // namespace civ13::social
