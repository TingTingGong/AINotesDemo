//
//  NoteDetailView.swift
//  笔记详情页 - 查看和编辑笔记
//
//  Created by 宫廷 on 2026/1/27.
//

import SwiftUI
import SwiftData

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var note: Note
    let modelContext: ModelContext
    
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedContent: String = ""
    @State private var editedSummary: String = ""
    @State private var showDeleteAlert = false
    @State private var showStructuredNoteGenerator = false
    
    @State private var showShare = false
    @State private var shareText: String?
    
    // 结构化笔记相关
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if note.isStructured, let structured = note.getStructuredNote(),
                   let formatString = note.structuredFormat,
                   let format = StructuredNoteFormat(rawValue: formatString) {
                    // 展示结构化笔记
                    structuredNoteView(structured: structured, format: format)
                } else {
                    // 展示普通笔记
                    regularNoteView
                }
            }
            .navigationTitle(note.isStructured ? "结构化笔记" : "笔记详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !note.isStructured {
                            Button(action: {
                                isEditing.toggle()
                                if isEditing {
                                    editedTitle = note.title
                                    editedContent = note.content
                                    editedSummary = note.summary ?? ""
                                }
                            }) {
                                Label(isEditing ? "完成编辑" : "编辑", systemImage: isEditing ? "checkmark" : "pencil")
                            }
                            
                            Button(action: {
                                showStructuredNoteGenerator = true
                            }) {
                                Label("生成结构化笔记", systemImage: "wand.and.stars")
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            showDeleteAlert = true
                        }) {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        Button {
                            shareText = buildShareText()
                        } label: {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("删除笔记", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteNote()
                }
            } message: {
                Text("确定要删除这条笔记吗？此操作无法撤销。")
            }
            .sheet(isPresented: $showStructuredNoteGenerator) {
                StructuredNoteGeneratorView(
                    originalContent: note.content,
                    modelContext: modelContext,
                    onNoteSaved: { newNote in
                        // 删除旧笔记，使用新的结构化笔记
                        modelContext.delete(note)
                        dismiss()
                    }
                )
            }
        }
        .sheet(item: $shareText) { text in
            ActivityView(activityItems: [text])
        }
    }
    
    // MARK: - 结构化笔记视图
    private func structuredNoteView(structured: StructuredNoteResponse, format: StructuredNoteFormat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 格式标记
            HStack {
                Image(systemName: format.icon)
                    .foregroundColor(.blue)
                Text(format.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // 标题
            Text(structured.title)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // 元数据
            if hasMetadata(structured.metadata) {
                metadataSection(metadata: structured.metadata)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // 摘要
            summarySection(summary: structured.summary)
                .padding(.horizontal)
            
            // 关键要点
            if !structured.keyPoints.isEmpty {
                keyPointsSection(points: structured.keyPoints)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // 详细内容
            contentSections(sections: structured.sections)
                .padding(.horizontal)
            
            // 行动项
            if !structured.actionItems.isEmpty {
                actionItemsSection(actions: structured.actionItems)
                    .padding(.horizontal)
            }
            
            // 标签
            if !structured.tags.isEmpty {
                tagsSection(tags: structured.tags)
                    .padding(.horizontal)
            }
            
            // 元数据（时间等）
            metadataFooter
                .padding(.horizontal)
                .padding(.bottom)
        }
    }
    
    // MARK: - 普通笔记视图
    private var regularNoteView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题部分
            titleSection
            
            Divider()
            
            // 摘要部分
            if let summary = note.summary, !summary.isEmpty {
                regularSummarySection(summary: summary)
                Divider()
            }
            
            // 标签部分
            if !note.tags.isEmpty {
                regularTagsSection
                Divider()
            }
            
            // 正文部分
            contentSection
            
            // 元数据
            metadataFooter
        }
        .padding()
    }
    
    // MARK: - 结构化笔记组件
    
    private func hasMetadata(_ metadata: NoteMetadata) -> Bool {
        !(metadata.participants?.isEmpty ?? true) ||
        metadata.location != nil ||
        metadata.duration != nil
    }
    
    private func metadataSection(metadata: NoteMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("会议信息")
                    .font(.headline)
            }
            
            if let participants = metadata.participants, !participants.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("参会人员：\(participants.joined(separator: ", "))")
                        .font(.subheadline)
                }
            }
            
            if let location = metadata.location {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("地点：\(location)")
                        .font(.subheadline)
                }
            }
            
            if let duration = metadata.duration {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text("时长：\(duration)分钟")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func summarySection(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("核心摘要")
                    .font(.headline)
            }
            
            Text(summary)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
        }
    }
    
    private func keyPointsSection(points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                Text("关键要点")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
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
    
    private func contentSections(sections: [NoteSection]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                Text("详细内容")
                    .font(.headline)
            }
            
            ForEach(sections) { section in
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
    
    private func actionItemsSection(actions: [ActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.red)
                Text("行动项")
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                ForEach(actions) { action in
                    ActionItemCard(action: action)
                }
            }
        }
    }
    
    private func tagsSection(tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.purple)
                Text("标签")
                    .font(.headline)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
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
    
    // MARK: - 普通笔记组件
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标题")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isEditing {
                TextField("标题", text: $editedTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: editedTitle) { _, newValue in
                        note.title = newValue
                    }
            } else {
                Text(note.title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
    }
    
    private func regularSummarySection(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("AI 摘要")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isEditing {
                TextEditor(text: $editedSummary)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .onChange(of: editedSummary) { _, newValue in
                        note.summary = newValue
                    }
            } else {
                Text(summary)
                    .font(.body)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
            }
        }
    }
    
    private var regularTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.caption)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(note.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                }
            }
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("内容")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isEditing {
                TextEditor(text: $editedContent)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .onChange(of: editedContent) { _, newValue in
                        note.content = newValue
                    }
            } else {
                Text(note.content)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
    }
    
    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(note.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(note.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if note.audioURL != nil {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                    Text("包含录音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("字数：\(note.content.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
    
    // MARK: - 操作方法
    private func deleteNote() {
        modelContext.delete(note)
        dismiss()
    }
    
    private func buildShareText() -> String {
        if note.isStructured, let structured = note.getStructuredNote() {
            // 分享结构化笔记
            return StructuredNoteService.shared.convertToMarkdown(
                structured: structured,
                format: StructuredNoteFormat(rawValue: note.structuredFormat ?? "") ?? .outline
            )
        } else {
            // 分享普通笔记
            return """
            \(note.title)

            \(note.summary ?? "")

            \(note.content)

            ---
            Created at \(note.timestamp.formatted())
            """
        }
    }
}
