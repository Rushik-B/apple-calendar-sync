# Google Calendar to Apple Calendar Sync

A native macOS application that automatically syncs your Google Calendars to Apple Calendar, ensuring your Apple devices (iPhone, Apple Watch, etc.) always have up-to-date calendar information.

## Features

- 🔄 **One-way sync** from Google Calendar to Apple Calendar
- 📅 **Automatic calendar creation** - Creates corresponding Apple Calendars for each Google Calendar
- 🎨 **Preserves calendar colors** from Google Calendar
- 📍 **Full event details** - Syncs titles, descriptions, locations, attendees, and URLs
- 🔁 **Recurring events** - Properly handles complex recurrence rules
- ⏰ **Reminders/Alarms** - Syncs notification settings
- 🚀 **Incremental sync** - Only fetches changes since last sync for efficiency
- 🔐 **Secure credential storage** - Uses macOS Keychain for OAuth tokens
- 🤖 **Automatic scheduling** - Can run hourly in the background via launchd

## Prerequisites

- macOS 12.0 (Monterey) or later
- Swift 5.9 or later
- Google account with calendars
- Apple ID with iCloud calendars enabled

## Installation

### 1. Clone and Build

```bash
# Clone the repository
git clone <repository-url>
cd apple-calendar-sync

# Build the project
swift build -c release

# Copy the executable to a system location
sudo cp .build/release/gcal-sync /usr/local/bin/
```

### 2. Google Calendar API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Calendar API:
   - Go to "APIs & Services" > "Library"
   - Search for "Google Calendar API"
   - Click on it and press "Enable"
4. Create OAuth 2.0 credentials:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth client ID"
   - Choose "Desktop app" as the application type
   - Give it a name (e.g., "Calendar Sync")
   - Download the credentials or note the Client ID and Client Secret

### 3. Initial Setup

Run the setup command to configure your Google API credentials:

```bash
gcal-sync setup
```

You'll be prompted to enter your Client ID and Client Secret from the Google Cloud Console.

### 4. First Sync

Run your first sync:

```bash
gcal-sync sync
```

On the first run:
1. You'll be given a URL to visit in your browser
2. Sign in to your Google account and grant calendar permissions
3. Copy the authorization code and paste it back in the terminal
4. The app will request access to your Apple Calendar (approve in the system dialog)

## Usage

### Manual Sync

```bash
# Run a sync
gcal-sync

# Or explicitly
gcal-sync sync
```

### Check Status

```bash
gcal-sync status
```

### Reset Sync State

If you want to perform a full re-sync:

```bash
gcal-sync reset
gcal-sync sync
```

### Help

```bash
gcal-sync help
```

## Automatic Scheduling

To run the sync automatically every hour:

1. Edit the provided `com.gcalsync.plist` file:
   - Replace `/Users/USERNAME` with your actual home directory path
   - Adjust the path to `gcal-sync` if you installed it elsewhere

2. Install the launch agent:

```bash
# Copy the plist to LaunchAgents
cp com.gcalsync.plist ~/Library/LaunchAgents/

# Load the agent
launchctl load ~/Library/LaunchAgents/com.gcalsync.plist
```

3. To stop automatic syncing:

```bash
launchctl unload ~/Library/LaunchAgents/com.gcalsync.plist
```

4. Check logs:

```bash
# View sync output
tail -f /tmp/gcal-sync.log

# View errors
tail -f /tmp/gcal-sync.error.log
```

## How It Works

1. **Authentication**: Uses OAuth 2.0 to securely access your Google Calendar
2. **Calendar Mapping**: Creates Apple Calendars with "GCal: " prefix to match your Google Calendars
3. **Event Syncing**: 
   - Fetches events from Google Calendar API
   - Creates/updates/deletes corresponding events in Apple Calendar
   - Embeds Google event IDs in Apple event notes for tracking
4. **Incremental Updates**: Uses Google's sync tokens to only fetch changes since last sync
5. **State Management**: Saves sync tokens in `~/Library/Application Support/gcal-sync/`

## Troubleshooting

### "Access to Calendar was denied"

Grant calendar access in System Settings:
1. Open System Settings > Privacy & Security > Calendar
2. Find and enable `gcal-sync`

### "Missing Google API credentials"

Run `gcal-sync setup` to configure your Google API credentials.

### Events not appearing on iPhone/Apple Watch

1. Ensure iCloud Calendar sync is enabled on all devices
2. Check that the "GCal: " calendars are selected in the Calendar app
3. Try toggling calendar visibility in Calendar app settings

### Sync seems stuck or not working

1. Check the logs: `tail -f /tmp/gcal-sync.log`
2. Try resetting sync state: `gcal-sync reset`
3. Ensure you have internet connectivity
4. Verify Google API credentials are still valid

### Building from source fails

Ensure you have Xcode Command Line Tools installed:
```bash
xcode-select --install
```

## Privacy & Security

- **OAuth tokens** are stored securely in macOS Keychain
- **Read-only access** to Google Calendar (doesn't modify Google events)
- **Local processing** - no data is sent to third-party servers
- **Open source** - you can review the code for security

## Limitations

- **One-way sync only** - changes in Apple Calendar won't sync back to Google
- **Attendee limitations** - EventKit API doesn't allow full attendee manipulation
- **No calendar deletion** - manually created calendars must be manually removed

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

[Your chosen license] 