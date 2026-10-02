#include "CSupertonic.h"
#if defined(__linux__) && !defined(__ANDROID__)
#include <dlfcn.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>

struct SupertonicPlayback {
    void *library;
    void *device;
    int (*open_device)(void **, const char *, int, int);
    int (*configure_device)(void *, int, int, unsigned int, unsigned int, int, unsigned int);
    long (*write_samples)(void *, const void *, unsigned long);
    int (*recover_device)(void *, int, int);
    int (*drain_device)(void *);
    int (*set_nonblocking)(void *, int);
    int (*drop_device)(void *);
    int (*close_device)(void *);
    int (*find_format)(const char *);
    const char *(*describe_error)(int);
};

static int load_playback_functions(SupertonicPlayback *playback, char **error) {
    playback->open_device = dlsym(playback->library, "snd_pcm_open");
    playback->configure_device = dlsym(playback->library, "snd_pcm_set_params");
    playback->write_samples = dlsym(playback->library, "snd_pcm_writei");
    playback->recover_device = dlsym(playback->library, "snd_pcm_recover");
    playback->drain_device = dlsym(playback->library, "snd_pcm_drain");
    playback->set_nonblocking = dlsym(playback->library, "snd_pcm_nonblock");
    playback->drop_device = dlsym(playback->library, "snd_pcm_drop");
    playback->close_device = dlsym(playback->library, "snd_pcm_close");
    playback->find_format = dlsym(playback->library, "snd_pcm_format_value");
    playback->describe_error = dlsym(playback->library, "snd_strerror");
    if (playback->open_device && playback->configure_device && playback->write_samples &&
        playback->recover_device && playback->drain_device && playback->drop_device &&
        playback->close_device && playback->find_format && playback->describe_error && playback->set_nonblocking) return 1;
    *error = strdup("ALSA playback functions are unavailable");
    return 0;
}

static int accept_playback_status(SupertonicPlayback *playback, int status, char **error) {
    if (status >= 0) return 1;
    *error = strdup(playback->describe_error(status));
    return 0;
}

SupertonicPlayback *supertonic_playback_create(const char *device_name, unsigned int sample_rate, char **error) {
    SupertonicPlayback *playback = calloc(1, sizeof(*playback));
    if (!playback) { *error = strdup("Cannot allocate audio playback"); return NULL; }
    playback->library = dlopen("libasound.so.2", RTLD_NOW | RTLD_LOCAL);
    if (!playback->library) {
        *error = strdup("Linux playback requires the system ALSA library (libasound.so.2)");
        supertonic_playback_release(playback);
        return NULL;
    }
    if (!load_playback_functions(playback, error)) {
        supertonic_playback_release(playback);
        return NULL;
    }
    int format = playback->find_format("FLOAT_LE");
    if (!accept_playback_status(playback, playback->open_device(&playback->device, device_name, 0, 0), error) ||
        !accept_playback_status(playback, playback->configure_device(playback->device, format, 3, 1, sample_rate, 1, 100000), error)) {
        supertonic_playback_release(playback);
        return NULL;
    }
    return playback;
}

long supertonic_playback_write(SupertonicPlayback *playback, const float *samples, unsigned long count, char **error) {
    long written = playback->write_samples(playback->device, samples, count);
    if (written < 0) {
        int recovered = playback->recover_device(playback->device, (int)written, 1);
        if (!accept_playback_status(playback, recovered, error)) return -1;
        written = playback->write_samples(playback->device, samples, count);
    }
    if (written <= 0) {
        if (written == 0) *error = strdup("Audio device made no playback progress");
        else *error = strdup(playback->describe_error((int)written));
        return -1;
    }
    return written;
}

int supertonic_playback_finish(SupertonicPlayback *playback, char **error) {
    if (!accept_playback_status(playback, playback->set_nonblocking(playback->device, 1), error)) return -1;
    int status = playback->drain_device(playback->device);
    if (status == -EAGAIN) return 0;
    return accept_playback_status(playback, status, error) ? 1 : -1;
}

void supertonic_playback_stop(SupertonicPlayback *playback) {
    if (playback && playback->device) playback->drop_device(playback->device);
}

void supertonic_playback_release(SupertonicPlayback *playback) {
    if (!playback) return;
    if (playback->device && playback->close_device) playback->close_device(playback->device);
    if (playback->library) dlclose(playback->library);
    free(playback);
}
#endif
