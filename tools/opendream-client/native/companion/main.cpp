// Private Windows child endpoint for the launcher's social companion.
// Launched only by WindowsCompanionFactory (inactive by default) as
//   civ13-social-companion.exe --social-peer-v1 provider port application
// with the private pipe pair on stdin/stdout and NUL on stderr.
//
// Production activation stays off: the default build answers Hello with an
// unavailable backend and exits. CIV13_COMPANION_LOOPBACK_BACKEND builds a
// vendor-free test child for the Windows integration suite only.
#include "endpoint.hpp"
#include "windows_pipe_io.hpp"

namespace {
std::atomic<bool> cancelled{false};
BOOL WINAPI on_console_event(DWORD) {
  cancelled.store(true);
  return TRUE;
}
#ifdef CIV13_COMPANION_LOOPBACK_BACKEND
// Test-only: accepts start/publish and reports accepted on the next pump.
class LoopbackBackend final : public civ13::social::Backend {
public:
  bool start(uint64_t application) override { return application != 0; }
  bool publish(const civ13::social::Activity &) override {
    pending_ = true;
    return true;
  }
  std::optional<civ13::social::Result> pump() override {
    if (!pending_)
      return std::nullopt;
    pending_ = false;
    return civ13::social::Result::accepted;
  }
  void clear() noexcept override {}
  void stop() noexcept override { pending_ = false; }

private:
  bool pending_ = false;
};
#endif
} // namespace

int main(int argc, char **argv) {
  // No error dialogs, and later DLL loads only from System32 or our own folder.
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX |
               SEM_NOOPENFILEERRORBOX);
  SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_SYSTEM32 |
                           LOAD_LIBRARY_SEARCH_APPLICATION_DIR);
  using civ13::social::Exit;
  const auto profile = civ13::social::parse_arguments(argc, argv);
  if (!profile)
    return int(Exit::arguments);
  auto io = civ13::social::WindowsPipeIo::from_standard_handles();
  if (!io)
    return int(Exit::startup);
  SetConsoleCtrlHandler(on_console_event, TRUE);
  // Backend is declared before run_endpoint's Host so it outlives Peer teardown.
#ifdef CIV13_COMPANION_LOOPBACK_BACKEND
  LoopbackBackend backend;
#else
  civ13::social::UnavailableBackend backend;
#endif
  civ13::social::SteadyClock clock;
  return int(civ13::social::run_endpoint(*profile, backend, *io, clock,
                                         cancelled));
}
