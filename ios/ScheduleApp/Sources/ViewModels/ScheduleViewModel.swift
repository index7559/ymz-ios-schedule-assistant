import Foundation
import Combine

// MARK: - Schedule View Model

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var schedules: [PendingSchedule] = []
    @Published var selectedDate = Date()
    @Published var isLoading = false
    @Published var error: String?

    private let databaseManager = DatabaseManager.shared

    // MARK: - Load Schedules

    func loadSchedules() {
        isLoading = true
        error = nil

        do {
            schedules = try databaseManager.getAllSchedules()
        } catch {
            self.error = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadSchedules(for sessionId: String) {
        isLoading = true
        error = nil

        do {
            schedules = try databaseManager.getSchedules(for: sessionId)
        } catch {
            self.error = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Delete

    func deleteSchedule(_ schedule: PendingSchedule) {
        do {
            try databaseManager.deleteSchedule(id: schedule.id)
            schedules.removeAll { $0.id == schedule.id }
        } catch {
            self.error = "删除失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Mark Complete

    func markComplete(_ schedule: PendingSchedule) {
        var updatedSchedule = schedule
        updatedSchedule.isCompleted = true
        updatedSchedule.updatedAt = Int64(Date().timeIntervalSince1970)

        do {
            try databaseManager.updateSchedule(updatedSchedule)
            if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
                schedules[index] = updatedSchedule
            }
        } catch {
            self.error = "更新失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Filter

    func schedulesForDate(_ date: Date) -> [PendingSchedule] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return schedules.filter { schedule in
            let scheduleDate = Date(timeIntervalSince1970: TimeInterval(schedule.startTime))
            return scheduleDate >= startOfDay && scheduleDate < endOfDay
        }
    }

    func upcomingSchedules() -> [PendingSchedule] {
        let now = Int64(Date().timeIntervalSince1970)
        return schedules
            .filter { $0.startTime >= now && !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
    }
}
