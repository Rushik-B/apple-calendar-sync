import Foundation

class GoogleAuth {
    private static let scope = "https://www.googleapis.com/auth/calendar.readonly"
    private static let redirectURI = "urn:ietf:wg:oauth:2.0:oob"
    
    private var clientId: String?
    private var clientSecret: String?
    
    init() throws {
        // Try to load saved credentials
        self.clientId = try KeychainHelper.get(.googleClientId)
        self.clientSecret = try KeychainHelper.get(.googleClientSecret)
    }
    
    func setupCredentials() throws {
        print("=== Google Calendar API Setup ===")
        print("You need to set up Google Calendar API credentials.")
        print("1. Go to https://console.cloud.google.com/")
        print("2. Create a new project or select an existing one")
        print("3. Enable the Google Calendar API")
        print("4. Create credentials (OAuth 2.0 Client ID)")
        print("5. Choose 'Desktop app' as the application type")
        print("")
        
        print("Enter your Client ID: ", terminator: "")
        guard let clientId = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clientId.isEmpty else {
            throw AuthError.invalidInput("Client ID cannot be empty")
        }
        
        print("Enter your Client Secret: ", terminator: "")
        guard let clientSecret = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clientSecret.isEmpty else {
            throw AuthError.invalidInput("Client Secret cannot be empty")
        }
        
        // Save credentials
        try KeychainHelper.save(clientId, for: .googleClientId)
        try KeychainHelper.save(clientSecret, for: .googleClientSecret)
        
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
    
    func getAccessToken() async throws -> String {
        // Check if we have credentials
        if clientId == nil || clientSecret == nil {
            try setupCredentials()
        }
        
        guard let clientId = clientId,
              let clientSecret = clientSecret else {
            throw AuthError.missingCredentials
        }
        
        // Check if we have a refresh token
        if let refreshToken = try KeychainHelper.get(.googleRefreshToken) {
            // Try to use refresh token to get new access token
            do {
                return try await refreshAccessToken(refreshToken: refreshToken, clientId: clientId, clientSecret: clientSecret)
            } catch {
                print("Failed to refresh token, need to re-authenticate: \(error)")
                // Fall through to full auth flow
            }
        }
        
        // Perform full OAuth flow
        return try await performOAuthFlow(clientId: clientId, clientSecret: clientSecret)
    }
    
    private func performOAuthFlow(clientId: String, clientSecret: String) async throws -> String {
        // Build authorization URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        print("\n=== Authorization Required ===")
        print("Please visit this URL to authorize the application:")
        print(components.url!.absoluteString)
        print("\nAfter authorizing, you'll see a code. Enter it here: ", terminator: "")
        
        guard let authCode = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !authCode.isEmpty else {
            throw AuthError.invalidInput("Authorization code cannot be empty")
        }
        
        // Exchange auth code for tokens
        let tokens = try await exchangeAuthCode(authCode: authCode, clientId: clientId, clientSecret: clientSecret)
        
        // Save refresh token
        if let refreshToken = tokens.refreshToken {
            try KeychainHelper.save(refreshToken, for: .googleRefreshToken)
        }
        
        return tokens.accessToken
    }
    
    private func exchangeAuthCode(authCode: String, clientId: String, clientSecret: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "code": authCode,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": Self.redirectURI,
            "grant_type": "authorization_code"
        ]
        
        let bodyString = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }
        
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    
    private func refreshAccessToken(refreshToken: String, clientId: String, clientSecret: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "refresh_token"
        ]
        
        let bodyString = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenRefreshFailed
        }
        
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokens.accessToken
    }
}

// Helper structures and errors
struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

enum AuthError: LocalizedError {
    case missingCredentials
    case invalidInput(String)
    case tokenExchangeFailed
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Missing Google API credentials"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        }
    }
} 