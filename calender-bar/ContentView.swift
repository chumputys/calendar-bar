//
//  ContentView.swift
//  calender-bar
//
//  Created by Ubaidulla Ali on 23-5-26.
//

import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var slideForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 14) {
                MonthHeader(
                    month: displayedMonth,
                    onPrev: { shiftMonth(-1) },
                    onNext: { shiftMonth(1) },
                    onToday: goToToday
                )

                VStack(spacing: 6) {
                    WeekdayRow()
                    MonthGrid(month: displayedMonth, selectedDate: $selectedDate)
                        .id(CalendarHelper.monthKey(displayedMonth))
                        .transition(slideTransition)
                }
                .padding(.top, 6)
                .padding(.bottom, 2)
                .background { WeekendStripes(columns: CalendarHelper.weekendColumns) }
                .clipped()

                HolidayLabel(date: selectedDate)
            }
            .padding(18)
            .frame(width: 320)
            .glassEffect(.regular, in: .rect) // edge-to-edge; popover clips corners
        }
        .focusEffectDisabled()
    }

    private var slideTransition: AnyTransition {
        if reduceMotion { return .opacity } // cross-fade instead of sliding
        return .asymmetric(
            insertion: .move(edge: slideForward ? .trailing : .leading),
            removal: .move(edge: slideForward ? .leading : .trailing)
        )
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = CalendarHelper.calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        slideForward = delta > 0
        withAnimation(reduceMotion ? nil : .snappy) { displayedMonth = next }
    }

    private func goToToday() {
        let now = Date()
        slideForward = now > displayedMonth
        withAnimation(reduceMotion ? nil : .snappy) {
            displayedMonth = now
            selectedDate = now
        }
    }
}

// MARK: - Header

private struct MonthHeader: View {
    let month: Date
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    private var title: String { month.formatted(.dateTime.month(.wide).year()) }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            HStack(spacing: 6) {
                NavButton(systemName: "chevron.left", action: onPrev)
                NavButton(systemName: "smallcircle.filled.circle", action: onToday)
                NavButton(systemName: "chevron.right", action: onNext)
                MenuButton()
            }
        }
    }
}

private struct NavButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}

private struct MenuButton: View {
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Menu {
            Picker("Menu Bar", selection: $settings.displayMode) {
                ForEach(MenuBarDisplay.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Toggle("Open at Login", isOn: $openAtLogin)
            Divider()
            Button("Quit calenderbar") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .circle)
        .onChange(of: openAtLogin) { _, enabled in
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                openAtLogin = SMAppService.mainApp.status == .enabled // revert on failure
            }
        }
    }
}

// MARK: - Holiday name line

private struct HolidayLabel: View {
    let date: Date

    var body: some View {
        HStack(spacing: 7) {
            if let name = Holidays.name(for: date) {
                Circle()
                    .fill(Holidays.color)
                    .frame(width: 6, height: 6)
                Text(name)
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 20) // fixed so layout never shifts
    }
}

// MARK: - Weekday row

private struct WeekdayRow: View {
    private var symbols: [String] { CalendarHelper.orderedWeekdaySymbols }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Weekend column shading

private struct WeekendStripes: View {
    let columns: Set<Int>

    private let spacing: CGFloat = 4
    private let cols = 7

    var body: some View {
        GeometryReader { geo in
            let w = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            ForEach(Array(CalendarHelper.contiguousRanges(columns).enumerated()), id: \.offset) { _, range in
                let width = CGFloat(range.count) * w + CGFloat(range.count - 1) * spacing
                let x = CGFloat(range.lowerBound) * (w + spacing)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: width, height: geo.size.height)
                    .position(x: x + width / 2, y: geo.size.height / 2)
            }
        }
    }
}

// MARK: - Grid

private struct MonthGrid: View {
    let month: Date
    @Binding var selectedDate: Date

    // Non-lazy week rows so the whole month renders up front and slides as one unit.
    private var weeks: [[Date]] {
        let days = CalendarHelper.gridDays(for: month)
        return stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(week, id: \.self) { day in
                        DayCell(
                            date: day,
                            isSelected: CalendarHelper.calendar.isDate(day, inSameDayAs: selectedDate),
                            isToday: CalendarHelper.calendar.isDateInToday(day),
                            isCurrentMonth: CalendarHelper.calendar.isDate(day, equalTo: month, toGranularity: .month)
                        ) {
                            selectedDate = day
                        }
                        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let action: () -> Void

    private var dayNumber: String {
        "\(CalendarHelper.calendar.component(.day, from: date))"
    }

    private var isHoliday: Bool { Holidays.isHoliday(date) }

    private var foreground: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(.white) }
        if isToday { return AnyShapeStyle(.tint) }
        if isCurrentMonth { return AnyShapeStyle(.primary) }
        return AnyShapeStyle(.secondary.opacity(0.5)) // muted adjacent-month days
    }

    var body: some View {
        Button(action: action) {
            Text(dayNumber)
                .font(.system(.callout, design: .rounded, weight: (isSelected || isToday) ? .bold : .regular))
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background {
                    if isSelected {
                        Circle().fill(.tint)
                    } else if isToday {
                        Circle().fill(.tint.opacity(0.15))
                    }
                }
                .overlay(alignment: .bottom) {
                    if isHoliday {
                        Circle()
                            .fill(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Holidays.color))
                            .frame(width: 5, height: 5)
                            .opacity(isCurrentMonth ? 1 : 0.45)
                            .padding(.bottom, 2)
                    }
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Holidays (Maldives 2026, embedded)

enum Holidays {
    static let color = Color.red

    private static let byKey: [String: String] = [
        "2026-01-01": "New Year's Day",
        "2026-02-05": "Majlis Presidential Address",
        "2026-02-18": "Ramadan Start",
        "2026-03-09": "Ramadan Holiday",
        "2026-03-10": "Ramadan Holiday",
        "2026-03-11": "Ramadan Holiday",
        "2026-03-12": "Ramadan Holiday",
        "2026-03-13": "Ramadan Holiday",
        "2026-03-14": "Ramadan Holiday",
        "2026-03-15": "Ramadan Holiday",
        "2026-03-16": "Ramadan Holiday",
        "2026-03-17": "Ramadan Holiday",
        "2026-03-18": "Ramadan Holiday",
        "2026-03-20": "Eid-ul-Fithr",
        "2026-03-21": "Eid-ul-Fithr Holiday",
        "2026-03-22": "Eid-ul-Fithr Holiday",
        "2026-05-01": "Labor Day",
        "2026-05-24": "Eid-ul Al'haa Holiday",
        "2026-05-25": "Eid-ul Al'haa Holiday",
        "2026-05-26": "Hajj Day",
        "2026-05-27": "Eid-ul Al'haa",
        "2026-05-28": "Eid-ul Al'haa Holiday",
        "2026-05-29": "Eid-ul Al'haa Holiday",
        "2026-05-30": "Eid-ul Al'haa Holiday",
        "2026-06-17": "Muharram",
        "2026-07-26": "Independence Day",
        "2026-07-27": "Independence Day Holiday",
        "2026-08-14": "National Day",
        "2026-08-26": "Milad un Nabi",
        "2026-09-14": "The Day Maldives Embraced Islam",
        "2026-11-03": "Victory Day",
        "2026-11-11": "Republic Day",
    ]

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func name(for date: Date) -> String? { byKey[keyFormatter.string(from: date)] }
    static func isHoliday(_ date: Date) -> Bool { name(for: date) != nil }
}

// MARK: - Calendar math

private enum CalendarHelper {
    static let calendar = Calendar.current

    /// Weekday short symbols rotated to start at the locale's first weekday.
    static var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Grid column indices (0-based) that land on Friday (weekday 6) and Saturday (weekday 7).
    static var weekendColumns: Set<Int> {
        var cols = Set<Int>()
        for col in 0..<7 {
            let weekday = ((calendar.firstWeekday - 1 + col) % 7) + 1
            if weekday == 6 || weekday == 7 { cols.insert(col) }
        }
        return cols
    }

    /// Groups column indices into contiguous ascending ranges (e.g. {5,6} -> [5..<7]).
    static func contiguousRanges(_ columns: Set<Int>) -> [Range<Int>] {
        let sorted = columns.sorted()
        var ranges: [Range<Int>] = []
        var start: Int?
        var prev: Int?
        for col in sorted {
            if let p = prev, col == p + 1 {
                prev = col
            } else {
                if let s = start, let p = prev { ranges.append(s..<(p + 1)) }
                start = col
                prev = col
            }
        }
        if let s = start, let p = prev { ranges.append(s..<(p + 1)) }
        return ranges
    }

    static func monthKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }

    /// Full 7-column grid of dates. Leading/trailing cells spill into adjacent months
    /// so every week row is complete (no gaps).
    static func gridDays(for month: Date) -> [Date] {
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let count = 42 // fixed 6 rows so the grid height never changes

        guard let start = calendar.date(byAdding: .day, value: -leading, to: firstOfMonth) else { return [] }
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

#Preview {
    PopoverView()
}
