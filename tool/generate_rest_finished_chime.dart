import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 44100;
const double durationSeconds = 0.62;

const List<String> outputPaths = <String>[
  'android/app/src/main/res/raw/exom_rest_finished.wav',
  'ios/Runner/exom_rest_finished.wav',
];

void main() {
  final int sampleCount = (sampleRate * durationSeconds).round();

  // Se utiliza Float64List para poder sumar tonos y normalizar después
  // sin provocar saturación durante la generación.
  final Float64List audio = Float64List(sampleCount);

  addBellTone(
    audio,
    start: 0.04,
    length: 0.19,
    frequency: 880.0,
    amplitude: 0.58,
  );

  addBellTone(
    audio,
    start: 0.28,
    length: 0.28,
    frequency: 1175.0,
    amplitude: 0.78,
  );

  applyGlobalFade(audio, fadeSeconds: 0.01);
  normalize(audio, targetPeak: 0.90);

  final Int16List pcm = convertToPcm16(audio);
  final Uint8List wav = buildWav(pcm);

  for (final String path in outputPaths) {
    final File file = File(path);

    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(wav, flush: true);

    stdout.writeln('Generated $path (${wav.length} bytes)');
  }
}

void addBellTone(
  Float64List samples, {
  required double start,
  required double length,
  required double frequency,
  required double amplitude,
}) {
  final int startSample = (start * sampleRate).round();
  final int lengthSamples = (length * sampleRate).round();
  final int endSample = math.min(
    samples.length,
    startSample + lengthSamples,
  );

  const double attackSeconds = 0.012;
  const double decayRate = 5.2;

  for (var i = startSample; i < endSample; i++) {
    final double time = (i - startSample) / sampleRate;

    // Ataque rápido y lineal.
    final double attack = (time / attackSeconds).clamp(0.0, 1.0);

    // Caída exponencial tipo campana o marimba digital.
    final double decay = math.exp(
      -decayRate * time / length,
    );

    final double envelope = attack * decay;

    final double fundamentalPhase =
        2.0 * math.pi * frequency * time;

    final double secondHarmonicPhase =
        2.0 * math.pi * frequency * 2.01 * time;

    final double fourthHarmonicPhase =
        2.0 * math.pi * frequency * 3.97 * time;

    final double signal =
        math.sin(fundamentalPhase) +
        0.28 * math.sin(secondHarmonicPhase) +
        0.12 * math.sin(fourthHarmonicPhase);

    samples[i] += signal * envelope * amplitude;
  }
}

void applyGlobalFade(
  Float64List samples, {
  required double fadeSeconds,
}) {
  final int fadeSamples = math.min(
    samples.length ~/ 2,
    (sampleRate * fadeSeconds).round(),
  );

  if (fadeSamples <= 1) {
    return;
  }

  for (var i = 0; i < fadeSamples; i++) {
    final double progress = i / (fadeSamples - 1);

    samples[i] *= progress;
    samples[samples.length - 1 - i] *= progress;
  }
}

void normalize(
  Float64List samples, {
  required double targetPeak,
}) {
  double peak = 0.0;

  for (final double sample in samples) {
    final double absoluteValue = sample.abs();

    if (absoluteValue > peak) {
      peak = absoluteValue;
    }
  }

  if (peak == 0.0) {
    return;
  }

  final double normalizationGain = targetPeak / peak;

  for (var i = 0; i < samples.length; i++) {
    samples[i] *= normalizationGain;
  }
}

Int16List convertToPcm16(Float64List samples) {
  final Int16List pcm = Int16List(samples.length);

  for (var i = 0; i < samples.length; i++) {
    final double clamped = samples[i].clamp(-1.0, 1.0);
    pcm[i] = (clamped * 32767.0).round();
  }

  return pcm;
}

Uint8List buildWav(Int16List samples) {
  const int headerSize = 44;
  const int channelCount = 1;
  const int bitsPerSample = 16;
  const int bytesPerSample = bitsPerSample ~/ 8;

  final int dataSize = samples.length * bytesPerSample;
  final ByteData bytes = ByteData(headerSize + dataSize);

  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);

  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');

  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // Linear PCM
  bytes.setUint16(22, channelCount, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);

  final int byteRate =
      sampleRate * channelCount * bytesPerSample;

  final int blockAlign =
      channelCount * bytesPerSample;

  bytes.setUint32(28, byteRate, Endian.little);
  bytes.setUint16(32, blockAlign, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);

  writeAscii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(
      headerSize + i * bytesPerSample,
      samples[i],
      Endian.little,
    );
  }

  return bytes.buffer.asUint8List();
}