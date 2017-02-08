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
    
    public static func getArtist(artists: [Any?]?) -> String {
        if artists != nil {
            if (artists?.count)! > 0 {
                if let first = artists?.first as? SPTArtist {
                    return first.name
                }
                else if let first = artists?.first as? SPTPartialArtist {
                    return first.name
                }
                else if let first = artists?.first as? String {
                    return first
                }
            }
        }
        return "N/A"
    }
    
    public static func restoreSession() -> SPTSession? {
        let userDefaults = UserDefaults.standard
        if let sessionData = userDefaults.object(forKey: "SpotifySession") {
            if let session = NSKeyedUnarchiver.unarchiveObject(with: sessionData as! Data) as? SPTSession {
                print("We found an SPTSession")
                SPTAuth.defaultInstance().session = session
            }
        }
        return SPTAuth.defaultInstance().session
    }
    
    public static func saveSession(session: SPTSession?) {
        var sess = session
        print("Saving an SPTSession")
        if sess == nil {
            sess = SPTSession()
        }
        
        let userDefaults = UserDefaults.standard
        let sessionData = NSKeyedArchiver.archivedData(withRootObject: sess!)
        
        userDefaults.set(sessionData, forKey: "SpotifySession")
        userDefaults.synchronize()
        
        SPTAuth.defaultInstance().session = sess
        print("Save success")
    }
    
}
