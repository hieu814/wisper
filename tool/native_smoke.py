"""Exercise the real native ABI. Optional args: GGML model and mono PCM16 WAV."""
import ctypes
import json
import math
import sys
import wave
from pathlib import Path

lib = ctypes.CDLL(str(Path(sys.argv[1]).resolve()))
lib.fw_transcribe.argtypes = [ctypes.c_char_p, ctypes.POINTER(ctypes.c_float),
    ctypes.c_int32, ctypes.c_char_p, ctypes.c_int32, ctypes.c_int32]
lib.fw_transcribe.restype = ctypes.c_void_p
lib.fw_free.argtypes = [ctypes.c_void_p]
lib.fw_free.restype = None

def run(model, samples, language=b'en', threads=2):
    output = lib.fw_transcribe(model, samples, len(samples), language, threads, 0)
    assert output, 'Unexpected allocation failure'
    try:
        return json.loads(ctypes.string_at(output).decode('utf-8'))
    finally:
        lib.fw_free(output)

samples = (ctypes.c_float * 16000)()
assert 'Could not load' in run(b'missing.bin', samples)['error']
assert 'Unknown language' in run(b'missing.bin', samples, b'zz')['error']
assert 'Invalid' in run(b'missing.bin', samples, threads=0)['error']
samples[0] = math.nan
assert 'PCM samples' in run(b'missing.bin', samples)['error']
samples[0] = 1.1
assert 'PCM samples' in run(b'missing.bin', samples)['error']
lib.fw_free(None)
if len(sys.argv) == 4:
    with wave.open(sys.argv[3], 'rb') as audio:
        assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, 16000)
        import array
        values = array.array('h', audio.readframes(audio.getnframes()))
        if sys.byteorder != 'little': values.byteswap()
        pcm = (ctypes.c_float * len(values))(*(n / 32768 for n in values))
    result = run(str(Path(sys.argv[2]).resolve()).encode(), pcm)
    assert 'error' not in result, result
    assert 'fellow americans' in result['text'].lower(), result
    assert result['segments'] and result['segments'][0]['endMs'] > 0
    print(result['text'])
print('Native ABI smoke checks passed')
