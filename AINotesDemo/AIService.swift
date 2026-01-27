//
//  AIService.swift
//  AI服务封装 - 包含Whisper转录和GPT/Gemini摘要生成
//

import Foundation

enum AIServiceError: LocalizedError {
    case invalidAPIKey
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API密钥无效，请在APIConfig中配置"
        case .invalidURL:
            return "URL格式错误"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "响应格式错误"
        case .apiError(let message):
            return "API错误: \(message)"
        }
    }
}

class AIService {
    static let shared = AIService()
    private init() {}
    
    // MARK: - Whisper 语音转文字
    func transcribeAudio(fileURL: URL) async throws -> String {
        guard !APIConfig.openAIKey.isEmpty && APIConfig.openAIKey != "YOUR_OPENAI_API_KEY" else {
            throw AIServiceError.invalidAPIKey
        }
        
        let url = URL(string: "\(APIConfig.openAIBaseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        
        // 创建 multipart/form-data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // 添加音频文件
        let audioData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加模型参数
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // 添加语言参数（可选，支持自动检测）
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("zh\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw AIServiceError.apiError(errorMessage)
            }
            throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        let whisperResponse = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return whisperResponse.text
    }
    
    // MARK: - GPT 生成摘要
    func generateSummaryWithGPT(content: String) async throws -> (summary: String, tags: [String]) {
        guard !APIConfig.openAIKey.isEmpty && APIConfig.openAIKey != "YOUR_OPENAI_API_KEY" else {
            throw AIServiceError.invalidAPIKey
        }
        
        let url = URL(string: "\(APIConfig.openAIBaseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        请分析以下笔记内容，生成一个简洁的摘要和相关标签。
        
        要求：
        1. 摘要：用1-3句话概括核心内容，不超过150字
        2. 标签：提取3-5个关键词标签
        3. 输出格式必须严格遵循JSON格式：{"summary": "摘要内容", "tags": ["标签1", "标签2", "标签3"]}
        
        笔记内容：
        \(content)
        """
        
        let chatRequest = ChatCompletionRequest(
            model: APIConfig.currentModel.rawValue,
            messages: [
                ChatMessage(role: "system", content: "你是一个专业的笔记助手，擅长提取要点和生成摘要。"),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.7,
            maxTokens: 500
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw AIServiceError.apiError(errorMessage)
            }
            throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let message = chatResponse.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }
        
        // 解析JSON响应
        return try parseAIResponse(message)
    }
    
    // MARK: - Gemini 生成摘要
    func generateSummaryWithGemini(content: String) async throws -> (summary: String, tags: [String]) {
        guard !APIConfig.geminiKey.isEmpty && APIConfig.geminiKey != "YOUR_GEMINI_API_KEY" else {
            throw AIServiceError.invalidAPIKey
        }
        
        let urlString = "\(APIConfig.geminiBaseURL)/models/gemini-pro:generateContent?key=\(APIConfig.geminiKey)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        请分析以下笔记内容，生成一个简洁的摘要和相关标签。
        
        要求：
        1. 摘要：用1-3句话概括核心内容，不超过150字
        2. 标签：提取3-5个关键词标签
        3. 输出格式必须严格遵循JSON格式：{"summary": "摘要内容", "tags": ["标签1", "标签2", "标签3"]}
        
        笔记内容：
        \(content)
        """
        
        let geminiRequest = GeminiRequest(
            contents: [
                GeminiRequest.GeminiContent(
                    parts: [
                        GeminiRequest.GeminiContent.GeminiPart(text: prompt)
                    ]
                )
            ]
        )
        
        request.httpBody = try JSONEncoder().encode(geminiRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw AIServiceError.apiError(errorMessage)
            }
            throw AIServiceError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw AIServiceError.invalidResponse
        }
        
        // 解析JSON响应
        return try parseAIResponse(text)
    }
    
    // MARK: - 解析AI响应
    private func parseAIResponse(_ response: String) throws -> (summary: String, tags: [String]) {
        // 尝试提取JSON部分
        var jsonString = response
        
        // 移除可能的markdown代码块标记
        if let startRange = response.range(of: "```json") {
            jsonString = String(response[startRange.upperBound...])
        }
        if let endRange = jsonString.range(of: "```") {
            jsonString = String(jsonString[..<endRange.lowerBound])
        }
        
        // 查找第一个{和最后一个}
        if let firstBrace = jsonString.firstIndex(of: "{"),
           let lastBrace = jsonString.lastIndex(of: "}") {
            jsonString = String(jsonString[firstBrace...lastBrace])
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }
        
        struct AIResult: Codable {
            let summary: String
            let tags: [String]
        }
        
        let result = try JSONDecoder().decode(AIResult.self, from: jsonData)
        return (result.summary, result.tags)
    }
    
    // MARK: - 统一生成摘要接口
    func generateSummary(content: String, useModel: APIConfig.AIModel? = nil) async throws -> (summary: String, tags: [String]) {
        let model = useModel ?? APIConfig.currentModel
        
        switch model {
        case .gpt4oMini, .gpt4o:
            return try await generateSummaryWithGPT(content: content)
        case .geminiPro:
            return try await generateSummaryWithGemini(content: content)
        }
    }
}
