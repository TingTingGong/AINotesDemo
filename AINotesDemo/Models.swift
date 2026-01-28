//
//  Note.swift
//  数据模型定义
//
//  Created by 宫廷 on 2026/1/27.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var summary: String?
    var timestamp: Date
    var tags: [String]
    var audioURL: String?
    
    init(title: String, content: String, summary: String? = nil, tags: [String] = [], audioURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.summary = summary
        self.timestamp = Date()
        self.tags = tags
        self.audioURL = audioURL
    }
}

// MARK: - API配置
struct APIConfig {
    // OpenAI 配置
    static let openAIKey = "sk-gkjZSjikfIyIY4DbDb47B0B9EfCb4626A741B5C22d8874C6"
    static let openAIBaseURL = "https://aihubmix.com/v1"
    
    // Google Gemini 配置（可选）
    static let geminiKey = "sk-gkjZSjikfIyIY4DbDb47B0B9EfCb4626A741B5C22d8874C6"
    static let geminiBaseURL = "https://aihubmix.com/v1"
    
    // 使用的模型
    enum AIModel: String {
        case gpt4oMini = "gpt-4o-mini"
        case gpt4o = "gpt-4o"
        case geminiPro = "gemini-pro"
    }
    
    static var currentModel: AIModel = .gpt4oMini
}

// MARK: - API响应模型
struct WhisperResponse: Codable {
    let text: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let title: String
        let message: ChatMessage
    }
}

// Gemini API 模型
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    
    struct GeminiContent: Codable {
        let parts: [GeminiPart]
        
        struct GeminiPart: Codable {
            let text: String
        }
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
        
        struct Content: Codable {
            let parts: [Part]
            
            struct Part: Codable {
                let text: String
            }
        }
    }
}
