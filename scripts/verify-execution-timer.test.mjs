import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');
const android = 'android/app/src/main/';
const kotlin = `${android}kotlin/com/exommethod/exom/`;

test('Android execution uses separate component, channels, notification ids and player instances', () => {
  const service = read(`${kotlin}ExecutionTimerService.kt`);
  assert.match(service, /class ExecutionTimerService : RestTimerService\(\)/);
  for (const identity of ['exom_execution_timer', 'exom_execution_finished_v1', '41022', '41023']) {
    assert.ok(service.includes(identity), identity);
  }
  assert.match(service, /removeLegacyRestChannels = false/);
  assert.match(service, /suppressExpiredStart = true/);
  assert.match(service, /soundResource = R.raw.exom_execution_finished/);
  const rest = read(`${kotlin}RestTimerService.kt`);
  assert.match(rest, /private var completionPlayer: MediaPlayer\?/);
  assert.match(rest, /soundResource = R.raw.exom_rest_finished/);
  assert.match(rest, /ONGOING_NOTIFICATION_ID = 41020/);
  assert.match(rest, /FINISHED_NOTIFICATION_ID = 41021/);
  assert.match(rest, /setSound\(null, null\)/);
  assert.match(rest, /if \(removeLegacyRestChannels\)/);
  assert.match(rest, /intent.getStringExtra\(EXTRA_SESSION_ID\) == sessionId/);
  assert.match(rest, /ACTION_CANCEL\) {[\s\S]*?timerFinished = true[\s\S]*?handler.removeCallbacks\(tickRunnable\)[\s\S]*?releaseCompletionPlayer\(\)/);
  assert.match(rest, /if \(suppressExpiredStart\) stopTimerService\(\) else finishTimer\(\)/);
  const manifest = read(`${android}AndroidManifest.xml`);
  assert.match(manifest, /name="\.ExecutionTimerService"\s+android:exported="false"\s+android:foregroundServiceType="specialUse"/);
  const activity = read(`${kotlin}MainActivity.kt`);
  assert.match(activity, /com.exommethod.exom\/execution_timer/);
  assert.equal((activity.match(/Intent\(this, ExecutionTimerService::class.java\)/g) ?? []).length, 2);
  assert.match(activity, /action = RestTimerService.ACTION_CANCEL/);
});

test('iOS expiry is a distinct scheduled notification without generic-sound fallback or Dart playback', () => {
  const coordinator = read('ios/Runner/ExecutionTimerCoordinator.swift');
  assert.match(coordinator, /prefix = "exom.execution."/);
  assert.match(coordinator, /UNTimeIntervalNotificationTrigger/);
  assert.match(coordinator, /guard deadline > Date\(\)/);
  assert.match(coordinator, /guard run == activeRun/);
  assert.match(coordinator, /if expected != generation/);
  assert.match(coordinator, /suppressed.remove\(identifier\)/);
  assert.match(coordinator, /exom_execution_finished.wav/);
  assert.doesNotMatch(coordinator, /\.default|AVAudioPlayer|RestTimerCoordinator|ActivityKit/);
  const delegate = read('ios/Runner/AppDelegate.swift');
  assert.match(delegate, /ExecutionTimerCoordinator.register/);
  assert.match(delegate, /ExecutionTimerCoordinator.shouldPresentForegroundNotification/);
  const project = read('ios/Runner.xcodeproj/project.pbxproj');
  assert.match(project, /ExecutionTimerCoordinator.swift in Sources/);
  assert.match(project, /exom_execution_finished.wav in Resources/);
  for (const path of ['lib/core/services/execution_timer_coordinator.dart',
    'lib/features/trainings/presentation/widgets/execution_timer.dart']) {
    assert.doesNotMatch(read(path), /invokeMethod.*finish|AudioPlayer|playSound/);
  }
});

test('original single 880 Hz attack WAV is identical on both platforms; rest audio is preserved', () => {
  const paths = [`${android}res/raw/exom_execution_finished.wav`, 'ios/Runner/exom_execution_finished.wav'];
  const buffers = paths.map((path) => readFileSync(new URL(`../${path}`, import.meta.url)));
  assert.deepEqual(buffers[0], buffers[1]);
  const wav = buffers[0];
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wav.toString('ascii', 8, 12), 'WAVE');
  assert.equal(wav.readUInt16LE(20), 1);
  assert.equal(wav.readUInt16LE(22), 1);
  assert.equal(wav.readUInt32LE(24), 44100);
  assert.equal(wav.readUInt16LE(34), 16);
  const samples = Array.from({ length: (wav.length - 44) / 2 }, (_, i) => wav.readInt16LE(44 + i * 2));
  assert.ok(Math.max(...samples.map(Math.abs)) <= 26870);
  const active = [];
  for (let i = 0; i < samples.length; i += 441) active.push(samples.slice(i, i + 441).some((x) => Math.abs(x) > 500));
  assert.equal(active.filter((x, i) => x && !active[i - 1]).length, 1);
  const energy = (frequency) => {
    let sin = 0, cos = 0;
    samples.forEach((sample, i) => {
      const phase = 2 * Math.PI * frequency * i / 44100;
      sin += sample * Math.sin(phase); cos += sample * Math.cos(phase);
    });
    return sin * sin + cos * cos;
  };
  assert.ok(energy(880) > 20 * energy(1175));
  for (const path of [`${android}res/raw/exom_rest_finished.wav`, 'ios/Runner/exom_rest_finished.wav']) {
    const hash = createHash('sha256').update(readFileSync(new URL(`../${path}`, import.meta.url))).digest('hex');
    assert.equal(hash, 'ed8e01c7b81849c36692827e9b5c641e32d725322d4842e268573309741a3ec9');
  }
});

test('countdown localization files have no duplicate keys', () => {
  for (const language of ['en', 'es']) {
    const arb = read(`lib/l10n/app_${language}.arb`);
    for (const key of ['executionPrepareTitle', 'executionPrepareBody', 'executionPrepareCountdown', 'executionPrepareCancel']) {
      assert.equal((arb.match(new RegExp(`"${key}"\\s*:`, 'g')) ?? []).length, 1);
    }
  }
});
