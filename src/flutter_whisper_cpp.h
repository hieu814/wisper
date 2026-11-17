#pragma once
#include <stdint.h>
#if defined(_WIN32)
#define FW_API __declspec(dllexport)
#else
#define FW_API __attribute__((visibility("default"))) __attribute__((used))
#endif
#ifdef __cplusplus
extern "C" {
#endif
// Returned UTF-8 JSON is owned by the caller; release using fw_free.
FW_API char * fw_transcribe(const char * model, const float * samples,
    int32_t count, const char * language, int32_t threads, int32_t translate);
FW_API void fw_free(void * pointer);
#ifdef __cplusplus
}
#endif
