import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var showingMicPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                statusBar

                // Main content
                if case .processing = viewModel.chatState {
                    processingView
                } else if case .error(let message) = viewModel.chatState {
                    errorView(message)
                } else {
                    idleView
                }

                Spacer()

                // Toast view
                if case .toast = viewModel.chatState {
                    toastView
                }

                // Input area
                inputArea
            }
            .navigationTitle("AI日程助手")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("需要麦克风权限", isPresented: $showingMicPermissionAlert) {
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在设置中开启麦克风权限以使用语音输入")
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private var statusColor: Color {
        switch viewModel.chatState {
        case .idle: return .gray
        case .listening: return .red
        case .processing: return .orange
        case .showingOptions: return .green
        case .toast: return .green
        case .error: return .red
        }
    }

    private var statusText: String {
        switch viewModel.chatState {
        case .idle: return "准备就绪"
        case .listening: return "正在聆听..."
        case .processing: return "正在理解..."
        case .showingOptions: return "已生成日程选项"
        case .toast: return viewModel.toastMessage
        case .error(let msg): return "错误: \(msg)"
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))

            Text("说出你的日程安排")
                .font(.title2)
                .fontWeight(.medium)

            Text("例如：\"明天下午三点开会\"")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("正在分析你的日程...")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("出错了")
                .font(.title2)
                .fontWeight(.medium)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("重试") {
                viewModel.dismissOptions()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toast View

    private var toastView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.toastMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if !viewModel.toastSchedules.isEmpty {
                        Text(viewModel.toastSchedules.map { $0.title }.joined(separator: "、"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button("撤销") {
                    viewModel.undoToast()
                }
                .font(.subheadline)
                .foregroundColor(.red)

                Button("详情") {
                    viewModel.dismissToast(action: .viewDetails)
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: viewModel.chatState)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 12) {
            // Follow-up question
            if let question = viewModel.followUpQuestion {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.blue)
                    Text(question)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Text input
            HStack(spacing: 12) {
                TextField("输入或说出日程安排...", text: $viewModel.userInput)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.chatState == .processing)

                // Mic button
                Button {
                    Task {
                        let authorized = await viewModel.speechService.requestAuthorization()
                        if authorized {
                            viewModel.toggleRecording()
                        } else {
                            showingMicPermissionAlert = true
                        }
                    }
                } label: {
                    Image(systemName: viewModel.speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(viewModel.speechService.isRecording ? .red : .blue)
                }
                .disabled(viewModel.chatState == .processing)

                // Send button
                Button {
                    Task {
                        await viewModel.submitInput()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                .disabled(viewModel.userInput.isEmpty || viewModel.chatState == .processing)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Option Card

struct OptionCard: View {
    let option: LLMOptions
    let index: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(index).")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(option.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(formatTime(option.startTime))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let endTime = option.endTime {
                        Text(" - \(formatTime(endTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let aiReasoning = option.aiReasoning {
                    Text(aiReasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
}
