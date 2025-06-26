import Foundation

class Config {
    private static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/gcal-sync")
    private static let configFile = configDirectory.appendingPathComponent("state.json")
    
    struct SyncState: Codable {
        var calendarSyncTokens: [String: String] = [:]  // Google Calendar ID -> Sync Token
        var lastSyncDate: Date?
    }
    
    static func loadState() throws -> SyncState {
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Load existing state or return empty state
        if FileManager.default.fileExists(atPath: configFile.path) {
            let data = try Data(contentsOf: configFile)
            return try JSONDecoder().decode(SyncState.self, from: data)
        } else {
            return SyncState()
        }
    }
    
    static func saveState(_ state: SyncState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        try data.write(to: configFile)
    }
    
    static func clearState() throws {
        if FileManager.default.fileExists(atPath: configFile.path) {
            try FileManager.default.removeItem(at: configFile)
        }
    }
} 