//
//  VideoViewController.swift
//  NabtoEdgeVideo
//
//  Created by Ahmad Saleh on 22/02/2023.
//  Copyright © 2023 Nabto. All rights reserved.
//

import Foundation
import UIKit

class VideoViewController: UIViewController, GStreamerBackendDelegate
{
    private var videoView = UIView()
    private var gst: GStreamerBackend?
    private var uri: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(appWillMoveToForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        gst?.destroy()
    }
    
    @objc func appMovedToBackground() {
        gst?.pause()
    }
    
    @objc func appWillMoveToForeground() {
        if let uri = uri {
            setUri(uri)
        }
    }
    
    func gstreamerInitialized() {
        if let uri = uri {
            gst?.setUri(uri)
            gst?.play()
        }
    }
    
    func pause() {
        gst?.pause()
    }
    
    func play() {
        gst?.play()
    }
    
    func setUri(_ newUri: String) {
        uri = newUri
        
        videoView.removeFromSuperview()
        videoView = UIView()
        view.addSubview(videoView)
        self.videoView.translatesAutoresizingMaskIntoConstraints = false
        self.videoView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        self.videoView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        self.videoView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 0).isActive = true
        self.videoView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: 0).isActive = true
        
        gst?.destroy()
        gst = GStreamerBackend(self, videoView: videoView)
    }
}
