//
//  AnalyticsView.swift
//  ClaudePet
//
//  Rolling usage analytics for recent Claude activity.
//

import SwiftUI

struct AnalyticsView: View {
    let dailyUsage: [Date: Int]
    let isLoading: Bool

    // MARK: - Layout constants

    private let cols = 7
    private let rows = 5         // 5 weeks = 35 days
    private let spacing: CGFloat = 3
    private let cellSize: CGFloat = 22

    private var heatmapWidth: CGFloat {
        CGFloat(cols) * cellSize + CGFloat(cols - 1) * spacing
    }

    // MARK: - Data

    /// 35 dates, index 0 = oldest (34 days ago), index 34 = today.
    private var dates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<(cols * rows)).map { n in
            cal.date(byAdding: .day, value: -(cols * rows - 1 - n), to: today)!
        }
    }

    private var trendPoints: [UsageTrendPoint] {
        dates.suffix(7).map { date in
            UsageTrendPoint(date: date, tokens: dailyUsage[date] ?? 0)
        }
    }

    private var maxTokens: Int { max(dailyUsage.values.max() ?? 1, 1) }

    private var totalTokens: Int {
        dailyUsage.values.reduce(0, +)
    }

    private var activeDays: Int {
        dates.filter { (dailyUsage[$0] ?? 0) > 0 }.count
    }

    private var activeStreak: Int {
        var streak = 0
        for date in dates.reversed() {
            if (dailyUsage[date] ?? 0) > 0 {
                streak += 1
            } else if streak > 0 {
                break
            }
        }
        return streak
    }

    private var averageTokensPerActiveDay: Int {
        guard activeDays > 0 else { return 0 }
        return totalTokens / activeDays
    }

    private var recentWeekTotal: Int {
        dates.suffix(7).reduce(0) { $0 + (dailyUsage[$1] ?? 0) }
    }

    private var recentWeekDailyAverage: Int {
        recentWeekTotal / max(trendPoints.count, 1)
    }

    private var recentWeekActiveDays: Int {
        trendPoints.filter { $0.tokens > 0 }.count
    }

    private var previousWeekTotal: Int {
        dates.dropLast(7).suffix(7).reduce(0) { $0 + (dailyUsage[$1] ?? 0) }
    }

    private var bestTrendPoint: UsageTrendPoint? {
        trendPoints.max { lhs, rhs in lhs.tokens < rhs.tokens }
    }

    private var bestTrendDayLabel: String {
        guard let bestTrendPoint, bestTrendPoint.tokens > 0 else { return "—" }
        return Self.shortDateFormatter.string(from: bestTrendPoint.date)
    }

    private var weeklyTrendText: String {
        if recentWeekTotal == 0 && previousWeekTotal == 0 {
            return "No activity in the last 2 weeks"
        }
        if previousWeekTotal == 0 {
            return "New activity this week"
        }

        let delta = recentWeekTotal - previousWeekTotal
        let percent = Int((Double(abs(delta)) / Double(previousWeekTotal) * 100).rounded())
        if delta > 0 {
            return "\(percent)% more than the previous 7 days"
        } else if delta < 0 {
            return "\(percent)% less than the previous 7 days"
        } else {
            return "Same pace as the previous 7 days"
        }
    }

    private var weeklyTrendAccent: Color {
        if recentWeekTotal > previousWeekTotal { return .green }
        if recentWeekTotal < previousWeekTotal { return .orange }
        return .secondary
    }

    private func level(for date: Date) -> Int {
        guard let t = dailyUsage[date], t > 0 else { return 0 }
        let r = Double(t) / Double(maxTokens)
        switch r {
        case 0..<0.10: return 1
        case 0.10..<0.30: return 2
        case 0.30..<0.65: return 3
        default: return 4
        }
    }

    private func cellColor(_ level: Int) -> Color {
        switch level {
        case 0: return Color.primary.opacity(0.08)
        case 1: return Color.green.opacity(0.25)
        case 2: return Color.green.opacity(0.45)
        case 3: return Color.green.opacity(0.70)
        case 4: return Color.green
        default: return Color.primary.opacity(0.08)
        }
    }

    // MARK: - Formatters

    private static let tooltipDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    private func tooltip(date: Date) -> String {
        let tokens = dailyUsage[date] ?? 0
        let dateStr = Self.tooltipDate.string(from: date)
        return tokens > 0
            ? "\(dateStr): \(tokens.formatted()) tokens"
            : "\(dateStr): No activity"
    }

    private func compactTokens(_ value: Int) -> String {
        let number = Double(value)
        switch number {
        case 1_000_000_000...:
            return String(format: "%.1fB", number / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", number / 1_000_000)
        case 10_000...:
            return String(format: "%.0fK", number / 1_000)
        case 1_000...:
            return String(format: "%.1fK", number / 1_000)
        default:
            return value.formatted()
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            usageTrendCard
            Divider()
                .padding(.vertical, 4)
            activityHistorySection
        }
    }

    private var usageTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Usage Trend")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary.opacity(0.86))
                    .lineLimit(1)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.55)
                        .padding(.leading, 2)
                }
                Spacer()
                Text("7 days")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            UsageTrendChartView(
                points: trendPoints,
                accent: Color(red: 0.52, green: 0.37, blue: 0.92)
            )

            HStack(spacing: 6) {
                metricPill(title: "Total", value: compactTokens(recentWeekTotal))
                metricPill(title: "Daily avg", value: compactTokens(recentWeekDailyAverage))
                metricPill(title: "Best day", value: bestTrendDayLabel)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(weeklyTrendAccent)
                    .frame(width: 6, height: 6)
                Text(weeklyTrendText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
    }

    private var activityHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Activity History")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Text("Last 35 days")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: spacing) {
                    let datesArr = dates
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: cols),
                        alignment: .leading,
                        spacing: spacing
                    ) {
                        ForEach(0..<(cols * rows), id: \.self) { i in
                            let date = datesArr[i]
                            let lv = level(for: date)

                            RoundedRectangle(cornerRadius: 5)
                                .fill(cellColor(lv))
                                .frame(width: cellSize, height: cellSize)
                                .help(tooltip(date: date))
                        }
                    }
                }
                .frame(width: heatmapWidth, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 4) {
                Spacer()
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ForEach(0..<5, id: \.self) { lv in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor(lv))
                        .frame(width: 12, height: 12)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !dailyUsage.isEmpty {
                HStack {
                    Text("\(activeDays) active days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(totalTokens.formatted()) tokens total")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 8) {
                    summaryCard(
                        title: "Streak",
                        value: activeStreak > 0 ? "\(activeStreak) days" : "No streak",
                        detail: activeStreak > 0
                            ? "Current streak is going strong"
                            : "Will start again on your next active day",
                        accent: activeStreak > 0 ? .green : .secondary
                    )

                    summaryCard(
                        title: "Daily average",
                        value: "\(averageTokensPerActiveDay.formatted()) tokens",
                        detail: activeDays > 0
                            ? "Average across active days only"
                            : "No active days to average yet",
                        accent: .blue
                    )

                    summaryCard(
                        title: "Last 7 days",
                        value: "\(recentWeekActiveDays) active days",
                        detail: weeklyTrendText,
                        accent: weeklyTrendAccent
                    )
                }
            } else if !isLoading {
                summaryCard(
                    title: "No activity yet",
                    value: "0 tokens",
                    detail: "Local Claude usage will appear here once recorded.",
                    accent: .secondary
                )
            }
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func summaryCard(title: String, value: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
            }

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary.opacity(0.75))

            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct UsageTrendPoint: Identifiable, Equatable {
    let date: Date
    let tokens: Int

    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
}

private struct UsageTrendChartView: View {
    let points: [UsageTrendPoint]
    let accent: Color

    @State private var hoveredIndex: Int?
    @Environment(\.colorScheme) private var colorScheme

    private let inset: CGFloat = 8
    private let vpad: CGFloat = 8

    private var hasUsage: Bool { points.contains { $0.tokens > 0 } }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private func compactTokens(_ v: Int) -> String {
        let n = Double(v)
        if n >= 1_000_000_000 { return String(format: "%.1fB tokens", n / 1_000_000_000) }
        if n >= 1_000_000     { return String(format: "%.1fM tokens", n / 1_000_000) }
        if n >= 10_000        { return String(format: "%.0fK tokens", n / 1_000) }
        if n >= 1_000         { return String(format: "%.1fK tokens", n / 1_000) }
        return "\(v.formatted()) tokens"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = points.count
            let maxVal = CGFloat(points.map(\.tokens).max() ?? 1)
            let stepX = n > 1 ? (w - inset * 2) / CGFloat(n - 1) : 0

            let pts: [CGPoint] = points.enumerated().map { i, p in
                let x = n > 1 ? inset + CGFloat(i) * stepX : w / 2
                let normalized = maxVal > 0 ? CGFloat(p.tokens) / maxVal : 0
                let y = (h - vpad) - normalized * (h - vpad * 2)
                return CGPoint(x: x, y: max(vpad, y))
            }

            ZStack {
                // Background card
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accent.opacity(0.08), Color.primary.opacity(0.025)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))

                if hasUsage, pts.count >= 2 {
                    // Area fill
                    Path { path in
                        path.move(to: CGPoint(x: pts[0].x, y: h))
                        path.addLine(to: pts[0])
                        for i in 1..<pts.count {
                            let a = pts[i - 1], b = pts[i]
                            let mx = (a.x + b.x) / 2
                            path.addCurve(to: b,
                                          control1: CGPoint(x: mx, y: a.y),
                                          control2: CGPoint(x: mx, y: b.y))
                        }
                        path.addLine(to: CGPoint(x: pts.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [accent.opacity(0.28), accent.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ))

                    // Stroke line
                    Path { path in
                        path.move(to: pts[0])
                        for i in 1..<pts.count {
                            let a = pts[i - 1], b = pts[i]
                            let mx = (a.x + b.x) / 2
                            path.addCurve(to: b,
                                          control1: CGPoint(x: mx, y: a.y),
                                          control2: CGPoint(x: mx, y: b.y))
                        }
                    }
                    .stroke(accent.opacity(0.8),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    if let idx = hoveredIndex, idx < pts.count {
                        let pt  = pts[idx]
                        let p   = points[idx]

                        // Vertical crosshair
                        Path { path in
                            path.move(to: CGPoint(x: pt.x, y: vpad))
                            path.addLine(to: CGPoint(x: pt.x, y: h - vpad))
                        }
                        .stroke(accent.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                        // Dot
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                            .position(pt)

                        // Tooltip
                        let tipW: CGFloat = 112
                        let tipH: CGFloat = 38
                        let tipX  = min(max(pt.x, tipW / 2 + 6), w - tipW / 2 - 6)
                        let tipAbove = pt.y - tipH / 2 - 14
                        let tipY  = tipAbove < vpad ? pt.y + tipH / 2 + 14 : tipAbove

                        VStack(spacing: 2) {
                            Text(Self.dateFmt.string(from: p.date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(compactTokens(p.tokens))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary.opacity(0.85))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .frame(width: tipW, height: tipH)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: Color.black.opacity(
                                    colorScheme == .dark ? 0.25 : 0.08
                                ), radius: 4, y: 1)
                        )
                        .position(x: tipX, y: tipY)

                    } else if let last = pts.last {
                        // Resting dot at latest data point
                        Circle()
                            .fill(accent.opacity(0.7))
                            .frame(width: 4, height: 4)
                            .position(last)
                    }
                } else {
                    // Empty state
                    Path { path in
                        let y = h - vpad
                        path.move(to: CGPoint(x: inset, y: y))
                        path.addLine(to: CGPoint(x: w - inset, y: y))
                    }
                    .stroke(Color.primary.opacity(0.14),
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))

                    Text("No recent activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    guard hasUsage, n > 1 else { hoveredIndex = nil; return }
                    let idx = Int(((loc.x - inset) / stepX).rounded())
                    hoveredIndex = min(max(idx, 0), n - 1)
                case .ended:
                    hoveredIndex = nil
                }
            }
        }
        .frame(height: 136)
    }
}
