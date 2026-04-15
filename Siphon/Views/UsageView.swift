import SwiftUI
import AppKit

// MARK: - Font helpers
private extension Font {
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:     return .custom("Inter-Bold",     size: size)
        case .semibold: return .custom("Inter-SemiBold", size: size)
        case .medium:   return .custom("Inter-Medium",   size: size)
        default:        return .custom("Inter-Regular",  size: size)
        }
    }
}

// MARK: - Root view

struct UsageView: View {
    @EnvironmentObject var store: UsageStore
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header
                thinDivider
                if store.isAuthenticating && store.awaitingCode {
                    CodeEntryPanel().environmentObject(store)
                } else {
                    mainContent
                }
            }

            if showSettings {
                SettingsPanel(showSettings: $showSettings)
                    .environmentObject(store)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .background(
            ZStack {
                // Frosted glass fill
                Rectangle().fill(.ultraThinMaterial)
                // Hook into the window and zero out all corner radii
                SquareWindowFix()
            }
        )
        .overlay(thinBorder)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 9) {
            PhosphorDrop()
                .fill(.orange)
                .frame(width: 14, height: 14)

            Text("Siphon")
                .font(.inter(13, .semibold))

            Spacer()

            Button {
                store.refresh()
                Task { await store.refreshQuota() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11.5))
                    .foregroundStyle(showSettings ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Main content

    @ViewBuilder
    private var mainContent: some View {
        if store.isSignedIn {
            quotaContent
        } else {
            signInRow
        }
        thinDivider
        footerRow
    }

    // MARK: Quota

    @ViewBuilder
    private var quotaContent: some View {
        if let q = store.quota {
            VStack(spacing: 0) {
                if let s = q.session {
                    MeterRow(label: "CURRENT SESSION", slot: s, color: barColor(s.percent), isSession: true)
                    thinDivider
                }
                if let s = q.weeklyAll {
                    MeterRow(label: "WEEKLY · ALL MODELS", slot: s, color: barColor(s.percent), isSession: false)
                }
                if let s = q.weeklySonnet {
                    thinDivider
                    MeterRow(label: "WEEKLY · SONNET", slot: s, color: barColor(s.percent), isSession: false)
                }
            }

            if !store.todayStats.isEmpty || !store.monthStats.isEmpty {
                thinDivider
                costStrip
            }

            if let date = store.lastUpdated {
                thinDivider
                HStack(spacing: 5) {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text(Date().timeIntervalSince(date) < 15
                         ? "Updated just now"
                         : "Updated \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.inter(10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
        } else if let err = store.quotaError {
            errorRow(err)
        } else {
            loadingRow
        }
    }

    // MARK: Cost strip

    private var costStrip: some View {
        HStack(spacing: 0) {
            costCell(label: "TODAY",      stats: store.todayStats)
            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 0.5)
            costCell(label: "THIS MONTH", stats: store.monthStats)
        }
    }

    private func costCell(label: String, stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.inter(9, .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)
            Text(stats.cost.formatted(.currency(code: "USD").precision(.fractionLength(4))))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
            if !stats.isEmpty {
                Text(formatTokens(stats.totalTokens) + " tokens")
                    .font(.inter(10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Footer

    private var footerRow: some View {
        HStack(spacing: 0) {
            Button {
                NSWorkspace.shared.open(URL(string: "https://claude.ai")!)
            } label: {
                HStack(spacing: 4) {
                    Text("Open Claude.ai").font(.inter(12, .medium))
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.04))
            }
            .buttonStyle(.plain)

            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 0.5)

            Button { NSApp.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
                    .font(.inter(12, .medium))
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Sign-in row

    private var signInRow: some View {
        Button { store.startSignIn() } label: {
            HStack(spacing: 10) {
                PhosphorDrop().fill(.orange).frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sign in with Claude").font(.inter(13, .medium))
                    Text("View your plan usage limits").font(.inter(11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: State rows

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.7)
            Text("Loading…").font(.inter(12)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange).font(.system(size: 12))
            Text(msg).font(.inter(11)).foregroundStyle(.secondary)
            Spacer()
            Button("Retry") { Task { await store.refreshQuota() } }
                .font(.inter(11)).buttonStyle(.bordered).controlSize(.mini)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: Helpers

    private var thinDivider: some View {
        Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)
    }

    private var thinBorder: some View {
        Rectangle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
    }

    private func barColor(_ pct: Double) -> Color {
        pct >= 76 ? .red : pct >= 31 ? .orange : .green
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.2fM", Double(n)/1_000_000) :
        n >= 1_000     ? String(format: "%.1fK", Double(n)/1_000) : "\(n)"
    }
}

// MARK: - Segmented pixel bar

private struct SegmentedBar: View {
    let percent: Double
    let color:   Color

    private let segments: Int    = 30
    private let gap:      CGFloat = 2
    private let height:   CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let segW   = (geo.size.width - gap * CGFloat(segments - 1)) / CGFloat(segments)
            let filled = Int((min(percent, 100) / 100.0 * Double(segments)).rounded())
            HStack(spacing: gap) {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle()
                        .fill(i < filled ? color : color.opacity(0.15))
                        .frame(width: max(segW, 1), height: height)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Meter row

private struct MeterRow: View {
    let label:     String
    let slot:      QuotaSlot
    let color:     Color
    let isSession: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.inter(9, .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.6)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(Int(slot.percent.rounded()))")
                    .font(.custom("Inter-Bold", size: 44))
                    .foregroundStyle(color)
                Text("%")
                    .font(.custom("Inter-SemiBold", size: 20))
                    .foregroundStyle(color.opacity(0.7))
            }

            SegmentedBar(percent: slot.percent, color: color)

            HStack(spacing: 5) {
                Text("Resets in \(slot.resetsInString)").font(.inter(12, .medium))
                if let date = slot.resetsAt {
                    Text("·").foregroundStyle(.tertiary)
                    Text(isSession
                         ? "Today at \(date.formatted(date: .omitted, time: .shortened))"
                         : date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .font(.inter(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Square window fix
//
// MenuBarExtra draws its popup in an NSPanel whose background view carries a
// cornerRadius. We walk every layer in the window hierarchy and zero them out.

private struct SquareWindowFix: NSViewRepresentable {

    func makeNSView(context: Context) -> _SquareFixView {
        _SquareFixView()
    }
    func updateNSView(_ nsView: _SquareFixView, context: Context) {}
}

final class _SquareFixView: NSView {

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        // Run after the window has fully composed its layer tree
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            Self.squareAll(window)
        }
    }

    private static func squareAll(_ window: NSWindow) {
        // Zero every layer cornerRadius in the entire content-view tree
        func squareView(_ v: NSView) {
            if v.wantsLayer || v.layer != nil {
                v.wantsLayer = true
                v.layer?.cornerRadius = 0
                v.layer?.cornerCurve  = .circular   // not that it matters at 0, but explicit
            }
            v.subviews.forEach(squareView)
        }

        // Content view + its superview (the panel's "chrome" layer)
        if let cv = window.contentView {
            squareView(cv)
            if let sv = cv.superview { squareView(sv) }
        }

        // Some macOS versions use child windows for the popover shadow/arrow
        window.childWindows?.forEach { squareAll($0) }
    }
}

// MARK: - Settings overlay

private struct SettingsPanel: View {
    @EnvironmentObject var store: UsageStore
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                PhosphorDrop().fill(.orange).frame(width: 14, height: 14)
                Text("Siphon").font(.inter(13, .semibold))
                Spacer()
                Button { showSettings = false } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)

            if store.isSignedIn {
                HStack(spacing: 8) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("Signed in to Claude").font(.inter(12))
                    Spacer()
                    Button("Sign out") {
                        store.signOut()
                        showSettings = false
                    }
                    .font(.inter(11))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            } else {
                Button {
                    showSettings = false
                    store.startSignIn()
                } label: {
                    HStack {
                        Text("Sign in with Claude").font(.inter(13, .medium))
                        Spacer()
                        Image(systemName: "arrow.right").font(.system(size: 11))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)
        }
        .background(.ultraThinMaterial)
        .overlay(Rectangle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
    }
}

// MARK: - Code entry panel

private struct CodeEntryPanel: View {
    @EnvironmentObject var store: UsageStore
    @State private var pasted = ""

    private var extractedCode: String {
        let t = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        let candidate = String(t.split(separator: "#", maxSplits: 1).first ?? t[t.startIndex...])
        if let comps = URLComponents(string: candidate),
           let code  = comps.queryItems?.first(where: { $0.name == "code" })?.value { return code }
        return candidate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("COMPLETE SIGN IN")
                    .font(.inter(9, .semibold)).kerning(0.6).foregroundStyle(.secondary)
                Text("Approve in the browser, then copy\nthe full URL from the address bar.")
                    .font(.inter(12)).foregroundStyle(.secondary)
            }

            TextField("Paste URL or code…", text: $pasted)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))

            if let err = store.authError {
                Text(err).font(.inter(10)).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { store.cancelAuth() }
                    .buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Button("Submit") { Task { await store.submitCode(extractedCode) } }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(extractedCode.isEmpty)
            }
        }
        .padding(14)
    }
}

extension PerModelStats: Identifiable { var id: String { modelKey } }
