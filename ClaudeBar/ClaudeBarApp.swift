import SwiftUI

@main
struct ClaudeBarApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsageView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 5) {
            if let q = store.quota, let session = q.session {
                // Session % in session color
                let sessionColor: Color = session.percent >= 90 ? .red : session.percent >= 70 ? .orange : .green
                Text("\(Int(session.percent.rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(sessionColor)

                if let weekly = q.weeklyAll {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    let weekColor: Color = weekly.percent >= 90 ? .red : weekly.percent >= 70 ? .orange : .primary
                    Text("\(Int(weekly.percent.rounded()))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(weekColor)
                }
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
    }
}
