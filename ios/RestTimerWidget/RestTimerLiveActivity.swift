import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let endsAt: Date
  }

  let sessionId: String
  let exerciseName: String
  let startedAt: Date
}

private enum ExomLiveActivityStyle {
  static let lime = Color(red: 0.773, green: 0.890, blue: 0.518)
  static let cocoa = Color(red: 0.137, green: 0.071, blue: 0.031)
  static let ivory = Color(red: 0.969, green: 0.976, blue: 0.937)
  static let track = lime.opacity(0.18)
}

private struct ExomMark: View {
  let size: CGFloat
  var onAccent = false

  var body: some View {
    Image("ExomMark")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .foregroundColor(onAccent ? ExomLiveActivityStyle.cocoa : ExomLiveActivityStyle.lime)
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

struct RestTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestTimerAttributes.self) { context in
      VStack(spacing: 16) {
        HStack(spacing: 12) {
          ZStack {
            Circle()
              .fill(ExomLiveActivityStyle.lime)
            ExomMark(size: 24, onAccent: true)
          }
          .frame(width: 44, height: 44)

          VStack(alignment: .leading, spacing: 3) {
            Text(localized("DESCANSO", "REST"))
              .font(.caption2.weight(.bold))
              .tracking(1.2)
              .foregroundStyle(ExomLiveActivityStyle.lime)
            Text(context.attributes.exerciseName)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(ExomLiveActivityStyle.ivory)
              .lineLimit(1)
          }

          Spacer(minLength: 8)

          countdown(until: context.state.endsAt)
            .font(.system(.title, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(ExomLiveActivityStyle.ivory)
        }

        progress(from: context.attributes.startedAt, until: context.state.endsAt)
      }
      .padding(16)
      .activityBackgroundTint(ExomLiveActivityStyle.cocoa)
      .activitySystemActionForegroundColor(ExomLiveActivityStyle.lime)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 8) {
            ExomMark(size: 22)
            Text(localized("DESCANSO", "REST"))
              .font(.caption.weight(.bold))
              .tracking(0.8)
              .foregroundStyle(ExomLiveActivityStyle.lime)
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          countdown(until: context.state.endsAt)
            .font(.system(.title3, design: .rounded).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(ExomLiveActivityStyle.ivory)
        }

        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 9) {
            Text(context.attributes.exerciseName)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(ExomLiveActivityStyle.ivory)
              .lineLimit(1)
            progress(from: context.attributes.startedAt, until: context.state.endsAt)
              .padding(.horizontal, 8)
          }
          .padding(.top, 4)
        }
      } compactLeading: {
        ExomMark(size: 19)
      } compactTrailing: {
        countdown(until: context.state.endsAt)
          .font(.caption.weight(.bold))
          .monospacedDigit()
          .foregroundStyle(ExomLiveActivityStyle.lime)
          .frame(minWidth: 38, alignment: .trailing)
      } minimal: {
        ExomMark(size: 18)
      }
      .keylineTint(ExomLiveActivityStyle.lime)
    }
  }

  private func countdown(until date: Date) -> Text {
    Text(timerInterval: Date()...date, countsDown: true)
  }

  private func progress(from start: Date, until end: Date) -> some View {
    ProgressView(timerInterval: start...end, countsDown: true) {
      EmptyView()
    } currentValueLabel: {
      EmptyView()
    }
      .progressViewStyle(.linear)
      .tint(ExomLiveActivityStyle.lime)
      .background(ExomLiveActivityStyle.track, in: Capsule())
      .clipShape(Capsule())
      .scaleEffect(x: 1, y: 1.35, anchor: .center)
      .accessibilityLabel(localized("Tiempo de descanso restante", "Rest time remaining"))
  }

  private func localized(_ spanish: String, _ english: String) -> String {
    Locale.current.language.languageCode?.identifier == "es" ? spanish : english
  }
}
