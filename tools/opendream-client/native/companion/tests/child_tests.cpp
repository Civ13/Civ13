// Windows-only integration suite for the real child endpoint executable.
// Creates private overlapped pipe pairs the way WindowsCompanionPlatform does,
// launches the built companion with them as stdin/stdout and NUL as stderr,
// and checks the exchange and every exit path against the real OS. No SDK,
// network, credentials or account flow is involved.
#include "../peer.hpp"
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <iostream>
#include <optional>
#include <source_location>
#include <stdexcept>
#include <string>
#include <vector>
using namespace civ13::social;
namespace {
int assertions = 0;
void check(bool value,
           std::source_location where = std::source_location::current()) {
  ++assertions;
  if (!value)
    throw std::runtime_error("child assertion " + std::to_string(assertions) +
                             " line " + std::to_string(where.line()) +
                             " error " + std::to_string(GetLastError()));
}
struct Handle {
  HANDLE value = nullptr;
  Handle() = default;
  explicit Handle(HANDLE h) : value(h == INVALID_HANDLE_VALUE ? nullptr : h) {}
  Handle(const Handle &) = delete;
  Handle &operator=(const Handle &) = delete;
  ~Handle() { reset(); }
  void reset() {
    if (value)
      CloseHandle(value);
    value = nullptr;
  }
  explicit operator bool() const { return value != nullptr; }
};
int sequence = 0;
// One direction of the private pair: overlapped server end kept by the test,
// inheritable overlapped client end handed to the child.
void pipe_pair(bool child_reads, Handle &server, Handle &client,
               bool read_attributes = true) {
  const auto name = L"\\\\.\\pipe\\civ13-child-test-" +
                    std::to_wstring(GetCurrentProcessId()) + L"-" +
                    std::to_wstring(++sequence);
  server.value = CreateNamedPipeW(
      name.c_str(),
      (child_reads ? PIPE_ACCESS_OUTBOUND : PIPE_ACCESS_INBOUND) |
          FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT |
          PIPE_REJECT_REMOTE_CLIENTS,
      1, 4096, 4096, 0, nullptr);
  check(server.value != INVALID_HANDLE_VALUE);
  SECURITY_ATTRIBUTES inherit{sizeof(inherit), nullptr, TRUE};
  client.value = CreateFileW(name.c_str(),
                             child_reads ? GENERIC_READ
                             : read_attributes
                                 ? GENERIC_WRITE | FILE_READ_ATTRIBUTES
                                 : GENERIC_WRITE,
                             0,
                             &inherit, OPEN_EXISTING, FILE_FLAG_OVERLAPPED,
                             nullptr);
  check(client.value != INVALID_HANDLE_VALUE);
  check(SetHandleInformation(server.value, HANDLE_FLAG_INHERIT, 0));
}
struct Child {
  Handle to_child, from_child, process;
};
// Launches with exactly three inherited handles, like the parent provider.
bool launch(const std::wstring &exe, const std::wstring &arguments,
            Child &child, bool pipe_stdin = true,
            bool read_attributes = true) {
  Handle child_in, child_out;
  pipe_pair(true, child.to_child, child_in);
  pipe_pair(false, child.from_child, child_out, read_attributes);
  SECURITY_ATTRIBUTES inherit{sizeof(inherit), nullptr, TRUE};
  Handle null(CreateFileW(L"NUL", GENERIC_READ | GENERIC_WRITE,
                          FILE_SHARE_READ | FILE_SHARE_WRITE, &inherit,
                          OPEN_EXISTING, 0, nullptr));
  check(bool(null));
  HANDLE list[3] = {pipe_stdin ? child_in.value : null.value, child_out.value,
                    null.value};
  const DWORD count = pipe_stdin ? 3 : 2;
  if (!pipe_stdin)
    list[1] = child_out.value, list[0] = null.value;
  SIZE_T bytes = 0;
  InitializeProcThreadAttributeList(nullptr, 1, 0, &bytes);
  std::vector<char> storage(bytes);
  auto attributes =
      reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(storage.data());
  check(InitializeProcThreadAttributeList(attributes, 1, 0, &bytes));
  HANDLE unique[3] = {list[0], list[1], null.value};
  check(UpdateProcThreadAttribute(attributes, 0,
                                  PROC_THREAD_ATTRIBUTE_HANDLE_LIST, unique,
                                  count * sizeof(HANDLE), nullptr, nullptr));
  STARTUPINFOEXW startup{};
  startup.StartupInfo.cb = sizeof(startup);
  startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  startup.StartupInfo.hStdInput = list[0];
  startup.StartupInfo.hStdOutput = list[1];
  startup.StartupInfo.hStdError = null.value;
  startup.lpAttributeList = attributes;
  std::wstring command = L"\"" + exe + L"\" " + arguments;
  PROCESS_INFORMATION info{};
  const bool created =
      CreateProcessW(exe.c_str(), command.data(), nullptr, nullptr, TRUE,
                     CREATE_NO_WINDOW | EXTENDED_STARTUPINFO_PRESENT, nullptr,
                     nullptr, &startup.StartupInfo, &info);
  DeleteProcThreadAttributeList(attributes);
  if (!created)
    return false;
  CloseHandle(info.hThread);
  child.process.value = info.hProcess;
  return true; // Child ends close here; only the child holds them now.
}
bool write_all(HANDLE pipe, const std::vector<uint8_t> &bytes) {
  OVERLAPPED operation{};
  Handle event(CreateEventW(nullptr, TRUE, FALSE, nullptr));
  operation.hEvent = event.value;
  DWORD done = 0;
  if (!WriteFile(pipe, bytes.data(), DWORD(bytes.size()), nullptr,
                 &operation) &&
      GetLastError() != ERROR_IO_PENDING)
    return false;
  if (WaitForSingleObject(event.value, 2000) != WAIT_OBJECT_0) {
    CancelIoEx(pipe, &operation);
    GetOverlappedResult(pipe, &operation, &done, TRUE);
    return false;
  }
  return GetOverlappedResult(pipe, &operation, &done, FALSE) &&
         done == bytes.size();
}
// Reads exactly count bytes, or nullopt on EOF/timeout.
std::optional<std::vector<uint8_t>> read_exact(HANDLE pipe, size_t count,
                                               DWORD timeout = 2000) {
  std::vector<uint8_t> result(count);
  size_t have = 0;
  const auto deadline = GetTickCount64() + timeout;
  while (have < count) {
    OVERLAPPED operation{};
    Handle event(CreateEventW(nullptr, TRUE, FALSE, nullptr));
    operation.hEvent = event.value;
    DWORD done = 0;
    if (!ReadFile(pipe, result.data() + have, DWORD(count - have), nullptr,
                  &operation) &&
        GetLastError() != ERROR_IO_PENDING)
      return std::nullopt;
    const auto now = GetTickCount64();
    const DWORD wait = now >= deadline ? 0 : DWORD(deadline - now);
    if (WaitForSingleObject(event.value, wait) != WAIT_OBJECT_0) {
      CancelIoEx(pipe, &operation);
      GetOverlappedResult(pipe, &operation, &done, TRUE);
      return std::nullopt;
    }
    if (!GetOverlappedResult(pipe, &operation, &done, FALSE) || done == 0)
      return std::nullopt;
    have += done;
  }
  return result;
}
bool at_eof(HANDLE pipe, DWORD timeout) {
  uint8_t byte = 0;
  OVERLAPPED operation{};
  Handle event(CreateEventW(nullptr, TRUE, FALSE, nullptr));
  operation.hEvent = event.value;
  DWORD done = 0;
  if (!ReadFile(pipe, &byte, 1, nullptr, &operation)) {
    const auto error = GetLastError();
    if (error == ERROR_BROKEN_PIPE || error == ERROR_PIPE_NOT_CONNECTED)
      return true;
    if (error != ERROR_IO_PENDING)
      return false;
  }
  if (WaitForSingleObject(event.value, timeout) != WAIT_OBJECT_0) {
    CancelIoEx(pipe, &operation);
    GetOverlappedResult(pipe, &operation, &done, TRUE);
    return false;
  }
  return !GetOverlappedResult(pipe, &operation, &done, FALSE) &&
         GetLastError() == ERROR_BROKEN_PIPE;
}
std::optional<DWORD> exit_code(const Child &child, DWORD timeout) {
  if (WaitForSingleObject(child.process.value, timeout) != WAIT_OBJECT_0)
    return std::nullopt;
  DWORD code = 0;
  check(GetExitCodeProcess(child.process.value, &code));
  return code;
}
void kill(Child &child) {
  if (child.process && WaitForSingleObject(child.process.value, 0) != 0) {
    TerminateProcess(child.process.value, 99);
    WaitForSingleObject(child.process.value, 2000);
  }
}
const Profile profile{"Civ13.com", "42", 1714};
const std::wstring arguments = L"--social-peer-v1 Civ13.com 1714 42";
std::vector<uint8_t> hello() { return encode({Op::hello, 1, profile_bytes(profile)}); }
std::vector<uint8_t> ready() { return encode({Op::ready, 1, profile_bytes(profile)}); }
void session(const std::wstring &loopback, bool read_attributes) {
  Child child;
  check(launch(loopback, arguments, child, true, read_attributes));
  check(write_all(child.to_child.value, hello()));
  check(read_exact(child.from_child.value, ready().size()) == ready());
  check(write_all(child.to_child.value,
                  encode({Op::publish, 2, {1, 1, 'D', 'S'}})));
  check(read_exact(child.from_child.value, 21) ==
        encode({Op::result, 2, {0}}));
  check(write_all(child.to_child.value, encode({Op::pulse, 3, {}})));
  check(write_all(child.to_child.value, encode({Op::stop, 4, {}})));
  check(exit_code(child, 3000) == DWORD(0));
  check(at_eof(child.from_child.value, 1000));
}
void parent_eof(const std::wstring &loopback) {
  Child child;
  check(launch(loopback, arguments, child));
  check(write_all(child.to_child.value, hello()));
  check(read_exact(child.from_child.value, ready().size()) == ready());
  child.to_child.reset(); // Parent closes its end: child must exit promptly.
  check(exit_code(child, 2000) == DWORD(0));
}
void lease(const std::wstring &loopback) {
  Child child;
  check(launch(loopback, arguments, child));
  check(write_all(child.to_child.value, hello()));
  check(read_exact(child.from_child.value, ready().size()) == ready());
  const auto began = GetTickCount64();
  check(!exit_code(child, 4000)); // Still within the five-second lease.
  check(exit_code(child, 4000) == DWORD(0));
  check(GetTickCount64() - began >= 4900);
  check(at_eof(child.from_child.value, 1000));
}
void malformed(const std::wstring &loopback) {
  Child child;
  check(launch(loopback, arguments, child));
  check(write_all(child.to_child.value, {'X', '1', '3', 'S', 1, 1, 0, 0, 1, 0,
                                         0, 0, 0, 0, 0, 0, 0, 0, 0, 0}));
  check(exit_code(child, 2000) == DWORD(0));
  check(at_eof(child.from_child.value, 1000));
  Child wrong;
  check(launch(loopback, L"--social-peer-v1 Civ13.com 1715 42", wrong));
  check(write_all(wrong.to_child.value, hello())); // Profile mismatch.
  check(exit_code(wrong, 2000) == DWORD(0));
  check(at_eof(wrong.from_child.value, 1000));
}
void refused_start(const std::wstring &production) {
  Child child;
  check(launch(production, arguments, child));
  check(write_all(child.to_child.value, hello()));
  check(at_eof(child.from_child.value, 2000)); // No Ready: activation is off.
  check(exit_code(child, 2000) == DWORD(0));
}
void invalid(const std::wstring &exe) {
  for (const auto *bad :
       {L"", L"--social-peer-v1", L"--social-peer-v1 Civ13.com 1716 42",
        L"--social-peer-v1 Civ13.com 1714 0",
        L"--social-peer-v1 Civ13.com 1714 42 extra",
        L"--social-peer-v2 Civ13.com 1714 42"}) {
    Child child;
    check(launch(exe, bad, child));
    check(exit_code(child, 2000) == DWORD(2));
    kill(child);
  }
  Child not_pipe;
  check(launch(exe, arguments, not_pipe, false)); // stdin is NUL, not a pipe.
  check(exit_code(not_pipe, 2000) == DWORD(3));
  kill(not_pipe);
}
} // namespace
int wmain(int argc, wchar_t **argv) {
  if (argc != 3) {
    std::cerr << "usage: child-tests <loopback.exe> <production.exe>\n";
    return 2;
  }
  try {
    session(argv[1], true);
    session(argv[1], false); // Write-only stdout without FILE_READ_ATTRIBUTES.
    parent_eof(argv[1]);
    malformed(argv[1]);
    refused_start(argv[2]);
    invalid(argv[2]);
    lease(argv[1]);
  } catch (const std::exception &error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
  std::cout << "child endpoint tests passed: " << assertions
            << " assertions\n";
  return 0;
}
