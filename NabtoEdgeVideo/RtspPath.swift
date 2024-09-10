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
        if (!bookmarkPath.isEmpty) {
            return bookmarkPath
        } else {
            return getNonUserPath()
        }
    }
    
    func getNonUserPath() -> String {
        if let devicePath = devicePath() {
            return devicePath
        } else {
            return defaultPath
        }
    }

}
