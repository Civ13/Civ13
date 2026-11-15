#include "windows_pipe_io.hpp"
#include <algorithm>
#include <winternl.h>

namespace civ13::social {
namespace {
using QueryFile = LONG(NTAPI *)(HANDLE, IO_STATUS_BLOCK *, PVOID, ULONG, int);
constexpr int file_mode_information = 16;
constexpr ULONG synchronous_io = 0x10 | 0x20; // FILE_SYNCHRONOUS_IO_(NON)ALERT
bool end_of_stream(DWORD error) noexcept {
  return error == ERROR_BROKEN_PIPE || error == ERROR_HANDLE_EOF ||
         error == ERROR_PIPE_NOT_CONNECTED || error == ERROR_NO_DATA;
}
} // namespace
bool overlapped_client_pipe(HANDLE handle, bool write_only) noexcept {
  if (!handle || handle == INVALID_HANDLE_VALUE ||
      GetFileType(handle) != FILE_TYPE_PIPE)
    return false;
  // GetNamedPipeInfo needs FILE_READ_ATTRIBUTES, which a write-only client
  // end may not carry; access denied leaves only the end/type check unproven.
  DWORD flags = 0;
  const bool queried =
      GetNamedPipeInfo(handle, &flags, nullptr, nullptr, nullptr) != FALSE;
  const bool denied = !queried && GetLastError() == ERROR_ACCESS_DENIED;
  if (!pipe_info_acceptable(queried, (flags & PIPE_SERVER_END) != 0,
                            (flags & PIPE_TYPE_MESSAGE) != 0, denied,
                            write_only))
    return false;
  // A synchronous handle would turn an "overlapped" read into a blocking wait
  // that stops the lease clock, so it is refused rather than tolerated.
  const auto ntdll = GetModuleHandleW(L"ntdll.dll");
  if (!ntdll)
    return false;
  const auto query = reinterpret_cast<QueryFile>(
      reinterpret_cast<void *>(GetProcAddress(ntdll, "NtQueryInformationFile")));
  if (!query)
    return false;
  IO_STATUS_BLOCK status{};
  ULONG mode = 0;
  if (query(handle, &status, &mode, sizeof(mode), file_mode_information) != 0)
    return false;
  return (mode & synchronous_io) == 0;
}
std::unique_ptr<WindowsPipeIo> WindowsPipeIo::from_standard_handles() {
  const HANDLE input = GetStdHandle(STD_INPUT_HANDLE);
  const HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
  if (input == output || !overlapped_client_pipe(input, false) ||
      !overlapped_client_pipe(output, true))
    return nullptr;
  // Detach from the standard slots so nothing else (CRT, SDK logging) can
  // write protocol bytes or close the channel behind the host.
  SetStdHandle(STD_INPUT_HANDLE, nullptr);
  SetStdHandle(STD_OUTPUT_HANDLE, nullptr);
  auto io = std::make_unique<WindowsPipeIo>(input, output);
  if (!io->valid())
    return nullptr;
  return io;
}
WindowsPipeIo::WindowsPipeIo(HANDLE input, HANDLE output)
    : input_(input), output_(output) {
  read_event_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  write_event_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  read_.hEvent = read_event_;
  write_.hEvent = write_event_;
  if (!valid())
    close();
}
WindowsPipeIo::~WindowsPipeIo() { close(); }
ReadResult WindowsPipeIo::read(std::span<uint8_t> buffer) {
  if (closed_ || buffer.empty())
    return {ReadState::failed, 0};
  if (!reading_) {
    ResetEvent(read_event_);
    const auto request = DWORD(std::min(buffer.size(), read_buffer_.size()));
    if (!ReadFile(input_, read_buffer_.data(), request, nullptr, &read_)) {
      const auto error = GetLastError();
      if (end_of_stream(error))
        return {ReadState::eof, 0};
      if (error != ERROR_IO_PENDING)
        return {ReadState::failed, 0};
    }
    reading_ = true;
  }
  DWORD count = 0;
  if (!GetOverlappedResult(input_, &read_, &count, FALSE)) {
    const auto error = GetLastError();
    if (error == ERROR_IO_INCOMPLETE)
      return {ReadState::idle, 0};
    reading_ = false;
    return {end_of_stream(error) ? ReadState::eof : ReadState::failed, 0};
  }
  reading_ = false;
  if (count == 0) // Zero-byte writes carry no protocol data.
    return {ReadState::idle, 0};
  if (count > buffer.size())
    return {ReadState::failed, 0};
  std::copy_n(read_buffer_.begin(), count, buffer.begin());
  return {ReadState::data, count};
}
bool WindowsPipeIo::begin_write(std::span<const uint8_t> frame) {
  if (closed_ || writing_ || frame.empty() || frame.size() > write_buffer_.size())
    return false;
  std::copy(frame.begin(), frame.end(), write_buffer_.begin());
  write_size_ = DWORD(frame.size());
  ResetEvent(write_event_);
  if (!WriteFile(output_, write_buffer_.data(), write_size_, nullptr, &write_) &&
      GetLastError() != ERROR_IO_PENDING)
    return false;
  writing_ = true;
  return true;
}
WriteState WindowsPipeIo::write_state() {
  if (closed_ || !writing_)
    return WriteState::failed;
  DWORD count = 0;
  if (!GetOverlappedResult(output_, &write_, &count, FALSE)) {
    if (GetLastError() == ERROR_IO_INCOMPLETE)
      return WriteState::pending;
    writing_ = false;
    return WriteState::failed;
  }
  writing_ = false;
  return count == write_size_ ? WriteState::written : WriteState::failed;
}
void WindowsPipeIo::settle(HANDLE handle, OVERLAPPED &operation,
                           bool &pending) noexcept {
  if (!pending)
    return;
  pending = false;
  // Cancel only this operation, then wait for its completion so the kernel no
  // longer references our buffer or OVERLAPPED before they are released.
  DWORD count = 0;
  if (CancelIoEx(handle, &operation) || GetLastError() != ERROR_NOT_FOUND)
    GetOverlappedResult(handle, &operation, &count, TRUE);
}
void WindowsPipeIo::close() noexcept {
  if (closed_)
    return;
  closed_ = true;
  settle(input_, read_, reading_);
  settle(output_, write_, writing_);
  for (HANDLE *handle : {&input_, &output_, &read_event_, &write_event_}) {
    if (*handle && *handle != INVALID_HANDLE_VALUE)
      CloseHandle(*handle);
    *handle = nullptr;
  }
}
} // namespace civ13::social
