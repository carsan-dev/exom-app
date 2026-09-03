import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  AVAudioPlayerDelegate {
  private var restTimerPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    RestTimerCoordinator.register(
      with: engineBridge.applicationRegistrar.messenger(),
      onTimerFinished: { [weak self] in
        _ = self?.playRestTimerSound()
      }
    )
    let settingsChannel = FlutterMethodChannel(
      name: "com.exommethod.exom/app_settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    settingsChannel.setMethodCallHandler { call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
        result(
          FlutterError(
            code: "SETTINGS_URL_UNAVAILABLE",
            message: "Application settings URL is unavailable",
            details: nil
          )
        )
        return
      }
      UIApplication.shared.open(settingsURL) { opened in
        if opened {
          result(nil)
        } else {
          result(
            FlutterError(
              code: "SETTINGS_OPEN_FAILED",
              message: "Application settings could not be opened",
              details: nil
            )
          )
        }
      }
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.identifier.hasPrefix("exom.rest.") {
      guard RestTimerCoordinator.shouldPresentForegroundNotification(
        identifier: notification.request.identifier
      ) else {
        completionHandler([])
        return
      }
      let shouldPlaySound = notification.request.content.sound != nil
      if shouldPlaySound {
        completionHandler([.banner, .sound])
      } else {
        completionHandler([.banner])
      }
    } else {
      super.userNotificationCenter(
        center,
        willPresent: notification,
        withCompletionHandler: completionHandler
      )
    }
  }

  private func playRestTimerSound() -> Bool {
    guard
      let soundURL = Bundle.main.url(
        forResource: "exom_rest_finished",
        withExtension: "wav"
      ),
      let player = try? AVAudioPlayer(contentsOf: soundURL)
    else {
      return false
    }

    finishRestTimerPlayback()
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
      try audioSession.setActive(true)
    } catch {
      // AVAudioPlayer can still succeed with the existing audio session.
    }
    restTimerPlayer = player
    player.delegate = self
    player.prepareToPlay()
    if player.play() {
      return true
    }
    finishRestTimerPlayback()
    return false
  }

  private func finishRestTimerPlayback() {
    restTimerPlayer?.stop()
    restTimerPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: [.notifyOthersOnDeactivation]
    )
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    if restTimerPlayer === player {
      finishRestTimerPlayback()
    }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    if restTimerPlayer === player {
      finishRestTimerPlayback()
    }
  }
}
