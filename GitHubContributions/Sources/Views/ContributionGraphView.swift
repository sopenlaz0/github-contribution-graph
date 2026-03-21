// Sources/Views/ContributionGraphView.swift
// Renders the GitHub-style contribution grid (green squares).
// Supports dark mode, hover info, and GitHub's exact color palette.
// RELEVANT FILES: Sources/Models/ContributionModels.swift, Sources/Views/MenuBarView.swift

import SwiftUI

// MARK: - GitHub Color Palette

enum GitHubColors {
    private static let lightToDark: [String: String] = [
        "#ebedf0": "#161b22",
        "#9be9a8": "#0e4429",
        "#40c463": "#006d32",
        "#30a14e": "#26a641",
        "#216e39": "#39d353",
    ]

    static let lightLevels = ["#ebedf0", "#9be9a8", "#40c463", "#30a14e", "#216e39"]
    static let darkLevels  = ["#161b22", "#0e4429", "#006d32", "#26a641", "#39d353"]

    static func color(for apiHex: String, scheme: ColorScheme) -> Color {
        if scheme == .dark, let darkHex = lightToDark[apiHex.lowercased()] {
            return Color(hex: darkHex)
        }
        return Color(hex: apiHex)
    }
}

// MARK: - Contribution Graph View

struct ContributionGraphView: View {

    let calendar: ContributionCalendar

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredDayId: String?

    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 3

    /// Pre-computed lookup for fast hover info display.
    private var dayLookup: [String: ContributionDay] {
        var dict = [String: ContributionDay]()
        dict.reserveCapacity(calendar.weeks.count * 7)
        for week in calendar.weeks {
            for day in week.contributionDays {
                dict[day.id] = day
            }
        }
        return dict
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            monthLabels
            graphGrid
            hoverInfo
        }
    }

    // MARK: - Month Labels

    private var monthLabels: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 32)

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

    private var graphGrid: some View {
        HStack(spacing: 0) {
            dayLabels

            HStack(spacing: cellSpacing) {
                ForEach(calendar.weeks) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week.contributionDays) { day in
                            ContributionCellView(
                                day: day,
                                isHovered: hoveredDayId == day.id,
                                fillColor: GitHubColors.color(for: day.color, scheme: colorScheme),
                                cellSize: cellSize,
                                onHover: { hovered in
                                    hoveredDayId = hovered ? day.id : nil
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hover Info Bar

    private var hoverInfo: some View {
        Group {
            if let id = hoveredDayId, let day = dayLookup[id] {
                Text(Self.tooltipText(for: day))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text(" ")
                    .font(.system(size: 10))
            }
        }
        .frame(height: 14)
    }

    // MARK: - Day Labels

    private var dayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { index in
                if index == 1 || index == 3 || index == 5 {
                    Text(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][index])
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: cellSize, alignment: .trailing)
                } else {
                    Color.clear
                        .frame(width: 26, height: cellSize)
                }
            }
        }
        .padding(.trailing, 4)
    }

    // MARK: - Tooltip

    static func tooltipText(for day: ContributionDay) -> String {
        let count = day.contributionCount
        let countText = count == 0 ? "No contributions" : "\(count) contribution\(count == 1 ? "" : "s")"

        guard let date = dateParser.date(from: day.date) else {
            return "\(countText) on \(day.date)"
        }
        return "\(countText) on \(tooltipFormatter.string(from: date))"
    }

    static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let tooltipFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Month Label Extraction

    private func extractMonthLabels() -> [(offset: Int, label: String, span: Int)] {
        var result: [(offset: Int, label: String, span: Int)] = []
        let formatter = Self.dateParser

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

        if currentMonth != -1 {
            result.append((offset: startOffset, label: monthNames[currentMonth - 1], span: currentSpan))
        }

        return result
    }
}

// MARK: - Contribution Cell

/// Separate View struct so SwiftUI only redraws the 2 cells that change on hover,
/// not the entire 365-cell grid.
struct ContributionCellView: View {
    let day: ContributionDay
    let isHovered: Bool
    let fillColor: Color
    let cellSize: CGFloat
    let onHover: (Bool) -> Void

    @State private var isCursorPushed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(fillColor)
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(.primary.opacity(0.5), lineWidth: 1)
                    .opacity(isHovered ? 1 : 0)
            )
            .onHover { hovered in
                if hovered && !isCursorPushed {
                    NSCursor.pointingHand.push()
                    isCursorPushed = true
                } else if !hovered && isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
                onHover(hovered)
            }
            .onDisappear {
                if isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
            .help(ContributionGraphView.tooltipText(for: day))
    }
}

// MARK: - Legend

struct ContributionLegend: View {

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            Text("Less")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            let hexes = colorScheme == .dark ? GitHubColors.darkLevels : GitHubColors.lightLevels
            ForEach(0..<hexes.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: hexes[i]))
                    .frame(width: 10, height: 10)
            }

            Text("More")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}
