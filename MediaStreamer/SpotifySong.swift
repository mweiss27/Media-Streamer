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
    var name: String!
    
    var playback_time: Double?
    var request_time: Double?
    
    init(_ id: String!, _ name: String!) {
        self.id = id
        self.name = name
    }
    
    func play(_ startTime: Double, callback: @escaping (String?) -> Void) {
        print("Playing SpotifySong: \(self.id) -- \(startTime)")
        print("Initialized? \(SpotifyApp.player.initialized)")
        let start = Helper.currentTimeMillis()
        SpotifyApp.player.playSpotifyURI(self.id, startingWith: 0, startingWithPosition: startTime) { (error) in
            print("SpotifySong.playSpotifyURI callback after \(Helper.currentTimeMillis() - start)ms")
            callback(error?.localizedDescription)
        }
        
        print("Play returned")
    }
    
    func seek(to: Double!, callback: @escaping (String?) -> Void) {
        let start = Helper.currentTimeMillis()
        SpotifyApp.player.seek(to: to) { (error) in
            print("SpotifySong.seek callback after \(Helper.currentTimeMillis() - start)ms")
            callback(error?.localizedDescription)
        }
    }
    
    static func ==(lhs: SpotifySong, rhs: SpotifySong) -> Bool {
        return lhs.id == rhs.id
    }
    
}
