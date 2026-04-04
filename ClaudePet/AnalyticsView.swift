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

    // MARK: - Data

    /// 35 dates, index 0 = oldest (34 days ago), index 34 = today
    private var dates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<(cols * rows)).map { n in
            cal.date(byAdding: .day, value: -(cols * rows - 1 - n), to: today)!
        }
    }

    private var maxTokens: Int { max(dailyUsage.values.max() ?? 1, 1) }

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

            // Heatmap grid
            let datesArr = dates
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: cols),
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
                let total = dailyUsage.values.reduce(0, +)
                let activeDays = dailyUsage.filter { $0.value > 0 }.count
                HStack {
                    Text("35일간 \(activeDays)일 활성")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("총 \(total.formatted()) tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
