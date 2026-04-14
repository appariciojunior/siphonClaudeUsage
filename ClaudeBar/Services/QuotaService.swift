import Foundation

struct QuotaService {
    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let store    = TokenStore.shared

    func fetch() async throws -> PlanQuota {
        let token = try await validToken()
        var req   = URLRequest(url: usageURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        req.setValue("Bearer \(token)",       forHTTPHeaderField: "Authorization")
        req.setValue("application/json",      forHTTPHeaderField: "Accept")
        req.setValue("application/json",      forHTTPHeaderField: "Content-Type")
        req.setValue("oauth-2025-04-20",      forHTTPHeaderField: "anthropic-beta")
        req.setValue("claude-code/2.1.0",     forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw QuotaError.badResponse }

        switch http.statusCode {
        case 200:
            let raw = try JSONDecoder().decode(RawUsageResponse.self, from: data)
            return raw.toPlanQuota()
        case 401:
            store.clear()
            throw QuotaError.unauthorized
        default:
            throw QuotaError.server(http.statusCode)
        }
    }

    // MARK: - Token management

    private func validToken() async throws -> String {
        guard var creds = store.load() else { throw QuotaError.notSignedIn }

        if creds.needsRefresh(), let refresh = creds.refreshToken {
            creds = try await OAuthService.refresh(using: refresh)
            store.save(creds)
        }
        guard !creds.isExpired else {
            store.clear()
            throw QuotaError.notSignedIn
        }
        return creds.accessToken
    }
}

// MARK: - Raw response models (snake_case from API)

private struct RawUsageResponse: Codable {
    let fiveHour:      RawBucket?
    let sevenDay:      RawBucket?
    let sevenDaySonnet: RawBucket?
    let sevenDayOpus:  RawBucket?
    let extraUsage:    RawExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour       = "five_hour"
        case sevenDay       = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus   = "seven_day_opus"
        case extraUsage     = "extra_usage"
    }

    func toPlanQuota() -> PlanQuota {
        PlanQuota(
            session:      fiveHour.map      { QuotaSlot(percent: $0.utilization ?? 0, resetsAt: $0.resetDate) },
            weeklyAll:    sevenDay.map       { QuotaSlot(percent: $0.utilization ?? 0, resetsAt: $0.resetDate) },
            weeklySonnet: sevenDaySonnet.map { QuotaSlot(percent: $0.utilization ?? 0, resetsAt: $0.resetDate) },
            weeklyOpus:   sevenDayOpus.map   { QuotaSlot(percent: $0.utilization ?? 0, resetsAt: $0.resetDate) }
        )
    }
}

private struct RawBucket: Codable {
    let utilization: Double?
    let resetsAt:    String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? {
        guard let s = resetsAt else { return nil }
        // Try standard ISO-8601 first, then with fractional seconds (e.g. "2025-04-17T15:00:00.000Z")
        let f = ISO8601DateFormatter()
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
}

private struct RawExtraUsage: Codable {
    let isEnabled:    Bool?
    let utilization:  Double?
    let usedCredits:  Int?
    let monthlyLimit: Int?

    enum CodingKeys: String, CodingKey {
        case isEnabled    = "is_enabled"
        case utilization
        case usedCredits  = "used_credits"
        case monthlyLimit = "monthly_limit"
    }
}

// MARK: - Errors

enum QuotaError: LocalizedError {
    case notSignedIn
    case badResponse
    case unauthorized
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:   return "Not signed in"
        case .badResponse:   return "Unexpected response"
        case .unauthorized:  return "Session expired — please sign in again"
        case .server(let c): return "Server error (\(c))"
        }
    }
}
