// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import OAuth2
import EventKit

// MARK: - Configuration

// 1. Get your client ID and secret from the Google API Console:
//    https://console.developers.google.com/
// 2. Create an "OAuth 2.0 Client ID" for a "Desktop app".
// 3. Paste the client ID and secret below.
let clientID = "YOUR_CLIENT_ID"
let clientSecret = "YOUR_CLIENT_SECRET"

// The calendar scope gives us read/write access to the user's calendars.
let scope = "https://www.googleapis.com/auth/calendar"

// The redirect URI must be registered in the Google API Console.
// For a desktop app, "urn:ietf:wg:oauth:2.0:oob" is a common choice,
// but we will use a local server to handle the redirect automatically.
let redirectURL = "http://localhost:8080/oauth2/callback"

class CalendarSync {
    let eventStore = EKEventStore()
    var oauth2: OAuth2CodeGrant!

    init() {
        // Using OAuth2CodeGrantGoogle automatically sets up the correct authorize and token URLs.
        oauth2 = OAuth2CodeGrant(settings: [
            "client_id": clientID,
            "client_secret": clientSecret,
            "authorize_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "scope": scope,
            "redirect_uris": [redirectURL],
            "keychain": true, // This will store the token in the keychain
        ] as OAuth2JSON)
    }

    func run() {
        // Check if the user has provided their credentials
        if clientID == "YOUR_CLIENT_ID" || clientSecret == "YOUR_CLIENT_SECRET" {
            print("Please open main.swift and replace YOUR_CLIENT_ID and YOUR_CLIENT_SECRET with your credentials from the Google API Console.")
            return
        }
        
        requestCalendarAccess { granted in
            if granted {
                print("Calendar access granted.")
                self.startGoogleAuthentication()
            } else {
                print("Calendar access was not granted.")
            }
        }
        
        // Keep the script running to handle the OAuth2 callback
        RunLoop.main.run()
    }

    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                if let error = error {
                    print("Error requesting calendar access: \(error.localizedDescription)")
                }
                completion(granted)
            }
        } else {
            // Fallback on earlier versions
            eventStore.requestAccess(to: .event) { granted, error in
                 if let error = error {
                    print("Error requesting calendar access: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }

    func startGoogleAuthentication() {
        oauth2.logger = OAuth2DebugLogger(.trace)
        
        oauth2.authorize() { authParameters, error in
            if let error = error {
                print("Google authentication error: \(error)")
            } else {
                print("Successfully authenticated with Google.")
                self.performSync()
            }
            // We can exit now
            exit(0)
        }
    }

    func performSync() {
        print("Starting calendar sync...")
        // 1. Fetch Google Calendar events
        // 2. Fetch Apple Calendar events
        // 3. Compare and sync
        // This is where the main logic will go.
        
        fetchGoogleEvents()
    }
    
    func fetchGoogleEvents() {
        let request = oauth2.request(forURL: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!)

        let loader = OAuth2DataLoader(oauth2: oauth2)
        loader.perform(request: request) { response in
            do {
                let json = try response.responseJSON()
                print("Google Calendar Events:")
                print(json)
            } catch let error {
                print("Error fetching Google events: \(error)")
            }
        }
    }
}

let sync = CalendarSync()
sync.run()
