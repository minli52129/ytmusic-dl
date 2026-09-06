import SwiftUI

struct MainView: View {
    @EnvironmentObject var manager: DownloadManager

    var body: some View {
        TabView {
            QueueTabView()
                .tabItem { Label("下载", systemImage: "arrow.down.circle") }
            HistoryTabView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
            SettingsTabView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .onAppear { manager.prepareBinaries() }
    }
}
