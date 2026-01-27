//
//  AINotesDemoApp.swift
//  AINotesDemo
//
//  核心功能演示版本
//  包含：录音、转录、AI摘要、笔记管理
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
    @State private var showingRecorder = false
    @State private var selectedNote: Note?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 笔记列表
                if notes.isEmpty {
                    emptyStateView
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
            .sheet(isPresented: $showingRecorder) {
                RecordingView(modelContext: modelContext)
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note, modelContext: modelContext)
            }
        }
    }
    
    // 空状态视图
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
    
    // 笔记列表
    private var notesList: some View {
        List {
            ForEach(notes) { note in
                NoteRowView(note: note)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNote = note
                    }
            }
            .onDelete(perform: deleteNotes)
        }
        .listStyle(.insetGrouped)
    }
    
    // 录音按钮
    private var recordButton: some View {
        Button(action: {
            showingRecorder = true
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
    
    // 删除笔记
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(notes[index])
        }
    }
}

// MARK: - 笔记行视图
struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            
            if let summary = note.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(note.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(note.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

