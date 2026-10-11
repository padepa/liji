import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    static func string(_ key: String, fallback: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }

    static func format(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(format: string(key, fallback: fallback), locale: Locale.current, arguments: arguments)
    }

    static func count(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(string(key), count)
    }
}
