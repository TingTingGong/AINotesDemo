//
//  StructuredNote.swift
//  结构化笔记数据模型
//

import Foundation

// MARK: - 结构化笔记响应
struct StructuredNoteResponse: Codable {
    let title: String
    let summary: String
    let keyPoints: [String]
    let sections: [NoteSection]
    let actionItems: [ActionItem]
    let tags: [String]
    let metadata: NoteMetadata
}

// MARK: - 笔记章节
struct NoteSection: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let subsections: [NoteSubsection]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, subsections
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
        self.subsections = try? container.decode([NoteSubsection].self, forKey: .subsections)
    }
    
    init(id: String = UUID().uuidString, title: String, content: String, subsections: [NoteSubsection]? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.subsections = subsections
    }
}

// MARK: - 子章节
struct NoteSubsection: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
    }
    
    init(id: String = UUID().uuidString, title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
    }
}

// MARK: - 行动项
struct ActionItem: Codable, Identifiable {
    let id: String
    let task: String
    let assignee: String?
    let deadline: String?
    let priority: String
    
    enum CodingKeys: String, CodingKey {
        case id, task, assignee, deadline, priority
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.task = try container.decode(String.self, forKey: .task)
        self.assignee = try? container.decode(String.self, forKey: .assignee)
        self.deadline = try? container.decode(String.self, forKey: .deadline)
        self.priority = (try? container.decode(String.self, forKey: .priority)) ?? "medium"
    }
    
    init(id: String = UUID().uuidString, task: String, assignee: String? = nil, deadline: String? = nil, priority: String = "medium") {
        self.id = id
        self.task = task
        self.assignee = assignee
        self.deadline = deadline
        self.priority = priority
    }
}

// MARK: - 笔记元数据
struct NoteMetadata: Codable {
    let type: String // meeting, learning, brainstorm, etc.
    let participants: [String]?
    let location: String?
    let duration: Int? // minutes
    
    init(type: String = "general", participants: [String]? = nil, location: String? = nil, duration: Int? = nil) {
        self.type = type
        self.participants = participants
        self.location = location
        self.duration = duration
    }
}

// MARK: - 结构化笔记格式类型
enum StructuredNoteFormat: String, CaseIterable {
    case outline = "大纲式"
    case cornell = "康奈尔"
    case mindmap = "思维导图"
    case project = "项目管理"
    case qa = "问答式"
    case timeline = "时间线"
    case analysis5W1H = "5W1H分析"
    
    var icon: String {
        switch self {
        case .outline: return "list.bullet.indent"
        case .cornell: return "rectangle.split.3x1"
        case .mindmap: return "point.3.connected.trianglepath.dotted"
        case .project: return "checklist"
        case .qa: return "bubble.left.and.bubble.right"
        case .timeline: return "timeline.selection"
        case .analysis5W1H: return "questionmark.circle"
        }
    }
    
    var description: String {
        switch self {
        case .outline: return "层次清晰，适合学习笔记"
        case .cornell: return "关键词+内容+总结，经典格式"
        case .mindmap: return "思维发散，适合头脑风暴"
        case .project: return "目标+任务+进度，适合项目"
        case .qa: return "问答对应，适合访谈"
        case .timeline: return "时序清晰，适合事件记录"
        case .analysis5W1H: return "全面系统，适合分析"
        }
    }
}
