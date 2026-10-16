using System.Diagnostics;
using NAudio.Wave;
using NAudio.Dsp;
using Windows.Media.Control;
using Windows.Storage.Streams;

namespace Matriz;

public sealed class MediaService : IDisposable
{
    private readonly Action<string> error;
    private readonly Action<object> send;
    private WasapiLoopbackCapture? capture;
    private GlobalSystemMediaTransportControlsSessionManager? manager;
    private readonly object gate = new();
    private float[] samples = [], raw = new float[4];
    private readonly float[] reference = [.04f,.04f,.04f], output = new float[4];
    private int filled, channels, sampleRate;
    private double sampleAt = -1e9, tickAt = Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency, artworkAt;
    private float totalReference = .08f;
    private bool armed, active, artworkBusy, disposed;
    private string? artworkKey;
    private int generation;
    private SettingsStore? settings;
    public MediaService(Action<string> error, Action<object> send) { this.error = error; this.send = send; }
    private static double Now => Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;
    public void ArmAudio() { armed = true; }
    public void Update(SettingsStore value) { settings = value; SetActive(active, value); }
    public void SetActive(bool value, SettingsStore settings)
    {
        this.settings = settings; active = value;
        if (active && armed && settings.Enabled("audioEnabled") && capture == null) StartAudio();
        if ((!active || !settings.Enabled("audioEnabled")) && capture != null) StopAudio();
        if (active && settings.Enabled("artworkEnabled") && manager != null && !artworkBusy && Now - artworkAt > 2) _ = PollArtwork();
        if (!settings.Enabled("artworkEnabled") && artworkKey != null) { generation++; artworkKey = null; send(new { type = "artwork", base64 = (string?)null, mime = "image/png" }); }
        if (!active) generation++;
    }
    private void StartAudio()
    {
        try {
            var next = new WasapiLoopbackCapture();
            channels = next.WaveFormat.Channels; sampleRate = next.WaveFormat.SampleRate; filled = 0;
            var floating = next.WaveFormat.Encoding == WaveFormatEncoding.IeeeFloat || next.WaveFormat is WaveFormatExtensible format && format.SubFormat == new Guid("00000003-0000-0010-8000-00aa00389b71");
            if (channels < 1 || channels > 32 || next.WaveFormat.BitsPerSample != 32 || !floating) { next.Dispose(); throw new NotSupportedException("Audio loopback requires a 32-bit float output format."); }
            samples = new float[2048 * channels];
            next.DataAvailable += Samples;
            next.RecordingStopped += (_, e) => { if (e.Exception != null) error(e.Exception.Message); };
            capture = next; next.StartRecording();
        } catch (Exception e) { StopAudio(); error(e.Message); }
    }
    private void Samples(object? sender, WaveInEventArgs e)
    {
        if (sender != capture || disposed) return;
        var frames = e.BytesRecorded / (4 * channels);
        for (var frame = 0; frame < frames; frame++) {
            for (var channel = 0; channel < channels; channel++) {
                var value = BitConverter.ToSingle(e.Buffer, (frame * channels + channel) * 4);
                samples[filled * channels + channel] = float.IsFinite(value) ? value : 0;
            }
            if (++filled != 2048) continue;
            filled = 0; var bands = new double[3]; double energy = 0;
            for (var channel = 0; channel < channels; channel++) {
                var fft = new Complex[2048];
                for (var i = 0; i < 2048; i++) { var value = samples[i * channels + channel]; energy += value * value / (2048d * channels); fft[i].X = value * (float)(.5 * (1 - Math.Cos(2 * Math.PI * i / 2047))); }
                FastFourierTransform.FFT(true, 11, fft);
                for (var i = 1; i < 1024; i++) {
                    var frequency = i * sampleRate / 2048d; var band = frequency < 40 || frequency >= 10000 ? -1 : frequency < 250 ? 0 : frequency < 2000 ? 1 : 2;
                    if (band >= 0) bands[band] += (fft[i].X * fft[i].X + fft[i].Y * fft[i].Y) / channels;
                }
            }
            var rms = Math.Sqrt(energy); var total = Math.Max(1e-12, bands.Sum());
            lock (gate) { for (var i = 0; i < 3; i++) raw[i] = (float)(Math.Sqrt(bands[i] / total) * rms); raw[3] = (float)rms; sampleAt = Now; }
        }
    }
    public float[] Audio(SettingsStore settings)
    {
        var now = Now; var dt = Math.Clamp(now - tickAt, 0, .25); tickAt = now;
        float[] input; lock (gate) input = active && capture != null && now - sampleAt <= .2 ? (float[])raw.Clone() : new float[4];
        var gain = Math.Pow(10, settings.Number("audioSensitivity") / 20); var response = settings.Number("audioResponse");
        var target = new float[4];
        if (input[3] > .001) {
            var totalTarget = Math.Max(.0126, input[3]); totalReference += (float)((totalTarget - totalReference) * (1 - Math.Exp(-dt / (totalTarget > totalReference ? .5 : 10))));
            for (var i = 0; i < 3; i++) { var next = Math.Max(.009, input[i]); reference[i] += (float)((next - reference[i]) * (1 - Math.Exp(-dt / (next > reference[i] ? .4 : 6)))); target[i] = (float)Math.Clamp(input[i] * gain * (i == 1 ? .85 : 1.05) / reference[i], 0, 1); }
            target[3] = (float)Math.Clamp(input[3] * gain * .9 / totalReference, 0, 1);
        }
        for (var i = 0; i < 4; i++) output[i] += (float)((target[i] - output[i]) * (1 - Math.Exp(-dt / (target[i] > output[i] ? .015 + .065 * response : .15 + .65 * response))));
        return (float[])output.Clone();
    }
    public async Task ConnectArtwork()
    {
        try { manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync(); artworkKey = null; await PollArtwork(); }
        catch (Exception e) { error("Media session access: " + e.Message); }
    }
    private async Task PollArtwork()
    {
        if (manager == null || settings == null || artworkBusy) return;
        artworkBusy = true; artworkAt = Now; var version = generation;
        try {
            var session = manager.GetCurrentSession();
            if (session == null || session.GetPlaybackInfo().PlaybackStatus != GlobalSystemMediaTransportControlsSessionPlaybackStatus.Playing) {
                if (artworkKey != null) { artworkKey = null; send(new { type = "artwork", base64 = (string?)null, mime = "image/png" }); } return;
            }
            var properties = await session.TryGetMediaPropertiesAsync(); var key = session.SourceAppUserModelId + properties.Title + properties.AlbumTitle + properties.Artist;
            if (version != generation || disposed || !settings.Enabled("artworkEnabled") || key == artworkKey) return;
            if (properties.Thumbnail == null) { artworkKey = null; send(new { type = "artwork", base64 = (string?)null, mime = "image/png" }); return; }
            using var stream = await properties.Thumbnail.OpenReadAsync();
            if (stream.Size == 0 || stream.Size > 8 * 1024 * 1024 || !stream.ContentType.StartsWith("image/")) return;
            using var reader = new DataReader(stream); var length = await reader.LoadAsync((uint)stream.Size); var bytes = new byte[length]; reader.ReadBytes(bytes);
            if (version != generation || disposed || !active) return;
            artworkKey = key; send(new { type = "artwork", base64 = Convert.ToBase64String(bytes), mime = stream.ContentType });
        } catch (Exception e) { error(e.Message); }
        finally { artworkBusy = false; }
    }
    private void StopAudio()
    {
        var old = capture; capture = null;
        if (old != null) { old.DataAvailable -= Samples; try { old.StopRecording(); } finally { old.Dispose(); } }
        lock (gate) { Array.Clear(raw); sampleAt = -1e9; }
    }
    public void Dispose() { disposed = true; generation++; StopAudio(); manager = null; }
}
