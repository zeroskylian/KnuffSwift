import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        NSApplication.shared.applicationIconImage = icon
    }
}

@main
struct KnuffSwiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
