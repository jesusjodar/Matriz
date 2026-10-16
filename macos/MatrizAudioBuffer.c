#include "MatrizAudioBuffer.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#define CAPACITY 16384u
struct MatrizAudioBuffer {
    _Atomic uint64_t read, write;
    uint32_t channels, bits, flags;
    float samples[];
};
MatrizAudioBuffer *MatrizAudioBufferCreate(uint32_t channels, uint32_t bits, uint32_t flags) {
    if (!channels || channels > 8) return NULL;
    MatrizAudioBuffer *b = calloc(1, sizeof(*b) + CAPACITY * channels * sizeof(float));
    if (b) { atomic_init(&b->read, 0); atomic_init(&b->write, 0); b->channels = channels; b->bits = bits; b->flags = flags; }
    return b;
}
void MatrizAudioBufferDestroy(MatrizAudioBuffer *b) { free(b); }
void MatrizAudioBufferWrite(MatrizAudioBuffer *b, const AudioBufferList *input) {
    if (!b || !input || !input->mNumberBuffers) return;
    uint32_t frames = UINT32_MAX, channels = 0, bytes = b->bits / 8;
    for (uint32_t i = 0; i < input->mNumberBuffers; i++) {
        const AudioBuffer *p = &input->mBuffers[i];
        if (!p->mData || !p->mNumberChannels || !bytes) return;
        uint32_t count = p->mDataByteSize / (bytes * p->mNumberChannels);
        if (count < frames) frames = count;
        channels += p->mNumberChannels;
    }
    if (channels != b->channels || !frames || frames > CAPACITY) return;
    uint64_t w = atomic_load_explicit(&b->write, memory_order_relaxed);
    uint64_t r = atomic_load_explicit(&b->read, memory_order_acquire);
    if (w - r + frames > CAPACITY) return; // Drop a block rather than overwrite samples being read.
    for (uint32_t f = 0; f < frames; f++) {
        uint32_t c = 0;
        for (uint32_t i = 0; i < input->mNumberBuffers; i++) {
            const AudioBuffer *p = &input->mBuffers[i];
            for (uint32_t j = 0; j < p->mNumberChannels; j++, c++) {
                const char *address = (const char *)p->mData + (f * p->mNumberChannels + j) * bytes;
                float value = 0;
                if (b->flags & kAudioFormatFlagIsFloat) {
                    if (b->bits == 32) memcpy(&value, address, 4);
                    else if (b->bits == 64) { double v; memcpy(&v, address, 8); value = (float)v; }
                } else if (b->bits == 16) { int16_t v; memcpy(&v, address, 2); value = v / 32768.0f; }
                else if (b->bits == 32) { int32_t v; memcpy(&v, address, 4); value = v / 2147483648.0f; }
                b->samples[((w + f) % CAPACITY) * channels + c] = isfinite(value) ? value : 0;
            }
        }
    }
    atomic_store_explicit(&b->write, w + frames, memory_order_release);
}
uint32_t MatrizAudioBufferRead(MatrizAudioBuffer *b, float *destination, uint32_t maxFrames) {
    uint64_t r = atomic_load_explicit(&b->read, memory_order_relaxed);
    uint64_t w = atomic_load_explicit(&b->write, memory_order_acquire);
    uint32_t count = (uint32_t)(w - r);
    if (count > maxFrames) { count = maxFrames; r = w - count; }
    for (uint32_t f = 0; f < count; f++)
        memcpy(destination + f * b->channels, b->samples + ((r + f) % CAPACITY) * b->channels,
               b->channels * sizeof(float));
    atomic_store_explicit(&b->read, w, memory_order_release);
    return count;
}
OSStatus MatrizAudioIOProc(AudioDeviceID device, const AudioTimeStamp *now,
    const AudioBufferList *input, const AudioTimeStamp *inputTime,
    AudioBufferList *output, const AudioTimeStamp *outputTime, void *context) {
    MatrizAudioBufferWrite(context, input);
    return noErr;
}
