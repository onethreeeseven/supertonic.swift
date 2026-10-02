#pragma once
#include <stdint.h>
#include <stddef.h>

typedef struct SupertonicRuntime SupertonicRuntime;
typedef struct SupertonicSession SupertonicSession;
typedef struct SupertonicTensor SupertonicTensor;

SupertonicRuntime *supertonic_runtime_create(const char *library_path, char **error);
void supertonic_runtime_release(SupertonicRuntime *runtime);
SupertonicSession *supertonic_session_create(SupertonicRuntime *runtime, const char *path, int threads, char **error);
void supertonic_session_release(SupertonicSession *session);
SupertonicTensor *supertonic_tensor_create(SupertonicRuntime *runtime, const void *data, size_t byte_count, const int64_t *shape, size_t rank, int is_integer, char **error);
void supertonic_tensor_release(SupertonicTensor *tensor);
SupertonicTensor *supertonic_session_run(SupertonicSession *session, const char *const *names, SupertonicTensor *const *tensors, size_t count, const char *output, char **error);
const float *supertonic_tensor_floats(SupertonicTensor *tensor, size_t *count, char **error);
void supertonic_error_release(char *error);

#if defined(__linux__)
typedef struct SupertonicPlayback SupertonicPlayback;
SupertonicPlayback *supertonic_playback_create(const char *device_name, unsigned int sample_rate, char **error);
long supertonic_playback_write(SupertonicPlayback *playback, const float *samples, unsigned long count, char **error);
int supertonic_playback_finish(SupertonicPlayback *playback, char **error);
void supertonic_playback_stop(SupertonicPlayback *playback);
void supertonic_playback_release(SupertonicPlayback *playback);
#endif
