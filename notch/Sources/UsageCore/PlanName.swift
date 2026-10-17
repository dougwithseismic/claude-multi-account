import Foundation

/// Short names for an organization's plan, from the login's `subscriptionType` and
/// `rateLimitTier` and the profile's `organization_type`.
public enum PlanName {
    /// "Max 20x", "Max 5x", "Pro", "Team", "Enterprise", "Free" …, or nil when nothing says.
    public static func of(subscriptionType: String?, rateLimitTier: String?, organizationType: String?) -> String? {
        let organization = kind(organizationType), subscription = kind(subscriptionType)
        if isShared(organization) || isShared(subscription) {
            return organization == "enterprise" || subscription == "enterprise" ? "Enterprise" : "Team"
        }
        guard let plan = subscription ?? organization else { return nil }
        if plan == "max", let size = ["20x", "5x"].first(where: { rateLimitTier?.lowercased().hasSuffix($0) == true }) {
            return "Max \(size)"
        }
        return plan.prefix(1).uppercased() + plan.dropFirst()
    }

    /// A Team or Enterprise organization by its name; anyone's own plan is "Personal".
    public static func organization(name: String?, organizationType: String?, subscriptionType: String?) -> String? {
        if isShared(kind(organizationType)) || isShared(kind(subscriptionType)) {
            let trimmed = name?.trimmingCharacters(in: .whitespaces) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        return organizationType == nil && subscriptionType == nil ? nil : "Personal"
    }

    /// "Team · Acme", "Max 20x · Personal".
    public static func label(plan: String?, organization: String?) -> String? {
        let parts = [plan, organization].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func isShared(_ kind: String?) -> Bool { kind == "team" || kind == "enterprise" }

    /// "claude_team" and "team" both mean a Team.
    static func kind(_ value: String?) -> String? {
        guard var value = value?.lowercased().trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if value.hasPrefix("claude_") { value.removeFirst("claude_".count) }
        return value.isEmpty ? nil : value
    }
}
