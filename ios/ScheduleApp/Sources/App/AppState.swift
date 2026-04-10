import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isConfigured: Bool = false
    @Published var serverURL: String = ""
    @Published var syncSecret: String = ""
    @Published var deviceId: String = UUID().uuidString
    @Published var isOnline: Bool = true
    @Published var syncStatus: SyncStatus = .idle

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadConfiguration()
    }

    func loadConfiguration() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        syncSecret = KeychainHelper.getSyncSecret() ?? ""
        isConfigured = !serverURL.isEmpty && !syncSecret.isEmpty
    }

    func saveConfiguration(serverURL: String, syncSecret: String) {
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        try? KeychainHelper.saveSyncSecret(syncSecret)
        self.serverURL = serverURL
        self.syncSecret = syncSecret
        isConfigured = true
    }

    func checkConnection() async {
        guard !serverURL.isEmpty else {
            isOnline = false
            return
        }

        do {
            let pong = try await APIService.shared.ping()
            isOnline = pong.status == "ok"
        } catch {
            isOnline = false
        }
    }
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case failed(String)
}
