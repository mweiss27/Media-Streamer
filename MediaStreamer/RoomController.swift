//
//  RoomController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation
import UIKit
import Toaster
import AVFoundation
import AudioToolbox
import Alamofire

class RoomController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var homeController: HomeController?
    
    var room: Room?
    let defaults = UserDefaults()
    var spotifyPlayer: SpotifyPlayer? = nil
    
    private var logic: RoomControllerLogic?
    
    public var spotifyDelegate: SpotifyDelegate?
    
    @IBOutlet weak var currentSongName: UILabel!
    @IBOutlet weak var spotifyButton: UIButton!
    @IBOutlet weak var spotifyLoading: UIActivityIndicatorView!
    @IBOutlet weak var currentUsersTable: UITableView!
    
    @IBOutlet weak var currentPlaying: UIView!
    @IBOutlet weak var currentArtistName: UILabel!
    @IBOutlet weak var currentPlaybackTime: UIProgressView!
    
    public var onLogin: (() -> Void)?
    public var onLogout: (() -> Void)?
    public var onError: ((_ error: Error?) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.logic = RoomControllerLogic(self)
        print(">>RoomController.viewDidLoad")
        // Do any additional setup after loading the view, typically from a nib.
        
        //Remove all events from spotifyButton and mark it disabled
        self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
        self.spotifyButton.isEnabled = false
        
        self.spotifyLoading.stopAnimating()
        
        //Setup delegates for receiving callbacks
        self.spotifyDelegate = SpotifyDelegate(self)
        SpotifyApp.player.delegate = self.spotifyDelegate!
        SpotifyApp.player.playbackDelegate = self.spotifyDelegate!
        
        let session = SpotifyApp.restoreSession()
        if session == nil {
            print("Stored session is nil. Enabling Spotify with action to authenticate")
            self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
            self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedNotAuthed(_:)), for: .touchUpInside)
            self.spotifyButton.isEnabled = true
        }
        
        self.initUserTable()
        self.initGestures()
        
        print("<<RoomController.viewDidLoad")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let session = SPTAuth.defaultInstance().session
        if session != nil {
            print("session exists. Checking if our session is valid.")
            if !(session?.isValid())! {
                //Exists, but not valid. Try to renew it
                self.spotifyLoading.startAnimating()
                SPTAuth.defaultInstance().renewSession(session!, callback: { (error, renewedSession) in
                    var allow = false
                    if error != nil {
                        print("Error on renewSession: \(error?.localizedDescription)")
                        Toast(text: "Error renewing Spotify Session.").show()
                    }
                    
                    if renewedSession != nil && (renewedSession?.isValid())! {
                        print("We got a new session!")
                        SpotifyApp.saveSession(session: renewedSession!)
                        allow = true
                    }
                    else {
                        print("We didn't get a new/valid session. :(")
                        Toast(text: "No error on renew, but invalid session.").show()
                    }
                    
                    self.spotifyLoading.stopAnimating()
                    if allow {
                        //Got a valid session now. Login!
                        self.loginToPlayer()
                    }
                    else {
                        SpotifyApp.saveSession(session: nil)
                        self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
                        self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedNotAuthed(_:)), for: .touchUpInside)
                        self.spotifyButton.isEnabled = true
                    }
                })
            }
            else {
                //exists, and is valid. Login!
                print("Session is valid. Calling login")
                self.loginToPlayer()
            }
            
        }
        
        print("RoomController.viewDidAppear")
    }
    
    // Only permit 30 characters in text fields
    var createAddTextField : UITextField!
    func createTextFieldDidChange(_ textField: UITextField) {
        if (createAddTextField.text!.characters.count > 30) {
            textField.deleteBackward()
        }
    }
    
    @IBAction func requestChangeRoomName(_ sender: Any) {
        let alert = UIAlertController(title: "Change Room Name", message: "Enter new room name:", preferredStyle: UIAlertControllerStyle.alert)
        alert.addTextField(configurationHandler: self.configurationTextField)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler:{ action in
            SocketIOManager.emit("request_display_change", [self.createAddTextField.text!.trimmingCharacters(in: CharacterSet.whitespaces)], { error in
                if error != nil {
                    Helper.alert(view: self, title: "Network error", message: "An error occurred while attempting to communicate with the server.")
                    return
                }
            })
            //self.navigationItem.title.text = self.createAddTextField.text!
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
    
    private func initQueue() {
        Alamofire.request(SocketIOManager.host + "/get_queue?roomNum=" + String(describing: (self.room?.id)!)).responseJSON { response in
            print("Raw result: \(response.result.value)")
            if let json = response.result.value as? [String: Any] {
                print("json result: \(json)")
                if let queue = json["queue"] as? [[AnyObject]] {
                    print("queue result: \(queue)")
                    
                    for info in queue {
                        let _playing = info[0] as! String
                        let _uri = info[1] as! String
                        let _request_time = info[2] as! String
                        let _playback_time = info[3] as! String
                        
                        
                        let song = SpotifySong(_uri)
                        self.room?.addSong(song: song)
                        if _playing == "True" {
                            
                            let dt = Double(Helper.currentTimeMillis() - Int64(_request_time)!)
                            print("Song was added \(dt)ms ago.")
                            let time = Double(_playback_time)! + Double(dt/1000.0)
                            print("Need to scrub to \(time)s")
                            
                            self.room?.playSong(_uri, time)
                        }
                    }
                }
                else {
                    print("users is not [[AnyObject]]: \(Mirror(reflecting: (json["queue"])!).subjectType)")
                }
            }
        }
    }
    
    private func initUserTable() {
        currentUsersTable.delegate = self
        currentUsersTable.dataSource = self
        currentUsersTable.register(UITableViewCell.self, forCellReuseIdentifier: "userCell")
        currentUsersTable.allowsSelection = false
        
        addUserListener()
        
        
        SocketIOManager.emit("request sid", []) { (error) in
            if error == nil {
                SocketIOManager.once("sid_response", callback: { (data, ack) in
                    if let sid = data[0] as? String {
                        self.room?.mySid = sid
                        print("Emitting enter room")
                        SocketIOManager.emit("enter room", [(self.room?.id)!, self.defaults.string(forKey: "displayName") ?? "Anonymous"], { error in
                            if let error = error {
                                Helper.alert(view: self, title: "Failed to contact server", message: "Failed to identify with the server [2]")
                                self.navigationController?.popViewController(animated: true)
                                return
                            }
                            
                            Alamofire.request(SocketIOManager.host + "/get_users?roomNum=" + String(describing: (self.room?.id)!)).responseJSON { response in
                                print("Raw result: \(response.result.value)")
                                if let json = response.result.value as? [String: Any] {
                                    print("json result: \(json)")
                                    if let users = json["users"] as? [[String]] {
                                        print("users result: \(users)")
                                        for info in users {
                                            let sid = info[0]
                                            let name = info[1]
                                            print("Adding a user who was already here -- \(name) -- \(sid)")
                                            self.addUserToTable(sid, name)
                                        }
                                    }
                                    else {
                                        print("users is not [String]: \(Mirror(reflecting: (json["users"])!).subjectType)")
                                    }
                                }
                            }
                            
                            
                        })
                    }
                    else {
                        Helper.alert(view: self, title: "Failed to contact server", message: "Failed to identify with the server [1]")
                        self.navigationController?.popViewController(animated: true)
                    }
                })
            }
        }
        
        
    }
    
    private func initGestures() {
        let touch = UITapGestureRecognizer.init(target: self, action: #selector(self.currentPlayingTouched))
        self.currentPlaying.addGestureRecognizer(touch)
        
        let swipeLeft = UISwipeGestureRecognizer.init(target: self, action: #selector(self.currentPlayingSwiped(_:)))
        swipeLeft.direction = .left
        self.currentPlaying.addGestureRecognizer(swipeLeft)
        
        let swipeUp = UISwipeGestureRecognizer.init(target: self, action: #selector(self.currentPlayingSwiped(_:)))
        swipeUp.direction = .up
        self.currentPlaying.addGestureRecognizer(swipeUp)
    }
    
    func spotifyButtonClickedAuthed(_ sender: UIButton!) {
        print("spotifyButtonClickedAuthed")
        self.performSegue(withIdentifier: Constants.RoomToSpotify, sender: self)
    }
    
    func spotifyButtonClickedNotAuthed(_ sender: UIButton!) {
        print("spotifyButtonClickedNotAuthed")
        (UIApplication.shared.delegate as? AppDelegate)?.roomController = self
        if SPTAuth.spotifyApplicationIsInstalled() && SPTAuth.supportsApplicationAuthentication() {
            UIApplication.shared.open(SPTAuth.defaultInstance().spotifyAppAuthenticationURL(), options: [ : ], completionHandler: nil)
        }
        else {
            let loginURL = SPTAuth.loginURL(forClientId: Constants.clientID,
                                            withRedirectURL: URL(string: Constants.SpotifyRedirectURI),
                                            scopes: Constants.requestedScopes,
                                            responseType: "code")
            
            print("loginURL: \(loginURL!)")
            UIApplication.shared.open(loginURL!, options: [:], completionHandler: nil)
        }
        
    }
    
    public func handleSpotifyAuthentication(session: SPTSession!) {
        print("RoomController.handleSpotifyLogin")
        if session.isValid() {
            SpotifyApp.saveSession(session: session)
            print("[1] We have a valid session. We need login to the player")
            self.loginToPlayer()
        }
        else {
            print("We attempted to login, but the session isn't valid!")
        }
    }
    
    @objc private func loginToPlayer() {
        if (!SpotifyApp.player.initialized || !SpotifyApp.player.loggedIn) {
            self.onLogin = {
                print("self.onLogin called!")
                
                self.spotifyLoading.stopAnimating()
                self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
                self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedAuthed(_:)), for: .touchUpInside)
                self.spotifyButton.isEnabled = true
                
                self.onLogin = nil
                self.onError = nil
                print("We're logged in. Initializing queue")
                self.initQueue()
            }
            self.onError = { (error: Error?) in
                print("self.onError")
                Toast(text: "Unable to login to Spotify Player").show()
                
                self.spotifyLoading.stopAnimating()
                self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
                self.spotifyButton.addTarget(self, action: #selector(self.loginToPlayer), for: .touchUpInside)
                self.spotifyButton.isEnabled = true
                
                self.onLogin = nil
                self.onError = nil
            }
            self.spotifyLoading.startAnimating()
            SpotifyApp.loginToPlayer()
        }
        else {
            print("Player is already logged in")
            self.spotifyLoading.stopAnimating()
            self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
            self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedAuthed(_:)), for: .touchUpInside)
            self.spotifyButton.isEnabled = true
            
            if self.isMovingToParentViewController {
                print("isMovingToParentViewController")
                self.initQueue()
            }
            else {
                print("viewDidAppear, but we aren't joining the room")
            }
        }
    }
    
    // Return number of rows in table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.room?.numUsers())!
    }
    
    // Populate table
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath as IndexPath)
        let tuple = self.room?.getUser(index: indexPath.item)
        if tuple != nil {
            cell.textLabel?.text = tuple!.1
        }
        else {
            cell.textLabel?.text = "Unknown"
        }
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let identifier = segue.identifier
        
        if identifier == "room_to_spotify" {
            if let dest = segue.destination as? SpotifySearchController {
                dest.roomController = self
            }
        }
        else if identifier == "room_to_player" {
            print("Preparing for room_to_player")
            if let dest = segue.destination as? SpotifyPlayer {
                dest.roomController = self
                
                if let metadata = SpotifyApp.player.metadata {
                    if let currentTrack = metadata.currentTrack {
                        if dest.songName != nil {
                            print("Setting songName")
                            dest.songName.text = currentTrack.name
                        }
                        else {
                            print("Caching songName")
                            dest._songName = currentTrack.name
                        }
                        
                        if dest.artistName != nil {
                            print("Setting artistName")
                            dest.artistName.text = currentTrack.artistName
                        }
                        else {
                            print("Caching artistName")
                            dest._artistName = currentTrack.artistName
                        }
                        
                        if dest.albumArt != nil {
                            print("Setting albumArt")
                            dest.setImage(currentTrack.albumCoverArtURL)
                        }
                        else {
                            print("Caching imageURL")
                            dest._imageURL = currentTrack.albumCoverArtURL
                        }
                        
                        
                        if let playbackState = SpotifyApp.player.playbackState {
                            if dest.pausePlay != nil {
                                print("Setting isPlaying")
                                dest.pausePlay.setImage(UIImage(named:playbackState.isPlaying ? "pauseButton" : "playButton"), for: .normal)
                            }
                            else {
                                print("Caching isPlaying")
                                dest._isPlaying = playbackState.isPlaying
                            }
                        }
                    }
                }
                
                self.spotifyDelegate?.spotifyPlayer = dest
            }
        }
    }
    
    override func viewDidDisappear(_ animated : Bool) {
        super.viewDidDisappear(animated)
        
        print("viewWillDisappear")
        if (self.isMovingFromParentViewController) {
            
            if SpotifyApp.player.initialized && SpotifyApp.player.loggedIn {
                SpotifyApp.player.setIsPlaying(false, callback: { (error) in
                    if let error = error {
                        print("Error on setIsPlaying false: \(error)")
                        return
                    }
                })
            }
            
            self.removeUserListener()
            SocketIOManager.emit("leave room", [], nil)
            self.defaults.removeObject(forKey: "currRoom")
        }
    }
    
    @IBAction func unwindToRoom(segue: UIStoryboardSegue) {
        print("RoomController.unwind")
    }
    
    func currentPlayingTouched() {
        print("Tapped currentPlaying")
        if self.room?.currentSong != nil {
            print("We're currently playing a song. Transitioning to SpotifyPlayer")
            self.performSegue(withIdentifier: "room_to_player", sender: self)
        }
        else {
            Toast(text: "The queue is currently empty", delay: 0, duration: 0.5).show()
        }
    }
    
    @objc func currentPlayingSwiped(_ gesture: UISwipeGestureRecognizer) {
        //left means next
        if gesture.direction == .left {
            if self.room?.currentSong != nil {
                self.requestNext()
            }
        }
        else if gesture.direction == .up {
            self.currentPlayingTouched()
        }
    }
    
    func addUserToTable(_ sid: String!, _ name: String!) {
        if (self.room?.addUser(sid: sid, name: name))! {
            self.currentUsersTable.reloadData()
        }
    }
    
    func removeUserListener() {
        SocketIOManager.off("add user")
        SocketIOManager.off("remove user")
        SocketIOManager.off("connect")
        SocketIOManager.off("client_add")
        SocketIOManager.off("client_play")
        SocketIOManager.off("client_remove")
        SocketIOManager.off("client_pause")
        SocketIOManager.off("client_resume")
        SocketIOManager.off("client_stop")
        SocketIOManager.off("client_scrub")
        SocketIOManager.off("client_change_display")
    }
    
    func addUserListener() {
        
        print("Registering add user")
        SocketIOManager.on("add user", callback: { (data, ack) in
            print("add user response: \(data)")
            if let values = data[0] as? [String] {
                let sid = values[0], name = values[1]
                if sid != self.room?.mySid {
                    print("add user received, it's not me -- \(name) -- \(sid)")
                    self.addUserToTable(sid, name)
                }
                else {
                    print("add user, but it's me. Ignoring")
                }
            }
            else {
                print("Invalid data line: \(data[0]) -- (\(data.count))")
            }
        })
        
        print("Registering remove user")
        SocketIOManager.on("remove user", callback: {[weak self] data, ack in
            print("remove user -- \(data)")
            if let sidRemoving = data[0] as? String {
                if (self?.room?.removeUser(sid: sidRemoving))! {
                    self?.currentUsersTable.reloadData()
                }
            }
            else {
                print("invalid data param")
            }
        })
        
        print("Registering connect")
        SocketIOManager.on("connect", callback: {[weak self] data, ack in
            print("connect")
            self?.room?.clearUsers()
            let defaults = UserDefaults()
            let currRoom = defaults.string(forKey: "currRoom")
            if currRoom != nil{
                let nickname = defaults.string(forKey: "displayName")
                if nickname != nil{
                    SocketIOManager.emit("enter room", [currRoom!, nickname!], nil)
                }else{
                    SocketIOManager.emit("enter room", [currRoom!, "Anonymous"], nil)
                }
            }
        })
        
        print("Registering client_add")
        SocketIOManager.on("client_add", callback: {[weak self] data, ack in
            print("client_add received: \(data)")
            if let info = data[0] as? [String] {
                if let id = info[0] as? String {
                    self?.room?.addSong(song: SpotifySong(id))
                }
                else {
                    print("No id attached with client_add")
                }
            }
            else {
                print("Invalid data. Expected a [String]")
            }
        })
        
        print("Registering client_play")
        SocketIOManager.on("client_play", callback: {[weak self] data, ack in
            print("client_play")
            if let info = data[0] as? [String] {
                if info.count >= 2 {
                    let songId = info[0]
                    let startTime = info[1]
                    let now = Helper.currentTimeMillis()
                    print("client_play received: \(songId) -- \(startTime)")
                    print("Now: \(now)")
                    
                    var dt = Double(now - Int64(startTime)!) / 1000.0
                    if dt < 0 {
                        print("[ERROR] dt is subzero! \(dt)")
                        dt = 0.0
                    }
                    print("Valid client_play: \(songId) -- \(startTime)")
                    print("startTime: dt=\(dt)")
                    
                    self?.room?.playSong(songId, dt)
                }
                else {
                    print("[ERROR] info.count is not >= 2")
                }
            }
            else {
                print("[ERROR] data is not a [String]")
            }
        })
        
        SocketIOManager.on("client_remove", callback: { [weak self] data, ack in
            print("client_remove: \(data)")
            if let info = data[0] as? [String] {
                let songId = info[0]
                print("Removing \(songId) from queue")
                self?.room?.removeFromMediaQueue(id: songId)
            }
            else {
                print("info is not a [String] -- \(Mirror(reflecting: data[0]).subjectType)")
            }
        })
        
        print("Registering client_pause")
        SocketIOManager.on("client_pause", callback: { [weak self] data, ack in
            print("client_pause received")
            self?.room?.setPlaying(false, callback: { error in
                if error == nil {
                    print("client_pause success")
                }
            })
        })
        
        print("Registering client_resume")
        SocketIOManager.on("client_resume", callback: { [weak self] data, ack in
            print("client_resume received")
            if let info = data[0] as? [String] {
                if info.count > 0 {
                    let songId = info[0]
                    let resume_time = info[1]
                    let responseTime = info[2]
                    let dt = Double(Helper.currentTimeMillis() - Int64(responseTime)!) / 1000.0
                    if self?.room?.currentSong != nil {
                        self?.room?.setPlaying(true, callback: { error in
                            if error == nil {
                                self?.room?.seek(to: Double(resume_time)! + dt - 1, callback: { error in
                                    print("client_resume success")
                                })
                            }
                        })
                    }
                    else {
                        self?.room?.playSong(songId, Double(resume_time)! + dt)
                    }
                }
                
            }
            else {
                print("Invalid info. Expected [String]. Got: \(Mirror(reflecting: data[0]).subjectType)")
            }
        })
        
        print("Registering client_stop")
        SocketIOManager.on("client_stop", callback: { [weak self] data, ack in
            print("client_stop")
            
            if self?.room?.currentSong != nil {
                SpotifyApp.player.setIsPlaying(false, callback: { error in
                    if error != nil {
                        Helper.alert(view: self, title: "Error while stopping", message: "An error occurred while attempting to stop the player.")
                    }
                })
            }
            
            self?.room?.currentSong = nil
            self?.room?.currentQueue = []
            
            self?.currentSongName.text = ""
            self?.currentArtistName.text = ""
            self?.currentPlaybackTime.progress = 0.0
            
            if let player = self?.spotifyPlayer {
                player.performSegue(withIdentifier: Constants.UnwindToRoom, sender: player)
            }
        })
        
        print("Registering client_scrub")
        SocketIOManager.on("client_scrub", callback: { [weak self] data, ack in
            print("client_scrub")
            if let info = data[0] as? [String] {
                let scrub_time = Double(info[0])!
                let response_time = Double(info[1])!
                let now = Double(Helper.currentTimeMillis())
                
                
                let dt = (now - response_time) / 1000.0
                print("Received playback: \(time) -- dt: \(dt)")
                self?.room?.seek(to: scrub_time + dt, callback: { error in
                    if error != nil {
                        print("error on client_playback seek")
                    }
                })
            }
            else {
                print("Invalid info. Expected [String]. Got: \(Mirror(reflecting: data[0]).subjectType)")
            }
        })
        
        print("Registering client_change_display. HomeController: \(self.homeController)")
        SocketIOManager.on("client_change_display", callback: { data, ack in
            if let info = data[0] as? [String] {
                let newName = info[0]
                self.navigationItem.title = newName

                
                let result = self.homeController?.db.execute(sql: "UPDATE Room SET DisplayName=? WHERE RoomNum=?", parameters: [newName, (self.room?.id)!])
                
                if result != 0 {
                    print("Result: \(result)")
                    Toast.init(text: "Room name changed", delay: 0, duration: 1.5).show()
                }
                else {
                    print("nil result")
                    Toast.init(text: "Failed to change room name", delay: 0, duration: 1.5).show()
                }
            }
            else {
                print("info is not a [String]")
            }
        })
        
    }
    
    func requestNext() {
        //Expects a response of 'client_play' or 'client_stop'
        SocketIOManager.emit("request_next", [], { error in
            if error != nil {
                Helper.alert(view: self, title: "Network Error", message: "An error occurred while communicating with the server.")
                return
            }
            
        })
    }
    
    func requestPause() {
        //Expects a response of 'client_pause'
        SocketIOManager.emit("request_pause", [], { error in
            if error != nil {
                Helper.alert(view: self, title: "Network Error", message: "An error occurred while communicating with the server.")
                return
            }
        })
    }
    
    func requestResume() {
        //Expects a response of 'client_resume'
        if let playback = SpotifyApp.player.playbackState {
            let resume_time = playback.position
            SocketIOManager.emit("request_resume", [resume_time], { error in
                if error != nil {
                    Helper.alert(view: self, title: "Network Error", message: "An error occurred while communicating with the server.")
                    return
                }
            })
        }
    }
    
    func requestRemove(_ song: SpotifySong) {
        SocketIOManager.emit("request_remove", [song.id], { error in
            if error != nil {
                Helper.alert(view: self, title: "Network Error", message: "An error occurred while communicating with the server.")
                return
            }
        })
    }
    
    func requestScrub(_ to: Double) {
        //Expects a response of 'client_scrub'
        SocketIOManager.emit("request_scrub", [to], { error in
            if error != nil {
                Helper.alert(view: self, title: "Network Error", message: "An error occurred while communicating with the server.")
                return
            }
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("didReceiveMemoryWarning")
    }
    
}
