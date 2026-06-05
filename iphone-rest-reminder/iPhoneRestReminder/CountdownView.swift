import Foundation
import SwiftUI

enum CountdownKind: String, Identifiable {
    case eye
    case body

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eye: "望向远处"
        case .body: "离开屏幕休息"
        }
    }

    var message: String {
        switch self {
        case .eye: "看向约 6 米以外的地方，放松眼睛。"
        case .body: "起身走动，活动肩颈，喝一点水。"
        }
    }

    var duration: Int {
        switch self {
        case .eye: 20
        case .body: 5 * 60
        }
    }

    var color: Color {
        switch self {
        case .eye: .blue
        case .body: .green
        }
    }
}

struct CountdownView: View {
    let kind: CountdownKind

    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int
    @State private var timer: Timer?

    init(kind: CountdownKind) {
        self.kind = kind
        _remaining = State(initialValue: kind.duration)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: kind == .eye ? "eye.fill" : "figure.walk")
                .font(.system(size: 58))
                .foregroundStyle(kind.color)

            Text(kind.title)
                .font(.largeTitle.bold())

            Text(formattedTime)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(kind.color)

            Text(kind.message)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Button("结束休息") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(kind.color)
            .controlSize(.large)
            .padding(.bottom)
        }
        .interactiveDismissDisabled()
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private var formattedTime: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if remaining > 0 {
                remaining -= 1
            } else {
                timer.invalidate()
                dismiss()
            }
        }
    }
}
