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
    
    static let player: SPTAudioStreamingController = SPTAudioStreamingController.sharedInstance()
    
    
    
    /**
     @note: Asynchronous. Listen for:
     Success will be notified on the `audioStreamingDidLogin:` delegate method and
     failure will be notified on the `audioStreaming:didEncounterError:` delegate method.
     */
    public static func loginToPlayer() {
        if !player.loggedIn {
            DispatchQueue.main.async {
                do {
                    
                    if !player.initialized {
                        print("Calling start")
                        try player.start(withClientId: Constants.clientID)
                    }
                    if !player.loggedIn {
                        print("Start finished. Calling login")
                        player.login(withAccessToken: SPTAuth.defaultInstance().session.accessToken)
                    }
                    print("login returned")
                } catch let error {
                    print("Error on player.start: \(error.localizedDescription)")
                }
            }
            print("login requested.")
        }
        else {
            print("[ERROR] loginToPlayer called, but already logged in")
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
        print("Saving an SPTSession: \(session)")
        
        let userDefaults = UserDefaults.standard
        if session == nil {
            userDefaults.removeObject(forKey: "SpotifySession")
        }
        else {
            let sessionData = NSKeyedArchiver.archivedData(withRootObject: session!)
            
            userDefaults.set(sessionData, forKey: "SpotifySession")
        }
        userDefaults.synchronize()
        SPTAuth.defaultInstance().session = session
        print("Save success")
    }
    
}
