import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var scheduleViewModel = ScheduleViewModel()

    @State private var selectedTab = 0
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView(viewModel: chatViewModel)
                .tabItem {
                    Label("创建", systemImage: "plus.circle.fill")
                }
                .tag(0)

            ScheduleListView(viewModel: scheduleViewModel)
                .tabItem {
                    Label("日程", systemImage: "list.bullet")
                }
                .tag(1)

            MonthView(viewModel: scheduleViewModel)
                .tabItem {
                    Label("日历", systemImage: "calendar")
                }
                .tag(2)
        }
        .onAppear {
            if !appState.isConfigured {
                showingSettings = true
            }
            scheduleViewModel.loadSchedules()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .onChange(of: chatViewModel.scheduleCreated) { created in
            if created {
                scheduleViewModel.loadSchedules()
                chatViewModel.resetScheduleCreated()
            }
        }
        .onChange(of: chatViewModel.dismissAction) { action in
            if action == .viewDetails {
                selectedTab = 2  // Switch to calendar tab
            }
        }
    }
}
