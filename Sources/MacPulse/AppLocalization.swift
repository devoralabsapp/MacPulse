import SwiftUI
import MacPulseCore

private struct LocalizerKey: EnvironmentKey {
    static let defaultValue = Localizer()
}

extension EnvironmentValues {
    var localizer: Localizer {
        get { self[LocalizerKey.self] }
        set { self[LocalizerKey.self] = newValue }
    }
}
