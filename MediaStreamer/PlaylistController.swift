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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        
        SpotifyApp.instance.player.delegate = self
        SpotifyApp.instance.player.playbackDelegate = self
        
        self.initPlaylists()
        
        print("PlaylistController viewDidLoad")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        SpotifyApp.instance.startPlayer()
        
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
                    
                    print("Currently logged in as: \(user.canonicalUserName)")
                    
                    SPTPlaylistList.playlists(forUser: user.canonicalUserName, withAccessToken: SPTAuth.defaultInstance().session.accessToken) { (error, obj) in
                        if error != nil {
                            print("Error on getPlaylists: \(error?.localizedDescription)")
                            return
                        }
                        
                        if (obj == nil) {
                            print("There are no playlists for spaccount1")
                            return
                        }
                        
                        
                        let x = self.appDelegate?.window?.frame.origin.x
                        var y = 0
                        let w = self.appDelegate?.window?.frame.width
                        let h = 21
                        
                        if obj is SPTPlaylistList {
                            let list = obj as! SPTPlaylistList
                            let playlists = list.items
                            for pl in playlists! {
                                //print("Playlist! \(Mirror(reflecting: pl).subjectType)")
                                if pl is SPTPartialPlaylist {
                                    let partial = pl as! SPTPartialPlaylist
                                    
                                    let rect = CGRect(x: x!, y: CGFloat(y), width: w!, height: CGFloat(h))
                                    let button = PlaylistButton.init(frame: rect)
                                    button.playlist = partial
                                    button.setTitle(partial.name, for: UIControlState.normal)
                                    button.setTitleColor(UIColor.white, for: UIControlState.normal)
                                    button.contentHorizontalAlignment = UIControlContentHorizontalAlignment.left
                                    button.titleLabel?.lineBreakMode = NSLineBreakMode.byTruncatingTail
                                    
                                    
                                    let sel = #selector(PlaylistController.playlistClicked(sender:))
                                    
                                    
                                    button.addTarget(self, action: sel, for: UIControlEvents.touchUpInside)
                                    self.playlistStack.addSubview(button)
                                    
                                    y += 21
                                }
                            }
                            print("Setting scroll size to: \(self.view.frame.width), \(y)")
                            self.playlistScroll.contentSize = CGSize(width: self.view.frame.width, height: CGFloat(y))
                            print("Scroll position is: \(self.playlistScroll.frame.origin)")
                        }
                        else {
                            print("Our object isn't an SPTPlaylistList")
                        }
                        
                    }
                    
                }
            }
            
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
        if let songController = segue.source as? SongController {
            print("Coming from SongController")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is SongController && sender is SPTPartialPlaylist {
            let songController = segue.destination as! SongController
            songController.playlist = sender as? SPTPartialPlaylist
        }
    }
    
    
}
