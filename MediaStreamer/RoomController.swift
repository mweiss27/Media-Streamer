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

class RoomController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    var homeController: HomeController?
    
    var room: Room?
    let defaults = UserDefaults()
    var spotifyPlayer: SpotifyPlayer? = nil
    
    private var logic: RoomControllerLogic?
    
    public var spotifyDelegate: SpotifyDelegate?
    
    private var queueVisible = false
    @IBOutlet weak var queueButton: UIButton!
    
    @IBOutlet weak var inviteButton: UIButton!
    @IBOutlet weak var spotifyButton: UIButton!
    @IBOutlet weak var spotifyLoading: UIActivityIndicatorView!
    @IBOutlet weak var currentUsersTable: UITableView!
    @IBOutlet weak var currentQueueTable: UITableView!
    
    @IBOutlet weak var hereNow: UILabel!
    @IBOutlet weak var currentPlaying: UIView!
    @IBOutlet weak var currentSongName: UILabel!
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
        
        self.spotifyPlayer = self.storyboard?.instantiateViewController(withIdentifier: "spotify_player") as? SpotifyPlayer
        self.spotifyPlayer?.roomController = self
        self.spotifyDelegate?.spotifyPlayer = self.spotifyPlayer
        
        let session = SpotifyApp.restoreSession()
        if session == nil {
            print("Stored session is nil. Enabling Spotify with action to authenticate")
            self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
            self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedNotAuthed(_:)), for: .touchUpInside)
            self.spotifyButton.isEnabled = true
        }
        
        self.logic?.setupSocket()
        self.initUserTable()
        self.initQueueTable()
        self.initGestures()
        
        self.becomeFirstResponder()
        
        print("<<RoomController.viewDidLoad")
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            if let state = SpotifyApp.player.playbackState {
                if state.isPlaying {
                    self.requestPause()
                }
                else {
                    self.requestResume()
                }
            }
        }
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
            SocketIOManager.emit("request_display_change", [self.createAddTextField.text!.trimmingCharacters(in: CharacterSet.whitespaces)], true, { error in
                if error != nil {
                    Helper.alert(title: "Network error", message: "An error occurred while attempting to communicate with the server.")
                    return
                }
            })
            //self.navigationItem.title.text = self.createAddTextField.text!
        }))
        self.createAddTextField.text = self.room?.name
        self.present(alert, animated: true, completion: nil)
    }
    
    // Setup text fields for alerts
    func configurationTextField(textField: UITextField!)
    {
        self.createAddTextField = textField!
        self.createAddTextField.autocapitalizationType = UITextAutocapitalizationType.words
        self.createAddTextField.addTarget(self, action: #selector(createTextFieldDidChange(_:)), for: .editingChanged)
        
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return false
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
                        let _name = info[2] as! String
                        let _artist = info[3] as! String
                        let _request_time = info[4] as! String
                        let _playback_time = info[5] as! String
                        
                        let song = SpotifySong(_uri, _name)
                        self.room?.addSong(song: song)
                        
                        var dt = Double(Helper.currentTimeMillis() - Int64(_request_time)!)
                        if dt < 0 {
                            dt = 0
                        }
                        let time = Double(_playback_time)! + Double(dt/1000.0)
                        
                        if !playing && _playing == "True" {
                            
                            
                            print("Song was added \(dt)ms ago.")
                            print("Need to scrub to \(time)s")
                            
                            self.room?.playSong(_uri, time)
                            playing = true
                        }
                        else if self.room?.currentQueue.count == 1 {
                            //First song added, but it looks like the room is paused
                            self.displaySongName(songName: _name)
                            self.displayArtistName(artistName: _artist)
                            self.displayProgress(progress: 0.33)
                            self.room?.currentSong = SpotifySong.init(_uri, _name)
                        }
                    }
                }
                else {
                    print("users is not [[AnyObject]]: \(Mirror(reflecting: (json["queue"])!).subjectType)")
                }
            }
        }
    }
    
    private func initQueueTable() {
        self.currentQueueTable.delegate = self
        self.currentQueueTable.dataSource = self
        self.currentQueueTable.register(UITableViewCell.self, forCellReuseIdentifier: "queueCell")
    }
    
    private func initUserTable() {
        currentUsersTable.delegate = self
        currentUsersTable.dataSource = self
        currentUsersTable.register(UITableViewCell.self, forCellReuseIdentifier: "userCell")
        currentUsersTable.allowsSelection = false
        
        SocketIOManager.emit("request sid", [], false, { error in
            if error == nil {
                SocketIOManager.once("sid_response", callback: { (data, ack) in
                    if let sid = data[0] as? String {
                        self.room?.mySid = sid
                        print("Emitting enter room")
                        SocketIOManager.emit("enter room", [(self.room?.id)!, self.defaults.string(forKey: "displayName") ?? "Anonymous"], false, { error in
                            if let error = error {
                                Helper.alert(title: "Failed to contact server", message: "Failed to identify with the server [2]")
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
                        Helper.alert(title: "Failed to contact server", message: "Failed to identify with the server [1]")
                        self.navigationController?.popViewController(animated: true)
                    }
                })
            }
        })
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
    
    // Allow rows to be deleted
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return tableView == self.currentQueueTable
    }
    
    // Delete a row
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if tableView == self.currentQueueTable {
            if (editingStyle == UITableViewCellEditingStyle.delete) {
                print("Attempting to delete QueueItem #\(indexPath.item + 1)")
                let song = self.room?.currentQueue[indexPath.item + 1]
                self.requestRemove(song!)
                self.currentQueueTable.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    // Return number of rows in table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.currentUsersTable {
            return (self.room?.numUsers())!
        }
        else {
            return (self.room?.currentQueue.count)! - 1
        }
    }
    
    // Populate table
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == self.currentUsersTable {
            print("populate, users")
            let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath as IndexPath)
            let tuple = self.room?.getUser(index: indexPath.item)
            print("User at \(indexPath.item) -- \(tuple)")
            if tuple != nil {
                cell.textLabel?.text = tuple!.1
            }
            else {
                cell.textLabel?.text = "Unknown"
            }
            return cell
        }
        else {
            print("Populate, not users!")
            let cell = tableView.dequeueReusableCell(withIdentifier: "queueCell", for: indexPath as IndexPath)
            let song = self.room?.currentQueue[indexPath.item + 1]
            print("Song at \(indexPath.item) -- \(song?.name)")
            cell.textLabel?.text = song?.name
            return cell
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let identifier = segue.identifier
        
        if identifier == "room_to_spotify" {
            if let dest = segue.destination as? SpotifySearchController {
                dest.roomController = self
            }
        }
    }
    
    private func preparePlayer() {
        if let dest = self.spotifyPlayer {
            
            if let metadata = SpotifyApp.player.metadata {
                if let currentTrack = metadata.currentTrack {
                    self.displaySongName(songName: currentTrack.name)
                    self.displayArtistName(artistName: currentTrack.artistName)
                    self.setAlbumArtURL(url: currentTrack.albumCoverArtURL!)
                    
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
            SocketIOManager.emit("leave room", [], false, nil)
            self.defaults.removeObject(forKey: "currRoom")
        }
    }
    
    @IBAction func unwindToRoom(segue: UIStoryboardSegue) {
        print("RoomController.unwind")
    }
    
    @IBAction func inviteButtonClicked(_ sender: Any) {
        self.promptInvite()
    }
    
    func currentPlayingTouched() {
        print("Tapped currentPlaying")
        if self.room?.currentSong != nil {
            print("We're currently playing a song. Transitioning to SpotifyPlayer")
            self.preparePlayer()
            self.present(self.spotifyPlayer!, animated: true, completion: {})
            //self.performSegue(withIdentifier: "room_to_player", sender: self)
        }
        else {
            Toast(text: "The queue is currently empty", delay: 0, duration: 0.5).show()
        }
    }
    
    func promptInvite() {
        let alert = UIAlertController(title: "Invite Code", message: "Send your room number to a friend", preferredStyle: UIAlertControllerStyle.alert)
        alert.addTextField(configurationHandler: self.configurationTextField)
        alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        
        self.createAddTextField.text = String(describing: (self.room?.id)!)
        self.createAddTextField.delegate = self
        self.present(alert, animated: true, completion: nil)
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
    
    func displaySongName(songName: String) {
        self.currentSongName.text = songName
        if let player = self.spotifyPlayer {
            if player.songName != nil {
                player.songName.text = songName
            }
            else {
                player._songName = songName
            }
        }
    }
    
    func displayArtistName(artistName: String) {
        self.currentArtistName.text = artistName
        if let player = self.spotifyPlayer {
            if player.artistName != nil {
                player.artistName.text = artistName
            }
            else {
                player._artistName = artistName
            }
        }
    }
    
    func displayProgress(progress: Float) {
        self.currentPlaybackTime.progress = progress
        if let player = self.spotifyPlayer {
            if player.progressSlider != nil {
                player.progressSlider.value = progress
            }
        }
    }
    
    func setAlbumArtURL(url: String) {
        if let player = self.spotifyPlayer {
            if player.albumArt != nil {
                player.setImage(url)
            }
            else {
                player._imageURL = url
            }
        }
    }
    
    func requestNext() {
        //Expects a response of 'client_play' or 'client_stop'
        let time = Helper.currentTimeMillis()
        SocketIOManager.emit("request_next", [Int(time)], true, { error in
            if error != nil {
                Helper.alert(title: "Network Error", message: "An error occurred while communicating with the server.")
                
                return
            }
            
        })
    }
    
    func requestPause() {
        //Expects a response of 'client_pause'
        SocketIOManager.emit("request_pause", [], true, { error in
            if error != nil {
                Helper.alert(title: "Network Error", message: "An error occurred while communicating with the server.")
                return
            }
        })
    }
    
    func requestResume() {
        //Expects a response of 'client_resume'
        let time = Helper.currentTimeMillis()
        if let playback = SpotifyApp.player.playbackState {
            let resume_time = playback.position
            SocketIOManager.emit("request_resume", [resume_time, Int(time)], true, { error in
                if error != nil {
                    Helper.alert(title: "Network Error", message: "An error occurred while communicating with the server.")
                    
                    return
                }
            })
        }
    }
    
    func requestRemove(_ song: SpotifySong) {
        SocketIOManager.emit("request_remove", [song.id], true, { error in
            if error != nil {
                Helper.alert(title: "Network Error", message: "An error occurred while communicating with the server.")
                
                return
            }
        })
    }
    
    func requestScrub(_ to: Double) {
        //Expects a response of 'client_scrub'
        let time = Helper.currentTimeMillis()
        print("request_scrub -- \(to)")
        SocketIOManager.emit("request_scrub", [to, Int(time)], true, { error in
            if error != nil {
                Helper.alert(title: "Network Error", message: "An error occurred while communicating with the server.")
                
                return
            }
        })
    }
    
    
    @IBAction func queueButtonClicked(_ sender: Any) {
        print("QUEUE")
        if self.queueVisible {
            //BACK TO NORMAL
            self.hereNow.text = "Here Now:"
            self.inviteButton.isHidden = false
            self.currentUsersTable.isHidden = false
            self.currentQueueTable.isHidden = true
        }
        else {
            //TO QUEUE
            self.hereNow.text = "Current Queue:"
            self.inviteButton.isHidden = true
            self.currentUsersTable.isHidden = true
            self.currentQueueTable.isHidden = false
        }
        self.queueVisible = !self.queueVisible
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("didReceiveMemoryWarning")
    }
    
}
