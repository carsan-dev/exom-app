import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'generate_rest_finished_chime.dart' as rest;

const destinations = [
  'android/app/src/main/res/raw/exom_execution_finished.wav',
  'ios/Runner/exom_execution_finished.wav',
];

/// Original single bell attack, distinct from the two-attack rest cue.
void main(List<String> arguments) {
  final samples = Float64List((rest.sampleRate * 0.55).round());
  rest.addBellTone(
    samples,
    start: 0.04,
    length: 0.44,
    frequency: 880,
    amplitude: 0.75,
  );
  rest.applyGlobalFade(samples, fadeSeconds: 0.01);
  rest.normalize(samples, targetPeak: 0.82);
  final pcm = rest.convertToPcm16(samples);
  final wav = rest.buildWav(pcm);
  final header = ByteData.sublistView(wav);
  if (header.getUint16(20, Endian.little) != 1 ||
      header.getUint16(22, Endian.little) != 1 ||
      header.getUint32(24, Endian.little) != 44100 ||
      header.getUint16(34, Endian.little) != 16 ||
      pcm.map((sample) => sample.abs()).reduce(max) > 26870) {
    throw StateError('Invalid PCM format or peak');
  }
  // A single synthesis call is the only attack; inspect its active envelope.
  final activeWindows = <bool>[];
  for (var offset = 0; offset < pcm.length; offset += 441) {
    final window = pcm.sublist(offset, min(offset + 441, pcm.length));
    activeWindows.add(window.any((sample) => sample.abs() > 500));
  }
  var attacks = 0;
  var previous = false;
  for (final active in activeWindows) {
    if (active && !previous) attacks++;
    previous = active;
  }
  if (attacks != 1) throw StateError('Expected one attack, got $attacks');
  for (final destination in destinations) {
    final file = File(destination);
    if (arguments.contains('--check')) {
      final existing = file.readAsBytesSync();
      if (existing.length != wav.length ||
          List.generate(
            wav.length,
            (i) => existing[i] == wav[i],
          ).contains(false)) {
        throw StateError('Generated audio differs: $destination');
      }
    } else {
      file.writeAsBytesSync(wav);
    }
  }
  stdout.writeln(
    'PASS: single 880 Hz attack; mono PCM 44100 Hz/16 bit; identical copies (${wav.length} bytes).',
  );
}
