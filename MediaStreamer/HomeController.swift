//
//  HomeController
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class HomeController: UIViewController {

    let defaults = UserDefaults()
    let db = SQLiteDB.shared
    
    @IBOutlet weak var displayNameField: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(HomeController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        let displayName = defaults.string(forKey: "displayName")
        if displayName != nil{
            displayNameField.text = displayName
        }
        displayNameField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("HomeController is displayed")
    }
    
    func textFieldDidChange(_ textField: UITextField) {
        defaults.set(displayNameField.text, forKey: "displayName");
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func createAddRoom(_ sender: Any) {
        // Ask what user wants
        let alert = UIAlertController(title: "Create/Add", message: "What would you like to do?", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Create New Room", style: UIAlertActionStyle.default, handler: nil))
        alert.addAction(UIAlertAction(title: "Join Existing Room", style: UIAlertActionStyle.default, handler: nil))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let button = sender as? UIButton {
            let roomTitle = button.currentTitle
            if let dest = segue.destination as? RoomController {
                dest.navigationItem.title = roomTitle
            }
        }
    }
    
}
