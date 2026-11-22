import Foundation

/// Static information shared by the iOS and watchOS apps.
enum AppInfo {
    static let name = "FitTrack"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    /// User agent sent to Open Food Facts (their API terms require an identifying user agent; no personal data).
    static let userAgent = "FitTrack/\(version) (iOS; open-source fitness app)"
}
