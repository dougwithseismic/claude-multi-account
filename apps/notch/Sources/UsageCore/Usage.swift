import Foundation

/// One limit window as Claude's usage card shows it.
public struct UsageWindow: Sendable, Equatable, Codable {
    public let label: String
    /// 0–100.
    public let percentUsed: Double
    public let resetsAt: Date?

    public init(label: String, percentUsed: Double, resetsAt: Date?) {
        self.label = label
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
    }
}

public struct ExtraUsage: Sendable, Equatable, Codable {
    public let enabled: Bool
    public let percentUsed: Double?
    /// In major units (for example euros), when the response gives them.
    public let spent: Double?
    public let monthlyLimit: Double?
    public let currency: String?
}

public struct UsageReport: Sendable, Equatable, Codable {
    public let windows: [UsageWindow]
    public let extraUsage: ExtraUsage?

    public init(windows: [UsageWindow], extraUsage: ExtraUsage?) {
        self.windows = windows
        self.extraUsage = extraUsage
    }

    public var fiveHour: UsageWindow? { windows.first { $0.label == UsageReport.fiveHourLabel } }
    public var weekly: UsageWindow? { windows.first { $0.label == UsageReport.weeklyLabel } }
    /// The fullest weekly window, all models or one model. A Team plan can have no
    /// all-models window, so this is what says an account is out for the week.
    public var weeklyPeak: UsageWindow? {
        windows.filter { $0.label.hasPrefix(UsageReport.weeklyPrefix) }.max { $0.percentUsed < $1.percentUsed }
    }

    /// A window is at 100%: nothing more until it resets.
    public var isOut: Bool { windows.contains { $0.percentUsed >= 100 } }

    /// When every window at 100% has reset. Nil when none is, or one's reset isn't known.
    public var backAt: Date? {
        let out = windows.filter { $0.percentUsed >= 100 }
        let resets = out.compactMap(\.resetsAt)
        guard !out.isEmpty, resets.count == out.count else { return nil }
        return resets.max()
    }

    static let fiveHourLabel = "5-hour"
    static let weeklyLabel = "Weekly · all models"
    static let weeklyPrefix = "Weekly"
}

/// `GET /api/oauth/profile`: who the token belongs to, and in which organization.
public struct AccountProfile: Sendable, Equatable, Codable {
    public let email: String?
    public let accountUUID: String?
    public let organizationUUID: String?
    public let organizationName: String?
    /// "claude_max", "claude_pro", "claude_team", "claude_enterprise", …
    public let organizationType: String?
    public let rateLimitTier: String?
}

// MARK: - Decoding

/// The usage endpoint is undocumented and gains fields over time, so everything is
/// optional and unknown fields are ignored. A window with no utilization isn't shown.
enum UsageDecoding {
    struct Response: Decodable {
        struct Window: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        struct Limit: Decodable {
            struct Scope: Decodable {
                struct Model: Decodable { let display_name: String? }
                let model: Model?
            }
            let kind: String?
            let percent: Double?
            let resets_at: String?
            let scope: Scope?
        }
        struct Extra: Decodable {
            let is_enabled: Bool?
            let monthly_limit: Double?
            let used_credits: Double?
            let utilization: Double?
            let currency: String?
        }
        let five_hour: Lenient<Window>?
        let seven_day: Lenient<Window>?
        let seven_day_opus: Lenient<Window>?
        let seven_day_sonnet: Lenient<Window>?
        let limits: Lenient<[Lenient<Limit>]>?
        let extra_usage: Lenient<Extra>?
    }

    /// Decodes to nil when a field changes shape, so one odd field (say a new kind of
    /// limit) hides only itself instead of the whole response.
    struct Lenient<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    static func report(from data: Data) throws -> UsageReport {
        let r: Response
        do { r = try JSONDecoder().decode(Response.self, from: data) } catch { throw UsageError.unexpectedResponse }

        var windows: [UsageWindow] = []
        func add(_ label: String, _ w: Lenient<Response.Window>?) {
            guard let w = w?.value, let u = w.utilization else { return }
            windows.append(UsageWindow(label: label, percentUsed: u, resetsAt: date(w.resets_at)))
        }
        add(UsageReport.fiveHourLabel, r.five_hour)
        add(UsageReport.weeklyLabel, r.seven_day)

        // Per-model weekly limits now come in `limits[]`; the old fields are the fallback.
        let scoped = (r.limits?.value ?? []).compactMap(\.value).filter { $0.kind == "weekly_scoped" }
        let named = scoped.compactMap { l -> UsageWindow? in
            guard let name = l.scope?.model?.display_name, let p = l.percent else { return nil }
            return UsageWindow(label: "Weekly · \(name)", percentUsed: p, resetsAt: date(l.resets_at))
        }
        if named.isEmpty {
            add("Weekly · Opus", r.seven_day_opus)
            add("Weekly · Sonnet", r.seven_day_sonnet)
        } else {
            windows += named
        }
        if windows.isEmpty && !reportsNoLimits(data) { throw UsageError.unexpectedResponse }

        let extra = r.extra_usage?.value.map {
            ExtraUsage(
                enabled: $0.is_enabled ?? false,
                percentUsed: $0.utilization,
                spent: $0.used_credits.map { $0 / 100 },
                monthlyLimit: $0.monthly_limit.map { $0 / 100 },
                currency: $0.currency
            )
        }
        return UsageReport(windows: windows, extraUsage: extra)
    }

    /// A plan with no limits to show (a free plan, say) answers with the usual fields set
    /// to null. Anything else without a window is a response this doesn't understand.
    static func reportsNoLimits(_ data: Data) -> Bool {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
        let known = ["five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet", "limits"].compactMap { root[$0] }
        return !known.isEmpty && known.allSatisfy { $0 is NSNull || ($0 as? [Any])?.isEmpty == true }
    }

    struct ProfileResponse: Decodable {
        struct Account: Decodable { let uuid: String?; let email: String? }
        struct Organization: Decodable {
            let uuid: String?
            let name: String?
            let organization_type: String?
            let rate_limit_tier: String?
        }
        let account: Account?
        let organization: Organization?
    }

    static func profile(from data: Data) throws -> AccountProfile {
        guard let r = try? JSONDecoder().decode(ProfileResponse.self, from: data) else {
            throw UsageError.unexpectedResponse
        }
        return AccountProfile(
            email: r.account?.email, accountUUID: r.account?.uuid,
            organizationUUID: r.organization?.uuid, organizationName: r.organization?.name,
            organizationType: r.organization?.organization_type, rateLimitTier: r.organization?.rate_limit_tier
        )
    }

    /// ISO-8601 in UTC, with or without fractional seconds (sometimes microseconds),
    /// and taken as UTC when it has no zone.
    static func date(_ string: String?) -> Date? {
        guard var string, !string.isEmpty else { return nil }
        // The formatter takes at most milliseconds, so cut longer fractions down to three digits.
        if let dot = string.firstIndex(of: ".") {
            let digits = string[string.index(after: dot)...].prefix { $0.isNumber }
            if digits.count > 3 {
                string.replaceSubrange(string.index(dot, offsetBy: 4)..<digits.endIndex, with: "")
            }
        }
        let formatter = ISO8601DateFormatter()
        for candidate in [string, string + "Z"] {
            for options: ISO8601DateFormatter.Options in [[.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]] {
                formatter.formatOptions = options
                if let d = formatter.date(from: candidate) { return d }
            }
        }
        return nil
    }
}
