import Foundation

public struct ProjectDecoder: Sendable {
    public init() {}

    /// Decode a Claude project directory name to a readable path.
    /// e.g. "-Users-brennan-code-openclaw" -> "~/code/openclaw"
    public func decode(_ encoded: String) -> String {
        let withoutLeading = encoded.hasPrefix("-") ? String(encoded.dropFirst()) : encoded
        let parts = withoutLeading.split(separator: "-").map(String.init)

        guard let usersIdx = parts.firstIndex(of: "Users") else { return encoded }

        let afterHome = Array(parts.dropFirst(usersIdx + 2))
        guard !afterHome.isEmpty else { return "~" }

        return "~/" + afterHome.joined(separator: "/")
    }

    /// Extract just the project name (last path component).
    /// e.g. "-Users-brennan-code-openclaw" -> "openclaw"
    public func projectName(_ encoded: String) -> String {
        let decoded = decode(encoded)
        guard let lastSlash = decoded.lastIndex(of: "/") else { return decoded }
        return String(decoded[decoded.index(after: lastSlash)...])
    }
}
