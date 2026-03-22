# exom_app

Flutter app for EXOM.

## Android dev

For physical Android devices, use the helper script to configure `adb reverse`
before `flutter run`:

```bat
scripts\run-android-dev.cmd
```

Useful variants:

```bat
scripts\run-android-dev.cmd -DeviceId RZGYA0Q2ADV
scripts\run-android-dev.cmd -SkipRun
scripts\run-android-dev.cmd --dart-define=EXOM_API_BASE_URL=http://192.168.1.20:3000/api/v1
```

By default the script:

- picks the first connected Android device in `adb devices`
- runs `adb reverse tcp:3000 tcp:3000`
- starts `flutter run -d <device>`
