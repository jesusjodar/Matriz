#pragma once
#include <CoreAudio/AudioHardware.h>
#include <stdint.h>
typedef struct MatrizAudioBuffer MatrizAudioBuffer;
MatrizAudioBuffer * _Nullable MatrizAudioBufferCreate(uint32_t channels, uint32_t bits, uint32_t flags);
void MatrizAudioBufferDestroy(MatrizAudioBuffer * _Nonnull buffer);
uint32_t MatrizAudioBufferRead(MatrizAudioBuffer * _Nonnull buffer, float * _Nonnull destination, uint32_t maxFrames);
OSStatus MatrizAudioIOProc(AudioDeviceID device, const AudioTimeStamp * _Nonnull now,
    const AudioBufferList * _Nonnull input, const AudioTimeStamp * _Nonnull inputTime,
    AudioBufferList * _Nonnull output, const AudioTimeStamp * _Nonnull outputTime, void * _Nullable context);
// The same writer is used by the synthetic checks; it never allocates or waits.
void MatrizAudioBufferWrite(MatrizAudioBuffer * _Nonnull buffer, const AudioBufferList * _Nullable input);
