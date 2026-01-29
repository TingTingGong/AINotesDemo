//
//  DocumentImportView.swift
//  文档导入并结构化功能
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

struct DocumentImportView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    
    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var extractedText = ""
    @State private var selectedFormat: StructuredNoteFormat = .outline
    @State private var structuredNote: StructuredNoteResponse?
    @State private var documentName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                if structuredNote == nil {
                    // 导入界面
                    importView
                } else {
                    // 结构化笔记预览
                    resultView
                }
                
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("导入文档")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
                
                if structuredNote != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            saveStructuredNote()
                        }
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentImportPicker(
                    onDocumentPicked: { url in
                        Task {
                            await processDocument(url: url)
                        }
                    }
                )
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 导入界面
    private var importView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 图标和说明
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("导入文档并结构化")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("上传文档，AI将自动提取内容并生成结构化笔记")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // 支持的格式
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("支持的格式")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        DocumentFormatRow(format: "PDF", description: "PDF文档（可提取文本）")
                        DocumentFormatRow(format: "DOCX", description: "Word文档")
                        DocumentFormatRow(format: "DOC", description: "旧版Word文档")
                        DocumentFormatRow(format: "TXT", description: "纯文本文件")
                        DocumentFormatRow(format: "MD", description: "Markdown文件")
                        DocumentFormatRow(format: "RTF", description: "富文本格式")
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // 文件大小限制
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("文件要求")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("• 最大文件大小: 10MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 最大字数: 约50,000字")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• PDF需要包含可提取的文本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // 格式选择
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.purple)
                        Text("选择结构化格式")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    // 简化的格式选择
                    VStack(spacing: 8) {
                        ForEach([StructuredNoteFormat.outline, .project, .qa, .analysis5W1H], id: \.self) { format in
                            FormatQuickSelectButton(
                                format: format,
                                isSelected: selectedFormat == format
                            ) {
                                selectedFormat = format
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 选择文件按钮
                Button(action: {
                    showDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("选择文档")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - 结果展示界面
    private var resultView: some View {
        VStack(spacing: 0) {
            // 文档名称
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text(documentName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            // 结构化笔记内容
            if let structured = structuredNote {
                StructuredNoteView(structured: structured, format: selectedFormat)
            }
        }
    }
    
    // MARK: - 处理中遮罩
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
    
    // MARK: - 处理文档
    private func processDocument(url: URL) async {
        await MainActor.run {
            isProcessing = true
            processingStep = "正在读取文档..."
            documentName = url.lastPathComponent
        }
        
        do {
            // 1. 检查文件访问权限
            guard url.startAccessingSecurityScopedResource() else {
                throw DocumentImportError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // 2. 检查文件大小
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
            let maxSize: UInt64 = 10 * 1024 * 1024 // 10MB
            
            if fileSize > maxSize {
                throw DocumentImportError.fileTooLarge
            }
            
            // 3. 提取文本内容
            await MainActor.run {
                processingStep = "正在提取文本内容..."
            }
            
            let text = try await extractText(from: url)
            
            if text.isEmpty {
                throw DocumentImportError.noTextContent
            }
            
            // 检查文本长度（约50,000字限制）
            if text.count > 50000 {
                throw DocumentImportError.textTooLong
            }
            
            await MainActor.run {
                extractedText = text
            }
            
            // 4. 生成结构化笔记
            await MainActor.run {
                processingStep = "AI正在整理文档结构..."
            }
            
            let structured = try await StructuredNoteService.shared.generateStructuredNote(
                content: text,
                format: selectedFormat
            )
            
            await MainActor.run {
                structuredNote = structured
                isProcessing = false
            }
            
        } catch DocumentImportError.accessDenied {
            await showErrorMessage("无法访问文件，请确保已授予权限")
        } catch DocumentImportError.fileTooLarge {
            await showErrorMessage("文件太大\n\n文件大小超过10MB限制，请选择较小的文件。")
        } catch DocumentImportError.unsupportedFormat {
            await showErrorMessage("不支持的文件格式\n\n请选择PDF、Word、TXT或Markdown文件。")
        } catch DocumentImportError.noTextContent {
            await showErrorMessage("无法提取文本内容\n\n文件可能是扫描版PDF或损坏的文档。")
        } catch DocumentImportError.textTooLong {
            await showErrorMessage("文档内容太长\n\n文档超过50,000字限制，请选择较短的文档。")
        } catch {
            await showErrorMessage("处理失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 提取文本内容
    private func extractText(from url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return try extractTextFromPDF(url: url)
        case "txt", "md":
            return try String(contentsOf: url, encoding: .utf8)
        case "rtf":
            return try extractTextFromRTF(url: url)
        case "docx", "doc":
            return try extractTextFromWord(url: url)
        default:
            throw DocumentImportError.unsupportedFormat
        }
    }
    
    // 从PDF提取文本
    private func extractTextFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentImportError.noTextContent
        }
        
        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }
            text += pageText + "\n\n"
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 从RTF提取文本
    private func extractTextFromRTF(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        
        if let attributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            return attributedString.string
        }
        
        throw DocumentImportError.noTextContent
    }
    
    // 从Word提取文本
    private func extractTextFromWord(url: URL) throws -> String {
        // 注意：iOS原生不支持直接读取.docx
        // 这里提供两个方案：
        
        // 方案1：使用第三方库（需要添加依赖）
        // 例如：ZIPFoundation 解压 .docx 然后解析 XML
        
        // 方案2：提示用户转换为PDF或TXT
        throw DocumentImportError.unsupportedFormat
        
        // 如果要实现完整的Word支持，可以：
        // 1. 使用第三方库如 ZIPFoundation
        // 2. 解压 .docx 文件（实际上是一个zip）
        // 3. 读取 word/document.xml
        // 4. 解析XML提取文本
    }
    
    // MARK: - 保存结构化笔记
    private func saveStructuredNote() {
        guard let structured = structuredNote else { return }
        
        // 创建笔记
        let note = Note(
            title: structured.title,
            content: extractedText,
            summary: structured.summary,
            tags: structured.tags
        )
        
        modelContext.insert(note)
        
        // 关闭视图
        dismiss()
    }
    
    // MARK: - 显示错误
    private func showErrorMessage(_ message: String) async {
        await MainActor.run {
            isProcessing = false
            errorMessage = message
            showError = true
        }
    }
}

// MARK: - 文档格式行
struct DocumentFormatRow: View {
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

// MARK: - 格式快速选择按钮
struct FormatQuickSelectButton: View {
    let format: StructuredNoteFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: format.icon)
                    .foregroundColor(isSelected ? .white : .purple)
                
                Text(format.rawValue)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(isSelected ? Color.purple : Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 文档选择器
struct DocumentImportPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            .pdf,
            .plainText,
            .text,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "md") ?? .text,
            UTType(filenameExtension: "rtf") ?? .rtf
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        
        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

// MARK: - 文档导入错误
enum DocumentImportError: LocalizedError {
    case accessDenied
    case fileTooLarge
    case unsupportedFormat
    case noTextContent
    case textTooLong
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "无法访问文件"
        case .fileTooLarge:
            return "文件太大"
        case .unsupportedFormat:
            return "不支持的文件格式"
        case .noTextContent:
            return "无法提取文本内容"
        case .textTooLong:
            return "文档内容太长"
        }
    }
}
