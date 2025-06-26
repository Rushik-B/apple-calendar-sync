import Foundation

class GoogleClient {
    private let auth: GoogleAuth
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    
    init(auth: GoogleAuth) {
        self.auth = auth
    }
    
    func listCalendars() async throws -> [GoogleCalendar] {
        let accessToken = try await auth.getAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/users/me/calendarList")!
        components.queryItems = [
            URLQueryItem(name: "showDeleted", value: "false"),
            URLQueryItem(name: "showHidden", value: "false")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GoogleClientError.unexpectedResponse
        }
        
        let calendarList = try JSONDecoder().decode(GoogleCalendarList.self, from: data)
        return calendarList.items ?? []
    }
    
    func listEvents(for calendarId: String, syncToken: String? = nil, pageToken: String? = nil) async throws -> EventsResult {
        let accessToken = try await auth.getAccessToken()
        
        var components = URLComponents(string: "\(baseURL)/calendars/\(calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId)/events")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "showDeleted", value: "true"),  // Important for sync
            URLQueryItem(name: "singleEvents", value: "true"), // Expand recurring events
            URLQueryItem(name: "maxResults", value: "250")     // Maximum allowed per page
        ]
        
        if let syncToken = syncToken {
            queryItems.append(URLQueryItem(name: "syncToken", value: syncToken))
        } else {
            // For initial sync, get events from 1 year ago to future
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            queryItems.append(URLQueryItem(name: "timeMin", value: formatter.string(from: oneYearAgo)))
        }
        
        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleClientError.unexpectedResponse
        }
        
        // Handle 410 Gone (sync token expired)
        if httpResponse.statusCode == 410 {
            // Retry without sync token
            if syncToken != nil {
                return try await listEvents(for: calendarId, syncToken: nil, pageToken: pageToken)
            }
            throw GoogleClientError.syncTokenExpired
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GoogleClientError.unexpectedResponse
        }
        
        let eventsList = try JSONDecoder().decode(GoogleEventsList.self, from: data)
        var allEvents = eventsList.items ?? []
        
        // Handle pagination
        if let nextPageToken = eventsList.nextPageToken {
            let nextPageResult = try await listEvents(for: calendarId, syncToken: syncToken, pageToken: nextPageToken)
            allEvents.append(contentsOf: nextPageResult.events)
            return EventsResult(events: allEvents, nextSyncToken: nextPageResult.nextSyncToken)
        }
        
        return EventsResult(events: allEvents, nextSyncToken: eventsList.nextSyncToken)
    }
}

// Helper structures
struct EventsResult {
    let events: [GoogleEvent]
    let nextSyncToken: String?
}

enum GoogleClientError: LocalizedError {
    case unexpectedResponse
    case syncTokenExpired
    
    var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return "Received unexpected response from Google Calendar API"
        case .syncTokenExpired:
            return "Sync token has expired, performing full sync"
        }
    }
} 