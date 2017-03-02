//
//  PlaylistController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/29/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class PlaylistController: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    var appDelegate: AppDelegate?
    
    @IBOutlet weak var playlistHeader: UILabel!
    @IBOutlet weak var playlistScroll: UIScrollView!
    @IBOutlet weak var playlistStack: UIView!
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        
        SpotifyApp.player.delegate = self
        SpotifyApp.player.playbackDelegate = self
        
        self.initPlaylists()
        
        print("PlaylistController viewDidLoad")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("PlaylistController viewDidAppear")
    }
    
    func initPlaylists() {
        print("PlaylistController.initPlaylists")
        SPTUser.requestCurrentUser(withAccessToken: SPTAuth.defaultInstance().session.accessToken) { (error, obj) in
            if error != nil {
                print("Error on requesetCurrentUser: \(error?.localizedDescription)")
                return
            }
            
            if obj != nil {
                if obj is SPTUser {
                    print("Got an SPTUser object")
                    let user = obj as! SPTUser
                    let accessToken = SPTAuth.defaultInstance().session.accessToken
                    
                    print("Currently logged in as: \(user.canonicalUserName)")
                    
                    SPTPlaylistList.playlists(forUser: user.canonicalUserName, withAccessToken: accessToken, callback: { (error, playlists) in
                        if error != nil {
                            print("Error on .playlists: \(error?.localizedDescription)")
                            return
                        }
                        print("\(Mirror(reflecting: playlists!).subjectType)")
                        if playlists is SPTPlaylistList {
                            let listlist = playlists as! SPTPlaylistList
                            let items = listlist.items
                            
                            var y = 0
                            if items != nil {
                                for item in items! {
                                    if item is SPTPartialPlaylist {
                                        let partial = item as! SPTPartialPlaylist
                                        print("Creating a UIPlaylistView for \(partial.name)")
                                        let view = UIPlaylistView.initWith(owner: self.playlistStack, playlist: partial)
                                        view.frame.origin.y = CGFloat(y)
                                        
                                        let gesture = UITapGestureRecognizer.init(target: self, action: #selector(self.playlistTapped(_:)))
                                        view.addGestureRecognizer(gesture)
                                        
                                        self.playlistStack.addSubview(view)
                                        y += Int(view.frame.height + 3)
                                    }
                                }
                            }
                            self.heightConstraint.constant = CGFloat(y)
                        }
                    })
                    
                }
            }
            
        }
        
    }
    
    func playlistTapped(_ sender: UITapGestureRecognizer) {
        
        if let source = sender.view as? UIPlaylistView {
            print("Playlist Tapped: \(source.playlistName!)")
            self.performSegue(withIdentifier: Constants.PlaylistToSongs, sender: source)
        }
        else {
            print("Bad source")
        }
        
    }
    
    func playlistClicked(sender: PlaylistButton) {
        if sender.playlist != nil {
            if let playlist = sender.playlist {
                self.performSegue(withIdentifier: Constants.PlaylistToSongs, sender: playlist)
            }
        }
        else {
            print("Bad argument: \(sender)")
        }
    }
    
    
    
    @IBAction func unwindToPlaylists(segue: UIStoryboardSegue) {
        print("PlaylistController.unwindToPlaylists")
        if segue.source is SongController {
            print("Coming from SongController")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let songController = segue.destination as? SongController {
            if let playlistView = sender as? UIPlaylistView {
                songController.playlist = playlistView.partialPlaylist
            }
        }
    }
    
    
}
