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
    private let apiService = APIService.shared

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

    // MARK: - Sync

    func syncWithServer() async {
        isLoading = true

        do {
            // Get unsynced local schedules
            let unsyncedSchedules = try databaseManager.getUnsyncedSchedules()

            // Upload unsynced schedules
            for schedule in unsyncedSchedules {
                let serverSchedule = Schedule(
                    id: schedule.id,
                    title: schedule.title,
                    location: schedule.location,
                    notes: schedule.notes,
                    startTime: schedule.startTime,
                    endTime: schedule.endTime,
                    reminderTime: schedule.reminderTime,
                    timezone: "Asia/Shanghai",
                    repeatRule: schedule.repeatRule,
                    isCompleted: schedule.isCompleted,
                    createdAt: schedule.createdAt,
                    updatedAt: schedule.updatedAt
                )

                try await apiService.createSchedule(serverSchedule)
                try databaseManager.markScheduleSynced(id: schedule.id)
            }

            // Download from server
            let from = Int64(Date().timeIntervalSince1970) - (30 * 24 * 3600) // 30 days ago
            let serverSchedules = try await apiService.getSchedules(from: from)

            // Merge server schedules (simple approach: just add missing ones)
            for serverSchedule in serverSchedules {
                let exists = schedules.contains { $0.id == serverSchedule.id }
                if !exists {
                    let localSchedule = PendingSchedule(
                        id: serverSchedule.id,
                        sessionId: "",
                        title: serverSchedule.title,
                        location: serverSchedule.location,
                        notes: serverSchedule.notes,
                        startTime: serverSchedule.startTime,
                        endTime: serverSchedule.endTime,
                        reminderTime: serverSchedule.reminderTime,
                        repeatRule: serverSchedule.repeatRule,
                        isCompleted: serverSchedule.isCompleted,
                        isSynced: true,
                        createdAt: serverSchedule.createdAt,
                        updatedAt: serverSchedule.updatedAt
                    )
                    try? databaseManager.saveSchedule(localSchedule)
                }
            }

            // Reload
            loadSchedules()
        } catch {
            self.error = "同步失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Delete

    func deleteSchedule(_ schedule: PendingSchedule) {
        do {
            try databaseManager.deleteSchedule(id: schedule.id)
            schedules.removeAll { $0.id == schedule.id }

            // Also delete from server
            Task {
                try? await apiService.deleteSchedule(id: schedule.id)
            }
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

            Task {
                try? await apiService.markComplete(id: schedule.id)
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
