//
//  InputMethodSelectionView.swift
//  输入方式选择 - 录音、YouTube、文件导入
//
//  Created by 宫廷 on 2026/1/27.
//

import SwiftUI
import SwiftData

struct InputMethodSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    
    @State private var showingRecorder = false
    @State private var showingYouTubeInput = false
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标题区域
                VStack(spacing: 8) {
                    Text("创建笔记")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("选择输入方式")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 30)
                .padding(.bottom, 30)
                
                // 选项列表
                VStack(spacing: 16) {
                    // 录音选项
                    InputMethodButton(
                        icon: "mic.circle.fill",
                        title: "New Record",
                        subtitle: "录制语音笔记",
                        color: .blue
                    ) {
                        showingRecorder = true
                    }
                    
                    // YouTube选项
                    InputMethodButton(
                        icon: "play.rectangle.fill",
                        title: "YouTube Video",
                        subtitle: "通过YouTube链接导入",
                        color: .red
                    ) {
                        showingYouTubeInput = true
                    }
                    
                    // 文件导入选项
                    InputMethodButton(
                        icon: "folder.circle.fill",
                        title: "Upload Voice Memo",
                        subtitle: "从文件中导入音频",
                        color: .green
                    ) {
                        showingFilePicker = true
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 取消按钮
                Button(action: {
                    dismiss()
                }) {
                    Text("取消")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingRecorder) {
                RecordingView(modelContext: modelContext)
            }
            .sheet(isPresented: $showingYouTubeInput) {
                YouTubeInputView(modelContext: modelContext)
            }
            .sheet(isPresented: $showingFilePicker) {
                FilePickerView(modelContext: modelContext)
            }
        }
    }
}

// MARK: - 输入方式按钮
struct InputMethodButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                // 文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
