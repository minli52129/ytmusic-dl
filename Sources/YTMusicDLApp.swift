import SwiftUI

@main
struct YTMusicDLApp: App {
    @StateObject private var manager = DownloadManager()

    var body: some Scene {
        WindowGroup("YTMusicDL") {
            MainView()
                .environmentObject(manager)
                .frame(minWidth: 780, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
    }
}
