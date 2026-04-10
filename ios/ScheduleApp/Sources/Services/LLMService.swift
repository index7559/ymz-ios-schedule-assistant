import Foundation

// MARK: - LLM Error

enum LLMError: Error, LocalizedError {
    case noAPIKey
    case networkError(Error)
    case timeout
    case invalidResponse
    case apiError(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "未配置API Key"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .timeout: return "请求超时"
        case .invalidResponse: return "无效的响应"
        case .apiError(let msg): return "API错误: \(msg)"
        case .decodingError: return "响应解析错误"
        }
    }
}

// MARK: - LLM Service

class LLMService {
    static let shared = LLMService()

    private let timeout: TimeInterval = 30
    private let maxRetries = 3

    private var apiKey: String? {
        KeychainHelper.getAPIKey()
    }

    private var baseURL: String {
        "https://ARK_BASE_URL/v1/chat/completions"  // 火山方舟API地址
    }

    private init() {}

    // MARK: - Create Mode

    func createSchedule(userInput: String) async throws -> LLMResponse {
        guard let apiKey = apiKey else {
            throw LLMError.noAPIKey
        }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let currentTime = formatter.string(from: now) + " CST"

        formatter.dateFormat = "yyyy-MM-dd"
        let currentDate = formatter.string(from: now)

        let request = LLMCreateRequest(
            currentTime: currentTime,
            currentDate: currentDate,
            userInput: userInput
        )

        return try await callLLM(request: request, apiKey: apiKey)
    }

    // MARK: - Modify Mode

    func modifySchedule(originalOption: LLMOptions, userInput: String) async throws -> LLMResponse {
        guard let apiKey = apiKey else {
            throw LLMError.noAPIKey
        }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let currentTime = formatter.string(from: now) + " CST"

        formatter.dateFormat = "yyyy-MM-dd"
        let currentDate = formatter.string(from: now)

        let request = LLMModifyRequest(
            currentTime: currentTime,
            currentDate: currentDate,
            originalOption: originalOption,
            userInput: userInput
        )

        return try await callLLM(request: request, apiKey: apiKey)
    }

    // MARK: - Private

    private func callLLM(request: any Encodable, apiKey: String, retryCount: Int = 0) async throws -> LLMResponse {
        guard let url = URL(string: baseURL) else {
            throw LLMError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = timeout

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        // Build messages
        let systemPrompt = buildSystemPrompt()
        let userMessage = try buildUserMessage(from: request)

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userMessage]
        ]

        let body: [String: Any] = [
            "model": "ark-code-latest",
            "messages": messages,
            "temperature": 0.7
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw LLMError.apiError("API Key无效")
            }

            if httpResponse.statusCode == 503 || httpResponse.statusCode == 504 {
                if retryCount < maxRetries {
                    let delay = pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await callLLM(request: request, apiKey: apiKey, retryCount: retryCount + 1)
                }
                throw LLMError.timeout
            }

            guard httpResponse.statusCode == 200 else {
                throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
            }

            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw LLMError.invalidResponse
            }

            // Extract JSON from content
            let jsonString = extractJSON(from: content)
            let decoder = JSONDecoder()
            return try decoder.decode(LLMResponse.self, from: jsonString.data(using: .utf8)!)

        } catch let error as LLMError {
            throw error
        } catch let error as DecodingError {
            throw LLMError.decodingError(error)
        } catch {
            throw LLMError.networkError(error)
        }
    }

    private func buildSystemPrompt() -> String {
        """
        你是一个日程管理助手。用户通过自然语言描述他们的日程安排。
        你的任务是解析用户的意图，生成明确的日程选项供用户确认。

        【每次请求时，以下内容由客户端动态注入，禁止硬编码】
        当前时间：{CURRENT_TIME} （北京时间 UTC+8）
        今天是：{CURRENT_DATE} （格式：YYYY-MM-DD）

        所有时间必须使用UTC Unix时间戳（秒），不要使用ISO 8601字符串。

        时区规则（重要）：
        - 用户说"10点开会"若未指定时区，理解为 Asia/Shanghai (UTC+8)
        - 计算提醒时间时：先将用户时间转换为UTC，再减去提前分钟数
        - 例如：用户说"10点提前15分钟通知"，当前时间为 2026-04-10 09:00 CST
          → startTime = 1744227600 (2026-04-10 10:00 CST = 02:00 UTC)
          → reminderTime = startTime - 15*60 = 1744226700 (2026-04-10 09:45 CST)

        时间依赖关系理解（重要）：
        - "会后" = 前一个日程的 end_time（如果前一个日程有结束时间）
        - "之前" = 某时间点之前，如"下班前"默认为17:00
        - "提前X分钟" = start_time - X*60
        - "紧接着" = 无间隙，后一个日程 start_time = 前一个日程的 end_time
        - "中间休息10分钟" = 日程之间留10分钟空白
        - "明天" = 当前日期+1天
        - "后天" = 当前日期+2天
        - "下周一" = 下一个周一（若今天已是周一则为今天起算的7天后）

        规则：
        1. 意图不完整时，必须追问，不猜
        2. 每个日程必须包含：title、startTime（Unix秒戳）、reminderTime（Unix秒戳）
        3. 有明确持续时间的日程必须包含endTime
        4. "提前X分钟通知"必须解析为 startTime 减 X * 60 秒
        5. 多个日程用 options 数组返回
        6. 意图完整时返回 status: "options_ready"
        7. 意图不完整时返回 status: "needs_info"，追问内容放入 followUp.question 字段

        输出格式（JSON，key为英文，内容为中文）：
        {
          "status": "options_ready",
          "options": [
            {
              "title": "日程标题",
              "startTime": 1744227600,
              "endTime": null,
              "reminderTime": 1744226700,
              "aiReasoning": "你对这条日程的理解说明"
            }
          ]
        }

        意图不完整时：
        {
          "status": "needs_info",
          "followUp": {
            "question": "追问问题",
            "context": "追问的背景说明"
          }
        }
        """
    }

    private func buildUserMessage(from request: any Encodable) throws -> String {
        if let createReq = request as? LLMCreateRequest {
            return createReq.userInput
        } else if let modifyReq = request as? LLMModifyRequest {
            let original = modifyReq.originalOption
            return """
            修改日程：\(original.title) (startTime: \(original.startTime), reminderTime: \(original.reminderTime ?? 0))
            新描述：\(modifyReq.userInput)
            """
        }
        return ""
    }

    private func extractJSON(from content: String) -> String {
        // Try to find JSON block using regex
        let pattern = "\\{[\\s\\S]*\\}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range, in: content) {
            return String(content[range])
        }
        return content
    }
}
