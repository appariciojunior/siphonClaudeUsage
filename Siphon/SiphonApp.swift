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

    private func registerBundledFonts() {
        let names = ["Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

// MARK: - Menu bar label
//
// SwiftUI's .foregroundColor / .foregroundStyle are silently ignored inside
// MenuBarExtra labels — NSStatusBarButton's compositing context overrides them.
// Solution: render the entire label as an NSImage via AppKit's NSAttributedString
// (which respects NSColor exactly), then display with a plain Image(nsImage:).

private struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @Environment(\.colorScheme) var colorScheme  // re-renders on light↔dark switch

    var body: some View {
        // Read MainActor-isolated values here (in SwiftUI body = main thread)
        // then pass them as plain value types to the renderer.
        let quota    = store.quota
        let signedIn = store.isSignedIn
        return Image(nsImage: LabelRenderer.render(
            quota:    quota,
            signedIn: signedIn,
            dark:     colorScheme == .dark
        ))
    }
}

// MARK: - Renderer

private enum LabelRenderer {

    // Cache the SVG so it's only loaded once
    private static let iconSrc: NSImage? = {
        guard let url = Bundle.main.url(forResource: "code", withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }()

    static func render(quota: PlanQuota?, signedIn: Bool, dark: Bool) -> NSImage {
        let mono  = dark ? NSColor.white : NSColor.black
        let font  = NSFont(name: "Inter-SemiBold", size: 11)
                    ?? NSFont.systemFont(ofSize: 11, weight: .semibold)
        let iconW : CGFloat = 12
        let gap   : CGFloat = 4
        let barH  : CGFloat = 22   // standard macOS menu bar slot height
        let sp    : CGFloat = 4    // gap between text segments

        // Build (string, NSColor) pairs
        let segs: [(String, NSColor)] = buildSegments(quota: quota, mono: mono)

        // Measure
        let strs = segs.map { (s, c) in
            NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c])
        }
        let textW = strs.reduce(0) { $0 + $1.size().width }
                    + sp * CGFloat(max(0, strs.count - 1))
        let totalW = iconW + gap + textW

        let image = NSImage(size: NSSize(width: totalW, height: barH), flipped: false) { _ in
            // Icon — tinted to mono (white on dark bar, black on light bar)
            if let src = iconSrc {
                let r = NSRect(x: 0, y: (barH - iconW) / 2, width: iconW, height: iconW)
                NSGraphicsContext.saveGraphicsState()
                src.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1.0)
                mono.setFill()
                r.fill(using: .sourceAtop)   // tint all non-transparent pixels to mono
                NSGraphicsContext.restoreGraphicsState()
            }

            // Text segments
            var x = iconW + gap
            for (i, str) in strs.enumerated() {
                let sz = str.size()
                str.draw(at: NSPoint(x: x, y: (barH - sz.height) / 2))
                x += sz.width + (i < strs.count - 1 ? sp : 0)
            }
            return true
        }
        return image
    }

    // MARK: - Helpers

    private static func buildSegments(quota: PlanQuota?, mono: NSColor) -> [(String, NSColor)] {
        guard let q = quota, let s = q.session else {
            return [("Siphon", mono)]
        }
        var out: [(String, NSColor)] = [
            ("\(Int(s.percent.rounded()))%", usageColor(s.percent))
        ]
        if let w = q.weeklyAll {
            out += [
                ("·",  mono.withAlphaComponent(0.4)),
                ("\(Int(w.percent.rounded()))%", usageColor(w.percent))
            ]
        }
        return out
    }

    /// 0–30 green · 31–75 orange · 76–100 red
    private static func usageColor(_ pct: Double) -> NSColor {
        pct >= 76 ? .systemRed : pct >= 31 ? .systemOrange : .systemGreen
    }
}
