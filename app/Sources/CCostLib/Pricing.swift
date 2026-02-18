import Foundation

public final class Pricing: @unchecked Sendable {
    public static let shared = Pricing()

    private let builtinPricing: [String: ModelPricing] = [
        "claude-opus-4-6": ModelPricing(
            inputPerMillion: 5,
            outputPerMillion: 25,
            cacheCreatePerMillion: 6.25,
            cacheReadPerMillion: 0.5
        ),
        "claude-opus-4-5-20251101": ModelPricing(
            inputPerMillion: 5,
            outputPerMillion: 25,
            cacheCreatePerMillion: 6.25,
            cacheReadPerMillion: 0.5
        ),
        "claude-sonnet-4-6": ModelPricing(
            inputPerMillion: 3,
            outputPerMillion: 15,
            cacheCreatePerMillion: 3.75,
            cacheReadPerMillion: 0.3
        ),
        "claude-sonnet-4-5-20250929": ModelPricing(
            inputPerMillion: 3,
            outputPerMillion: 15,
            cacheCreatePerMillion: 3.75,
            cacheReadPerMillion: 0.3
        ),
        "claude-haiku-4-5-20251001": ModelPricing(
            inputPerMillion: 1,
            outputPerMillion: 5,
            cacheCreatePerMillion: 1.25,
            cacheReadPerMillion: 0.1
        ),
    ]

    private let lock = NSLock()
    private var _pricing: [String: ModelPricing]
    private var _unknownModels = Set<String>()

    private init() {
        _pricing = builtinPricing
        loadCachedPricing()
    }

    public var unknownModels: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(_unknownModels)
    }

    public func resetUnknownModels() {
        lock.lock()
        defer { lock.unlock() }
        _unknownModels.removeAll()
    }

    public func calculateCost(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int,
        cacheReadInputTokens: Int
    ) -> Double {
        let p = getPricing(model: model)
        return Double(inputTokens) * p.inputPerMillion / 1_000_000
            + Double(outputTokens) * p.outputPerMillion / 1_000_000
            + Double(cacheCreationInputTokens) * p.cacheCreatePerMillion / 1_000_000
            + Double(cacheReadInputTokens) * p.cacheReadPerMillion / 1_000_000
    }

    private func getPricing(model: String) -> ModelPricing {
        lock.lock()
        defer { lock.unlock() }

        if let p = _pricing[model] { return p }

        // Fuzzy match: check if model string contains a known key
        for (key, pricing) in _pricing {
            if model.contains(key) || key.contains(model) { return pricing }
        }

        // Default to sonnet pricing for unknown claude models
        if model.hasPrefix("claude-") {
            _unknownModels.insert(model)
        }
        return builtinPricing["claude-sonnet-4-6"]!
    }

    private func loadCachedPricing() {
        let cacheFile = cacheDir + "/pricing.json"
        guard let data = FileManager.default.contents(atPath: cacheFile) else { return }
        guard let cached = try? JSONDecoder().decode([String: ModelPricing].self, from: data) else { return }

        for (model, pricing) in cached {
            _pricing[model] = pricing
        }
    }

    private var cacheDir: String {
        NSHomeDirectory() + "/.cache/ccost"
    }
}
