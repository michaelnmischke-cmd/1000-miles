import Foundation

/// Settings for connecting Fitbit through Google.
///
/// Fitbit's own API was switched off in fall 2026. Fitbit data now comes from the
/// Google Health API, which needs a free Google Cloud project. Setup steps are in
/// docs/fitbit-setup.md. Until a client ID is filled in below, the Fitbit option
/// in Settings explains that it isn't set up yet.
enum GoogleHealthConfig {
    /// The iOS OAuth client ID from Google Cloud, like
    /// "1234567890-abcdefg.apps.googleusercontent.com".
    static let clientID = ""

    static var isConfigured: Bool { !clientID.isEmpty }

    /// Google's iOS clients sign in with the client ID reversed as a URL scheme.
    static var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    static var redirectURI: String { "\(callbackScheme):/oauth2redirect" }

    static let scope = "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly"
    static let authorizeURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    static let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!
    static let apiBase = URL(string: "https://health.googleapis.com/v4")!
}
