//
//  RtspPath.swift
//  NabtoEdgeVideo
//
//  Created by Ulrik Gammelby on 09/09/2024.
//  Copyright © 2024 Nabto. All rights reserved.
//

import Foundation

class RtspPath {
    let defaultPath: String
    var serviceInfo: ServiceInfo?
    var device: Bookmark?
    
    init(defaultPath: String) {
        self.defaultPath = defaultPath
    }

    func devicePath() -> String? {
        return serviceInfo?.metadata["rtsp-path"]
    }
    
    func getPath() -> String {
        let bookmarkPath = device?.rtspPath ?? ""
        let path: String
        if bookmarkPath.isEmpty {
            if let devicePath = devicePath() {
                path = devicePath
            } else {
                path = defaultPath
            }
        } else {
            path = bookmarkPath
        }
        return path
    }

}
