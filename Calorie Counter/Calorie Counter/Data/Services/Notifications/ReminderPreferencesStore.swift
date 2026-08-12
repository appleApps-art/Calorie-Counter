import Foundation

protocol ReminderPreferencesStoring: AnyObject {
    var configuration: ReminderScheduleConfiguration { get set }
    func preference(for kind: ReminderKind) -> ReminderPreference?
    func updatePreference(_ preference: ReminderPreference)
}

final class ReminderPreferencesStore: ReminderPreferencesStoring {
    private let defaults: UserDefaults
    private let key = "avo.reminders.configuration"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var configuration: ReminderScheduleConfiguration {
        get {
            guard let data = defaults.data(forKey: key) else {
                return .default
            }
            do {
                return try JSONDecoder().decode(ReminderScheduleConfiguration.self, from: data)
            } catch {
                return .default
            }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }

    func preference(for kind: ReminderKind) -> ReminderPreference? {
        configuration.preferences.first(where: { $0.kind == kind })
    }

    func updatePreference(_ preference: ReminderPreference) {
        var config = configuration
        if let index = config.preferences.firstIndex(where: { $0.kind == preference.kind }) {
            config.preferences[index] = preference
        } else {
            config.preferences.append(preference)
        }
        configuration = config
    }
}
