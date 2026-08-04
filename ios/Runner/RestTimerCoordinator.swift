import ActivityKit
import Flutter
import UserNotifications

struct RestTimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let endsAt: Date
  }

  let sessionId: String
  let exerciseName: String
}

final class RestTimerCoordinator {
  private static let channelName = "com.exommethod.exom/rest_timer"
  private static let notificationPrefix = "exom.rest."

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        guard
          let arguments = call.arguments as? [String: Any],
          let id = arguments["id"] as? String,
          let exerciseName = arguments["exerciseName"] as? String,
          let endsAtMillis = arguments["endsAtMillis"] as? NSNumber
        else {
          result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
          return
        }
        let endsAt = Date(timeIntervalSince1970: endsAtMillis.doubleValue / 1000)
        start(id: id, exerciseName: exerciseName, endsAt: endsAt)
        result(nil)
      case "cancel":
        cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func start(id: String, exerciseName: String, endsAt: Date) {
    cancel()
    requestNotificationPermissionContextually()
    scheduleFinishedNotification(id: id, endsAt: endsAt)

    guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else {
      return
    }
    let attributes = RestTimerAttributes(sessionId: id, exerciseName: exerciseName)
    do {
      _ = try Activity.request(
        attributes: attributes,
        contentState: RestTimerAttributes.ContentState(endsAt: endsAt),
        pushType: nil
      )
    } catch {
      // Local notification remains fallback when Live Activities are unavailable.
    }
  }

  private static func cancel() {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let ids = requests.map(\.identifier).filter { $0.hasPrefix(notificationPrefix) }
      center.removePendingNotificationRequests(withIdentifiers: ids)
    }
    if #available(iOS 16.1, *) {
      Task {
        for activity in Activity<RestTimerAttributes>.activities {
          await activity.end(using: nil, dismissalPolicy: .immediate)
        }
      }
    }
  }

  private static func requestNotificationPermissionContextually() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .notDetermined else { return }
      center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
  }

  private static func scheduleFinishedNotification(id: String, endsAt: Date) {
    guard endsAt > Date() else { return }
    let spanish = Locale.preferredLanguages.first?.hasPrefix("es") == true
    let content = UNMutableNotificationContent()
    content.title = spanish ? "Descanso terminado" : "Rest finished"
    content.body = spanish ? "Es hora de tu siguiente serie" : "Time for your next set"
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: max(1, endsAt.timeIntervalSinceNow),
      repeats: false
    )
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(
        identifier: notificationPrefix + id,
        content: content,
        trigger: trigger
      )
    )
  }
}
