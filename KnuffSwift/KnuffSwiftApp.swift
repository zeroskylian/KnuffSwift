import SwiftUI

@main
struct KnuffSwiftApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: KnuffDocument()) { configuration in
            ContentView(document: configuration.$document)
                .frame(minWidth: 720, minHeight: 620)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Link("Apple Push Notification documentation", destination: URL(string: "https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/generating_a_remote_notification")!)
            }
        }
    }
}
