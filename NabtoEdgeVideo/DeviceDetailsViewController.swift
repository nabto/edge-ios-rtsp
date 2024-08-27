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

    @IBOutlet weak var deviceIDLabel    : UILabel!
    @IBOutlet weak var productIDLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var pathField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = device?.name ?? ""
        nameField.text = device?.name ?? ""
        pathField.text = device?.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func goToHome(_ sender: Any) {
        _ = navigationController?.popToRootViewController(animated: true)
    }
}
