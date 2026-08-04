import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let endsAt: Date
  }

  let sessionId: String
  let exerciseName: String
}

struct RestTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestTimerAttributes.self) { context in
      HStack(spacing: 14) {
        Image(systemName: "timer")
          .font(.title2.bold())
          .foregroundStyle(Color(red: 0.84, green: 0.96, blue: 0.54))
        VStack(alignment: .leading, spacing: 3) {
          Text(localized("Descanso", "Rest time"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(context.attributes.exerciseName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
        }
        Spacer()
        countdown(until: context.state.endsAt)
          .font(.title2.monospacedDigit().bold())
      }
      .padding()
      .activityBackgroundTint(Color(red: 0.14, green: 0.07, blue: 0.04))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(localized("Descanso", "Rest"), systemImage: "timer")
            .foregroundStyle(Color(red: 0.84, green: 0.96, blue: 0.54))
        }
        DynamicIslandExpandedRegion(.trailing) {
          countdown(until: context.state.endsAt)
            .monospacedDigit()
            .font(.headline.bold())
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.attributes.exerciseName)
            .lineLimit(1)
            .font(.subheadline.weight(.semibold))
        }
      } compactLeading: {
        Image(systemName: "timer")
          .foregroundStyle(Color(red: 0.84, green: 0.96, blue: 0.54))
      } compactTrailing: {
        countdown(until: context.state.endsAt)
          .monospacedDigit()
          .frame(maxWidth: 44)
      } minimal: {
        Image(systemName: "timer")
          .foregroundStyle(Color(red: 0.84, green: 0.96, blue: 0.54))
      }
      .keylineTint(Color(red: 0.84, green: 0.96, blue: 0.54))
    }
  }

  private func countdown(until date: Date) -> Text {
    Text(timerInterval: Date()...date, countsDown: true)
  }

  private func localized(_ spanish: String, _ english: String) -> String {
    Locale.current.language.languageCode?.identifier == "es" ? spanish : english
  }
}
