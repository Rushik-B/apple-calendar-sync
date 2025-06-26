import Foundation
import EventKit

class AppleCalendar {
    private let eventStore = EKEventStore()
    private var hasAccess = false
    private let googleIdPrefix = "[gcal_id:"
    private let googleIdSuffix = "]"
    
    init() async throws {
        // Request access to calendars
        if #available(macOS 14.0, *) {
            hasAccess = try await eventStore.requestFullAccessToEvents()
        } else {
            hasAccess = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        
        if !hasAccess {
            throw AppleCalendarError.accessDenied
        }
    }
    
    func findOrCreateCalendar(named name: String, color: CGColor? = nil) throws -> EKCalendar {
        // First, try to find existing calendar
        let calendars = eventStore.calendars(for: .event)
        if let existingCalendar = calendars.first(where: { $0.title == name }) {
            return existingCalendar
        }
        
        // Create new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = name
        
        // Find the iCloud source (preferred) or local source
        let sources = eventStore.sources
        if let iCloudSource = sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            newCalendar.source = iCloudSource
        } else if let localSource = sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else {
            throw AppleCalendarError.noSuitableCalendarSource
        }
        
        // Set color if provided
        if let color = color {
            newCalendar.cgColor = color
        }
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
    
    func findEvent(withGoogleId googleId: String, in calendar: EKCalendar) -> EKEvent? {
        let predicate = eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-365 * 24 * 60 * 60), // 1 year ago
            end: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year future
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        return events.first { event in
            event.notes?.contains("\(googleIdPrefix)\(googleId)\(googleIdSuffix)") ?? false
        }
    }
    
    func createEvent(from googleEvent: GoogleEventData, in calendar: EKCalendar) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        
        try updateEvent(event, from: googleEvent)
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        return event
    }
    
    func updateEvent(_ event: EKEvent, from googleEvent: GoogleEventData) throws {
        // Basic properties
        event.title = googleEvent.summary ?? "(No title)"
        
        // Build notes with Google ID embedded
        var notes = ""
        if let description = googleEvent.description {
            notes = description
        }
        notes += "\n\n\(googleIdPrefix)\(googleEvent.id)\(googleIdSuffix)"
        event.notes = notes
        
        // Location
        event.location = googleEvent.location
        
        // Start and end dates
        if let start = googleEvent.startDate, let end = googleEvent.endDate {
            event.startDate = start
            event.endDate = end
            event.isAllDay = googleEvent.isAllDay
        }
        
        // Recurrence rules
        if let recurrenceRules = googleEvent.recurrenceRules {
            event.recurrenceRules = recurrenceRules
        }
        
        // Alarms/Reminders
        event.alarms = googleEvent.alarms
        
        // Attendees (if available)
        if googleEvent.attendees != nil {
            // Note: EventKit doesn't allow direct manipulation of attendees
            // We can only set the organizer and EventKit handles invitations
            // This is a limitation of the EventKit API
        }
        
        // URL
        event.url = googleEvent.url
    }
    
    func deleteEvent(_ event: EKEvent) throws {
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func deleteAllEvents(in calendar: EKCalendar) throws {
        let predicate = eventStore.predicateForEvents(
            withStart: Date().addingTimeInterval(-365 * 24 * 60 * 60), // 1 year ago
            end: Date().addingTimeInterval(365 * 24 * 60 * 60), // 1 year future
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        for event in events {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        try eventStore.commit()
    }
}

// Data structure to hold Google event data in a format we can use
struct GoogleEventData {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let startDate: Date?
    let endDate: Date?
    let isAllDay: Bool
    let recurrenceRules: [EKRecurrenceRule]?
    let alarms: [EKAlarm]?
    let attendees: [String]?
    let url: URL?
}

enum AppleCalendarError: LocalizedError {
    case accessDenied
    case noSuitableCalendarSource
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Calendar was denied. Please grant permission in System Preferences > Security & Privacy > Privacy > Calendar"
        case .noSuitableCalendarSource:
            return "No suitable calendar source found (iCloud or Local)"
        }
    }
} 