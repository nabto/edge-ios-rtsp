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

class DeviceDetailsViewController: ViewControllerWithDevice, UITextFieldDelegate {
    
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
        if let path = pathTextField.text {
            self.device.rtspPath = path
        }
        updateView()
        nameTextField.resignFirstResponder()
        pathTextField.resignFirstResponder()
        do {
            try BookmarkManager.shared.saveBookmarks()
        } catch {
            let banner = GrowingNotificationBanner(title: "Error", subtitle: "Could not update bookmark: \(error)", style: .danger)
            banner.show()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.pathTextField.addTarget(self, action: #selector(pathTextFieldDidChange), for: .editingChanged)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateView()
    }

    @objc func pathTextFieldDidChange(_ textField: UITextField) {
        updatePlaceHolderText()
    }
    
    func getPlaceHolderText() -> String {
        let prefix = "Enter path"
        if let rtspPath = self.rtspPath {
            return "\(prefix) (default is \"\(rtspPath.getNonUserPath())\")"
        } else {
            return prefix
        }
    }
    
    func updatePlaceHolderText() {
        if (self.pathTextField.text?.isEmpty ?? true) {
            self.pathTextField.placeholder = self.getPlaceHolderText()
        }
    }
    
    private func updateView() {
        navigationItem.title = device?.name ?? ""
        updatePlaceHolderText()
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
