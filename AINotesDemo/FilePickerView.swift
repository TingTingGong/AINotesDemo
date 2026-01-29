//
//  FilePickerView.swift
//  文件选择器 - 从系统Files导入音频文件
//
//  Created by 宫廷 on 2026/1/28.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FilePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDocumentPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 图标和说明
                VStack(spacing: 12) {
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("导入音频文件")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("从Files应用中选择音频文件进行转录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // 支持的格式
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("支持的格式")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        FormatRow(format: "M4A", description: "iPhone录音格式")
                        FormatRow(format: "MP3", description: "常见音频格式")
                        FormatRow(format: "WAV", description: "无损音频格式")
                        FormatRow(format: "AAC", description: "高质量压缩格式")
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // 文件大小限制
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("文件要求")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("• 最大文件大小: 25MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 最大时长: 30分钟")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 建议清晰的语音录音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 选择文件按钮
                Button(action: {
                    showDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("选择文件")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("导入音频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(
                    onFilePicked: { url in
                        Task {
                            await processAudioFile(url: url)
                        }
                    }
                )
            }
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // 格式行
    private struct FormatRow: View {
        let format: String
        let description: String
        
        var body: some View {
            HStack {
                Text(format)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    // 处理中遮罩
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(processingStep)
                    .foregroundColor(.white)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    // 处理音频文件
    private func processAudioFile(url: URL) async {
        await MainActor.run {
            isProcessing = true
            processingStep = "正在加载文件..."
        }
        
        do {
            // 1. 验证文件
            guard url.startAccessingSecurityScopedResource() else {
                throw FileError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // 检查文件大小 (25MB限制)
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
            let maxSize: UInt64 = 25 * 1024 * 1024 // 25MB
            
            if fileSize > maxSize {
                throw FileError.fileTooLarge
            }
            
            // 2. 复制文件到临时目录
            await MainActor.run {
                processingStep = "正在准备文件..."
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent("imported_\(Date().timeIntervalSince1970)\(url.pathExtension.isEmpty ? ".m4a" : ".\(url.pathExtension)")")
            
            try FileManager.default.copyItem(at: url, to: tempFileURL)
            
            // 3. 验证音频文件
            let isValid = validateAudioFile(url: tempFileURL)
            if !isValid {
                throw FileError.invalidFormat
            }
            
            // 4. 转录音频
            await MainActor.run {
                processingStep = "正在转录音频..."
            }
            
            let transcription = try await AIService.shared.transcribeAudio(fileURL: tempFileURL)
            
            if transcription.isEmpty {
                throw FileError.noAudioContent
            }
            
            // 5. 生成摘要
            await MainActor.run {
                processingStep = "正在生成摘要..."
            }
            
            // 生成标题，摘要和标签
            let aISummaryResult = try await AIService.shared.generateSummary(content: transcription)
            
            // 6. 保存笔记
            await MainActor.run {
                let title = generateTitle(from: transcription)
                let note = Note(
                    title: title,
                    content: transcription,
                    summary: aISummaryResult.summary,
                    tags: aISummaryResult.tags,
                    audioURL: tempFileURL.lastPathComponent
                )
                modelContext.insert(note)
                
                isProcessing = false
                dismiss()
            }
            
        } catch FileError.accessDenied {
            await MainActor.run {
                isProcessing = false
                errorMessage = "无法访问文件，请确保已授予权限"
                showError = true
            }
        } catch FileError.fileTooLarge {
            await MainActor.run {
                isProcessing = false
                errorMessage = "文件太大\n\n文件大小超过25MB限制，请选择较小的文件。"
                showError = true
            }
        } catch FileError.invalidFormat {
            await MainActor.run {
                isProcessing = false
                errorMessage = "不支持的文件格式\n\n请选择M4A、MP3、WAV或AAC格式的音频文件。"
                showError = true
            }
        } catch FileError.noAudioContent {
            await MainActor.run {
                isProcessing = false
                errorMessage = "无法识别音频内容\n\n文件可能损坏或不包含可识别的语音。"
                showError = true
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "处理失败: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // 验证音频文件
    private func validateAudioFile(url: URL) -> Bool {
        let supportedExtensions = ["m4a", "mp3", "wav", "aac", "mp4", "m4v"]
        let fileExtension = url.pathExtension.lowercased()
        
        return supportedExtensions.contains(fileExtension)
    }
    
    // 生成标题
    private func generateTitle(from content: String) -> String {
        // 去除多余的空格
        let content = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果内容为空，返回当前时间
        if content.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return "笔记 \(formatter.string(from: Date()))"
        }
        
        // 中文文本按字符切割
        let words = Array(content)

        // 如果字符数量大于5，截取前5个字符并加上省略号
        if words.count > 5 {
            return String(words.prefix(5)) + "..."
        } else {
            return String(words)
        }
    }

//    private func generateTitle(from content: String, fileName: String) -> String {
//        // 尝试从内容生成标题
//        let words = content.components(separatedBy: .whitespacesAndNewlines)
//            .filter { !$0.isEmpty }
//        
//        if words.count > 5 {
//            return words.prefix(5).joined(separator: " ") + "..."
//        } else if !words.isEmpty {
//            return words.joined(separator: " ")
//        }
//        
//        // 如果内容为空，使用文件名
//        let nameWithoutExtension = fileName.components(separatedBy: ".").first ?? fileName
//        return nameWithoutExtension
//    }
}

// MARK: - 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let onFilePicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .audio,
            .mp3,
            .mpeg4Audio,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "wav") ?? .audio
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFilePicked: onFilePicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFilePicked: (URL) -> Void
        
        init(onFilePicked: @escaping (URL) -> Void) {
            self.onFilePicked = onFilePicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onFilePicked(url)
        }
    }
}

// MARK: - 文件错误类型
enum FileError: LocalizedError {
    case accessDenied
    case fileTooLarge
    case invalidFormat
    case noAudioContent
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "无法访问文件"
        case .fileTooLarge:
            return "文件太大"
        case .invalidFormat:
            return "不支持的文件格式"
        case .noAudioContent:
            return "无法识别音频内容"
        }
    }
}
