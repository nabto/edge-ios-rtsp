//
//  EdgeDeviceViewController.swift
//  Nabto Edge Video
//
//  Created by Nabto on 03/02/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit
import NotificationBannerSwift
import CBORCoding
import NabtoEdgeClient
import NabtoEdgeIamUtil
import OSLog

class EdgeDeviceViewController: DeviceDetailsViewController {
    private let defaultVideoPath = "/video"
    
    private let cborEncoder: CBOREncoder = CBOREncoder()
    private var tunnel: TcpTunnel? = nil
    private let videoViewController = VideoViewController()
    private var serviceInfo: ServiceInfo? = nil

    @IBOutlet weak var settingsButton       : UIButton!
    @IBOutlet weak var connectingView       : UIView!
    @IBOutlet weak var spinner              : UIActivityIndicatorView!
    @IBOutlet weak var videoView            : UIView!
    @IBOutlet weak var refreshVideoButton   : UIButton!
    @IBOutlet weak var videoPathTextField   : UITextField!
    
    @IBOutlet weak var deviceIdLabel         : UILabel!
    @IBOutlet weak var appNameAndVersionLabel: UILabel!
    @IBOutlet weak var usernameLabel         : UILabel!
    @IBOutlet weak var displayNameLabel      : UILabel!
    @IBOutlet weak var roleLabel             : UILabel!

    var offline         = false
    var showReconnectedMessage: Bool = false
    var refreshTimer: Timer?
    var busyTimer: Timer?
    var banner: GrowingNotificationBanner? = nil
    
    var busy = false {
        didSet {
            self.busyTimer?.invalidate()
            if busy {
                DispatchQueue.main.async {
                    self.busyTimer = Timer.scheduledTimer(timeInterval: 0.8, target: self, selector: #selector(self.showSpinner), userInfo: nil, repeats: false)
                }
            } else {
                self.hideSpinner()
            }
        }
    }

    private func showConnectSuccessIfNecessary() {
        if (self.showReconnectedMessage) {
            DispatchQueue.main.async {
                self.banner?.dismiss()
                self.banner = GrowingNotificationBanner(title: "Connected", subtitle: "Connection re-established!", style: .success)
                self.banner!.show()
                self.showReconnectedMessage = false
            }
        }
    }

    func handleDeviceError(_ error: Error) {
        EdgeConnectionManager.shared.removeConnection(self.device)
        if let error = error as? NabtoEdgeClientError {
            handleApiError(error: error)
        } else if let error = error as? IamError {
            if case .API_ERROR(let cause) = error {
                handleApiError(error: cause)
            } else {
                NSLog("Pairing error, really? \(error)")
            }
        } else {
            self.showDeviceErrorMsg("\(error)")
        }
    }

    private func handleApiError(error: NabtoEdgeClientError) {
        switch error {
        case .NO_CHANNELS:
            self.showDeviceErrorMsg("Device offline - please make sure you and the target device both have a working network connection")
            break
        case .TIMEOUT:
            self.showDeviceErrorMsg("The operation timed out - was the connection lost?")
            break
        case .STOPPED:
            // ignore - connection/client will be restarted at next connect attempt
            break
        default:
            self.showDeviceErrorMsg("An error occurred: \(error)")
        }
    }

    func showDeviceErrorMsg(_ msg: String) {
        DispatchQueue.main.async {
            self.banner?.dismiss()
            self.banner = GrowingNotificationBanner(title: "Communication Error", subtitle: msg, style: .danger)
            self.banner!.show()
        }
    }

    @objc func showSpinner() {
        DispatchQueue.main.async {
            if (self.busy) {
                self.connectingView.isHidden = false
                self.spinner.startAnimating()
            }
        }
    }

    func hideSpinner() {
        DispatchQueue.main.async {
            self.connectingView.isHidden = true
            self.spinner.stopAnimating()
        }
    }
    
    @IBAction func refreshVideoTap(_ sender: Any) {
        if (videoPathTextField.text != nil && !videoPathTextField.text!.isEmpty) {
            startVideo(userPath: videoPathTextField.text!)
        }
    }
    
    private func constructRtspUri(auth: String, port: UInt16, path: String) -> String {
        var cleanedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if (!cleanedPath.hasPrefix("/")) {
            cleanedPath.insert("/", at: cleanedPath.startIndex)
        }
        return "rtsp://\(auth)127.0.0.1:\(port)\(cleanedPath)"
    }
    
    private func startVideo(userPath: String? = nil) {
        if let tunnel = self.tunnel, let serviceInfo = self.serviceInfo, let port = try? tunnel.getLocalPort() {
            let path = userPath ?? serviceInfo.metadata["rtsp-path"] ?? defaultVideoPath
            
            let username = serviceInfo.metadata["rtsp-username"] ?? ""
            let password = serviceInfo.metadata["rtsp-password"] ?? ""
            let auth = username.isEmpty ? "" : "\(username):\(password)@"
            
            let uri = constructRtspUri(auth: auth, port: port, path: path)
            DispatchQueue.main.async {
                self.videoPathTextField.text = path
                self.videoViewController.setUri(uri)
            }
        } else {
            showDeviceErrorMsg("TcpTunnel is not open, failed to start video stream!")
            startTunnelOnMainThread(userPath: userPath)
        }
        self.busy = false
    }
    
    private func getServiceInfo(connection: Connection) throws -> ServiceInfo {
        let request = try connection.createCoapRequest(method: "GET", path: "/tcp-tunnels/services/rtsp")
        let response = try request.execute()
        if (response.status == 205) {
            return try ServiceInfo.decode(cbor: response.payload)
        } else {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Could not get device service info, got status \(response.status)")
        }
    }
    
    private func startTunnel(userPath: String? = nil) {
        do {
            let conn = try EdgeConnectionManager.shared.getConnection(self.device)
            serviceInfo = try getServiceInfo(connection: conn)
            
            tunnel = try conn.createTcpTunnel()
            tunnel?.openAsync(service: "rtsp", localPort: 0, closure: { _ in
                self.startVideo(userPath: userPath)
            })
        } catch {
            handleDeviceError(error)
        }
    }
    
    private func startTunnelOnMainThread(userPath: String? = nil) {
        DispatchQueue.main.async { self.startTunnel(userPath: userPath) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.busy = true
        self.videoView.addSubview(videoViewController.view)
        videoViewController.view.translatesAutoresizingMaskIntoConstraints = false
        videoViewController.view.topAnchor.constraint(equalTo: self.videoView.topAnchor, constant: 0).isActive = true
        videoViewController.view.bottomAnchor.constraint(equalTo: self.videoView.bottomAnchor, constant: 0).isActive = true
        videoViewController.view.leftAnchor.constraint(equalTo: self.videoView.leftAnchor, constant: 0).isActive = true
        videoViewController.view.rightAnchor.constraint(equalTo: self.videoView.rightAnchor, constant: 0).isActive = true
        
        videoPathTextField.autocorrectionType = .no
        startTunnelOnMainThread()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default
                .removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameConnectionClosed), object: nil)
        NotificationCenter.default
                .removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameNoNetwork), object: nil)
        NotificationCenter.default
                .removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameNetworkAvailable), object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(connectionClosed),
                       name: NSNotification.Name (EdgeConnectionManager.eventNameConnectionClosed),
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(networkLost),
                       name: NSNotification.Name (EdgeConnectionManager.eventNameNoNetwork),
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(networkAvailable),
                       name: NSNotification.Name (EdgeConnectionManager.eventNameNetworkAvailable),
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(appMovedToBackground),
                       name: UIApplication.willResignActiveNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(appWillMoveToForeground),
                       name: UIApplication.willEnterForegroundNotification,
                       object: nil)
    }

    // MARK: - Reachability callbacks
    @objc func appMovedToBackground() {
        videoViewController.pause()
    }
    
    @objc func appWillMoveToForeground() {
        startTunnelOnMainThread()
    }

    @objc func connectionClosed(_ notification: Notification) {
        if notification.object is Bookmark {
            DispatchQueue.main.async {
                self.showDeviceErrorMsg("Connection closed - refresh to try to reconnect")
                self.showReconnectedMessage = true
            }
        }
    }

    @objc func networkLost(_ notification: Notification) {
        DispatchQueue.main.async {
            let banner = GrowingNotificationBanner(title: "Network connection lost", subtitle: "Please try again later", style: .warning)
            banner.show()
            do {
                try self.tunnel?.close()
            } catch {
                NSLog("Could not close tunnel in networkLost")
            }
        }
    }

    @objc func networkAvailable(_ notification: Notification) {
        DispatchQueue.main.async {
            let banner = GrowingNotificationBanner(title: "Network up again!", style: .success)
            banner.show()
        }
        //startTunnelOnMainThread()
    }
}

struct ServiceInfo: Codable {
    public let serviceId: String
    public let type: String
    public let host: String
    public let port: Int
    public let streamPort: Int
    public let metadata: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case serviceId = "Id"
        case type = "Type"
        case host = "Host"
        case port = "Port"
        case streamPort = "StreamPort"
        case metadata = "Metadata"
    }
    
    public static func decode(cbor: Data) throws -> ServiceInfo {
        let decoder = CBORDecoder()
        do {
            return try decoder.decode(ServiceInfo.self, from: cbor)
        } catch {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Could not decode service info: \(error)")
        }
    }
}
