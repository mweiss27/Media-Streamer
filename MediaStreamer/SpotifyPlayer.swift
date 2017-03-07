//
//  SpotifyPlayer.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit
import MediaPlayer

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
        
        print("Player is logged in? " + SpotifyApp.player.loggedIn.description)
        print("Player is initialized? " + SpotifyApp.player.initialized.description)
        
        let swipeDown = UISwipeGestureRecognizer.init(target: self, action: #selector(self.swipeGesture(_:)))
        swipeDown.direction = UISwipeGestureRecognizerDirection.down
        
        let swipeLeft = UISwipeGestureRecognizer.init(target: self, action: #selector(self.swipeGesture(_:)))
        swipeLeft.direction = UISwipeGestureRecognizerDirection.left
        
        self.albumArt.addGestureRecognizer(swipeDown)
        self.albumArt.addGestureRecognizer(swipeLeft)
    }
    
    @objc private func swipeGesture(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .down {
            self.performSegue(withIdentifier: "unwindToRoom", sender: self)
        }
            //Swiping left implies going right
        else if gesture.direction == .left {
            self.nextClicked(nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.roomController?.spotifyPlayer = self
        print("PlayerController.viewDidAppear")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if self.isMovingFromParentViewController {
            print("Player is going away")
            self.roomController?.spotifyPlayer = nil
        }
    }
    
    @IBAction func pausePlayClicked(_ sender: Any) {
        if SpotifyApp.player.playbackState.isPlaying {
            self.roomController?.room?.pause(true)
        }
        else {
            self.roomController?.room?.resume(true)
        }
    }
    
    @IBAction func nextClicked(_ sender: Any?) {
        print("nextClicked")
        if !(self.roomController?.room?.playNextSong(startTime: 0.0, true))! {
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
                let image = UIImage(data: data!)
                print("No error. Setting image!")
                DispatchQueue.main.async {
                    self.albumArt.image = image!
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
            let metadata = SpotifyApp.player.metadata
            if metadata != nil {
                let realPosition = self.progressSlider.value * Float((metadata?.currentTrack?.duration)!)
                print("Playback position changed: \(self.progressSlider.value)")
                
                let now = Helper.currentTimeMillis()
                let scrubTime = Double(realPosition)
                print("emitting playback: \(scrubTime)")
                SocketIOManager.emit("change playback", [ Int(now), scrubTime ], { (error) in
                    if error != nil {
                        Helper.alert(view: self, title: "Failed to set playback time", message: "An error occurred while updating the playback time.")
                        return
                    }
                })
                
            }
            self.dragging = false
        }
        else {
            self.dragging = true
        }
        
    }
    
}
