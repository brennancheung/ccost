import Foundation
import CCostLib

struct UsageWindow: Codable, Sendable {
    let utilization: Double
    let resets_at: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resets_at
    }
}

struct UsageResponse: Codable, Sendable {
    let five_hour: UsageWindow
    let seven_day: UsageWindow

    enum CodingKeys: String, CodingKey {
        case five_hour
        case seven_day
    }
}

struct ClaudeCredentials: Codable, Sendable {
    let claudeAiOauth: OAuthCredential
}

struct OAuthCredential: Codable, Sendable {
    let accessToken: String
}

struct CostData: Sendable {
    let cost: Double
    let sessions: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
}

struct RateLimitData: Sendable {
    let fiveHourUtilization: Double
    let fiveHourResetsAt: Date
    let sevenDayUtilization: Double
    let sevenDayResetsAt: Date
}

enum CostRefreshInterval: Int, CaseIterable, Sendable {
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
}

let costRefreshLabels: [CostRefreshInterval: String] = [
    .thirtySeconds: "30 seconds",
    .oneMinute: "1 minute",
    .fiveMinutes: "5 minutes",
    .fifteenMinutes: "15 minutes",
]

enum RateLimitRefreshInterval: Int, CaseIterable, Sendable {
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
}

let rateLimitRefreshLabels: [RateLimitRefreshInterval: String] = [
    .fiveMinutes: "5 minutes",
    .fifteenMinutes: "15 minutes",
    .thirtyMinutes: "30 minutes",
    .oneHour: "1 hour",
]

enum DisplayFormat: String, CaseIterable, Sendable {
    case costAndPercent = "costAndPercent"
    case costOnly = "costOnly"
    case percentOnly = "percentOnly"
    case compact = "compact"
}

enum ServiceError: Error, Sendable {
    case processFailure(String)
    case parseFailure(String)
    case keychainFailure(String)
    case networkFailure(String)
}
