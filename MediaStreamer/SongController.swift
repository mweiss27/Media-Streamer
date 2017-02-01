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
    
    @IBOutlet weak var songStack: UIView!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var songScroll: UIScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        self.header.text = self.playlist?.name
        
        
        self.initSongs()
        self.songScroll.contentOffset = CGPoint.zero
        
        print("SongController.viewDidLoad")
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("SongController.viewDidAppear")
    }
    
    func initSongs() {
        print("SongController.initSongs")
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
                
                var y = 0
                let w = self.songScroll.frame.width
                let h = 45
                
                if obj is SPTPlaylistSnapshot {
                    let snapshot = obj as! SPTPlaylistSnapshot
                    let tracks = snapshot.tracksForPlayback()
                    var i = 0
                    for obj in tracks! {
                        if obj is SPTPlaylistTrack {
                            let track = obj as! SPTPlaylistTrack
                            
                            let label_song = UILabel.init(frame: CGRect(
                                x: 0,
                                y: 0,
                                width: CGFloat(w),
                                height: CGFloat(18)
                            ))
                            label_song.text = track.name
                            label_song.textColor = UIColor.white
                            label_song.lineBreakMode = NSLineBreakMode.byTruncatingTail
                            
                            let label_artist = UILabel.init(frame: CGRect(
                                x: CGFloat(0),
                                y: 18,
                                width: CGFloat(w),
                                height: CGFloat(18)
                            ))
                            let artist = track.artists.first as! SPTPartialArtist?
                            if artist?.name != nil {
                                label_artist.text = artist?.name
                                label_artist.textColor = UIColor.gray
                                label_artist.lineBreakMode = NSLineBreakMode.byTruncatingTail
                            }
                            
                            let view = SongView.init(frame: CGRect(
                                x: CGFloat(0),
                                y: CGFloat(y),
                                width: CGFloat(w),
                                height: CGFloat(label_song.frame.height + 1 + label_artist.frame.height)
                                
                            ))
                            view.isOpaque = false
                            view.playlist = snapshot
                            view.index = i
                            
                            view.addSubview(label_song)
                            view.addSubview(label_artist)
                            let gesture = UITapGestureRecognizer.init(
                                target: self,
                                action: #selector(self.songClicked(_:)))
                            view.addGestureRecognizer(gesture)
                            
                            self.songStack.addSubview(view)
                            y += h-1
                            i += 1
                        }
                        else {
                            print("\(Mirror(reflecting: obj).subjectType)")
                        }
                    }
                    
                    print("Setting scroll size to: \(self.view.frame.width), \(y)")
                    self.songScroll.contentSize = CGSize(width: self.songScroll.frame.width, height: CGFloat(y))
                    print("Setting song stack size to \(self.songStack.frame.width), \(y)")
                    self.songStack.frame.size = CGSize(
                        width: self.songStack.frame.width,
                        height: CGFloat(y)
                    )
                }
                
            })
            
        }
        else {
            print("URI is nil :(")
        }
    }
    
    func songClicked(_ sender: UITapGestureRecognizer) {
        let source = sender.view
        if source != nil && source is SongView {
            let source_sv = source as! SongView
            if (SpotifyApp.instance.player?.loggedIn)! && (SpotifyApp.instance.player?.initialized)! {
                self.performSegue(withIdentifier: Constants.SongsToPlayer, sender: PlayInfo(playlist: source_sv.playlist!, index: source_sv.index!))
            }
            else {
                print("[ERROR] Not ready to play songs.")
            }
        }
        else {
            print("source is nil or not SongView")
        }
    }
    
    func scrollTap(_ sender: UITapGestureRecognizer) {
        print("Scroll Tap")
        print("Point: \(sender.location(in: songScroll))")
    }
    
    @IBAction func unwindToSongs(segue: UIStoryboardSegue) {
        print("SongController.unwindToSongs")
        if let songController = segue.source as? PlayerController {
            print("Coming from PlayerController")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is PlayerController && sender is PlayInfo {
            let playerController = segue.destination as! PlayerController
            let playInfo = sender as! PlayInfo
            playerController.playlist = playInfo.playlist
            playerController.index = UInt(playInfo.index)
        }
    }
    
    class PlayInfo {
        
        let playlist: SPTPlaylistSnapshot
        let index: Int
        
        init(playlist: SPTPlaylistSnapshot, index: Int) {
            self.playlist = playlist
            self.index = index
        }
        
    }
    
}
