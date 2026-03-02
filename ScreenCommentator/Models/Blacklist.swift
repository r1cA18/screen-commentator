import Foundation

struct BlacklistEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var pattern: String
    var matchType: MatchType

    enum MatchType: String, Codable, CaseIterable {
        case url
        case bundleID
    }

    init(pattern: String, matchType: MatchType = .url) {
        self.id = UUID()
        self.pattern = pattern
        self.matchType = matchType
    }
}

@MainActor
final class BlacklistManager: ObservableObject {
    @Published var entries: [BlacklistEntry] {
        didSet { save() }
    }

    private static let storageKey = "blacklistEntries"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([BlacklistEntry].self, from: data) {
            self.entries = decoded
        } else {
            self.entries = Self.defaultEntries
        }
    }

    private static let defaultEntries: [BlacklistEntry] = [
        BlacklistEntry(pattern: "youtube.com"),
        BlacklistEntry(pattern: "twitter.com"),
        BlacklistEntry(pattern: "x.com"),
        BlacklistEntry(pattern: "reddit.com"),
        BlacklistEntry(pattern: "tiktok.com"),
        BlacklistEntry(pattern: "instagram.com"),
    ]

    func matches(app: ActiveAppInfo) -> Bool {
        for entry in entries {
            switch entry.matchType {
            case .url:
                if let url = app.url,
                   url.localizedCaseInsensitiveContains(entry.pattern) {
                    return true
                }
            case .bundleID:
                if app.bundleIdentifier.localizedCaseInsensitiveContains(entry.pattern) {
                    return true
                }
            }
        }
        return false
    }

    func add(_ entry: BlacklistEntry) {
        entries.append(entry)
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
