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

private struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 4) {
            CodeMenuIcon()

            if let q = store.quota, let session = q.session {
                // Signed in — icon + colour-coded percentages
                Text("\(Int(session.percent.rounded()))%")
                    .font(.custom("Inter-SemiBold", size: 11))
                    .foregroundColor(usageColor(session.percent))

                if let weekly = q.weeklyAll {
                    Text("·")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(Int(weekly.percent.rounded()))%")
                        .font(.custom("Inter-SemiBold", size: 11))
                        .foregroundColor(usageColor(weekly.percent))
                }
            } else {
                // Logged out — icon + brand name
                Text("Siphon")
                    .font(.custom("Inter-SemiBold", size: 11))
            }
        }
    }

    private func usageColor(_ pct: Double) -> Color {
        pct >= 76 ? .red : pct >= 31 ? .orange : .green
    }
}

// MARK: - Code icon

/// Loads code.svg from the bundle, pre-renders it at exactly 12 × 12 pt so the
/// SwiftUI Image view renders at a predictable size without any .frame() hacks.
/// isTemplate = true tells AppKit to tint it white/black automatically based on
/// the current menu bar appearance.
private struct CodeMenuIcon: View {

    private static let nsImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "code", withExtension: "svg"),
              let src = NSImage(contentsOf: url) else { return nil }

        let targetPt: CGFloat = 12          // logical points
        let scale: CGFloat    = 2           // @2x for retina
        let px = targetPt * scale           // physical pixels

        // Draw the SVG into a new bitmap at the exact pixel size
        let bmp = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(px), pixelsHigh: Int(px),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        bmp.size = NSSize(width: targetPt, height: targetPt)   // logical size = 12 pt

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
        src.draw(in: NSRect(x: 0, y: 0, width: targetPt, height: targetPt))
        NSGraphicsContext.restoreGraphicsState()

        let out = NSImage(size: NSSize(width: targetPt, height: targetPt))
        out.addRepresentation(bmp)
        out.isTemplate = true
        return out
    }()

    var body: some View {
        if let img = Self.nsImage {
            Image(nsImage: img)   // renders at exactly 12 × 12 pt — no .frame() needed
        }
    }
}
