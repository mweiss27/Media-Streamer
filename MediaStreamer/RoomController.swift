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
        
        self.logic?.setupSocket()
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
                    
                    var playing = false
                    for info in queue {
                        let _playing = info[0] as! String
                        let _uri = info[1] as! String
                        let _request_time = info[2] as! String
                        let _playback_time = info[3] as! String
                        
                        
                        let song = SpotifySong(_uri)
                        self.room?.addSong(song: song)
                        if !playing && _playing == "True" {
                            
                            let dt = Double(Helper.currentTimeMillis() - Int64(_request_time)!)
                            print("Song was added \(dt)ms ago.")
                            let time = Double(_playback_time)! + Double(dt/1000.0)
                            print("Need to scrub to \(time)s")
                            
                            self.room?.playSong(_uri, time)
                            playing = true
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
            
            self.logic?.cleanupSocket()
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
