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
        print("Initialized? \(SpotifyApp.player.initialized)")
        SpotifyApp.player.playSpotifyURI(self.id, startingWith: 0, startingWithPosition: 0.0) { (error) in
            if error != nil {
                print("Error on Spotify.playSpotifyURI: \(error?.localizedDescription)")
                return
            }
            
            print("Play success")
            
        }
    }
    
    override func pause(completion: @escaping (Error?) -> Void) {
        print("Pausing SpotifySong: \(self.id)")
        if let playback = SpotifyApp.player.playbackState {
            if playback.isPlaying {
                
                //TODO -- Send a message to the server that we're pausing
                
                SpotifyApp.player.setIsPlaying(false, callback: { (error) in
                    if error != nil {
                        print("Error on SpotifySong.pause: \(error?.localizedDescription)")
                        completion(error)
                        return
                    }
                    
                    print("Pause success")
                    completion(nil)
                })
            }
        }
    }
    
    override func resume() {
        print("Resuming SpotifySong: \(self.id)")
        if let playback = SpotifyApp.player.playbackState {
            if !playback.isPlaying {
                
                //TODO -- Send a message to the server that we're resuming
                //Don't worry about re-syncing after a resume.
                //The pause will be delayed for other users, putting them slightly ahead
                //The resume will be delayed for other users, putting them back in sync
                
                SpotifyApp.player.setIsPlaying(true, callback: { (error) in
                    if error != nil {
                        print("Error on SpotifySong.pause: \(error?.localizedDescription)")
                        return
                    }
                    
                    print("Resume success")
                    
                })
            }
        }
    }
    
    override func setPlaybackTime(time: Double!) {
        SpotifyApp.player.seek(to: time) { (error) in
            if error != nil {
                print("Error on SpotifySong.setPlaybackTime: \(error?.localizedDescription)")
                return
            }
            
            print("Seek success")
        }
    }
    
    
    
}
