import SwiftUI

struct MonthView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var selectedDate = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation
                monthHeader

                // Weekday headers
                weekdayHeader

                // Calendar grid
                calendarGrid

                Divider()

                // Selected date schedules
                selectedDateSchedules
            }
            .navigationTitle("日历")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(monthYearString)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = generateDays()
        let today = calendar.startOfDay(for: Date())

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let date = day {
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDate(date, inSameDayAs: today),
                        hasSchedules: hasSchedules(on: date)
                    ) {
                        selectedDate = date
                    }
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal)
    }

    private func generateDays() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)

        // Add empty cells for days before the first of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add days of the month
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }

    private func hasSchedules(on date: Date) -> Bool {
        !viewModel.schedulesForDate(date).isEmpty
    }

    // MARK: - Selected Date Schedules

    private var selectedDateSchedules: some View {
        let schedules = viewModel.schedulesForDate(selectedDate)

        return VStack(alignment: .leading, spacing: 8) {
            Text(selectedDateString)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if schedules.isEmpty {
                Text("无日程")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(schedules) { schedule in
                            MiniScheduleRow(schedule: schedule)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()
        }
    }

    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasSchedules: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.body)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(foregroundColor)

                if hasSchedules {
                    Circle()
                        .fill(isSelected ? .white : .blue)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .blue.opacity(0.2)
        }
        return .clear
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        }
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 {
            return .red
        } else if weekday == 7 {
            return .orange
        }
        return .primary
    }
}

// MARK: - Mini Schedule Row

struct MiniScheduleRow: View {
    let schedule: PendingSchedule

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(schedule.isCompleted ? Color.gray : Color.blue)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(schedule.isCompleted)
                    .foregroundColor(schedule.isCompleted ? .secondary : .primary)

                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")

        let start = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(schedule.startTime)))

        if let endTime = schedule.endTime {
            let end = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(endTime)))
            return "\(start) - \(end)"
        }

        return start
    }
}
