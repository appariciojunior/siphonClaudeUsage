import SwiftUI

// MARK: - Root view

struct UsageView: View {
    @EnvironmentObject var store: UsageStore
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            // Base content
            VStack(spacing: 0) {
                header
                thinDivider
                if store.isAuthenticating && store.awaitingCode {
                    CodeEntryPanel().environmentObject(store)
                } else {
                    mainContent
                }
            }

            // Settings slides in as overlay — avoids layout thrash / freeze
            if showSettings {
                SettingsPanel(showSettings: $showSettings)
                    .environmentObject(store)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .overlay(thinBorder)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)

            Text("ClaudeBar")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                store.refresh()
                Task { await store.refreshQuota() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(showSettings ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Main

    @ViewBuilder
    private var mainContent: some View {
        if store.isSignedIn {
            quotaContent
        } else {
            signInSection
        }

        thinDivider
        footerButtons
    }

    // MARK: Quota

    @ViewBuilder
    private var quotaContent: some View {
        if let q = store.quota {
            VStack(spacing: 0) {
                if let s = q.session {
                    MeterRow(label: "CURRENT SESSION", slot: s,
                             color: barColor(s.percent), isSession: true)
                    thinDivider
                }
                if let s = q.weeklyAll {
                    MeterRow(label: "WEEKLY · ALL MODELS", slot: s,
                             color: barColor(s.percent), isSession: false)
                }
                if let s = q.weeklySonnet {
                    thinDivider
                    MeterRow(label: "WEEKLY · SONNET", slot: s,
                             color: barColor(s.percent), isSession: false)
                }
            }

            // Cost strip
            if !store.todayStats.isEmpty || !store.monthStats.isEmpty {
                thinDivider
                costStrip
            }

            // Status row
            if let date = store.lastUpdated {
                thinDivider
                HStack(spacing: 5) {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text(Date().timeIntervalSince(date) < 15 ? "Updated just now" :
                         "Updated \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
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
            costCell(label: "TODAY", stats: store.todayStats)
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5)
            costCell(label: "THIS MONTH", stats: store.monthStats)
        }
    }

    private func costCell(label: String, stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)
            Text(stats.cost.formatted(.currency(code: "USD").precision(.fractionLength(4))))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
            if !stats.isEmpty {
                Text(formatTokens(stats.totalTokens) + " tokens")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Footer

    private var footerButtons: some View {
        HStack(spacing: 0) {
            Button {
                NSWorkspace.shared.open(URL(string: "https://claude.ai")!)
            } label: {
                HStack(spacing: 4) {
                    Text("Open Claude.ai")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.04))
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 0.5)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Sign-in

    private var signInSection: some View {
        Button { store.startSignIn() } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sign in with Claude")
                        .font(.system(size: 13, weight: .medium))
                    Text("View your plan usage limits")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
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
            Text("Loading…").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange).font(.system(size: 12))
            Text(msg).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Button("Retry") { Task { await store.refreshQuota() } }
                .font(.system(size: 11)).buttonStyle(.bordered).controlSize(.mini)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: Helpers

    private var thinDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(height: 0.5)
    }

    private var thinBorder: some View {
        Rectangle()
            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
    }

    private func barColor(_ pct: Double) -> Color {
        pct >= 90 ? .red : pct >= 70 ? .orange : .green
    }

    private func formatTokens(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.2fM", Double(n)/1_000_000) :
        n >= 1_000     ? String(format: "%.1fK", Double(n)/1_000) : "\(n)"
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
            // Label
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.6)

            // Big number
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(Int(slot.percent.rounded()))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("%")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.7))
            }

            // Thin progress bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.12))
                        .frame(height: 3)
                    Rectangle()
                        .fill(color)
                        .frame(width: g.size.width * min(slot.percent / 100, 1), height: 3)
                }
            }
            .frame(height: 3)

            // Reset info
            HStack(spacing: 6) {
                Text("Resets in \(slot.resetsInString)")
                    .font(.system(size: 12, weight: .medium))
                if let date = slot.resetsAt {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(isSession
                         ? "Today at \(date.formatted(date: .omitted, time: .shortened))"
                         : date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings overlay

private struct SettingsPanel: View {
    @EnvironmentObject var store: UsageStore
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Mirror the header so it sits flush
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("ClaudeBar")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { showSettings = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)

            VStack(alignment: .leading, spacing: 10) {
                if store.isSignedIn {
                    HStack(spacing: 8) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text("Signed in to Claude")
                            .font(.system(size: 12))
                        Spacer()
                        Button("Sign out") {
                            store.signOut()
                            showSettings = false
                        }
                        .font(.system(size: 11))
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
                            Text("Sign in with Claude")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 0.5)
        }
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Code entry

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
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.6)
                Text("Approve in the browser, then copy\nthe full URL from the address bar.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            TextField("Paste URL or code…", text: $pasted)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))

            if let err = store.authError {
                Text(err).font(.system(size: 10)).foregroundStyle(.red)
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
