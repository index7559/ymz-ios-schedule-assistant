import SwiftUI

struct ScheduleListView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var showingEditSheet = false
    @State private var scheduleToEdit: PendingSchedule?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.schedules.isEmpty {
                    ProgressView("加载中...")
                } else if viewModel.schedules.isEmpty {
                    emptyView
                } else {
                    scheduleList
                }
            }
            .navigationTitle("日程列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.syncWithServer()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await viewModel.syncWithServer()
            }
            .sheet(item: $scheduleToEdit) { schedule in
                EditSheet(schedule: schedule, viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("暂无日程")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("点击下方「创建」添加日程")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Schedule List

    private var scheduleList: some View {
        List {
            // Upcoming section
            let upcoming = viewModel.upcomingSchedules()
            if !upcoming.isEmpty {
                Section("即将到来") {
                    ForEach(upcoming) { schedule in
                        ScheduleRow(schedule: schedule) {
                            scheduleToEdit = schedule
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteSchedule(schedule)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                viewModel.markComplete(schedule)
                            } label: {
                                Label("完成", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }

            // Completed section
            let completed = viewModel.schedules.filter { $0.isCompleted }
            if !completed.isEmpty {
                Section("已完成") {
                    ForEach(completed) { schedule in
                        ScheduleRow(schedule: schedule) {
                            scheduleToEdit = schedule
                        }
                        .opacity(0.6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteSchedule(schedule)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Schedule Row

struct ScheduleRow: View {
    let schedule: PendingSchedule
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time column
                VStack(alignment: .center, spacing: 2) {
                    Text(dayOfMonth)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(month)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 44)

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.title)
                        .font(.headline)
                        .strikethrough(schedule.isCompleted)
                        .foregroundColor(schedule.isCompleted ? .secondary : .primary)

                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(timeRange)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    if let location = schedule.location, !location.isEmpty {
                        HStack {
                            Image(systemName: "location")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Sync status
                if !schedule.isSynced {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var dayOfMonth: String {
        let date = Date(timeIntervalSince1970: TimeInterval(schedule.startTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var month: String {
        let date = Date(timeIntervalSince1970: TimeInterval(schedule.startTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月"
        return formatter.string(from: date)
    }

    private var timeRange: String {
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
