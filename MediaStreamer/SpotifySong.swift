//
//  SpotifySong.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/15/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class SpotifySong: Equatable {
    
    var id: String!
    
    var playback_time: Double?
    var request_time: Double?
    
    init(id: String!) {
        self.id = id
    }
    
    func play(_ startTime: Double, callback: @escaping (String?) -> Void) {
        print("Playing SpotifySong: \(self.id) -- \(startTime)")
        print("Initialized? \(SpotifyApp.player.initialized)")
        SpotifyApp.player.playSpotifyURI(self.id, startingWith: 0, startingWithPosition: startTime) { (error) in
            print("playSpotifyURI callback")
            if error != nil {
                print("Error on Spotify.playSpotifyURI: \(error?.localizedDescription)")
            }
            else {
                print("Play success")
            }
            callback(error?.localizedDescription)
        }
        
        print("Play returned")
    }
    
    func setPlaybackTime(time: Double!) {
        SpotifyApp.player.seek(to: time) { (error) in
            if error != nil {
                print("Error on SpotifySong.setPlaybackTime: \(error?.localizedDescription)")
                return
            }
            
            print("Seek success")
        }
    }
    
    static func ==(lhs: SpotifySong, rhs: SpotifySong) -> Bool {
        return lhs.id == rhs.id
    }
    
}
