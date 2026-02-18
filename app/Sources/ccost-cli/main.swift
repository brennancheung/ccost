import Foundation
import CCostLib

func printHelp() {
    print("""
    ccost - Fast Claude Code usage tracker

    Usage: ccost [options]

    Options:
      --since <date>    Show usage from this date (YYYYMMDD or YYYY-MM-DD)
      --until <date>    Show usage until this date (YYYYMMDD or YYYY-MM-DD)
      --project <name>  Filter by project name (partial match)
      --json            Output as JSON
      --rebuild         Force full re-parse (ignore cache)
      -h, --help        Show this help message
    """)
}

func normalizeDate(_ d: String) -> String {
    if d.count == 8 && !d.contains("-") {
        return "\(d.prefix(4))-\(d.dropFirst(4).prefix(2))-\(d.dropFirst(6).prefix(2))"
    }
    return d
}

func parseArgs() -> CliOptions? {
    let args = Array(CommandLine.arguments.dropFirst())
    var since: String?
    var until: String?
    var json = false
    var project: String?
    var rebuild = false
    var i = 0

    while i < args.count {
        let arg = args[i]

        if arg == "-h" || arg == "--help" {
            printHelp()
            return nil
        }

        if arg == "--since" && i + 1 < args.count {
            i += 1
            since = normalizeDate(args[i])
            i += 1
            continue
        }

        if arg == "--until" && i + 1 < args.count {
            i += 1
            until = normalizeDate(args[i])
            i += 1
            continue
        }

        if arg == "--project" && i + 1 < args.count {
            i += 1
            project = args[i]
            i += 1
            continue
        }

        if arg == "--json" {
            json = true
            i += 1
            continue
        }

        if arg == "--rebuild" {
            rebuild = true
            i += 1
            continue
        }

        i += 1
    }

    return CliOptions(since: since, until: until, json: json, project: project, rebuild: rebuild)
}

func main() {
    let startTime = CFAbsoluteTimeGetCurrent()

    guard let opts = parseArgs() else { return }

    let database = CostDatabase()
    let scanner = FileScanner()
    let parser = Parser()
    let formatter = CostFormatter()

    // Rebuild if requested
    if opts.rebuild {
        database.clearCache()
    }

    // Discover all JSONL files
    let discovered = scanner.discoverFiles()

    // Diff against cache
    let cached = database.getCachedFiles()
    let diff = scanner.diffFiles(discovered: discovered, cached: cached)

    // Parse new/changed files
    let filesToProcess = diff.added + diff.changed
    let records = parser.parseFiles(filesToProcess)

    // Write to cache
    if !filesToProcess.isEmpty || !diff.removed.isEmpty {
        database.writeResults(files: filesToProcess, records: records, removedPaths: diff.removed)
    }

    // Query and format
    let summaries = database.queryDailySummaries(since: opts.since, until: opts.until, project: opts.project)

    let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

    if opts.json {
        print(formatter.formatJson(summaries))
    } else {
        print(formatter.formatTable(
            summaries: summaries,
            processedCount: filesToProcess.count,
            cachedCount: diff.unchanged.count,
            elapsedMs: elapsedMs
        ))
    }

    // Print unknown model warnings
    for model in Pricing.shared.unknownModels {
        fputs("\u{1B}[33mWarning: Unknown model \"\(model)\" — using Sonnet pricing as fallback.\u{1B}[0m\n", stderr)
    }
}

main()
