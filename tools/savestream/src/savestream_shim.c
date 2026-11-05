/* Civ13 stream save shim: the 32-bit library Dream Daemon loads with call_ext.
 *
 * It holds no save data. Each session spawns the 64-bit savestream_helper
 * and forwards framed requests to it, so the save tree, its index and its
 * validation state live in the helper's address space instead of dd.exe's.
 *
 * Classic call_ext interface: every export is  char *fn(int argc, char **argv)
 * and returns text that stays valid until the next call.
 *
 *   savestream_open(mode, file, helper)  -> "<id>" or "ERR:..."   mode = write|read
 *   savestream_write(id, part...)        -> "OK" or "ERR:..."  (parts joined; one batch in flight)
 *   savestream_finish(id, force)         -> JSON summary from the helper
 *   savestream_abort(id)                 -> "OK"
 *   savestream_get(id, path)             -> wire token, "?" if absent
 *   savestream_dir(id, path)             -> L token of child names
 *   savestream_iter(id, "start;max")     -> "<next>;" then W records in path order
 *   savestream_stats(id)                 -> JSON
 *   savestream_close(id)                 -> "OK"
 *   savestream_version()                 -> identity string
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#define EXPORT __declspec(dllexport)
#else
#include <dlfcn.h>
#include <errno.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#define EXPORT __attribute__((visibility("default")))
#endif
#include "savestream_format.h"

#define SHIM_IDENTITY "civ13-savestream-shim;format=1;protocol=1"
#define MAX_SESSIONS 8

typedef struct {
	int used;
	int pending; /* a write reply is still owed by the helper */
	char pending_error[256];
#ifdef _WIN32
	HANDLE to_child, from_child, process;
#else
	int fd;
	pid_t pid;
#endif
} session_t;

static session_t sessions[MAX_SESSIONS];
static void resolve_path(const char *in, char *out, size_t outlen);
static char *ret; static size_t ret_cap;

static char *set_ret(const char *d, size_t n) {
	if (n + 1 > ret_cap) { size_t cap = ret_cap ? ret_cap : 256; while (cap < n + 1) cap *= 2; char *p = realloc(ret, cap); if (!p) return (char *)"ERR:out of memory"; ret = p; ret_cap = cap; }
	memcpy(ret, d, n); ret[n] = 0; return ret;
}
static char *ret_str(const char *s) { return set_ret(s, strlen(s)); }

/* ---------- process and pipe plumbing ---------- */

static int send_all(session_t *s, const void *d, size_t n) {
	const char *p = d;
	while (n) {
#ifdef _WIN32
		DWORD w = 0;
		if (!WriteFile(s->to_child, p, n > 0x40000000 ? 0x40000000 : (DWORD)n, &w, NULL) || !w) return 0;
#else
		ssize_t w = send(s->fd, p, n, MSG_NOSIGNAL);
		if (w < 0 && errno == EINTR) continue;
		if (w <= 0) return 0;
#endif
		p += w; n -= (size_t)w;
	}
	return 1;
}
static int recv_all(session_t *s, void *d, size_t n) {
	char *p = d;
	while (n) {
#ifdef _WIN32
		DWORD r = 0;
		if (!ReadFile(s->from_child, p, n > 0x40000000 ? 0x40000000 : (DWORD)n, &r, NULL) || !r) return 0;
#else
		ssize_t r = recv(s->fd, p, n, 0);
		if (r < 0 && errno == EINTR) continue;
		if (r <= 0) return 0;
#endif
		p += r; n -= (size_t)r;
	}
	return 1;
}
static int send_request(session_t *s, char op, const char *d, size_t n) {
	unsigned char h[5] = { (unsigned char)op, (unsigned char)n, (unsigned char)(n >> 8), (unsigned char)(n >> 16), (unsigned char)(n >> 24) };
	return send_all(s, h, 5) && send_all(s, d, n);
}
/* Read one reply into the return buffer. */
static char *read_reply(session_t *s) {
	unsigned char h[4];
	if (!recv_all(s, h, 4)) return NULL;
	size_t n = h[0] | (size_t)h[1] << 8 | (size_t)h[2] << 16 | (size_t)h[3] << 24;
	if (n + 1 > ret_cap) { size_t cap = ret_cap ? ret_cap : 256; while (cap < n + 1) cap *= 2; char *p = realloc(ret, cap); if (!p) return NULL; ret = p; ret_cap = cap; }
	if (n && !recv_all(s, ret, n)) return NULL;
	ret[n] = 0;
	return ret;
}

static void close_session(session_t *s) {
#ifdef _WIN32
	if (s->to_child) CloseHandle(s->to_child);
	if (s->from_child) CloseHandle(s->from_child);
	if (s->process) { if (WaitForSingleObject(s->process, 5000) != WAIT_OBJECT_0) TerminateProcess(s->process, 1); CloseHandle(s->process); }
#else
	if (s->fd > 0) close(s->fd);
	if (s->pid > 0) {
		int status; int waited = 0;
		for (int i = 0; i < 500 && !waited; i++) { if (waitpid(s->pid, &status, WNOHANG) == s->pid) waited = 1; else usleep(10000); }
		if (!waited) { kill(s->pid, SIGKILL); waitpid(s->pid, &status, 0); }
	}
#endif
	memset(s, 0, sizeof *s);
}

static int spawn_helper(session_t *s, const char *helper, const char *mode, const char *file, char *err, size_t errlen) {
#ifdef _WIN32
	SECURITY_ATTRIBUTES sa = { sizeof sa, NULL, TRUE };
	HANDLE child_in_r, child_in_w, child_out_r, child_out_w;
	if (!CreatePipe(&child_in_r, &child_in_w, &sa, 1 << 20)) { snprintf(err, errlen, "CreatePipe failed"); return 0; }
	if (!CreatePipe(&child_out_r, &child_out_w, &sa, 1 << 20)) { CloseHandle(child_in_r); CloseHandle(child_in_w); snprintf(err, errlen, "CreatePipe failed"); return 0; }
	SetHandleInformation(child_in_w, HANDLE_FLAG_INHERIT, 0);
	SetHandleInformation(child_out_r, HANDLE_FLAG_INHERIT, 0);
	HANDLE nul = CreateFileA("NUL", GENERIC_WRITE, FILE_SHARE_WRITE, &sa, OPEN_EXISTING, 0, NULL);
	STARTUPINFOA si; PROCESS_INFORMATION pi;
	memset(&si, 0, sizeof si); memset(&pi, 0, sizeof pi);
	si.cb = sizeof si; si.dwFlags = STARTF_USESTDHANDLES;
	si.hStdInput = child_in_r; si.hStdOutput = child_out_w; si.hStdError = nul;
	size_t cl = strlen(helper) + strlen(mode) + strlen(file) + 16;
	char *cmd = malloc(cl);
	if (!cmd) { snprintf(err, errlen, "out of memory"); return 0; }
	snprintf(cmd, cl, "\"%s\" %s \"%s\"", helper, mode, file);
	char workdir[1200];
	resolve_path(".", workdir, sizeof workdir);
	BOOL ok = CreateProcessA(helper, cmd, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, workdir, &si, &pi);
	free(cmd);
	CloseHandle(child_in_r); CloseHandle(child_out_w);
	if (nul != INVALID_HANDLE_VALUE) CloseHandle(nul);
	if (!ok) { CloseHandle(child_in_w); CloseHandle(child_out_r); snprintf(err, errlen, "cannot start helper %s (error %lu)", helper, (unsigned long)GetLastError()); return 0; }
	CloseHandle(pi.hThread);
	s->to_child = child_in_w; s->from_child = child_out_r; s->process = pi.hProcess;
	return 1;
#else
	int sv[2];
	if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0, sv) != 0) { snprintf(err, errlen, "socketpair: %s", strerror(errno)); return 0; }
	pid_t pid = fork();
	if (pid < 0) { close(sv[0]); close(sv[1]); snprintf(err, errlen, "fork: %s", strerror(errno)); return 0; }
	if (pid == 0) {
		dup2(sv[1], 0); dup2(sv[1], 1);
		execl(helper, helper, mode, file, (char *)NULL);
		_exit(127);
	}
	close(sv[1]);
	s->fd = sv[0]; s->pid = pid;
	return 1;
#endif
}

/* Relative helper and file paths resolve against the directory this library
 * was loaded from (the .dmb directory), not Dream Daemon's working directory,
 * which BYOND does not guarantee. */
static void resolve_path(const char *in, char *out, size_t outlen) {
	int absolute = in[0] == '/' || in[0] == '\\' || (in[0] && in[1] == ':');
	char dir[1024] = "";
#ifdef _WIN32
	HMODULE self = NULL;
	if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)&resolve_path, &self)) {
		DWORD n = GetModuleFileNameA(self, dir, sizeof dir);
		if (n && n < sizeof dir) { char *slash = strrchr(dir, '\\'); char *fwd = strrchr(dir, '/'); if (fwd > slash) slash = fwd; if (slash) slash[1] = 0; else dir[0] = 0; }
		else dir[0] = 0;
	}
#else
	Dl_info info;
	if (dladdr((void *)&resolve_path, &info) && info.dli_fname) {
		snprintf(dir, sizeof dir, "%s", info.dli_fname);
		char *slash = strrchr(dir, '/');
		if (slash) slash[1] = 0; else dir[0] = 0;
	}
#endif
	if (absolute || !dir[0]) snprintf(out, outlen, "%s", in);
	else snprintf(out, outlen, "%s%s", dir, in);
}

static session_t *session_arg(int argc, char **argv) {
	if (argc < 1) return NULL;
	int id = atoi(argv[0]);
	if (id < 1 || id > MAX_SESSIONS || !sessions[id - 1].used) return NULL;
	return &sessions[id - 1];
}
static char *helper_gone(session_t *s) { close_session(s); return ret_str("ERR:helper exited"); }

/* Collect the reply owed for the last asynchronous write. */
static int drain_pending(session_t *s) {
	if (!s->pending) return 1;
	s->pending = 0;
	char *r = read_reply(s);
	if (!r) { snprintf(s->pending_error, sizeof s->pending_error, "ERR:helper exited"); return 0; }
	if (strcmp(r, "OK") != 0) { snprintf(s->pending_error, sizeof s->pending_error, "%s", r); return 0; }
	return 1;
}

/* ---------- exports ---------- */

EXPORT char *savestream_version(int argc, char **argv) { (void)argc; (void)argv; return ret_str(SHIM_IDENTITY); }

EXPORT char *savestream_open(int argc, char **argv) {
	if (argc < 2) return ret_str("ERR:usage open(mode, file, helper)");
	const char *mode = argv[0];
	const char *helper_arg = argc > 2 && argv[2][0] ? argv[2] :
#ifdef _WIN32
		"savestream_helper.exe";
#else
		"savestream_helper";
#endif
	char helper[1200], file[1200];
	resolve_path(helper_arg, helper, sizeof helper);
	resolve_path(argv[1], file, sizeof file);
	if (strcmp(mode, "write") != 0 && strcmp(mode, "read") != 0) return ret_str("ERR:mode must be write or read");
	int slot = -1;
	for (int i = 0; i < MAX_SESSIONS; i++) if (!sessions[i].used) { slot = i; break; }
	if (slot < 0) return ret_str("ERR:too many sessions");
	session_t *s = &sessions[slot];
	memset(s, 0, sizeof *s);
	char err[256];
	if (!spawn_helper(s, helper, mode, file, err, sizeof err)) { char m[300]; snprintf(m, sizeof m, "ERR:%s", err); return ret_str(m); }
	s->used = 1;
	/* Round trip once so a helper that failed to open its file is reported here. */
	if (!send_request(s, OP_STATS, "", 0)) return helper_gone(s);
	char *r = read_reply(s);
	if (!r) return helper_gone(s);
	if (strncmp(r, "ERR:", 4) == 0) { char m[300]; snprintf(m, sizeof m, "%s", r); close_session(s); return ret_str(m); }
	char id[16]; snprintf(id, sizeof id, "%d", slot + 1);
	return ret_str(id);
}

EXPORT char *savestream_write(int argc, char **argv) {
	session_t *s = session_arg(argc, argv);
	if (!s || argc < 2) return ret_str("ERR:bad session");
	if (s->pending_error[0]) return ret_str(s->pending_error);
	if (!drain_pending(s)) return ret_str(s->pending_error);
	/* The game passes a batch as several fragments (DM cannot join text that
	 * holds text macros without dropping them); join them here. */
	size_t total = 0;
	for (int i = 1; i < argc; i++) total += strlen(argv[i]);
	char *payload = malloc(total + 1);
	if (!payload) return ret_str("ERR:out of memory");
	size_t at = 0;
	for (int i = 1; i < argc; i++) { size_t n = strlen(argv[i]); memcpy(payload + at, argv[i], n); at += n; }
	payload[at] = 0;
	int sent = send_request(s, OP_WRITE, payload, total);
	free(payload);
	if (!sent) return helper_gone(s);
	s->pending = 1;
	return ret_str("OK");
}

EXPORT char *savestream_finish(int argc, char **argv) {
	session_t *s = session_arg(argc, argv);
	if (!s) return ret_str("ERR:bad session");
	if (!drain_pending(s) || s->pending_error[0]) {
		send_request(s, OP_ABORT, "", 0); read_reply(s);
		return ret_str(s->pending_error);
	}
	const char *force = argc > 1 && argv[1][0] == '1' ? "force" : "";
	if (!send_request(s, OP_FINISH, force, strlen(force))) return helper_gone(s);
	char *r = read_reply(s);
	return r ? r : helper_gone(s);
}

EXPORT char *savestream_abort(int argc, char **argv) {
	session_t *s = session_arg(argc, argv);
	if (!s) return ret_str("ERR:bad session");
	drain_pending(s);
	if (send_request(s, OP_ABORT, "", 0)) read_reply(s);
	return ret_str("OK");
}

static char *query(int argc, char **argv, char op) {
	session_t *s = session_arg(argc, argv);
	if (!s || argc < 2) return ret_str("ERR:bad session");
	/* A write-mode read must not take the reply owed to the last write. */
	if (!drain_pending(s)) return ret_str(s->pending_error);
	if (!send_request(s, op, argv[1], strlen(argv[1]))) return helper_gone(s);
	char *r = read_reply(s);
	return r ? r : helper_gone(s);
}
EXPORT char *savestream_get(int argc, char **argv) { return query(argc, argv, OP_GET); }
EXPORT char *savestream_dir(int argc, char **argv) { return query(argc, argv, OP_DIR); }
EXPORT char *savestream_iter(int argc, char **argv) { return query(argc, argv, OP_ITER); }
EXPORT char *savestream_seek(int argc, char **argv) { return query(argc, argv, OP_SEEK); }

EXPORT char *savestream_stats(int argc, char **argv) {
	session_t *s = session_arg(argc, argv);
	if (!s) return ret_str("ERR:bad session");
	if (!drain_pending(s)) return ret_str(s->pending_error);
	if (!send_request(s, OP_STATS, "", 0)) return helper_gone(s);
	char *r = read_reply(s);
	return r ? r : helper_gone(s);
}

EXPORT char *savestream_close(int argc, char **argv) {
	session_t *s = session_arg(argc, argv);
	if (!s) return ret_str("OK");
	drain_pending(s);
	if (send_request(s, OP_QUIT, "", 0)) read_reply(s);
	close_session(s);
	return ret_str("OK");
}
