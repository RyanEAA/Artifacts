//
//  FirebaseStorageHelper.swift
//  ARTutorial
//
//  Created by Ryan Aparicio on 10/22/25.
//

import Foundation
import Firebase
import FirebaseStorage

class FirebaseStorageHelper {
    static private let cloudStorage = Storage.storage()
    static private let syncQueue = DispatchQueue(label: "FirebaseStorageHelper.sync")
    static private var inFlightDownloads: [String: [(URL) -> Void]] = [:]
    
    class func asyncDownloadToFilesystem(relativePath: String, handler: @escaping(_ fileurl: URL)-> Void){
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileUrl = docsUrl.appendingPathComponent(relativePath)

        if FileManager.default.fileExists(atPath: fileUrl.path) {
            handler(fileUrl)
            return
        }

        let parentDirectory = fileUrl.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: parentDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("Firebase Storage: Failed to create directory for \(relativePath): \(error.localizedDescription)")
        }

        var shouldStartDownload = false
        syncQueue.sync {
            if inFlightDownloads[relativePath] != nil {
                inFlightDownloads[relativePath, default: []].append(handler)
            } else {
                inFlightDownloads[relativePath] = [handler]
                shouldStartDownload = true
            }
        }

        guard shouldStartDownload else { return }

        let storageRef = cloudStorage.reference(withPath: relativePath)

        storageRef.write(toFile: fileUrl) { url, error in
            let handlers: [(URL) -> Void] = syncQueue.sync {
                defer { inFlightDownloads[relativePath] = nil }
                return inFlightDownloads[relativePath] ?? []
            }

            guard let localUrl = url else {
                if let error {
                    print("Firebase Storage: Error downloading \(relativePath): \(error.localizedDescription)")
                } else {
                    print("Firebase Storage: Error downloading \(relativePath)")
                }
                return
            }

            handlers.forEach { $0(localUrl) }
        }.resume()
    }
}
