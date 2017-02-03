//
//  SpotifyApp.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 1/29/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import Foundation

class SpotifyApp {
    
    static let instance = SpotifyApp.init()
    
    let audioController: SPTCoreAudioController!
    let player: SPTAudioStreamingController!
    
    private init() {
        self.audioController = SPTCoreAudioController.init()
        self.player = SPTAudioStreamingController.sharedInstance()
    }
    
    public func startPlayer() {
        if !player.initialized {
            do {
                print("Starting our SPTAudioStreamingController")
                DispatchQueue.main.async {
                    self.player.login(withAccessToken: SPTAuth.defaultInstance().session.accessToken)
                }
                
                try self.player.start(withClientId: Constants.clientID,
                                 audioController: self.audioController,
                                 allowCaching: true)
                print("Start success")
            } catch let error {
                print("Error on start: \(error.localizedDescription)")
                
            }
        }
    }
    
    static public func getArtist(artists: [Any?]) -> String {
        print("getArtist: \(artists)")
        if artists.count > 0 {
            if let first = artists.first as? SPTArtist {
                return first.name
            }
            else if let first = artists.first as? SPTPartialArtist {
                return first.name
            }
            else if let first = artists.first as? String {
                return first
            }
        }
        return "N/A"
    }
    
}
