import Foundation

public enum DataStore {
    public static let defaultSuiteName = "group.com.opencode.widget"
    public static let defaultFileName = "widget-data.json"

    public static func sharedContainerURL(suiteName: String = defaultSuiteName, fileName: String = defaultFileName) -> URL? {
        if suiteName.hasPrefix("/") {
            let dir = URL(fileURLWithPath: suiteName, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent(fileName)
        }
        if suiteName == defaultSuiteName,
           let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let directory = applicationSupport.appendingPathComponent("OpencodeWidgetApp", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent(fileName)
        }
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) {
            try? FileManager.default.createDirectory(at: groupURL, withIntermediateDirectories: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: groupURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return groupURL.appendingPathComponent(fileName)
            }
        }
        return nil
    }

    public static func save(cache: WidgetCache, suiteName: String = defaultSuiteName, fileName: String = defaultFileName) {
        guard let url = sharedContainerURL(suiteName: suiteName, fileName: fileName) else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public static func load(suiteName: String = defaultSuiteName, fileName: String = defaultFileName) -> WidgetCache? {
        guard let url = sharedContainerURL(suiteName: suiteName, fileName: fileName),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetCache.self, from: data)
    }
}
