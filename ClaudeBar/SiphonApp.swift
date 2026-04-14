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
        HStack(spacing: 4) {
            // Icon — always visible
            CodeMenuIcon()

            if let q = store.quota, let session = q.session {
                // Signed in: icon + session % · weekly %
                let sessionColor: Color = session.percent >= 76 ? .red : session.percent >= 31 ? .orange : .green
                Text("\(Int(session.percent.rounded()))%")
                    .font(.custom("Inter-SemiBold", size: 11))
                    .foregroundStyle(sessionColor)

                if let weekly = q.weeklyAll {
                    Text("·")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    let weekColor: Color = weekly.percent >= 76 ? .red : weekly.percent >= 31 ? .orange : .green
                    Text("\(Int(weekly.percent.rounded()))%")
                        .font(.custom("Inter-SemiBold", size: 11))
                        .foregroundStyle(weekColor)
                }
            } else {
                // Logged out: icon + "Siphon"
                Text("Siphon")
                    .font(.custom("Inter-SemiBold", size: 11))
            }
        }
    }
}

// MARK: - Code icon (light/dark adaptive template image)

private struct CodeMenuIcon: View {
    /// Loaded once; isTemplate=true makes macOS auto-render white on dark
    /// menu bars and black on light menu bars — no manual colour handling needed.
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
                .frame(width: 8, height: 8)
        }
    }
}
