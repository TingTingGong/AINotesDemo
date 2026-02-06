//
//  StructuredNoteGeneratorView.swift
//  结构化笔记生成界面
//
//  Created by 宫廷 on 2026/1/30.
//

import SwiftUI
import SwiftData

struct StructuredNoteGeneratorView: View {
    let originalContent: String
    let modelContext: ModelContext
    let onNoteSaved: ((Note) -> Void)? // 保存成功后的回调
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: StructuredNoteFormat = .outline
    @State private var isGenerating = false
    @State private var structuredNote: StructuredNoteResponse?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if structuredNote == nil {
                    formatSelectionView
                } else {
                    previewView
                }
                
                if isGenerating {
                    generatingOverlay
                }
                
                if isSaving {
                    savingOverlay
                }
            }
            .navigationTitle("结构化笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isGenerating || isSaving)
                }
                
                if structuredNote != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: saveStructuredNote) {
                                Label("保存笔记", systemImage: "square.and.arrow.down")
                            }
                            
                            Button(action: { structuredNote = nil }) {
                                Label("重新生成", systemImage: "arrow.clockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 格式选择视图
    private var formatSelectionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 说明
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("选择笔记格式")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("AI将会把笔记内容重新组织成更清晰的结构")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // 格式选项
                VStack(spacing: 12) {
                    ForEach(StructuredNoteFormat.allCases, id: \.self) { format in
                        FormatOptionCard(
                            format: format,
                            isSelected: selectedFormat == format
                        ) {
                            selectedFormat = format
                        }
                    }
                }
                .padding(.horizontal)
                
                // 生成按钮
                Button(action: generateStructuredNote) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("生成结构化笔记")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - 预览视图
    private var previewView: some View {
        Group {
            if let structured = structuredNote {
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部保存提示
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("预览生成结果，点击右上角保存")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        
                        // 结构化笔记内容
                        StructuredNoteContentView(
                            structured: structured,
                            format: selectedFormat
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - 生成中遮罩
    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("AI正在整理笔记...")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Text("识别关键信息并重新组织结构")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    // MARK: - 保存中遮罩
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("正在保存...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    // MARK: - 生成结构化笔记
    private func generateStructuredNote() {
        Task {
            await performGeneration()
        }
    }
    
    private func performGeneration() async {
        await MainActor.run {
            isGenerating = true
        }
        
        do {
            let result = try await StructuredNoteService.shared.generateStructuredNote(
                content: originalContent,
                format: selectedFormat
            )
            
            await MainActor.run {
                structuredNote = result
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
                errorMessage = "生成失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - 保存结构化笔记
    private func saveStructuredNote() {
        guard let structured = structuredNote else { return }
        
        Task {
            await performSave(structured: structured)
        }
    }
    
    private func performSave(structured: StructuredNoteResponse) async {
        await MainActor.run {
            isSaving = true
        }
        
        // 创建新的笔记对象
        let note = Note(
            title: structured.title,
            content: originalContent, // 保留原始内容
            summary: structured.summary,
            tags: structured.tags
        )
        
        // 设置结构化数据
        note.setStructuredNote(structured, format: selectedFormat)
        
        // 保存到数据库
        modelContext.insert(note)
        
        do {
            try modelContext.save()
            
            await MainActor.run {
                isSaving = false
                onNoteSaved?(note)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "保存失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - 格式选项卡片
struct FormatOptionCard: View {
    let format: StructuredNoteFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: format.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .clipShape(Circle())
                
                // 文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(format.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 结构化笔记内容视图（用于预览）
struct StructuredNoteContentView: View {
    let structured: StructuredNoteResponse
    let format: StructuredNoteFormat
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            Text(structured.title)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top)
            
            // 元数据
            if hasMetadata {
                metadataSection
                    .padding(.horizontal)
            }
            
            Divider()
            
            // 摘要
            summarySection
                .padding(.horizontal)
            
            // 关键要点
            if !structured.keyPoints.isEmpty {
                keyPointsSection
                    .padding(.horizontal)
            }
            
            Divider()
            
            // 详细内容
            contentSections
                .padding(.horizontal)
            
            // 行动项
            if !structured.actionItems.isEmpty {
                actionItemsSection
                    .padding(.horizontal)
            }
            
            // 标签
            if !structured.tags.isEmpty {
                tagsSection
                    .padding(.horizontal)
            }
        }
        .padding(.bottom)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
