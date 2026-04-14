import SwiftUI
import CoreText
import AppKit

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
                CodeMenuIcon()
            }
        }
    }
}

// MARK: - Code icon (light/dark adaptive template image)

private struct CodeMenuIcon: View {
    /// Loaded once, marked as template so AppKit renders it white on dark
    /// menu bars and black on light menu bars automatically.
    private static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "code", withExtension: "svg"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true
        return img
    }()

    var body: some View {
        if let img = Self.image {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
        }
    }
}
