import Foundation

// Main async function
@main
struct GCalSync {
    static func main() async {
        let command = parseCommand()
        
        do {
            switch command {
            case .help:
                printHelp()
                
            case .setup:
                print("🔧 Setting up Google Calendar API credentials...")
                let auth = try GoogleAuth()
                try auth.setupCredentials()
                print("✅ Credentials saved successfully!")
                
            case .sync:
                let engine = try await SyncEngine()
                try await engine.performSync(verbose: true)
                
            case .status:
                let engine = try await SyncEngine()
                try engine.showStatus()
                
            case .reset:
                let engine = try await SyncEngine()
                try engine.resetSync()
            }
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            
            // Provide more specific error messages
            if let authError = error as? AuthError {
                switch authError {
                case .missingCredentials:
                    print("\n💡 Tip: Run 'gcal-sync setup' to configure Google API credentials")
                default:
                    break
                }
            } else if let appleError = error as? AppleCalendarError {
                switch appleError {
                case .accessDenied:
                    print("\n💡 Tip: Grant calendar access in System Settings > Privacy & Security > Calendar")
                default:
                    break
                }
            }
            
            exit(1)
        }
    }
    
    // Command-line argument parsing
    enum Command {
        case sync
        case status
        case reset
        case help
        case setup
    }
    
    static func parseCommand() -> Command {
        let args = CommandLine.arguments
        
        if args.count < 2 {
            return .sync // Default to sync
        }
        
        switch args[1].lowercased() {
        case "sync":
            return .sync
        case "status":
            return .status
        case "reset":
            return .reset
        case "setup":
            return .setup
        case "help", "--help", "-h":
            return .help
        default:
            return .help
        }
    }
    
    static func printHelp() {
        print("""
        Google Calendar to Apple Calendar Sync Tool
        
        Usage: gcal-sync [command]
        
        Commands:
            sync    - Perform calendar synchronization (default)
            status  - Show sync status and last sync time
            reset   - Reset sync state (next sync will be full sync)
            setup   - Set up Google API credentials
            help    - Show this help message
        
        Examples:
            gcal-sync               # Run sync
            gcal-sync sync          # Run sync (explicit)
            gcal-sync status        # Check sync status
            gcal-sync reset         # Reset sync state
        
        The tool will sync your Google Calendars to Apple Calendar, creating
        calendars prefixed with "GCal: " to avoid conflicts.
        """)
    }
} 