// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * Full file details in Dolphin tooltips and the Information panel for files on
 * mounted network shares (cifs, NFS, ...).
 *
 * baloo-widgets skips every file for which KFileItem::isSlow() returns true,
 * and KIO reports all network filesystems as slow. Preloaded into Dolphin, this
 * library answers "not slow" only when the question comes from
 * libKF6BalooWidgets; every other caller gets the real answer from KIO, so
 * remote preview limits and the like keep working.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <link.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define ISSLOW_SYMBOL "_ZNK9KFileItem6isSlowEv" /* bool KFileItem::isSlow() const */
#define SELF_NAME "dolphin-network-metadata"

typedef bool (*is_slow_fn)(const void *self);

static is_slow_fn real_is_slow;
static uintptr_t baloo_start, baloo_end;

static int find_baloo_widgets(struct dl_phdr_info *info, size_t size, void *data)
{
    (void)size;
    (void)data;
    if (!info->dlpi_name || !strstr(info->dlpi_name, "libKF6BalooWidgets.so")) {
        return 0;
    }
    for (int i = 0; i < info->dlpi_phnum; i++) {
        const ElfW(Phdr) *ph = &info->dlpi_phdr[i];
        if (ph->p_type == PT_LOAD && (ph->p_flags & PF_X)) {
            uintptr_t start = info->dlpi_addr + ph->p_vaddr;
            __atomic_store_n(&baloo_end, start + ph->p_memsz, __ATOMIC_RELAXED);
            __atomic_store_n(&baloo_start, start, __ATOMIC_RELEASE);
            return 1;
        }
    }
    return 0;
}

/* Remove this library from LD_PRELOAD so programs started from Dolphin don't inherit it. */
static void drop_self_from_ld_preload(void)
{
    const char *old = getenv("LD_PRELOAD");
    if (!old) {
        return;
    }
    char *copy = strdup(old);
    char *rest = malloc(strlen(old) + 1);
    if (!copy || !rest) {
        free(copy);
        free(rest);
        return;
    }
    rest[0] = '\0';
    char *save = NULL;
    for (char *tok = strtok_r(copy, ": ", &save); tok; tok = strtok_r(NULL, ": ", &save)) {
        if (strstr(tok, SELF_NAME)) {
            continue;
        }
        if (rest[0]) {
            strcat(rest, ":");
        }
        strcat(rest, tok);
    }
    if (rest[0]) {
        setenv("LD_PRELOAD", rest, 1);
    } else {
        unsetenv("LD_PRELOAD");
    }
    free(copy);
    free(rest);
}

__attribute__((constructor)) static void init(void)
{
    drop_self_from_ld_preload();
    dl_iterate_phdr(find_baloo_widgets, NULL);
}

bool _ZNK9KFileItem6isSlowEv(const void *self)
{
    const uintptr_t caller = (uintptr_t)__builtin_return_address(0);

    is_slow_fn real = __atomic_load_n(&real_is_slow, __ATOMIC_ACQUIRE);
    if (!real) {
        real = (is_slow_fn)dlsym(RTLD_NEXT, ISSLOW_SYMBOL);
        if (!real) {
            return false;
        }
        __atomic_store_n(&real_is_slow, real, __ATOMIC_RELEASE);
    }

    uintptr_t start = __atomic_load_n(&baloo_start, __ATOMIC_ACQUIRE);
    if (!start) {
        dl_iterate_phdr(find_baloo_widgets, NULL);
        start = __atomic_load_n(&baloo_start, __ATOMIC_ACQUIRE);
    }
    if (start && caller >= start && caller < __atomic_load_n(&baloo_end, __ATOMIC_RELAXED)) {
        return false;
    }
    return real(self);
}
