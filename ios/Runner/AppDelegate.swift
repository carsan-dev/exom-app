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
      with: engineBridge.applicationRegistrar.messenger()
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.identifier.hasPrefix("exom.rest.") {
      let shouldPlaySound = notification.request.content.sound != nil
      if shouldPlaySound, playRestTimerSound() {
        completionHandler([.banner])
      } else if shouldPlaySound {
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

    restTimerPlayer?.stop()
    restTimerPlayer = player
    player.delegate = self
    player.prepareToPlay()
    if player.play() {
      return true
    }
    restTimerPlayer = nil
    return false
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    if restTimerPlayer === player {
      restTimerPlayer = nil
    }
  }
}
