//
//  SpotifyPlaylistsController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class SpotifyPlaylistsController: UIViewController {
    
    @IBOutlet weak var playlistStack: UIView!
    @IBOutlet weak var playlistStackHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initPlaylists()
        
        print("SpotifyPlaylistsController viewDidLoad")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("SpotifyPlaylistsController viewDidAppear")
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
                    
                    print("Currently logged in as: \(user.displayName)")
                    
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
                                        let view = SpotifyPlaylistView.initWith(owner: self.playlistStack, playlist: partial)
                                        view.frame.origin.y = CGFloat(y)
                                        
                                        let gesture = UITapGestureRecognizer.init(target: self, action: #selector(self.playlistTapped(_:)))
                                        view.addGestureRecognizer(gesture)
                                        
                                        self.playlistStack.addSubview(view)
                                        y += Int(view.frame.height + 3)
                                    }
                                }
                            }
                            self.playlistStackHeight.constant = CGFloat(y)
                        }
                    })
                    
                }
            }
            
        }
        
    }
    
    func playlistTapped(_ sender: UITapGestureRecognizer) {
        
        if let source = sender.view as? SpotifyPlaylistView {
            print("Playlist Tapped: \(source.playlistName!)")
            
            
            
        }
        else {
            print("Bad source")
        }
        
    }
    
    
//    @IBAction func unwindToPlaylists(segue: UIStoryboardSegue) {
//        print("PlaylistController.unwindToPlaylists")
//        if segue.source is SongController {
//            print("Coming from SongController")
//        }
//    }
    
    
}

