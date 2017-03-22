//
//  HomeController
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class HomeController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private var sid: String?
    
    let defaults = UserDefaults()
    let db = SQLiteDB.shared
    var createAddTextField : UITextField!
    
    //[0] = [Name, Number]
    var rooms: [[String]] = []
    
    @IBOutlet weak var displayNameField: UILabel!
    @IBOutlet weak var roomTableView: UITableView!
    
    var roomsDirty: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        let displayName = defaults.string(forKey: "displayName")
        if displayName != nil{
            displayNameField.text = "Display Name: " + displayName!
        }
        
        roomTableView.delegate = self;
        roomTableView.dataSource = self;
        roomTableView.register(UITableViewCell.self, forCellReuseIdentifier: "customcell")
        roomTableView.allowsSelection = true
        
        print("HomeController.viewDidLoad")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("Requested Scopes: \(SPTAuth.defaultInstance().requestedScopes)")
        
            rooms = []
            // Init rooms table
            let data = db.query(sql: "SELECT * FROM Room ORDER BY DisplayName ASC")
            if data.count > 0 {
                for i in 0...data.count-1 {
                    print("Room[\(i)]: \(data[i]) -- \(data[i]["DisplayName"])) -- \(data[i]["RoomNum"])")
                    if let rName = data[i]["DisplayName"] as? String, let rNum = data[i]["RoomNum"] {
                        print("Appending room")
                        rooms.append( [ rName, String(describing: rNum) ] )
                    }
                }
            }
            self.roomTableView.reloadData()
            
            roomsDirty = false
        
        print("HomeController is displayed")
    }
    
    // Return number of rows in table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rooms.count
    }
    
    // Populate table
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "customcell", for: indexPath as IndexPath)
        cell.textLabel?.text = "\(rooms[indexPath.item][0])"
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
            let roomNum = rooms[indexPath.item][1]
            let result = self.db.execute(sql: "DELETE FROM Room WHERE roomNum=?", parameters: [roomNum])
            if result != 0 {
                rooms.remove(at: indexPath.item)
                self.roomTableView.reloadData()
            } else {
                print("Room delete failed")
            }
        }
    }
    
    // Enter selected room
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // TODO: Tell server to change rooms
        //self.defaults.set(roomNumberList[indexPath.item], forKey: "currRoom")
        
        self.roomTableView.deselectRow(at: indexPath, animated: true)
        let roomNum = rooms[indexPath.item][1]
        self.joinRoom(roomNum, false)
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
    
    // Prompt for room name, add it to local database, and tell sever about new room
    func createRoom(alert: UIAlertAction) {
        let alert = UIAlertController(title: "Create Room", message: "Name your room:", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField(configurationHandler: self.configurationTextField)
        
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ action in
            
            let displayName = self.createAddTextField.text!.trimmingCharacters(in: CharacterSet.whitespaces)
            let roomNum = Int(arc4random_uniform(999999))
            
            let overlay = Helper.loading(self.navigationController?.view, "Joining room...")
            
            SocketIOManager.createRoom(view: self, id: roomNum, displayName: displayName, callback: { (error) in
                
                overlay.removeFromSuperview()
                
                if let error = error {
                    print("Error on createRoom: \(error)")
                    if error != Constants.ERROR_TIMEOUT {
                        Helper.alert(view: self, title: "Create Room Failed", message: "Invalid response from the server")
                    }
                    return
                }
                
                
                // Insert record into local database
                let result = self.db.execute(sql: "INSERT INTO Room (RoomNum, DisplayName) VALUES (?,?)", parameters: [String(roomNum), displayName])
                if result != 0 {
                    self.rooms.append( [displayName, String(roomNum)] )
                    self.roomTableView.reloadData()
                    
                } else {
                    Helper.alert(view: self, title: "Failed to Create Room", message: "Failed to create Room")
                }
                
            })
            
            
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func joinRoom(_ roomNum: String!, _ insert: Bool!) {
        var ins = insert
        let overlay = Helper.loading(self.navigationController?.view, "Joining room...")
        
        if insert {
            for room in self.rooms {
                print("Room: \(room) -- \(roomNum)")
                if room[1] == String(describing: roomNum!) {
                    print("ADDING ROOM WE ALREADY HAVE")
                    ins = false
                }
            }
        }
        
        SocketIOManager.joinRoom(view: self, roomNum: roomNum, callback: { (roomId, roomName, error) in
            
            overlay.removeFromSuperview()
            
            if let error = error {
                if error != Constants.ERROR_TIMEOUT {
                    Helper.alert(view: self, title: "Failed to Join Room", message: "We were not able to join the specified room.")
                }
                
                print("Error on joinRoom: \(error)")
                return
            }
            
            if ins! {
                let result = self.db.execute(sql: "INSERT INTO Room (RoomNum, DisplayName) VALUES (?,?)", parameters: [roomId, roomName])
                if result != 0 {
                    self.rooms.append( [roomName, roomId] )
                    self.roomTableView.reloadData()
                } else {
                    print("Room join failed")
                    Helper.alert(view: self, title: "", message: "An error occurred while adding your room locally.")
                    return
                }
            }
            
            self.db.execute(sql: "UPDATE Room SET DisplayName=? WHERE RoomNum=?", parameters: [roomName, roomId])
            self.performSegue(withIdentifier: Constants.ENTER_ROOM, sender: [roomName, roomId] )
            
        })
    }
    
    // Send request for corresponding name to the server
    func promptJoinRoom(alert: UIAlertAction) {
        let alert = UIAlertController(title: "Join Room", message: "Enter the room number:", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addTextField(configurationHandler: self.configurationTextField)
        
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ action in
            let roomNum = self.createAddTextField.text!
            self.joinRoom(roomNum, true)
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    // Show alert for room creation/adding
    @IBAction func createAddRoom(_ sender: Any) {
        // Ask what user wants
        let alert = UIAlertController(title: "Create/Add", message: "What would you like to do?", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Create New Room", style: UIAlertActionStyle.default, handler: createRoom))
        alert.addAction(UIAlertAction(title: "Join Existing Room", style: UIAlertActionStyle.default, handler: promptJoinRoom))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any!) {
        if segue.identifier == Constants.ENTER_ROOM {
            if let dest = segue.destination as? RoomController {
                if let info = sender as? [String] {
                    if info.count >= 2 {
                        dest.homeController = self
                        dest.navigationItem.title = info[0]
                        dest.room = Room(roomController: dest, id: Int(info[1]), name: info[0])
                    }
                }
            }
        }
    }
    
}
