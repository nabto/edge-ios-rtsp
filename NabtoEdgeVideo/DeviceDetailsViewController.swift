//
//  VendorHeatingViewController.swift
//  Nabto Edge Video
//
//  Created by Nabto on 31/01/2022.
//  Copyright © 2022 Nabto. All rights reserved.
//

import UIKit

// You should subclass this controller to implement custom devices.
// More info on StoryboardHelper.swift

class ViewControllerWithDevice: UIViewController {
    var device : Bookmark!
}

class DeviceDetailsViewController: ViewControllerWithDevice {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var pathTextField: UITextField!
    @IBOutlet weak var deviceIdLabel: UILabel!
    @IBOutlet weak var productIdLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.title = device?.name ?? ""
        nameTextField.text = device?.name ?? ""
        pathTextField.text = "/\(device?.name ?? "(no name)")"
        deviceIdLabel.text = device?.deviceId ?? ""
        productIdLabel.text = device?.productId ?? ""
        nameLabel.text = device?.name ?? ""
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
}
// mPe-hl-Hx2
