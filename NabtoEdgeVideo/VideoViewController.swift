//
//  VideoViewController.swift
//  NabtoEdgeVideo
//
//  Created by Ahmad Saleh on 22/02/2023.
//  Copyright © 2023 Nabto. All rights reserved.
//

import Foundation
import UIKit
import NotificationBannerSwift


class VideoViewController: UIViewController, GStreamerBackendDelegate
{
    private var videoView = UIView()
    private var gst: GStreamerBackend?
    private var uri: String?
    private var isPlayingDesired = false
    private var banner: GrowingNotificationBanner?

    override func viewDidLoad() {
        super.viewDidLoad()
        let nc = NotificationCenter.default
        // todo - handled both here and in parent
//        nc.addObserver(
//            self,
//            selector: #selector(appMovedToBackground),
//            name: UIApplication.willResignActiveNotification,
//            object: nil
//        )
//        nc.addObserver(
//            self,
//            selector: #selector(appWillMoveToForeground),
//            name: UIApplication.willEnterForegroundNotification,
//            object: nil
//        )
        
        // todo - move to parent
        nc.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        gst?.destroy()
    }
    
    @objc func appWillResignActive() {
        gst?.pause()
    }
    
    @objc func appDidBecomeActive() {
        if isPlayingDesired {
            gst?.play()
        }
    }
    
//    @objc func appMovedToBackground() {
//        gst?.pause()
//    }
//    
//    @objc func appWillMoveToForeground() {
//        if isPlayingDesired, let uri = uri {
//            setUri(uri)
//        }
//    }
//    
    func onInitialized() {
        if let uri = uri {
            gst?.setUri(uri)
            gst?.play()
        }
    }
    
    func getMessage(_ errorCode: GstBackendError, _ message: String) -> String {
        switch (errorCode) {
        case .notFound: return "Invalid RTSP path - fix on details page"
        case .notAuthorized: return "Unauthorized - missing credentials?"
        default: return message
        }
    }
    
    func onError(_ errorCode: GstBackendError, message: String) {
        DispatchQueue.main.async {
            self.banner?.dismiss()
            self.banner = GrowingNotificationBanner(title: "Error playing RTSP video stream", subtitle: self.getMessage(errorCode, message), style: .danger)
            self.banner?.show()
        }

        print("GST ERROR OCCURRED: code=[\(errorCode)], message=[\(message)]")
    }
    
    @objc func onBuffering() {
        print("GST BUFFERING")
    }
    
    func pause() {
        isPlayingDesired = false
        gst?.pause()
    }
    
    func stop() {
        gst?.destroy()
    }
    
    func play() {
        isPlayingDesired = true
        gst?.play()
    }
    
    func setUri(_ newUri: String) {
        isPlayingDesired = true
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
