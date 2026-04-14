import Foundation

// MARK: - claude.ai API response models

struct OrgListResponse: Codable {
    let uuid: String
    // other fields ignored
}

struct PlanUsageResponse: Codable {
    let fiveHour:      UsagePeriod?
    let sevenDay:      UsagePeriod?
    let sevenDaySonnet: UsagePeriod?
    let sevenDayOpus:  UsagePeriod?

    enum CodingKeys: String, CodingKey {
        case fiveHour       = "five_hour"
        case sevenDay       = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus   = "seven_day_opus"
    }
}

struct UsagePeriod: Codable {
    let utilization: Double   // 0–100
    let resetsAt:    String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? {
        guard let s = resetsAt else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }
}

// MARK: - Display model

struct PlanQuota {
    let session:      QuotaSlot?   // five_hour
    let weeklyAll:    QuotaSlot?   // seven_day
    let weeklySonnet: QuotaSlot?   // seven_day_sonnet
    let weeklyOpus:   QuotaSlot?   // seven_day_opus
}

struct QuotaSlot {
    let percent:  Double   // 0–100
    let resetsAt: Date?

    var resetsInString: String {
        guard let date = resetsAt else { return "unknown" }
        let diff = date.timeIntervalSinceNow
        guard diff > 0 else { return "soon" }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        if h > 0 { return "\(h) hr \(m) min" }
        return "\(m) min"
    }

    var resetsDayTimeString: String {
        guard let date = resetsAt else { return "unknown" }
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f.string(from: date)
    }
}
