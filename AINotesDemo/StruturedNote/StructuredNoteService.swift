//
//  StructuredNoteService.swift
//  结构化笔记生成服务
//
//  Created by 宫廷 on 2026/1/30.
//

import Foundation

class StructuredNoteService {
    static let shared = StructuredNoteService()
    private init() {}
    
    // MARK: - 生成结构化笔记
    func generateStructuredNote(content: String, format: StructuredNoteFormat = .outline) async throws -> StructuredNoteResponse {
        guard !APIConfig.openAIKey.isEmpty && APIConfig.openAIKey != "YOUR_OPENAI_API_KEY" else {
            throw AIServiceError.invalidAPIKey
        }
        
        let prompt = buildStructuredPrompt(content: content, format: format)
        
        let url = URL(string: "\(APIConfig.openAIBaseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = ChatCompletionRequest(
            model: APIConfig.currentModel.rawValue,
            messages: [
                ChatMessage(role: "system", content: "你是一个专业的笔记整理专家，擅长将文本内容结构化组织。你的输出必须是严格的JSON格式。"),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.7,
            maxTokens: 2000
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
        
        return try parseStructuredResponse(message)
    }
    
    // MARK: - 构建Prompt
    private func buildStructuredPrompt(content: String, format: StructuredNoteFormat) -> String {
        let basePrompt = """
        请将以下文本内容转换为结构化笔记。
        
        要求：
        1. 提取核心标题（简洁明了，5-10字）
        2. 生成3-5句话的摘要
        3. 提取3-5个关键要点（每个10-20字）
        4. 将内容分成2-5个主题章节，每个章节可以有子章节
        5. 识别所有行动项（任务、负责人、截止日期、优先级）
        6. 提取3-5个标签
        7. 识别笔记类型和元数据（参会人员、地点、时长等）
        
        """
        
        let formatGuidance: String
        switch format {
        case .outline:
            formatGuidance = """
            【大纲式格式要求】
            - 使用层次化的章节和子章节
            - 主章节：核心主题（如"设计决策"、"技术方案"）
            - 子章节：具体细节（如"视觉设计"、"交互设计"）
            - 内容简洁明了，要点突出
            """
            
        case .project:
            formatGuidance = """
            【项目管理式格式要求】
            - 章节包括：项目目标、团队成员、关键决策、资源预算等
            - 特别关注行动项、负责人、截止日期
            - 标注优先级（高/中/低）
            """
            
        case .qa:
            formatGuidance = """
            【问答式格式要求】
            - 将内容转化为问题和答案的形式
            - 章节标题使用问题（如"会议的主要目的是什么？"）
            - 内容为对应的答案
            - 适合访谈、讨论类笔记
            """
            
        case .timeline:
            formatGuidance = """
            【时间线式格式要求】
            - 按时间顺序组织内容
            - 章节标题包含时间点
            - 内容描述该时间点发生的事情
            - 适合事件记录、会议流程
            """
            
        case .analysis5W1H:
            formatGuidance = """
            【5W1H分析式格式要求】
            - 章节必须包括：What（什么）、Who（谁）、When（何时）、Where（何地）、Why（为什么）、How（如何）
            - 全面系统地分析内容
            - 适合事件分析、项目复盘
            """
            
        case .cornell:
            formatGuidance = """
            【康奈尔式格式要求】
            - 关键词（左栏）：提取核心概念
            - 笔记内容（右栏）：详细信息
            - 总结（底部）：3-5句话概括
            - 经典学习笔记格式
            """
            
        case .mindmap:
            formatGuidance = """
            【思维导图式格式要求】
            - 中心主题明确
            - 主分支：核心概念（2-5个）
            - 子分支：具体内容
            - 适合头脑风暴、创意整理
            """
        }
        
        let jsonFormat = """
        
        输出格式必须是严格的JSON：
        {
          "title": "核心标题",
          "summary": "3-5句话的摘要",
          "keyPoints": ["要点1", "要点2", "要点3"],
          "sections": [
            {
              "id": "section1",
              "title": "章节标题",
              "content": "章节内容",
              "subsections": [
                {
                  "id": "subsection1",
                  "title": "子章节标题",
                  "content": "子章节内容"
                }
              ]
            }
          ],
          "actionItems": [
            {
              "id": "action1",
              "task": "任务描述",
              "assignee": "负责人（如果有）",
              "deadline": "截止日期（如果有，格式YYYY-MM-DD）",
              "priority": "high/medium/low"
            }
          ],
          "tags": ["标签1", "标签2", "标签3"],
          "metadata": {
            "type": "meeting/learning/brainstorm/general",
            "participants": ["参与者1", "参与者2"],
            "location": "地点（如果有）",
            "duration": 时长分钟数（如果有）
          }
        }
        
        原始内容：
        \(content)
        """
        
        return basePrompt + formatGuidance + jsonFormat
    }
    
    // MARK: - 解析结构化响应
    private func parseStructuredResponse(_ response: String) throws -> StructuredNoteResponse {
        var jsonString = response
        
        // 移除markdown代码块标记
        if let startRange = response.range(of: "```json") {
            jsonString = String(response[startRange.upperBound...])
        } else if let startRange = response.range(of: "```") {
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
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(StructuredNoteResponse.self, from: jsonData)
        return result
    }
    
    // MARK: - 转换为Markdown
    func convertToMarkdown(structured: StructuredNoteResponse, format: StructuredNoteFormat) -> String {
        var markdown = ""
        
        // 标题
        markdown += "# \(structured.title)\n\n"
        
        // 元数据
        if !structured.metadata.participants.isEmptyOrNil {
            markdown += "**参会人员：** \(structured.metadata.participants!.joined(separator: ", "))\n"
        }
        if let location = structured.metadata.location {
            markdown += "**地点：** \(location)\n"
        }
        if let duration = structured.metadata.duration {
            markdown += "**时长：** \(duration)分钟\n"
        }
        markdown += "\n"
        
        // 摘要
        markdown += "## 🎯 核心摘要\n\n"
        markdown += "\(structured.summary)\n\n"
        
        // 关键要点
        if !structured.keyPoints.isEmpty {
            markdown += "## 📌 关键要点\n\n"
            for point in structured.keyPoints {
                markdown += "• \(point)\n"
            }
            markdown += "\n"
        }
        
        // 章节内容
        markdown += "## 💡 详细内容\n\n"
        for section in structured.sections {
            markdown += "### \(section.title)\n\n"
            markdown += "\(section.content)\n\n"
            
            if let subsections = section.subsections {
                for subsection in subsections {
                    markdown += "#### \(subsection.title)\n\n"
                    markdown += "\(subsection.content)\n\n"
                }
            }
        }
        
        // 行动项
        if !structured.actionItems.isEmpty {
            markdown += "## ✅ 行动项\n\n"
            for action in structured.actionItems {
                let priorityEmoji = action.priority == "high" ? "🔴" : action.priority == "low" ? "🟢" : "🟡"
                var actionLine = "- [ ] \(priorityEmoji) \(action.task)"
                
                if let assignee = action.assignee {
                    actionLine += " [@\(assignee)]"
                }
                
                if let deadline = action.deadline {
                    actionLine += " 📅 \(deadline)"
                }
                
                markdown += "\(actionLine)\n"
            }
            markdown += "\n"
        }
        
        // 标签
        if !structured.tags.isEmpty {
            markdown += "## 🏷️ 标签\n\n"
            markdown += structured.tags.map { "#\($0)" }.joined(separator: " ")
            markdown += "\n\n"
        }
        
        return markdown
    }
}

// MARK: - Helper Extension
extension Optional where Wrapped == Array<String> {
    var isEmptyOrNil: Bool {
        return self?.isEmpty ?? true
    }
}
