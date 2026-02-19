import Foundation

struct RateLimitService: Sendable {
    private let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func fetchUsage() async throws -> RateLimitData {
        let token = try await readTokenViaSecurityCLI()

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkFailure("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.networkFailure("HTTP \(httpResponse.statusCode): \(body.prefix(200))")
        }

        let usage: UsageResponse
        do {
            usage = try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.parseFailure("Failed to decode usage: \(error.localizedDescription) body=\(body.prefix(200))")
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fiveHourReset = usage.five_hour.resets_at.flatMap { isoFormatter.date(from: $0) ?? parseWithoutFractional($0) }
        let sevenDayReset = usage.seven_day.resets_at.flatMap { isoFormatter.date(from: $0) ?? parseWithoutFractional($0) }

        return RateLimitData(
            fiveHourUtilization: usage.five_hour.utilization,
            fiveHourResetsAt: fiveHourReset,
            sevenDayUtilization: usage.seven_day.utilization,
            sevenDayResetsAt: sevenDayReset
        )
    }

    private func parseWithoutFractional(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func readTokenViaSecurityCLI() async throws -> String {
        let output = try await runProcess(
            executable: "/usr/bin/security",
            arguments: ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        )

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.keychainFailure("Empty keychain result")
        }

        guard let jsonData = trimmed.data(using: .utf8) else {
            throw ServiceError.keychainFailure("Failed to encode keychain data")
        }

        let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: jsonData)
        return credentials.claudeAiOauth.accessToken
    }

    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ServiceError.keychainFailure("Failed to launch security: \(error.localizedDescription)"))
                return
            }

            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                continuation.resume(throwing: ServiceError.keychainFailure("security exit code: \(process.terminationStatus)"))
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                continuation.resume(throwing: ServiceError.keychainFailure("Failed to decode security output"))
                return
            }

            continuation.resume(returning: output)
        }
    }
}
