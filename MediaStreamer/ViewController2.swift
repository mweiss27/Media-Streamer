//
//  DisplayInfo.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/25/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class ViewController2: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
    
    var appDelegate: AppDelegate?
    let player: SPTAudioStreamingController = SPTAudioStreamingController.sharedInstance()
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var albumArt: UIImageView!
    @IBOutlet weak var artistName: UILabel!
    @IBOutlet weak var songName: UILabel!
    @IBOutlet weak var songProgress: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.appDelegate = UIApplication.shared.delegate as? AppDelegate
        
        player.playbackDelegate = self
        player.delegate = self
        
        albumArt.contentMode = UIViewContentMode.scaleAspectFit
        songName.text = ""
        artistName.text = ""
        songProgress.progress = 0
        
        self.navigationItem.hidesBackButton = true
        print("ViewController2 is displayed")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        let audioController = SPTCoreAudioController()
        
        do {
            print("Starting our SPTAudioStreamingController")
            try player.start(withClientId: self.appDelegate?.clientID,
                              audioController: audioController,
                              allowCaching: true)
            print("Started")
        } catch let error {
            print("Error on start: " + error.localizedDescription)
        }
        if (!player.loggedIn) {
            print("Our player is NOT logged in")
            
            print("Logging in")
            player.login(withAccessToken: SPTAuth.defaultInstance().session.accessToken)
            print("Login returned")
            
        }
        else {
            print("Our player is logged in")
        }
        
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        print("SPOTIFY LOGIN")
        
        print("Player is logged in? " + player.loggedIn.description)
        print("Player is initialized? " + player.initialized.description)
        
        player.playSpotifyURI("spotify:track:4kbDYMLy5qdn1UqaNiNWsM",
                               startingWith: 0,
                               startingWithPosition: 0) { (error) in
                                if error != nil {
                                    print("Error on playSpotifyURI: \(error)")
                                }
                                print("Song is playing!")
                                
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!,
                        didStartPlayingTrack trackUri: String!) {
        print("SPOTIFY STARTED A TRACK")
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePlaybackStatus isPlaying: Bool) {
        print("Playback status changed. Playing? \(isPlaying.description)")
        var image: UIImage?
        if isPlaying {
            image = UIImage(named: "pauseButton")
        }
        else {
            image = UIImage(named: "playButton")
        }
        playButton.setImage(image, for: UIControlState.normal)
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChange metadata: SPTPlaybackMetadata!) {
        if metadata != nil {
            if let track = metadata.currentTrack {
                songName.text = track.name
                artistName.text = track.artistName
                print("Starting dataTask to get the album art")
                URLSession.shared.dataTask(with: URL(string: track.albumCoverArtURL!)!) {
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
            else {
                print("currentTrack is nil")
            }
        }
        else {
            print("metadata is nil. what the !@#$")
        }
    }
    
    func audioStreaming(_ audioStreaming: SPTAudioStreamingController!, didChangePosition position: TimeInterval) {
        let duration = (audioStreaming.metadata.currentTrack?.duration)!
        self.songProgress.progress = Float(position / duration)
    }
    
    @IBAction func pausePlay(_ sender: Any) {
        self.player.setIsPlaying(!self.player.playbackState.isPlaying) { (error) in
            if error != nil {
                print("Error on pause/play: \(error?.localizedDescription)")
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}
