//
//  YouTubeInputView.swift
//  YouTube视频链接输入和处理
//
//  Created by 宫廷 on 2026/1/27.
//

import SwiftUI
import SwiftData

struct YouTubeInputView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    
    @State private var youtubeURL = ""
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 图标和说明
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("从YouTube导入")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("粘贴YouTube视频链接，我们会自动提取音频并转录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("YouTube链接")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("https://www.youtube.com/watch?v=...", text: $youtubeURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                .padding(.horizontal, 20)
                
                // 提示信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("支持的格式")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("• 标准YouTube链接")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• YouTube短链接 (youtu.be)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("不支持未列出的视频")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 处理按钮
                Button(action: processYouTubeVideo) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("导入并转录")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValidURL ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!isValidURL || isProcessing)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("YouTube导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
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
    
    // 验证URL
    private var isValidURL: Bool {
        guard !youtubeURL.isEmpty else { return false }
        
        let patterns = [
            "youtube.com/watch?v=",
            "youtu.be/",
            "youtube.com/shorts/"
        ]
        
        return patterns.contains { youtubeURL.contains($0) }
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
    
    // 处理YouTube视频
    private func processYouTubeVideo() {
        Task {
            await processVideo()
        }
    }
    
    private func processVideo() async {
        await MainActor.run {
            isProcessing = true
            processingStep = "正在检查视频..."
        }
        
        do {
            // 1. 提取视频ID
            guard let videoID = extractVideoID(from: youtubeURL) else {
                throw YouTubeError.invalidURL
            }
            
            // 2. 检查视频可访问性
            await MainActor.run {
                processingStep = "正在验证视频..."
            }
            
            let isAccessible = try await checkVideoAccessibility(videoID: videoID)
            if !isAccessible {
                throw YouTubeError.unlistedVideo
            }
            
            // 3. 下载音频
            await MainActor.run {
                processingStep = "正在下载音频..."
            }
            
            let audioURL = try await downloadYouTubeAudio(videoID: videoID)
            
            // 4. 转录音频
            await MainActor.run {
                processingStep = "正在转录音频..."
            }
            
            let transcription = try await AIService.shared.transcribeAudio(fileURL: audioURL)
            
            // 5. 生成摘要
            await MainActor.run {
                processingStep = "正在生成摘要..."
            }
            
            let aISummaryResult = try await AIService.shared.generateSummary(content: transcription)
            
            // 6. 保存笔记
            await MainActor.run {
                let title = "YouTube: " + (extractVideoTitle(from: transcription) ?? "视频笔记")
                let note = Note(
                    title: title,
                    content: transcription,
                    summary: aISummaryResult.summary,
                    tags: aISummaryResult.tags,
                    audioURL: "youtube_\(videoID)"
                )
                modelContext.insert(note)
                
                isProcessing = false
                dismiss()
            }
            
        } catch YouTubeError.invalidURL {
            await MainActor.run {
                isProcessing = false
                errorMessage = "无效的YouTube链接"
                showError = true
            }
        } catch YouTubeError.unlistedVideo {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Unlisted videos aren't supported\n\n不支持未列出的视频，请确保视频是公开的。"
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
    
    // 提取视频ID
    private func extractVideoID(from urlString: String) -> String? {
        // youtube.com/watch?v=VIDEO_ID
        if let range = urlString.range(of: "watch\\?v=([a-zA-Z0-9_-]+)", options: .regularExpression) {
            let matched = String(urlString[range])
            return matched.replacingOccurrences(of: "watch?v=", with: "")
        }
        
        // youtu.be/VIDEO_ID
        if let range = urlString.range(of: "youtu\\.be/([a-zA-Z0-9_-]+)", options: .regularExpression) {
            let matched = String(urlString[range])
            return matched.replacingOccurrences(of: "youtu.be/", with: "")
        }
        
        // youtube.com/shorts/VIDEO_ID
        if let range = urlString.range(of: "shorts/([a-zA-Z0-9_-]+)", options: .regularExpression) {
            let matched = String(urlString[range])
            return matched.replacingOccurrences(of: "shorts/", with: "")
        }
        
        return nil
    }
    
    // 检查视频可访问性
    private func checkVideoAccessibility(videoID: String) async throws -> Bool {
        // 使用YouTube的oEmbed API检查视频是否可访问
        let urlString = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=\(videoID)&format=json"
        
        guard let url = URL(string: urlString) else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            // 如果返回200，视频是公开的或未列出的
            // 如果返回401/403/404，视频不可访问或是私密的
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 404 {
                return false
            }
            
            // 检查返回的JSON是否包含视频信息
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 如果有title，说明视频可访问
                return json["title"] != nil
            }
            
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }
    
    // 下载YouTube音频
    private func downloadYouTubeAudio(videoID: String) async throws -> URL {
        // 注意：实际实现需要使用yt-dlp或类似工具
        // 这里提供一个模拟实现框架
        
        // 方案1: 使用后端API
        // 你需要搭建一个后端服务来调用yt-dlp
        let apiURL = "YOUR_BACKEND_API/download?videoId=\(videoID)"
        
        guard let url = URL(string: apiURL) else {
            throw YouTubeError.downloadFailed
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YouTubeError.downloadFailed
        }
        
        // 保存音频文件
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("youtube_\(videoID).m4a")
        try data.write(to: audioURL)
        
        return audioURL
        
        // 方案2: 使用第三方服务
        // 可以使用一些YouTube下载服务的API
        // 但需要注意版权和服务条款
    }
    
    // 提取视频标题
    private func extractVideoTitle(from content: String) -> String? {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if words.count > 5 {
            return words.prefix(5).joined(separator: " ") + "..."
        } else if !words.isEmpty {
            return words.joined(separator: " ")
        }
        
        return nil
    }
}

// MARK: - YouTube错误类型
enum YouTubeError: LocalizedError {
    case invalidURL
    case unlistedVideo
    case downloadFailed
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的YouTube链接"
        case .unlistedVideo:
            return "Unlisted videos aren't supported"
        case .downloadFailed:
            return "下载失败"
        case .processingFailed:
            return "处理失败"
        }
    }
}
