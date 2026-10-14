#include <CoreGraphics/CoreGraphics.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct {
    uint32_t display;
    uint32_t count;
    float *samples;
} SavedTable;

static int read_exact(void *destination, size_t count) {
    unsigned char *cursor = destination;
    while (count > 0) {
        ssize_t received = read(STDIN_FILENO, cursor, count);
        if (received < 0 && errno == EINTR) { continue; }
        if (received <= 0) { return 0; }
        cursor += received;
        count -= received;
    }
    return 1;
}

static int read_table(SavedTable *table) {
    if (!read_exact(&table->display, sizeof(uint32_t))) { return 0; }
    if (!read_exact(&table->count, sizeof(uint32_t))) { return 0; }
    uint32_t count = table->count;
    if (count < 1 || count > 65536) { return 0; }
    size_t bytes = count * 3 * sizeof(float);
    table->samples = malloc(bytes);
    if (!table->samples) { return 0; }
    return read_exact(table->samples, bytes);
}

static void finish(SavedTable *tables, uint32_t count, int restore) {
    for (uint32_t index = 0; index < count; index++) {
        SavedTable *table = &tables[index];
        if (restore) {
            CGSetDisplayTransferByTable(table->display, table->count, table->samples,
                                       table->samples + table->count, table->samples + table->count * 2);
        }
        free(table->samples);
    }
}

int main(void) {
    SavedTable tables[32] = {0};
    uint32_t count = 0;
    if (!read_exact(&count, sizeof(count))) { return 1; }
    if (count < 1 || count > 32) { return 1; }
    for (uint32_t index = 0; index < count; index++) {
        if (!read_table(&tables[index])) { finish(tables, index + 1, 0); return 1; }
    }
    unsigned char normal_exit = 0;
    int normal = read_exact(&normal_exit, 1);
    finish(tables, count, !normal);
    return 0;
}
