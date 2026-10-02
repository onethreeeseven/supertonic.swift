#include "CSupertonic.h"
#if defined(__ANDROID__)
#include <aaudio/AAudio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

struct SupertonicPlayback {
    AAudioStream *stream;
    bool is_started;
};

static int accept_android_audio_status(aaudio_result_t status, char **error) {
    if (status >= 0) return 1;
    *error = strdup(AAudio_convertResultToText(status));
    return 0;
}

SupertonicPlayback *supertonic_playback_create(const char *device_name, unsigned int sample_rate, char **error) {
    SupertonicPlayback *playback = calloc(1, sizeof(*playback));
    if (!playback) { *error = strdup("Cannot allocate Android audio playback"); return NULL; }
    AAudioStreamBuilder *builder = NULL;
    if (!accept_android_audio_status(AAudio_createStreamBuilder(&builder), error)) {
        free(playback); return NULL;
    }
    AAudioStreamBuilder_setDirection(builder, AAUDIO_DIRECTION_OUTPUT);
    AAudioStreamBuilder_setSharingMode(builder, AAUDIO_SHARING_MODE_SHARED);
    AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_FLOAT);
    AAudioStreamBuilder_setChannelCount(builder, 1);
    AAudioStreamBuilder_setSampleRate(builder, (int32_t)sample_rate);
    aaudio_result_t status = AAudioStreamBuilder_openStream(builder, &playback->stream);
    AAudioStreamBuilder_delete(builder);
    if (!accept_android_audio_status(status, error)) {
        free(playback); return NULL;
    }
    return playback;
}

long supertonic_playback_write(SupertonicPlayback *playback, const float *samples, unsigned long count, char **error) {
    int64_t timeout = playback->is_started ? 100000000 : 0;
    aaudio_result_t written = AAudioStream_write(playback->stream, samples, (int32_t)count, timeout);
    if (!accept_android_audio_status(written, error)) return -1;
    if (written == 0) { *error = strdup("Android audio output made no playback progress"); return -1; }
    if (!playback->is_started) {
        if (!accept_android_audio_status(AAudioStream_requestStart(playback->stream), error)) return -1;
        playback->is_started = true;
    }
    return written;
}

int supertonic_playback_finish(SupertonicPlayback *playback, char **error) {
    if (AAudioStream_getState(playback->stream) == AAUDIO_STREAM_STATE_DISCONNECTED) {
        *error = strdup("Android audio output disconnected"); return -1;
    }
    return AAudioStream_getFramesRead(playback->stream) >= AAudioStream_getFramesWritten(playback->stream);
}

void supertonic_playback_stop(SupertonicPlayback *playback) {
    if (playback && playback->stream) AAudioStream_requestStop(playback->stream);
}

void supertonic_playback_release(SupertonicPlayback *playback) {
    if (!playback) return;
    if (playback->stream) AAudioStream_close(playback->stream);
    free(playback);
}
#endif
