#include "peer.hpp"
#include <algorithm>
#include <limits>
#include <stdexcept>

namespace civ13::social {
namespace {
uint64_t little(std::span<const uint8_t> b) {
  uint64_t n = 0;
  for (size_t i = 0; i < b.size(); ++i)
    n |= uint64_t(b[i]) << (8 * i);
  return n;
}
void put(std::vector<uint8_t> &b, size_t at, uint64_t n, size_t size) {
  for (size_t i = 0; i < size; ++i)
    b[at + i] = uint8_t(n >> (8 * i));
}
bool text(const std::string &s) noexcept {
  if (s.empty() || s.size() > 96)
    return false;
  for (size_t i = 0; i < s.size();) {
    auto c = uint8_t(s[i++]);
    uint32_t cp = c;
    size_t more = 0;
    uint32_t minimum = 0;
    if (c >= 0xc2 && c <= 0xdf) {
      cp = c & 31;
      more = 1;
      minimum = 0x80;
    } else if (c >= 0xe0 && c <= 0xef) {
      cp = c & 15;
      more = 2;
      minimum = 0x800;
    } else if (c >= 0xf0 && c <= 0xf4) {
      cp = c & 7;
      more = 3;
      minimum = 0x10000;
    } else if (c >= 0x80)
      return false;
    if (i + more > s.size())
      return false;
    for (size_t j = 0; j < more; ++j) {
      auto d = uint8_t(s[i++]);
      if ((d & 0xc0) != 0x80)
        return false;
      cp = (cp << 6) | (d & 63);
    }
    if (cp < minimum || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff) ||
        cp <= 31 || (cp >= 127 && cp <= 159))
      return false;
  }
  return true;
}
} // namespace
uint64_t application_id(const Profile &p) {
  if (p.application.empty() || p.application.size() > 20 ||
      p.application[0] == '0')
    throw std::invalid_argument("application");
  uint64_t n = 0;
  for (char c : p.application) {
    if (c < '0' || c > '9' ||
        n > (std::numeric_limits<uint64_t>::max() - uint64_t(c - '0')) / 10)
      throw std::invalid_argument("application");
    n = n * 10 + uint64_t(c - '0');
  }
  return n;
}
bool valid_profile(const Profile &p) noexcept {
  try {
    return (p.provider == "Civ13.com" || p.provider == "ValZarGaming") &&
           (p.port == 1714 || p.port == 1715) && application_id(p) != 0;
  } catch (...) {
    return false;
  }
}
bool valid_activity(const Activity &a) noexcept {
  return text(a.details) && text(a.state);
}
std::vector<uint8_t> profile_bytes(const Profile &p) {
  if (!valid_profile(p))
    throw std::invalid_argument("profile");
  std::vector<uint8_t> b(4 + p.provider.size() + p.application.size());
  put(b, 0, p.port, 2);
  b[2] = uint8_t(p.provider.size());
  b[3] = uint8_t(p.application.size());
  std::copy(p.provider.begin(), p.provider.end(), b.begin() + 4);
  std::copy(p.application.begin(), p.application.end(),
            b.begin() + 4 + p.provider.size());
  return b;
}
std::vector<uint8_t> encode(const Frame &f) {
  if (f.id == 0 || f.payload.size() > 256 || uint8_t(f.op) < 1 ||
      uint8_t(f.op) > 7)
    throw std::invalid_argument("frame");
  std::vector<uint8_t> b(20 + f.payload.size());
  b[0] = 'C';
  b[1] = '1';
  b[2] = '3';
  b[3] = 'S';
  b[4] = 1;
  b[5] = uint8_t(f.op);
  put(b, 8, f.id, 8);
  put(b, 16, f.payload.size(), 4);
  std::copy(f.payload.begin(), f.payload.end(), b.begin() + 20);
  return b;
}
Peer::Peer(Profile p, Backend &backend, int64_t now)
    : expected_(std::move(p)), backend_(backend), previous_(now), lease_(now) {
  if (now < 0 || !valid_profile(expected_))
    throw std::invalid_argument("profile/clock");
}
Peer::~Peer() { close(); }
void Peer::owner() const {
  if (std::this_thread::get_id() != owner_)
    throw std::logic_error("peer owner");
}
bool Peer::time(int64_t now) {
  if (closed_)
    return false;
  if (now < previous_ || now - lease_ >= (started_ ? 5000 : 3000)) {
    close();
    return false;
  }
  previous_ = now;
  return true;
}
void Peer::queue(Frame f) {
  if (output_) {
    close();
    return;
  }
  output_ = std::move(f);
}
void Peer::feed(std::span<const uint8_t> bytes, int64_t now) {
  owner();
  if (!time(now))
    return;
  if (bytes.size() > 276) {
    close();
    return;
  }
  try {
    while (!bytes.empty() && !closed_) {
      auto count = std::min(needed_ - used_, bytes.size());
      std::copy_n(bytes.begin(), count, buffer_.begin() + used_);
      used_ += count;
      bytes = bytes.subspan(count);
      if (used_ < needed_)
        continue;
      auto b = std::span<const uint8_t>(buffer_);
      if (b[0] != 'C' || b[1] != '1' || b[2] != '3' || b[3] != 'S' ||
          b[4] != 1 || b[5] < 1 || b[5] > 7 || b[6] || b[7] ||
          little(b.subspan(8, 8)) == 0 || little(b.subspan(16, 4)) > 256) {
        close();
        return;
      }
      needed_ = 20 + size_t(little(b.subspan(16, 4)));
      if (used_ < needed_)
        continue;
      Frame f{Op(b[5]),
              little(b.subspan(8, 8)),
              {b.begin() + 20, b.begin() + needed_}};
      used_ = 0;
      needed_ = 20;
      accept(std::move(f), now);
    }
  } catch (...) {
    close();
  }
}
void Peer::accept(Frame f, int64_t now) {
  if (f.id <= sequence_) {
    close();
    return;
  }
  sequence_ = f.id;
  if (!started_) {
    if (f.op != Op::hello || f.payload != profile_bytes(expected_)) {
      close();
      return;
    }
    started_ = true;
    lease_ = now;
    if (!backend_.start(application_id(expected_))) {
      close();
      return;
    }
    queue({Op::ready, f.id, std::move(f.payload)});
    return;
  }
  if (f.op == Op::publish) {
    if (!ready_ || pending_ || output_ || f.payload.size() < 4) {
      close();
      return;
    }
    size_t a = f.payload[0], b = f.payload[1];
    if (a + b + 2 != f.payload.size()) {
      close();
      return;
    }
    Activity value{
        std::string(f.payload.begin() + 2, f.payload.begin() + 2 + a),
        std::string(f.payload.begin() + 2 + a, f.payload.end())};
    if (!valid_activity(value)) {
      close();
      return;
    }
    pending_ = true;
    publication_ = f.id;
    if (!backend_.publish(value))
      close();
  } else if (f.op == Op::clear && f.payload.empty()) {
    if (pending_ || (output_ && output_->op == Op::result)) {
      close();
      return;
    }
    backend_.clear();
  } else if (f.op == Op::pulse && f.payload.empty())
    lease_ = now;
  else if (f.op == Op::stop && f.payload.empty())
    close();
  else
    close();
}
void Peer::tick(int64_t now) {
  owner();
  if (!time(now) || !started_)
    return;
  try {
    if (auto result = backend_.pump()) {
      if (!pending_) {
        close();
        return;
      }
      pending_ = false;
      queue({Op::result, publication_, {uint8_t(*result)}});
    }
  } catch (...) {
    close();
  }
}
const std::optional<Frame> &Peer::output() const {
  owner();
  return output_;
}
void Peer::acknowledge_output() {
  owner();
  if (output_ && output_->op == Op::ready)
    ready_ = true;
  output_.reset();
}
void Peer::close() noexcept {
  if (std::this_thread::get_id() != owner_)
    std::terminate();
  if (closed_)
    return;
  closed_ = true;
  output_.reset();
  pending_ = false;
  used_ = 0;
  backend_.stop();
}
} // namespace civ13::social
