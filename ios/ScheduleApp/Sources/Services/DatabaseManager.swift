import Foundation
import GRDB

// MARK: - Database Manager

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?

    private init() {
        setupDatabase()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = appSupportURL.appendingPathComponent("schedule.sqlite")

            dbQueue = try DatabaseQueue(path: dbURL.path)
            try createTables()
        } catch {
            print("FATAL: Database setup failed: \(error). All DB operations will fail!")
        }
    }

    /// Returns the database queue, throwing if not initialized
    private func getDB() throws -> DatabaseQueue {
        guard let db = dbQueue else {
            let error = NSError(domain: "DatabaseManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Database not initialized. GRDB setup failed — check console for errors."])
            throw error
        }
        return db
    }

    private func createTables() throws {
        try getDB().write { db in
            // Schedules table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS schedules (
                    id TEXT PRIMARY KEY,
                    sessionId TEXT NOT NULL,
                    title TEXT NOT NULL,
                    location TEXT,
                    notes TEXT,
                    startTime INTEGER NOT NULL,
                    endTime INTEGER,
                    reminderTime INTEGER,
                    repeatRule TEXT,
                    isCompleted INTEGER NOT NULL DEFAULT 0,
                    isSynced INTEGER NOT NULL DEFAULT 0,
                    createdAt INTEGER NOT NULL,
                    updatedAt INTEGER NOT NULL
                )
            """)

            // Pending inputs table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS pendingInputs (
                    id TEXT PRIMARY KEY,
                    sessionId TEXT NOT NULL,
                    userInput TEXT NOT NULL,
                    isProcessed INTEGER NOT NULL DEFAULT 0,
                    createdAt INTEGER NOT NULL
                )
            """)

            // Sessions table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    lastActiveAt INTEGER NOT NULL
                )
            """)

            // Create indexes
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_schedules_sessionId ON schedules(sessionId)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_schedules_isSynced ON schedules(isSynced)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_pendingInputs_sessionId ON pendingInputs(sessionId)")
        }
    }

    // MARK: - Schedules

    func saveSchedule(_ schedule: PendingSchedule) throws {
        try getDB().write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO schedules
                (id, sessionId, title, location, notes, startTime, endTime, reminderTime, repeatRule, isCompleted, isSynced, createdAt, updatedAt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                schedule.id,
                schedule.sessionId,
                schedule.title,
                schedule.location,
                schedule.notes,
                schedule.startTime,
                schedule.endTime,
                schedule.reminderTime,
                schedule.repeatRule,
                schedule.isCompleted ? 1 : 0,
                schedule.isSynced ? 1 : 0,
                schedule.createdAt,
                schedule.updatedAt
            ])
        }
    }

    func getSchedules(for sessionId: String) throws -> [PendingSchedule] {
        try getDB().read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM schedules WHERE sessionId = ? ORDER BY startTime ASC
            """, arguments: [sessionId])
            return rows.map { row in
                PendingSchedule(
                    id: row["id"],
                    sessionId: row["sessionId"],
                    title: row["title"],
                    location: row["location"],
                    notes: row["notes"],
                    startTime: row["startTime"],
                    endTime: row["endTime"],
                    reminderTime: row["reminderTime"],
                    repeatRule: row["repeatRule"],
                    isCompleted: row["isCompleted"] == 1,
                    isSynced: row["isSynced"] == 1,
                    createdAt: row["createdAt"],
                    updatedAt: row["updatedAt"]
                )
            }
        }
    }

    func getAllSchedules() throws -> [PendingSchedule] {
        try getDB().read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM schedules ORDER BY startTime ASC")
            return rows.map { row in
                PendingSchedule(
                    id: row["id"],
                    sessionId: row["sessionId"],
                    title: row["title"],
                    location: row["location"],
                    notes: row["notes"],
                    startTime: row["startTime"],
                    endTime: row["endTime"],
                    reminderTime: row["reminderTime"],
                    repeatRule: row["repeatRule"],
                    isCompleted: row["isCompleted"] == 1,
                    isSynced: row["isSynced"] == 1,
                    createdAt: row["createdAt"],
                    updatedAt: row["updatedAt"]
                )
            }
        }
    }

    func getUnsyncedSchedules() throws -> [PendingSchedule] {
        try getDB().read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM schedules WHERE isSynced = 0")
            return rows.map { row in
                PendingSchedule(
                    id: row["id"],
                    sessionId: row["sessionId"],
                    title: row["title"],
                    location: row["location"],
                    notes: row["notes"],
                    startTime: row["startTime"],
                    endTime: row["endTime"],
                    reminderTime: row["reminderTime"],
                    repeatRule: row["repeatRule"],
                    isCompleted: row["isCompleted"] == 1,
                    isSynced: row["isSynced"] == 1,
                    createdAt: row["createdAt"],
                    updatedAt: row["updatedAt"]
                )
            }
        }
    }

    func markScheduleSynced(id: String) throws {
        try getDB().write { db in
            try db.execute(sql: "UPDATE schedules SET isSynced = 1 WHERE id = ?", arguments: [id])
        }
    }

    func deleteSchedule(id: String) throws {
        try getDB().write { db in
            try db.execute(sql: "DELETE FROM schedules WHERE id = ?", arguments: [id])
        }
    }

    func updateSchedule(_ schedule: PendingSchedule) throws {
        try saveSchedule(schedule)
    }

    // MARK: - Pending Inputs

    func savePendingInput(_ input: PendingInput) throws {
        try getDB().write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO pendingInputs (id, sessionId, userInput, isProcessed, createdAt)
                VALUES (?, ?, ?, ?, ?)
            """, arguments: [
                input.id,
                input.sessionId,
                input.userInput,
                input.isProcessed ? 1 : 0,
                input.createdAt
            ])
        }
    }

    func getPendingInputs(for sessionId: String) throws -> [PendingInput] {
        try getDB().read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT * FROM pendingInputs WHERE sessionId = ? AND isProcessed = 0 ORDER BY createdAt ASC
            """, arguments: [sessionId])
            return rows.map { row in
                PendingInput(
                    id: row["id"],
                    sessionId: row["sessionId"],
                    userInput: row["userInput"],
                    isProcessed: row["isProcessed"] == 1,
                    createdAt: row["createdAt"]
                )
            }
        }
    }

    func markPendingInputProcessed(id: String) throws {
        try getDB().write { db in
            try db.execute(sql: "UPDATE pendingInputs SET isProcessed = 1 WHERE id = ?", arguments: [id])
        }
    }

    func deletePendingInput(id: String) throws {
        try getDB().write { db in
            try db.execute(sql: "DELETE FROM pendingInputs WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Sessions

    func saveSession(_ session: Session) throws {
        try getDB().write { db in
            try db.execute(sql: """
                INSERT OR REPLACE INTO sessions (id, lastActiveAt) VALUES (?, ?)
            """, arguments: [session.id, session.lastActiveAt])
        }
    }

    func getSession(id: String) throws -> Session? {
        try getDB().read { db in
            if let row = try Row.fetchOne(db, sql: "SELECT * FROM sessions WHERE id = ?", arguments: [id]) {
                return Session(id: row["id"], lastActiveAt: row["lastActiveAt"])
            }
            return nil
        }
    }

    func updateSessionLastActive(id: String) throws {
        try getDB().write { db in
            try db.execute(
                sql: "UPDATE sessions SET lastActiveAt = ? WHERE id = ?",
                arguments: [Int64(Date().timeIntervalSince1970), id]
            )
        }
    }

    func getOrCreateSession() throws -> Session {
        // Check for existing session
        let rows: [Row] = try getDB().read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM sessions ORDER BY lastActiveAt DESC")
        }

        if let lastSession = rows.first {
            let lastActive = Date(timeIntervalSince1970: TimeInterval(lastSession["lastActiveAt"] as Int64))
            let hoursSinceActive = Date().timeIntervalSince(lastActive) / 3600

            if hoursSinceActive < 72 {
                try? updateSessionLastActive(id: lastSession["id"])
                return Session(id: lastSession["id"], lastActiveAt: lastSession["lastActiveAt"])
            }
        }

        // Create new session
        let newSession = Session(
            id: UUID().uuidString,
            lastActiveAt: Int64(Date().timeIntervalSince1970)
        )
        try saveSession(newSession)
        return newSession
    }

    // MARK: - Cleanup

    func cleanupOldSessions() throws {
        let cutoff = Int64(Date().timeIntervalSince1970) - (72 * 3600)
        try getDB().write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE lastActiveAt < ?", arguments: [cutoff])
        }
    }

    func cleanupOldPendingInputs() throws {
        let cutoff = Int64(Date().timeIntervalSince1970) - (24 * 3600)
        try getDB().write { db in
            try db.execute(
                sql: "DELETE FROM pendingInputs WHERE createdAt < ? AND isProcessed = 1",
                arguments: [cutoff]
            )
        }
    }
}
