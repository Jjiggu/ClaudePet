//
//  AnalyticsView.swift
//  ClaudePet
//
//  GitHub-style 35-day token usage heatmap (7 cols × 5 rows)
//  Columns = weeks (left = oldest), rows = days within week (top = oldest in that week)

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

    /// 35 dates, index 0 = oldest (34 days ago), index 34 = today
    private var dates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<(cols * rows)).map { n in
            cal.date(byAdding: .day, value: -(cols * rows - 1 - n), to: today)!
        }
    }

    private var weekdayLabels: [String] {
        Array(dates.prefix(cols)).map { Self.weekdayFormatter.string(from: $0) }
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

    private var previousWeekTotal: Int {
        dates.dropLast(7).suffix(7).reduce(0) { $0 + (dailyUsage[$1] ?? 0) }
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
            return "최근 7일 사용량이 지난 7일보다 \(percent)% 늘었어요"
        } else if delta < 0 {
            return "최근 7일 사용량이 지난 7일보다 \(percent)% 줄었어요"
        } else {
            return "최근 7일 사용량이 지난주와 비슷해요"
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

    // MARK: - Tooltip

    private static let tooltipDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M월 d일"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private func tooltip(date: Date) -> String {
        let tokens = dailyUsage[date] ?? 0
        let dateStr = Self.tooltipDate.string(from: date)
        return tokens > 0
            ? "\(dateStr): \(tokens.formatted()) tokens"
            : "\(dateStr): 사용 없음"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity")
                    .font(.caption)
                    .fontWeight(.semibold)
                if isLoading {
                    ProgressView().scaleEffect(0.6).padding(.leading, 2)
                }
                Spacer()
                Text("최근 35일")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: spacing) {
                        ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .foregroundColor(.secondary)
                                .frame(width: cellSize)
                        }
                    }

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

            // Legend
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

            // Summary row
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
                        title: "최근 7일 추세",
                        value: "\(recentWeekTotal.formatted()) tokens",
                        detail: weeklyTrendText,
                        accent: weeklyTrendAccent
                    )
                }
            } else if !isLoading {
                summaryCard(
                    title: "No activity yet",
                    value: "0 tokens",
                    detail: "The heatmap will fill in as local Claude usage is collected.",
                    accent: .secondary
                )
            }
        }
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
