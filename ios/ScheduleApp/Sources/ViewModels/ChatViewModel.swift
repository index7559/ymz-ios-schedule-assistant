import Foundation
import Combine

// MARK: - Chat State

enum ChatState: Equatable {
    case idle
    case listening
    case processing
    case showingOptions([LLMOptions])
    case error(String)
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
                currentOptions = options
                chatState = .showingOptions(options)
                followUpQuestion = nil
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

            // Trigger sync
            await syncSchedule(schedule)
        } catch {
            chatState = .error("保存失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync

    private func syncSchedule(_ schedule: PendingSchedule) async {
        do {
            try await APIService.shared.createSchedule(
                Schedule(
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
            )
            try databaseManager.markScheduleSynced(id: schedule.id)
        } catch {
            print("Sync failed: \(error)")
            // Will retry on next sync
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
