//
//  NoteDetailView.swift
//  笔记详情页 - 查看和编辑笔记
//
//  Created by 宫廷 on 2026/1/27.
//

import SwiftUI
import SwiftData

//让 String 可 Identifiable（一次性）
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
    
    @State private var showShare = false
    @State private var shareText: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题部分
                    titleSection
                    
                    Divider()
                    
                    // 摘要部分
                    if let summary = note.summary, !summary.isEmpty {
                        summarySection(summary: summary)
                        Divider()
                    }
                    
                    // 标签部分
                    if !note.tags.isEmpty {
                        tagsSection
                        Divider()
                    }
                    
                    // 正文部分
                    contentSection
                    
                    // 元数据
                    metadataSection
                }
                .padding()
            }
            .navigationTitle("笔记详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
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
        }.sheet(item: $shareText) { text in
            ActivityView(activityItems: [text])
        }
    }
    
    
    // MARK: - 标题部分
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
    
    // MARK: - 摘要部分
    private func summarySection(summary: String) -> some View {
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
    
    // MARK: - 标签部分
    private var tagsSection: some View {
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
    
    // MARK: - 正文部分
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
    
    private func generateTitle(from content: String) -> String {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if words.count > 5 {
            return words.prefix(5).joined(separator: " ") + "..."
        } else if !words.isEmpty {
            return words.joined(separator: " ")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return "笔记 \(formatter.string(from: Date()))"
        }
    }
    
    // MARK: - 元数据部分
    private var metadataSection: some View {
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
                    """
                    \(note.title)

                    \(note.summary ?? "")

                    \(note.content)

                    ---
                    Created at \(note.timestamp.formatted())
                    """
                }
}

// MARK: - FlowLayout 自定义布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
