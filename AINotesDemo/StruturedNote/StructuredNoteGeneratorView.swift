//
//  StructuredNoteGeneratorView.swift
//  结构化笔记生成界面
//

import SwiftUI

struct StructuredNoteGeneratorView: View {
    let originalContent: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: StructuredNoteFormat = .outline
    @State private var isGenerating = false
    @State private var structuredNote: StructuredNoteResponse?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPreview = false
    
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
            }
            .navigationTitle("结构化笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
                
                if structuredNote != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("重新生成") {
                            structuredNote = nil
                        }
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
                    
                    Text("AI将帮你把笔记内容重新组织成更清晰的结构")
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
                StructuredNoteView(structured: structured, format: selectedFormat)
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

// MARK: - 推荐格式提示
struct FormatRecommendationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("格式推荐")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                RecommendationRow(
                    scenario: "会议记录",
                    format: "项目管理式",
                    reason: "决策、分工清晰"
                )
                
                RecommendationRow(
                    scenario: "学习笔记",
                    format: "大纲式/康奈尔",
                    reason: "知识层次分明"
                )
                
                RecommendationRow(
                    scenario: "头脑风暴",
                    format: "思维导图式",
                    reason: "想法发散关联"
                )
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RecommendationRow: View {
    let scenario: String
    let format: String
    let reason: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(scenario)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("→")
                        .foregroundColor(.secondary)
                    
                    Text(format)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
