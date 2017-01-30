//
//  SongController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/30/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class SongController: UIViewController {
    
    var appDelegate: AppDelegate?
    
    @IBOutlet weak var header: UILabel!
    var playlist: SPTPartialPlaylist?
    
    @IBOutlet weak var songsScroll: UIScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        self.header.text = self.playlist?.name
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.initSongs()
        
    }
    
    func initSongs() {
        let uri = self.playlist?.playableUri
        if uri != nil {
            SPTPlaylistSnapshot.playlist(withURI: self.playlist?.playableUri, accessToken: SPTAuth.defaultInstance().session.accessToken, callback: { (error, obj) in
                if error != nil {
                    print("Error on playlist: \(error?.localizedDescription)")
                    return
                }
                if obj == nil {
                    print("Got a nil obj")
                    return
                }
                
                let x = self.appDelegate?.window?.frame.origin.x
                var y = 0
                let w = self.appDelegate?.window?.frame.width
                let h = 21
                
                print("We got an obj: \(Mirror(reflecting: obj!).subjectType)")
                if obj is SPTPlaylistSnapshot {
                    let snapshot = obj as! SPTPlaylistSnapshot
                    let tracks = snapshot.tracksForPlayback()
                    for obj in tracks! {
                        if obj is SPTPlaylistTrack {
                            let track = obj as! SPTPlaylistTrack
                            let rect = CGRect(x: x!, y: CGFloat(y), width: w!, height: CGFloat(h))
                            let button = SongButton.init(frame: rect)
                            button.song = track
                            button.setTitle(track.name, for: UIControlState.normal)
                            button.setTitleColor(UIColor.white, for: UIControlState.normal)
                            button.contentHorizontalAlignment = UIControlContentHorizontalAlignment.left
                            button.titleLabel?.lineBreakMode = NSLineBreakMode.byTruncatingTail
                            
                            
                            let sel = #selector(SongController.songClicked(sender:))
                            
                            
                            button.addTarget(self, action: sel, for: UIControlEvents.touchUpInside)
                            self.songsScroll.addSubview(button)

                            y += 21
                        }
                        else {
                            print("\(Mirror(reflecting: obj).subjectType)")
                        }
                    }
                    print("ScrollView height: \(self.songsScroll.frame.height)")
                }
                
            })
            
        }
        else {
            print("URI is nil :(")
        }
    }
    
    func songClicked(sender: SongButton) {
        if (SpotifyApp.instance.player?.loggedIn)! && (SpotifyApp.instance.player?.initialized)! {
            print("Song Clicked: \(sender)")
            if sender.song != nil {
                self.performSegue(withIdentifier: Constants.SongsToPlayer, sender: sender.song)
            }
        }
        else {
            print("[ERROR] Not ready to play songs.")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is PlayerController && sender is SPTPlaylistTrack {
            let playerController = segue.destination as! PlayerController
            playerController.song = sender as? SPTPlaylistTrack
        }
    }
    
}
