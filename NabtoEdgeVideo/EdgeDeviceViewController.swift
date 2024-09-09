import UIKit
import NotificationBannerSwift
import CBORCoding
import NabtoEdgeClient
import NabtoEdgeIamUtil
import OSLog

class EdgeDeviceViewController: ViewControllerWithDevice {
    private let cborEncoder = CBOREncoder()
    private var tunnel: TcpTunnel?
    private let videoViewController = VideoViewController()
    private var serviceInfo: ServiceInfo?
    private var rtspPath: RtspPath = RtspPath(defaultPath: "/video")

    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var connectingView: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var refreshVideoButton: UIButton!
    
    @IBOutlet weak var deviceIdLabel: UILabel!
    @IBOutlet weak var appNameAndVersionLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!

    var offline = false
    var showReconnectedMessage = false
    var refreshTimer: Timer?
    var busyTimer: Timer?
    var banner: GrowingNotificationBanner?

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
    
    @IBAction func detailsTapped(_ sender: Any) {
        performSegue(withIdentifier: "toDeviceDetails", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDeviceDetails" {
            if let destination = segue.destination as? DeviceDetailsViewController {
                destination.device = self.device
                destination.rtspPath = self.rtspPath
            }
        }
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }

    private func showConnectSuccessIfNecessary() {
        guard self.showReconnectedMessage else { return }
        DispatchQueue.main.async {
            self.banner?.dismiss()
            self.banner = GrowingNotificationBanner(title: "Connected", subtitle: "Connection re-established!", style: .success)
            self.banner?.show()
            self.showReconnectedMessage = false
        }
    }

    func handleDeviceError(_ error: Error) {
        EdgeConnectionManager.shared.removeConnection(self.device)
        if let error = error as? NabtoEdgeClientError {
            handleApiError(error: error)
        } else if let error = error as? IamError, case .API_ERROR(let cause) = error {
            handleApiError(error: cause)
        } else {
            NSLog("Pairing error: \(error)")
            showDeviceErrorMsg("\(error)")
        }
    }

    private func handleApiError(error: NabtoEdgeClientError) {
        let message: String
        switch error {
        case .NO_CHANNELS:
            message = "Device offline - please make sure you and the target device both have a working network connection"
        case .TIMEOUT:
            message = "The operation timed out - was the connection lost?"
        case .STOPPED:
            return // ignore - connection/client will be restarted at next connect attempt
        default:
            message = "An error occurred: \(error)"
        }
        showDeviceErrorMsg(message)
    }

    func showDeviceErrorMsg(_ msg: String) {
        DispatchQueue.main.async {
            self.banner?.dismiss()
            self.banner = GrowingNotificationBanner(title: "Communication Error", subtitle: msg, style: .danger)
            self.banner?.show()
        }
    }

    @objc func showSpinner() {
        DispatchQueue.main.async {
            if self.busy {
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
        startTunnelAndVideo()
    }
    
    private func constructRtspUri(auth: String, port: UInt16, path: String) -> String {
        var cleanedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedPath.hasPrefix("/") {
            cleanedPath.insert("/", at: cleanedPath.startIndex)
        }
        return "rtsp://\(auth)127.0.0.1:\(port)\(cleanedPath)"
    }
    
    private func getServiceInfo(connection: Connection) throws -> ServiceInfo {
        let request = try connection.createCoapRequest(method: "GET", path: "/tcp-tunnels/services/rtsp")
        let response = try request.execute()
        guard response.status == 205 else {
            throw NabtoEdgeClientError.FAILED_WITH_DETAIL(detail: "Could not get device service info, got status \(response.status)")
        }
        return try ServiceInfo.decode(cbor: response.payload)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.rtspPath.device = self.device
        navigationItem.title = self.device?.name ?? "Video Device"
        startTunnelAndVideo()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (self.isMovingFromParent) {
            // moving back to overview - stop tunnel and player
            stopTunnelAndVideo()
        } else {
            pauseVideo()
        }

        removeObservers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addObservers()
    }

    // MARK: - Helper Functions
    private func startTunnelAndVideo() {
        DispatchQueue.global(qos: .background).async {
            do {
                self.busy = true
                let conn = try EdgeConnectionManager.shared.getConnection(self.device)
                self.serviceInfo = try self.getServiceInfo(connection: conn)
                self.rtspPath.serviceInfo = self.serviceInfo
                if (self.tunnel != nil) {
                    try self.tunnel?.close()
                }
                // open a fresh tunnel - gstreamer behaves oddly with severe artifacts the first 0.5-5 seconds if re-using exact RTSP URL (likely until an I-Frame is received)
                self.tunnel = try conn.createTcpTunnel()
                try self.tunnel?.open(service: "rtsp", localPort: 0)
                self.startVideo()
            } catch {
                self.handleDeviceError(error)
            }
        }
    }

    private func startVideo() {
        guard let tunnel = self.tunnel, let serviceInfo = self.serviceInfo, let port = try? tunnel.getLocalPort() else {
            showDeviceErrorMsg("TcpTunnel is not open, failed to start video stream!")
            DispatchQueue.main.async {
                self.busy = false
            }
            return
        }
        
        let path = self.rtspPath.getPath()
        let username = serviceInfo.metadata["rtsp-username"] ?? ""
        let password = serviceInfo.metadata["rtsp-password"] ?? ""
        let auth = username.isEmpty ? "" : "\(username):\(password)@"
        
        let uri = constructRtspUri(auth: auth, port: port, path: path)
        DispatchQueue.main.async {
            self.busy = false
            self.videoViewController.setUri(uri)
            self.videoViewController.play()
        }
    }
    
    private func stopTunnelAndVideo() {
        // XXX if not stopping, gstreamer crashes when closing tunnel
        self.videoViewController.stop()
        self.tunnel?.closeAsync(closure: { ec in
            if (ec != NabtoEdgeClientError.OK) {
                NSLog("Could not close tunnel: \(ec)");
            }
            self.tunnel = nil
        })
    }
    
    private func pauseVideo() {
        self.videoViewController.pause()
    }

    private func setupVideoView() {
        addChild(videoViewController)
        videoView.addSubview(videoViewController.view)
        videoViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            videoViewController.view.topAnchor.constraint(equalTo: videoView.topAnchor),
            videoViewController.view.bottomAnchor.constraint(equalTo: videoView.bottomAnchor),
            videoViewController.view.leftAnchor.constraint(equalTo: videoView.leftAnchor),
            videoViewController.view.rightAnchor.constraint(equalTo: videoView.rightAnchor)
        ])
        videoViewController.didMove(toParent: self)
    }

    private func addObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(connectionClosed), name: NSNotification.Name(EdgeConnectionManager.eventNameConnectionClosed), object: nil)
        nc.addObserver(self, selector: #selector(networkLost), name: NSNotification.Name(EdgeConnectionManager.eventNameNoNetwork), object: nil)
        nc.addObserver(self, selector: #selector(networkAvailable), name: NSNotification.Name(EdgeConnectionManager.eventNameNetworkAvailable), object: nil)
        nc.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillMoveToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameConnectionClosed), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameNoNetwork), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(EdgeConnectionManager.eventNameNetworkAvailable), object: nil)
    }

    // MARK: - Reachability callbacks

    @objc func appMovedToBackground() {
        stopTunnelAndVideo()
    }
    
    @objc func appWillMoveToForeground() {
        startTunnelAndVideo()
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
            self.showDeviceErrorMsg("Network connection lost - Please try again later")
            do {
                try self.tunnel?.close()
            } catch {
                NSLog("Could not close tunnel in networkLost")
            }
        }
    }

    @objc func networkAvailable(_ notification: Notification) {
        DispatchQueue.main.async {
            GrowingNotificationBanner(title: "Network up again!", style: .success).show()
        }
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
