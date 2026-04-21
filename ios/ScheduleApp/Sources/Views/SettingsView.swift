import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                // API Configuration Section
                Section {
                    SecureField("API Key (火山方舟)", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                } header: {
                    Text("LLM API 配置")
                } footer: {
                    Text("输入你的火山方舟 API Key，用于 AI 语义理解")
                }

                // App Info Section
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("设备ID")
                        Spacer()
                        Text(appState.deviceId.prefix(8) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if appState.isConfigured {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private func loadCurrentSettings() {
        apiKey = KeychainHelper.getAPIKey() ?? ""
    }

    private func saveSettings() {
        // Save API Key
        do {
            try KeychainHelper.saveAPIKey(apiKey)
        } catch {
            print("Failed to save API Key: \(error)")
        }

        appState.saveConfiguration()
        dismiss()
    }
}
