//
//  CollaborationManager.swift
//  Artifacts
//
//  Created by Ryan Aparicio on 1/31/26.
//

import Foundation
import ARKit

final class CollaborationManager: ObservableObject {
    let multipeer = MultipeerSession()

    /// We set this after ARView is created
    weak var session: ARSession?

    init() {
        multipeer.onReceiveData = { [weak self] data, peer in
            self?.handleIncomingData(data, from: peer)
        }
    }

    func host() { multipeer.startHosting() }
    func join() { multipeer.startBrowsing() }
    func stop() { multipeer.stop() }

    func sendCollaborationData(_ collaborationData: ARSession.CollaborationData) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: collaborationData, requiringSecureCoding: true)
            multipeer.sendToAllPeers(data, reliably: false) // collaboration packets can be unreliable
        } catch {
            print("❌ Failed to archive collaboration data:", error.localizedDescription)
        }
    }

    private func handleIncomingData(_ data: Data, from peer: Any) {
        guard let session = session else { return }
        do {
            guard let collab = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) else {
                return
            }
            DispatchQueue.main.async {
                session.update(with: collab)
            }
        } catch {
            // This will also fire if other non-collaboration data arrives in the future
            print("⚠️ Incoming data was not CollaborationData:", error.localizedDescription)
        }
    }
}

