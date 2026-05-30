import Foundation

/// Claims encoded inside the EdDSA-signed license JWT.
/// Wire format: { "iss":"api.devtray.app", "sub":<uuid>, "email":<string>, "iat":<unix-seconds>, "tier":"v1" }
public struct LicenseClaims: Codable, Sendable, Equatable {
    public let licenseUUID: UUID
    public let email: String
    public let issuedAt: Date
    public let tier: String

    public init(licenseUUID: UUID, email: String, issuedAt: Date, tier: String) {
        self.licenseUUID = licenseUUID
        self.email = email
        self.issuedAt = issuedAt
        self.tier = tier
    }
}

/// Application-wide license state — the single source of truth that gating views consume.
public enum LicenseState: Equatable, Sendable {
    /// Transient state during launch boot before TrialTracker.ensureTrialStarted runs (<100ms in practice).
    case untrialed

    /// Active trial, with calendar days remaining (0...14, clamped).
    case trialing(daysLeft: Int)

    /// 14-day trial elapsed OR clock-setback tampering detected; paywall surfaces are gated.
    case trialExpired

    /// Active paid license; full feature access.
    case licensed(claims: LicenseClaims)

    /// Server flagged the license revoked (refund, manual admin action, machine-not-in-activations).
    case revoked

    /// True if Snippets save/edit + Settings → Tools should show PaywallView instead of content.
    /// Read by `View.paywalled()` in DevTrayUI.
    public var isGated: Bool {
        switch self {
        case .untrialed, .trialing, .licensed:
            return false
        case .trialExpired, .revoked:
            return true
        }
    }
}
