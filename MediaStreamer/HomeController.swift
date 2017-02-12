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
    @IBOutlet weak var displayNameField: UILabel!
    
    @IBOutlet weak var roomTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let displayName = defaults.string(forKey: "displayName")
        if displayName != nil{
            displayNameField.text = "Display Name: " + displayName!
        }

        // Init rooms table
        let data = db.query(sql: "SELECT * FROM Room ORDER BY DisplayName ASC")
        if data.count > 0{
            for i in 1...data.count-1{
                if let rName = data[i]["DisplayName"]{
                    roomList.append(rName as! String)
                }
                if let rNum = data[i]["RoomNum"]{
                    roomNumberList.append(String(describing: rNum))
                }
            }
        }
        
        roomTableView.delegate = self;
        roomTableView.dataSource = self;
        roomTableView.register(UITableViewCell.self, forCellReuseIdentifier: "customcell")
        roomTableView.allowsSelection = true
    }
    
    // Return number of rows in table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return roomList.count
    }
    
    // Populate table
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "customcell", for: indexPath as IndexPath)
        cell.textLabel?.text = roomList[indexPath.item] + " (" + roomNumberList[indexPath.item] + ")"
        return cell
    }
    
    // Allow rows to be deleted
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // Delete a row
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.delete) {
            // handle delete (by removing the data from your array and updating the tableview)
            let roomNum = roomNumberList[indexPath.item]
            let result = self.db.execute(sql: "DELETE FROM Room WHERE roomNum=?", parameters: [roomNum])
            if (result != 0){
                roomNumberList.remove(at: indexPath.item)
                roomList.remove(at: indexPath.item)
                self.roomTableView.reloadData()
            }else{
                print("Room delete failed")
            }
        }
    }
    
    // Enter selected room
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // TODO: Tell server to change rooms
        print("selection")
        let displayName = roomList[indexPath.item]
        performSegue(withIdentifier: "enterRoom", sender: displayName)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let row = roomTableView.indexPathForSelectedRow {
            self.roomTableView.deselectRow(at: row, animated: false)
        }
        print("HomeController is displayed")
    }
    
    // Only permit 30 characters in text fields
    func createTextFieldDidChange(_ textField: UITextField) {
        if (createAddTextField.text!.characters.count > 30) {
            textField.deleteBackward()
        }
    }
    
    @IBAction func changeDisplayName(_ sender: Any) {
        let alert = UIAlertController(title: "Change Name", message: "Enter new display name:", preferredStyle: UIAlertControllerStyle.alert)
        alert.addTextField(configurationHandler: self.configurationTextField)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ action in
            self.defaults.set(self.createAddTextField.text!, forKey: "displayName");
            self.displayNameField.text = "Display Name: " + self.createAddTextField.text!
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    // Setup text fields for alerts
    func configurationTextField(textField: UITextField!)
    {
            
        self.createAddTextField = textField!
        self.createAddTextField.autocapitalizationType = UITextAutocapitalizationType.words
        self.createAddTextField.addTarget(self, action: #selector(createTextFieldDidChange(_:)), for: .editingChanged)
        
    }
    
    // Listen for server response when trying to join room
    func addSocketRoomJoinListener(roomNum: String){
        SocketIOManager.socket.on("join reply") {[weak self] data, ack in
            if let displayName = data[0] as? String {
                if displayName == "nil"{
                    let alert = UIAlertController(title: "Room Not Found", message: "No room found for that id", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
                    self?.present(alert, animated: true, completion: nil)
                } else {
                    let result = self?.db.execute(sql: "INSERT INTO Room (RoomNum, DisplayName) VALUES (?,?)", parameters: [roomNum, displayName])
                    if result != 0{
                        self?.roomList.append(displayName)
                        self?.roomNumberList.append(String(roomNum))
                        self?.roomTableView.reloadData()
                    }
                }
            }
        }
    }
    
    // Prompt for room name, add it to local database, and tell sever about new room
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
    
    // Send request for corresponding name to the server
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
    
    // Show alert for room creation/adding
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
        if segue.identifier == "enterRoom"{
            if let dest = segue.destination as? RoomController {
                dest.navigationItem.title = sender as! String?
            }
        }
    }
    
}
