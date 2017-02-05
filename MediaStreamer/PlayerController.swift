//
//  PlayerController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/30/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class PlayerController: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    var playlist: SPTPartialPlaylist?
    var index: UInt?
    var dragging: Bool = false
    private var lastImageURL: String? = nil
    
    @IBOutlet weak var albumArt: UIImageView!
    @IBOutlet weak var songName: UILabel!
    @IBOutlet weak var shuffleButton: UIButton!
    @IBOutlet weak var artistName: UILabel!
    @IBOutlet weak var pausePlay: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("PlayerController.viewDidLoad")
        print("Playlist: \(self.playlist)")
        print("Largeset Image: \(self.playlist?.largestImage)")
        
        SpotifyApp.instance.player.delegate = self
        SpotifyApp.instance.player.playbackDelegate = self
        
        
        URLSession.shared.dataTask(with: (self.playlist?.largestImage.imageURL)!) {
            (data, response, error) in
            if error != nil {
                print("Error on dataTask: \(error)")
                return
            }
            print("No error. Setting image!")
            DispatchQueue.main.async {
                self.albumArt.image = UIImage(data: data!)
            }
            }.resume()
        
        print("Player is logged in? " + SpotifyApp.instance.player.loggedIn.description)
        print("Player is initialized? " + SpotifyApp.instance.player.initialized.description)
        if SpotifyApp.instance.player.playbackState != nil {
            
            if SpotifyApp.instance.player.playbackState.isShuffling {
                self.shuffleButton.imageView?.image = UIImage(named: "shuffle_onButton")
            }
            
            SpotifyApp.instance.player.setIsPlaying(false) { (error) in
                if error != nil {
                    print("Error on setIsPlaying(false): \(error?.localizedDescription)")
                    return
                }
                SpotifyApp.instance.player.playSpotifyURI(self.playlist?.playableUri.absoluteString, startingWith: self.index!, startingWithPosition: 0) { (error) in
                    if error != nil {
                        print("Error on playSpotifyURI: \(error?.localizedDescription)")
                    }
                }
            }
        }
        else {
            SpotifyApp.instance.player.playSpotifyURI(self.playlist?.playableUri.absoluteString, startingWith: self.index!, startingWithPosition: 0) { (error) in
                if error != nil {
                    print("Error on playSpotifyURI: \(error?.localizedDescription)")
                }
            }
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("PlayerController.viewDidAppear")
    }
    
    @IBAction func pausePlayClicked(_ sender: Any) {
        SpotifyApp.instance.player.setIsPlaying(!SpotifyApp.instance.player.playbackState.isPlaying) { (error) in
            if error != nil {
                print("Error on setIsPlaying: \(error?.localizedDescription)")
            }
        }
    }
    
    @IBAction func backClicked(_ sender: Any) {
        
        let playbackState = SpotifyApp.instance.player.playbackState
        if playbackState != nil {
            let position = Int((playbackState?.position)!)
            if position < 2 {
                SpotifyApp.instance.player.skipPrevious { (error) in
                    if error != nil {
                        print("Error on skipPrevious: \(error?.localizedDescription)")
                        return
                    }
                }
            }
            else {
                SpotifyApp.instance.player.seek(to: 0, callback: { (error) in
                    if error != nil {
                        print("Error on seekToStart: \(error?.localizedDescription)")
                    }
                })
            }
        }
        
    }
    
    @IBAction func nextClicked(_ sender: Any) {
        self.index = self.index! + 1
        if self.index! > (self.playlist?.trackCount)! {
            self.index = 0
        }
        SpotifyApp.instance.player.skipNext { (error) in
            if error != nil {
                print("Error on skipNext: \(error?.localizedDescription)")
                return
            }
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        print("didStartPlayingTrack")
        self.songName.text = audioStreaming.metadata.currentTrack?.name
        self.artistName.text = audioStreaming.metadata.currentTrack?.artistName
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStopPlayingTrack trackUri: String!) {
        print("didStopPlayingTrack")
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChange metadata: SPTPlaybackMetadata!) {
        print("metadataChanged")
        self.songName.text = metadata.currentTrack?.name
        self.artistName.text = metadata.currentTrack?.artistName
        
        if self.lastImageURL != metadata.currentTrack?.albumCoverArtURL {
            self.lastImageURL = metadata.currentTrack?.albumCoverArtURL
            URLSession.shared.dataTask(with: URL(string: (metadata.currentTrack?.albumCoverArtURL)!)!) {
                (data, response, error) in
                if error != nil {
                    print("Error on dataTask: \(error)")
                    return
                }
                print("No error. Setting image!")
                DispatchQueue.main.async {
                    self.albumArt.image = UIImage(data: data!)
                }
                }.resume()
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        print("Playback Status Changed: \(isPlaying.description)")
        var image: UIImage?
        if isPlaying {
            image = UIImage(named: "pauseButton")
        }
        else {
            image = UIImage(named: "playButton")
        }
        self.pausePlay.setImage(image, for: UIControlState.normal)
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePosition position: TimeInterval) {
        let metadata = audioStreaming.metadata
        if metadata != nil {
            let track = metadata?.currentTrack
            if track != nil {
                let duration = (track?.duration)!
                //print("Progress: \(Float(position / duration))")
                if !self.dragging {
                    self.progressSlider.value = Float(position / duration)
                }
            }
            else {
                print("Position changed, nil track")
            }
        }
        else {
            print("Position changed, nil metadata")
        }
    }
    
    @IBAction func playbackValueChanged(_ sender: Any, forEvent event: UIEvent) {
        let touches = event.allTouches
        var stillMoving = false
        for touch in touches! {
            if touch.phase == UITouchPhase.moved || touch.phase == UITouchPhase.began {
                stillMoving = true
            }
        }
        if !stillMoving {
            let metadata = SpotifyApp.instance.player.metadata
            if metadata != nil {
                let realPosition = self.progressSlider.value * Float((metadata?.currentTrack?.duration)!)
                print("Playback position changed: \(self.progressSlider.value)")
                SpotifyApp.instance.player.seek(to: Double(realPosition), callback: { (error) in
                    if error != nil {
                        print("Error on seekToStart: \(error?.localizedDescription)")
                    }
                })
            }
            self.dragging = false
        }
        else {
            self.dragging = true
        }
        
    }
    
    @IBAction func shuffleButtonClicked(_ sender: Any) {
        print("shuffleButtonClicked")
        var shuffling: Bool = false
        if let state = SpotifyApp.instance.player.playbackState {
            shuffling = state.isShuffling
        }
        SpotifyApp.instance.player.setShuffle(!shuffling) { (error) in
            if error != nil {
                print("Error on setShuffle: \(error?.localizedDescription)")
                return
            }
            
            if shuffling {
                //No we aren't shuffling
                self.shuffleButton.imageView?.image = UIImage(named: "shuffle_offButton")
            }
            else {
                //And now we are
                self.shuffleButton.imageView?.image = UIImage(named: "shuffle_onButton")
            }
            
        }
    }
    
}

