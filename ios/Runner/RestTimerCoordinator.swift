import ActivityKit
import Flutter
import UserNotifications

struct RestTimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let endsAt: Date
  }

  let sessionId: String
  let exerciseName: String
  let startedAt: Date
}

final class RestTimerCoordinator {
  private static let channelName = "com.exommethod.exom/rest_timer"
  private static let notificationPrefix = "exom.rest."
  private static let finishedSoundName = UNNotificationSoundName(
    rawValue: "exom_rest_finished.wav"
  )
  private static var notificationGeneration = 0
  private static var activeTimerId: String?
  private static var activeNotificationIdentifier: String?
  private static var activeSoundEnabled = false
  private static var suppressedForegroundNotifications = Set<String>()
  private static var onTimerFinished: (() -> Void)?

  static func register(
    with messenger: FlutterBinaryMessenger,
    onTimerFinished: @escaping () -> Void
  ) {
    self.onTimerFinished = onTimerFinished
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
        let soundEnabled = arguments["soundEnabled"] as? Bool ?? true
        let endsAt = Date(timeIntervalSince1970: endsAtMillis.doubleValue / 1000)
        start(id: id, exerciseName: exerciseName, endsAt: endsAt, soundEnabled: soundEnabled)
        result(nil)
      case "finish":
        guard
          let arguments = call.arguments as? [String: Any],
          let id = arguments["id"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
          return
        }
        finish(id: id)
        result(nil)
      case "cancel":
        cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func start(
    id: String,
    exerciseName: String,
    endsAt: Date,
    soundEnabled: Bool
  ) {
    notificationGeneration += 1
    let generation = notificationGeneration
    if let previousIdentifier = activeNotificationIdentifier {
      suppressedForegroundNotifications.insert(previousIdentifier)
    }
    let notificationIdentifier = notificationPrefix + id + "." + String(generation)
    activeTimerId = id
    activeNotificationIdentifier = notificationIdentifier
    activeSoundEnabled = soundEnabled
    endLiveActivities()
    requestNotificationPermissionContextually()
    scheduleFinishedNotification(
      identifier: notificationIdentifier,
      endsAt: endsAt,
      generation: generation,
      soundEnabled: soundEnabled
    )

    guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else {
      return
    }
    let attributes = RestTimerAttributes(
      sessionId: id,
      exerciseName: exerciseName,
      startedAt: Date()
    )
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
    notificationGeneration += 1
    let generation = notificationGeneration
    if let identifier = activeNotificationIdentifier {
      suppressedForegroundNotifications.insert(identifier)
    }
    activeTimerId = nil
    activeNotificationIdentifier = nil
    activeSoundEnabled = false
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let ids = requests.map(\.identifier).filter { $0.hasPrefix(notificationPrefix) }
      DispatchQueue.main.async {
        guard generation == notificationGeneration else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
      }
    }
    endLiveActivities()
  }

  private static func finish(id: String) {
    guard activeTimerId == id else { return }

    notificationGeneration += 1
    let finishedNotificationIdentifier = activeNotificationIdentifier
    if let identifier = finishedNotificationIdentifier {
      suppressedForegroundNotifications.insert(identifier)
      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: [identifier]
      )
    }
    let shouldPlaySound = activeSoundEnabled
    activeTimerId = nil
    activeNotificationIdentifier = nil
    activeSoundEnabled = false
    endLiveActivities()
    guard shouldPlaySound else { return }
    guard let identifier = finishedNotificationIdentifier else {
      onTimerFinished?()
      return
    }

    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { notifications in
      let wasAlreadyDelivered = notifications.contains {
        $0.request.identifier == identifier
      }
      DispatchQueue.main.async {
        guard !wasAlreadyDelivered else { return }
        onTimerFinished?()
      }
    }
  }

  static func shouldPresentForegroundNotification(identifier: String) -> Bool {
    guard identifier.hasPrefix(notificationPrefix) else { return true }
    if suppressedForegroundNotifications.remove(identifier) != nil {
      return false
    }
    if let activeIdentifier = activeNotificationIdentifier {
      guard identifier == activeIdentifier else { return false }
      activeTimerId = nil
      activeNotificationIdentifier = nil
      activeSoundEnabled = false
    }
    return true
  }

  private static func endLiveActivities() {
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

  private static func scheduleFinishedNotification(
    identifier: String,
    endsAt: Date,
    generation: Int,
    soundEnabled: Bool
  ) {
    guard endsAt > Date() else { return }
    let spanish = Locale.preferredLanguages.first?.hasPrefix("es") == true
    let content = UNMutableNotificationContent()
    content.title = spanish ? "Descanso terminado" : "Rest finished"
    content.body = spanish ? "Es hora de tu siguiente serie" : "Time for your next set"
    if soundEnabled {
      let bundledSound = Bundle.main.url(
        forResource: "exom_rest_finished",
        withExtension: "wav"
      )
      content.sound = bundledSound == nil
        ? .default
        : UNNotificationSound(named: finishedSoundName)
    }
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: max(1, endsAt.timeIntervalSinceNow),
      repeats: false
    )
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let staleIds = requests.map(\.identifier).filter { $0.hasPrefix(notificationPrefix) }
      DispatchQueue.main.async {
        guard generation == notificationGeneration else { return }
        center.removePendingNotificationRequests(withIdentifiers: staleIds)
        center.add(
          UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
          )
        )
      }
    }
  }
}
