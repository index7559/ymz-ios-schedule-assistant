import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isConfigured: Bool = false
    @Published var deviceId: String = UUID().uuidString

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadConfiguration()
    }

    func loadConfiguration() {
        deviceId = UserDefaults.standard.string(forKey: "deviceId") ?? UUID().uuidString
        if deviceId.isEmpty {
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: "deviceId")
        }
        // isConfigured: app is ready if API key exists in Keychain
        isConfigured = KeychainHelper.getAPIKey() != nil
    }

    func saveConfiguration() {
        // API key is saved directly via KeychainHelper in SettingsView
        isConfigured = KeychainHelper.getAPIKey() != nil
    }
}
