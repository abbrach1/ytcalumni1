import SwiftUI

// Live fundraising progress + "time left" countdown for the home-screen campaign
// banner. Mirrors the website's CampaignProgress / CampaignCountdown components.
// Both are self-gating: they render nothing until there's usable data, so the
// banner can drop them in unconditionally.

/// Live progress bar (amount raised / goal / donors) pulled from CharityExtra.
struct CampaignProgressView: View {
    let slug: String
    @State private var status: CampaignStatus?

    var body: some View {
        Group {
            if let status = status, status.goal > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(formatAmount(status.currencySymbol, status.amount))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.gold)
                        Text("raised of \(formatAmount(status.currencySymbol, status.goal)) goal")
                            .font(.caption)
                            .foregroundColor(.cream.opacity(0.7))
                        Spacer()
                        Text("\(Int(status.percent.rounded()))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.cream)
                    }

                    // Progress track + gold fill.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.cream.opacity(0.15))
                            Capsule()
                                .fill(Color.gold)
                                .frame(width: geo.size.width * CGFloat(status.percent / 100))
                        }
                    }
                    .frame(height: 10)

                    HStack(spacing: 16) {
                        Label("\(status.donations) donation\(status.donations == 1 ? "" : "s")",
                              systemImage: "person.2.fill")
                        if status.multiplied > 1 {
                            Label("Donations matched \(status.multiplied)x", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.cream.opacity(0.7))
                }
                .transition(.opacity)
            }
        }
        .task {
            status = await CampaignStatus.fetch(slug: slug)
        }
    }

    private func formatAmount(_ symbol: String, _ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value))"
        return "\(symbol)\(number)"
    }
}

/// Live "time left" countdown to the campaign deadline. Re-computes each minute.
struct CampaignCountdownView: View {
    let deadline: String   // yyyy-MM-dd

    var body: some View {
        if let end = Self.endDate(deadline) {
            // TimelineView ticks the closure so the label stays current.
            TimelineView(.periodic(from: Date(), by: 60)) { context in
                let (label, ended) = Self.timeLeft(until: end, now: context.date)
                Label(label, systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(ended ? .cream.opacity(0.6) : .gold)
            }
        }
    }

    /// End of the deadline day in the user's local time.
    private static func endDate(_ deadline: String) -> Date? {
        guard !deadline.isEmpty else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let day = f.date(from: deadline) else { return nil }
        return Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: day)
    }

    private static func timeLeft(until end: Date, now: Date) -> (label: String, ended: Bool) {
        let secs = Int(end.timeIntervalSince(now))
        if secs <= 0 { return ("Campaign ended", true) }
        let mins = secs / 60
        let days = mins / (60 * 24)
        let hours = (mins % (60 * 24)) / 60
        let minutes = mins % 60
        if days >= 1 {
            let h = hours > 0 ? ", \(hours) hr\(hours == 1 ? "" : "s")" : ""
            return ("\(days) day\(days == 1 ? "" : "s")\(h) left", false)
        }
        if hours >= 1 { return ("\(hours) hr\(hours == 1 ? "" : "s"), \(minutes) min left", false) }
        return ("\(minutes) min left", false)
    }
}
