//
//  VideoViewController.swift
//  NabtoEdgeThermostat
//
//  Created by Ahmad Saleh on 22/02/2023.
//  Copyright © 2023 Nabto. All rights reserved.
//

import Foundation
import UIKit

class VideoViewController: UIViewController, GStreamerBackendDelegate
{
    private var videoView: UIView!
    private var gst: GStreamerBackend!
    private var uri: String?
    
    convenience init() {
        self.init(nibName:nil, bundle:nil)
        self.videoView = UIView()
        self.gst = GStreamerBackend(self, videoView: self.videoView)
    }
    
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
        
        self.view.addSubview(self.videoView)
        self.videoView.translatesAutoresizingMaskIntoConstraints = false
        self.videoView.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        self.videoView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        self.videoView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 0).isActive = true
        self.videoView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: 0).isActive = true
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
        if uri != nil {
            gst?.play()
        }
    }
    
    func gstreamerInitialized() {
        if let uri = uri {
            gst?.setUri(uri)
            gst?.play()
        }
    }
    
    // @TODO: Delete or do something else with this
    func gstreamerSetUIMessage(_ message: String) {
        print("gstreamerSetUIMessage: \(message)")
    }
    
    func pause() {
        gst?.pause()
    }
    
    func play() {
        gst?.play()
    }
    
    func setUri(_ newUri: String) {
        uri = newUri
        gst?.setUri(newUri)
        gst?.play()
    }
}
