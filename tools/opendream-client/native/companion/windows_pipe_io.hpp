#pragma once
#ifndef _WIN32
#error "windows_pipe_io is the Windows child endpoint adapter."
#endif
#include "host.hpp"
#include <memory>
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

namespace civ13::social {
// Child side of the launcher's private pipe pair. The parent passes the client
// ends of two current-user, overlapped, single-instance local pipes as standard
// input/output (WindowsCompanionPlatform). This adapter never opens a pipe by
// name, never listens and never touches any other handle.
class WindowsPipeIo final : public PrivatePipeIo {
public:
  // Null unless stdin/stdout are distinct overlapped client pipe ends.
  static std::unique_ptr<WindowsPipeIo> from_standard_handles();
  // Takes ownership of both handles; both must already be validated.
  WindowsPipeIo(HANDLE input, HANDLE output);
  ~WindowsPipeIo() override;
  WindowsPipeIo(const WindowsPipeIo &) = delete;
  WindowsPipeIo &operator=(const WindowsPipeIo &) = delete;
  ReadResult read(std::span<uint8_t>) override;
  bool begin_write(std::span<const uint8_t>) override;
  WriteState write_state() override;
  void close() noexcept override;
  bool valid() const noexcept { return read_event_ && write_event_; }

private:
  void settle(HANDLE handle, OVERLAPPED &operation, bool &pending) noexcept;
  HANDLE input_, output_;
  HANDLE read_event_ = nullptr, write_event_ = nullptr;
  OVERLAPPED read_{}, write_{};
  std::array<uint8_t, 276> read_buffer_{}, write_buffer_{};
  DWORD write_size_ = 0;
  bool reading_ = false, writing_ = false, closed_ = false;
};
// True when the handle is a client-end byte pipe opened for overlapped I/O.
bool overlapped_client_pipe(HANDLE handle) noexcept;
} // namespace civ13::social
