import SwiftUI

@main
struct JianshengjilyWatchApp: App {
    @StateObject private var connectivity = WatchRecordService.shared

    var body: some Scene {
        WindowGroup {
            WatchRecordView()
                .environmentObject(connectivity)
        }
    }
}
