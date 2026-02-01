//
//  MultipeerSession.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 1/31/26.
//

import Foundation
import MultipeerConnectivity

final class MultipeerSession: NSObject, ObservableObject {
    private let serviceType = "artifacts-ar"  // must be <= 15 chars
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)

    private lazy var session: MCSession = {
        let s = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        return s
    }()

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// Called whenever we receive raw Data from a peer
    var onReceiveData: ((Data, MCPeerID) -> Void)?

    @Published var connectedPeers: [MCPeerID] = []

    func startHosting() {
        stop() // reset
        let adv = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        print("📡 Hosting started as:", myPeerID.displayName)
    }

    func startBrowsing() {
        stop() // reset
        let br = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br
        print("🔎 Browsing started as:", myPeerID.displayName)
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()
        connectedPeers = []
    }

    func sendToAllPeers(_ data: Data, reliably: Bool = true) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data,
                             toPeers: session.connectedPeers,
                             with: reliably ? .reliable : .unreliable)
        } catch {
            print("❌ Multipeer send error:", error.localizedDescription)
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("🤝 Invitation received from:", peerID.displayName)
        invitationHandler(true, session) // auto-accept for demo
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ Advertiser failed:", error.localizedDescription)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        print("✅ Found peer:", peerID.displayName)
        // Auto-invite for demo
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("⚠️ Lost peer:", peerID.displayName)
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Browser failed:", error.localizedDescription)
    }
}

// MARK: - MCSessionDelegate
extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
        }
        print("🔗 Peer \(peerID.displayName) state:", state.rawValue)
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        onReceiveData?(data, peerID)
    }

    // Unused but required:
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
