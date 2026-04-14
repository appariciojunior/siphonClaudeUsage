import Foundation

// MARK: - Local file models (~/.claude/)

struct CostCache: Codable {
    // { "days": { "2026-04-14": { "claude-opus-4-6": { "input": N, "output": N, "cacheWrite": N, "cacheRead": N } } } }
    let days: [String: [String: ModelTokens]]
}

struct ModelTokens: Codable {
    let input:      Int
    let output:     Int
    let cacheWrite: Int?
    let cacheRead:  Int?
}

struct PricingFile: Codable {
    let models: [String: ModelPrice]
}

struct ModelPrice: Codable {
    let input:      Double   // per million tokens
    let output:     Double
    let cacheRead:  Double?
    let cacheWrite: Double?
}

// MARK: - Aggregated display models

struct DayStats: Identifiable {
    let date:    String
    let models:  [String: ModelTokens]
    let cost:    Double

    var id: String { date }
}

struct PeriodStats {
    let inputTokens:      Int
    let outputTokens:     Int
    let cacheReadTokens:  Int
    let cacheWriteTokens: Int
    let cost:             Double
    let byModel:          [String: PerModelStats]

    var totalTokens: Int { inputTokens + outputTokens }
    var isEmpty: Bool { totalTokens == 0 && cost == 0 }

    static let empty = PeriodStats(inputTokens: 0, outputTokens: 0, cacheReadTokens: 0,
                                   cacheWriteTokens: 0, cost: 0, byModel: [:])
}

struct PerModelStats {
    let inputTokens:     Int
    let outputTokens:    Int
    let cacheReadTokens: Int
    let cost:            Double
    var totalTokens:     Int { inputTokens + outputTokens }

    var shortName: String { Pricing.shortName(modelKey) }
    let modelKey: String
}

// MARK: - Pricing helpers

enum Pricing {
    static func cost(tokens: ModelTokens, price: ModelPrice) -> Double {
        let m = 1_000_000.0
        let inp   = Double(tokens.input)      / m * price.input
        let out   = Double(tokens.output)     / m * price.output
        let cr    = Double(tokens.cacheRead  ?? 0) / m * (price.cacheRead  ?? 0)
        let cw    = Double(tokens.cacheWrite ?? 0) / m * (price.cacheWrite ?? 0)
        return inp + out + cr + cw
    }

    // "claude-opus-4-6" -> "opus-4-6" to match pricing file keys
    static func pricingKey(from model: String) -> String {
        let lower = model.lowercased()
        return lower.hasPrefix("claude-") ? String(lower.dropFirst(7)) : lower
    }

    static func shortName(_ model: String) -> String {
        let key = pricingKey(from: model)
        if key.contains("opus")   { return "Opus" }
        if key.contains("sonnet") { return "Sonnet" }
        if key.contains("haiku")  { return "Haiku" }
        return key
    }
}
