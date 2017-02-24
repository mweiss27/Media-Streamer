//
//  SpotifyPlayer.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class SpotifyPlayer: UIViewController {
    
    var roomController: RoomController?
    
    var dragging: Bool = false
    var lastImageURL: String? = nil
    
    @IBOutlet weak var albumArt: UIImageView!
    @IBOutlet weak var songName: UILabel!
    @IBOutlet weak var artistName: UILabel!
    @IBOutlet weak var pausePlay: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    
    var _songName: String?, _artistName: String?, _imageURL: String?, _isPlaying: Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("SpotifyPlayer.viewDidLoad")
        
        if self._songName != nil {
            self.songName.text = self._songName
        }
        
        if self._artistName != nil {
            self.artistName.text = self._artistName
        }
        
        if self._imageURL != nil {
            self.setImage(self._imageURL)
        }
        
        if self._isPlaying != nil {
            self.pausePlay.setImage(UIImage(named:self._isPlaying! ? "pauseButton" : "playButton"), for: .normal)
        }
        
        print("Player is logged in? " + SpotifyApp.instance.player.loggedIn.description)
        print("Player is initialized? " + SpotifyApp.instance.player.initialized.description)
        
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
    
    @IBAction func nextClicked(_ sender: Any) {
        print("nextClicked")
        if !(self.roomController?.room?.playNextSong())! {
            self.roomController?.currentSongName.text = ""
            self.roomController?.currentArtistName.text = ""
            self.roomController?.currentPlaybackTime.progress = 0
            self.performSegue(withIdentifier: "unwindToRoom", sender: self)
        }
    }
    
    func setImage(_ url: String!) {
        if self.lastImageURL != url {
            self.lastImageURL = url
            URLSession.shared.dataTask(with: URL(string: url)!) {
                (data, response, error) in
                if error != nil {
                    print("Error on dataTask: \(error)")
                    self.lastImageURL = nil
                    return
                }
                print("No error. Setting image!")
                DispatchQueue.main.async {
                    self.albumArt.image = UIImage(data: data!)
                }
                }.resume()
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
                
                self.roomController?.room?.seek(to: Double(realPosition))
                
            }
            self.dragging = false
        }
        else {
            self.dragging = true
        }
        
    }
    
}
