import Foundation

public struct FileScanner: Sendable {
    private let projectsDir: String

    public init() {
        self.projectsDir = NSHomeDirectory() + "/.claude/projects"
    }

    public func discoverFiles() -> [FileInfo] {
        var paths: [String] = []
        walkJsonl(dir: projectsDir, results: &paths)

        var files: [FileInfo] = []
        let fm = FileManager.default

        for filePath in paths {
            guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                  let modDate = attrs[.modificationDate] as? Date,
                  let size = attrs[.size] as? Int else {
                continue
            }

            let mtimeMs = Int(modDate.timeIntervalSince1970 * 1000)
            let sessionId = extractSessionId(filePath: filePath)
            let projectDir = extractProjectDir(filePath: filePath)

            files.append(FileInfo(
                filePath: filePath,
                mtimeMs: mtimeMs,
                size: size,
                sessionId: sessionId,
                projectDir: projectDir
            ))
        }

        return files
    }

    public func diffFiles(
        discovered: [FileInfo],
        cached: [String: (mtimeMs: Int, size: Int)]
    ) -> DiffResult {
        var added: [FileInfo] = []
        var changed: [FileInfo] = []
        var unchanged: [String] = []
        var seenPaths = Set<String>()

        for file in discovered {
            seenPaths.insert(file.filePath)

            guard let cachedEntry = cached[file.filePath] else {
                added.append(file)
                continue
            }

            if cachedEntry.mtimeMs != file.mtimeMs || cachedEntry.size != file.size {
                changed.append(file)
                continue
            }

            unchanged.append(file.filePath)
        }

        let removed = cached.keys.filter { !seenPaths.contains($0) }

        return DiffResult(added: added, changed: changed, removed: removed, unchanged: unchanged)
    }

    private func walkJsonl(dir: String, results: inout [String]) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }

        for entry in entries {
            let fullPath = dir + "/" + entry
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                walkJsonl(dir: fullPath, results: &results)
                continue
            }

            if entry.hasSuffix(".jsonl") {
                results.append(fullPath)
            }
        }
    }

    private func extractSessionId(filePath: String) -> String {
        let name = (filePath as NSString).lastPathComponent
        if name.hasSuffix(".jsonl") {
            return String(name.dropLast(6))
        }
        return name
    }

    private func extractProjectDir(filePath: String) -> String {
        let prefix = projectsDir + "/"
        guard filePath.hasPrefix(prefix) else { return filePath }
        let relative = String(filePath.dropFirst(prefix.count))
        guard let firstSlash = relative.firstIndex(of: "/") else { return relative }
        return String(relative[relative.startIndex..<firstSlash])
    }
}
