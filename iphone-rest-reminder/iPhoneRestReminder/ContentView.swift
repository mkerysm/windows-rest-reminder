import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var reminderManager: ReminderManager
    @State private var countdown: CountdownKind?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    ReminderCard(
                        title: "距离护眼提醒",
                        time: reminderManager.formatted(reminderManager.eyeRemaining),
                        color: .blue,
                        detail: "每 20 分钟远眺 20 秒"
                    )

                    ReminderCard(
                        title: "距离身体休息",
                        time: reminderManager.formatted(reminderManager.bodyRemaining),
                        color: .green,
                        detail: "每 60 分钟休息 5 分钟"
                    )

                    notificationCard
                    inactivityCard

                    Button {
                        reminderManager.reset()
                    } label: {
                        Label("重新开始计时", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    HStack(spacing: 12) {
                        countdownButton(
                            title: "远眺 20 秒",
                            icon: "eye",
                            color: .blue,
                            kind: .eye
                        )

                        countdownButton(
                            title: "休息 5 分钟",
                            icon: "figure.walk",
                            color: .green,
                            kind: .body
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .sheet(item: $countdown) { kind in
                CountdownView(kind: kind)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "eyes")
                .font(.system(size: 38))
                .foregroundStyle(.blue)

            Text("护眼与休息")
                .font(.largeTitle.bold())

            Text("规律休息，比忍到疲劳更轻松")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private var notificationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: reminderManager.notificationsEnabled ? "bell.badge.fill" : "bell.slash")
                .foregroundStyle(reminderManager.notificationsEnabled ? .green : .orange)

            VStack(alignment: .leading, spacing: 3) {
                Text(reminderManager.notificationsEnabled ? "通知已开启" : "需要开启通知")
                    .font(.headline)
                Text("锁屏或使用其他 App 时由系统通知提醒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !reminderManager.notificationsEnabled {
                Button("开启") {
                    Task {
                        await reminderManager.requestNotifications()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var inactivityCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(.indigo)

            VStack(alignment: .leading, spacing: 3) {
                Text("长时间休息后自动重置")
                    .font(.headline)
                Text("离开 App 满 5 分钟后再次打开，会重新开始护眼和身体休息计时。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func countdownButton(
        title: String,
        icon: String,
        color: Color,
        kind: CountdownKind
    ) -> some View {
        Button {
            countdown = kind
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
}

private struct ReminderCard: View {
    let title: String
    let time: String
    let color: Color
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(time)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22))
    }
}
