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
    
    var room: Room?
    let defaults = UserDefaults()
    
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
                self.loginToPlayer()
            }
            
        }
        
        print("RoomController.viewDidAppear")
    }
    
    private func initUserTable() {
        currentUsersTable.delegate = self
        currentUsersTable.dataSource = self
        currentUsersTable.register(UITableViewCell.self, forCellReuseIdentifier: "userCell")
        currentUsersTable.allowsSelection = false
        
        addUserListener()
        
        Alamofire.request(SocketIOManager.host + "/get_users?roomNum=" + String(describing: (self.room?.id)!)).responseJSON { response in
            print("Raw result: \(response.result.value)")
            if let json = response.result.value as? [String: Any] {
                print("json result: \(json)")
                if let users = json["users"] as? [[String]] {
                    print("users result: \(users)")
                    for info in users {
                        let sid = info[0]
                        let name = info[1]
                        self.addUserToTable(sid, name)
                    }
                }
                else {
                    print("users is not [String]: \(Mirror(reflecting: (json["users"])!).subjectType)")
                }
            }
        }
        
        SocketIOManager.emit("request sid", []) { (error) in
            if error == nil {
                SocketIOManager.once("sid_response", callback: { (data, ack) in
                    if let sid = data[0] as? String {
                        self.room?.mySid = sid
                    }
                })
            }
        }
        
        print("Emitting enter room")
        SocketIOManager.emit("enter room", [(self.room?.id)!, self.defaults.string(forKey: "displayName") ?? "Anonymous"], { error in
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
                                            withRedirectURL: URL(string: Constants.redirectURL),
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
            self.spotifyLoading.stopAnimating()
            self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
            self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedAuthed(_:)), for: .touchUpInside)
            self.spotifyButton.isEnabled = true
        }
    }
    
    // Return number of rows in table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.room?.users.count)!
    }
    
    // Populate table
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath as IndexPath)
        cell.textLabel?.text = self.room?.users[indexPath.item]?.1
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
            SocketIOManager.emit("leave room", [String(self.room!.id)], nil)
            self.defaults.removeObject(forKey: "currRoom")
        }
    }
    
    @IBAction func unwindToRoom(segue: UIStoryboardSegue) {
        print("RoomController.unwind")
    }
    
    func currentPlayingTouched() {
        print("Tapped currentPlaying")
        if self.room?.queue.currentMedia != nil || (self.room?.queue.count)! > 0 {
            print("We're currently playing a SpotifySong. Transitioning to SpotifyPlayer")
            self.performSegue(withIdentifier: "room_to_player", sender: self)
        }
        else {
            Toast(text: "The queue is currently empty", delay: 0, duration: 0.5).show()
        }
    }
    
    @objc func currentPlayingSwiped(_ gesture: UISwipeGestureRecognizer) {
        //left means next
        if gesture.direction == .left {
            if self.room?.queue.currentMedia != nil {
                if !(self.room?.playNextSong(startTime: 0.0, true))! {
                    self.currentSongName.text = ""
                    self.currentArtistName.text = ""
                    self.currentPlaybackTime.progress = 0
                }
            }
        }
        else if gesture.direction == .up {
            self.currentPlayingTouched()
        }
    }
    
    func addUserToTable(_ sid: String!, _ name: String!) {
        var found = false
        for i in (self.room?.users.keys)! {
            let tuple = self.room?.users[i]
            if tuple?.0 == sid {
                found = true
                break
            }
        }
        if !found {
            self.room?.users[(self.room?.users.count)!] = (sid, name)
            self.currentUsersTable.reloadData()
        }
    }
    
    func removeUserListener() {
        SocketIOManager.off("add user")
        SocketIOManager.off("remove user")
        SocketIOManager.off("connect")
        SocketIOManager.off("client_add")
        
    }
    
    func addUserListener(){
        print("Registering add user")
        SocketIOManager.on("add user", callback: { (data, ack) in
            print("add user response: \(data)")
            if let values = data[0] as? [String] {
                let sid = values[0], name = values[1]
                self.addUserToTable(sid, name)
            }
            else {
                print("Invalid data line: \(data[0]) -- (\(data.count))")
            }
        })
        
        print("Registering remove user")
        SocketIOManager.on("remove user") {[weak self] data, ack in
            print("remove user -- \(data)")
            if let sidRemoving = data[0] as? String {
                for i in 0..<(self?.room?.users.count)! {
                    if let sidHave = self?.room?.users[i]?.0 {
                        if sidHave == sidRemoving {
                            print("Found a matching SID in our room. Removing it")
                            self?.room?.users.removeValue(forKey: i)
                            self?.currentUsersTable.reloadData()
                            break
                        }
                    }
                }
            }
            else {
                print("invalid data param")
            }
        }
        
        print("Registering connect")
        SocketIOManager.on("connect") {[weak self] data, ack in
            self?.room?.users.removeAll()
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
        }
        
        print("Registering client_add")
        SocketIOManager.on("client_add") {[weak self] data, ack in
            print("client_add received: \(data)")
            if let id = data[0] as? String {
                self?.room?.addToMediaQueue(song: SpotifySong(id: id))
            }
        }
        
        print("Registering client_play")
        SocketIOManager.on("client_play") {[weak self] data, ack in
            if let info = data[0] as? [String] {
                let sid = info[0]
                let songId = info[1]
                let requestTime = info[2]
                let dt = Double(Helper.currentTimeMillis() - Int64(requestTime)!) / 1000.0
                if sid != self?.room?.mySid {
                    self?.room?.playNextSong(startTime: dt, false)
                    print("Valid client_play: \(sid) -- \(songId) -- \(requestTime)")
                }
                else {
                    print("This is our play request. Ignoring")
                }
            }
        }
        
        print("Registering client_pause")
        SocketIOManager.on("client_pause") { [weak self] data, ack in
            print("client_pause received")
            self?.room?.pause(false)
        }
        
        print("Registering client_resume")
        SocketIOManager.on("client_resume") { [weak self] data, ack in
            print("client_resume received")
            if let info = data[0] as? [String] {
                let sid = info[0]
                let playbackTime = info[1]
                let requestTime = info[2]
                let dt = Double(Helper.currentTimeMillis() - Int64(requestTime)!) / 1000.0
                self?.room?.resume(false)
                self?.room?.seek(to: Double(playbackTime)! + dt)
            }
        }
        
    }
    
}
