//
//  SpotifySong.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class SpotifySong: Media {
    
    override func play() {
        print("Playing SpotifySong: \(self.id)")
        SpotifyApp.instance.player.playSpotifyURI(self.id, startingWith: 0, startingWithPosition: 0.0) { (error) in
            if error != nil {
                print("Error on Spotify.playSpotifyURI: \(error?.localizedDescription)")
                return
            }
            
            print("Play success")
            
        }
    }
    
    override func setPlaybackTime(time: Double!) {
        SpotifyApp.instance.player.seek(to: time) { (error) in
            if error != nil {
                print("Error on SpotifySong.setPlaybackTime: \(error?.localizedDescription)")
                return
            }
            
            print("Seek success")
        }
    }
    
    
    
}
