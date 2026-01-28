//
//  RecordingView.swift
//  录音界面 - 包含录音、转录、AI处理
//
//  Created by 宫廷 on 2026/1/27.
//

import SwiftUI
import AVFoundation
import SwiftData
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var audioURL: URL?
    private var levelTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        audioURL = audioFilename
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            
            // 开始计时
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingTime += 0.1
                self?.audioRecorder?.updateMeters()
                if let level = self?.audioRecorder?.averagePower(forChannel: 0) {
                    // 转换到0-1范围，-60dB到0dB
                    let normalized = max(0.0, min(1.0, 1.0 + level / 60.0))
                    self?.audioLevel = Float(normalized)
                }
            }
        } catch {
            print("录音失败: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        return audioURL
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        timer?.invalidate()
        isRecording = false
    }
    
    func resumeRecording() {
        audioRecorder?.record()
        isRecording = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingTime += 0.1
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorder()
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    let modelContext: ModelContext
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // 音频可视化
                    audioVisualization
                    
                    // 计时器
                    Text(recorder.formatTime(recorder.recordingTime))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    // 录音状态
                    Text(recorder.isRecording ? "正在录音..." : "已暂停")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 控制按钮
                    HStack(spacing: 60) {
                        // 取消按钮
                        Button(action: {
                            if recorder.isRecording {
                                _ = recorder.stopRecording()
                            }
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        
                        // 暂停/继续按钮
                        if recorder.recordingTime > 0 {
                            Button(action: {
                                if recorder.isRecording {
                                    recorder.pauseRecording()
                                } else {
                                    recorder.resumeRecording()
                                }
                            }) {
                                Image(systemName: recorder.isRecording ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                            }
                        }
                        
                        // 完成按钮
                        if recorder.recordingTime > 0 {
                            Button(action: {
                                finishRecording()
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.green)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
                
                // 处理中遮罩
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("录音")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                recorder.startRecording()
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // 音频可视化
    private var audioVisualization: some View {
        HStack(spacing: 4) {
            ForEach(0..<40, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3, height: CGFloat.random(in: 20...100) * CGFloat(recorder.audioLevel + 0.1))
                    .animation(.easeInOut(duration: 0.1), value: recorder.audioLevel)
            }
        }
        .frame(height: 120)
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
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    // 完成录音并处理
    private func finishRecording() {
        guard let audioURL = recorder.stopRecording() else {
            errorMessage = "录音文件保存失败"
            showError = true
            return
        }
        
        Task {
            await processRecording(audioURL: audioURL)
        }
    }
    
    // 处理录音：转录 + AI摘要
    private func processRecording(audioURL: URL) async {
        await MainActor.run {
            isProcessing = true
            processingStep = "正在转录音频..."
        }
        
        do {
            // 1. 转录音频
            let transcription = try await AIService.shared.transcribeAudio(fileURL: audioURL)
            
            await MainActor.run {
                processingStep = "正在生成摘要..."
            }
            
            // 2. 生成标题和摘要和标签
            let aISummaryResult = try await AIService.shared.generateSummary(content: transcription)
            
            // 3. 保存笔记
            await MainActor.run {
                let note = Note(
                    title: aISummaryResult.title,
                    content: transcription,
                    summary: aISummaryResult.summary,
                    tags: aISummaryResult.tags,
                    audioURL: audioURL.lastPathComponent
                )
                modelContext.insert(note)
                
                isProcessing = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    // 生成标题
//    private func generateTitle(from content: String) -> String {
//        let words = content.components(separatedBy: .whitespacesAndNewlines)
//            .filter { !$0.isEmpty }
//        
//        if words.count > 5 {
//            return words.prefix(5).joined(separator: " ") + "..."
//        } else if !words.isEmpty {
//            return words.joined(separator: " ")
//        } else {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "yyyy-MM-dd HH:mm"
//            return "笔记 \(formatter.string(from: Date()))"
//        }
//    }
}
