//
//  RoomController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit
import Toaster
import AVFoundation
import AudioToolbox

class RoomController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var room: Room?
    let defaults = UserDefaults()
    
    private var spotifyDelegate: SpotifyDelegate?
    let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    @IBOutlet weak var currentSongName: UILabel!
    @IBOutlet weak var spotifyButton: UIButton!
    @IBOutlet weak var currentUsersTable: UITableView!
    
    @IBOutlet weak var currentPlaying: UIView!
    @IBOutlet weak var currentArtistName: UILabel!
    @IBOutlet weak var currentPlaybackTime: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
        self.tryInitSpotify { (result) in
            if result {
                self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedAuthed(_:)), for: .touchUpInside)
                
                self.spotifyDelegate = SpotifyDelegate(self)
                SpotifyApp.instance.player.delegate = self.spotifyDelegate!
                SpotifyApp.instance.player.playbackDelegate = self.spotifyDelegate!
                
            }
            else {
                self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedNotAuthed(_:)), for: .touchUpInside)
            }
            self.spotifyButton.isEnabled = true
        }
        
        currentUsersTable.delegate = self
        currentUsersTable.dataSource = self
        currentUsersTable.register(UITableViewCell.self, forCellReuseIdentifier: "userCell")
        currentUsersTable.allowsSelection = false
        addUserListener()
        
        let touch = UITapGestureRecognizer.init(target: self, action: #selector(self.currentPlayingTouched))
        self.currentPlaying.addGestureRecognizer(touch)
        
        print("RoomController loaded")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if SPTAuth.defaultInstance().session != nil && SPTAuth.defaultInstance().session.isValid() {
            //Start it if it isn't currently started
            SpotifyApp.instance.startPlayer()
        }
        
        print("RoomController is displayed")
    }
    
    private func tryInitSpotify(callback: @escaping (Bool) -> ()) {
        if let storedSession: SPTSession = SpotifyApp.restoreSession() {
            print("We have a session stored!")
            if storedSession.isValid() {
                print("[2] We have a valid session. We need to transition to the info view")
                callback(true)
            }
            else {
                if SPTAuth.defaultInstance().hasTokenRefreshService {
                    print("Our session is invalid. Let's try to refresh it")
                    print("Our encrypted_refresh_token: \(storedSession.encryptedRefreshToken)")
                    SPTAuth.defaultInstance().renewSession(storedSession, callback: { (error, renewedSession) in
                        if error != nil {
                            print("Error on renewSession: \(error?.localizedDescription)")
                            callback(false)
                        }
                        
                        if renewedSession != nil && (renewedSession?.isValid())! {
                            print("We got a new session!")
                            SpotifyApp.saveSession(session: renewedSession!)
                            callback(true)
                            
                        }
                        else {
                            print("We didn't get a new/valid session. :(")
                            callback(false)
                        }
                    })
                }
            }
        }
        else {
            print("We didn't find a stored session")
            callback(false)
        }
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
            
            print("loginURL: \(loginURL)")
            UIApplication.shared.open(loginURL!, options: [:], completionHandler: nil)
        }
        
    }
    
    public func handleSpotifyLogin(session: SPTSession!) {
        print("RoomController.handleSpotifyLogin")
        SpotifyApp.saveSession(session: session!)
        if session.isValid() {
            print("[1] We have a valid session. We need to transition to spotify browser")
            self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
            self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedAuthed(_:)), for: .touchUpInside)
            
            SpotifyApp.saveSession(session: session)
            self.performSegue(withIdentifier: "room_to_spotify", sender: self)
        }
        else {
            print("We attempted to login, but the session isn't valid!")
        }
    }
    
    // Return number of rows in table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.room?.users.count)!
    }
    
    // Populate table
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath as IndexPath)
        cell.textLabel?.text = self.room?.users[indexPath.item]
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
                
                if let metadata = SpotifyApp.instance.player.metadata {
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
                        
                        
                        if let playbackState = SpotifyApp.instance.player.playbackState {
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
    
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        
        if (self.isMovingFromParentViewController){
            SocketIOManager.socket.emit("leave room", String(self.room!.id))
            self.defaults.removeObject(forKey: "currRoom")
        }
    }
    
    @IBAction func unwindToRoom(segue: UIStoryboardSegue) {
        print("RoomController.unwind")
    }
    
    func currentPlayingTouched() {
        print("Tapped currentPlaying")
        if self.room?.queue.currentMedia != nil || (self.room?.queue.count)! > 0 {
            if self.room?.queue.currentMedia is SpotifySong || self.room?.queue.front is SpotifySong {
                print("We're currently playing a SpotifySong. Transitioning to SpotifyPlayer")
                
                self.performSegue(withIdentifier: "room_to_player", sender: self)
            }
        }
        else {
            Toast(text: "The queue is currently empty", delay: 0, duration: 0.5).show()
        }
    }
    
    func addUserListener(){
        SocketIOManager.socket.on("add user") {[weak self] data, ack in
            var found = false
            if let nickname = data[0] as? String {
                if(self?.room?.users) != nil{
                    for user in (self?.room?.users)! {
                        if user == nickname{
                            found = true
                        }
                    }
                    if !found{
                        self?.room?.users.append(nickname)
                        self?.currentUsersTable.reloadData()
                    }
                }
            }
        }
        
        SocketIOManager.socket.on("remove user") {[weak self] data, ack in
            if let nickname = data[0] as? String {
                if let index = self?.room?.users.index(of: nickname) {
                    self?.room?.users.remove(at: index)
                    self?.currentUsersTable.reloadData()
                }
            }
        }
        SocketIOManager.socket.on("connect") {[weak self] data, ack in
            self?.room?.users.removeAll()
            let defaults = UserDefaults()
            let currRoom = defaults.string(forKey: "currRoom")
            if currRoom != nil{
                let nickname = defaults.string(forKey: "displayName")
                if nickname != nil{
                    SocketIOManager.socket.emit("enter room", currRoom!, nickname!)
                }else{
                    SocketIOManager.socket.emit("enter room", currRoom!, "Anonymous")
                }
            }
        }
        
    }
    
}
