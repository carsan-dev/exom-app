import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P-LOGO-2: the status-bar icon must be the monochrome `ic_stat_exom`
/// drawable, never the opaque launcher mipmap (Android paints it as a white
/// square).
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('local notifications init uses ic_stat_exom, not the launcher icon', () {
    final source = read('lib/core/services/local_notification_service.dart');
    expect(
      source,
      contains("AndroidInitializationSettings('@drawable/ic_stat_exom')"),
    );
    expect(source, isNot(contains('ic_launcher')));
  });

  test('monochrome drawable exists and is white-on-transparent only', () {
    final file = File('android/app/src/main/res/drawable/ic_stat_exom.xml');
    expect(file.existsSync(), isTrue);
    final xml = file.readAsStringSync();
    expect(xml, contains('android:width="24dp"'));
    expect(xml, contains('android:height="24dp"'));
    final colours = RegExp(
      r'android:(?:fillColor|strokeColor)="([^"]+)"',
    ).allMatches(xml).map((m) => m.group(1)).toSet();
    expect(colours, {'#FFFFFFFF'});
  });

  test('FCM default notification icon points to ic_stat_exom', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains('com.google.firebase.messaging.default_notification_icon'),
    );
    expect(manifest, contains('@drawable/ic_stat_exom'));
  });

  test('release shrinker keeps ic_stat_exom', () {
    final keep = read('android/app/src/main/res/raw/keep.xml');
    expect(keep, contains('tools:keep="@drawable/ic_stat_exom"'));
  });

  test('foreground rest timer notification uses ic_stat_exom', () {
    final kt = read(
      'android/app/src/main/kotlin/com/exommethod/exom/RestTimerService.kt',
    );
    expect(kt, contains('R.drawable.ic_stat_exom'));
    expect(kt, isNot(contains('R.mipmap.ic_launcher')));
  });
}
