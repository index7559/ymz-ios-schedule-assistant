import Foundation

// MARK: - API Service Error

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case unauthorized
    case notFound
    case serverError(String)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务器地址"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .unauthorized: return "认证失败，请检查SYNC_SECRET"
        case .notFound: return "资源不存在"
        case .serverError(let msg): return "服务器错误: \(msg)"
        case .decodingError: return "数据解析错误"
        case .unknown: return "未知错误"
        }
    }
}

// MARK: - API Service

class APIService {
    static let shared = APIService()

    private init() {}

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? ""
    }

    private var deviceId: String {
        UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString
    }

    private var syncSecret: String? {
        KeychainHelper.getSyncSecret()
    }

    // MARK: - Ping

    func ping() async throws -> PingResponse {
        guard let url = URL(string: "\(baseURL)/api/ping") else {
            throw APIServiceError.invalidURL
        }
        return try await request(url: url, method: "GET", body: nil as String?)
    }

    // MARK: - Get Schedules

    func getSchedules(from: Int64? = nil, to: Int64? = nil) async throws -> [Schedule] {
        var urlString = "\(baseURL)/api/schedules"
        var queryItems: [String] = []

        if let from = from {
            queryItems.append("from=\(from)")
        }
        if let to = to {
            queryItems.append("to=\(to)")
        }
        if !queryItems.isEmpty {
            urlString += "?" + queryItems.joined(separator: "&")
        }

        guard let url = URL(string: urlString) else {
            throw APIServiceError.invalidURL
        }

        let response: SchedulesResponse = try await request(url: url, method: "GET", body: nil as String?)
        return response.schedules
    }

    // MARK: - Create Schedule

    func createSchedule(_ schedule: Schedule) async throws {
        let url = URL(string: "\(baseURL)/api/schedules")!
        let _: EmptyResponse = try await request(url: url, method: "POST", body: schedule)
    }

    // MARK: - Update Schedule

    func updateSchedule(_ schedule: Schedule) async throws {
        let url = URL(string: "\(baseURL)/api/schedules/\(schedule.id)")!
        let _: ScheduleResponse = try await request(url: url, method: "PUT", body: schedule)
    }

    // MARK: - Delete Schedule

    func deleteSchedule(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/schedules/\(id)")!
        let _: EmptyResponse = try await request(url: url, method: "DELETE", body: nil as String?)
    }

    // MARK: - Mark Complete

    func markComplete(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/schedules/\(id)/complete")!
        let _: EmptyResponse = try await request(url: url, method: "POST", body: nil as String?)
    }

    // MARK: - Sync

    func syncSchedules(_ schedules: [Schedule]) async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/api/sync")!
        return try await request(url: url, method: "POST", body: SyncRequest(schedules: schedules))
    }

    // MARK: - Private

    private func request<T: Decodable>(url: URL, method: String, body: (any Encodable)?) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

        if let secret = syncSecret {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknown
            }

            switch httpResponse.statusCode {
            case 200...201:
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)

            case 401:
                throw APIServiceError.unauthorized

            case 404:
                throw APIServiceError.notFound

            default:
                if let apiError = try? JSONDecoder().decode(APIServiceErrorResponse.self, from: data) {
                    throw APIServiceError.serverError(apiError.error)
                }
                throw APIServiceError.serverError("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as APIServiceError {
            throw error
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }
}

// MARK: - Helper Types

struct EmptyResponse: Codable {
    let success: Bool?

    init(success: Bool? = nil) {
        self.success = success
    }
}

struct ScheduleResponse: Codable {
    let success: Bool
    let schedule: Schedule
}

struct SyncRequest: Codable {
    let schedules: [Schedule]
}

struct APIServiceErrorResponse: Codable {
    let error: String
}
