import Foundation
import Combine

// MARK: - Chat State

enum ChatState: Equatable {
    case idle
    case listening
    case processing
    case showingOptions([LLMOptions])
    case toast(ToastData)
    case error(String)
}

struct ToastData: Equatable {
    let schedules: [PendingSchedule]
    let undoId: String
}

/// Actions triggered when toast is dismissed
enum ToastDismissAction: Equatable {
    case none
    case viewDetails  // User tapped "详情" — switch to calendar tab
}

// MARK: - Chat View Model

@MainActor
class ChatViewModel: ObservableObject {
    @Published var userInput = ""
    @Published var chatState: ChatState = .idle
    @Published var currentOptions: [LLMOptions] = []
    @Published var followUpQuestion: String?
    @Published var sessionId: String = ""
    @Published var scheduleCreated = false
    @Published var toastMessage: String = ""
    @Published var toastSchedules: [PendingSchedule] = []
    @Published var toastUndoId: String = ""
    @Published var dismissAction: ToastDismissAction = .none

    let speechService = SpeechService.shared
    private let llmService = LLMService.shared
    private let databaseManager = DatabaseManager.shared

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        loadOrCreateSession()
    }

    private func setupBindings() {
        speechService.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                if !transcript.isEmpty {
                    self?.userInput = transcript
                }
            }
            .store(in: &cancellables)
    }

    private func loadOrCreateSession() {
        do {
            let session = try databaseManager.getOrCreateSession()
            sessionId = session.id
        } catch {
            print("Failed to get session: \(error)")
            sessionId = UUID().uuidString
        }
    }

    // MARK: - Speech

    func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
            chatState = .idle
        } else {
            do {
                try speechService.startRecording()
                chatState = .listening
            } catch {
                chatState = .error("无法开始录音: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Submit

    func submitInput() async {
        let input = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        // Save pending input
        let pendingInput = PendingInput(
            id: UUID().uuidString,
            sessionId: sessionId,
            userInput: input,
            isProcessed: false,
            createdAt: Int64(Date().timeIntervalSince1970)
        )
        try? databaseManager.savePendingInput(pendingInput)

        // Stop recording if active
        if speechService.isRecording {
            speechService.stopRecording()
        }

        chatState = .processing
        userInput = ""

        do {
            let response = try await llmService.createSchedule(userInput: input)

            if response.status == "options_ready", let options = response.options, !options.isEmpty {
                // Directly create schedules without showing options
                await createSchedulesFromOptions(options)
            } else if response.status == "needs_info", let followUp = response.followUp {
                currentOptions = []
                chatState = .idle
                followUpQuestion = followUp.question
            } else {
                chatState = .error("无法理解回复")
            }
        } catch {
            chatState = .error(error.localizedDescription)
        }
    }

    // MARK: - Create Schedules

    private func createSchedulesFromOptions(_ options: [LLMOptions]) async {
        let now = Int64(Date().timeIntervalSince1970)
        var createdSchedules: [PendingSchedule] = []
        let undoId = UUID().uuidString

        for option in options {
            let schedule = PendingSchedule(
                id: UUID().uuidString,
                sessionId: sessionId,
                title: option.title,
                location: nil,
                notes: option.aiReasoning,
                startTime: option.startTime,
                endTime: option.endTime,
                reminderTime: option.reminderTime,
                repeatRule: nil,
                isCompleted: false,
                isSynced: false,
                createdAt: now,
                updatedAt: now
            )

            do {
                try databaseManager.saveSchedule(schedule)
                createdSchedules.append(schedule)
            } catch {
                print("Failed to save schedule: \(error)")
            }
        }

        // Mark pending input as processed
        if let inputs = try? databaseManager.getPendingInputs(for: sessionId),
           let lastInput = inputs.last {
            try? databaseManager.markPendingInputProcessed(id: lastInput.id)
        }

        // Show toast
        let count = createdSchedules.count
        toastMessage = "✓ 已添加 \(count) 个日程"
        toastSchedules = createdSchedules
        toastUndoId = undoId
        chatState = .toast(ToastData(schedules: createdSchedules, undoId: undoId))

        // Trigger list refresh via ContentView's onChange(scheduleCreated)
        scheduleCreated = true

        // Schedule auto-dismiss after 5 seconds
        scheduleAutoDismiss(undoId: undoId)
    }

    private func scheduleAutoDismiss(undoId: String) {
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await MainActor.run {
                if self.toastUndoId == undoId {
                    self.dismissToast(action: .none)
                }
            }
        }
    }

    func dismissToast(action: ToastDismissAction = .none) {
        dismissAction = action
        toastMessage = ""
        toastSchedules = []
        toastUndoId = ""
        if case .toast = chatState {
            chatState = .idle
        }
        // Reset action after a short delay so the same action can be triggered again
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                self.dismissAction = .none
            }
        }
    }

    func undoToast() {
        // Delete all schedules in toast
        for schedule in toastSchedules {
            try? databaseManager.deleteSchedule(id: schedule.id)
        }
        // Trigger list refresh to show updated state after deletion
        scheduleCreated = true
        dismissToast()
    }

    // MARK: - Select Option

    func selectOption(_ option: LLMOptions) async {
        let now = Int64(Date().timeIntervalSince1970)

        let schedule = PendingSchedule(
            id: UUID().uuidString,
            sessionId: sessionId,
            title: option.title,
            location: nil,
            notes: option.aiReasoning,
            startTime: option.startTime,
            endTime: option.endTime,
            reminderTime: option.reminderTime,
            repeatRule: nil,
            isCompleted: false,
            isSynced: false,
            createdAt: now,
            updatedAt: now
        )

        do {
            try databaseManager.saveSchedule(schedule)
            scheduleCreated = true
            currentOptions = []
            chatState = .idle

            // Mark pending input as processed
            if let inputs = try? databaseManager.getPendingInputs(for: sessionId),
               let lastInput = inputs.last {
                try? databaseManager.markPendingInputProcessed(id: lastInput.id)
            }
        } catch {
            chatState = .error("保存失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Dismiss Options

    func dismissOptions() {
        currentOptions = []
        chatState = .idle
        followUpQuestion = nil
    }

    func resetScheduleCreated() {
        scheduleCreated = false
    }
}
