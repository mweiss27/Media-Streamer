//
//  RoomController.swift
//  MediaStreamer
//
//  Created by Matt Weiss on 2/6/17.
//  Copyright © 2017 Matt Weiss. All rights reserved.
//

import UIKit

class RoomController: UIViewController {
    
    @IBOutlet weak var spotifyButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
        self.tryInitSpotify { (result) in
            if result {
                self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedAuthed(_:)), for: .touchUpInside)
            }
            else {
                self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedNotAuthed(_:)), for: .touchUpInside)
            }
            self.spotifyButton.isEnabled = true
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("RoomController is displayed")
    }
    
    private func tryInitSpotify(callback: @escaping (Bool) -> ()) {
        if let storedSession: SPTSession = SpotifyApp.restoreSession() {
            print("We have a session stored!")
            if storedSession.isValid() {
                print("[2] We have a valid session. We need to transition to the info view")
                callback(true)
            }
            else {
                if SPTAuth.defaultInstance().hasTokenRefreshService {
                    print("Our session is invalid. Let's try to refresh it")
                    print("Our encrypted_refresh_token: \(storedSession.encryptedRefreshToken)")
                    SPTAuth.defaultInstance().renewSession(storedSession, callback: { (error, renewedSession) in
                        if error != nil {
                            print("Error on renewSession: \(error?.localizedDescription)")
                            callback(false)
                        }
                        
                        if renewedSession != nil && (renewedSession?.isValid())! {
                            print("We got a new session!")
                            SpotifyApp.saveSession(session: renewedSession!)
                            callback(true)
                            
                        }
                        else {
                            print("We didn't get a new/valid session. :(")
                            callback(false)
                        }
                    })
                }
            }
        }
        else {
            print("We didn't find a stored session")
            callback(false)
        }
    }
    
    func spotifyButtonClickedAuthed(_ sender: UIButton!) {
        print("spotifyButtonClickedAuthed")
        self.performSegue(withIdentifier: "room_to_spotify", sender: self)
    }
    
    func spotifyButtonClickedNotAuthed(_ sender: UIButton!) {
        print("spotifyButtonClickedNotAuthed")
        (UIApplication.shared.delegate as? AppDelegate)?.roomController = self
        if SPTAuth.spotifyApplicationIsInstalled() && SPTAuth.supportsApplicationAuthentication() {
            UIApplication.shared.open(SPTAuth.defaultInstance().spotifyAppAuthenticationURL(), options: [:], completionHandler: nil)
        }
        else {
            let loginURL = SPTAuth.loginURL(forClientId: Constants.clientID,
                                            withRedirectURL: URL(string: Constants.redirectURL),
                                            scopes: Constants.requestedScopes,
                                            responseType: "code")
            
            print("loginURL: \(loginURL)")
            UIApplication.shared.open(loginURL!, options: [:], completionHandler: nil)
        }
        
    }
    
    public func handleSpotifyLogin(session: SPTSession!) {
        print("RoomController.handleSpotifyLogin")
        SpotifyApp.saveSession(session: session!)
        if session.isValid() {
            print("[1] We have a valid session. We need to transition to spotify browser")
            self.spotifyButton.removeTarget(nil, action: nil, for: .allEvents)
            self.spotifyButton.addTarget(self, action: #selector(self.spotifyButtonClickedAuthed(_:)), for: .touchUpInside)
            
            SpotifyApp.saveSession(session: session)
            self.performSegue(withIdentifier: "room_to_spotify", sender: self)
        }
        else {
            print("We attempted to login, but the session isn't valid!")
        }
    }
    
}
