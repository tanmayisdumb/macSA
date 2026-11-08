#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <limits.h>

#define V10_US_SIZE 14383616

static int file_exists(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0);
}

static off_t file_size(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    return st.st_size;
}

static int copy_file(const char *src, const char *dst) {
    FILE *in = fopen(src, "rb");
    if (!in) return 0;
    FILE *out = fopen(dst, "wb");
    if (!out) { fclose(in); return 0; }
    char buf[65536];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
        if (fwrite(buf, 1, n, out) != n) {
            fclose(in);
            fclose(out);
            return 0;
        }
    }
    fclose(in);
    fclose(out);
    chmod(dst, 0755);
    return 1;
}

static void mkdir_p(const char *path) {
    char tmp[PATH_MAX];
    char *p = NULL;
    snprintf(tmp, sizeof(tmp), "%s", path);
    size_t len = strlen(tmp);
    if (len > 0 && tmp[len - 1] == '/') tmp[len - 1] = 0;
    for (p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            mkdir(tmp, 0755);
            *p = '/';
        }
    }
    mkdir(tmp, 0755);
}

// Configures default settings in gta_sa.set:
// - bInvertMouseY = 1 (inverted mouse by default) [offset t_pos - 22]
// - m_bWidescreenOn = 1 (widescreen on by default) [offset t_pos + 6]
// - m_nPrefsVideoMode = 2 (2560x1600x32 video mode) [offset t_pos + 8]
// - m_bPrefsFrameLimiter = 0 (frame limiter off by default) [offset t_pos + 14]
// - m_nDisplayVideoMode = 2 (2560x1600x32 active video mode) [offset t_pos + 15]
static void ensure_default_settings(const char *contents_dir) {
    const char *home = getenv("HOME");
    if (!home) return;

    char set_dir[PATH_MAX];
    snprintf(set_dir, sizeof(set_dir),
             "%s/Library/Application Support/saif/overlay/Users/player/Documents/GTA San Andreas User Files",
             home);

    char set_file[PATH_MAX];
    snprintf(set_file, sizeof(set_file), "%s/gta_sa.set", set_dir);

    // If gta_sa.set doesn't exist yet, copy bundled template from Resources
    if (!file_exists(set_file)) {
        char template_set[PATH_MAX];
        snprintf(template_set, sizeof(template_set), "%s/Resources/gta_sa.set", contents_dir);
        if (file_exists(template_set)) {
            mkdir_p(set_dir);
            copy_file(template_set, set_file);
        }
    }

    if (!file_exists(set_file)) return;

    FILE *f = fopen(set_file, "r+b");
    if (!f) return;

    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    if (sz >= 2900) {
        fseek(f, 0, SEEK_SET);
        unsigned char *data = (unsigned char *)malloc(sz);
        if (data && fread(data, 1, sz, f) == (size_t)sz) {
            // Find marker 'T' (0x54) near the end
            long t_pos = -1;
            for (long i = sz - 100; i < sz - 15; i++) {
                if (data[i] == 0x54) {
                    t_pos = i;
                    break;
                }
            }

            if (t_pos > 30) {
                // bInvertMouseY: offset t_pos - 22 (1 = Invert Mouse)
                data[t_pos - 22] = 1;

                // m_bWidescreenOn: offset t_pos + 6 (1 = On)
                data[t_pos + 6] = 1;

                // m_nPrefsVideoMode: offset t_pos + 8 (4 bytes)
                // Mode 2 corresponds to 2560x1600x32 in SaifRuntime
                data[t_pos + 8] = 2;
                data[t_pos + 9] = 0;
                data[t_pos + 10] = 0;
                data[t_pos + 11] = 0;

                // m_bPrefsFrameLimiter: offset t_pos + 14 (0 = Off)
                data[t_pos + 14] = 0;

                // m_nDisplayVideoMode: offset t_pos + 15 (4 bytes)
                // Mode 2 corresponds to 2560x1600x32 in SaifRuntime
                data[t_pos + 15] = 2;
                data[t_pos + 16] = 0;
                data[t_pos + 17] = 0;
                data[t_pos + 18] = 0;

                // Write back
                fseek(f, 0, SEEK_SET);
                fwrite(data, 1, sz, f);
            }
        }
        free(data);
    }
    fclose(f);
}

int main(int argc, char *argv[]) {
    // 1. Resolve application bundle paths
    char exec_path[PATH_MAX];
    uint32_t size = sizeof(exec_path);
    if (_NSGetExecutablePath(exec_path, &size) != 0) {
        fprintf(stderr, "macSA: Unable to locate executable path.\n");
        return 1;
    }

    char real_exec[PATH_MAX];
    if (!realpath(exec_path, real_exec)) {
        strncpy(real_exec, exec_path, sizeof(real_exec) - 1);
        real_exec[sizeof(real_exec) - 1] = '\0';
    }

    // real_exec is ".../Contents/MacOS/macSA"
    char *last_slash = strrchr(real_exec, '/');
    if (!last_slash) return 1;
    *last_slash = '\0'; // real_exec is now ".../Contents/MacOS"

    char contents_dir[PATH_MAX];
    strncpy(contents_dir, real_exec, sizeof(contents_dir) - 1);
    contents_dir[sizeof(contents_dir) - 1] = '\0';
    char *c_slash = strrchr(contents_dir, '/');
    if (!c_slash) return 1;
    *c_slash = '\0'; // contents_dir is now ".../Contents"

    char runtime_path[PATH_MAX];
    snprintf(runtime_path, sizeof(runtime_path), "%s/SaifRuntime", real_exec);

    char gamedata_path[PATH_MAX];
    snprintf(gamedata_path, sizeof(gamedata_path), "%s/Resources/GameData", contents_dir);

    // Apply user defaults
    // 1. Force 2560x1600 resolution
    setenv("GTA_FORCE_RES", "2560x1600", 0);

    // 2. Uncap internal 30fps engine cap
    setenv("GTA_UNCAP", "1", 0);

    // 3. Smooth VSync frame pacing with ProMotion / display refresh rate
    setenv("GTA_VSYNC", "1", 0);

    // 4. Update gta_sa.set preferences (invert mouse, frame limiter off, 2560x1600x32 video mode)
    ensure_default_settings(contents_dir);

    char v10us_patch[PATH_MAX];
    snprintf(v10us_patch, sizeof(v10us_patch), "%s/Resources/gta_sa_v10us.exe", contents_dir);

    char exe1[PATH_MAX], img1[PATH_MAX];
    snprintf(exe1, sizeof(exe1), "%s/gta_sa.exe", gamedata_path);
    snprintf(img1, sizeof(img1), "%s/models/gta3.img", gamedata_path);

    int has_baked_game = file_exists(exe1) || file_exists(img1);

    // If game files are baked into Contents/Resources/GameData
    if (has_baked_game) {
        // Auto-fix: Ensure gta_sa.exe is the clean v1.0 US executable if a patch is available
        if (file_exists(v10us_patch)) {
            off_t current_size = file_size(exe1);
            if (current_size != V10_US_SIZE) {
                char backup_exe[PATH_MAX];
                snprintf(backup_exe, sizeof(backup_exe), "%s/gta_sa.exe.original", gamedata_path);
                if (!file_exists(backup_exe) && file_exists(exe1)) {
                    rename(exe1, backup_exe);
                }
                copy_file(v10us_patch, exe1);
            }
        }

        // Auto-patch default resolution in gta_sa.exe to 2560x1600 (offset 0x345762)
        if (file_exists(exe1) && file_size(exe1) == V10_US_SIZE) {
            FILE *exef = fopen(exe1, "r+b");
            if (exef) {
                if (fseek(exef, 0x345762, SEEK_SET) == 0) {
                    unsigned char res_buf[10];
                    if (fread(res_buf, 1, 10, exef) == 10) {
                        // Check if 800x600 (bd 20 03 00 00 bb 58 02 00 00)
                        if (res_buf[0] == 0xbd && res_buf[1] == 0x20 && res_buf[2] == 0x03 &&
                            res_buf[5] == 0xbb && res_buf[6] == 0x58 && res_buf[7] == 0x02) {
                            // Patch to 2560x1600 (bd 00 0a 00 00 bb 40 06 00 00)
                            res_buf[1] = 0x00; res_buf[2] = 0x0a;
                            res_buf[6] = 0x40; res_buf[7] = 0x06;
                            fseek(exef, 0x345762, SEEK_SET);
                            fwrite(res_buf, 1, 10, exef);
                        }
                    }
                }
                fclose(exef);
            }
        }

        chdir(gamedata_path);

        // If extra arguments were provided via CLI (excluding macOS Finder's -psn)
        if (argc >= 2 && strncmp(argv[1], "-psn", 4) != 0) {
            char **new_argv = (char **)malloc((argc + 2) * sizeof(char *));
            if (!new_argv) return 1;

            new_argv[0] = runtime_path;
            new_argv[1] = gamedata_path;
            for (int i = 1; i < argc; i++) {
                new_argv[i + 1] = argv[i];
            }
            new_argv[argc + 1] = NULL;

            execv(runtime_path, new_argv);
            free(new_argv);
        } else {
            char *new_argv[] = { runtime_path, gamedata_path, NULL };
            execv(runtime_path, new_argv);
        }

        perror("macSA: Failed to execute SaifRuntime");
        return 1;
    }

    // Case 2: User specified an external folder or arguments via command line
    if (argc >= 2 && strncmp(argv[1], "-psn", 4) != 0) {
        argv[0] = runtime_path;
        execv(runtime_path, argv);
        perror("macSA: Failed to execute SaifRuntime with arguments");
        return 1;
    }

    // Case 3: Empty template app opened directly.
    char *fallback_argv[] = { runtime_path, NULL };
    execv(runtime_path, fallback_argv);
    perror("macSA: Failed to launch SaifRuntime fallback");
    return 1;
}
