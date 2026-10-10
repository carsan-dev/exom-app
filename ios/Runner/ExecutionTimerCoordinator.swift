import Flutter
import UserNotifications

/// Independent notification identity; rest Live Activities remain untouched.
enum ExecutionTimerCoordinator {
  private static let prefix = "exom.execution."
  private static var generation = 0
  private static var activeRun: String?
  private static var activeIdentifier: String?
  private static var suppressed = Set<String>()

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.exommethod.exom/execution_timer", binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any], let run = args["id"] as? String else {
        result(FlutterError(code: "INVALID_TIMER", message: "Missing run identity", details: nil))
        return
      }
      switch call.method {
      case "start":
        guard let millis = args["endsAtMillis"] as? NSNumber else {
          result(FlutterError(code: "INVALID_TIMER", message: "Missing deadline", details: nil))
          return
        }
        start(run: run, deadline: Date(timeIntervalSince1970: millis.doubleValue / 1000),
              sound: args["soundEnabled"] as? Bool ?? true, result: result)
      case "cancel":
        cancel(run: run)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func start(run: String, deadline: Date, sound: Bool, result: @escaping FlutterResult) {
    guard deadline > Date() else { result(nil); return }
    generation += 1
    let expected = generation
    if let previous = activeIdentifier { suppressed.insert(previous) }
    let identifier = prefix + UUID().uuidString
    activeRun = run
    activeIdentifier = identifier
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
      center.getPendingNotificationRequests { pending in
        DispatchQueue.main.async {
          guard expected == generation, deadline > Date() else { result(nil); return }
          center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
          )
          let content = UNMutableNotificationContent()
          let spanish = Locale.preferredLanguages.first?.hasPrefix("es") == true
          content.title = spanish ? "Tiempo del ejercicio finalizado" : "Exercise time finished"
          content.body = spanish ? "Registra la serie cuando estés listo." : "Record the set when you are ready."
          // Muted or unavailable custom audio never falls back to an OS tone.
          if sound, Bundle.main.url(forResource: "exom_execution_finished", withExtension: "wav") != nil {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("exom_execution_finished.wav"))
          }
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(0.1, deadline.timeIntervalSinceNow), repeats: false)
          let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
          center.add(request) { error in
            DispatchQueue.main.async {
              if expected != generation {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
              }
              result(error.map { FlutterError(code: "TIMER_NOTIFICATION", message: $0.localizedDescription, details: nil) })
            }
          }
        }
      }
    }
  }

  private static func cancel(run: String) {
    guard run == activeRun else { return }
    generation += 1
    if let identifier = activeIdentifier {
      suppressed.insert(identifier)
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    activeRun = nil
    activeIdentifier = nil
  }

  static func shouldPresentForegroundNotification(identifier: String) -> Bool {
    if suppressed.remove(identifier) != nil { return false }
    guard identifier == activeIdentifier else { return false }
    activeRun = nil
    activeIdentifier = nil
    return true
  }
}
