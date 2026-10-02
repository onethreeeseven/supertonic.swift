#include "CSupertonic.h"
#include "onnxruntime_c_api.h"
#if defined(__linux__)
#include <dlfcn.h>
#endif

struct SupertonicRuntime {
    const OrtApi *api;
    OrtEnv *environment;
    OrtAllocator *allocator;
    void *library;
};
struct SupertonicSession {
    SupertonicRuntime *runtime;
    OrtSession *value;
};
struct SupertonicTensor {
    SupertonicRuntime *runtime;
    OrtValue *value;
};

static int accept_status(SupertonicRuntime *runtime, OrtStatus *status, char **error) {
    if (!status) return 1;
    *error = strdup(runtime->api->GetErrorMessage(status));
    runtime->api->ReleaseStatus(status);
    return 0;
}

SupertonicRuntime *supertonic_runtime_create(const char *library_path, char **error) {
    SupertonicRuntime *runtime = calloc(1, sizeof(*runtime));
    if (!runtime) { *error = strdup("Cannot allocate ONNX runtime"); return NULL; }
#if defined(__linux__)
    runtime->library = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (!runtime->library) {
        *error = strdup(dlerror()); free(runtime); return NULL;
    }
    const OrtApiBase *(*get_api_base)(void) = dlsym(runtime->library, "OrtGetApiBase");
    if (!get_api_base) {
        *error = strdup("ONNX runtime does not export OrtGetApiBase");
        supertonic_runtime_release(runtime); return NULL;
    }
    runtime->api = get_api_base()->GetApi(ORT_API_VERSION);
#else
    runtime->api = OrtGetApiBase()->GetApi(ORT_API_VERSION);
#endif
    if (!runtime->api) {
        *error = strdup("ONNX runtime API version 24 is unavailable");
        supertonic_runtime_release(runtime); return NULL;
    }
    if (!accept_status(runtime, runtime->api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "Supertonic", &runtime->environment), error) ||
        !accept_status(runtime, runtime->api->GetAllocatorWithDefaultOptions(&runtime->allocator), error)) {
        supertonic_runtime_release(runtime); return NULL;
    }
    return runtime;
}

void supertonic_runtime_release(SupertonicRuntime *runtime) {
    if (!runtime) return;
    if (runtime->environment) runtime->api->ReleaseEnv(runtime->environment);
#if defined(__linux__)
    if (runtime->library) dlclose(runtime->library);
#endif
    free(runtime);
}

SupertonicSession *supertonic_session_create(SupertonicRuntime *runtime, const char *path, int threads, char **error) {
    OrtSessionOptions *options = NULL;
    if (!accept_status(runtime, runtime->api->CreateSessionOptions(&options), error)) return NULL;
    SupertonicSession *session = calloc(1, sizeof(*session));
    if (!session) { runtime->api->ReleaseSessionOptions(options); *error = strdup("Cannot allocate ONNX session"); return NULL; }
    session->runtime = runtime;
    int succeeded = accept_status(runtime, runtime->api->SetIntraOpNumThreads(options, threads), error) &&
        accept_status(runtime, runtime->api->SetSessionGraphOptimizationLevel(options, ORT_ENABLE_ALL), error) &&
        accept_status(runtime, runtime->api->CreateSession(runtime->environment, path, options, &session->value), error);
    runtime->api->ReleaseSessionOptions(options);
    if (!succeeded) { supertonic_session_release(session); return NULL; }
    return session;
}

void supertonic_session_release(SupertonicSession *session) {
    if (!session) return;
    if (session->value) session->runtime->api->ReleaseSession(session->value);
    free(session);
}

SupertonicTensor *supertonic_tensor_create(SupertonicRuntime *runtime, const void *data, size_t byte_count, const int64_t *shape, size_t rank, int is_integer, char **error) {
    SupertonicTensor *tensor = calloc(1, sizeof(*tensor));
    if (!tensor) { *error = strdup("Cannot allocate ONNX tensor"); return NULL; }
    tensor->runtime = runtime;
    ONNXTensorElementDataType type = is_integer ? ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 : ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
    void *destination = NULL;
    if (!accept_status(runtime, runtime->api->CreateTensorAsOrtValue(runtime->allocator, shape, rank, type, &tensor->value), error) ||
        !accept_status(runtime, runtime->api->GetTensorMutableData(tensor->value, &destination), error)) {
        supertonic_tensor_release(tensor); return NULL;
    }
    OrtTensorTypeAndShapeInfo *information = NULL;
    size_t element_count = 0;
    if (!accept_status(runtime, runtime->api->GetTensorTypeAndShape(tensor->value, &information), error)) {
        supertonic_tensor_release(tensor); return NULL;
    }
    int has_count = accept_status(runtime, runtime->api->GetTensorShapeElementCount(information, &element_count), error);
    runtime->api->ReleaseTensorTypeAndShapeInfo(information);
    size_t element_size = is_integer ? sizeof(int64_t) : sizeof(float);
    if (!has_count || element_count > SIZE_MAX / element_size || byte_count != element_count * element_size) {
        if (has_count) *error = strdup("ONNX tensor byte count does not match its shape");
        supertonic_tensor_release(tensor); return NULL;
    }
    memcpy(destination, data, byte_count);
    return tensor;
}

void supertonic_tensor_release(SupertonicTensor *tensor) {
    if (!tensor) return;
    if (tensor->value) tensor->runtime->api->ReleaseValue(tensor->value);
    free(tensor);
}

SupertonicTensor *supertonic_session_run(SupertonicSession *session, const char *const *names, SupertonicTensor *const *tensors, size_t count, const char *output, char **error) {
    const OrtValue **values = calloc(count, sizeof(*values));
    SupertonicTensor *result = calloc(1, sizeof(*result));
    if (!values || !result) { free(values); free(result); *error = strdup("Cannot allocate ONNX inference inputs"); return NULL; }
    result->runtime = session->runtime;
    for (size_t index = 0; index < count; index++) values[index] = tensors[index]->value;
    int succeeded = accept_status(session->runtime, session->runtime->api->Run(session->value, NULL, names, values, count, &output, 1, &result->value), error);
    free(values);
    if (!succeeded) { supertonic_tensor_release(result); return NULL; }
    return result;
}

const float *supertonic_tensor_floats(SupertonicTensor *tensor, size_t *count, char **error) {
    OrtTensorTypeAndShapeInfo *information = NULL;
    void *data = NULL;
    SupertonicRuntime *runtime = tensor->runtime;
    if (!accept_status(runtime, runtime->api->GetTensorTypeAndShape(tensor->value, &information), error)) return NULL;
    ONNXTensorElementDataType type;
    int succeeded = accept_status(runtime, runtime->api->GetTensorElementType(information, &type), error) &&
        accept_status(runtime, runtime->api->GetTensorShapeElementCount(information, count), error);
    runtime->api->ReleaseTensorTypeAndShapeInfo(information);
    if (!succeeded) return NULL;
    if (type != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) { *error = strdup("ONNX output is not a Float32 tensor"); return NULL; }
    if (!accept_status(runtime, runtime->api->GetTensorMutableData(tensor->value, &data), error)) return NULL;
    return data;
}

void supertonic_error_release(char *error) { free(error); }
