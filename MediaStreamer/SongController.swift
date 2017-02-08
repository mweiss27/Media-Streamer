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
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
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
                
                if let snapshot = obj as? SPTPlaylistSnapshot {
                    let page: SPTListPage! = snapshot.firstTrackPage
                    
                    //Remove all subviews
                    for sub in self.songStack.subviews as [UIView] {
                        sub.removeFromSuperview()
                    }
                    self.heightConstraint.constant = 0
                    
                    self.loadSongs(snapshot, page)
                }
                
            })
            
        }
        else {
            print("URI is nil :(")
        }
    }
    
    /*
     let tracks = snapshot.tracksForPlayback()
     var i = 0
     for obj in tracks! {
     if obj is SPTPlaylistTrack {
     let track = obj as! SPTPlaylistTrack
     
     let view = UISongView.initWith(owner: self.songStack, song: track)
     view.frame.origin.y = CGFloat(y)
     view.playlist = snapshot
     view.index = i
     
     let gesture = UITapGestureRecognizer.init(
     target: self,
     action: #selector(self.songClicked(_:)))
     view.addGestureRecognizer(gesture)
     
     self.songStack.addSubview(view)
     y += Int(view.frame.height+2)
     i += 1
     }
     else {
     print("\(Mirror(reflecting: obj).subjectType)")
     }
     }
     self.heightConstraint.constant = CGFloat(y)
     
     */
    
    func loadSongs(_ playlist: SPTPlaylistSnapshot, _ listPage: SPTListPage) {
        
        let songs = listPage.tracksForPlayback()
        for obj in songs! {
            if let song = obj as? SPTPlaylistTrack {
                let view = UISongView.initWith(owner: self.songStack, song: song)
                view.playlist = playlist
                view.index = self.songStack.subviews.count
                
                let h = view.frame.height
                self.heightConstraint.constant = self.heightConstraint.constant + h
                let y = Int(h) * self.songStack.subviews.count
                view.frame.origin = CGPoint(x: 0, y: y)
                
                let gest = UITapGestureRecognizer.init(target: self, action: #selector(self.songClicked(_:)))
                view.addGestureRecognizer(gest)
                
                self.songStack.addSubview(view)
            }
            else {
                print("obj is not SPTPlaylistTrack: \(Mirror(reflecting: obj).subjectType)")
            }
        }
        
        print("Successfully added \(songs?.count) songs. Total: \(self.songStack.subviews.count)")
        
        if listPage.hasNextPage {
            print("This page has a next page")
            listPage.requestNextPage(withAccessToken: SPTAuth.defaultInstance().session.accessToken, callback: {
                (err, obj) in
                if err != nil {
                    print("Error on requestNextPage: \(err?.localizedDescription)")
                    return
                }
                
                print("Got our next page")
                print("Type of obj: \(Mirror(reflecting: obj!).subjectType)")
                
                if let nextPage = obj as? SPTListPage {
                    self.loadSongs(playlist, nextPage)
                }
                
            })
        }
    }
    
    func songClicked(_ sender: UITapGestureRecognizer) {
        if let source = sender.view as? UISongView {
            if (SpotifyApp.instance.player?.loggedIn)! && (SpotifyApp.instance.player?.initialized)! {
                self.performSegue(withIdentifier: Constants.SongsToPlayer, sender: PlayInfo(playlist: source.playlist!, index: source.index!))
            }
            else {
                print("[ERROR] Not ready to play songs.")
            }
        }
        else {
            print("[ERROR] source is nil or not UISongView: \(sender.view)")
        }
    }
    
    func scrollTap(_ sender: UITapGestureRecognizer) {
        print("Scroll Tap")
        print("Point: \(sender.location(in: songScroll))")
    }
    
    @IBAction func unwindToSongs(segue: UIStoryboardSegue) {
        print("SongController.unwindToSongs")
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
