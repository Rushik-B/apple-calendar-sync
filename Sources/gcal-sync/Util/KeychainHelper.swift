import Foundation
import KeychainAccess

class KeychainHelper {
    private static let keychain = Keychain(service: "com.gcalsync.credentials")
    
    enum Key: String {
        case googleRefreshToken = "google_refresh_token"
        case googleClientId = "google_client_id"
        case googleClientSecret = "google_client_secret"
    }
    
    static func save(_ value: String, for key: Key) throws {
        try keychain.set(value, key: key.rawValue)
    }
    
    static func get(_ key: Key) throws -> String? {
        return try keychain.get(key.rawValue)
    }
    
    static func delete(_ key: Key) throws {
        try keychain.remove(key.rawValue)
    }
    
    static func deleteAll() throws {
        try keychain.removeAll()
    }
} 