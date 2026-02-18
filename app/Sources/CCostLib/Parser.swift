import Foundation

public struct Parser: Sendable {
    public init() {}

    public func parseFiles(_ files: [FileInfo]) -> [UsageRecord] {
        var allRecords: [UsageRecord] = []
        var globalSeen = Set<String>()

        for file in files {
            let records = parseFile(file, globalSeen: &globalSeen)
            allRecords.append(contentsOf: records)
        }

        return allRecords
    }

    private func parseFile(_ file: FileInfo, globalSeen: inout Set<String>) -> [UsageRecord] {
        guard let data = FileManager.default.contents(atPath: file.filePath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        struct MessageUsage {
            let model: String
            let inputTokens: Int
            let outputTokens: Int
            let cacheCreationInputTokens: Int
            let cacheReadInputTokens: Int
            let timestamp: String
        }

        var messages: [MessageUsage] = []

        for line in lines {
            // Fast filter: skip lines without usage data
            guard line.contains("\"usage\"") else { continue }

            guard let lineData = line.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let msg = parsed["message"] as? [String: Any],
                  let usage = msg["usage"] as? [String: Any],
                  usage["input_tokens"] != nil else {
                continue
            }

            let messageId = msg["id"] as? String
            let requestId = parsed["requestId"] as? String

            // Dedup: messageId:requestId, first-wins
            if let mid = messageId, let rid = requestId {
                let dedupKey = "\(mid):\(rid)"
                if globalSeen.contains(dedupKey) { continue }
                globalSeen.insert(dedupKey)
            }

            let model = msg["model"] as? String ?? ""
            if model.isEmpty || model == "<synthetic>" { continue }

            messages.append(MessageUsage(
                model: model,
                inputTokens: usage["input_tokens"] as? Int ?? 0,
                outputTokens: usage["output_tokens"] as? Int ?? 0,
                cacheCreationInputTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
                cacheReadInputTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
                timestamp: parsed["timestamp"] as? String ?? ""
            ))
        }

        // Aggregate by (date, model)
        struct AggKey: Hashable {
            let date: String
            let model: String
        }

        struct AggValue {
            var inputTokens: Int
            var outputTokens: Int
            var cacheCreationInputTokens: Int
            var cacheReadInputTokens: Int
            var messageCount: Int
        }

        var aggregateMap: [AggKey: AggValue] = [:]

        for msg in messages {
            guard !msg.timestamp.isEmpty else { continue }
            let date = toLocalDate(msg.timestamp)
            guard date.count == 10 else { continue }

            let key = AggKey(date: date, model: msg.model)

            if var existing = aggregateMap[key] {
                existing.inputTokens += msg.inputTokens
                existing.outputTokens += msg.outputTokens
                existing.cacheCreationInputTokens += msg.cacheCreationInputTokens
                existing.cacheReadInputTokens += msg.cacheReadInputTokens
                existing.messageCount += 1
                aggregateMap[key] = existing
            } else {
                aggregateMap[key] = AggValue(
                    inputTokens: msg.inputTokens,
                    outputTokens: msg.outputTokens,
                    cacheCreationInputTokens: msg.cacheCreationInputTokens,
                    cacheReadInputTokens: msg.cacheReadInputTokens,
                    messageCount: 1
                )
            }
        }

        return aggregateMap.map { (key, agg) in
            UsageRecord(
                filePath: file.filePath,
                date: key.date,
                model: key.model,
                sessionId: file.sessionId,
                projectDir: file.projectDir,
                inputTokens: agg.inputTokens,
                outputTokens: agg.outputTokens,
                cacheCreationInputTokens: agg.cacheCreationInputTokens,
                cacheReadInputTokens: agg.cacheReadInputTokens,
                messageCount: agg.messageCount
            )
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func toLocalDate(_ isoTimestamp: String) -> String {
        guard let date = Self.isoFormatter.date(from: isoTimestamp)
                ?? Self.isoFormatterNoFrac.date(from: isoTimestamp) else {
            return ""
        }
        return Self.localDateFormatter.string(from: date)
    }
}
