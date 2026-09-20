# KnuffSwift

A native Swift and SwiftUI recreation of Knuff, the macOS APNs debugging tool.

## What was modernized

- SwiftUI `DocumentGroup` replaces `NSDocument`, storyboard wiring, Mantle, and KVOController.
- `URLSession` with a Keychain client identity sends HTTP/2 requests directly to APNs.
- A native SwiftUI editor provides monospaced JSON editing, line numbers, undo, and live validation instead of Fragaria.
- SwiftUI transitions and layout replace POP animations.
- `MultipeerConnectivity` still discovers nearby devices advertising the `knuff` service.
- CocoaPods, Fabric, and Crashlytics are not required.

## Run

Open `KnuffSwift.xcodeproj`, select the **KnuffSwift** scheme, and run on macOS 14 or later. Import an Apple Push Services certificate and matching private key into Keychain Access before choosing a certificate in the app.

Saved `.knuff` files use a readable JSON format. Documents created by the original Objective-C app are also supported: its Mantle/`NSKeyedArchiver` fields are migrated when opened and saved as JSON on the next save.
