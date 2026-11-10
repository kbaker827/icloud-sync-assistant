import Foundation

/// The iCloud features shown as cards on the dashboard.
public enum ICloudService: String, CaseIterable, Identifiable, Sendable {
    case photos
    case messages
    case notes
    case contacts
    case calendar
    case reminders
    case safari
    case passwords
    case drive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .photos: return "Photos"
        case .messages: return "Messages"
        case .notes: return "Notes"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .safari: return "Safari"
        case .passwords: return "Passwords"
        case .drive: return "iCloud Drive"
        }
    }

    /// SF Symbol shown on the card.
    public var symbolName: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .messages: return "message.fill"
        case .notes: return "note.text"
        case .contacts: return "person.crop.circle"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .safari: return "safari"
        case .passwords: return "key.fill"
        case .drive: return "icloud.fill"
        }
    }

    /// Mac apps to open for this service, in order of preference.
    /// iCloud Drive is opened in Finder instead, so it has none.
    public var bundleIdentifiers: [String] {
        switch self {
        case .photos: return ["com.apple.Photos"]
        case .messages: return ["com.apple.MobileSMS"]
        case .notes: return ["com.apple.Notes"]
        case .contacts: return ["com.apple.AddressBook"]
        case .calendar: return ["com.apple.iCal"]
        case .reminders: return ["com.apple.reminders"]
        case .safari: return ["com.apple.Safari"]
        case .passwords: return ["com.apple.Passwords"]
        case .drive: return []
        }
    }

    /// Service names used in macOS's iCloud account preferences (MobileMeAccounts).
    /// When none of these appear, the dashboard says it isn't sure rather than guessing.
    public var accountServiceNames: [String] {
        switch self {
        case .photos: return ["CLOUD_PHOTOS", "CLOUDPHOTOS"]
        case .messages: return ["MESSAGES", "CLOUD_MESSAGES"]
        case .notes: return ["NOTES"]
        case .contacts: return ["CONTACTS"]
        case .calendar: return ["CALENDAR"]
        case .reminders: return ["REMINDERS"]
        case .safari: return ["BOOKMARKS"]
        case .passwords: return ["KEYCHAIN_SYNC"]
        case .drive: return ["MOBILE_DOCUMENTS"]
        }
    }

    /// What to do on the Mac to make this service catch up.
    public var macTip: String {
        switch self {
        case .photos:
            return "Open Photos and click Library. The bottom of the window shows sync progress. If it says Paused, click Resume."
        case .messages:
            return "Open Messages, then choose Messages > Settings > iMessage and click Sync Now."
        case .notes:
            return "Open Notes and leave it open for a minute. Notes syncs while the app is open."
        case .contacts:
            return "Open Contacts. Your iCloud contacts refresh each time the app opens."
        case .calendar:
            return "Open Calendar and choose View > Refresh Calendars (Command-R)."
        case .reminders:
            return "Open Reminders and leave it open for a minute so it can catch up."
        case .safari:
            return "Open Safari. Bookmarks, Reading List and tabs sync while Safari is open."
        case .passwords:
            return "Open the Passwords app (or System Settings > Passwords on older Macs) and make sure iCloud Keychain is on."
        case .drive:
            return "Open iCloud Drive in Finder. A cloud icon next to a file means it's still uploading or waiting to download."
        }
    }

    /// What to do on the iPhone to make this service catch up.
    public var iPhoneTip: String {
        switch self {
        case .photos:
            return "Open Photos, tap Library and scroll to the bottom to see sync status. Leave the iPhone plugged in and on Wi-Fi to finish."
        case .messages:
            return "Go to Settings > [your name] > iCloud > Messages in iCloud and tap Sync Now."
        case .notes:
            return "Open Notes and pull down on the folder list to refresh."
        case .contacts:
            return "Go to Settings > [your name] > iCloud and make sure Contacts is on, then open the Contacts app."
        case .calendar:
            return "Open Calendar, tap Calendars at the bottom, then pull down on the list to refresh."
        case .reminders:
            return "Open Reminders and pull down on the list to refresh."
        case .safari:
            return "Go to Settings > [your name] > iCloud and make sure Safari is on, then open Safari."
        case .passwords:
            return "Go to Settings > [your name] > iCloud > Passwords and Keychain and make sure it's on."
        case .drive:
            return "Open the Files app, tap Browse > iCloud Drive and pull down to refresh."
        }
    }
}
