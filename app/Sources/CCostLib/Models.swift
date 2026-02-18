import Foundation

public struct FileInfo: Sendable {
    public let filePath: String
    public let mtimeMs: Int
    public let size: Int
    public let sessionId: String
    public let projectDir: String

    public init(filePath: String, mtimeMs: Int, size: Int, sessionId: String, projectDir: String) {
        self.filePath = filePath
        self.mtimeMs = mtimeMs
        self.size = size
        self.sessionId = sessionId
        self.projectDir = projectDir
    }
}

public struct DiffResult: Sendable {
    public let added: [FileInfo]
    public let changed: [FileInfo]
    public let removed: [String]
    public let unchanged: [String]
}

public struct UsageRecord: Sendable {
    public let filePath: String
    public let date: String
    public let model: String
    public let sessionId: String
    public let projectDir: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int
    public let messageCount: Int
}

public struct DailySummary: Sendable {
    public var date: String
    public var cost: Double
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheCreationInputTokens: Int
    public var cacheReadInputTokens: Int
    public var sessions: Int

    public init(date: String, cost: Double, inputTokens: Int, outputTokens: Int,
                cacheCreationInputTokens: Int, cacheReadInputTokens: Int, sessions: Int) {
        self.date = date
        self.cost = cost
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.sessions = sessions
    }
}

public struct ModelPricing: Codable, Sendable {
    public let inputPerMillion: Double
    public let outputPerMillion: Double
    public let cacheCreatePerMillion: Double
    public let cacheReadPerMillion: Double
}

public struct CliOptions: Sendable {
    public let since: String?
    public let until: String?
    public let json: Bool
    public let project: String?
    public let rebuild: Bool

    public init(since: String? = nil, until: String? = nil, json: Bool = false, project: String? = nil, rebuild: Bool = false) {
        self.since = since
        self.until = until
        self.json = json
        self.project = project
        self.rebuild = rebuild
    }
}
