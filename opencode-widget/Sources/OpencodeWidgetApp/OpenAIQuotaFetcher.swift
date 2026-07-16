import Foundation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

enum OpenAIQuotaFetcher {
    static func fetch(
        helperPath: String,
        usageURL: URL,
        timeout: TimeInterval
    ) async -> OpenAIQuota? {
        let process = Process()
        let output = Pipe()
        if helperPath.hasSuffix(".mjs") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["node", helperPath]
        } else {
            process.executableURL = URL(fileURLWithPath: helperPath)
            process.arguments = []
        }
        var environment = ProcessInfo.processInfo.environment
        environment["OPENAI_USAGE_URL"] = usageURL.absoluteString
        process.environment = environment
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let waitTask = Task.detached {
            process.waitUntilExit()
        }

        let completed = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            group.addTask {
                await waitTask.value
                return true
            }
            group.addTask {
                do {
                    try await Task.sleep(for: .seconds(timeout))
                } catch {
                    return true
                }
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }

        guard completed else {
            process.terminate()
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(OpenAIQuota.self, from: data)
    }
}
