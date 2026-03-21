// Sources/Views/ContributionGraphView.swift
// Renders the GitHub-style contribution grid (green squares).
// This is the core visual component — a 52-week x 7-day grid of colored cells.
// RELEVANT FILES: Sources/Models/ContributionModels.swift, Sources/Views/MenuBarView.swift

import SwiftUI

// MARK: - Contribution Graph View

struct ContributionGraphView: View {

    let calendar: ContributionCalendar

    /// Size of each contribution square.
    private let cellSize: CGFloat = 10
    /// Gap between squares.
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            monthLabels
            graphGrid
        }
    }

    // MARK: - Month Labels

    /// Row of month abbreviations aligned above the grid columns.
    private var monthLabels: some View {
        HStack(spacing: 0) {
            // Left spacer to align with day labels
            Text("")
                .frame(width: 28)

            let months = extractMonthLabels()
            ForEach(months, id: \.offset) { item in
                Text(item.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: CGFloat(item.span) * (cellSize + cellSpacing), alignment: .leading)
            }
        }
    }

    // MARK: - Grid

    /// The main grid: 7 rows (days) x N columns (weeks).
    private var graphGrid: some View {
        HStack(spacing: 0) {
            dayLabels

            HStack(spacing: cellSpacing) {
                ForEach(calendar.weeks) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week.contributionDays) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.swiftUIColor)
                                .frame(width: cellSize, height: cellSize)
                                .help("\(day.contributionCount) contributions on \(day.date)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Day Labels

    /// Abbreviated day-of-week labels on the left side (Mon, Wed, Fri).
    private var dayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                if index == 1 || index == 3 || index == 5 {
                    Text(dayAbbreviation(index))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: cellSize, alignment: .trailing)
                } else {
                    Text("")
                        .frame(width: 24, height: cellSize)
                }
            }
        }
        .padding(.trailing, 4)
    }

    // MARK: - Helpers

    private func dayAbbreviation(_ index: Int) -> String {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days[index]
    }

    /// Extracts month labels with their column spans from the calendar data.
    private func extractMonthLabels() -> [(offset: Int, label: String, span: Int)] {
        var result: [(offset: Int, label: String, span: Int)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        var currentMonth = -1
        var currentSpan = 0
        var startOffset = 0

        for (index, week) in calendar.weeks.enumerated() {
            guard let firstDay = week.contributionDays.first,
                  let date = formatter.date(from: firstDay.date) else {
                currentSpan += 1
                continue
            }

            let month = Foundation.Calendar.current.component(.month, from: date)

            if month != currentMonth {
                if currentMonth != -1 {
                    result.append((offset: startOffset, label: monthNames[currentMonth - 1], span: currentSpan))
                }
                currentMonth = month
                currentSpan = 1
                startOffset = index
            } else {
                currentSpan += 1
            }
        }

        // Append last month
        if currentMonth != -1 {
            result.append((offset: startOffset, label: monthNames[currentMonth - 1], span: currentSpan))
        }

        return result
    }
}

// MARK: - Legend

/// The color legend showing contribution levels (less → more).
struct ContributionLegend: View {

    private let colors: [Color] = [
        Color(hex: "#ebedf0"),
        Color(hex: "#9be9a8"),
        Color(hex: "#40c463"),
        Color(hex: "#30a14e"),
        Color(hex: "#216e39")
    ]

    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            ForEach(0..<colors.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors[index])
                    .frame(width: 10, height: 10)
            }

            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}
