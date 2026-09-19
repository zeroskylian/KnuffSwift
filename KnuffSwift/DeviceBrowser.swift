import Combine
import Foundation
import MultipeerConnectivity

struct NearbyDevice: Identifiable, Equatable {
    let id: MCPeerID
    let name: String
    let token: String
}

final class DeviceBrowser: NSObject, ObservableObject, MCNearbyServiceBrowserDelegate {
    @Published private(set) var devices: [NearbyDevice] = []
    private let browser: MCNearbyServiceBrowser

    override init() {
        let name = Host.current().localizedName ?? "KnuffSwift"
        browser = MCNearbyServiceBrowser(peer: MCPeerID(displayName: name), serviceType: "knuff")
        super.init()
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    deinit { browser.stopBrowsingForPeers() }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let token = info?["token"] else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !devices.contains(where: { $0.id == peerID }) else { return }
            devices.append(NearbyDevice(id: peerID, name: peerID.displayName, token: token))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in self?.devices.removeAll { $0.id == peerID } }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
