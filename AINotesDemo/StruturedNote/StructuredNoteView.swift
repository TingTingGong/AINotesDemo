//
//  StructuredNoteView.swift
//  结构化笔记展示界面
//
//  Created by 宫廷 on 2026/1/30.
//

import SwiftUI

struct StructuredNoteView: View {
    let structured: StructuredNoteResponse
    let format: StructuredNoteFormat
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题
                Text(structured.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                // 元数据
                if hasMetadata {
                    metadataSection
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Divider()
                
                // 摘要
                summarySection
                
                // 关键要点
                if !structured.keyPoints.isEmpty {
                    keyPointsSection
                }
                
                Divider()
                
                // 详细内容
                contentSections
                
                // 行动项
                if !structured.actionItems.isEmpty {
                    actionItemsSection
                }
                
                // 标签
                if !structured.tags.isEmpty {
                    tagsSection
                }
            }
            .padding()
        }
        .navigationTitle("结构化笔记")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 元数据部分
    private var hasMetadata: Bool {
        !(structured.metadata.participants?.isEmpty ?? true) ||
        structured.metadata.location != nil ||
        structured.metadata.duration != nil
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("会议信息")
                    .font(.headline)
            }
            
            if let participants = structured.metadata.participants, !participants.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("参会人员：\(participants.joined(separator: ", "))")
                        .font(.subheadline)
                }
            }
            
            if let location = structured.metadata.location {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("地点：\(location)")
                        .font(.subheadline)
                }
            }
            
            if let duration = structured.metadata.duration {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("时长：\(duration)分钟")
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - 摘要部分
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("核心摘要")
                    .font(.headline)
            }
            
            Text(structured.summary)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
        }
    }
    
    // MARK: - 关键要点部分
    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                Text("关键要点")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(structured.keyPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text(point)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 内容章节
    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                Text("详细内容")
                    .font(.headline)
            }
            
            ForEach(structured.sections) { section in
                SectionCard(
                    section: section,
                    isExpanded: expandedSections.contains(section.id),
                    onToggle: {
                        if expandedSections.contains(section.id) {
                            expandedSections.remove(section.id)
                        } else {
                            expandedSections.insert(section.id)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - 行动项部分
    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.red)
                Text("行动项")
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                ForEach(structured.actionItems) { action in
                    ActionItemCard(action: action)
                }
            }
        }
    }
    
    // MARK: - 标签部分
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.purple)
                Text("标签")
                    .font(.headline)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(structured.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(16)
                }
            }
        }
    }
}

// MARK: - 章节卡片
struct SectionCard: View {
    let section: NoteSection
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 章节标题（可折叠）
            Button(action: onToggle) {
                HStack {
                    Text(section.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                // 章节内容
                Text(section.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // 子章节
                if let subsections = section.subsections {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(subsections) { subsection in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(subsection.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(subsection.content)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 行动项卡片
struct ActionItemCard: View {
    let action: ActionItem
    
    private var priorityColor: Color {
        switch action.priority {
        case "high": return .red
        case "low": return .green
        default: return .orange
        }
    }
    
    private var priorityIcon: String {
        switch action.priority {
        case "high": return "exclamationmark.3"
        case "low": return "minus"
        default: return "equal"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 优先级图标
            Image(systemName: priorityIcon)
                .foregroundColor(priorityColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                // 任务描述
                Text(action.task)
                    .font(.body)
                
                // 负责人和截止日期
                HStack(spacing: 12) {
                    if let assignee = action.assignee {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(assignee)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if let deadline = action.deadline {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(deadline)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(priorityColor.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(priorityColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - FlowLayout 自定义布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
