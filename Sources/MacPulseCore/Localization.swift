import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case system, vietnamese = "vi", english = "en"

    public var resolvedCode: String {
        switch self {
        case .system: return Locale.preferredLanguages.first?.hasPrefix("vi") == true ? "vi" : "en"
        case .vietnamese: return "vi"
        case .english: return "en"
        }
    }
}

public struct Localizer: Equatable, Sendable {
    public let language: AppLanguage
    public init(language: AppLanguage = .system) { self.language = language }
    public var locale: Locale { Locale(identifier: language.resolvedCode == "vi" ? "vi_VN" : "en_US") }

    public static var resourceBundle: Bundle {
        // Installed apps must use their bundled resources, not SwiftPM's build-path fallback.
        if let url = Bundle.main.url(forResource: "MacPulse_MacPulseCore", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return Bundle.module
    }

    private var bundle: Bundle {
        guard let path = Self.resourceBundle.path(forResource: language.resolvedCode, ofType: "lproj"),
              let localized = Bundle(path: path) else { return Self.resourceBundle }
        return localized
    }

    public func text(_ key: String, _ arguments: String...) -> String { format(key, arguments: arguments) }
    public func format(_ key: String, arguments: [String]) -> String {
        let template = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: locale, arguments: arguments)
    }
    public func render(_ message: LocalizedMessage) -> String { format(message.key, arguments: message.arguments) }
    public func bytes(_ value: Int64) -> String { DisplayFormat.bytes(value, locale: locale) }
    public func bytes(_ value: UInt64) -> String { DisplayFormat.bytes(value, locale: locale) }
    public func memory(_ value: UInt64) -> String { DisplayFormat.memory(value, locale: locale) }
    public func number(_ value: Int?) -> String { DisplayFormat.number(value, locale: locale) }
    public func percent(_ value: Double?) -> String { DisplayFormat.percent(value, locale: locale) }
    public func rate(_ value: Double?) -> String { DisplayFormat.rate(value, locale: locale) }
}

/// Keep messages structured so an existing scan result can change language without a rescan.
public struct LocalizedMessage: Hashable, Sendable {
    public let key: String
    public let arguments: [String]
    public init(_ key: String, _ arguments: String...) { self.key = key; self.arguments = arguments }
}
