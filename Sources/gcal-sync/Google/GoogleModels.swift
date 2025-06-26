import Foundation

// Google Calendar API Models

struct GoogleCalendarList: Codable {
    let items: [GoogleCalendar]?
    let nextPageToken: String?
}

struct GoogleCalendar: Codable {
    let id: String
    let summary: String?
    let description: String?
    let backgroundColor: String?
    let foregroundColor: String?
    let selected: Bool?
    let hidden: Bool?
    let primary: Bool?
}

struct GoogleEventsList: Codable {
    let items: [GoogleEvent]?
    let nextPageToken: String?
    let nextSyncToken: String?
}

struct GoogleEvent: Codable {
    let id: String
    let status: String?
    let summary: String?
    let description: String?
    let location: String?
    let start: GoogleEventDateTime?
    let end: GoogleEventDateTime?
    let recurrence: [String]?
    let attendees: [GoogleEventAttendee]?
    let reminders: GoogleEventReminders?
    let htmlLink: String?
    let conferenceData: GoogleConferenceData?
    
    var isDeleted: Bool {
        return status == "cancelled"
    }
}

struct GoogleEventDateTime: Codable {
    let date: String?      // For all-day events (YYYY-MM-DD)
    let dateTime: String?  // For timed events (RFC3339)
    let timeZone: String?
    
    var dateValue: Date? {
        if let dateTime = dateTime {
            // Parse RFC3339 datetime
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateTime) {
                return date
            }
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateTime)
        } else if let date = date {
            // Parse date only (YYYY-MM-DD)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.date(from: date)
        }
        return nil
    }
}

struct GoogleEventAttendee: Codable {
    let email: String?
    let displayName: String?
    let organizer: Bool?
    let responseStatus: String?
}

struct GoogleEventReminders: Codable {
    let useDefault: Bool?
    let overrides: [GoogleEventReminder]?
}

struct GoogleEventReminder: Codable {
    let method: String?
    let minutes: Int?
}

struct GoogleConferenceData: Codable {
    let entryPoints: [GoogleEntryPoint]?
}

struct GoogleEntryPoint: Codable {
    let entryPointType: String?
    let uri: String?
    let label: String?
} 