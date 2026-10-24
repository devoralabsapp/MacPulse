import Foundation

struct VerificationFailure: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}

func require(_ condition: Bool, _ reason: String) throws {
    if !condition { throw VerificationFailure(reason: reason) }
}

guard CommandLine.arguments.count == 2 else {
    throw VerificationFailure(reason: "Usage: swift scripts/verify-app.swift /path/to/MacPulse.app")
}
let appURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
guard let app = Bundle(url: appURL),
      let resourcesURL = app.url(forResource: "MacPulse_MacPulseCore", withExtension: "bundle"),
      let resources = Bundle(url: resourcesURL) else {
    throw VerificationFailure(reason: "The packaged app is missing its embedded localization bundle.")
}
try require(resourcesURL.path.hasPrefix(appURL.path + "/"), "Resources must be inside the app, not in a build directory.")

for (code, expected) in [("en", "Overview"), ("vi", "Tổng quan")] {
    guard let path = resources.path(forResource: code, ofType: "lproj"), let language = Bundle(path: path) else {
        throw VerificationFailure(reason: "Missing \(code) localization in the packaged app.")
    }
    try require(language.localizedString(forKey: "Tổng quan", value: nil, table: nil) == expected,
                "Unable to read the \(code) translation from the packaged app.")
    try require(app.path(forResource: "InfoPlist", ofType: "strings", inDirectory: "\(code).lproj") != nil,
                "Missing localized permission descriptions for \(code).")
}
try require(app.url(forResource: "LICENSE", withExtension: nil) != nil, "Missing MIT License in the app bundle.")
print("Packaged resources verified: English, Vietnamese, permission descriptions, and MIT License.")
