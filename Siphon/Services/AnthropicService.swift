import Foundation

// Reads Claude Code's local usage files — no API key required.
// Files written by Claude Code CLI at ~/.claude/

struct LocalDataService {
    private let claudeDir = URL.homeDirectory.appending(path: ".claude", directoryHint: .isDirectory)

    var costCacheURL: URL  { claudeDir.appending(path: "readout-cost-cache.json") }
    var pricingURL:   URL  { claudeDir.appending(path: "readout-pricing.json") }

    func load() throws -> (cache: CostCache, pricing: PricingFile) {
        let cacheData   = try Data(contentsOf: costCacheURL)
        let pricingData = try Data(contentsOf: pricingURL)
        let cache   = try JSONDecoder().decode(CostCache.self,   from: cacheData)
        let pricing = try JSONDecoder().decode(PricingFile.self, from: pricingData)
        return (cache, pricing)
    }
}
