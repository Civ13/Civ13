// Host-architecture seccomp installed before the tested payload execs.
#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <linux/audit.h>
#include <linux/filter.h>
#include <linux/seccomp.h>
#include <stddef.h>
#include <stdio.h>
#include <sys/prctl.h>
#include <sys/syscall.h>
#include <unistd.h>

#define DENY(n) BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, (n), 0, 1), BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EPERM)

int main(int argc, char **argv) {
    if (argc < 2) return 2;
#if !defined(__x86_64__)
#error This guard has only been reviewed for an x86-64 Linux host.
#endif
    struct sock_filter program[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, arch)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, AUDIT_ARCH_X86_64, 1, 0),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        BPF_JUMP(BPF_JMP | BPF_JSET | BPF_K, 0x40000000U, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS),
        DENY(SYS_socket), DENY(SYS_socketpair), DENY(SYS_bind), DENY(SYS_listen),
        DENY(SYS_connect), DENY(SYS_accept), DENY(SYS_accept4),
        DENY(SYS_io_uring_setup), DENY(SYS_unshare), DENY(SYS_setns),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
    };
    struct sock_fprog filter = { .len = sizeof(program) / sizeof(program[0]), .filter = program };
    if (syscall(SYS_close_range, 3U, UINT_MAX, 0U) || prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) ||
            prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &filter)) {
        perror("refusing payload: cannot install no-network guard");
        return 2;
    }
    fprintf(stderr, "civ13 guard: closed inherited fds and installed seccomp before exec\n");
    execv(argv[1], &argv[1]);
    perror("exec");
    return 2;
}
