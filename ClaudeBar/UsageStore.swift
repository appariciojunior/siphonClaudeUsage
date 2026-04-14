import Foundation
import AppKit
import UserNotifications

@MainActor
final class UsageStore: ObservableObject {
    // Local token data
    @Published var todayStats:  PeriodStats = .empty
    @Published var monthStats:  PeriodStats = .empty
    @Published var recentDays:  [DayStats]  = []
    @Published var localError:  String?
    @Published var lastUpdated: Date?

    // Plan quota
    @Published var quota:       PlanQuota?
    @Published var quotaError:  String?

    // Auth state
    @Published var isSignedIn:  Bool = false

    // OAuth flow state (ephemeral)
    @Published var isAuthenticating = false
    @Published var awaitingCode     = false
    @Published var authError:       String?
    private var pkceVerifier:       String?
    private var pkceState:          String?

    var todayCost: Double? { todayStats.isEmpty ? nil : todayStats.cost }

    private let localService = LocalDataService()
    private let quotaService = QuotaService()
    private let tokenStore   = TokenStore.shared
    private var timer:        Timer?

    // Notification tracking — reset when a session restarts
    private var notifiedThresholds: Set<Int> = []
    private var lastSessionPercent: Double    = 0

    init() {
        isSignedIn = tokenStore.load() != nil
        refresh()
        if isSignedIn { Task { await refreshQuota() } }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
                if self?.isSignedIn == true { await self?.refreshQuota() }
            }
        }
        requestNotificationPermission()
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkSessionWarning(_ quota: PlanQuota) {
        guard let session = quota.session else { return }
        let pct = session.percent

        // Session reset — clear fired thresholds so warnings fire again next session
        if pct < lastSessionPercent - 15 {
            notifiedThresholds.removeAll()
        }
        lastSessionPercent = pct

        // Fire at 90 % then again at 95 %
        for threshold in [90, 95] where pct >= Double(threshold) && !notifiedThresholds.contains(threshold) {
            notifiedThresholds.insert(threshold)
            sendSessionWarning(percent: Int(pct.rounded()), resetsIn: session.resetsInString)
        }
    }

    private func sendSessionWarning(percent: Int, resetsIn: String) {
        let content          = UNMutableNotificationContent()
        content.title        = "Session \(percent)% used"
        content.body         = "Your session resets in \(resetsIn). You can continue with paid credits once the limit is reached."
        content.sound        = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "siphon-session-\(percent)",
            content: content,
            trigger: nil    // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Local data

    func refresh() {
        do {
            let (cache, pricing) = try localService.load()
            let today       = todayString()
            let monthPrefix = today.prefix(7)
            var todayModels: [String: (tokens: ModelTokens, cost: Double)] = [:]
            var monthModels: [String: (inp: Int, out: Int, cr: Int, cost: Double)] = [:]
            var days: [DayStats] = []

            for (date, modelMap) in cache.days {
                var dayCost = 0.0
                for (model, tokens) in modelMap {
                    let price = pricing.models[Pricing.pricingKey(from: model)]
                    let cost  = price.map { Pricing.cost(tokens: tokens, price: $0) } ?? 0
                    dayCost += cost
                    if date == today { todayModels[model] = (tokens, cost) }
                    if date.hasPrefix(monthPrefix) {
                        let p = monthModels[model] ?? (0, 0, 0, 0)
                        monthModels[model] = (p.inp + tokens.input, p.out + tokens.output,
                                              p.cr + (tokens.cacheRead ?? 0), p.cost + cost)
                    }
                }
                days.append(DayStats(date: date, models: modelMap, cost: dayCost))
            }
            todayStats  = aggregate(todayModels)
            monthStats  = aggregateMonth(monthModels)
            recentDays  = days.sorted { $0.date > $1.date }
            lastUpdated = Date()
            localError  = nil
        } catch {
            localError = "Could not read ~/.claude/ data"
        }
    }

    // MARK: - Quota

    func refreshQuota() async {
        do {
            let fresh  = try await quotaService.fetch()
            quota      = fresh
            quotaError = nil
            isSignedIn = true
            checkSessionWarning(fresh)
        } catch QuotaError.notSignedIn {
            isSignedIn = false
            quota      = nil
        } catch {
            quotaError = error.localizedDescription
        }
    }

    // MARK: - OAuth

    func startSignIn() {
        authError        = nil
        let flow         = OAuthService.prepareFlow()
        pkceVerifier     = flow.verifier
        pkceState        = flow.state
        awaitingCode     = true
        isAuthenticating = true
        // Open browser AFTER SwiftUI has finished this state update — prevents freeze
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSWorkspace.shared.open(flow.url)
        }
    }

    func submitCode(_ code: String) async {
        guard let verifier = pkceVerifier, let state = pkceState else { return }
        authError = nil
        do {
            let creds = try await OAuthService.exchange(rawCode: code, verifier: verifier, state: state)
            tokenStore.save(creds)
            isSignedIn       = true
            awaitingCode     = false
            isAuthenticating = false
            pkceVerifier     = nil
            pkceState        = nil
            await refreshQuota()
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        tokenStore.clear()
        isSignedIn       = false
        awaitingCode     = false
        isAuthenticating = false
        pkceVerifier     = nil
        pkceState        = nil
        quota            = nil
        quotaError       = nil
        authError        = nil
    }

    func cancelAuth() {
        awaitingCode     = false
        isAuthenticating = false
        pkceVerifier     = nil
        pkceState        = nil
        authError        = nil
    }

    // MARK: - Helpers

    private func aggregate(_ map: [String: (tokens: ModelTokens, cost: Double)]) -> PeriodStats {
        var inp = 0, out = 0, cr = 0, cw = 0, cost = 0.0
        var byModel: [String: PerModelStats] = [:]
        for (model, v) in map {
            inp += v.tokens.input; out += v.tokens.output
            cr  += v.tokens.cacheRead ?? 0; cw += v.tokens.cacheWrite ?? 0
            cost += v.cost
            byModel[model] = PerModelStats(inputTokens: v.tokens.input, outputTokens: v.tokens.output,
                                           cacheReadTokens: v.tokens.cacheRead ?? 0, cost: v.cost, modelKey: model)
        }
        return PeriodStats(inputTokens: inp, outputTokens: out, cacheReadTokens: cr,
                           cacheWriteTokens: cw, cost: cost, byModel: byModel)
    }

    private func aggregateMonth(_ map: [String: (inp: Int, out: Int, cr: Int, cost: Double)]) -> PeriodStats {
        var inp = 0, out = 0, cr = 0, cost = 0.0
        var byModel: [String: PerModelStats] = [:]
        for (model, v) in map {
            inp += v.inp; out += v.out; cr += v.cr; cost += v.cost
            byModel[model] = PerModelStats(inputTokens: v.inp, outputTokens: v.out,
                                           cacheReadTokens: v.cr, cost: v.cost, modelKey: model)
        }
        return PeriodStats(inputTokens: inp, outputTokens: out, cacheReadTokens: cr,
                           cacheWriteTokens: 0, cost: cost, byModel: byModel)
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
