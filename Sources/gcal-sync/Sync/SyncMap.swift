import Foundation
import EventKit

class SyncMap {
    
    static func mapGoogleEventToAppleEventData(_ googleEvent: GoogleEvent) -> GoogleEventData {
        let id = googleEvent.id
        let summary = googleEvent.summary
        let description = googleEvent.description
        let location = googleEvent.location
        
        // Parse dates
        let (startDate, endDate, isAllDay) = parseDates(from: googleEvent)
        
        // Parse recurrence rules
        let recurrenceRules = parseRecurrenceRules(from: googleEvent)
        
        // Parse reminders/alarms
        let alarms = parseAlarms(from: googleEvent)
        
        // Parse attendees
        let attendees = googleEvent.attendees?.compactMap { $0.email }
        
        // Parse URL from conference data or htmlLink
        let url = parseURL(from: googleEvent)
        
        return GoogleEventData(
            id: id,
            summary: summary,
            description: description,
            location: location,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            recurrenceRules: recurrenceRules,
            alarms: alarms,
            attendees: attendees,
            url: url
        )
    }
    
    private static func parseDates(from googleEvent: GoogleEvent) -> (start: Date?, end: Date?, isAllDay: Bool) {
        var startDate: Date?
        var endDate: Date?
        var isAllDay = false
        
        if let start = googleEvent.start {
            if start.dateTime != nil {
                startDate = start.dateValue
            } else if start.date != nil {
                startDate = start.dateValue
                isAllDay = true
            }
        }
        
        if let end = googleEvent.end {
            if end.dateTime != nil {
                endDate = end.dateValue
            } else if end.date != nil {
                endDate = end.dateValue
                // For all-day events, Google uses exclusive end date, Apple uses inclusive
                // So we need to subtract one day
                if isAllDay, let endDateValue = endDate {
                    endDate = Calendar.current.date(byAdding: .day, value: -1, to: endDateValue)
                }
            }
        }
        
        return (startDate, endDate, isAllDay)
    }
    
    private static func parseRecurrenceRules(from googleEvent: GoogleEvent) -> [EKRecurrenceRule]? {
        guard let recurrenceStrings = googleEvent.recurrence else { return nil }
        
        var rules: [EKRecurrenceRule] = []
        
        for rruleString in recurrenceStrings {
            if rruleString.hasPrefix("RRULE:") {
                let rrule = String(rruleString.dropFirst(6)) // Remove "RRULE:"
                if let rule = parseRRule(rrule) {
                    rules.append(rule)
                }
            }
        }
        
        return rules.isEmpty ? nil : rules
    }
    
    private static func parseRRule(_ rrule: String) -> EKRecurrenceRule? {
        var frequency: EKRecurrenceFrequency?
        var interval = 1
        var daysOfWeek: [EKRecurrenceDayOfWeek]?
        var daysOfMonth: [NSNumber]?
        var monthsOfYear: [NSNumber]?
        let weeksOfYear: [NSNumber]? = nil
        let daysOfYear: [NSNumber]? = nil
        let setPositions: [NSNumber]? = nil
        var end: EKRecurrenceEnd?
        
        // Parse RRULE components
        let components = rrule.split(separator: ";").map { String($0) }
        
        for component in components {
            let parts = component.split(separator: "=", maxSplits: 1).map { String($0) }
            guard parts.count == 2 else { continue }
            
            let key = parts[0]
            let value = parts[1]
            
            switch key {
            case "FREQ":
                frequency = parseFrequency(value)
                
            case "INTERVAL":
                interval = Int(value) ?? 1
                
            case "BYDAY":
                daysOfWeek = parseDaysOfWeek(value)
                
            case "BYMONTHDAY":
                daysOfMonth = value.split(separator: ",").compactMap { NSNumber(value: Int($0) ?? 0) }
                
            case "BYMONTH":
                monthsOfYear = value.split(separator: ",").compactMap { NSNumber(value: Int($0) ?? 0) }
                
            case "COUNT":
                if let count = Int(value) {
                    end = EKRecurrenceEnd(occurrenceCount: count)
                }
                
            case "UNTIL":
                if let untilDate = parseDateTime(value) {
                    end = EKRecurrenceEnd(end: untilDate)
                }
                
            default:
                break
            }
        }
        
        guard let freq = frequency else { return nil }
        
        return EKRecurrenceRule(
            recurrenceWith: freq,
            interval: interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: daysOfMonth,
            monthsOfTheYear: monthsOfYear,
            weeksOfTheYear: weeksOfYear,
            daysOfTheYear: daysOfYear,
            setPositions: setPositions,
            end: end
        )
    }
    
    private static func parseFrequency(_ value: String) -> EKRecurrenceFrequency? {
        switch value {
        case "DAILY": return .daily
        case "WEEKLY": return .weekly
        case "MONTHLY": return .monthly
        case "YEARLY": return .yearly
        default: return nil
        }
    }
    
    private static func parseDaysOfWeek(_ value: String) -> [EKRecurrenceDayOfWeek]? {
        let dayMap: [String: EKWeekday] = [
            "SU": .sunday,
            "MO": .monday,
            "TU": .tuesday,
            "WE": .wednesday,
            "TH": .thursday,
            "FR": .friday,
            "SA": .saturday
        ]
        
        let days = value.split(separator: ",").compactMap { dayString -> EKRecurrenceDayOfWeek? in
            let day = String(dayString)
            
            // Check for positional prefix (e.g., "1MO" for first Monday)
            if day.count > 2 {
                let position = String(day.dropLast(2))
                let dayCode = String(day.suffix(2))
                
                if let weekNumber = Int(position),
                   let weekday = dayMap[dayCode] {
                    return EKRecurrenceDayOfWeek(weekday, weekNumber: weekNumber)
                }
            } else if let weekday = dayMap[day] {
                return EKRecurrenceDayOfWeek(weekday)
            }
            
            return nil
        }
        
        return days.isEmpty ? nil : days
    }
    
    private static func parseDateTime(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: value)
    }
    
    private static func parseAlarms(from googleEvent: GoogleEvent) -> [EKAlarm]? {
        var alarms: [EKAlarm] = []
        
        // Default reminders
        if let reminders = googleEvent.reminders,
           let overrides = reminders.overrides {
            for reminder in overrides {
                if let minutes = reminder.minutes {
                    let offset = TimeInterval(-minutes * 60) // negative for before event
                    alarms.append(EKAlarm(relativeOffset: offset))
                }
            }
        }
        
        // Use default reminders if not overridden
        if alarms.isEmpty,
           let reminders = googleEvent.reminders,
           reminders.useDefault == true {
            // Default Google Calendar reminder is 10 minutes before
            alarms.append(EKAlarm(relativeOffset: -600)) // -10 minutes
        }
        
        return alarms.isEmpty ? nil : alarms
    }
    
    private static func parseURL(from googleEvent: GoogleEvent) -> URL? {
        // Try conference data first
        if let conferenceData = googleEvent.conferenceData,
           let entryPoint = conferenceData.entryPoints?.first,
           let uri = entryPoint.uri {
            return URL(string: uri)
        }
        
        // Fall back to HTML link
        if let htmlLink = googleEvent.htmlLink {
            return URL(string: htmlLink)
        }
        
        return nil
    }
    
    // Helper function to extract color from Google Calendar
    static func parseColor(from googleCalendar: GoogleCalendar) -> CGColor? {
        guard let colorId = googleCalendar.backgroundColor else { return nil }
        
        // Convert hex color to CGColor
        let hex = colorId.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6 else { return nil }
        
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
} 