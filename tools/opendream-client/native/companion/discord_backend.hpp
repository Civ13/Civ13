#pragma once
#include "peer.hpp"
#include <memory>
namespace civ13::social {
// SDK headers and binaries are external inputs. Construction itself is inert.
class DiscordBackend final : public Backend {
public:
  DiscordBackend();
  ~DiscordBackend() override;
  bool start(uint64_t application) override;
  bool publish(const Activity &) override;
  std::optional<Result> pump() override;
  void clear() noexcept override;
  void stop() noexcept override;

private:
  struct State;
  std::shared_ptr<State> state_;
};
} // namespace civ13::social
