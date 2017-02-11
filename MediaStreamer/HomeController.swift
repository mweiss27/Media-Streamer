//
//  HomeController
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class HomeController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let defaults = UserDefaults()
    let db = SQLiteDB.shared
    var createAddTextField : UITextField!
    var roomList : [String] = []
    var roomNumberList : [String] = []
    
    @IBOutlet weak var displayNameField: UITextField!
    @IBOutlet weak var roomTableView: UITableView!
    
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
        
        // Init rooms table
        let data = db.query(sql: "SELECT * FROM Room ORDER BY DisplayName ASC")
        for i in 0...data.count-1{
            if let rName = data[i]["DisplayName"]{
                roomList.append(rName as! String)
            }
            if let rNum = data[i]["RoomNum"]{
                roomNumberList.append(String(describing: rNum))
            }
        }
        
        roomTableView.delegate = self;
        roomTableView.dataSource = self;
        roomTableView.register(UITableViewCell.self, forCellReuseIdentifier: "customcell")
    }
    
    var myarray = ["item1", "item2", "item3"]
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return roomList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "customcell", for: indexPath as IndexPath)
        cell.textLabel?.text = roomList[indexPath.item] + " (" + roomNumberList[indexPath.item] + ")"
        return cell
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("HomeController is displayed")
    }
    
    func textFieldDidChange(_ textField: UITextField) {
        defaults.set(displayNameField.text, forKey: "displayName");
    }
    
    func createTextFieldDidChange(_ textField: UITextField) {
        if (createAddTextField.text!.characters.count > 30) {
            textField.deleteBackward()
        }
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func configurationTextField(textField: UITextField!)
    {
            
        self.createAddTextField = textField!
        self.createAddTextField.autocapitalizationType = UITextAutocapitalizationType.words
        self.createAddTextField.addTarget(self, action: #selector(createTextFieldDidChange(_:)), for: .editingChanged)
        
    }
    
    func addSocketRoomJoinListener(roomNum: String){
        SocketIOManager.socket.on("join reply") {[weak self] data, ack in
            if let displayName = data[0] as? String {
                let result = self?.db.execute(sql: "INSERT INTO Room (RoomNum, DisplayName) VALUES (?,?)", parameters: [roomNum, displayName])
                if result != 0{
                    self?.roomList.append(displayName)
                    self?.roomNumberList.append(String(roomNum))
                    self?.roomTableView.reloadData()
                }
            }
        }
    }
    
    func createRoom(alert: UIAlertAction) {
        let alert = UIAlertController(title: "Create Room", message: "Name your room:", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField(configurationHandler: self.configurationTextField)
        
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ action in

            let displayName = self.createAddTextField.text!
            let roomNum = Int(arc4random_uniform(999999))
            
            // Insert record into local database
            let result = self.db.execute(sql: "INSERT INTO Room (RoomNum, DisplayName) VALUES (?,?)", parameters: [roomNum, displayName])
            if result != 0{
                // Tell server about new room
                SocketIOManager.socket.emit("create room", displayName, roomNum)
                
                self.roomList.append(displayName)
                self.roomNumberList.append(String(roomNum))
                self.roomTableView.reloadData()
            }else{
                print("Room creation failed.")
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func joinRoom(alert: UIAlertAction) {
        let alert = UIAlertController(title: "Join Room", message: "Enter the room number:", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField(configurationHandler: self.configurationTextField)
        
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ action in
            let roomNum = self.createAddTextField.text!
            self.addSocketRoomJoinListener(roomNum: roomNum)
            SocketIOManager.socket.emit("join room", roomNum)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func createAddRoom(_ sender: Any) {
        // Ask what user wants
        let alert = UIAlertController(title: "Create/Add", message: "What would you like to do?", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Create New Room", style: UIAlertActionStyle.default, handler: createRoom))
        alert.addAction(UIAlertAction(title: "Join Existing Room", style: UIAlertActionStyle.default, handler: joinRoom))
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
