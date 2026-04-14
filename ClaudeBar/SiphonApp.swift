import SwiftUI
import CoreText

@main
struct SiphonApp: App {
    @StateObject private var store = UsageStore()

    init() {
        registerBundledFonts()
    }

    var body: some Scene {
        MenuBarExtra {
            UsageView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Font registration

    private func registerBundledFonts() {
        let names = ["Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Menu bar label

private struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 5) {
            if let q = store.quota, let session = q.session {
                let sessionColor: Color = session.percent >= 90 ? .red : session.percent >= 70 ? .orange : .green
                Text("\(Int(session.percent.rounded()))%")
                    .font(.custom("Inter-SemiBold", size: 11))
                    .foregroundStyle(sessionColor)

                if let weekly = q.weeklyAll {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    let weekColor: Color = weekly.percent >= 90 ? .red : weekly.percent >= 70 ? .orange : .primary
                    Text("\(Int(weekly.percent.rounded()))%")
                        .font(.custom("Inter-SemiBold", size: 11))
                        .foregroundStyle(weekColor)
                }
            } else {
                PhosphorDrop()
                    .fill(.orange)
                    .frame(width: 13, height: 13)
            }
        }
    }
}
