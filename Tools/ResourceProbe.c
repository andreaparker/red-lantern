#include <libproc.h>
#include <sys/resource.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

static int snapshot(int pid, struct rusage_info_v4 *info) {
    return proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)info);
}

static void report(int pid, struct rusage_info_v4 *before, struct rusage_info_v4 *after, int seconds) {
    double cpu = (after->ri_user_time - before->ri_user_time)
        + (after->ri_system_time - before->ri_system_time);
    printf("pid=%d footprint_MiB=%.2f resident_MiB=%.2f cpu_ms=%.3f cpu_percent=%.5f wakeups=%llu sample_seconds=%d\n",
           pid, after->ri_phys_footprint / 1048576.0, after->ri_resident_size / 1048576.0,
           cpu / 1000000.0, cpu / (seconds * 10000000.0),
           after->ri_interrupt_wkups - before->ri_interrupt_wkups, seconds);
}

static int capture(char **pids, int count, struct rusage_info_v4 *before) {
    for (int index = 0; index < count; index++) {
        if (snapshot(atoi(pids[index]), &before[index]) != 0) { return 2; }
    }
    return 0;
}

static void finish(char **pids, int count, struct rusage_info_v4 *before, int seconds) {
    for (int index = 0; index < count; index++) {
        struct rusage_info_v4 after = {0};
        int pid = atoi(pids[index]);
        if (snapshot(pid, &after) == 0) { report(pid, &before[index], &after, seconds); }
    }
}

int main(int argc, char **argv) {
    if (argc < 3 || argc > 34) { return 1; }
    int seconds = atoi(argv[1]);
    if (seconds < 1 || seconds > 60) { return 1; }
    struct rusage_info_v4 before[32] = {0};
    if (capture(argv + 2, argc - 2, before) != 0) { return 2; }
    struct timespec duration = {.tv_sec = seconds};
    nanosleep(&duration, NULL);
    finish(argv + 2, argc - 2, before, seconds);
    return 0;
}
