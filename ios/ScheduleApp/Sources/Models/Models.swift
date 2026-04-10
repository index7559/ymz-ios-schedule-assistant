import Foundation

// MARK: - Schedule

struct Schedule: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var location: String?
    var notes: String?
    var startTime: Int64          // Unix timestamp (seconds)
    var endTime: Int64?
    var reminderTime: Int64?
    var timezone: String = "Asia/Shanghai"
    var repeatRule: String?
    var isCompleted: Bool = false
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, location, notes
        case startTime = "start_time"
        case endTime = "end_time"
        case reminderTime = "reminder_time"
        case timezone
        case repeatRule = "repeat_rule"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startTime))
    }

    var endDate: Date? {
        endTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    var reminderDate: Date? {
        reminderTime.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}

// MARK: - Pending Schedule (local only)

struct PendingSchedule: Identifiable, Codable {
    let id: String
    var sessionId: String
    var title: String
    var location: String?
    var notes: String?
    var startTime: Int64
    var endTime: Int64?
    var reminderTime: Int64?
    var repeatRule: String?
    var isCompleted: Bool = false
    var isSynced: Bool = false
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, sessionId, title, location, notes
        case startTime = "start_time"
        case endTime = "end_time"
        case reminderTime = "reminder_time"
        case repeatRule = "repeat_rule"
        case isCompleted = "is_completed"
        case isSynced = "is_synced"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Pending Input (local only)

struct PendingInput: Identifiable, Codable {
    let id: String
    var sessionId: String
    var userInput: String
    var isProcessed: Bool = false
    var createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, sessionId, userInput
        case isProcessed = "is_processed"
        case createdAt = "created_at"
    }
}

// MARK: - LLM Options

struct LLMOptions: Codable, Equatable {
    let title: String
    let startTime: Int64
    let endTime: Int64?
    let reminderTime: Int64?
    let aiReasoning: String?

    enum CodingKeys: String, CodingKey {
        case title
        case startTime = "startTime"
        case endTime = "endTime"
        case reminderTime = "reminderTime"
        case aiReasoning = "aiReasoning"
    }
}

struct LLMResponse: Codable {
    let status: String  // "options_ready" or "needs_info"
    let options: [LLMOptions]?
    let followUp: LLMFollowUp?

    enum CodingKeys: String, CodingKey {
        case status
        case options
        case followUp
    }
}

struct LLMFollowUp: Codable {
    let question: String
    let context: String?
}

// MARK: - LLM Request

struct LLMCreateRequest: Codable {
    let mode: String = "create"
    let currentTime: String
    let currentDate: String
    let userInput: String
}

struct LLMModifyRequest: Codable {
    let mode: String = "modify"
    let currentTime: String
    let currentDate: String
    let originalOption: LLMOptions
    let userInput: String
}

// MARK: - Session

struct Session: Codable {
    let id: String
    var lastActiveAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case lastActiveAt = "last_active_at"
    }
}

// MARK: - API Response

struct SchedulesResponse: Codable {
    let schedules: [Schedule]
}

struct SyncResponse: Codable {
    let success: Bool
    let syncedCount: Int
}

struct PingResponse: Codable {
    let status: String
    let timestamp: Int64
}

struct APIError: Codable {
    let error: String
}
