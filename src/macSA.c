#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <limits.h>

static int file_exists(const char *path) {
    struct stat st;
    return (stat(path, &st) == 0);
}

int main(int argc, char *argv[]) {
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
    if (!last_slash) {
        fprintf(stderr, "macSA: Invalid executable path format.\n");
        return 1;
    }
    *last_slash = '\0'; // real_exec is now ".../Contents/MacOS"

    char contents_dir[PATH_MAX];
    strncpy(contents_dir, real_exec, sizeof(contents_dir) - 1);
    contents_dir[sizeof(contents_dir) - 1] = '\0';
    char *c_slash = strrchr(contents_dir, '/');
    if (!c_slash) {
        fprintf(stderr, "macSA: Invalid Contents directory format.\n");
        return 1;
    }
    *c_slash = '\0'; // contents_dir is now ".../Contents"

    char runtime_path[PATH_MAX];
    snprintf(runtime_path, sizeof(runtime_path), "%s/SaifRuntime", real_exec);

    char gamedata_path[PATH_MAX];
    snprintf(gamedata_path, sizeof(gamedata_path), "%s/Resources/GameData", contents_dir);

    char exe1[PATH_MAX], exe2[PATH_MAX], exe3[PATH_MAX], img1[PATH_MAX];
    snprintf(exe1, sizeof(exe1), "%s/gta_sa.exe", gamedata_path);
    snprintf(exe2, sizeof(exe2), "%s/gta-sa.exe", gamedata_path);
    snprintf(exe3, sizeof(exe3), "%s/GTA_SA.EXE", gamedata_path);
    snprintf(img1, sizeof(img1), "%s/models/gta3.img", gamedata_path);

    int has_baked_game = file_exists(exe1) || file_exists(exe2) || file_exists(exe3) || file_exists(img1);

    // Case 1: Game files are baked into Contents/Resources/GameData (standard install)
    if (has_baked_game) {
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
    // Launch SaifRuntime without arguments to show the interactive GUI folder selector.
    char *fallback_argv[] = { runtime_path, NULL };
    execv(runtime_path, fallback_argv);
    perror("macSA: Failed to launch SaifRuntime fallback");
    return 1;
}
