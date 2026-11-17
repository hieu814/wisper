#include "flutter_whisper_cpp.h"
#include "whisper.h"
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <exception>

namespace {
std::string quote(const char * value) {
    std::string out = "\"";
    const char * hex = "0123456789abcdef";
    for (const unsigned char * p = reinterpret_cast<const unsigned char *>(value); *p; ++p) {
        if (*p == '"' || *p == '\\') { out += '\\'; out += static_cast<char>(*p); }
        else if (*p < 32) { out += "\\u00"; out += hex[*p >> 4]; out += hex[*p & 15]; }
        else { out += static_cast<char>(*p); }
    }
    return out + "\"";
}
char * copy(const std::string & value) {
    auto * out = static_cast<char *>(std::malloc(value.size() + 1));
    if (out) std::memcpy(out, value.c_str(), value.size() + 1);
    return out;
}
char * error(const char * message) { return copy("{\"error\":" + quote(message) + "}"); }
}

char * fw_transcribe(const char * model, const float * samples, int32_t count,
                    const char * language, int32_t threads, int32_t translate) {
    try {
        if (!model || !*model || !samples || count <= 0 || threads < 1 || threads > 64 || !language)
            return error("Invalid transcription arguments");
        for (int32_t i = 0; i < count; ++i)
            if (!std::isfinite(samples[i]) || samples[i] < -1 || samples[i] > 1)
                return error("PCM samples must be finite and normalized to [-1, 1]");
        if (std::strcmp(language, "auto") != 0 && whisper_lang_id(language) < 0)
            return error("Unknown language code");
        auto cp = whisper_context_default_params();
        cp.use_gpu = false;
        std::unique_ptr<whisper_context, decltype(&whisper_free)> ctx(
            whisper_init_from_file_with_params(model, cp), whisper_free);
        if (!ctx) return error("Could not load Whisper GGML model");
        if (!whisper_is_multilingual(ctx.get()) &&
            (translate || (std::strcmp(language, "auto") && std::strcmp(language, "en"))))
            return error("This request requires a multilingual model");
        auto p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        p.n_threads = threads;
        p.language = language;
        p.translate = translate != 0;
        p.no_context = true;
        p.print_realtime = false;
        p.print_progress = false;
        p.print_timestamps = false;
        p.print_special = false;
        if (whisper_full(ctx.get(), p, samples, count) != 0)
            return error("Whisper inference failed");
        std::string segments = "[", text;
        for (int i = 0; i < whisper_full_n_segments(ctx.get()); ++i) {
            const auto * segment = whisper_full_get_segment_text(ctx.get(), i);
            text += segment;
            if (i) segments += ',';
            segments += "{\"text\":" + quote(segment) + ",\"startMs\":" +
                std::to_string(whisper_full_get_segment_t0(ctx.get(), i) * 10) +
                ",\"endMs\":" + std::to_string(whisper_full_get_segment_t1(ctx.get(), i) * 10) + "}";
        }
        const auto * detected = whisper_lang_str(whisper_full_lang_id(ctx.get()));
        return copy("{\"text\":" + quote(text.c_str()) + ",\"language\":" +
            quote(detected ? detected : "en") + ",\"segments\":" + segments + "]}");
    } catch (const std::exception & e) { return error(e.what()); }
      catch (...) { return error("Unexpected native error"); }
}
void fw_free(void * pointer) { std::free(pointer); }
