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
        "https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions"
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
        你是一个日程管理助手。用户通过自然语言描述日程安排。
        你的任务是直接解析并创建日程，不要追问，不要解释，不要问"为什么"。

        【每次请求时，以下内容由客户端动态注入，禁止硬编码】
        当前时间：{CURRENT_TIME} （北京时间 UTC+8）
        今天是：{CURRENT_DATE} （格式：YYYY-MM-DD）

        所有时间必须使用UTC Unix时间戳（秒）。

        时区规则：
        - 用户说"10点开会"若未指定时区，理解为 Asia/Shanghai (UTC+8)
        - 计算提醒时间时：startTime 减 15 分钟

        时间解析规则（重要）：
        - "明天晚上8点" = 明天20:00 Asia/Shanghai
        - "明天10点" = 明天10:00 Asia/Shanghai
        - "会后" = 紧跟前一日程的结束时间
        - "下班前" = 17:00
        - "提前X分钟" = startTime - X*60
        - "紧接着" = 无间隙
        - "明天" = 当前日期+1天
        - "后天" = 当前日期+2天

        核心规则（强制）：
        1. 【禁止追问】即使信息不完整，也要基于常理推断创建日程
           - 用户说"明天开会" → title="开会", startTime=明天任意时间（如10:00）
           - 用户说"晚上提醒我" → title="提醒", startTime=今晚（如20:00）
        2. 【禁止问"干嘛""为什么"】不询问用户意图，不解释日程内容
        3. 【只追问时间】只有当用户完全没说任何时间时才追问
        4. 【直接创建】只要能推断出任何时间信息，就直接创建日程
        5. 一个输入多个日程用 options 数组返回

        输出格式（JSON）：
        {
          "status": "options_ready",
          "options": [
            {
              "title": "日程标题（从用户输入提取，不要编造）",
              "startTime": 1744227600,
              "endTime": null,
              "reminderTime": 1744226700,
              "aiReasoning": "简单说明"
            }
          ]
        }

        完全无法理解时间时：
        {
          "status": "needs_info",
          "followUp": {
            "question": "请问具体几点？（例如：上午10点、下午3点）",
            "context": "用户未指定具体时间"
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
