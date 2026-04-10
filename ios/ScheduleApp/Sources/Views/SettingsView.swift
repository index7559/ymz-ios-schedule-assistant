import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var serverURL = ""
    @State private var syncSecret = ""
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var showTestSuccess = false

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

                // Server Configuration Section
                Section {
                    TextField("服务器地址", text: $serverURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)

                    SecureField("同步密钥 (SYNC_SECRET)", text: $syncSecret)
                        .textContentType(.password)
                } header: {
                    Text("后端服务器配置")
                } footer: {
                    Text("服务器地址格式: https://your-ngrok-url.ngrok-free.app")
                }

                // Connection Status Section
                Section {
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        HStack {
                            Text("测试连接")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else if showTestSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .disabled(isTesting || serverURL.isEmpty || syncSecret.isEmpty)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("成功") ? .green : .red)
                    }
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
                    .disabled(serverURL.isEmpty || syncSecret.isEmpty || apiKey.isEmpty)
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }

    private func loadCurrentSettings() {
        serverURL = appState.serverURL
        syncSecret = appState.syncSecret
        apiKey = KeychainHelper.getAPIKey() ?? ""
    }

    private func saveSettings() {
        // Save API Key
        do {
            try KeychainHelper.saveAPIKey(apiKey)
        } catch {
            print("Failed to save API Key: \(error)")
        }

        // Save server config
        appState.saveConfiguration(serverURL: serverURL, syncSecret: syncSecret)

        // Test connection
        Task {
            await testConnection()
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil
        showTestSuccess = false

        do {
            // Temporarily save settings for testing
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
            try? KeychainHelper.saveSyncSecret(syncSecret)

            // Try ping
            let pong = try await APIService.shared.ping()
            if pong.status == "ok" {
                testResult = "连接成功！"
                showTestSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if appState.isConfigured {
                        dismiss()
                    }
                }
            } else {
                testResult = "服务器响应异常"
            }
        } catch {
            testResult = "连接失败: \(error.localizedDescription)"
        }

        isTesting = false
    }
}
