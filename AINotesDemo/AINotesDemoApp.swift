//
//  AINotesDemoApp.swift
//  AINotesDemo
//
//  核心功能演示版本
//  包含：录音、转录、AI摘要、笔记管理，搜索
//  Created by 宫廷 on 2026/1/27.
//

import SwiftUI
import SwiftData

@main
struct AINotesDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)
    }
}

// MARK: - 主视图
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.timestamp, order: .reverse) private var notes: [Note]
    @State private var showingInputMethodSelection = false
    @State private var showingRecorder = false
    @State private var selectedNote: Note?
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 笔记列表
                if filteredNotes.isEmpty {
                    if searchText.isEmpty {
                        emptyStateView
                    } else {
                        searchEmptyView
                    }
                } else {
                    notesList
                }
                
                // 浮动录音按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        recordButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("AI Notes")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索笔记标题、内容、标签"
            )
            .sheet(isPresented: $showingInputMethodSelection) {
                InputMethodSelectionView(modelContext: modelContext)
            }
            .sheet(isPresented: $showingRecorder) {
                RecordingView(modelContext: modelContext)
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note, modelContext: modelContext)
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))
            
            Text("还没有笔记")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("点击下方按钮开始录音")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 搜索空状态视图
    private var searchEmptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("未找到相关笔记")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("尝试其他关键词")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 笔记列表
    private var notesList: some View {
        List {
            ForEach(filteredNotes) { note in
                NoteListItemView(note: note)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNote = note
                    }
            }
            .onDelete(perform: deleteNotes)
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - 录音按钮
    private var recordButton: some View {
        Button(action: {
            showingInputMethodSelection = true
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 58, height: 58)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - 删除笔记
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredNotes[index])
        }
    }
    
    // MARK: - 过滤笔记（搜索功能）
    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                (note.summary?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}

// MARK: - 笔记列表项视图
struct NoteListItemView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行（包含结构化标识）
            HStack {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // 结构化笔记标识
                if note.isStructured {
                    HStack(spacing: 4) {
                        Image(systemName: formatIcon)
                            .font(.caption)
                        Text(formatName)
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // 摘要或内容预览
            if let summary = note.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 底部信息栏
            HStack {
                // 标签
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                        
                        // 最多显示2个标签
                        ForEach(note.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                        }
                        
                        // 如果标签超过2个，显示数量
                        if note.tags.count > 2 {
                            Text("+\(note.tags.count - 2)")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.purple)
                }
                
                Spacer()
                
                // 时间
                HStack(spacing: 4) {
                    Text(note.timestamp, style: .date)
                        .font(.caption)
                    Text(note.timestamp, style: .time)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                // 音频标识
                if note.audioURL != nil {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 格式化相关计算属性
    
    private var formatIcon: String {
        guard let formatString = note.structuredFormat,
              let format = StructuredNoteFormat(rawValue: formatString) else {
            return "doc.text"
        }
        return format.icon
    }
    
    private var formatName: String {
        guard let formatString = note.structuredFormat,
              let format = StructuredNoteFormat(rawValue: formatString) else {
            return "结构化"
        }
        return format.rawValue
    }
}

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, configurations: config)
    let context = container.mainContext
    
    // 示例数据
    let note1 = Note(
        title: "普通会议记录",
        content: "今天讨论了产品的下一步规划，包括功能优化和用户体验提升。团队一致认为应该优先处理用户反馈最多的问题。",
        summary: "讨论产品规划和用户体验优化",
        tags: ["会议", "产品"]
    )
    context.insert(note1)
    
    let note2 = Note(
        title: "项目进度追踪",
        content: "第一季度项目进展顺利...",
        summary: "Q1项目完成度达到85%，按计划推进",
        tags: ["项目", "进度", "重要"]
    )
    note2.isStructured = true
    note2.structuredFormat = StructuredNoteFormat.project.rawValue
    context.insert(note2)
    
    let note3 = Note(
        title: "学习笔记：SwiftUI 状态管理",
        content: "State、Binding、ObservableObject的使用场景...",
        summary: "深入理解SwiftUI的状态管理机制",
        tags: ["学习", "SwiftUI"],
        audioURL: "recording.m4a"
    )
    note3.isStructured = true
    note3.structuredFormat = StructuredNoteFormat.outline.rawValue
    context.insert(note3)
    
    return ContentView()
        .modelContainer(container)
}
