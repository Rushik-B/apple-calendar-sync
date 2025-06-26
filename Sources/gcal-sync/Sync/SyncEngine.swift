import Foundation
import EventKit

class SyncEngine {
    private let googleAuth: GoogleAuth
    private let googleClient: GoogleClient
    private let appleCalendar: AppleCalendar
    
    init() async throws {
        self.googleAuth = try GoogleAuth()
        self.googleClient = GoogleClient(auth: googleAuth)
        self.appleCalendar = try await AppleCalendar()
    }
    
    func performSync(verbose: Bool = false) async throws {
        if verbose {
            print("🔄 Starting sync process...")
        }
        
        // Load saved state
        var state = try Config.loadState()
        
        // Get all Google calendars
        let googleCalendars = try await googleClient.listCalendars()
        
        if verbose {
            print("📅 Found \(googleCalendars.count) Google calendars")
        }
        
        // Process each calendar
        for googleCalendar in googleCalendars {
            let calendarId = googleCalendar.id
            let calendarName = googleCalendar.summary ?? "Untitled Calendar"
            
            // Skip calendars that are not selected or are hidden
            if googleCalendar.selected != true || googleCalendar.hidden == true {
                if verbose {
                    print("⏭️  Skipping calendar: \(calendarName)")
                }
                continue
            }
            
            if verbose {
                print("\n📋 Syncing calendar: \(calendarName)")
            }
            
            // Create or find corresponding Apple calendar
            let appleCalendarName = "GCal: \(calendarName)"
            let color = SyncMap.parseColor(from: googleCalendar)
            let appleCalendarObj = try appleCalendar.findOrCreateCalendar(named: appleCalendarName, color: color)
            
            // Get sync token for incremental sync
            let syncToken = state.calendarSyncTokens[calendarId]
            
            // Fetch events from Google
            let eventsResult = try await googleClient.listEvents(for: calendarId, syncToken: syncToken)
            
            if verbose {
                print("  📥 Fetched \(eventsResult.events.count) events/changes")
            }
            
            // Process each event
            var createdCount = 0
            var updatedCount = 0
            var deletedCount = 0
            
            for googleEvent in eventsResult.events {
                let eventId = googleEvent.id
                
                // Check if event is cancelled (deleted)
                if googleEvent.isDeleted {
                    if let existingEvent = appleCalendar.findEvent(withGoogleId: eventId, in: appleCalendarObj) {
                        try appleCalendar.deleteEvent(existingEvent)
                        deletedCount += 1
                    }
                    continue
                }
                
                // Convert Google event to Apple event data
                let eventData = SyncMap.mapGoogleEventToAppleEventData(googleEvent)
                
                // Check if event already exists in Apple Calendar
                if let existingEvent = appleCalendar.findEvent(withGoogleId: eventId, in: appleCalendarObj) {
                    // Update existing event
                    try appleCalendar.updateEvent(existingEvent, from: eventData)
                    updatedCount += 1
                } else {
                    // Create new event
                    _ = try appleCalendar.createEvent(from: eventData, in: appleCalendarObj)
                    createdCount += 1
                }
            }
            
            if verbose {
                print("  ✅ Created: \(createdCount), Updated: \(updatedCount), Deleted: \(deletedCount)")
            }
            
            // Save new sync token
            if let nextSyncToken = eventsResult.nextSyncToken {
                state.calendarSyncTokens[calendarId] = nextSyncToken
            }
        }
        
        // Update last sync date
        state.lastSyncDate = Date()
        
        // Save state
        try Config.saveState(state)
        
        if verbose {
            print("\n✨ Sync completed successfully!")
            print("📅 Last sync: \(formatDate(state.lastSyncDate!))")
        }
    }
    
    func resetSync() throws {
        print("🗑️  Resetting sync state...")
        
        // Clear saved state
        try Config.clearState()
        
        // Clear keychain (except credentials)
        // We keep the credentials so user doesn't have to re-authenticate
        
        print("✅ Sync state has been reset. Next sync will be a full sync.")
    }
    
    func showStatus() throws {
        let state = try Config.loadState()
        
        print("📊 Sync Status")
        print("=" * 40)
        
        if let lastSync = state.lastSyncDate {
            print("Last sync: \(formatDate(lastSync))")
            print("Time since last sync: \(formatTimeSince(lastSync))")
        } else {
            print("Last sync: Never")
        }
        
        print("\nTracked calendars: \(state.calendarSyncTokens.count)")
        
        if !state.calendarSyncTokens.isEmpty {
            print("\nCalendar sync tokens:")
            for (calendarId, _) in state.calendarSyncTokens {
                print("  - \(calendarId)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimeSince(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
    }
}

// String extension for repeating characters
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
} 