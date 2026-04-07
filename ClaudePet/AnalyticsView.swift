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
            return "최근 2주 활동이 아직 없어요"
        }
        if previousWeekTotal == 0 {
            return "지난주보다 새롭게 사용량이 생겼어요"
        }

        let delta = recentWeekTotal - previousWeekTotal
        let percent = Int((Double(abs(delta)) / Double(previousWeekTotal) * 100).rounded())
        if delta > 0 {
            return "이전 7일보다 \(percent)% 더 많이 사용했어요"
        } else if delta < 0 {
            return "이전 7일보다 \(percent)% 적게 사용했어요"
        } else {
            return "이전 7일과 거의 같은 페이스예요"
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
        f.dateFormat = "M월 d일"
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
            : "\(dateStr): 사용 없음"
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
        VStack(alignment: .leading, spacing: 12) {
            usageTrendCard
            activityHistorySection
        }
    }

    private var usageTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Usage Trend")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.82))
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.55)
                        .padding(.leading, 2)
                }
                Spacer()
                Text("7 days")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.72))
            }

            UsageTrendChartView(
                points: trendPoints,
                accent: Color(red: 0.52, green: 0.37, blue: 0.92)
            )
            .frame(height: 116)

            HStack(spacing: 8) {
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var activityHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity History")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("최근 35일")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                    Text("35일간 \(activeDays)일 활성")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("총 \(totalTokens.formatted()) tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 8) {
                    summaryCard(
                        title: "연속 활동",
                        value: activeStreak > 0 ? "\(activeStreak)일째" : "오늘은 휴식",
                        detail: activeStreak > 0
                            ? "최근 흐름이 이어지고 있어요"
                            : "다음 사용이 시작되면 다시 쌓여요",
                        accent: activeStreak > 0 ? .green : .secondary
                    )

                    summaryCard(
                        title: "활성일 평균",
                        value: "\(averageTokensPerActiveDay.formatted()) tokens",
                        detail: activeDays > 0
                            ? "토큰을 쓴 날 기준 평균이에요"
                            : "아직 집계할 활동일이 없어요",
                        accent: .blue
                    )

                    summaryCard(
                        title: "최근 7일",
                        value: "\(recentWeekActiveDays)일 활성",
                        detail: weeklyTrendText,
                        accent: weeklyTrendAccent
                    )
                }
            } else if !isLoading {
                summaryCard(
                    title: "아직 활동 없음",
                    value: "0 tokens",
                    detail: "로컬 Claude 사용 기록이 쌓이면 이곳에 표시돼요.",
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
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .foregroundColor(.primary)

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

    private let horizontalInset: CGFloat = 8
    private let topInset: CGFloat = 10
    private let bottomInset: CGFloat = 16

    private var hasUsage: Bool {
        points.contains { $0.tokens > 0 }
    }

    private var focusedIndex: Int? {
        guard hasUsage, !points.isEmpty else { return nil }
        return hoveredIndex ?? (points.count - 1)
    }

    private static let tooltipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M월 d일"
        return f
    }()

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let chartPoints = plotPoints(in: size)

            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.08),
                                Color.primary.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if hasUsage, chartPoints.count > 1 {
                    smoothPath(points: chartPoints, closingAt: size.height - bottomInset)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.34),
                                    accent.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    smoothPath(points: chartPoints)
                        .stroke(
                            accent,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    if let focusedIndex {
                        focusedOverlay(
                            focusedIndex: focusedIndex,
                            chartPoints: chartPoints,
                            size: size
                        )
                    }
                } else {
                    emptyChart(in: size)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredIndex = nearestIndex(for: location.x, in: size)
                case .ended:
                    hoveredIndex = nil
                }
            }
            .animation(.easeOut(duration: 0.18), value: hoveredIndex)
        }
    }

    private func focusedOverlay(focusedIndex: Int, chartPoints: [CGPoint], size: CGSize) -> some View {
        let point = chartPoints[focusedIndex]
        let model = points[focusedIndex]
        let showTooltip = hoveredIndex != nil

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.x, y: topInset))
                path.addLine(to: CGPoint(x: point.x, y: size.height - bottomInset))
            }
            .stroke(accent.opacity(showTooltip ? 0.28 : 0.0), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            Circle()
                .fill(accent)
                .frame(width: showTooltip ? 8 : 6, height: showTooltip ? 8 : 6)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.92), lineWidth: 1.5)
                )
                .position(point)

            if showTooltip {
                tooltip(for: model, in: size, anchoredAt: point)
            }
        }
    }

    private func emptyChart(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                let y = size.height - bottomInset
                path.move(to: CGPoint(x: horizontalInset, y: y))
                path.addLine(to: CGPoint(x: size.width - horizontalInset, y: y))
            }
            .stroke(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))

            Text("최근 사용 기록이 아직 없어요")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func tooltip(for point: UsageTrendPoint, in size: CGSize, anchoredAt anchor: CGPoint) -> some View {
        let width: CGFloat = 138
        let x = min(max(anchor.x, width / 2), max(width / 2, size.width - width / 2))
        let y = max(anchor.y - 38, 24)

        return VStack(alignment: .leading, spacing: 3) {
            Text(Self.tooltipDateFormatter.string(from: point.date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary.opacity(0.78))
            Text("\(point.tokens.formatted()) tokens")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(averageComparisonText(for: point))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(accent.opacity(0.9))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(width: width, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
        .position(x: x, y: y)
    }

    private func averageComparisonText(for point: UsageTrendPoint) -> String {
        let total = points.reduce(0) { $0 + $1.tokens }
        let average = total / max(points.count, 1)
        guard average > 0 else { return "7일 평균 데이터 없음" }

        let delta = point.tokens - average
        let percent = Int((Double(abs(delta)) / Double(average) * 100).rounded())
        if delta > 0 {
            return "7일 평균보다 +\(percent)%"
        } else if delta < 0 {
            return "7일 평균보다 -\(percent)%"
        }
        return "7일 평균과 비슷해요"
    }

    private func plotPoints(in size: CGSize) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let maxValue = max(points.map(\.tokens).max() ?? 0, 1)
        let plotWidth = max(size.width - horizontalInset * 2, 1)
        let plotHeight = max(size.height - topInset - bottomInset, 1)
        let denominator = max(points.count - 1, 1)

        return points.enumerated().map { index, point in
            let x = horizontalInset + plotWidth * CGFloat(index) / CGFloat(denominator)
            let normalized = CGFloat(Double(point.tokens) / Double(maxValue))
            let y = topInset + plotHeight * (1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    private func nearestIndex(for x: CGFloat, in size: CGSize) -> Int? {
        guard !points.isEmpty else { return nil }

        let plotWidth = max(size.width - horizontalInset * 2, 1)
        let clampedX = min(max(x, horizontalInset), size.width - horizontalInset)
        let progress = (clampedX - horizontalInset) / plotWidth
        let rawIndex = Int((progress * CGFloat(points.count - 1)).rounded())
        return min(max(rawIndex, 0), points.count - 1)
    }

    private func smoothPath(points: [CGPoint], closingAt bottom: CGFloat? = nil) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        if let bottom {
            path.move(to: CGPoint(x: first.x, y: bottom))
            path.addLine(to: first)
        } else {
            path.move(to: first)
        }

        if points.count == 1 {
            path.addLine(to: first)
        } else {
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let mid = CGPoint(
                    x: (previous.x + current.x) / 2,
                    y: (previous.y + current.y) / 2
                )
                path.addQuadCurve(to: mid, control: previous)
            }

            if let last = points.last {
                path.addLine(to: last)
            }
        }

        if let bottom, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: bottom))
            path.addLine(to: CGPoint(x: first.x, y: bottom))
            path.closeSubpath()
        }

        return path
    }
}
