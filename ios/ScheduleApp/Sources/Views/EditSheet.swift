import SwiftUI

struct EditSheet: View {
    let schedule: PendingSchedule
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var location: String
    @State private var notes: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasEndTime: Bool
    @State private var reminderDate: Date
    @State private var hasReminder: Bool

    init(schedule: PendingSchedule, viewModel: ScheduleViewModel) {
        self.schedule = schedule
        self.viewModel = viewModel

        _title = State(initialValue: schedule.title)
        _location = State(initialValue: schedule.location ?? "")
        _notes = State(initialValue: schedule.notes ?? "")
        _startDate = State(initialValue: Date(timeIntervalSince1970: TimeInterval(schedule.startTime)))
        _hasEndTime = State(initialValue: schedule.endTime != nil)
        _endDate = State(initialValue: Date(timeIntervalSince1970: TimeInterval(schedule.endTime ?? schedule.startTime)))
        _hasReminder = State(initialValue: schedule.reminderTime != nil)
        _reminderDate = State(initialValue: Date(timeIntervalSince1970: TimeInterval(schedule.reminderTime ?? (schedule.startTime - 900))))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("日程详情") {
                    TextField("标题", text: $title)

                    TextField("位置（可选）", text: $location)

                    TextField("备注（可选）", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("时间") {
                    DatePicker("开始时间", selection: $startDate, displayedComponents: .hourAndMinute)

                    Toggle("设置结束时间", isOn: $hasEndTime)

                    if hasEndTime {
                        DatePicker("结束时间", selection: $endDate, displayedComponents: .hourAndMinute)
                    }
                }

                Section("提醒") {
                    Toggle("设置提醒", isOn: $hasReminder)

                    if hasReminder {
                        DatePicker("提醒时间", selection: $reminderDate, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.deleteSchedule(schedule)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("删除日程")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("编辑日程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        var updated = schedule
        updated.title = title
        updated.location = location.isEmpty ? nil : location
        updated.notes = notes.isEmpty ? nil : notes
        updated.startTime = Int64(startDate.timeIntervalSince1970)
        updated.endTime = hasEndTime ? Int64(endDate.timeIntervalSince1970) : nil
        updated.reminderTime = hasReminder ? Int64(reminderDate.timeIntervalSince1970) : nil
        updated.updatedAt = Int64(Date().timeIntervalSince1970)

        do {
            try DatabaseManager.shared.updateSchedule(updated)
            viewModel.loadSchedules()

            // Sync with server
            dismiss()
        } catch {
            print("Failed to update schedule: \(error)")
        }
    }
}
