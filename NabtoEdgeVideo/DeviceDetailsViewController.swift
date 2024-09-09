//
//  VendorHeatingViewController.swift
//  Nabto Edge Video
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit
import NotificationBannerSwift

// You should subclass this controller to implement custom devices.
// More info on StoryboardHelper.swift

class ViewControllerWithDevice: UIViewController {
    var device : Bookmark!
}

class DeviceDetailsViewController: ViewControllerWithDevice {
    
    var rtspPath: RtspPath?
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var pathTextField: UITextField!
    @IBOutlet weak var deviceIdLabel: UILabel!
    @IBOutlet weak var productIdLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var pathActualLabel: UILabel!
    @IBOutlet weak var pathDeviceLabel: UILabel!
    
    @IBAction func saveTapped(_ sender: Any) {
        if let text = nameTextField.text, !text.isEmpty {
            self.device.name = text
        }
        if let path = pathTextField.text, !path.isEmpty{
            self.device.rtspPath = path
        }
        updateView()
        do {
            try BookmarkManager.shared.saveBookmarks()
        } catch {
            let banner = GrowingNotificationBanner(title: "Error", subtitle: "Could not update bookmark: \(error)", style: .danger)
            banner.show()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateView()
    }
    
    private func updateView() {
        navigationItem.title = device?.name ?? ""
        nameTextField.text = device?.name ?? ""
        nameTextField.autocorrectionType = .no
        pathTextField.text = device?.rtspPath ?? ""
        pathTextField.autocorrectionType = .no
        deviceIdLabel.text = device?.deviceId ?? ""
        productIdLabel.text = device?.productId ?? ""
        nameLabel.text = device?.name ?? ""
        pathDeviceLabel.text = rtspPath?.devicePath() ?? "(not set)"
        pathActualLabel.text = rtspPath?.getPath()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
}
// mPe-hl-Hx2
