//
//  PlayerController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/30/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class PlayerController: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    var song: SPTPlaylistTrack?
    
    @IBOutlet weak var albumArt: UIImageView!
    @IBOutlet weak var songName: UILabel!
    @IBOutlet weak var artistName: UILabel!
    @IBOutlet weak var pausePlay: UIButton!
    @IBOutlet weak var progressBar: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("PlayerController.viewDidLoad: \(self.song?.name)")
        
        URLSession.shared.dataTask(with: (self.song?.album.largestCover.imageURL)!) {
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
        SpotifyApp.instance.player.playSpotifyURI(self.song?.playableUri.absoluteString, startingWith: 0, startingWithPosition: 0) { (error) in
            if error != nil {
                print("Error on playSpotifyURI: \(error?.localizedDescription)")
            }
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        SpotifyApp.instance.player.delegate = self
        SpotifyApp.instance.player.playbackDelegate = self
    }
    
    @IBAction func pausePlayClicked(_ sender: Any) {
        SpotifyApp.instance.player.setIsPlaying(!SpotifyApp.instance.player.playbackState.isPlaying) { (error) in
            if error != nil {
                print("Error on setIsPlaying: \(error?.localizedDescription)")
            }
        }
    }

    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didStartPlayingTrack trackUri: String!) {
        self.songName.text = audioStreaming.metadata.currentTrack?.name
        self.artistName.text = audioStreaming.metadata.currentTrack?.artistName
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
        let duration = (audioStreaming.metadata.currentTrack?.duration)!
        print("Progress: \(Float(position / duration))")
        self.progressBar.progress = Float(position / duration)
    }
    
}

