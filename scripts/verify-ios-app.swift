import Foundation
let path = CommandLine.arguments[1]
func require(_ condition: Bool, _ message: String) { if !condition { fatalError(message) } }
guard let app = Bundle(path: path) else { fatalError("App bundle unavailable") }
require(app.object(forInfoDictionaryKey: "UIDeviceFamily") as? [Int] == [1, 2], "App must support iPhone and iPad")
require(FileManager.default.fileExists(atPath: path + "/LICENSE"), "MIT License missing")
require(FileManager.default.fileExists(atPath: path + "/PrivacyInfo.xcprivacy"), "Privacy manifest missing")
guard let resourceURL = app.url(forResource: "MacPulse_MacPulseCore", withExtension: "bundle") else { fatalError("Core resources missing") }
for (code, expected) in [("en", "App CPU"), ("vi", "CPU của app")] {
    guard let bundle = Bundle(path: resourceURL.appendingPathComponent(code + ".lproj").path) else { fatalError("Localization missing: \(code)") }
    require(bundle.localizedString(forKey: "CPU của app", value: nil, table: nil) == expected, "Mobile localization invalid: \(code)")
}
print("Verified iPhone/iPad support, mobile translations, privacy manifest, and MIT License.")
