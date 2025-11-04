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
    
    class func asyncDownloadToFilesystem(relativePath: String, handler: @escaping(_ fileurl: URL)-> Void){
        let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileUrl = docsUrl.appendingPathComponent(relativePath)
        
        // check if asset is already in the local filesystem
        // if it is, load that asset and run
        
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            handler(fileUrl)
            return
        }
        
        // create reference to the asset
        let storageRef = cloudStorage.reference(withPath: relativePath)
        
        // download asset to local filesystem
        storageRef.write(toFile: fileUrl) { url, error in
            guard let localUrl = url else {
                print("Firebase Storage: Error Downloading file with relative Path: \(relativePath)")
                return
            }
            
            handler(localUrl)
        }.resume()
    }
}
